-- RODA Capoeira App Database Schema
-- Clean, normalized structure for Supabase with PostGIS

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- =====================================================
-- USERS TABLE
-- =====================================================
CREATE TABLE users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT UNIQUE NOT NULL,
  full_name TEXT NOT NULL,
  capoeira_name TEXT NOT NULL,
  date_of_birth DATE,
  role TEXT CHECK (role IN ('teacher', 'student')) NOT NULL,
  profile_picture_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for users
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role);

-- =====================================================
-- GROUPS TABLE
-- =====================================================
CREATE TABLE groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  branch TEXT,
  display_name TEXT NOT NULL,
  description TEXT,
  location TEXT,
  default_timezone TEXT DEFAULT 'America/New_York',
  venmo_handle TEXT,
  header_image_url TEXT,
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  is_active BOOLEAN DEFAULT true
);

-- Indexes for groups
CREATE INDEX idx_groups_display_name ON groups(display_name);
CREATE INDEX idx_groups_created_by ON groups(created_by);
CREATE INDEX idx_groups_active ON groups(is_active);

-- =====================================================
-- GROUP MEMBERS (Relationship Table)
-- =====================================================
CREATE TABLE group_members (
  group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  role TEXT CHECK (role IN ('member', 'teacher', 'admin')) NOT NULL DEFAULT 'member',
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (group_id, user_id)
);

-- Indexes for efficient lookups
CREATE INDEX idx_group_members_user ON group_members(user_id);
CREATE INDEX idx_group_members_role ON group_members(group_id, role);

-- =====================================================
-- SCHEDULES (Recurring Class Templates)
-- =====================================================
CREATE TABLE schedules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
  teacher_id UUID REFERENCES users(id),
  
  -- Basic info
  name TEXT NOT NULL,
  description TEXT,
  event_type TEXT CHECK (event_type IN ('class', 'roda')) DEFAULT 'class',
  
  -- Location
  location GEOGRAPHY(POINT, 4326),
  location_name TEXT NOT NULL,
  location_address TEXT,
  timezone TEXT NOT NULL,
  
  -- Recurring pattern
  day_of_week INT CHECK (day_of_week BETWEEN 0 AND 6), -- 0 = Sunday
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  
  -- Settings
  price DECIMAL(10,2),
  max_students INT,
  
  -- Validity period
  effective_from DATE DEFAULT CURRENT_DATE,
  effective_until DATE,
  
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for schedules
CREATE INDEX idx_schedules_group ON schedules(group_id);
CREATE INDEX idx_schedules_teacher ON schedules(teacher_id);
CREATE INDEX idx_schedules_location ON schedules USING GIST(location);
CREATE INDEX idx_schedules_day ON schedules(day_of_week);
CREATE INDEX idx_schedules_active ON schedules(is_active);

-- =====================================================
-- CLASS INSTANCES (Actual occurrences)
-- =====================================================
CREATE TABLE class_instances (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  schedule_id UUID REFERENCES schedules(id) ON DELETE CASCADE,
  
  -- When this specific instance occurs
  scheduled_date DATE NOT NULL,
  
  -- Overrides (NULL means use schedule value)
  custom_name TEXT,
  custom_description TEXT,
  custom_start_time TIME,
  custom_end_time TIME,
  custom_location GEOGRAPHY(POINT, 4326),
  custom_location_name TEXT,
  custom_price DECIMAL(10,2),
  
  -- Instance state
  is_cancelled BOOLEAN DEFAULT false,
  cancellation_reason TEXT,
  notes TEXT,
  
  -- Computed UTC times for global queries
  start_datetime_utc TIMESTAMPTZ GENERATED ALWAYS AS (
    (scheduled_date + COALESCE(custom_start_time, 
      (SELECT start_time FROM schedules WHERE id = schedule_id)))::timestamp 
      AT TIME ZONE (SELECT timezone FROM schedules WHERE id = schedule_id)
  ) STORED,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Ensure no duplicate instances for same schedule/date
  UNIQUE(schedule_id, scheduled_date)
);

-- Indexes for class instances
CREATE INDEX idx_instances_schedule ON class_instances(schedule_id);
CREATE INDEX idx_instances_date ON class_instances(scheduled_date);
CREATE INDEX idx_instances_utc ON class_instances(start_datetime_utc);
CREATE INDEX idx_instances_cancelled ON class_instances(is_cancelled);

-- =====================================================
-- CLASS ATTENDANCE
-- =====================================================
CREATE TABLE class_attendance (
  class_instance_id UUID REFERENCES class_instances(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  
  status TEXT CHECK (status IN ('registered', 'attended', 'absent', 'cancelled')) DEFAULT 'registered',
  
  -- Payment tracking
  payment_status TEXT CHECK (payment_status IN ('not_required', 'pending', 'paid', 'verified', 'refunded')),
  payment_amount DECIMAL(10,2),
  payment_date TIMESTAMPTZ,
  payment_method TEXT,
  
  registered_at TIMESTAMPTZ DEFAULT NOW(),
  attended_at TIMESTAMPTZ,
  
  PRIMARY KEY (class_instance_id, user_id)
);

-- Indexes for attendance
CREATE INDEX idx_attendance_user ON class_attendance(user_id);
CREATE INDEX idx_attendance_status ON class_attendance(status);
CREATE INDEX idx_attendance_payment ON class_attendance(payment_status);

-- =====================================================
-- ANNOUNCEMENTS
-- =====================================================
CREATE TABLE announcements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
  author_id UUID REFERENCES users(id),
  
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  
  is_pinned BOOLEAN DEFAULT false,
  is_visible BOOLEAN DEFAULT true,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for announcements
CREATE INDEX idx_announcements_group ON announcements(group_id);
CREATE INDEX idx_announcements_author ON announcements(author_id);
CREATE INDEX idx_announcements_pinned ON announcements(is_pinned, created_at DESC);

-- =====================================================
-- USEFUL VIEWS
-- =====================================================

-- View for map display (combines schedule and instance data)
CREATE VIEW map_classes AS
SELECT 
  ci.id,
  ci.scheduled_date,
  ci.start_datetime_utc,
  COALESCE(ci.custom_name, s.name) as name,
  COALESCE(ci.custom_location, s.location) as location,
  COALESCE(ci.custom_location_name, s.location_name) as location_name,
  COALESCE(ci.custom_price, s.price) as price,
  s.event_type,
  s.teacher_id,
  s.group_id,
  s.max_students,
  ci.is_cancelled,
  ci.cancellation_reason,
  g.display_name as group_name,
  u.capoeira_name as teacher_name,
  (
    SELECT COUNT(*) 
    FROM class_attendance 
    WHERE class_instance_id = ci.id 
      AND status IN ('registered', 'attended')
  ) as registered_count
FROM class_instances ci
JOIN schedules s ON ci.schedule_id = s.id
JOIN groups g ON s.group_id = g.id
JOIN users u ON s.teacher_id = u.id
WHERE ci.scheduled_date >= CURRENT_DATE - INTERVAL '1 day'
  AND NOT ci.is_cancelled;

-- View for user's groups with their role
CREATE VIEW user_groups AS
SELECT 
  g.*,
  gm.role as user_role,
  gm.joined_at,
  gm.user_id
FROM groups g
JOIN group_members gm ON g.id = gm.group_id;

-- View for user's upcoming classes
CREATE VIEW user_upcoming_classes AS
SELECT 
  ci.*,
  s.name,
  s.description,
  s.location,
  s.location_name,
  s.timezone,
  s.teacher_id,
  s.group_id,
  ca.status as attendance_status,
  ca.payment_status,
  ca.user_id
FROM class_instances ci
JOIN schedules s ON ci.schedule_id = s.id
LEFT JOIN class_attendance ca ON ci.id = ca.class_instance_id
WHERE ci.scheduled_date >= CURRENT_DATE
  AND NOT ci.is_cancelled
ORDER BY ci.start_datetime_utc;

-- =====================================================
-- ROW LEVEL SECURITY (RLS)
-- =====================================================

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE class_instances ENABLE ROW LEVEL SECURITY;
ALTER TABLE class_attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE announcements ENABLE ROW LEVEL SECURITY;

-- Users can read all users but only update themselves
CREATE POLICY "Users can view all profiles" ON users
  FOR SELECT USING (true);

CREATE POLICY "Users can update own profile" ON users
  FOR UPDATE USING (auth.uid() = id);

-- Groups are public to read
CREATE POLICY "Groups are viewable by all" ON groups
  FOR SELECT USING (true);

-- Only group admins can update groups
CREATE POLICY "Group admins can update" ON groups
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM group_members
      WHERE group_id = groups.id
        AND user_id = auth.uid()
        AND role = 'admin'
    )
  );

-- Group members can view membership
CREATE POLICY "Members can view group membership" ON group_members
  FOR SELECT USING (true);

-- Only admins can modify membership
CREATE POLICY "Admins can manage members" ON group_members
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM group_members gm
      WHERE gm.group_id = group_members.group_id
        AND gm.user_id = auth.uid()
        AND gm.role = 'admin'
    )
  );

-- Schedules viewable by all
CREATE POLICY "Schedules are public" ON schedules
  FOR SELECT USING (true);

-- Only teachers can modify their schedules
CREATE POLICY "Teachers can manage own schedules" ON schedules
  FOR ALL USING (teacher_id = auth.uid());

-- Class instances viewable by all
CREATE POLICY "Classes are public" ON class_instances
  FOR SELECT USING (true);

-- Attendance viewable by participant or teacher
CREATE POLICY "Users can view own attendance" ON class_attendance
  FOR SELECT USING (
    user_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM class_instances ci
      JOIN schedules s ON ci.schedule_id = s.id
      WHERE ci.id = class_attendance.class_instance_id
        AND s.teacher_id = auth.uid()
    )
  );

-- =====================================================
-- HELPER FUNCTIONS
-- =====================================================

-- Function to generate class instances for a schedule
CREATE OR REPLACE FUNCTION generate_class_instances(
  schedule_id UUID,
  start_date DATE,
  end_date DATE
) RETURNS void AS $$
DECLARE
  schedule_record RECORD;
  current_date DATE;
BEGIN
  -- Get the schedule details
  SELECT * INTO schedule_record FROM schedules WHERE id = schedule_id;
  
  -- Generate instances for each matching day
  current_date := start_date;
  WHILE current_date <= end_date LOOP
    -- Check if this date matches the schedule's day of week
    IF EXTRACT(DOW FROM current_date) = schedule_record.day_of_week THEN
      -- Insert if not exists
      INSERT INTO class_instances (schedule_id, scheduled_date)
      VALUES (schedule_id, current_date)
      ON CONFLICT (schedule_id, scheduled_date) DO NOTHING;
    END IF;
    
    current_date := current_date + INTERVAL '1 day';
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Function to find classes near a point
CREATE OR REPLACE FUNCTION find_classes_near(
  user_location GEOGRAPHY,
  radius_meters INTEGER DEFAULT 5000
) RETURNS TABLE (
  id UUID,
  name TEXT,
  location GEOGRAPHY,
  distance FLOAT,
  scheduled_date DATE,
  start_time TIME
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    mc.id,
    mc.name,
    mc.location,
    ST_Distance(mc.location, user_location) as distance,
    mc.scheduled_date,
    s.start_time
  FROM map_classes mc
  JOIN schedules s ON mc.id = s.id
  WHERE ST_DWithin(mc.location, user_location, radius_meters)
  ORDER BY distance;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at trigger to relevant tables
CREATE TRIGGER set_updated_at BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
  
CREATE TRIGGER set_updated_at BEFORE UPDATE ON schedules
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
  
CREATE TRIGGER set_updated_at BEFORE UPDATE ON announcements
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- =====================================================
-- INITIAL DATA / MIGRATION HELPERS
-- =====================================================

-- Function to migrate a Firebase user to Supabase
CREATE OR REPLACE FUNCTION migrate_firebase_user(
  firebase_uid TEXT,
  user_email TEXT,
  user_data JSONB
) RETURNS UUID AS $$
DECLARE
  new_user_id UUID;
BEGIN
  -- Create auth user first (this would be done via Supabase Auth API)
  -- Then create profile
  INSERT INTO users (
    id,
    email,
    full_name,
    capoeira_name,
    date_of_birth,
    role,
    profile_picture_url
  ) VALUES (
    gen_random_uuid(), -- Would be auth.uid() in real scenario
    user_email,
    user_data->>'fullName',
    user_data->>'capoeiraName',
    (user_data->>'dateOfBirth')::date,
    user_data->>'role',
    user_data->>'profilePictureUrl'
  ) RETURNING id INTO new_user_id;
  
  RETURN new_user_id;
END;
$$ LANGUAGE plpgsql;
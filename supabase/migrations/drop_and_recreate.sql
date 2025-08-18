-- Drop all tables and start fresh
DROP SCHEMA public CASCADE;
CREATE SCHEMA public;

-- Grant permissions
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO public;

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- Create users table with text ID for Firebase UIDs
CREATE TABLE users (
  id text PRIMARY KEY,
  email text UNIQUE NOT NULL,
  full_name text NOT NULL,
  capoeira_name text,
  date_of_birth date,
  role text CHECK (role IN ('student', 'teacher', 'admin')),
  venmo_handle text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

-- Create groups table with text IDs
CREATE TABLE groups (
  id text PRIMARY KEY DEFAULT gen_random_uuid()::text,
  name text NOT NULL,
  branch text,
  location text,
  admin_ids text[] DEFAULT '{}',
  teacher_ids text[] DEFAULT '{}',
  member_ids text[] DEFAULT '{}',
  display_name text NOT NULL,
  description text,
  venmo_handle text,
  created_by text REFERENCES users(id) ON DELETE SET NULL,
  created_at timestamp with time zone DEFAULT now(),
  is_active boolean DEFAULT true,
  UNIQUE(display_name)
);

-- Create schedules table with text IDs
CREATE TABLE schedules (
  id text PRIMARY KEY DEFAULT gen_random_uuid()::text,
  group_id text NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  teacher_id text NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  event_type text NOT NULL DEFAULT 'class',
  location geography(POINT, 4326),
  location_name text NOT NULL,
  location_address text,
  timezone text NOT NULL DEFAULT 'America/New_York',
  recurrence_type text DEFAULT 'weekly',
  day_of_week integer NOT NULL CHECK (day_of_week >= 0 AND day_of_week <= 6),
  start_time time NOT NULL,
  end_time time NOT NULL,
  price decimal(10,2),
  max_students integer,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

-- Create class_instances table with text IDs
CREATE TABLE class_instances (
  id text PRIMARY KEY DEFAULT gen_random_uuid()::text,
  schedule_id text NOT NULL REFERENCES schedules(id) ON DELETE CASCADE,
  teacher_id text REFERENCES users(id) ON DELETE SET NULL,
  scheduled_date date NOT NULL,
  start_time time NOT NULL,
  end_time time NOT NULL,
  is_cancelled boolean DEFAULT false,
  cancellation_reason text,
  custom_name text,
  custom_description text,
  attending_student_ids text[] DEFAULT '{}',
  present_student_ids text[] DEFAULT '{}',
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  UNIQUE(schedule_id, scheduled_date)
);

-- Create indexes for performance
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_groups_display_name ON groups(display_name);
CREATE INDEX idx_groups_is_active ON groups(is_active);
CREATE INDEX idx_schedules_group_id ON schedules(group_id);
CREATE INDEX idx_schedules_teacher_id ON schedules(teacher_id);
CREATE INDEX idx_schedules_is_active ON schedules(is_active);
CREATE INDEX idx_class_instances_schedule_id ON class_instances(schedule_id);
CREATE INDEX idx_class_instances_scheduled_date ON class_instances(scheduled_date);
CREATE INDEX idx_class_instances_is_cancelled ON class_instances(is_cancelled);

-- Create function to generate class instances
CREATE OR REPLACE FUNCTION generate_class_instances(
  p_schedule_id text,
  p_start_date date,
  p_end_date date
) RETURNS void AS $$
DECLARE
  v_schedule record;
  v_current_date date;
  v_start_datetime timestamp;
  v_end_datetime timestamp;
BEGIN
  -- Get schedule details
  SELECT * INTO v_schedule FROM schedules WHERE id = p_schedule_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Schedule not found';
  END IF;
  
  -- Loop through date range
  v_current_date := p_start_date;
  WHILE v_current_date <= p_end_date LOOP
    -- Check if this date matches the schedule's day of week
    IF EXTRACT(DOW FROM v_current_date) = v_schedule.day_of_week THEN
      -- Check if instance already exists
      IF NOT EXISTS (
        SELECT 1 FROM class_instances 
        WHERE schedule_id = p_schedule_id 
        AND scheduled_date = v_current_date
      ) THEN
        -- Create the instance
        INSERT INTO class_instances (
          id,
          schedule_id,
          teacher_id,
          scheduled_date,
          start_time,
          end_time,
          is_cancelled,
          attending_student_ids,
          present_student_ids
        ) VALUES (
          gen_random_uuid()::text,
          p_schedule_id,
          v_schedule.teacher_id,
          v_current_date,
          v_schedule.start_time,
          v_schedule.end_time,
          false,
          ARRAY[]::text[],
          ARRAY[]::text[]
        );
      END IF;
    END IF;
    
    v_current_date := v_current_date + 1;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Enable Row Level Security
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE class_instances ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "Public profiles are viewable by everyone" ON users FOR SELECT USING (true);
CREATE POLICY "Users can update own profile" ON users FOR UPDATE USING (auth.uid()::text = id);

CREATE POLICY "Groups are viewable by everyone" ON groups FOR SELECT USING (true);
CREATE POLICY "Group admins can update" ON groups FOR UPDATE USING (auth.uid()::text = ANY(admin_ids));
CREATE POLICY "Anyone can create groups" ON groups FOR INSERT WITH CHECK (true);

CREATE POLICY "Schedules are viewable by everyone" ON schedules FOR SELECT USING (true);
CREATE POLICY "Teachers can manage their schedules" ON schedules FOR ALL USING (auth.uid()::text = teacher_id);

CREATE POLICY "Class instances are viewable by everyone" ON class_instances FOR SELECT USING (true);
CREATE POLICY "Teachers can manage their class instances" ON class_instances FOR ALL USING (auth.uid()::text = teacher_id);
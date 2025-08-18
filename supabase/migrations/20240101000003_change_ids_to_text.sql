-- Change all UUID columns to TEXT to support Firebase Auth IDs

-- First, drop all foreign key constraints
ALTER TABLE groups DROP CONSTRAINT IF EXISTS groups_created_by_fkey;
ALTER TABLE class_instances DROP CONSTRAINT IF EXISTS class_instances_schedule_id_fkey;
ALTER TABLE class_instances DROP CONSTRAINT IF EXISTS class_instances_teacher_id_fkey;
ALTER TABLE schedules DROP CONSTRAINT IF EXISTS schedules_group_id_fkey;
ALTER TABLE schedules DROP CONSTRAINT IF EXISTS schedules_teacher_id_fkey;

-- Change users table
ALTER TABLE users ALTER COLUMN id TYPE text;

-- Change groups table
ALTER TABLE groups ALTER COLUMN id TYPE text;
ALTER TABLE groups ALTER COLUMN created_by TYPE text;

-- Change schedules table
ALTER TABLE schedules ALTER COLUMN id TYPE text;
ALTER TABLE schedules ALTER COLUMN group_id TYPE text;
ALTER TABLE schedules ALTER COLUMN teacher_id TYPE text;

-- Change class_instances table
ALTER TABLE class_instances ALTER COLUMN id TYPE text;
ALTER TABLE class_instances ALTER COLUMN schedule_id TYPE text;
ALTER TABLE class_instances ALTER COLUMN teacher_id TYPE text;

-- Update array columns to text[]
ALTER TABLE groups ALTER COLUMN admin_ids TYPE text[] USING admin_ids::text[];
ALTER TABLE groups ALTER COLUMN teacher_ids TYPE text[] USING teacher_ids::text[];
ALTER TABLE groups ALTER COLUMN member_ids TYPE text[] USING member_ids::text[];
ALTER TABLE class_instances ALTER COLUMN attending_student_ids TYPE text[] USING attending_student_ids::text[];
ALTER TABLE class_instances ALTER COLUMN present_student_ids TYPE text[] USING present_student_ids::text[];

-- Re-add foreign key constraints with text types
ALTER TABLE groups 
  ADD CONSTRAINT groups_created_by_fkey 
  FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL;

ALTER TABLE schedules 
  ADD CONSTRAINT schedules_group_id_fkey 
  FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE;

ALTER TABLE schedules 
  ADD CONSTRAINT schedules_teacher_id_fkey 
  FOREIGN KEY (teacher_id) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE class_instances 
  ADD CONSTRAINT class_instances_schedule_id_fkey 
  FOREIGN KEY (schedule_id) REFERENCES schedules(id) ON DELETE CASCADE;

ALTER TABLE class_instances 
  ADD CONSTRAINT class_instances_teacher_id_fkey 
  FOREIGN KEY (teacher_id) REFERENCES users(id) ON DELETE SET NULL;

-- Update the function to work with text IDs
CREATE OR REPLACE FUNCTION generate_class_instances(
  p_schedule_id text,
  p_start_date date,
  p_end_date date
) RETURNS void AS $$
DECLARE
  v_schedule record;
  v_current_date date;
  v_class_date date;
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
      -- Calculate the full datetime
      v_start_datetime := v_current_date + v_schedule.start_time;
      v_end_datetime := v_current_date + v_schedule.end_time;
      
      -- Check if instance already exists
      IF NOT EXISTS (
        SELECT 1 FROM class_instances 
        WHERE schedule_id = p_schedule_id 
        AND scheduled_date = v_current_date
      ) THEN
        -- Create the instance with text ID
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
          gen_random_uuid()::text,  -- Convert UUID to text
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
-- Change all UUID columns to TEXT to support Firebase Auth IDs

-- First, drop dependent views
DROP VIEW IF EXISTS map_classes CASCADE;
DROP VIEW IF EXISTS user_groups CASCADE;

-- Drop all foreign key constraints
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

-- Add missing columns if they don't exist
ALTER TABLE groups ADD COLUMN IF NOT EXISTS admin_ids text[] DEFAULT '{}';
ALTER TABLE groups ADD COLUMN IF NOT EXISTS teacher_ids text[] DEFAULT '{}';
ALTER TABLE groups ADD COLUMN IF NOT EXISTS member_ids text[] DEFAULT '{}';
ALTER TABLE class_instances ADD COLUMN IF NOT EXISTS teacher_id text;
ALTER TABLE class_instances ADD COLUMN IF NOT EXISTS attending_student_ids text[] DEFAULT '{}';
ALTER TABLE class_instances ADD COLUMN IF NOT EXISTS present_student_ids text[] DEFAULT '{}';

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

-- Recreate the views with text types
CREATE OR REPLACE VIEW user_groups AS
SELECT 
  g.*,
  u.full_name as created_by_name
FROM groups g
LEFT JOIN users u ON g.created_by = u.id;

CREATE OR REPLACE VIEW map_classes AS
SELECT 
  ci.id,
  ci.schedule_id,
  ci.scheduled_date,
  ci.start_time,
  ci.end_time,
  ci.is_cancelled,
  ci.teacher_id,
  s.name as class_name,
  s.location,
  s.location_name,
  s.group_id,
  g.display_name as group_name
FROM class_instances ci
JOIN schedules s ON ci.schedule_id = s.id
JOIN groups g ON s.group_id = g.id
WHERE ci.is_cancelled = false
  AND ci.scheduled_date >= CURRENT_DATE;
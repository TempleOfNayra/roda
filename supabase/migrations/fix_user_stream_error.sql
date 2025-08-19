-- Fix user stream error by ensuring all columns exist in users table

-- Add missing columns to users table that UserModel expects
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS teaching_group_ids TEXT[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS joined_group_ids TEXT[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS affiliation_group_id TEXT,
ADD COLUMN IF NOT EXISTS group_id TEXT,
ADD COLUMN IF NOT EXISTS group_name TEXT,
ADD COLUMN IF NOT EXISTS teacher_name TEXT;

-- Ensure all required columns have proper defaults
UPDATE users 
SET 
  teaching_group_ids = COALESCE(teaching_group_ids, '{}'),
  joined_group_ids = COALESCE(joined_group_ids, '{}')
WHERE teaching_group_ids IS NULL OR joined_group_ids IS NULL;

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_users_teaching_group_ids ON users USING GIN (teaching_group_ids);
CREATE INDEX IF NOT EXISTS idx_users_joined_group_ids ON users USING GIN (joined_group_ids);
CREATE INDEX IF NOT EXISTS idx_users_affiliation_group_id ON users(affiliation_group_id);
-- Fix groups table by adding all missing columns

-- Add all the new columns needed for the enhanced group model
ALTER TABLE groups 
ADD COLUMN IF NOT EXISTS city TEXT DEFAULT 'Unknown City',
ADD COLUMN IF NOT EXISTS teacher_title TEXT DEFAULT 'Professor',
ADD COLUMN IF NOT EXISTS teacher_full_name TEXT DEFAULT 'Unknown Teacher',
ADD COLUMN IF NOT EXISTS capoeira_style TEXT DEFAULT 'contemporanea',
ADD COLUMN IF NOT EXISTS lineage TEXT,
ADD COLUMN IF NOT EXISTS header_image_url TEXT,
ADD COLUMN IF NOT EXISTS teacher_profile_picture TEXT,
ADD COLUMN IF NOT EXISTS admin_ids TEXT[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS teacher_ids TEXT[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS member_ids TEXT[] DEFAULT '{}';

-- Ensure proper constraints on capoeira_style
ALTER TABLE groups 
DROP CONSTRAINT IF EXISTS groups_capoeira_style_check;

ALTER TABLE groups
ADD CONSTRAINT groups_capoeira_style_check 
CHECK (capoeira_style IN ('angola', 'regional', 'contemporanea', 'other'));

-- Update existing rows with defaults where needed
UPDATE groups 
SET 
  city = COALESCE(city, location, 'Unknown City'),
  teacher_full_name = COALESCE(teacher_full_name, 'Unknown Teacher'),
  admin_ids = CASE 
    WHEN admin_ids IS NULL OR admin_ids = '{}' 
    THEN ARRAY[created_by]::TEXT[] 
    ELSE admin_ids 
  END,
  teacher_ids = CASE 
    WHEN teacher_ids IS NULL OR teacher_ids = '{}' 
    THEN ARRAY[created_by]::TEXT[] 
    ELSE teacher_ids 
  END,
  member_ids = CASE 
    WHEN member_ids IS NULL OR member_ids = '{}' 
    THEN ARRAY[created_by]::TEXT[] 
    ELSE member_ids 
  END
WHERE city IS NULL 
  OR teacher_full_name IS NULL 
  OR admin_ids IS NULL 
  OR teacher_ids IS NULL 
  OR member_ids IS NULL;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_groups_city ON groups(city);
CREATE INDEX IF NOT EXISTS idx_groups_capoeira_style ON groups(capoeira_style);
CREATE INDEX IF NOT EXISTS idx_groups_teacher_title ON groups(teacher_title);
CREATE INDEX IF NOT EXISTS idx_groups_admin_ids ON groups USING GIN (admin_ids);
CREATE INDEX IF NOT EXISTS idx_groups_teacher_ids ON groups USING GIN (teacher_ids);
CREATE INDEX IF NOT EXISTS idx_groups_member_ids ON groups USING GIN (member_ids);
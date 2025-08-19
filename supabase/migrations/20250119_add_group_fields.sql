-- Add new fields to groups table for enhanced group creation

-- Add city field (required)
ALTER TABLE groups 
ADD COLUMN IF NOT EXISTS city TEXT;

-- Add teacher title field (required) 
ALTER TABLE groups
ADD COLUMN IF NOT EXISTS teacher_title TEXT DEFAULT 'Professor';

-- Add teacher full name field (required)
ALTER TABLE groups
ADD COLUMN IF NOT EXISTS teacher_full_name TEXT;

-- Add capoeira style field (required)
ALTER TABLE groups
ADD COLUMN IF NOT EXISTS capoeira_style TEXT DEFAULT 'contemporanea'
CHECK (capoeira_style IN ('angola', 'regional', 'contemporanea', 'other'));

-- Add lineage field (optional)
ALTER TABLE groups
ADD COLUMN IF NOT EXISTS lineage TEXT;

-- Update existing rows with default values if needed
UPDATE groups 
SET city = COALESCE(location, 'Unknown City')
WHERE city IS NULL;

UPDATE groups
SET teacher_full_name = COALESCE(teacher_full_name, 'Unknown Teacher')
WHERE teacher_full_name IS NULL;

-- Make city and teacher_full_name required for new rows
ALTER TABLE groups
ALTER COLUMN city SET NOT NULL;

ALTER TABLE groups
ALTER COLUMN teacher_full_name SET NOT NULL;

-- Add indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_groups_city ON groups(city);
CREATE INDEX IF NOT EXISTS idx_groups_capoeira_style ON groups(capoeira_style);
CREATE INDEX IF NOT EXISTS idx_groups_teacher_title ON groups(teacher_title);

-- Update RLS policies if needed to include new fields
-- The existing policies should work fine as they check user IDs, not specific fields
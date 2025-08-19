-- Update Groups Table Structure
-- Groups are uniquely identified by name + city + primary teacher

-- First, drop existing constraints if any
ALTER TABLE groups DROP CONSTRAINT IF EXISTS groups_unique_name_city_teacher;

-- Add new columns if they don't exist
ALTER TABLE groups 
  ADD COLUMN IF NOT EXISTS city TEXT,
  ADD COLUMN IF NOT EXISTS primary_teacher_id UUID REFERENCES users(id),
  ADD COLUMN IF NOT EXISTS primary_teacher_name TEXT,
  ADD COLUMN IF NOT EXISTS profile_header_url TEXT;

-- Create unique constraint for group identification
ALTER TABLE groups 
  ADD CONSTRAINT groups_unique_name_city_teacher 
  UNIQUE (name, city, primary_teacher_name);

-- Update display_name to be generated from name + city + teacher
CREATE OR REPLACE FUNCTION update_group_display_name()
RETURNS TRIGGER AS $$
BEGIN
  NEW.display_name = NEW.name || ' - ' || COALESCE(NEW.city, 'Online') || ' - ' || COALESCE(NEW.primary_teacher_name, 'TBD');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_group_display_name_trigger ON groups;
CREATE TRIGGER update_group_display_name_trigger
  BEFORE INSERT OR UPDATE ON groups
  FOR EACH ROW
  EXECUTE FUNCTION update_group_display_name();

-- Ensure group_members table exists with proper structure
CREATE TABLE IF NOT EXISTS group_members (
  group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  role TEXT CHECK (role IN ('member', 'teacher', 'admin')) NOT NULL DEFAULT 'member',
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (group_id, user_id)
);

-- Indexes for efficient lookups
CREATE INDEX IF NOT EXISTS idx_group_members_user ON group_members(user_id);
CREATE INDEX IF NOT EXISTS idx_group_members_role ON group_members(group_id, role);
CREATE INDEX IF NOT EXISTS idx_groups_city ON groups(city);
CREATE INDEX IF NOT EXISTS idx_groups_primary_teacher ON groups(primary_teacher_id);

-- Add RLS policies for group_members
ALTER TABLE group_members ENABLE ROW LEVEL SECURITY;

-- Anyone can view group members
CREATE POLICY "Anyone can view group members" ON group_members
  FOR SELECT USING (true);

-- Group admins can manage members
CREATE POLICY "Group admins can manage members" ON group_members
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM group_members gm
      WHERE gm.group_id = group_members.group_id
      AND gm.user_id = auth.uid()
      AND gm.role = 'admin'
    )
  );

-- Users can leave groups (delete their own membership)
CREATE POLICY "Users can leave groups" ON group_members
  FOR DELETE USING (user_id = auth.uid());
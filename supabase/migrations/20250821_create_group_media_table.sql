-- Create group_media table for storing photos and videos
CREATE TABLE IF NOT EXISTS group_media (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  group_id TEXT NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  uploaded_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  url TEXT NOT NULL,
  media_type TEXT NOT NULL CHECK (media_type IN ('photo', 'video')),
  caption TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Add indexes
CREATE INDEX idx_group_media_group_id ON group_media(group_id);
CREATE INDEX idx_group_media_uploaded_by ON group_media(uploaded_by);
CREATE INDEX idx_group_media_created_at ON group_media(created_at DESC);

-- Enable RLS
ALTER TABLE group_media ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- View policy: Group members can view their group's media
CREATE POLICY "Group members can view group media" ON group_media
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM group_members gm
      WHERE gm.group_id = group_media.group_id
      AND gm.user_id = auth.uid()
    )
  );

-- Insert policy: Group members can upload media
CREATE POLICY "Group members can upload media" ON group_media
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM group_members gm
      WHERE gm.group_id = group_media.group_id
      AND gm.user_id = auth.uid()
    )
    AND uploaded_by = auth.uid()
  );

-- Update policy: Uploader can update their own media (e.g., caption)
CREATE POLICY "Users can update their own media" ON group_media
  FOR UPDATE
  USING (uploaded_by = auth.uid())
  WITH CHECK (uploaded_by = auth.uid());

-- Delete policy: Uploader or group admin can delete media
CREATE POLICY "Uploader or admin can delete media" ON group_media
  FOR DELETE
  USING (
    uploaded_by = auth.uid()
    OR EXISTS (
      SELECT 1 FROM group_members gm
      WHERE gm.group_id = group_media.group_id
      AND gm.user_id = auth.uid()
      AND gm.role = 'admin'
    )
  );

-- Grant permissions
GRANT ALL ON group_media TO authenticated;
GRANT SELECT ON group_media TO anon;

-- Enable realtime
ALTER PUBLICATION supabase_realtime ADD TABLE group_media;
-- Drop existing policies that reference non-existent group_members table
DROP POLICY IF EXISTS "Group members can view group media" ON group_media;
DROP POLICY IF EXISTS "Group members can upload media" ON group_media;
DROP POLICY IF EXISTS "Uploader or admin can delete media" ON group_media;

-- Create new policies using the groups table structure
-- View policy: Group members can view their group's media
CREATE POLICY "Group members can view group media" ON group_media
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM groups g
      WHERE g.id = group_media.group_id
      AND (
        auth.uid()::text = ANY(g.admin_ids) OR
        auth.uid()::text = ANY(g.teacher_ids) OR
        auth.uid()::text = ANY(g.member_ids)
      )
    )
  );

-- Insert policy: Group members can upload media
CREATE POLICY "Group members can upload media" ON group_media
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM groups g
      WHERE g.id = group_media.group_id
      AND (
        auth.uid()::text = ANY(g.admin_ids) OR
        auth.uid()::text = ANY(g.teacher_ids) OR
        auth.uid()::text = ANY(g.member_ids)
      )
    )
    AND uploaded_by = auth.uid()
  );

-- Delete policy: Uploader or group admin can delete media
CREATE POLICY "Uploader or admin can delete media" ON group_media
  FOR DELETE
  USING (
    uploaded_by = auth.uid()
    OR EXISTS (
      SELECT 1 FROM groups g
      WHERE g.id = group_media.group_id
      AND auth.uid()::text = ANY(g.admin_ids)
    )
  );
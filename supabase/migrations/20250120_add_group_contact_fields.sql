-- Add new fields to groups table
ALTER TABLE groups 
ADD COLUMN IF NOT EXISTS logo_image_url TEXT,
ADD COLUMN IF NOT EXISTS contact_number TEXT,
ADD COLUMN IF NOT EXISTS email TEXT;

-- Add comments for documentation
COMMENT ON COLUMN groups.logo_image_url IS 'URL to the group logo image in R2 storage';
COMMENT ON COLUMN groups.contact_number IS 'Contact phone number for the group';
COMMENT ON COLUMN groups.email IS 'Contact email for the group';
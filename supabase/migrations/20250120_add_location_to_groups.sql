-- Add location fields to groups table
ALTER TABLE groups 
ADD COLUMN IF NOT EXISTS location_address text,
ADD COLUMN IF NOT EXISTS location_name text,
ADD COLUMN IF NOT EXISTS latitude double precision,
ADD COLUMN IF NOT EXISTS longitude double precision,
ADD COLUMN IF NOT EXISTS place_id text;

-- Add geography column for spatial queries
ALTER TABLE groups
ADD COLUMN IF NOT EXISTS location_point geography(POINT, 4326);

-- Create function to update location_point when lat/lng changes
CREATE OR REPLACE FUNCTION update_group_location_point()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL THEN
    NEW.location_point = ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326);
  ELSE
    NEW.location_point = NULL;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically update location_point
DROP TRIGGER IF EXISTS update_group_location_point_trigger ON groups;
CREATE TRIGGER update_group_location_point_trigger
BEFORE INSERT OR UPDATE OF latitude, longitude ON groups
FOR EACH ROW
EXECUTE FUNCTION update_group_location_point();
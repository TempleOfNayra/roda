-- Drop existing view if it exists (to handle schema changes)
DROP VIEW IF EXISTS map_classes CASCADE;

-- Create the map_classes view with all required columns
CREATE VIEW map_classes AS
SELECT 
  ci.id,
  ci.schedule_id,
  ci.scheduled_date,
  CAST(ci.scheduled_date AS TIMESTAMPTZ) + ci.start_time as start_datetime_utc,
  COALESCE(ci.custom_name, s.name) as name,
  s.location as location,
  s.location_name as location_name,
  s.price as price,
  s.event_type,
  ci.teacher_id,
  s.group_id,
  s.max_students,
  ci.is_cancelled,
  ci.cancellation_reason,
  g.display_name as group_name,
  u.capoeira_name as teacher_name,
  ci.attending_student_ids,
  ci.present_student_ids,
  (
    SELECT COUNT(*) 
    FROM unnest(ci.attending_student_ids) as student_id
  ) as registered_count
FROM class_instances ci
JOIN schedules s ON ci.schedule_id = s.id
JOIN groups g ON s.group_id = g.id
JOIN users u ON ci.teacher_id = u.id
WHERE ci.scheduled_date >= CURRENT_DATE - INTERVAL '1 day';

-- Drop existing functions if they exist
DROP FUNCTION IF EXISTS get_classes_in_bounds CASCADE;
DROP FUNCTION IF EXISTS get_classes_near_point CASCADE;
DROP FUNCTION IF EXISTS get_classes_along_route CASCADE;

-- Get classes within a polygon boundary
CREATE OR REPLACE FUNCTION get_classes_in_bounds(
  bounds_polygon TEXT,
  start_date DATE,
  end_date DATE
) RETURNS TABLE (
  id TEXT,
  schedule_id TEXT,
  scheduled_date DATE,
  start_datetime_utc TIMESTAMPTZ,
  location GEOGRAPHY,
  location_name TEXT,
  name TEXT,
  event_type TEXT,
  teacher_id TEXT,
  group_id TEXT,
  price DECIMAL,
  max_students INT,
  is_cancelled BOOLEAN,
  cancellation_reason TEXT,
  registered_count BIGINT,
  group_name TEXT,
  teacher_name TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    mc.id,
    mc.schedule_id,
    mc.scheduled_date,
    mc.start_datetime_utc,
    mc.location,
    mc.location_name,
    mc.name,
    mc.event_type,
    mc.teacher_id,
    mc.group_id,
    mc.price,
    mc.max_students,
    mc.is_cancelled,
    mc.cancellation_reason,
    mc.registered_count,
    mc.group_name,
    mc.teacher_name
  FROM map_classes mc
  WHERE mc.location IS NOT NULL
    AND ST_Within(mc.location, ST_GeomFromText(bounds_polygon, 4326)::geography)
    AND mc.scheduled_date >= start_date
    AND mc.scheduled_date <= end_date
    AND NOT COALESCE(mc.is_cancelled, false);
END;
$$ LANGUAGE plpgsql;

-- Get classes near a point with distance
CREATE OR REPLACE FUNCTION get_classes_near_point(
  center_lat DOUBLE PRECISION,
  center_lng DOUBLE PRECISION,
  radius_meters DOUBLE PRECISION,
  start_date DATE,
  end_date DATE
) RETURNS TABLE (
  id TEXT,
  schedule_id TEXT,
  scheduled_date DATE,
  start_datetime_utc TIMESTAMPTZ,
  location GEOGRAPHY,
  location_name TEXT,
  name TEXT,
  event_type TEXT,
  teacher_id TEXT,
  group_id TEXT,
  price DECIMAL,
  max_students INT,
  is_cancelled BOOLEAN,
  cancellation_reason TEXT,
  registered_count BIGINT,
  group_name TEXT,
  teacher_name TEXT,
  distance FLOAT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    mc.id,
    mc.schedule_id,
    mc.scheduled_date,
    mc.start_datetime_utc,
    mc.location,
    mc.location_name,
    mc.name,
    mc.event_type,
    mc.teacher_id,
    mc.group_id,
    mc.price,
    mc.max_students,
    mc.is_cancelled,
    mc.cancellation_reason,
    mc.registered_count,
    mc.group_name,
    mc.teacher_name,
    ST_Distance(
      mc.location,
      ST_MakePoint(center_lng, center_lat)::geography
    ) as distance
  FROM map_classes mc
  WHERE mc.location IS NOT NULL
    AND ST_DWithin(
      mc.location,
      ST_MakePoint(center_lng, center_lat)::geography,
      radius_meters
    )
    AND mc.scheduled_date >= start_date
    AND mc.scheduled_date <= end_date
    AND NOT COALESCE(mc.is_cancelled, false)
  ORDER BY distance;
END;
$$ LANGUAGE plpgsql;

-- Get classes along a route with buffer
CREATE OR REPLACE FUNCTION get_classes_along_route(
  route_line TEXT,
  buffer_meters DOUBLE PRECISION,
  start_date DATE,
  end_date DATE
) RETURNS TABLE (
  id TEXT,
  location GEOGRAPHY,
  location_name TEXT,
  name TEXT,
  scheduled_date DATE,
  distance FLOAT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    mc.id,
    mc.location,
    mc.location_name,
    mc.name,
    mc.scheduled_date,
    ST_Distance(
      mc.location,
      ST_GeomFromText(route_line, 4326)::geography
    ) as distance
  FROM map_classes mc
  WHERE mc.location IS NOT NULL
    AND ST_DWithin(
      mc.location,
      ST_Buffer(ST_GeomFromText(route_line, 4326)::geography, buffer_meters),
      0
    )
    AND mc.scheduled_date >= start_date
    AND mc.scheduled_date <= end_date
    AND NOT COALESCE(mc.is_cancelled, false)
  ORDER BY distance;
END;
$$ LANGUAGE plpgsql;
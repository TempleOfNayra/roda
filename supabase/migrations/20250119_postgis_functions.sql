-- PostGIS functions for efficient geographic queries

-- Get classes within a polygon boundary
CREATE OR REPLACE FUNCTION get_classes_in_bounds(
  bounds_polygon TEXT,
  start_date DATE,
  end_date DATE
) RETURNS TABLE (
  id UUID,
  scheduled_date DATE,
  start_datetime_utc TIMESTAMPTZ,
  location GEOGRAPHY,
  location_name TEXT,
  name TEXT,
  event_type TEXT,
  teacher_id UUID,
  group_id UUID,
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
  WHERE ST_Within(mc.location, ST_GeomFromText(bounds_polygon, 4326)::geography)
    AND mc.scheduled_date >= start_date
    AND mc.scheduled_date <= end_date;
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
  id UUID,
  scheduled_date DATE,
  start_datetime_utc TIMESTAMPTZ,
  location GEOGRAPHY,
  location_name TEXT,
  name TEXT,
  event_type TEXT,
  teacher_id UUID,
  group_id UUID,
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
  WHERE ST_DWithin(
    mc.location,
    ST_MakePoint(center_lng, center_lat)::geography,
    radius_meters
  )
    AND mc.scheduled_date >= start_date
    AND mc.scheduled_date <= end_date
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
  id UUID,
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
  WHERE ST_DWithin(
    mc.location,
    ST_Buffer(ST_GeomFromText(route_line, 4326)::geography, buffer_meters),
    0
  )
    AND mc.scheduled_date >= start_date
    AND mc.scheduled_date <= end_date
  ORDER BY distance;
END;
$$ LANGUAGE plpgsql;
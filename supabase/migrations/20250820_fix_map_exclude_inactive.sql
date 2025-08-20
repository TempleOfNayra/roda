-- Fix map_classes view to exclude inactive schedules and cancelled classes
-- This ensures only active, non-cancelled classes appear on the map

-- First drop the existing view
DROP VIEW IF EXISTS map_classes CASCADE;

-- Recreate with filters for active schedules and non-cancelled classes
CREATE VIEW map_classes AS
SELECT 
  ci.id,
  ci.schedule_id,
  ci.scheduled_date,
  CAST(ci.scheduled_date AS TIMESTAMPTZ) + ci.start_time as start_datetime_utc,
  COALESCE(ci.custom_name, s.name) as name,
  s.location as location,
  s.location_name as location_name,
  -- Extract coordinates from geography field
  ST_Y(s.location::geometry) as latitude,
  ST_X(s.location::geometry) as longitude,
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
WHERE ci.scheduled_date >= CURRENT_DATE - INTERVAL '1 day'
  AND s.is_active = true  -- Only show active schedules
  AND ci.is_cancelled = false;  -- Only show non-cancelled classes

-- Grant permissions for authenticated and anonymous users
GRANT SELECT ON map_classes TO authenticated;
GRANT SELECT ON map_classes TO anon;

-- Add a comment explaining the view
COMMENT ON VIEW map_classes IS 'Provides active class instance data with extracted location coordinates for map display. Excludes inactive schedules and cancelled classes.';
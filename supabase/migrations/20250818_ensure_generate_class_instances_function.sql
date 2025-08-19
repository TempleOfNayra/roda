-- Drop the existing function if it exists (to handle parameter type mismatches)
DROP FUNCTION IF EXISTS generate_class_instances CASCADE;

-- Create the generate_class_instances function with correct parameter types
CREATE OR REPLACE FUNCTION generate_class_instances(
  p_schedule_id text,
  p_start_date date,
  p_end_date date
) RETURNS void AS $$
DECLARE
  v_schedule record;
  v_current_date date;
BEGIN
  -- Get schedule details
  SELECT * INTO v_schedule FROM schedules WHERE id = p_schedule_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Schedule not found';
  END IF;
  
  -- Loop through date range
  v_current_date := p_start_date;
  WHILE v_current_date <= p_end_date LOOP
    -- Check if this date matches the schedule's day of week (PostgreSQL DOW: 0=Sunday, 6=Saturday)
    IF EXTRACT(DOW FROM v_current_date) = v_schedule.day_of_week THEN
      -- Check if instance already exists
      IF NOT EXISTS (
        SELECT 1 FROM class_instances 
        WHERE schedule_id = p_schedule_id 
        AND scheduled_date = v_current_date
      ) THEN
        -- Create the instance with all required fields
        INSERT INTO class_instances (
          schedule_id,
          teacher_id,
          scheduled_date,
          start_time,
          end_time,
          is_cancelled,
          attending_student_ids,
          present_student_ids
        ) VALUES (
          p_schedule_id,
          v_schedule.teacher_id,
          v_current_date,
          v_schedule.start_time,
          v_schedule.end_time,
          false,
          '{}',
          '{}'
        );
      END IF;
    END IF;
    
    v_current_date := v_current_date + INTERVAL '1 day';
  END LOOP;
END;
$$ LANGUAGE plpgsql;
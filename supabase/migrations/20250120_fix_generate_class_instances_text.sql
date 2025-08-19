-- Drop the existing function
DROP FUNCTION IF EXISTS generate_class_instances(UUID, DATE, DATE);

-- Recreate with TEXT ID parameter to match schedules table
CREATE OR REPLACE FUNCTION generate_class_instances(
    p_schedule_id TEXT,
    p_start_date DATE,
    p_end_date DATE
)
RETURNS VOID AS $$
DECLARE
    v_schedule RECORD;
    v_current_date DATE;
    v_class_date DATE;
    v_start_datetime TIMESTAMP;
    v_end_datetime TIMESTAMP;
BEGIN
    -- Get the schedule details
    SELECT * INTO v_schedule
    FROM schedules
    WHERE id = p_schedule_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Schedule not found: %', p_schedule_id;
    END IF;
    
    -- Loop through each date in the range
    v_current_date := p_start_date;
    
    WHILE v_current_date <= p_end_date LOOP
        -- Check if this date matches the schedule's day of week (0=Sunday, 6=Saturday)
        IF EXTRACT(DOW FROM v_current_date) = v_schedule.day_of_week THEN
            -- Create timestamps for this instance
            v_start_datetime := v_current_date + v_schedule.start_time;
            v_end_datetime := v_current_date + v_schedule.end_time;
            
            -- Insert the class instance if it doesn't already exist
            INSERT INTO class_instances (
                schedule_id,
                scheduled_date,
                start_time,
                end_time,
                status,
                created_at
            )
            VALUES (
                p_schedule_id,
                v_current_date,
                v_schedule.start_time::TEXT,
                v_schedule.end_time::TEXT,
                'scheduled',
                NOW()
            )
            ON CONFLICT (schedule_id, scheduled_date) 
            DO NOTHING; -- Skip if instance already exists for this date
        END IF;
        
        -- Move to next day
        v_current_date := v_current_date + INTERVAL '1 day';
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION generate_class_instances(TEXT, DATE, DATE) TO authenticated;
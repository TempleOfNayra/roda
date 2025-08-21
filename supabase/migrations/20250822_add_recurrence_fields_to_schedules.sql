-- Add fields for supporting different recurrence patterns for rodas/batizados
ALTER TABLE schedules 
ADD COLUMN IF NOT EXISTS week_of_month INTEGER CHECK (week_of_month >= 1 AND week_of_month <= 5),
ADD COLUMN IF NOT EXISTS specific_date DATE;

-- Add comment for clarity
COMMENT ON COLUMN schedules.week_of_month IS 'For monthly recurrence: 1=first, 2=second, 3=third, 4=fourth, 5=last occurrence of day_of_week in month';
COMMENT ON COLUMN schedules.specific_date IS 'For one-time events, the specific date';
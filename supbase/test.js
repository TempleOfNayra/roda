
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://enukwrgrbbglxvllcjjn.supabase.co'
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVudWt3cmdyYmJnbHh2bGxjampuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTU0NzQ5NTMsImV4cCI6MjA3MTA1MDk1M30.W6sz8lohUh0wa1lsxQsGEKe2JqVHiQtrdswcoKakbUQ'
const supabase = createClient(supabaseUrl, supabaseKey);
console.log(supabase);


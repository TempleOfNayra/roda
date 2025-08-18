import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://enukwrgrbbglxvllcjjn.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVudWt3cmdyYmJnbHh2bGxjampuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTU0NzQ5NTMsImV4cCI6MjA3MTA1MDk1M30.W6sz8lohUh0wa1lsxQsGEKe2JqVHiQtrdswcoKakbUQ';

const supabase = createClient(supabaseUrl, supabaseKey);

async function checkTables() {
  try {
    // Try to query each table
    console.log('Checking if tables exist...\n');
    
    const tables = ['users', 'groups', 'schedules', 'class_instances'];
    
    for (const table of tables) {
      const { data, error } = await supabase
        .from(table)
        .select('*')
        .limit(1);
      
      if (error) {
        console.log(`❌ Table '${table}' - Error: ${error.message}`);
      } else {
        console.log(`✅ Table '${table}' exists`);
      }
    }
  } catch (e) {
    console.error('Error:', e);
  }
}

checkTables();
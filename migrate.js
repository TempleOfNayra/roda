const { createClient } = require('@supabase/supabase-js');

// Use service role key for admin access
const SUPABASE_URL = 'https://enukwrgrbbglxvllcjjn.supabase.co';
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY || 'your-service-role-key-here';

// Get service key from: https://supabase.com/dashboard/project/enukwrgrbbglxvllcjjn/settings/api
// Look for "service_role" under Project API keys

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

async function runMigrations() {
  console.log('🚀 Starting migrations...\n');

  // Test connection
  try {
    const { data, error } = await supabase.from('groups').select('id').limit(1);
    if (error && error.message.includes('column')) {
      console.log('✅ Connected to database, migrations needed\n');
    } else {
      console.log('✅ Connected to database\n');
    }
  } catch (e) {
    console.error('❌ Failed to connect. Check your service key.');
    console.error('Get it from: https://supabase.com/dashboard/project/enukwrgrbbglxvllcjjn/settings/api');
    process.exit(1);
  }

  // Since we can't run ALTER TABLE directly, we'll check what exists
  // and provide feedback
  
  console.log('Checking groups table...');
  try {
    await supabase.from('groups').select('city, teacher_title').limit(1);
    console.log('✅ Groups table has new columns');
  } catch (e) {
    console.log('❌ Groups table missing columns');
    console.log('   Run the SQL from supabase/migrations/20250818184535_add_enhanced_group_fields.sql');
  }

  console.log('\nChecking users table...');
  try {
    await supabase.from('users').select('teaching_group_ids').limit(1);
    console.log('✅ Users table has new columns');
  } catch (e) {
    console.log('❌ Users table missing columns');
    console.log('   Run the SQL from supabase/migrations/20250818184535_add_enhanced_group_fields.sql');
  }

  console.log('\nChecking storage buckets...');
  try {
    const buckets = await supabase.storage.listBuckets();
    const required = ['profile-pictures', 'group-images', 'announcement-images'];
    
    for (const bucket of required) {
      if (buckets.data?.some(b => b.id === bucket)) {
        console.log(`✅ Bucket exists: ${bucket}`);
      } else {
        console.log(`❌ Missing bucket: ${bucket}`);
        // Try to create it
        try {
          await supabase.storage.createBucket(bucket, { public: true });
          console.log(`   ✅ Created bucket: ${bucket}`);
        } catch (e) {
          console.log(`   ❌ Could not create bucket: ${e.message}`);
        }
      }
    }
  } catch (e) {
    console.log('❌ Could not check storage buckets');
  }

  console.log('\n📝 Migration check complete!');
  console.log('If you see ❌ above, you need to run the migrations.');
  console.log('\nTo get your service key:');
  console.log('1. Go to: https://supabase.com/dashboard/project/enukwrgrbbglxvllcjjn/settings/api');
  console.log('2. Copy the "service_role" key (starts with eyJ...)');
  console.log('3. Run: SUPABASE_SERVICE_KEY="your-key" node migrate.js');
}

// Check if service key is provided
if (SUPABASE_SERVICE_KEY === 'your-service-role-key-here') {
  console.error('❌ Please provide your Supabase service role key!');
  console.error('\nGet it from: https://supabase.com/dashboard/project/enukwrgrbbglxvllcjjn/settings/api');
  console.error('Look for "service_role" under Project API keys\n');
  console.error('Then run: SUPABASE_SERVICE_KEY="your-key" node migrate.js');
  process.exit(1);
}

runMigrations().catch(console.error);
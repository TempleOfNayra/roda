import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { persistSession: false } }
    )

    // Migration SQL statements
    const migrations = [
      {
        name: 'add_group_fields',
        sql: `
          ALTER TABLE groups 
          ADD COLUMN IF NOT EXISTS city TEXT DEFAULT 'Unknown City',
          ADD COLUMN IF NOT EXISTS teacher_title TEXT DEFAULT 'Professor',
          ADD COLUMN IF NOT EXISTS teacher_full_name TEXT DEFAULT 'Unknown Teacher',
          ADD COLUMN IF NOT EXISTS capoeira_style TEXT DEFAULT 'contemporanea',
          ADD COLUMN IF NOT EXISTS lineage TEXT,
          ADD COLUMN IF NOT EXISTS header_image_url TEXT,
          ADD COLUMN IF NOT EXISTS teacher_profile_picture TEXT,
          ADD COLUMN IF NOT EXISTS admin_ids TEXT[] DEFAULT '{}',
          ADD COLUMN IF NOT EXISTS teacher_ids TEXT[] DEFAULT '{}',
          ADD COLUMN IF NOT EXISTS member_ids TEXT[] DEFAULT '{}';
        `
      },
      {
        name: 'add_user_fields',
        sql: `
          ALTER TABLE users 
          ADD COLUMN IF NOT EXISTS teaching_group_ids TEXT[] DEFAULT '{}',
          ADD COLUMN IF NOT EXISTS joined_group_ids TEXT[] DEFAULT '{}',
          ADD COLUMN IF NOT EXISTS affiliation_group_id TEXT,
          ADD COLUMN IF NOT EXISTS group_id TEXT,
          ADD COLUMN IF NOT EXISTS group_name TEXT,
          ADD COLUMN IF NOT EXISTS teacher_name TEXT;
        `
      },
      {
        name: 'create_storage_buckets',
        sql: `
          INSERT INTO storage.buckets (id, name, public)
          VALUES 
            ('profile-pictures', 'profile-pictures', true),
            ('group-images', 'group-images', true),
            ('announcement-images', 'announcement-images', true)
          ON CONFLICT (id) DO NOTHING;
        `
      }
    ]

    const results = []
    
    for (const migration of migrations) {
      try {
        // Execute migration using raw SQL
        const { error } = await supabaseClient.rpc('exec_sql', { 
          sql: migration.sql 
        })
        
        if (error) {
          results.push({ name: migration.name, status: 'failed', error: error.message })
        } else {
          results.push({ name: migration.name, status: 'success' })
        }
      } catch (e) {
        results.push({ name: migration.name, status: 'failed', error: e.message })
      }
    }

    return new Response(
      JSON.stringify({ success: true, migrations: results }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    )
  }
})
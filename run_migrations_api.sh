#!/bin/bash

# Supabase Management API approach
SUPABASE_PROJECT_REF="enukwrgrbbglxvllcjjn"
SUPABASE_ACCESS_TOKEN="${SUPABASE_ACCESS_TOKEN:-your_access_token_here}"

# Function to run SQL via Management API
run_sql() {
    local sql="$1"
    
    curl -X POST \
        "https://api.supabase.com/v1/projects/${SUPABASE_PROJECT_REF}/database/query" \
        -H "Authorization: Bearer ${SUPABASE_ACCESS_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{\"query\": \"${sql}\"}"
}

echo "Running migrations via Supabase Management API..."

# Migration 1: Groups table
echo "Migrating groups table..."
run_sql "ALTER TABLE groups ADD COLUMN IF NOT EXISTS city TEXT DEFAULT 'Unknown City'"
run_sql "ALTER TABLE groups ADD COLUMN IF NOT EXISTS teacher_title TEXT DEFAULT 'Professor'"
run_sql "ALTER TABLE groups ADD COLUMN IF NOT EXISTS teacher_full_name TEXT DEFAULT 'Unknown Teacher'"
run_sql "ALTER TABLE groups ADD COLUMN IF NOT EXISTS capoeira_style TEXT DEFAULT 'contemporanea'"
run_sql "ALTER TABLE groups ADD COLUMN IF NOT EXISTS lineage TEXT"
run_sql "ALTER TABLE groups ADD COLUMN IF NOT EXISTS header_image_url TEXT"
run_sql "ALTER TABLE groups ADD COLUMN IF NOT EXISTS teacher_profile_picture TEXT"
run_sql "ALTER TABLE groups ADD COLUMN IF NOT EXISTS admin_ids TEXT[] DEFAULT '{}'"
run_sql "ALTER TABLE groups ADD COLUMN IF NOT EXISTS teacher_ids TEXT[] DEFAULT '{}'"
run_sql "ALTER TABLE groups ADD COLUMN IF NOT EXISTS member_ids TEXT[] DEFAULT '{}'"

# Migration 2: Users table
echo "Migrating users table..."
run_sql "ALTER TABLE users ADD COLUMN IF NOT EXISTS teaching_group_ids TEXT[] DEFAULT '{}'"
run_sql "ALTER TABLE users ADD COLUMN IF NOT EXISTS joined_group_ids TEXT[] DEFAULT '{}'"
run_sql "ALTER TABLE users ADD COLUMN IF NOT EXISTS affiliation_group_id TEXT"
run_sql "ALTER TABLE users ADD COLUMN IF NOT EXISTS group_id TEXT"
run_sql "ALTER TABLE users ADD COLUMN IF NOT EXISTS group_name TEXT"
run_sql "ALTER TABLE users ADD COLUMN IF NOT EXISTS teacher_name TEXT"

# Migration 3: Storage buckets
echo "Creating storage buckets..."
run_sql "INSERT INTO storage.buckets (id, name, public) VALUES ('profile-pictures', 'profile-pictures', true) ON CONFLICT (id) DO NOTHING"
run_sql "INSERT INTO storage.buckets (id, name, public) VALUES ('group-images', 'group-images', true) ON CONFLICT (id) DO NOTHING"
run_sql "INSERT INTO storage.buckets (id, name, public) VALUES ('announcement-images', 'announcement-images', true) ON CONFLICT (id) DO NOTHING"

echo "Migrations complete!"
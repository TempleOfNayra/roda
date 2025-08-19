#!/bin/bash

# Supabase project details
SUPABASE_URL="https://enukwrgrbbglxvllcjjn.supabase.co"
SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVudWt3cmdyYmJnbHh2bGxjampuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMzNDkxMzAsImV4cCI6MjA0ODkyNTEzMH0.1A5VqPQQnMQSvI-U25Y8yQ9y7OzVBkR6KT0jKYLpFa8"

echo "Testing connection to Supabase..."

# Test if we can connect
curl -X GET \
  "${SUPABASE_URL}/rest/v1/groups?limit=1" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_ANON_KEY}"

echo ""
echo "Note: Migrations need to be run via Supabase Dashboard SQL Editor"
echo "The migration files are in supabase/migrations/"
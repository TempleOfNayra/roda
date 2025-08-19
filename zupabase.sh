#!/bin/zsh
# Supabase environment variables (hard set)

export SUPABASE_DB_HOST="db.enukwrgrbbglxvllcjjn.supabase.co"
export SUPABASE_DB_PORT="5432"
export SUPABASE_DB_NAME="postgres"
export SUPABASE_DB_USER="postgres"
export SUPABASE_DB_PASSWORD="321MyRoda321!!!"
export SUPABASE_ACCESS_TOKEN="sbp_0a5876fcf0843045ca8dfc8500c78795645c2ed7"

echo "✅ Supabase env vars set (with hardcoded password)."
supabase link --project-ref enukwrgrbbglxvllcjjn

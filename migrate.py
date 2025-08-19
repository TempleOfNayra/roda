#!/usr/bin/env python3
import os
import sys
import psycopg2
from psycopg2 import sql

# Database connection details
DB_HOST = "db.enukwrgrbbglxvllcjjn.supabase.co"
DB_PORT = 5432
DB_NAME = "postgres"
DB_USER = "postgres"
DB_PASSWORD = os.environ.get('DB_PASSWORD', '')

if not DB_PASSWORD:
    print("❌ Please set DB_PASSWORD environment variable")
    print("Run: export DB_PASSWORD='your-database-password'")
    print("Get password from: https://supabase.com/dashboard/project/enukwrgrbbglxvllcjjn/settings/database")
    sys.exit(1)

def run_migrations():
    try:
        # Connect to database
        print("🔌 Connecting to database...")
        conn = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD
        )
        conn.autocommit = True
        cursor = conn.cursor()
        print("✅ Connected to database\n")

        # Migration 1: Groups table
        print("📦 Migrating groups table...")
        migrations = [
            "ALTER TABLE groups ADD COLUMN IF NOT EXISTS city TEXT DEFAULT 'Unknown City'",
            "ALTER TABLE groups ADD COLUMN IF NOT EXISTS teacher_title TEXT DEFAULT 'Professor'",
            "ALTER TABLE groups ADD COLUMN IF NOT EXISTS teacher_full_name TEXT DEFAULT 'Unknown Teacher'",
            "ALTER TABLE groups ADD COLUMN IF NOT EXISTS capoeira_style TEXT DEFAULT 'contemporanea'",
            "ALTER TABLE groups ADD COLUMN IF NOT EXISTS lineage TEXT",
            "ALTER TABLE groups ADD COLUMN IF NOT EXISTS header_image_url TEXT",
            "ALTER TABLE groups ADD COLUMN IF NOT EXISTS teacher_profile_picture TEXT",
            "ALTER TABLE groups ADD COLUMN IF NOT EXISTS admin_ids TEXT[] DEFAULT '{}'",
            "ALTER TABLE groups ADD COLUMN IF NOT EXISTS teacher_ids TEXT[] DEFAULT '{}'",
            "ALTER TABLE groups ADD COLUMN IF NOT EXISTS member_ids TEXT[] DEFAULT '{}'",
        ]
        
        for migration in migrations:
            try:
                cursor.execute(migration)
                print(f"  ✅ {migration.split('ADD COLUMN IF NOT EXISTS')[1].split(' ')[1]}")
            except Exception as e:
                print(f"  ⚠️  {e}")

        # Migration 2: Users table
        print("\n📦 Migrating users table...")
        user_migrations = [
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS teaching_group_ids TEXT[] DEFAULT '{}'",
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS joined_group_ids TEXT[] DEFAULT '{}'",
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS affiliation_group_id TEXT",
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS group_id TEXT",
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS group_name TEXT",
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS teacher_name TEXT",
        ]
        
        for migration in user_migrations:
            try:
                cursor.execute(migration)
                field = migration.split('ADD COLUMN IF NOT EXISTS')[1].split(' ')[1]
                print(f"  ✅ {field}")
            except Exception as e:
                print(f"  ⚠️  {e}")

        # Migration 3: Storage buckets
        print("\n📦 Creating storage buckets...")
        bucket_sql = """
            INSERT INTO storage.buckets (id, name, public)
            VALUES (%s, %s, %s)
            ON CONFLICT (id) DO NOTHING
        """
        buckets = [
            ('profile-pictures', 'profile-pictures', True),
            ('group-images', 'group-images', True),
            ('announcement-images', 'announcement-images', True),
        ]
        
        for bucket in buckets:
            try:
                cursor.execute(bucket_sql, bucket)
                print(f"  ✅ {bucket[0]}")
            except Exception as e:
                print(f"  ⚠️  {bucket[0]}: {e}")

        print("\n🎉 Migrations complete!")
        
        cursor.close()
        conn.close()
        
    except psycopg2.OperationalError as e:
        print(f"❌ Connection failed: {e}")
        print("\nMake sure:")
        print("1. Your password is correct")
        print("2. Get it from: https://supabase.com/dashboard/project/enukwrgrbbglxvllcjjn/settings/database")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    run_migrations()
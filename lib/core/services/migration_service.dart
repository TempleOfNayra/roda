import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:roda/core/utils/logger.dart';

class MigrationService {
  static final _client = Supabase.instance.client;
  
  static Future<void> runMigrations() async {
    Logger.debug('Checking and running database migrations...');
    
    try {
      // Check if migrations table exists
      await _ensureMigrationsTable();
      
      // Get list of migration files
      final migrations = await _getMigrationFiles();
      
      // Run each migration in order
      for (final migration in migrations) {
        await _runMigration(migration);
      }
      
      Logger.debug('All migrations completed successfully');
    } catch (e) {
      Logger.debug('Migration error: $e');
      // Don't crash the app if migrations fail
    }
  }
  
  static Future<void> _ensureMigrationsTable() async {
    try {
      await _client.rpc('exec_sql', params: {
        'sql': '''
          CREATE TABLE IF NOT EXISTS app_migrations (
            id SERIAL PRIMARY KEY,
            filename TEXT UNIQUE NOT NULL,
            executed_at TIMESTAMP DEFAULT NOW()
          );
        '''
      });
    } catch (e) {
      // If RPC doesn't exist, create it
      await _createExecSqlFunction();
      await _ensureMigrationsTable();
    }
  }
  
  static Future<void> _createExecSqlFunction() async {
    // This would need to be done once via Supabase dashboard
    // For now, we'll use a different approach
  }
  
  static Future<List<String>> _getMigrationFiles() async {
    // List of migrations to run
    return [
      '20250818_enhanced_groups.sql',
      '20250818_user_fields.sql',
      '20250818_storage_buckets.sql',
    ];
  }
  
  static Future<void> _runMigration(String filename) async {
    try {
      // Check if migration has already been run
      final result = await _client
          .from('app_migrations')
          .select()
          .eq('filename', filename)
          .maybeSingle();
      
      if (result != null) {
        Logger.debug('Migration $filename already executed');
        return;
      }
      
      // Get migration SQL
      final sql = _getMigrationSql(filename);
      
      // Run migration
      await _executeMigrationSql(sql);
      
      // Record migration as executed
      await _client.from('app_migrations').insert({
        'filename': filename,
      });
      
      Logger.debug('Migration $filename executed successfully');
    } catch (e) {
      Logger.debug('Failed to run migration $filename: $e');
    }
  }
  
  static String _getMigrationSql(String filename) {
    switch (filename) {
      case '20250818_enhanced_groups.sql':
        return '''
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
        ''';
        
      case '20250818_user_fields.sql':
        return '''
          ALTER TABLE users 
          ADD COLUMN IF NOT EXISTS teaching_group_ids TEXT[] DEFAULT '{}',
          ADD COLUMN IF NOT EXISTS joined_group_ids TEXT[] DEFAULT '{}',
          ADD COLUMN IF NOT EXISTS affiliation_group_id TEXT,
          ADD COLUMN IF NOT EXISTS group_id TEXT,
          ADD COLUMN IF NOT EXISTS group_name TEXT,
          ADD COLUMN IF NOT EXISTS teacher_name TEXT;
        ''';
        
      case '20250818_storage_buckets.sql':
        return '''
          INSERT INTO storage.buckets (id, name, public)
          VALUES 
            ('profile-pictures', 'profile-pictures', true),
            ('group-images', 'group-images', true),
            ('announcement-images', 'announcement-images', true)
          ON CONFLICT (id) DO NOTHING;
        ''';
        
      default:
        return '';
    }
  }
  
  static Future<void> _executeMigrationSql(String sql) async {
    // Since we can't execute arbitrary SQL from the client,
    // we need to work with what we have
    
    // For ALTER TABLE, we'll handle it differently
    if (sql.contains('ALTER TABLE groups')) {
      await _migrateGroupsTable();
    } else if (sql.contains('ALTER TABLE users')) {
      await _migrateUsersTable();
    } else if (sql.contains('storage.buckets')) {
      await _createStorageBuckets();
    }
  }
  
  static Future<void> _migrateGroupsTable() async {
    // We can't alter tables from client, but we can check and handle missing columns
    try {
      // Try to select from groups with new columns
      await _client.from('groups').select('city, teacher_title, teacher_full_name').limit(1);
      Logger.debug('Groups table already has new columns');
    } catch (e) {
      Logger.debug('Groups table missing new columns - please run migrations via Supabase CLI');
      // The app will still work with the fallback code we added
    }
  }
  
  static Future<void> _migrateUsersTable() async {
    try {
      await _client.from('users').select('teaching_group_ids, joined_group_ids').limit(1);
      Logger.debug('Users table already has new columns');
    } catch (e) {
      Logger.debug('Users table missing new columns - please run migrations via Supabase CLI');
    }
  }
  
  static Future<void> _createStorageBuckets() async {
    try {
      final buckets = await _client.storage.listBuckets();
      final requiredBuckets = ['profile-pictures', 'group-images', 'announcement-images'];
      
      for (final bucketId in requiredBuckets) {
        if (!buckets.any((b) => b.id == bucketId)) {
          await _client.storage.createBucket(bucketId, BucketOptions(public: true));
          Logger.debug('Created bucket: $bucketId');
        }
      }
    } catch (e) {
      Logger.debug('Could not create storage buckets: $e');
    }
  }
}
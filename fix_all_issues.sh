#!/bin/bash

# Fix all Flutter analyze issues

echo "Fixing Flutter analyze issues..."

# 1. Replace all print statements with Logger.debug in lib/ files
find lib -name "*.dart" -type f -exec sed -i '' "s/print(/Logger.debug(/g" {} \;

# 2. Add Logger import to files that use print (now Logger.debug)
for file in $(grep -l "Logger.debug" lib/**/*.dart 2>/dev/null); do
  if ! grep -q "import 'package:roda/core/utils/logger.dart';" "$file"; then
    # Add import after the first import statement
    sed -i '' "1,/^import /s/^import /import 'package:roda\/core\/utils\/logger.dart';\nimport /" "$file"
  fi
done

# 3. Fix deprecated withOpacity
find lib -name "*.dart" -type f -exec sed -i '' "s/\.withOpacity(/\.withValues(opacity: /g" {} \;

# 4. Fix deprecated textScaleFactor
find lib -name "*.dart" -type f -exec sed -i '' "s/textScaleFactor:/textScaler: TextScaler.linear(/g" {} \;
find lib -name "*.dart" -type f -exec sed -i '' "s/MediaQuery.of(context).textScaleFactor/MediaQuery.of(context).textScaler.scale(1.0)/g" {} \;

# 5. Remove print statements from test files
find test -name "*.dart" -type f -exec sed -i '' "/print(/d" {} \;
find . -name "test_*.dart" -type f -exec sed -i '' "/print(/d" {} \;

# 6. Fix unused variables in test files
sed -i '' "s/final groups = /final _ = /g" test_supabase_connection.dart 2>/dev/null
sed -i '' "s/final users = /final _ = /g" test_supabase_connection.dart 2>/dev/null
sed -i '' "s/final schedules = /final _ = /g" test_supabase_connection.dart 2>/dev/null
sed -i '' "s/final supabase = /final _ = /g" apply_text_migration.dart 2>/dev/null

# 7. Remove unused variables in providers
sed -i '' "/final startTime = /d" lib/features/teacher/providers/supabase_schedule_providers.dart 2>/dev/null
sed -i '' "/final endTime = /d" lib/features/teacher/providers/supabase_schedule_providers.dart 2>/dev/null

echo "Fixes applied. Running flutter analyze to check..."
flutter analyze
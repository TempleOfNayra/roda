import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:roda/core/config/supabase_config.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return SupabaseConfig.client;
});

final supabaseAuthClientProvider = Provider<GoTrueClient>((ref) {
  return ref.watch(supabaseClientProvider).auth;
});

// Unused - removed by DCM
// final supabaseStorageClientProvider = Provider<SupabaseStorageClient>((ref) {
//   return ref.watch(supabaseClientProvider).storage;
// });
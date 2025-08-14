import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:roda/core/routing/app_router.dart';
import 'package:roda/core/theme/app_theme.dart';

// Set to true to run in mock mode without real Firebase
const bool useMockMode = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (!useMockMode) {
    // Initialize Firebase with options
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  
  runApp(
    const ProviderScope(
      child: RodaApp(),
    ),
  );
}

class RodaApp extends ConsumerWidget {
  const RodaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    
    return MaterialApp.router(
      title: 'RODA',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.lightTheme,  // Use light theme for dark mode too
      themeMode: ThemeMode.light,  // Always use light theme
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
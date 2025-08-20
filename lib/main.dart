import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show WidgetsFlutterBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roda/core/routing/app_router.dart';
import 'package:roda/core/theme/roda_theme.dart';
import 'package:roda/core/config/supabase_config.dart';
import 'package:app_links/app_links.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Set to true to run in mock mode without real Firebase
const bool useMockMode = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Removed custom error handler - let Flutter handle errors normally
  
  // Initialize Supabase
  await SupabaseConfig.initialize();
  
  // Handle deep links for OAuth
  _handleDeepLinks();
  
  runApp(
    const ProviderScope(
      child: RodaApp(),
    ),
  );
}

void _handleDeepLinks() {
  final appLinks = AppLinks();
  
  // Handle initial link if app was launched from a deep link
  appLinks.getInitialLink().then((uri) {
    if (uri != null) {
      _handleDeepLink(uri);
    }
  });
  
  // Handle deep links when app is already running
  appLinks.uriLinkStream.listen((uri) {
    _handleDeepLink(uri);
  });
}

void _handleDeepLink(Uri uri) {
  // Let Supabase handle the OAuth callback
  if (uri.scheme == 'io.nayra.roda' && uri.host == 'login-callback') {
    Supabase.instance.client.auth.getSessionFromUrl(uri);
  }
}

class RodaApp extends ConsumerWidget {
  const RodaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    
    return CupertinoApp.router(
      title: 'RODA',
      theme: RodaTheme.theme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return child!;
      },
    );
  }
}
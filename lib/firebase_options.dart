// Mock Firebase configuration for local development
// Replace this with actual configuration when Firebase is set up

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAyUC95jPPbVE6aqTWIebeFDAHUCJ6wZ3Q',
    appId: '1:491672145228:web:2ca0a0d80c1103f619d3e9',
    messagingSenderId: '491672145228',
    projectId: 'roda-33c6f',
    authDomain: 'roda-33c6f.firebaseapp.com',
    storageBucket: 'roda-33c6f.firebasestorage.app',
  );

  // Mock configuration - these are dummy values

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD0RWCliozfGpgzQX-cJDFFHV224-bNwGY',
    appId: '1:491672145228:android:88d1fb0fd935d5d319d3e9',
    messagingSenderId: '491672145228',
    projectId: 'roda-33c6f',
    storageBucket: 'roda-33c6f.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA5kTisKeaWEybkosez-mfcwcGMRrCE9Tg',
    appId: '1:491672145228:ios:9f3805f82ace6c9c19d3e9',
    messagingSenderId: '491672145228',
    projectId: 'roda-33c6f',
    storageBucket: 'roda-33c6f.firebasestorage.app',
    iosClientId: '491672145228-7ejmlraviqqo1prcp72kk7o1to8e45i8.apps.googleusercontent.com',
    iosBundleId: 'io.nayra.roda',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'mock-api-key',
    appId: 'mock-app-id',
    messagingSenderId: 'mock-sender-id',
    projectId: 'mock-project-id',
    storageBucket: 'mock-project-id.appspot.com',
    iosBundleId: 'com.example.roda',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'mock-api-key',
    appId: 'mock-app-id',
    messagingSenderId: 'mock-sender-id',
    projectId: 'mock-project-id',
    storageBucket: 'mock-project-id.appspot.com',
  );
}
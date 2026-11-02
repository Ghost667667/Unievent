// Generated from android/app/google-services.json for project unievent-1ee62.
// Re-run `flutterfire configure` if you add iOS or change projects.

// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'iOS is not configured yet - run flutterfire configure',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAPUmSsvzJqwd4zRORZoGFbVArMgkYFCik',
    appId: '1:380622754913:web:bc450c8bee07e3a2e98620',
    messagingSenderId: '380622754913',
    projectId: 'unievent-1ee62',
    authDomain: 'unievent-1ee62.firebaseapp.com',
    storageBucket: 'unievent-1ee62.firebasestorage.app',
    measurementId: 'G-TFDJNQKRK1',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCVAZjzwmIx2kz8V5wXWMw-mK8BK-YslWg',
    appId: '1:380622754913:android:151d93c9ffe02bafe98620',
    messagingSenderId: '380622754913',
    projectId: 'unievent-1ee62',
    storageBucket: 'unievent-1ee62.firebasestorage.app',
  );
}

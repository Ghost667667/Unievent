import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'navigation/app_router.dart';
import 'services/app_services.dart';
import 'services/notification_service.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'viewmodels/auth_viewmodel.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Never leave the native (white) launch screen up: if Firebase cannot start
  // within a few seconds we show a readable error instead.
  Object? startupError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 15));

    // Offline persistence keeps event lists and the attendee list available
    // when the venue network drops (used by offline check-in).
    if (!kIsWeb) {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    }
  } catch (e, st) {
    startupError = e;
    debugPrint('Firebase startup failed: $e\n$st');
  }

  if (startupError != null) {
    runApp(_StartupErrorApp(error: startupError));
    return;
  }

  final services = AppServices.production();
  runApp(UniEventApp(services: services));

  // FCM permission / token work happens after the first frame so a missing
  // Google Play Services (common on emulators) can't block the UI.
  if (kIsWeb) return; // push notifications are mobile-only
  unawaited(
    services.notifications.init().timeout(
      const Duration(seconds: 10),
      onTimeout: () => debugPrint('FCM init timed out — continuing without push'),
    ),
  );
}

class UniEventApp extends StatefulWidget {
  const UniEventApp({super.key, required this.services});

  final AppServices services;

  @override
  State<UniEventApp> createState() => _UniEventAppState();
}

class _UniEventAppState extends State<UniEventApp> {
  late final AuthViewModel _auth = AuthViewModel(widget.services);
  late final router = buildRouter(_auth);

  @override
  void dispose() {
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppServices>.value(value: widget.services),
        ChangeNotifierProvider<AuthViewModel>.value(value: _auth),
      ],
      child: MaterialApp.router(
        title: 'UniEvent',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        routerConfig: router,
        builder: (context, child) {
          // Clamp extreme system font scaling so layouts stay usable.
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              textScaler: media.textScaler.clamp(
                minScaleFactor: 0.85,
                maxScaleFactor: 1.3,
              ),
            ),
            child: child!,
          );
        },
      ),
    );
  }
}

/// Shown only when Firebase itself could not initialise.
class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.cloud,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off, size: 56, color: AppColors.orange),
                const SizedBox(height: 16),
                const Text(
                  'UniEvent could not connect to Firebase',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Check that the device has internet access, that '
                  'google-services.json matches lib/firebase_options.dart, '
                  'and that the emulator image includes Google APIs.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$error',
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../repositories/user_repository.dart';

/// Background handler must be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firestore in-app notifications are written server-side; nothing to do.
  debugPrint('Background message: ${message.messageId}');
}

/// Firebase Cloud Messaging wrapper.
///
/// Push delivery is handled by the Cloud Function in `functions/src/index.ts`,
/// which fans out to the `fcmTokens` of affected users when an announcement,
/// waitlist promotion or Seat Rescue request is written. This service
/// registers the device token and surfaces foreground messages to the UI.
class NotificationService {
  NotificationService({
    FirebaseMessaging? messaging,
    required UserRepository users,
    this.enabled = true,
  })  : _messaging = messaging,
        _users = users;

  FirebaseMessaging? _messaging;
  final UserRepository _users;

  /// False in tests so no platform channel is touched.
  final bool enabled;

  FirebaseMessaging get _fcm => _messaging ??= FirebaseMessaging.instance;

  final StreamController<RemoteMessage> _foreground =
      StreamController<RemoteMessage>.broadcast();

  /// Messages received while the app is open, for showing a banner/snackbar.
  Stream<RemoteMessage> get foregroundMessages => _foreground.stream;

  String? _token;
  StreamSubscription<String>? _tokenSub;
  StreamSubscription<RemoteMessage>? _msgSub;

  Future<void> init() async {
    if (!enabled) return;
    try {
      await _fcm.requestPermission(alert: true, badge: true, sound: true);
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      _msgSub ??= FirebaseMessaging.onMessage.listen(_foreground.add);
    } catch (e) {
      debugPrint('FCM init skipped: $e');
    }
  }

  /// Stores the device token on the signed-in user's profile.
  Future<void> registerToken(String uid) async {
    if (!enabled) return;
    try {
      _token = await _fcm.getToken();
      if (_token != null) await _users.addFcmToken(uid, _token!);
      _tokenSub?.cancel();
      _tokenSub = _fcm.onTokenRefresh.listen((t) {
        _token = t;
        _users.addFcmToken(uid, t);
      });
      await _fcm.subscribeToTopic('all_users');
    } catch (e) {
      debugPrint('FCM token registration skipped: $e');
    }
  }

  Future<void> unregisterToken(String uid) async {
    if (!enabled) return;
    try {
      if (_token != null) await _users.removeFcmToken(uid, _token!);
      await _tokenSub?.cancel();
    } catch (_) {}
  }

  /// Writes an in-app notification for each recipient. The Cloud Function
  /// `onNotificationCreated` turns these into push messages.
  Future<void> notifyUsers(
    Iterable<String> uids, {
    required String title,
    required String body,
    String? eventId,
    String type = 'general',
  }) =>
      _users.pushNotificationToMany(
        uids,
        AppNotification(
          id: '',
          title: title,
          body: body,
          eventId: eventId,
          type: type,
        ),
      );

  void dispose() {
    _tokenSub?.cancel();
    _msgSub?.cancel();
    _foreground.close();
  }
}

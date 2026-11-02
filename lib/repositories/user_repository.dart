import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';

class UserRepository {
  UserRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');

  Stream<AppUser?> watch(String uid) =>
      _users.doc(uid).snapshots().map((d) => d.exists ? AppUser.fromDoc(d) : null);

  Future<AppUser?> get(String uid) async {
    final d = await _users.doc(uid).get();
    return d.exists ? AppUser.fromDoc(d) : null;
  }

  Future<void> update(String uid, Map<String, dynamic> fields) =>
      _users.doc(uid).update(fields);

  Future<void> toggleSavedEvent(String uid, String eventId, bool save) =>
      _users.doc(uid).update({
        'savedEventIds': save
            ? FieldValue.arrayUnion([eventId])
            : FieldValue.arrayRemove([eventId]),
      });

  Future<void> toggleFollowOrganiser(
    String uid,
    String organiserId,
    bool follow,
  ) =>
      _users.doc(uid).update({
        'followingOrganiserIds': follow
            ? FieldValue.arrayUnion([organiserId])
            : FieldValue.arrayRemove([organiserId]),
      });

  Future<void> addFcmToken(String uid, String token) =>
      _users.doc(uid).update({'fcmTokens': FieldValue.arrayUnion([token])});

  Future<void> removeFcmToken(String uid, String token) =>
      _users.doc(uid).update({'fcmTokens': FieldValue.arrayRemove([token])});

  /// Organisers listed for the Explore filter / follow feature.
  Stream<List<AppUser>> watchOrganisers() => _users
      .where('role', isEqualTo: UserRole.organiser.value)
      .snapshots()
      .map((s) => s.docs.map(AppUser.fromDoc).toList());

  /// Students following an organiser (for "new event" alerts).
  Future<List<String>> fetchFollowers(String organiserId) async {
    final snap = await _users
        .where('followingOrganiserIds', arrayContains: organiserId)
        .get();
    return snap.docs.map((d) => d.id).toList();
  }

  /// In-app notification inbox.
  Stream<List<AppNotification>> watchNotifications(String uid) => _users
      .doc(uid)
      .collection('notifications')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((s) => s.docs.map(AppNotification.fromDoc).toList());

  Stream<int> watchUnreadCount(String uid) => _users
      .doc(uid)
      .collection('notifications')
      .where('read', isEqualTo: false)
      .snapshots()
      .map((s) => s.docs.length);

  Future<void> markNotificationRead(String uid, String id) => _users
      .doc(uid)
      .collection('notifications')
      .doc(id)
      .update({'read': true});

  Future<void> pushNotification(String uid, AppNotification n) =>
      _users.doc(uid).collection('notifications').add(n.toMap());

  /// Writes the same notification to many users in batches of 400.
  Future<void> pushNotificationToMany(
    Iterable<String> uids,
    AppNotification n,
  ) async {
    final ids = uids.toSet().toList();
    for (var i = 0; i < ids.length; i += 400) {
      final batch = _db.batch();
      for (final uid in ids.skip(i).take(400)) {
        batch.set(
          _users.doc(uid).collection('notifications').doc(),
          n.toMap(),
        );
      }
      await batch.commit();
    }
  }
}

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A scan recorded while offline, waiting to be reconciled with Firestore.
class QueuedScan {
  const QueuedScan({
    required this.payload,
    required this.eventId,
    required this.scannedAt,
    required this.staffUid,
    this.registrationId,
  });

  final String payload;
  final String eventId;
  final DateTime scannedAt;
  final String staffUid;
  final String? registrationId;

  Map<String, dynamic> toJson() => {
        'payload': payload,
        'eventId': eventId,
        'scannedAt': scannedAt.toIso8601String(),
        'staffUid': staffUid,
        'registrationId': registrationId,
      };

  factory QueuedScan.fromJson(Map<String, dynamic> j) => QueuedScan(
        payload: j['payload'] as String,
        eventId: j['eventId'] as String,
        scannedAt: DateTime.parse(j['scannedAt'] as String),
        staffUid: j['staffUid'] as String,
        registrationId: j['registrationId'] as String?,
      );
}

/// Persists offline scans so check-in keeps working when the network or the
/// backend is down (System Proposal §2.3 "Offline-first check-in").
///
/// The queue is per event. On reconnect the CheckInViewModel replays each
/// scan through [RegistrationRepository.checkInByPayload], which decides the
/// final outcome (success / duplicate / invalid) against server records —
/// so if two phones scanned the same ticket offline, only the first replay
/// wins and the second is reported as a duplicate.
class OfflineCheckInQueue {
  OfflineCheckInQueue({SharedPreferences? prefs}) : _prefs = prefs;

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _store async =>
      _prefs ??= await SharedPreferences.getInstance();

  String _key(String eventId) => 'offline_scans_$eventId';

  Future<List<QueuedScan>> load(String eventId) async {
    final raw = (await _store).getStringList(_key(eventId)) ?? const [];
    return raw
        .map((s) => QueuedScan.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  Future<void> enqueue(QueuedScan scan) async {
    final list = await load(scan.eventId);
    // Avoid storing the exact same payload twice locally.
    if (list.any((q) => q.payload == scan.payload)) return;
    list.add(scan);
    await _save(scan.eventId, list);
  }

  Future<void> remove(String eventId, String payload) async {
    final list = await load(eventId);
    list.removeWhere((q) => q.payload == payload);
    await _save(eventId, list);
  }

  Future<void> clear(String eventId) async =>
      (await _store).remove(_key(eventId));

  Future<int> count(String eventId) async => (await load(eventId)).length;

  Future<void> _save(String eventId, List<QueuedScan> list) async {
    await (await _store).setStringList(
      _key(eventId),
      list.map((q) => jsonEncode(q.toJson())).toList(),
    );
  }
}

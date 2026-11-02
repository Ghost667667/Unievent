import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';

/// Filters applied on the Explore page.
class EventFilter {
  const EventFilter({
    this.query = '',
    this.category,
    this.date,
    this.venue,
    this.freeOnly,
    this.organiserId,
    this.acceptsVendors,
  });

  final String query;
  final String? category;
  final DateTime? date;
  final String? venue;

  /// true = free only, false = paid only, null = any
  final bool? freeOnly;
  final String? organiserId;
  final bool? acceptsVendors;

  EventFilter copyWith({
    String? query,
    String? category,
    DateTime? date,
    String? venue,
    bool? freeOnly,
    String? organiserId,
    bool? acceptsVendors,
    bool clearCategory = false,
    bool clearDate = false,
    bool clearVenue = false,
    bool clearFree = false,
    bool clearOrganiser = false,
  }) =>
      EventFilter(
        query: query ?? this.query,
        category: clearCategory ? null : (category ?? this.category),
        date: clearDate ? null : (date ?? this.date),
        venue: clearVenue ? null : (venue ?? this.venue),
        freeOnly: clearFree ? null : (freeOnly ?? this.freeOnly),
        organiserId: clearOrganiser ? null : (organiserId ?? this.organiserId),
        acceptsVendors: acceptsVendors ?? this.acceptsVendors,
      );

  bool get hasActiveFilters =>
      category != null ||
      date != null ||
      venue != null ||
      freeOnly != null ||
      organiserId != null;

  /// Client-side matching. Firestore can only apply one range filter per
  /// query, so the stream fetches upcoming events and we refine here.
  bool matches(Event e) {
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      if (!e.title.toLowerCase().contains(q) &&
          !e.venue.toLowerCase().contains(q) &&
          !e.organiserName.toLowerCase().contains(q) &&
          !e.category.toLowerCase().contains(q)) {
        return false;
      }
    }
    if (category != null && e.category != category) return false;
    if (date != null) {
      final d = date!;
      if (e.startTime.year != d.year ||
          e.startTime.month != d.month ||
          e.startTime.day != d.day) {
        return false;
      }
    }
    if (venue != null && !e.venue.toLowerCase().contains(venue!.toLowerCase())) {
      return false;
    }
    if (freeOnly == true && !e.isFree) return false;
    if (freeOnly == false && e.isFree) return false;
    if (organiserId != null && e.organiserId != organiserId) return false;
    if (acceptsVendors == true && !e.acceptsVendors) return false;
    return true;
  }
}

class EventRepository {
  EventRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _events =>
      _db.collection('events');

  Stream<Event?> watch(String id) =>
      _events.doc(id).snapshots().map((d) => d.exists ? Event.fromDoc(d) : null);

  Future<Event?> get(String id) async {
    final d = await _events.doc(id).get();
    return d.exists ? Event.fromDoc(d) : null;
  }

  /// Upcoming, non-cancelled events ordered by start time.
  Stream<List<Event>> watchUpcoming({int limit = 100}) => _events
      .where('endTime', isGreaterThan: Timestamp.now())
      .orderBy('endTime')
      .limit(limit)
      .snapshots()
      .map(
        (s) => s.docs
            .map(Event.fromDoc)
            .where((e) => e.status != EventStatus.cancelled)
            .toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime)),
      );

  /// Events accepting vendor applications.
  Stream<List<Event>> watchAcceptingVendors() => _events
      .where('acceptsVendors', isEqualTo: true)
      .where('endTime', isGreaterThan: Timestamp.now())
      .orderBy('endTime')
      .snapshots()
      .map(
        (s) => s.docs
            .map(Event.fromDoc)
            .where((e) => e.status != EventStatus.cancelled)
            .toList(),
      );

  Stream<List<Event>> watchByOrganiser(String organiserId) => _events
      .where('organiserId', isEqualTo: organiserId)
      .orderBy('startTime', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Event.fromDoc).toList());

  Future<List<Event>> fetchByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final result = <Event>[];
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.skip(i).take(10).toList();
      final snap =
          await _events.where(FieldPath.documentId, whereIn: chunk).get();
      result.addAll(snap.docs.map(Event.fromDoc));
    }
    return result;
  }

  /// Past events of the organiser in a category, for the show-up forecast.
  Future<List<(int, int)>> fetchHistory(
    String organiserId,
    String category,
  ) async {
    final snap = await _events
        .where('organiserId', isEqualTo: organiserId)
        .where('category', isEqualTo: category)
        .where('status', isEqualTo: EventStatus.ended.value)
        .limit(20)
        .get();
    return snap.docs
        .map(Event.fromDoc)
        .map((e) => (e.registeredCount, e.attendedCount))
        .toList();
  }

  Future<String> create(Event event) async {
    final ref = _events.doc();
    await ref.set(event.toMap());
    return ref.id;
  }

  Future<void> update(String id, Map<String, dynamic> fields) =>
      _events.doc(id).update(fields);

  Future<void> save(Event event) => _events.doc(event.id).set(event.toMap());

  Future<void> setStatus(String id, EventStatus status) =>
      _events.doc(id).update({'status': status.value});

  Future<void> cancel(String id) => setStatus(id, EventStatus.cancelled);
}

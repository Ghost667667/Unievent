import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';

/// Proposals (organiser ⇄ Student Affairs).
class ProposalRepository {
  ProposalRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('proposals');

  Stream<List<Proposal>> watchByOrganiser(String organiserId) => _col
      .where('organiserId', isEqualTo: organiserId)
      .snapshots()
      .map((s) => _sort(s.docs.map(Proposal.fromDoc)));

  /// Student Affairs queue: everything that is not a draft.
  Stream<List<Proposal>> watchForReview() => _col
      .where(
        'status',
        whereIn: [
          ProposalStatus.submitted.value,
          ProposalStatus.needsChanges.value,
          ProposalStatus.approved.value,
          ProposalStatus.rejected.value,
        ],
      )
      .snapshots()
      .map((s) => _sort(s.docs.map(Proposal.fromDoc)));

  List<Proposal> _sort(Iterable<Proposal> p) => p.toList()
    ..sort(
      (a, b) => (b.createdAt ?? DateTime(2000))
          .compareTo(a.createdAt ?? DateTime(2000)),
    );

  Future<String> create(Proposal p) async {
    final ref = _col.doc();
    await ref.set(p.toMap());
    return ref.id;
  }

  Future<void> save(Proposal p) => _col.doc(p.id).set(p.toMap());

  Future<void> submit(String id) => _col.doc(id).update({
        'status': ProposalStatus.submitted.value,
        'submittedAt': FieldValue.serverTimestamp(),
      });

  Future<void> review({
    required String id,
    required ProposalStatus status,
    required String reviewerUid,
    String? comment,
  }) =>
      _col.doc(id).update({
        'status': status.value,
        'reviewerComment': comment,
        'reviewedBy': reviewerUid,
        'reviewedAt': FieldValue.serverTimestamp(),
      });

  Future<void> linkEvent(String proposalId, String eventId) =>
      _col.doc(proposalId).update({'eventId': eventId});

  Future<void> delete(String id) => _col.doc(id).delete();
}

/// Vendor applications.
class VendorApplicationRepository {
  VendorApplicationRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('vendorApplications');

  Stream<List<VendorApplication>> watchByVendor(String vendorId) => _col
      .where('vendorId', isEqualTo: vendorId)
      .snapshots()
      .map((s) => s.docs.map(VendorApplication.fromDoc).toList());

  Stream<List<VendorApplication>> watchByEvent(String eventId) => _col
      .where('eventId', isEqualTo: eventId)
      .snapshots()
      .map((s) => s.docs.map(VendorApplication.fromDoc).toList());

  Stream<List<VendorApplication>> watchByOrganiser(String organiserId) => _col
      .where('organiserId', isEqualTo: organiserId)
      .snapshots()
      .map((s) => s.docs.map(VendorApplication.fromDoc).toList());

  /// Approved vendors shown on the student's Vendors tab.
  Stream<List<VendorApplication>> watchApprovedForEvent(String eventId) => _col
      .where('eventId', isEqualTo: eventId)
      .where('status', isEqualTo: ApplicationStatus.approved.value)
      .snapshots()
      .map((s) => s.docs.map(VendorApplication.fromDoc).toList());

  Future<void> apply(VendorApplication app) =>
      _col.doc(app.id).set(app.toMap());

  Future<void> review({
    required String id,
    required ApplicationStatus status,
    String? boothNumber,
    String? arrivalTime,
    String? parkingDetails,
    String? setupInstructions,
    String? note,
  }) =>
      _col.doc(id).update({
        'status': status.value,
        'boothNumber': boothNumber,
        'arrivalTime': arrivalTime,
        'parkingDetails': parkingDetails,
        'setupInstructions': setupInstructions,
        'organiserNote': note,
        'reviewedAt': FieldValue.serverTimestamp(),
      });

  Future<void> updateLogistics(String id, Map<String, dynamic> fields) =>
      _col.doc(id).update(fields);

  Future<void> vendorCheckIn(String id) =>
      _col.doc(id).update({'checkedInAt': FieldValue.serverTimestamp()});

  Future<void> withdraw(String id) => _col.doc(id).delete();
}

/// Crew tasks.
class TaskRepository {
  TaskRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;
  CollectionReference<Map<String, dynamic>> get _col => _db.collection('tasks');

  Stream<List<CrewTask>> watchByEvent(String eventId) => _col
      .where('eventId', isEqualTo: eventId)
      .snapshots()
      .map((s) => s.docs.map(CrewTask.fromDoc).toList());

  Future<void> add(CrewTask t) => _col.add(t.toMap());
  Future<void> setStatus(String id, TaskStatus s) =>
      _col.doc(id).update({'status': s.value});
  Future<void> delete(String id) => _col.doc(id).delete();
}

/// Budget lines.
class BudgetRepository {
  BudgetRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;
  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('budgets');

  Stream<List<BudgetLine>> watchByEvent(String eventId) => _col
      .where('eventId', isEqualTo: eventId)
      .snapshots()
      .map((s) => s.docs.map(BudgetLine.fromDoc).toList());

  Future<List<BudgetLine>> fetchByEvent(String eventId) async {
    final s = await _col.where('eventId', isEqualTo: eventId).get();
    return s.docs.map(BudgetLine.fromDoc).toList();
  }

  Future<void> add(BudgetLine b) => _col.add(b.toMap());
  Future<void> update(String id, Map<String, dynamic> f) =>
      _col.doc(id).update(f);
  Future<void> delete(String id) => _col.doc(id).delete();
}

/// Announcements.
class AnnouncementRepository {
  AnnouncementRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;
  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('announcements');

  Stream<List<Announcement>> watchByEvent(String eventId) => _col
      .where('eventId', isEqualTo: eventId)
      .snapshots()
      .map(
        (s) => s.docs.map(Announcement.fromDoc).toList()
          ..sort(
            (a, b) => (b.createdAt ?? DateTime(2000))
                .compareTo(a.createdAt ?? DateTime(2000)),
          ),
      );

  Future<String> add(Announcement a) async {
    final ref = _col.doc();
    await ref.set(a.toMap());
    return ref.id;
  }
}

/// Feedback.
class FeedbackRepository {
  FeedbackRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;
  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('feedback');

  Stream<EventFeedback?> watchMine(String eventId, String studentId) => _col
      .doc(EventFeedback.makeId(eventId, studentId))
      .snapshots()
      .map((d) => d.exists ? EventFeedback.fromDoc(d) : null);

  Stream<List<EventFeedback>> watchByEvent(String eventId) => _col
      .where('eventId', isEqualTo: eventId)
      .snapshots()
      .map((s) => s.docs.map(EventFeedback.fromDoc).toList());

  Future<List<EventFeedback>> fetchByEvent(String eventId) async {
    final s = await _col.where('eventId', isEqualTo: eventId).get();
    return s.docs.map(EventFeedback.fromDoc).toList();
  }

  Future<void> submit(EventFeedback f) => _col.doc(f.id).set(f.toMap());
}

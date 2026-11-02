import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import 'enums.dart';
import 'firestore_helpers.dart';

/// Crew task on the organiser task board. `tasks/{id}`.
class CrewTask extends Equatable {
  const CrewTask({
    required this.id,
    required this.eventId,
    required this.title,
    required this.owner,
    required this.status,
    this.dueDate,
    this.createdAt,
  });

  final String id;
  final String eventId;
  final String title;
  final String owner;
  final TaskStatus status;
  final DateTime? dueDate;
  final DateTime? createdAt;

  factory CrewTask.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return CrewTask(
      id: d.id,
      eventId: m['eventId'] as String? ?? '',
      title: m['title'] as String? ?? '',
      owner: m['owner'] as String? ?? '',
      status: TaskStatus.fromValue(m['status'] as String?),
      dueDate: tsToDate(m['dueDate']),
      createdAt: tsToDate(m['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'eventId': eventId,
        'title': title,
        'owner': owner,
        'status': status.value,
        'dueDate': dateToTs(dueDate),
        'createdAt': createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt!),
      };

  @override
  List<Object?> get props => [id, status];
}

/// Budget line. `budgets/{id}`.
class BudgetLine extends Equatable {
  const BudgetLine({
    required this.id,
    required this.eventId,
    required this.category,
    required this.description,
    required this.planned,
    required this.actual,
    this.receiptUrl,
    this.createdAt,
  });

  final String id;
  final String eventId;
  final String category;
  final String description;
  final double planned;
  final double actual;
  final String? receiptUrl;
  final DateTime? createdAt;

  double get variance => planned - actual;

  factory BudgetLine.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return BudgetLine(
      id: d.id,
      eventId: m['eventId'] as String? ?? '',
      category: m['category'] as String? ?? 'Other',
      description: m['description'] as String? ?? '',
      planned: toDouble(m['planned']),
      actual: toDouble(m['actual']),
      receiptUrl: m['receiptUrl'] as String?,
      createdAt: tsToDate(m['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'eventId': eventId,
        'category': category,
        'description': description,
        'planned': planned,
        'actual': actual,
        'receiptUrl': receiptUrl,
        'createdAt': createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt!),
      };

  @override
  List<Object?> get props => [id, planned, actual];
}

const List<String> kBudgetCategories = [
  'Venue',
  'Food & Beverage',
  'Marketing',
  'Equipment',
  'Speakers & Guests',
  'Prizes',
  'Logistics',
  'Other',
];

/// Organiser announcement. `announcements/{id}`.
class Announcement extends Equatable {
  const Announcement({
    required this.id,
    required this.eventId,
    required this.eventTitle,
    required this.organiserId,
    required this.type,
    required this.title,
    required this.body,
    this.notifyStudents = true,
    this.notifyVendors = true,
    this.createdAt,
  });

  final String id;
  final String eventId;
  final String eventTitle;
  final String organiserId;
  final AnnouncementType type;
  final String title;
  final String body;
  final bool notifyStudents;
  final bool notifyVendors;
  final DateTime? createdAt;

  factory Announcement.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Announcement(
      id: d.id,
      eventId: m['eventId'] as String? ?? '',
      eventTitle: m['eventTitle'] as String? ?? '',
      organiserId: m['organiserId'] as String? ?? '',
      type: AnnouncementType.fromValue(m['type'] as String?),
      title: m['title'] as String? ?? '',
      body: m['body'] as String? ?? '',
      notifyStudents: m['notifyStudents'] as bool? ?? true,
      notifyVendors: m['notifyVendors'] as bool? ?? true,
      createdAt: tsToDate(m['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'eventId': eventId,
        'eventTitle': eventTitle,
        'organiserId': organiserId,
        'type': type.value,
        'title': title,
        'body': body,
        'notifyStudents': notifyStudents,
        'notifyVendors': notifyVendors,
        'createdAt': createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt!),
      };

  @override
  List<Object?> get props => [id, title];
}

/// Post-event feedback. Doc id `${eventId}_${studentId}`. `feedback/{id}`.
class EventFeedback extends Equatable {
  const EventFeedback({
    required this.id,
    required this.eventId,
    required this.studentId,
    required this.eventRating,
    this.comment = '',
    this.vendorRatings = const {},
    this.createdAt,
  });

  final String id;
  final String eventId;
  final String studentId;
  final int eventRating;
  final String comment;

  /// vendorId → stars
  final Map<String, int> vendorRatings;
  final DateTime? createdAt;

  static String makeId(String eventId, String studentId) =>
      '${eventId}_$studentId';

  factory EventFeedback.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return EventFeedback(
      id: d.id,
      eventId: m['eventId'] as String? ?? '',
      studentId: m['studentId'] as String? ?? '',
      eventRating: toInt(m['eventRating']),
      comment: m['comment'] as String? ?? '',
      vendorRatings: Map<String, dynamic>.from(m['vendorRatings'] ?? {})
          .map((k, v) => MapEntry(k, toInt(v))),
      createdAt: tsToDate(m['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'eventId': eventId,
        'studentId': studentId,
        'eventRating': eventRating,
        'comment': comment,
        'vendorRatings': vendorRatings,
        'createdAt': createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt!),
      };

  @override
  List<Object?> get props => [id, eventRating];
}

/// In-app notification stored under `users/{uid}/notifications/{id}`.
class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.eventId,
    this.type = 'general',
    this.read = false,
    this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final String? eventId;
  final String type;
  final bool read;
  final DateTime? createdAt;

  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return AppNotification(
      id: d.id,
      title: m['title'] as String? ?? '',
      body: m['body'] as String? ?? '',
      eventId: m['eventId'] as String?,
      type: m['type'] as String? ?? 'general',
      read: m['read'] as bool? ?? false,
      createdAt: tsToDate(m['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'body': body,
        'eventId': eventId,
        'type': type,
        'read': read,
        'createdAt': FieldValue.serverTimestamp(),
      };

  @override
  List<Object?> get props => [id, read];
}

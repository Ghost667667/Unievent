import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import 'enums.dart';
import 'firestore_helpers.dart';

/// A student's registration for an event. Doc id is `${eventId}_${studentId}`
/// so a student can never hold two registrations for the same event.
class Registration extends Equatable {
  const Registration({
    required this.id,
    required this.eventId,
    required this.eventTitle,
    required this.studentId,
    required this.studentName,
    required this.studentTp,
    required this.status,
    required this.ticketCode,
    this.programme,
    this.confirmed = false,
    this.confirmationRequestedAt,
    this.waitlistPosition,
    this.checkedInAt,
    this.checkedInBy,
    this.isWalkIn = false,
    this.eventStartTime,
    this.venue,
    this.createdAt,
    this.cancelledAt,
  });

  final String id;
  final String eventId;
  final String eventTitle;
  final String studentId;
  final String studentName;
  final String studentTp;
  final String? programme;
  final RegistrationStatus status;

  /// Unique, unguessable code encoded in the QR ticket.
  final String ticketCode;

  /// Seat Rescue: did the student confirm attendance?
  final bool confirmed;
  final DateTime? confirmationRequestedAt;
  final int? waitlistPosition;
  final DateTime? checkedInAt;
  final String? checkedInBy;
  final bool isWalkIn;

  // Denormalised for the My Events list
  final DateTime? eventStartTime;
  final String? venue;
  final DateTime? createdAt;
  final DateTime? cancelledAt;

  bool get isActive =>
      status == RegistrationStatus.registered ||
      status == RegistrationStatus.waitlisted;

  static String makeId(String eventId, String studentId) =>
      '${eventId}_$studentId';

  factory Registration.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Registration.fromMap(doc.id, doc.data() ?? {});

  factory Registration.fromMap(String id, Map<String, dynamic> m) {
    return Registration(
      id: id,
      eventId: m['eventId'] as String? ?? '',
      eventTitle: m['eventTitle'] as String? ?? '',
      studentId: m['studentId'] as String? ?? '',
      studentName: m['studentName'] as String? ?? '',
      studentTp: m['studentTp'] as String? ?? '',
      programme: m['programme'] as String?,
      status: RegistrationStatus.fromValue(m['status'] as String?),
      ticketCode: m['ticketCode'] as String? ?? '',
      confirmed: m['confirmed'] as bool? ?? false,
      confirmationRequestedAt: tsToDate(m['confirmationRequestedAt']),
      waitlistPosition: (m['waitlistPosition'] as num?)?.toInt(),
      checkedInAt: tsToDate(m['checkedInAt']),
      checkedInBy: m['checkedInBy'] as String?,
      isWalkIn: m['isWalkIn'] as bool? ?? false,
      eventStartTime: tsToDate(m['eventStartTime']),
      venue: m['venue'] as String?,
      createdAt: tsToDate(m['createdAt']),
      cancelledAt: tsToDate(m['cancelledAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'eventId': eventId,
        'eventTitle': eventTitle,
        'studentId': studentId,
        'studentName': studentName,
        'studentNameLower': studentName.toLowerCase(),
        'studentTp': studentTp,
        'programme': programme,
        'status': status.value,
        'ticketCode': ticketCode,
        'confirmed': confirmed,
        'confirmationRequestedAt': dateToTs(confirmationRequestedAt),
        'waitlistPosition': waitlistPosition,
        'checkedInAt': dateToTs(checkedInAt),
        'checkedInBy': checkedInBy,
        'isWalkIn': isWalkIn,
        'eventStartTime': dateToTs(eventStartTime),
        'venue': venue,
        'createdAt': createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt!),
        'cancelledAt': dateToTs(cancelledAt),
      };

  Registration copyWith({
    RegistrationStatus? status,
    bool? confirmed,
    int? waitlistPosition,
    DateTime? checkedInAt,
    String? checkedInBy,
    DateTime? cancelledAt,
  }) {
    return Registration(
      id: id,
      eventId: eventId,
      eventTitle: eventTitle,
      studentId: studentId,
      studentName: studentName,
      studentTp: studentTp,
      programme: programme,
      status: status ?? this.status,
      ticketCode: ticketCode,
      confirmed: confirmed ?? this.confirmed,
      confirmationRequestedAt: confirmationRequestedAt,
      waitlistPosition: waitlistPosition ?? this.waitlistPosition,
      checkedInAt: checkedInAt ?? this.checkedInAt,
      checkedInBy: checkedInBy ?? this.checkedInBy,
      isWalkIn: isWalkIn,
      eventStartTime: eventStartTime,
      venue: venue,
      createdAt: createdAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
    );
  }

  @override
  List<Object?> get props => [id, status, confirmed, checkedInAt];
}

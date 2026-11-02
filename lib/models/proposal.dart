import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import 'enums.dart';
import 'firestore_helpers.dart';

/// Student Affairs event proposal. Stored in `proposals/{id}`.
class Proposal extends Equatable {
  const Proposal({
    required this.id,
    required this.organiserId,
    required this.organiserName,
    required this.organisationName,
    required this.eventTitle,
    required this.category,
    required this.description,
    required this.proposedDate,
    required this.venue,
    required this.expectedAttendance,
    required this.budgetEstimate,
    required this.status,
    this.objectives = '',
    this.needsVendors = false,
    this.reviewerComment,
    this.reviewedBy,
    this.reviewedAt,
    this.submittedAt,
    this.createdAt,
    this.eventId,
  });

  final String id;
  final String organiserId;
  final String organiserName;
  final String organisationName;
  final String eventTitle;
  final String category;
  final String description;
  final String objectives;
  final DateTime proposedDate;
  final String venue;
  final int expectedAttendance;
  final double budgetEstimate;
  final bool needsVendors;
  final ProposalStatus status;
  final String? reviewerComment;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime? submittedAt;
  final DateTime? createdAt;

  /// Set once the organiser creates the event from this proposal.
  final String? eventId;

  bool get canEdit =>
      status == ProposalStatus.draft || status == ProposalStatus.needsChanges;
  bool get canCreateEvent => status == ProposalStatus.approved && eventId == null;

  factory Proposal.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Proposal.fromMap(doc.id, doc.data() ?? {});

  factory Proposal.fromMap(String id, Map<String, dynamic> m) => Proposal(
        id: id,
        organiserId: m['organiserId'] as String? ?? '',
        organiserName: m['organiserName'] as String? ?? '',
        organisationName: m['organisationName'] as String? ?? '',
        eventTitle: m['eventTitle'] as String? ?? '',
        category: m['category'] as String? ?? 'Social',
        description: m['description'] as String? ?? '',
        objectives: m['objectives'] as String? ?? '',
        proposedDate: tsToDate(m['proposedDate']) ?? DateTime.now(),
        venue: m['venue'] as String? ?? '',
        expectedAttendance: toInt(m['expectedAttendance']),
        budgetEstimate: toDouble(m['budgetEstimate']),
        needsVendors: m['needsVendors'] as bool? ?? false,
        status: ProposalStatus.fromValue(m['status'] as String?),
        reviewerComment: m['reviewerComment'] as String?,
        reviewedBy: m['reviewedBy'] as String?,
        reviewedAt: tsToDate(m['reviewedAt']),
        submittedAt: tsToDate(m['submittedAt']),
        createdAt: tsToDate(m['createdAt']),
        eventId: m['eventId'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'organiserId': organiserId,
        'organiserName': organiserName,
        'organisationName': organisationName,
        'eventTitle': eventTitle,
        'category': category,
        'description': description,
        'objectives': objectives,
        'proposedDate': Timestamp.fromDate(proposedDate),
        'venue': venue,
        'expectedAttendance': expectedAttendance,
        'budgetEstimate': budgetEstimate,
        'needsVendors': needsVendors,
        'status': status.value,
        'reviewerComment': reviewerComment,
        'reviewedBy': reviewedBy,
        'reviewedAt': dateToTs(reviewedAt),
        'submittedAt': dateToTs(submittedAt),
        'createdAt': createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt!),
        'eventId': eventId,
      };

  Proposal copyWith({
    String? eventTitle,
    String? category,
    String? description,
    String? objectives,
    DateTime? proposedDate,
    String? venue,
    int? expectedAttendance,
    double? budgetEstimate,
    bool? needsVendors,
    ProposalStatus? status,
    String? reviewerComment,
    String? eventId,
  }) =>
      Proposal(
        id: id,
        organiserId: organiserId,
        organiserName: organiserName,
        organisationName: organisationName,
        eventTitle: eventTitle ?? this.eventTitle,
        category: category ?? this.category,
        description: description ?? this.description,
        objectives: objectives ?? this.objectives,
        proposedDate: proposedDate ?? this.proposedDate,
        venue: venue ?? this.venue,
        expectedAttendance: expectedAttendance ?? this.expectedAttendance,
        budgetEstimate: budgetEstimate ?? this.budgetEstimate,
        needsVendors: needsVendors ?? this.needsVendors,
        status: status ?? this.status,
        reviewerComment: reviewerComment ?? this.reviewerComment,
        reviewedBy: reviewedBy,
        reviewedAt: reviewedAt,
        submittedAt: submittedAt,
        createdAt: createdAt,
        eventId: eventId ?? this.eventId,
      );

  @override
  List<Object?> get props => [id, status, eventTitle];
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import 'enums.dart';
import 'firestore_helpers.dart';

/// A vendor's application to join an event. Doc id `${eventId}_${vendorId}`.
class VendorApplication extends Equatable {
  const VendorApplication({
    required this.id,
    required this.eventId,
    required this.eventTitle,
    required this.vendorId,
    required this.vendorName,
    required this.productCategory,
    required this.status,
    this.eventStartTime,
    this.organiserId = '',
    this.message = '',
    this.isStudentVendor = false,
    this.boothNumber,
    this.arrivalTime,
    this.parkingDetails,
    this.setupInstructions,
    this.organiserNote,
    this.checkedInAt,
    this.createdAt,
    this.reviewedAt,
  });

  final String id;
  final String eventId;
  final String eventTitle;
  final DateTime? eventStartTime;
  final String organiserId;
  final String vendorId;
  final String vendorName;
  final String productCategory;
  final String message;
  final bool isStudentVendor;
  final ApplicationStatus status;

  // Set by the organiser on approval
  final String? boothNumber;
  final String? arrivalTime;
  final String? parkingDetails;
  final String? setupInstructions;
  final String? organiserNote;
  final DateTime? checkedInAt;
  final DateTime? createdAt;
  final DateTime? reviewedAt;

  static String makeId(String eventId, String vendorId) => '${eventId}_$vendorId';

  factory VendorApplication.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) =>
      VendorApplication.fromMap(doc.id, doc.data() ?? {});

  factory VendorApplication.fromMap(String id, Map<String, dynamic> m) =>
      VendorApplication(
        id: id,
        eventId: m['eventId'] as String? ?? '',
        eventTitle: m['eventTitle'] as String? ?? '',
        eventStartTime: tsToDate(m['eventStartTime']),
        organiserId: m['organiserId'] as String? ?? '',
        vendorId: m['vendorId'] as String? ?? '',
        vendorName: m['vendorName'] as String? ?? '',
        productCategory: m['productCategory'] as String? ?? '',
        message: m['message'] as String? ?? '',
        isStudentVendor: m['isStudentVendor'] as bool? ?? false,
        status: ApplicationStatus.fromValue(m['status'] as String?),
        boothNumber: m['boothNumber'] as String?,
        arrivalTime: m['arrivalTime'] as String?,
        parkingDetails: m['parkingDetails'] as String?,
        setupInstructions: m['setupInstructions'] as String?,
        organiserNote: m['organiserNote'] as String?,
        checkedInAt: tsToDate(m['checkedInAt']),
        createdAt: tsToDate(m['createdAt']),
        reviewedAt: tsToDate(m['reviewedAt']),
      );

  Map<String, dynamic> toMap() => {
        'eventId': eventId,
        'eventTitle': eventTitle,
        'eventStartTime': dateToTs(eventStartTime),
        'organiserId': organiserId,
        'vendorId': vendorId,
        'vendorName': vendorName,
        'productCategory': productCategory,
        'message': message,
        'isStudentVendor': isStudentVendor,
        'status': status.value,
        'boothNumber': boothNumber,
        'arrivalTime': arrivalTime,
        'parkingDetails': parkingDetails,
        'setupInstructions': setupInstructions,
        'organiserNote': organiserNote,
        'checkedInAt': dateToTs(checkedInAt),
        'createdAt': createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt!),
        'reviewedAt': dateToTs(reviewedAt),
      };

  @override
  List<Object?> get props => [id, status, boothNumber];
}

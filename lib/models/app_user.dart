import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import 'enums.dart';

/// A UniEvent account. One document per Firebase Auth user in `users/{uid}`.
class AppUser extends Equatable {
  const AppUser({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.role,
    this.photoUrl,
    this.fcmTokens = const [],
    this.notificationsEnabled = true,
    this.reminderOneDay = true,
    this.reminderOneHour = true,
    this.createdAt,
    // Student
    this.studentId,
    this.programme,
    this.interests = const [],
    this.savedEventIds = const [],
    this.followingOrganiserIds = const [],
    // Organiser
    this.organisationName,
    this.position,
    // Vendor
    this.businessName,
    this.contactNumber,
    this.productCategory,
    this.isStudentVendor = false,
    this.eligibilityNotes,
    this.businessImageUrl,
  });

  final String uid;
  final String email;
  final String fullName;
  final UserRole role;
  final String? photoUrl;
  final List<String> fcmTokens;
  final bool notificationsEnabled;
  final bool reminderOneDay;
  final bool reminderOneHour;
  final DateTime? createdAt;

  // Student fields
  final String? studentId;
  final String? programme;
  final List<String> interests;
  final List<String> savedEventIds;
  final List<String> followingOrganiserIds;

  // Organiser fields
  final String? organisationName;
  final String? position;

  // Vendor fields
  final String? businessName;
  final String? contactNumber;
  final String? productCategory;

  /// APU policy: booths may currently only be run by students.
  final bool isStudentVendor;
  final String? eligibilityNotes;
  final String? businessImageUrl;

  String get displayName =>
      role == UserRole.vendor && (businessName?.isNotEmpty ?? false)
          ? businessName!
          : fullName;

  String get firstName => fullName.trim().split(' ').first;

  factory AppUser.fromMap(String uid, Map<String, dynamic> m) {
    return AppUser(
      uid: uid,
      email: m['email'] as String? ?? '',
      fullName: m['fullName'] as String? ?? '',
      role: UserRole.fromValue(m['role'] as String?),
      photoUrl: m['photoUrl'] as String?,
      fcmTokens: _strList(m['fcmTokens']),
      notificationsEnabled: m['notificationsEnabled'] as bool? ?? true,
      reminderOneDay: m['reminderOneDay'] as bool? ?? true,
      reminderOneHour: m['reminderOneHour'] as bool? ?? true,
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      studentId: m['studentId'] as String?,
      programme: m['programme'] as String?,
      interests: _strList(m['interests']),
      savedEventIds: _strList(m['savedEventIds']),
      followingOrganiserIds: _strList(m['followingOrganiserIds']),
      organisationName: m['organisationName'] as String?,
      position: m['position'] as String?,
      businessName: m['businessName'] as String?,
      contactNumber: m['contactNumber'] as String?,
      productCategory: m['productCategory'] as String?,
      isStudentVendor: m['isStudentVendor'] as bool? ?? false,
      eligibilityNotes: m['eligibilityNotes'] as String?,
      businessImageUrl: m['businessImageUrl'] as String?,
    );
  }

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      AppUser.fromMap(doc.id, doc.data() ?? {});

  Map<String, dynamic> toMap() => {
        'email': email,
        'fullName': fullName,
        'role': role.value,
        'photoUrl': photoUrl,
        'fcmTokens': fcmTokens,
        'notificationsEnabled': notificationsEnabled,
        'reminderOneDay': reminderOneDay,
        'reminderOneHour': reminderOneHour,
        'createdAt':
            createdAt == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(createdAt!),
        'studentId': studentId,
        'programme': programme,
        'interests': interests,
        'savedEventIds': savedEventIds,
        'followingOrganiserIds': followingOrganiserIds,
        'organisationName': organisationName,
        'position': position,
        'businessName': businessName,
        'contactNumber': contactNumber,
        'productCategory': productCategory,
        'isStudentVendor': isStudentVendor,
        'eligibilityNotes': eligibilityNotes,
        'businessImageUrl': businessImageUrl,
      };

  AppUser copyWith({
    String? fullName,
    String? photoUrl,
    bool? notificationsEnabled,
    bool? reminderOneDay,
    bool? reminderOneHour,
    String? studentId,
    String? programme,
    List<String>? interests,
    List<String>? savedEventIds,
    List<String>? followingOrganiserIds,
    String? organisationName,
    String? position,
    String? businessName,
    String? contactNumber,
    String? productCategory,
    bool? isStudentVendor,
    String? eligibilityNotes,
    String? businessImageUrl,
  }) {
    return AppUser(
      uid: uid,
      email: email,
      fullName: fullName ?? this.fullName,
      role: role,
      photoUrl: photoUrl ?? this.photoUrl,
      fcmTokens: fcmTokens,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      reminderOneDay: reminderOneDay ?? this.reminderOneDay,
      reminderOneHour: reminderOneHour ?? this.reminderOneHour,
      createdAt: createdAt,
      studentId: studentId ?? this.studentId,
      programme: programme ?? this.programme,
      interests: interests ?? this.interests,
      savedEventIds: savedEventIds ?? this.savedEventIds,
      followingOrganiserIds:
          followingOrganiserIds ?? this.followingOrganiserIds,
      organisationName: organisationName ?? this.organisationName,
      position: position ?? this.position,
      businessName: businessName ?? this.businessName,
      contactNumber: contactNumber ?? this.contactNumber,
      productCategory: productCategory ?? this.productCategory,
      isStudentVendor: isStudentVendor ?? this.isStudentVendor,
      eligibilityNotes: eligibilityNotes ?? this.eligibilityNotes,
      businessImageUrl: businessImageUrl ?? this.businessImageUrl,
    );
  }

  @override
  List<Object?> get props => [uid, email, fullName, role, photoUrl, studentId];
}

List<String> _strList(dynamic v) =>
    (v as List?)?.map((e) => e.toString()).toList() ?? const [];

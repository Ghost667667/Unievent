import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import 'enums.dart';

class EventSpeaker extends Equatable {
  const EventSpeaker({required this.name, this.title = '', this.photoUrl});
  final String name;
  final String title;
  final String? photoUrl;

  factory EventSpeaker.fromMap(Map<String, dynamic> m) => EventSpeaker(
        name: m['name'] as String? ?? '',
        title: m['title'] as String? ?? '',
        photoUrl: m['photoUrl'] as String?,
      );
  Map<String, dynamic> toMap() =>
      {'name': name, 'title': title, 'photoUrl': photoUrl};

  @override
  List<Object?> get props => [name, title];
}

class ScheduleItem extends Equatable {
  const ScheduleItem({
    required this.time,
    required this.title,
    this.description = '',
  });
  final String time;
  final String title;
  final String description;

  factory ScheduleItem.fromMap(Map<String, dynamic> m) => ScheduleItem(
        time: m['time'] as String? ?? '',
        title: m['title'] as String? ?? '',
        description: m['description'] as String? ?? '',
      );
  Map<String, dynamic> toMap() =>
      {'time': time, 'title': title, 'description': description};

  @override
  List<Object?> get props => [time, title];
}

/// A campus event. Stored in `events/{eventId}`.
class Event extends Equatable {
  const Event({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.organiserId,
    required this.organiserName,
    required this.startTime,
    required this.endTime,
    required this.venue,
    required this.capacity,
    this.proposalId,
    this.posterUrl,
    this.latitude,
    this.longitude,
    this.registeredCount = 0,
    this.confirmedCount = 0,
    this.waitlistCount = 0,
    this.attendedCount = 0,
    this.price = 0,
    this.status = EventStatus.upcoming,
    this.registrationDeadline,
    this.allowWalkIns = false,
    this.acceptsVendors = false,
    this.vendorFee = 0,
    this.vendorFacilities = const [],
    this.vendorRequirements = '',
    this.allowedProductCategories = const [],
    this.studentVendorsOnly = true,
    this.speakers = const [],
    this.schedule = const [],
    this.requirements = '',
    this.certificateOffered = false,
    this.photographyAllowed = true,
    this.format = 'Talk',
    this.seatRescueHoursBefore = 24,
    this.seatRescueDeadlineHours = 6,
    this.seatRescueSentAt,
    this.seatRescueReleasedAt,
    this.isOutdoor = false,
    this.createdAt,
  });

  final String id;
  final String title;
  final String description;
  final String category;
  final String organiserId;
  final String organiserName;
  final String? proposalId;
  final DateTime startTime;
  final DateTime endTime;
  final String venue;
  final double? latitude;
  final double? longitude;
  final String? posterUrl;
  final int capacity;
  final int registeredCount;
  final int confirmedCount;
  final int waitlistCount;
  final int attendedCount;

  /// Price in MYR; 0 means free.
  final double price;
  final EventStatus status;
  final DateTime? registrationDeadline;
  final bool allowWalkIns;

  // Vendor participation
  final bool acceptsVendors;
  final double vendorFee;
  final List<String> vendorFacilities;
  final String vendorRequirements;
  final List<String> allowedProductCategories;
  final bool studentVendorsOnly;

  // Details
  final List<EventSpeaker> speakers;
  final List<ScheduleItem> schedule;
  final String requirements;
  final bool certificateOffered;
  final bool photographyAllowed;
  final String format;

  // Seat Rescue
  final int seatRescueHoursBefore;
  final int seatRescueDeadlineHours;
  final DateTime? seatRescueSentAt;
  final DateTime? seatRescueReleasedAt;

  final bool isOutdoor;
  final DateTime? createdAt;

  bool get isFree => price <= 0;
  int get seatsLeft => (capacity - registeredCount).clamp(0, capacity).toInt();
  bool get isFull => registeredCount >= capacity;
  bool get isCancelled => status == EventStatus.cancelled;
  bool get hasEnded =>
      status == EventStatus.ended || DateTime.now().isAfter(endTime);
  bool get registrationOpen =>
      !isCancelled &&
      !hasEnded &&
      (registrationDeadline == null ||
          DateTime.now().isBefore(registrationDeadline!));
  bool get hasLocation => latitude != null && longitude != null;

  factory Event.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Event.fromMap(doc.id, doc.data() ?? {});

  factory Event.fromMap(String id, Map<String, dynamic> m) {
    return Event(
      id: id,
      title: m['title'] as String? ?? '',
      description: m['description'] as String? ?? '',
      category: m['category'] as String? ?? 'Social',
      organiserId: m['organiserId'] as String? ?? '',
      organiserName: m['organiserName'] as String? ?? '',
      proposalId: m['proposalId'] as String?,
      startTime: _ts(m['startTime']) ?? DateTime.now(),
      endTime: _ts(m['endTime']) ??
          (_ts(m['startTime']) ?? DateTime.now()).add(const Duration(hours: 2)),
      venue: m['venue'] as String? ?? '',
      latitude: (m['latitude'] as num?)?.toDouble(),
      longitude: (m['longitude'] as num?)?.toDouble(),
      posterUrl: m['posterUrl'] as String?,
      capacity: (m['capacity'] as num?)?.toInt() ?? 0,
      registeredCount: (m['registeredCount'] as num?)?.toInt() ?? 0,
      confirmedCount: (m['confirmedCount'] as num?)?.toInt() ?? 0,
      waitlistCount: (m['waitlistCount'] as num?)?.toInt() ?? 0,
      attendedCount: (m['attendedCount'] as num?)?.toInt() ?? 0,
      price: (m['price'] as num?)?.toDouble() ?? 0,
      status: EventStatus.fromValue(m['status'] as String?),
      registrationDeadline: _ts(m['registrationDeadline']),
      allowWalkIns: m['allowWalkIns'] as bool? ?? false,
      acceptsVendors: m['acceptsVendors'] as bool? ?? false,
      vendorFee: (m['vendorFee'] as num?)?.toDouble() ?? 0,
      vendorFacilities: _strList(m['vendorFacilities']),
      vendorRequirements: m['vendorRequirements'] as String? ?? '',
      allowedProductCategories: _strList(m['allowedProductCategories']),
      studentVendorsOnly: m['studentVendorsOnly'] as bool? ?? true,
      speakers: (m['speakers'] as List?)
              ?.map((e) => EventSpeaker.fromMap(Map<String, dynamic>.from(e)))
              .toList() ??
          const [],
      schedule: (m['schedule'] as List?)
              ?.map((e) => ScheduleItem.fromMap(Map<String, dynamic>.from(e)))
              .toList() ??
          const [],
      requirements: m['requirements'] as String? ?? '',
      certificateOffered: m['certificateOffered'] as bool? ?? false,
      photographyAllowed: m['photographyAllowed'] as bool? ?? true,
      format: m['format'] as String? ?? 'Talk',
      seatRescueHoursBefore: (m['seatRescueHoursBefore'] as num?)?.toInt() ?? 24,
      seatRescueDeadlineHours:
          (m['seatRescueDeadlineHours'] as num?)?.toInt() ?? 6,
      seatRescueSentAt: _ts(m['seatRescueSentAt']),
      seatRescueReleasedAt: _ts(m['seatRescueReleasedAt']),
      isOutdoor: m['isOutdoor'] as bool? ?? false,
      createdAt: _ts(m['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'titleLower': title.toLowerCase(),
        'description': description,
        'category': category,
        'organiserId': organiserId,
        'organiserName': organiserName,
        'proposalId': proposalId,
        'startTime': Timestamp.fromDate(startTime),
        'endTime': Timestamp.fromDate(endTime),
        'venue': venue,
        'latitude': latitude,
        'longitude': longitude,
        'posterUrl': posterUrl,
        'capacity': capacity,
        'registeredCount': registeredCount,
        'confirmedCount': confirmedCount,
        'waitlistCount': waitlistCount,
        'attendedCount': attendedCount,
        'price': price,
        'status': status.value,
        'registrationDeadline': registrationDeadline == null
            ? null
            : Timestamp.fromDate(registrationDeadline!),
        'allowWalkIns': allowWalkIns,
        'acceptsVendors': acceptsVendors,
        'vendorFee': vendorFee,
        'vendorFacilities': vendorFacilities,
        'vendorRequirements': vendorRequirements,
        'allowedProductCategories': allowedProductCategories,
        'studentVendorsOnly': studentVendorsOnly,
        'speakers': speakers.map((s) => s.toMap()).toList(),
        'schedule': schedule.map((s) => s.toMap()).toList(),
        'requirements': requirements,
        'certificateOffered': certificateOffered,
        'photographyAllowed': photographyAllowed,
        'format': format,
        'seatRescueHoursBefore': seatRescueHoursBefore,
        'seatRescueDeadlineHours': seatRescueDeadlineHours,
        'seatRescueSentAt':
            seatRescueSentAt == null ? null : Timestamp.fromDate(seatRescueSentAt!),
        'seatRescueReleasedAt': seatRescueReleasedAt == null
            ? null
            : Timestamp.fromDate(seatRescueReleasedAt!),
        'isOutdoor': isOutdoor,
        'createdAt': createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt!),
      };

  Event copyWith({
    String? title,
    String? description,
    String? category,
    DateTime? startTime,
    DateTime? endTime,
    String? venue,
    double? latitude,
    double? longitude,
    String? posterUrl,
    int? capacity,
    int? registeredCount,
    int? confirmedCount,
    int? waitlistCount,
    int? attendedCount,
    double? price,
    EventStatus? status,
    DateTime? registrationDeadline,
    bool? allowWalkIns,
    bool? acceptsVendors,
    double? vendorFee,
    List<String>? vendorFacilities,
    String? vendorRequirements,
    List<String>? allowedProductCategories,
    bool? studentVendorsOnly,
    List<EventSpeaker>? speakers,
    List<ScheduleItem>? schedule,
    String? requirements,
    bool? certificateOffered,
    bool? photographyAllowed,
    String? format,
    bool? isOutdoor,
  }) {
    return Event(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      organiserId: organiserId,
      organiserName: organiserName,
      proposalId: proposalId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      venue: venue ?? this.venue,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      posterUrl: posterUrl ?? this.posterUrl,
      capacity: capacity ?? this.capacity,
      registeredCount: registeredCount ?? this.registeredCount,
      confirmedCount: confirmedCount ?? this.confirmedCount,
      waitlistCount: waitlistCount ?? this.waitlistCount,
      attendedCount: attendedCount ?? this.attendedCount,
      price: price ?? this.price,
      status: status ?? this.status,
      registrationDeadline: registrationDeadline ?? this.registrationDeadline,
      allowWalkIns: allowWalkIns ?? this.allowWalkIns,
      acceptsVendors: acceptsVendors ?? this.acceptsVendors,
      vendorFee: vendorFee ?? this.vendorFee,
      vendorFacilities: vendorFacilities ?? this.vendorFacilities,
      vendorRequirements: vendorRequirements ?? this.vendorRequirements,
      allowedProductCategories:
          allowedProductCategories ?? this.allowedProductCategories,
      studentVendorsOnly: studentVendorsOnly ?? this.studentVendorsOnly,
      speakers: speakers ?? this.speakers,
      schedule: schedule ?? this.schedule,
      requirements: requirements ?? this.requirements,
      certificateOffered: certificateOffered ?? this.certificateOffered,
      photographyAllowed: photographyAllowed ?? this.photographyAllowed,
      format: format ?? this.format,
      seatRescueHoursBefore: seatRescueHoursBefore,
      seatRescueDeadlineHours: seatRescueDeadlineHours,
      seatRescueSentAt: seatRescueSentAt,
      seatRescueReleasedAt: seatRescueReleasedAt,
      isOutdoor: isOutdoor ?? this.isOutdoor,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props =>
      [id, title, startTime, capacity, registeredCount, status];
}

DateTime? _ts(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return null;
}

List<String> _strList(dynamic v) =>
    (v as List?)?.map((e) => e.toString()).toList() ?? const [];

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/registration_rules.dart';
import '../core/ticket_codec.dart';
import '../models/models.dart';

class RegistrationException implements Exception {
  RegistrationException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Result of a QR / manual check-in attempt.
enum CheckInResult { success, duplicate, invalid, wrongEvent, notRegistered }

class CheckInOutcome {
  const CheckInOutcome(this.result, {this.registration, this.message});
  final CheckInResult result;
  final Registration? registration;
  final String? message;
}

/// All registration, waitlist, Seat Rescue and check-in operations.
///
/// Every write that affects capacity runs inside a Firestore transaction so
/// two students tapping Register at the same moment can never over-book.
class RegistrationRepository {
  RegistrationRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _regs =>
      _db.collection('registrations');
  CollectionReference<Map<String, dynamic>> get _events =>
      _db.collection('events');

  // ───────────────────────── Student side ─────────────────────────

  Stream<Registration?> watchForStudent(String eventId, String studentId) =>
      _regs
          .doc(Registration.makeId(eventId, studentId))
          .snapshots()
          .map((d) => d.exists ? Registration.fromDoc(d) : null);

  Stream<List<Registration>> watchByStudent(String studentId) => _regs
      .where('studentId', isEqualTo: studentId)
      .snapshots()
      .map(
        (s) => s.docs.map(Registration.fromDoc).toList()
          ..sort((a, b) {
            final at = a.eventStartTime ?? DateTime(2100);
            final bt = b.eventStartTime ?? DateTime(2100);
            return at.compareTo(bt);
          }),
      );

  Stream<Registration?> watch(String registrationId) => _regs
      .doc(registrationId)
      .snapshots()
      .map((d) => d.exists ? Registration.fromDoc(d) : null);

  /// Registers the student or places them on the waitlist.
  /// Returns the resulting registration.
  Future<Registration> register({
    required Event event,
    required AppUser student,
  }) async {
    final regRef = _regs.doc(Registration.makeId(event.id, student.uid));
    final eventRef = _events.doc(event.id);

    return _db.runTransaction<Registration>((tx) async {
      final eventSnap = await tx.get(eventRef);
      if (!eventSnap.exists) {
        throw RegistrationException('This event no longer exists.');
      }
      final fresh = Event.fromDoc(eventSnap);
      final existingSnap = await tx.get(regRef);
      final existing =
          existingSnap.exists ? Registration.fromDoc(existingSnap) : null;

      final decision = RegistrationRules.decide(
        capacity: fresh.capacity,
        registeredCount: fresh.registeredCount,
        registrationOpen: fresh.registrationOpen,
        existingStatus: existing?.status,
      );

      switch (decision) {
        case RegistrationDecision.alreadyRegistered:
          throw RegistrationException(
            existing!.status == RegistrationStatus.waitlisted
                ? 'You are already on the waitlist.'
                : 'You are already registered for this event.',
          );
        case RegistrationDecision.closed:
          throw RegistrationException('Registration for this event is closed.');
        case RegistrationDecision.register:
        case RegistrationDecision.waitlist:
          final isWaitlist = decision == RegistrationDecision.waitlist;
          final reg = Registration(
            id: regRef.id,
            eventId: fresh.id,
            eventTitle: fresh.title,
            studentId: student.uid,
            studentName: student.fullName,
            studentTp: student.studentId ?? '',
            programme: student.programme,
            status: isWaitlist
                ? RegistrationStatus.waitlisted
                : RegistrationStatus.registered,
            ticketCode: TicketCodec.generateCode(),
            waitlistPosition: isWaitlist ? fresh.waitlistCount + 1 : null,
            eventStartTime: fresh.startTime,
            venue: fresh.venue,
            createdAt: DateTime.now(),
          );
          tx.set(regRef, reg.toMap());
          tx.update(eventRef, {
            if (isWaitlist)
              'waitlistCount': FieldValue.increment(1)
            else
              'registeredCount': FieldValue.increment(1),
          });
          return reg;
      }
    });
  }

  /// Cancels a registration and promotes the next waitlisted student.
  /// Returns the promoted registration, if any, so the caller can notify.
  Future<Registration?> cancel(Registration reg) async {
    final regRef = _regs.doc(reg.id);
    final eventRef = _events.doc(reg.eventId);

    // Look up the next waitlisted student *before* the transaction (queries
    // are not allowed inside transactions on mobile), then re-validate inside.
    Registration? candidate;
    if (reg.status == RegistrationStatus.registered) {
      candidate = await _nextWaitlisted(reg.eventId);
    }

    return _db.runTransaction<Registration?>((tx) async {
      // Firestore requires every read to happen before the first write.
      final regSnap = await tx.get(regRef);
      if (!regSnap.exists) throw RegistrationException('Registration not found.');
      final current = Registration.fromDoc(regSnap);
      if (!current.isActive) {
        throw RegistrationException('This registration is no longer active.');
      }
      final eventSnap = await tx.get(eventRef);
      final event = Event.fromDoc(eventSnap);
      Registration? cand;
      if (candidate != null && current.status == RegistrationStatus.registered) {
        final candSnap = await tx.get(_regs.doc(candidate.id));
        if (candSnap.exists) cand = Registration.fromDoc(candSnap);
      }

      tx.update(regRef, {
        'status': RegistrationStatus.cancelled.value,
        'cancelledAt': FieldValue.serverTimestamp(),
        'waitlistPosition': null,
      });

      if (current.status == RegistrationStatus.waitlisted) {
        tx.update(eventRef, {'waitlistCount': FieldValue.increment(-1)});
        return null;
      }

      // A registered seat was freed.
      var registeredDelta = -1;
      var waitlistDelta = 0;
      Registration? promoted;

      if (cand != null &&
          cand.status == RegistrationStatus.waitlisted &&
          event.registeredCount - 1 < event.capacity) {
        tx.update(_regs.doc(cand.id), {
          'status': RegistrationStatus.registered.value,
          'waitlistPosition': null,
          'promotedAt': FieldValue.serverTimestamp(),
        });
        promoted = cand.copyWith(status: RegistrationStatus.registered);
        registeredDelta += 1;
        waitlistDelta -= 1;
      }

      tx.update(eventRef, {
        'registeredCount': FieldValue.increment(registeredDelta),
        'waitlistCount': FieldValue.increment(waitlistDelta),
        if (current.confirmed) 'confirmedCount': FieldValue.increment(-1),
      });
      return promoted;
    });
  }

  Future<Registration?> _nextWaitlisted(String eventId) async {
    final snap = await _regs
        .where('eventId', isEqualTo: eventId)
        .where('status', isEqualTo: RegistrationStatus.waitlisted.value)
        .orderBy('createdAt')
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return Registration.fromDoc(snap.docs.first);
  }

  /// Seat Rescue: student confirms attendance.
  Future<void> confirmAttendance(Registration reg) async {
    if (reg.confirmed) return;
    final batch = _db.batch();
    batch.update(_regs.doc(reg.id), {
      'confirmed': true,
      'confirmedAt': FieldValue.serverTimestamp(),
    });
    batch.update(_events.doc(reg.eventId), {
      'confirmedCount': FieldValue.increment(1),
    });
    await batch.commit();
  }

  // ───────────────────────── Organiser side ─────────────────────────

  Stream<List<Registration>> watchByEvent(String eventId) => _regs
      .where('eventId', isEqualTo: eventId)
      .snapshots()
      .map(
        (s) => s.docs.map(Registration.fromDoc).toList()
          ..sort(
            (a, b) => (a.createdAt ?? DateTime(2000))
                .compareTo(b.createdAt ?? DateTime(2000)),
          ),
      );

  Future<List<Registration>> fetchByEvent(String eventId) async {
    final snap = await _regs.where('eventId', isEqualTo: eventId).get();
    return snap.docs.map(Registration.fromDoc).toList();
  }

  /// Validates a scanned QR payload and marks attendance. Runs in a
  /// transaction so two crew phones scanning the same ticket at once can't
  /// both succeed.
  Future<CheckInOutcome> checkInByPayload({
    required String payload,
    required String expectedEventId,
    required String staffUid,
    DateTime? scannedAt,
  }) async {
    final ticket = TicketCodec.decode(payload);
    if (ticket == null) {
      return const CheckInOutcome(
        CheckInResult.invalid,
        message: 'This QR code is not a UniEvent ticket.',
      );
    }
    if (ticket.eventId != expectedEventId) {
      return const CheckInOutcome(
        CheckInResult.wrongEvent,
        message: 'This ticket belongs to a different event.',
      );
    }
    return _checkIn(
      registrationId: ticket.registrationId,
      expectedCode: ticket.code,
      staffUid: staffUid,
      scannedAt: scannedAt,
    );
  }

  /// Manual check-in from the attendee list (no code verification needed —
  /// the organiser has identified the student by name / TP number).
  Future<CheckInOutcome> checkInManually({
    required Registration reg,
    required String staffUid,
  }) =>
      _checkIn(registrationId: reg.id, expectedCode: null, staffUid: staffUid);

  Future<CheckInOutcome> _checkIn({
    required String registrationId,
    required String? expectedCode,
    required String staffUid,
    DateTime? scannedAt,
  }) async {
    final regRef = _regs.doc(registrationId);
    return _db.runTransaction<CheckInOutcome>((tx) async {
      final snap = await tx.get(regRef);
      if (!snap.exists) {
        return const CheckInOutcome(
          CheckInResult.invalid,
          message: 'No registration matches this ticket.',
        );
      }
      final reg = Registration.fromDoc(snap);
      if (expectedCode != null && reg.ticketCode != expectedCode) {
        return const CheckInOutcome(
          CheckInResult.invalid,
          message: 'Ticket code does not match our records.',
        );
      }
      if (reg.status == RegistrationStatus.attended) {
        return CheckInOutcome(
          CheckInResult.duplicate,
          registration: reg,
          message: 'Already checked in',
        );
      }
      if (reg.status != RegistrationStatus.registered) {
        return CheckInOutcome(
          CheckInResult.notRegistered,
          registration: reg,
          message: reg.status == RegistrationStatus.waitlisted
              ? 'Student is on the waitlist, not registered.'
              : 'This registration was cancelled.',
        );
      }
      final at = scannedAt ?? DateTime.now();
      tx.update(regRef, {
        'status': RegistrationStatus.attended.value,
        'checkedInAt': Timestamp.fromDate(at),
        'checkedInBy': staffUid,
      });
      tx.update(_events.doc(reg.eventId), {
        'attendedCount': FieldValue.increment(1),
      });
      return CheckInOutcome(
        CheckInResult.success,
        registration: reg.copyWith(
          status: RegistrationStatus.attended,
          checkedInAt: at,
        ),
      );
    });
  }

  /// Registers a walk-in on the spot (only if seats remain) and checks them in.
  Future<Registration> registerWalkIn({
    required Event event,
    required String name,
    required String tpNumber,
    required String staffUid,
  }) async {
    final eventRef = _events.doc(event.id);
    final regRef = _regs.doc('${event.id}_walkin_${tpNumber.toUpperCase()}');
    return _db.runTransaction<Registration>((tx) async {
      final eSnap = await tx.get(eventRef);
      final fresh = Event.fromDoc(eSnap);
      if (!fresh.allowWalkIns) {
        throw RegistrationException('Walk-ins are disabled for this event.');
      }
      if (fresh.isFull) {
        throw RegistrationException('No seats left for walk-ins.');
      }
      final existing = await tx.get(regRef);
      if (existing.exists) {
        throw RegistrationException('This walk-in is already recorded.');
      }
      final reg = Registration(
        id: regRef.id,
        eventId: fresh.id,
        eventTitle: fresh.title,
        studentId: 'walkin_${tpNumber.toUpperCase()}',
        studentName: name,
        studentTp: tpNumber.toUpperCase(),
        status: RegistrationStatus.attended,
        ticketCode: TicketCodec.generateCode(),
        isWalkIn: true,
        checkedInAt: DateTime.now(),
        checkedInBy: staffUid,
        eventStartTime: fresh.startTime,
        venue: fresh.venue,
        createdAt: DateTime.now(),
      );
      tx.set(regRef, reg.toMap());
      tx.update(eventRef, {
        'registeredCount': FieldValue.increment(1),
        'attendedCount': FieldValue.increment(1),
      });
      return reg;
    });
  }

  // ───────────────────────── Seat Rescue ─────────────────────────

  /// Marks every registered, unconfirmed student as "confirmation requested"
  /// and stamps the event. Returns the affected registrations so the caller
  /// can send notifications.
  Future<List<Registration>> sendConfirmationRequests(Event event) async {
    final regs = await fetchByEvent(event.id);
    final targets = regs
        .where((r) => r.status == RegistrationStatus.registered && !r.confirmed)
        .toList();
    final batch = _db.batch();
    for (final r in targets) {
      batch.update(_regs.doc(r.id), {
        'confirmationRequestedAt': FieldValue.serverTimestamp(),
      });
    }
    batch.update(_events.doc(event.id), {
      'seatRescueSentAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return targets;
  }

  /// Releases seats of students who never confirmed and promotes waitlisted
  /// students into them. Returns (released, promoted).
  Future<(List<Registration>, List<Registration>)> releaseUnconfirmedSeats(
    Event event,
  ) async {
    final regs = await fetchByEvent(event.id);
    final unconfirmed = regs
        .where(
          (r) =>
              r.status == RegistrationStatus.registered &&
              !r.confirmed &&
              r.confirmationRequestedAt != null,
        )
        .toList();
    final waitlisted = regs
        .where((r) => r.status == RegistrationStatus.waitlisted)
        .toList()
      ..sort(
        (a, b) => (a.createdAt ?? DateTime(2000))
            .compareTo(b.createdAt ?? DateTime(2000)),
      );

    final freed = unconfirmed.length;
    final toPromote = RegistrationRules.seatsToPromote(
      capacity: event.capacity,
      registeredCount: event.registeredCount - freed,
      waitlistCount: waitlisted.length,
    );
    final promoted = waitlisted.take(toPromote).toList();

    final batch = _db.batch();
    for (final r in unconfirmed) {
      batch.update(_regs.doc(r.id), {
        'status': RegistrationStatus.cancelled.value,
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledReason': 'seat_rescue_unconfirmed',
      });
    }
    for (final r in promoted) {
      batch.update(_regs.doc(r.id), {
        'status': RegistrationStatus.registered.value,
        'waitlistPosition': null,
        'promotedAt': FieldValue.serverTimestamp(),
      });
    }
    batch.update(_events.doc(event.id), {
      'registeredCount': FieldValue.increment(-freed + promoted.length),
      'waitlistCount': FieldValue.increment(-promoted.length),
      'seatRescueReleasedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return (unconfirmed, promoted);
  }
}

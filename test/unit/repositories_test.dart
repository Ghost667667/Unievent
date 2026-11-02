import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unievent/core/ticket_codec.dart';
import 'package:unievent/models/models.dart';
import 'package:unievent/repositories/order_repository.dart';
import 'package:unievent/repositories/product_repository.dart';
import 'package:unievent/repositories/registration_repository.dart';

AppUser student(String id) => AppUser(
      uid: id,
      email: '$id@mail.apu.edu.my',
      fullName: 'Student $id',
      role: UserRole.student,
      studentId: 'TP0000$id',
      programme: 'BSc CS',
    );

Event event({int capacity = 2}) => Event(
      id: 'ev1',
      title: 'Test Event',
      description: '',
      category: 'Technical',
      organiserId: 'org1',
      organiserName: 'Org',
      startTime: DateTime.now().add(const Duration(days: 3)),
      endTime: DateTime.now().add(const Duration(days: 3, hours: 2)),
      venue: 'Hall',
      capacity: capacity,
    );

void main() {
  late FakeFirebaseFirestore db;
  late RegistrationRepository regs;

  setUp(() async {
    db = FakeFirebaseFirestore();
    regs = RegistrationRepository(firestore: db);
    await db.collection('events').doc('ev1').set(event().toMap());
  });

  Future<Event> freshEvent() async => Event.fromDoc(await db.collection('events').doc('ev1').get());

  group('Registration capacity & waitlist', () {
    test('fills seats then waitlists, promoting on cancel', () async {
      final r1 = await regs.register(event: await freshEvent(), student: student('a'));
      final r2 = await regs.register(event: await freshEvent(), student: student('b'));
      final r3 = await regs.register(event: await freshEvent(), student: student('c'));

      expect(r1.status, RegistrationStatus.registered);
      expect(r2.status, RegistrationStatus.registered);
      expect(r3.status, RegistrationStatus.waitlisted);
      expect(r3.waitlistPosition, 1);

      var e = await freshEvent();
      expect(e.registeredCount, 2);
      expect(e.waitlistCount, 1);
      expect(e.isFull, isTrue);

      // Cancelling a registered seat promotes the waitlisted student.
      final promoted = await regs.cancel(r1);
      expect(promoted, isNotNull);
      expect(promoted!.studentId, 'c');

      e = await freshEvent();
      expect(e.registeredCount, 2);
      expect(e.waitlistCount, 0);

      final cDoc = Registration.fromDoc(await db.collection('registrations').doc(r3.id).get());
      expect(cDoc.status, RegistrationStatus.registered);
    });

    test('rejects duplicate registration', () async {
      await regs.register(event: await freshEvent(), student: student('a'));
      expect(
        () async => regs.register(event: await freshEvent(), student: student('a')),
        throwsA(isA<RegistrationException>()),
      );
    });

    test('rejects registration when closed', () async {
      await db.collection('events').doc('ev1').update({'status': EventStatus.cancelled.value});
      expect(
        () async => regs.register(event: await freshEvent(), student: student('a')),
        throwsA(isA<RegistrationException>()),
      );
    });

    test('each registration has a unique ticket code', () async {
      final r1 = await regs.register(event: await freshEvent(), student: student('a'));
      final r2 = await regs.register(event: await freshEvent(), student: student('b'));
      expect(r1.ticketCode, isNot(r2.ticketCode));
      expect(r1.ticketCode.length, TicketCodec.codeLength);
    });
  });

  group('QR check-in', () {
    test('valid ticket checks in once; second scan is a duplicate', () async {
      final r = await regs.register(event: await freshEvent(), student: student('a'));
      final payload = TicketCodec.encode(eventId: 'ev1', registrationId: r.id, code: r.ticketCode);

      final first = await regs.checkInByPayload(payload: payload, expectedEventId: 'ev1', staffUid: 'staff');
      expect(first.result, CheckInResult.success);

      final second = await regs.checkInByPayload(payload: payload, expectedEventId: 'ev1', staffUid: 'staff');
      expect(second.result, CheckInResult.duplicate);

      final e = await freshEvent();
      expect(e.attendedCount, 1);
    });

    test('rejects tampered codes, wrong events and foreign QR', () async {
      final r = await regs.register(event: await freshEvent(), student: student('a'));
      final tampered = TicketCodec.encode(eventId: 'ev1', registrationId: r.id, code: 'AAAAAAAAAAAAAAAA');
      expect((await regs.checkInByPayload(payload: tampered, expectedEventId: 'ev1', staffUid: 's')).result, CheckInResult.invalid);

      final good = TicketCodec.encode(eventId: 'ev1', registrationId: r.id, code: r.ticketCode);
      expect((await regs.checkInByPayload(payload: good, expectedEventId: 'ev2', staffUid: 's')).result, CheckInResult.wrongEvent);
      expect((await regs.checkInByPayload(payload: 'https://evil', expectedEventId: 'ev1', staffUid: 's')).result, CheckInResult.invalid);
    });

    test('waitlisted ticket cannot check in', () async {
      await regs.register(event: await freshEvent(), student: student('a'));
      await regs.register(event: await freshEvent(), student: student('b'));
      final w = await regs.register(event: await freshEvent(), student: student('c'));
      final payload = TicketCodec.encode(eventId: 'ev1', registrationId: w.id, code: w.ticketCode);
      final res = await regs.checkInByPayload(payload: payload, expectedEventId: 'ev1', staffUid: 's');
      expect(res.result, CheckInResult.notRegistered);
    });

    test('walk-in requires permission and seats', () async {
      expect(
        () async => regs.registerWalkIn(event: await freshEvent(), name: 'W', tpNumber: 'TP999999', staffUid: 's'),
        throwsA(isA<RegistrationException>()),
      );
      await db.collection('events').doc('ev1').update({'allowWalkIns': true});
      final w = await regs.registerWalkIn(event: await freshEvent(), name: 'W', tpNumber: 'TP999999', staffUid: 's');
      expect(w.status, RegistrationStatus.attended);
      expect(w.isWalkIn, isTrue);
    });
  });

  group('Seat Rescue', () {
    test('releases unconfirmed seats and promotes waitlist', () async {
      final a = await regs.register(event: await freshEvent(), student: student('a'));
      final b = await regs.register(event: await freshEvent(), student: student('b'));
      await regs.register(event: await freshEvent(), student: student('c')); // waitlisted
      await regs.confirmAttendance(a);

      final targets = await regs.sendConfirmationRequests(await freshEvent());
      expect(targets.map((r) => r.studentId), ['b']);

      final (released, promoted) = await regs.releaseUnconfirmedSeats(await freshEvent());
      expect(released.map((r) => r.id), [b.id]);
      expect(promoted.map((r) => r.studentId), ['c']);

      final e = await freshEvent();
      expect(e.registeredCount, 2);
      expect(e.waitlistCount, 0);
      expect(e.seatRescueReleasedAt, isNotNull);
    });
  });

  group('Orders & inventory', () {
    late OrderRepository orders;
    late ProductRepository products;

    setUp(() async {
      orders = OrderRepository(firestore: db);
      products = ProductRepository(firestore: db);
      await db.collection('products').doc('p1').set(
            const Product(id: 'p1', vendorId: 'v1', vendorName: 'Stall', name: 'Wrap', price: 10, quantity: 2).toMap(),
          );
    });

    test('placing an order deducts stock transactionally and never goes negative', () async {
      final o = await orders.placeOrder(
        event: await freshEvent(),
        student: student('a'),
        vendorId: 'v1',
        vendorName: 'Stall',
        quantities: {'p1': 2},
        paymentReference: 'SBX-1',
      );
      expect(o.total, 20);
      expect(o.status, OrderStatus.pending);
      var p = Product.fromDoc(await db.collection('products').doc('p1').get());
      expect(p.quantity, 0);
      expect(p.soldCount, 2);

      expect(
        () => orders.placeOrder(
          event: event(),
          student: student('b'),
          vendorId: 'v1',
          vendorName: 'Stall',
          quantities: {'p1': 1},
          paymentReference: 'SBX-2',
        ),
        throwsA(isA<OrderException>()),
      );

      // Cancelling restores stock.
      await orders.cancel(o, byStudent: true);
      p = Product.fromDoc(await db.collection('products').doc('p1').get());
      expect(p.quantity, 2);
      final list = await products.fetchByVendor('v1');
      expect(list.single.soldCount, 0);
    });

    test('status advances along the pipeline and student cancel is blocked after pending', () async {
      final o = await orders.placeOrder(
        event: await freshEvent(),
        student: student('a'),
        vendorId: 'v1',
        vendorName: 'Stall',
        quantities: {'p1': 1},
        paymentReference: 'SBX-1',
      );
      await orders.advance(o);
      var doc = VendorOrder.fromDoc(await db.collection('orders').doc(o.id).get());
      expect(doc.status, OrderStatus.preparing);

      expect(() => orders.cancel(doc, byStudent: true), throwsA(isA<OrderException>()));

      await orders.advance(doc);
      doc = VendorOrder.fromDoc(await db.collection('orders').doc(o.id).get());
      expect(doc.status, OrderStatus.ready);
      expect(() => orders.cancel(doc, byStudent: false), throwsA(isA<OrderException>()));

      await orders.advance(doc);
      doc = VendorOrder.fromDoc(await db.collection('orders').doc(o.id).get());
      expect(doc.status, OrderStatus.collected);
      expect(() => orders.advance(doc), throwsA(isA<OrderException>()));
    });
  });

  test('Timestamp round-trip in models', () {
    final e = event();
    final map = e.toMap();
    expect(map['startTime'], isA<Timestamp>());
    final back = Event.fromMap('ev1', map..['createdAt'] = Timestamp.now());
    expect(back.title, e.title);
    expect(back.capacity, e.capacity);
  });
}

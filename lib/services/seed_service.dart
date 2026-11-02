import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';

/// Writes realistic sample data so the three dashboards have something to
/// show on a fresh Firebase project. Triggered from Profile → "Load sample
/// data" (organiser and vendor accounts). Safe to run more than once: sample
/// documents use deterministic ids and are overwritten.
class SeedService {
  SeedService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const _posters = [
    'https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=1200',
    'https://images.unsplash.com/photo-1523580494863-6f3031224c94?w=1200',
    'https://images.unsplash.com/photo-1515187029135-18ee286d815b?w=1200',
    'https://images.unsplash.com/photo-1511578314322-379afb476865?w=1200',
    'https://images.unsplash.com/photo-1461896836934-ffe607ba8211?w=1200',
    'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=1200',
  ];

  Future<int> seedForOrganiser(AppUser organiser) async {
    final now = DateTime.now();
    final org = organiser.organisationName ?? 'APU Student Council';
    final batch = _db.batch();

    final events = <Event>[
      Event(
        id: 'sample_${organiser.uid}_africa_day',
        title: 'Africa Day Cultural Night',
        description:
            'An evening of music, dance, fashion and food celebrating the '
            'cultures of Africa. Open to all APU students. Dress code: '
            'traditional or smart casual.',
        category: 'Cultural',
        organiserId: organiser.uid,
        organiserName: org,
        startTime: DateTime(now.year, now.month, now.day + 9, 19),
        endTime: DateTime(now.year, now.month, now.day + 9, 22, 30),
        venue: 'APU Auditorium 1, Level 2',
        latitude: 2.9218,
        longitude: 101.6565,
        posterUrl: _posters[0],
        capacity: 300,
        registeredCount: 0,
        price: 0,
        acceptsVendors: true,
        vendorFee: 50,
        vendorFacilities: const ['Table & 2 chairs', 'Power socket', 'Lighting'],
        vendorRequirements:
            'Student-run booths only (APU policy). Food vendors must hold a '
            'valid food-handling certificate.',
        allowedProductCategories: const ['Food', 'Beverages', 'Crafts', 'Merchandise'],
        speakers: const [
          EventSpeaker(name: 'Dr. Amina Yusuf', title: 'Guest of Honour'),
        ],
        schedule: const [
          ScheduleItem(time: '7:00 PM', title: 'Doors open & vendor fair'),
          ScheduleItem(time: '7:45 PM', title: 'Opening dance performance'),
          ScheduleItem(time: '8:30 PM', title: 'Fashion show'),
          ScheduleItem(time: '9:30 PM', title: 'Live band & closing'),
        ],
        requirements: 'Bring your APU student card.',
        certificateOffered: false,
        format: 'Social',
        registrationDeadline: DateTime(now.year, now.month, now.day + 8, 23, 59),
        allowWalkIns: true,
      ),
      Event(
        id: 'sample_${organiser.uid}_tedx',
        title: 'TEDxAPU 2026: Ideas in Motion',
        description:
            'Eight speakers, one stage. Talks on technology, sustainability '
            'and student life, followed by a networking session.',
        category: 'Career',
        organiserId: organiser.uid,
        organiserName: org,
        startTime: DateTime(now.year, now.month, now.day + 16, 10),
        endTime: DateTime(now.year, now.month, now.day + 16, 16),
        venue: 'APU Auditorium 2',
        latitude: 2.9221,
        longitude: 101.6562,
        posterUrl: _posters[1],
        capacity: 150,
        price: 15,
        acceptsVendors: true,
        vendorFee: 0,
        vendorFacilities: const ['Table', 'Power socket'],
        allowedProductCategories: const ['Beverages', 'Snacks'],
        speakers: const [
          EventSpeaker(name: 'Hamza Rahim', title: 'Founder, GreenGrid'),
          EventSpeaker(name: 'Priscilla Tan', title: 'UX Lead, Grab'),
        ],
        schedule: const [
          ScheduleItem(time: '10:00 AM', title: 'Registration & coffee'),
          ScheduleItem(time: '10:30 AM', title: 'Session 1 — Technology'),
          ScheduleItem(time: '1:00 PM', title: 'Lunch break'),
          ScheduleItem(time: '2:00 PM', title: 'Session 2 — Sustainability'),
        ],
        certificateOffered: true,
        format: 'Talk',
        registrationDeadline: DateTime(now.year, now.month, now.day + 14),
      ),
      Event(
        id: 'sample_${organiser.uid}_hackathon',
        title: 'APU Hack 48: Campus Solutions',
        description:
            '48-hour hackathon. Build something that improves life at APU. '
            'Teams of 2–4. Prizes worth RM 5,000.',
        category: 'Technical',
        organiserId: organiser.uid,
        organiserName: org,
        startTime: DateTime(now.year, now.month, now.day + 23, 9),
        endTime: DateTime(now.year, now.month, now.day + 25, 9),
        venue: 'Tech Lab 6-01',
        posterUrl: _posters[2],
        capacity: 20,
        price: 0,
        requirements: 'Laptop, charger and a GitHub account.',
        certificateOffered: true,
        format: 'Hands-on',
        speakers: const [],
      ),
      Event(
        id: 'sample_${organiser.uid}_sports',
        title: 'Inter-School Sports Day',
        description: 'Futsal, badminton, and track events. Cheer for your school!',
        category: 'Sports',
        organiserId: organiser.uid,
        organiserName: org,
        startTime: DateTime(now.year, now.month, now.day + 5, 8),
        endTime: DateTime(now.year, now.month, now.day + 5, 17),
        venue: 'APU Sports Field',
        latitude: 2.9205,
        longitude: 101.6580,
        posterUrl: _posters[4],
        capacity: 400,
        price: 0,
        isOutdoor: true,
        acceptsVendors: true,
        vendorFee: 30,
        vendorFacilities: const ['Canopy', 'Table'],
        allowedProductCategories: const ['Food', 'Beverages', 'Snacks'],
        format: 'Social',
        allowWalkIns: true,
      ),
      Event(
        id: 'sample_${organiser.uid}_arabic_night',
        title: 'Arabic Nights 2026',
        description: 'Poetry, calligraphy, oud music and a feast.',
        category: 'Cultural',
        organiserId: organiser.uid,
        organiserName: org,
        startTime: DateTime(now.year, now.month, now.day - 20, 19),
        endTime: DateTime(now.year, now.month, now.day - 20, 22),
        venue: 'APU Auditorium 1',
        posterUrl: _posters[3],
        capacity: 250,
        registeredCount: 238,
        attendedCount: 171,
        confirmedCount: 180,
        price: 0,
        status: EventStatus.ended,
        format: 'Social',
      ),
      Event(
        id: 'sample_${organiser.uid}_career_fair',
        title: 'Spring Career Fair',
        description: '40 employers on campus. Bring your CV.',
        category: 'Career',
        organiserId: organiser.uid,
        organiserName: org,
        startTime: DateTime(now.year, now.month, now.day - 45, 10),
        endTime: DateTime(now.year, now.month, now.day - 45, 16),
        venue: 'APU Atrium',
        posterUrl: _posters[5],
        capacity: 500,
        registeredCount: 412,
        attendedCount: 356,
        confirmedCount: 370,
        price: 0,
        status: EventStatus.ended,
        format: 'Social',
      ),
    ];

    // Events must be committed before tasks/budgets/announcements, because
    // the security rules verify event ownership with get() on each write.
    for (final e in events) {
      batch.set(_db.collection('events').doc(e.id), e.toMap());
    }
    await batch.commit();
    final batch2 = _db.batch();

    // One proposal awaiting Student Affairs review and one draft. (Rules only
    // let Student Affairs set a proposal to Approved.)
    final p1 = Proposal(
      id: 'sample_${organiser.uid}_proposal_africa',
      organiserId: organiser.uid,
      organiserName: organiser.fullName,
      organisationName: org,
      eventTitle: 'Africa Day Cultural Night',
      category: 'Cultural',
      description: events[0].description,
      objectives: 'Celebrate diversity; raise RM 2,000 for the welfare fund.',
      proposedDate: events[0].startTime,
      venue: events[0].venue,
      expectedAttendance: 300,
      budgetEstimate: 4500,
      needsVendors: true,
      status: ProposalStatus.submitted,
      submittedAt: now,
    );
    final p2 = Proposal(
      id: 'sample_${organiser.uid}_proposal_talent',
      organiserId: organiser.uid,
      organiserName: organiser.fullName,
      organisationName: org,
      eventTitle: 'APU Talent Show',
      category: 'Creative',
      description: 'An open-mic talent show for all schools.',
      proposedDate: DateTime(now.year, now.month + 1, 15, 19),
      venue: 'APU Auditorium 1',
      expectedAttendance: 200,
      budgetEstimate: 1800,
      status: ProposalStatus.draft,
    );
    batch2.set(_db.collection('proposals').doc(p1.id), p1.toMap());
    batch2.set(_db.collection('proposals').doc(p2.id), p2.toMap());

    // Budget for Africa Day.
    final budget = [
      ('Venue', 'Auditorium booking & AV', 800.0, 800.0),
      ('Food & Beverage', 'Catering deposit', 1500.0, 1650.0),
      ('Marketing', 'Posters & social ads', 300.0, 240.0),
      ('Equipment', 'Lighting rental', 600.0, 0.0),
      ('Prizes', 'Fashion show prizes', 400.0, 0.0),
    ];
    for (var i = 0; i < budget.length; i++) {
      final b = budget[i];
      batch2.set(
        _db.collection('budgets').doc('sample_${organiser.uid}_budget_$i'),
        BudgetLine(
          id: '',
          eventId: events[0].id,
          category: b.$1,
          description: b.$2,
          planned: b.$3,
          actual: b.$4,
        ).toMap(),
      );
    }

    // Crew tasks.
    final tasks = [
      ('Confirm sound check with AV team', 'Leila', TaskStatus.done),
      ('Print 300 wristbands', 'Yunis', TaskStatus.inProgress),
      ('Brief vendors on arrival slots', 'Massa', TaskStatus.todo),
      ('Set up registration desk at 6 PM', 'Crew A', TaskStatus.todo),
    ];
    for (var i = 0; i < tasks.length; i++) {
      final t = tasks[i];
      batch2.set(
        _db.collection('tasks').doc('sample_${organiser.uid}_task_$i'),
        CrewTask(
          id: '',
          eventId: events[0].id,
          title: t.$1,
          owner: t.$2,
          status: t.$3,
        ).toMap(),
      );
    }

    // One announcement.
    batch2.set(
      _db.collection('announcements').doc('sample_${organiser.uid}_ann_1'),
      Announcement(
        id: '',
        eventId: events[0].id,
        eventTitle: events[0].title,
        organiserId: organiser.uid,
        type: AnnouncementType.general,
        title: 'Vendor fair opens at 7 PM',
        body: 'Come early — the vendor fair in the foyer opens 45 minutes '
            'before the show. Pre-order from the Vendors tab to skip the queue.',
      ).toMap(),
    );

    await batch2.commit();
    return events.length;
  }

  Future<int> seedForVendor(AppUser vendor) async {
    final name = vendor.businessName ?? vendor.fullName;
    final batch = _db.batch();
    final products = [
      ('Chicken Shawarma Wrap', 'Food', 9.5, 40, 'Grilled chicken, garlic sauce, pickles.'),
      ('Falafel Bowl (V)', 'Food', 8.0, 25, 'Crispy falafel with hummus and salad.'),
      ('Mango Lassi', 'Beverages', 5.0, 30, 'Chilled, made fresh.'),
      ('Iced Teh Tarik', 'Beverages', 3.5, 60, ''),
      ('Baklava (3 pcs)', 'Snacks', 6.0, 4, 'Pistachio & honey.'),
      ('UniEvent Tote Bag', 'Merchandise', 18.0, 0, 'Limited edition canvas tote.'),
    ];
    for (var i = 0; i < products.length; i++) {
      final p = products[i];
      batch.set(
        _db.collection('products').doc('sample_${vendor.uid}_product_$i'),
        Product(
          id: '',
          vendorId: vendor.uid,
          vendorName: name,
          name: p.$1,
          category: p.$2,
          price: p.$3,
          quantity: p.$4,
          description: p.$5,
          imageUrl:
              'https://picsum.photos/seed/unievent_${vendor.uid.hashCode + i}/600/400',
        ).toMap(),
      );
    }
    await batch.commit();
    return products.length;
  }
}

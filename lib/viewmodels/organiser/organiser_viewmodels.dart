import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../../core/registration_rules.dart';
import '../../models/models.dart';
import '../../repositories/registration_repository.dart';
import '../../services/app_services.dart';
import '../../services/offline_checkin_queue.dart';
import '../../services/report_service.dart';
import '../student/student_viewmodels.dart' show BaseViewModel;

/// Organiser Home + Events tab: the organiser's events, proposals and the
/// headline stats for the "current" (next upcoming) event.
class OrganiserDashboardViewModel extends BaseViewModel {
  OrganiserDashboardViewModel(this._services, this.organiser) {
    _eventsSub = _services.events.watchByOrganiser(organiser.uid).listen((e) {
      _events = e;
      _refreshForecast();
      safeNotify();
    });
    _proposalsSub = _services.proposals.watchByOrganiser(organiser.uid).listen((p) {
      _proposals = p;
      safeNotify();
    });
  }

  final AppServices _services;
  final AppUser organiser;
  StreamSubscription? _eventsSub;
  StreamSubscription? _proposalsSub;

  List<Event>? _events;
  List<Proposal>? _proposals;
  int? _forecast;

  bool get loading => _events == null || _proposals == null;
  List<Event> get events => _events ?? const [];
  List<Proposal> get proposals => _proposals ?? const [];

  List<Event> get upcoming => events
      .where((e) => !e.hasEnded && !e.isCancelled)
      .toList()
    ..sort((a, b) => a.startTime.compareTo(b.startTime));
  List<Event> get past => events.where((e) => e.hasEnded || e.isCancelled).toList();

  /// The event shown in the dashboard header.
  Event? get currentEvent => upcoming.isEmpty ? null : upcoming.first;
  int? get forecast => _forecast;

  Future<void> _refreshForecast() async {
    final e = currentEvent;
    if (e == null) {
      _forecast = null;
      return;
    }
    final history = await _services.events.fetchHistory(organiser.uid, e.category);
    final rate = ShowUpForecast.showUpRate(history: history, isFree: e.isFree);
    _forecast = ShowUpForecast.forecast(
      registeredCount: e.registeredCount,
      confirmedCount: e.confirmedCount,
      showUpRate: rate,
    );
    safeNotify();
  }

  Future<bool> cancelEvent(Event e, String reason) async {
    final ok = await run(() async {
      await _services.events.cancel(e.id);
      await _services.announcements.add(
        Announcement(
          id: '',
          eventId: e.id,
          eventTitle: e.title,
          organiserId: organiser.uid,
          type: AnnouncementType.cancellation,
          title: 'Event cancelled',
          body: reason,
        ),
      );
      final regs = await _services.registrations.fetchByEvent(e.id);
      await _services.notifications.notifyUsers(
        regs.where((r) => r.isActive).map((r) => r.studentId),
        title: '${e.title} has been cancelled',
        body: reason,
        eventId: e.id,
        type: 'announcement',
      );
    });
    return ok;
  }

  Future<bool> submitProposal(Proposal p) async {
    final ok = await run(() => _services.proposals.submit(p.id));
    return ok;
  }

  Future<bool> deleteProposal(Proposal p) async {
    final ok = await run(() => _services.proposals.delete(p.id));
    return ok;
  }

  Future<int> loadSampleData() async {
    final n = await guard(() => _services.seed.seedForOrganiser(organiser));
    return n ?? 0;
  }

  @override
  void dispose() {
    _eventsSub?.cancel();
    _proposalsSub?.cancel();
    super.dispose();
  }
}

/// Everything about one event for the organiser: registrations, tasks,
/// vendors, announcements, Seat Rescue, status changes.
class EventManageViewModel extends BaseViewModel {
  EventManageViewModel(this._services, this.organiser, this.eventId) {
    _eventSub = _services.events.watch(eventId).listen((e) {
      _event = e;
      _loaded = true;
      _refreshForecast();
      safeNotify();
    });
    _regSub = _services.registrations.watchByEvent(eventId).listen((r) {
      _registrations = r;
      safeNotify();
    });
    _taskSub = _services.tasks.watchByEvent(eventId).listen((t) {
      _tasks = t;
      safeNotify();
    });
    _vendorSub = _services.vendorApplications.watchByEvent(eventId).listen((v) {
      _vendorApps = v;
      safeNotify();
    });
  }

  final AppServices _services;
  final AppUser organiser;
  final String eventId;

  StreamSubscription? _eventSub;
  StreamSubscription? _regSub;
  StreamSubscription? _taskSub;
  StreamSubscription? _vendorSub;

  Event? _event;
  bool _loaded = false;
  List<Registration> _registrations = const [];
  List<CrewTask> _tasks = const [];
  List<VendorApplication> _vendorApps = const [];
  int? _forecast;
  double? _showUpRate;

  Event? get event => _event;
  bool get loaded => _loaded;
  List<Registration> get registrations => _registrations;
  List<CrewTask> get tasks => _tasks;
  List<VendorApplication> get vendorApplications => _vendorApps;
  int? get forecast => _forecast;
  double? get showUpRate => _showUpRate;

  List<Registration> get registered =>
      _registrations.where((r) => r.status == RegistrationStatus.registered).toList();
  List<Registration> get confirmed => registered.where((r) => r.confirmed).toList();
  List<Registration> get waitlisted => _registrations
      .where((r) => r.status == RegistrationStatus.waitlisted)
      .toList()
    ..sort((a, b) => (a.waitlistPosition ?? 999).compareTo(b.waitlistPosition ?? 999));
  List<Registration> get attended =>
      _registrations.where((r) => r.status == RegistrationStatus.attended).toList();
  List<Registration> get cancelled =>
      _registrations.where((r) => r.status == RegistrationStatus.cancelled).toList();

  bool get seatRescueSent => _event?.seatRescueSentAt != null;
  bool get seatRescueReleased => _event?.seatRescueReleasedAt != null;

  /// Manual trigger is allowed any time before the event (the scheduled
  /// Cloud Function applies the 24h window automatically).
  bool get canSendSeatRescue {
    final e = _event;
    if (e == null) return false;
    return !seatRescueSent && !e.hasEnded && !e.isCancelled;
  }

  /// True once the automatic 24h window has opened (shown as a hint).
  bool get seatRescueWindowOpen {
    final e = _event;
    if (e == null) return false;
    return RegistrationRules.shouldSendConfirmationRequests(
      now: DateTime.now(),
      eventStart: e.startTime,
      hoursBefore: e.seatRescueHoursBefore,
      alreadySentAt: e.seatRescueSentAt,
    );
  }

  bool get canReleaseSeats {
    final e = _event;
    if (e == null) return false;
    return seatRescueSent && !seatRescueReleased && !e.hasEnded;
  }

  Future<void> _refreshForecast() async {
    final e = _event;
    if (e == null) return;
    final history = await _services.events.fetchHistory(organiser.uid, e.category);
    _showUpRate = ShowUpForecast.showUpRate(history: history, isFree: e.isFree);
    _forecast = ShowUpForecast.forecast(
      registeredCount: e.registeredCount,
      confirmedCount: e.confirmedCount,
      showUpRate: _showUpRate!,
    );
    safeNotify();
  }

  Future<bool> setStatus(EventStatus s) async {
    final ok = await run(() => _services.events.setStatus(eventId, s));
    return ok;
  }

  /// Cancels the event, posts a cancellation announcement and notifies every
  /// active registrant and approved vendor.
  Future<bool> cancelEvent(String reason) async {
    final e = _event;
    if (e == null) return false;
    return run(() async {
      await _services.events.cancel(e.id);
      await _services.announcements.add(
        Announcement(
          id: '',
          eventId: e.id,
          eventTitle: e.title,
          organiserId: organiser.uid,
          type: AnnouncementType.cancellation,
          title: 'Event cancelled',
          body: reason,
        ),
      );
      final recipients = <String>{
        ..._registrations.where((r) => r.isActive).map((r) => r.studentId),
        ..._vendorApps.where((a) => a.status == ApplicationStatus.approved).map((a) => a.vendorId),
      };
      if (recipients.isNotEmpty) {
        await _services.notifications.notifyUsers(
          recipients,
          title: '${e.title} has been cancelled',
          body: reason,
          eventId: e.id,
          type: 'announcement',
        );
      }
    });
  }

  Future<bool> toggleWalkIns(bool allow) async {
    final ok = await run(() => _services.events.update(eventId, {'allowWalkIns': allow}));
    return ok;
  }

  Future<bool> updateCapacity(int capacity) async {
    final ok = await run(() => _services.events.update(eventId, {'capacity': capacity}));
    return ok;
  }

  Future<bool> updateDeadline(DateTime? deadline) async {
    final ok = await run(
      () => _services.events.update(eventId, {
        'registrationDeadline': deadline,
      }),
    );
    return ok;
  }

  // ── Seat Rescue ──
  Future<int> sendSeatRescue() async {
    final e = _event;
    if (e == null) return 0;
    final n = await guard(() async {
      final targets = await _services.registrations.sendConfirmationRequests(e);
      await _services.notifications.notifyUsers(
        targets.map((r) => r.studentId),
        title: 'Still coming to ${e.title}?',
        body: 'Please confirm your attendance in My Events. Unconfirmed seats are released to the waitlist ${e.seatRescueDeadlineHours}h before the event.',
        eventId: e.id,
        type: 'seat_rescue',
      );
      return targets.length;
    });
    return n ?? 0;
  }

  Future<(int released, int promoted)> releaseSeats() async {
    final e = _event;
    if (e == null) return (0, 0);
    final result = await guard(() async {
      final (released, promoted) = await _services.registrations.releaseUnconfirmedSeats(e);
      if (released.isNotEmpty) {
        await _services.notifications.notifyUsers(
          released.map((r) => r.studentId),
          title: 'Your seat for ${e.title} was released',
          body: 'You did not confirm attendance in time, so your seat went to a waitlisted student.',
          eventId: e.id,
          type: 'seat_rescue',
        );
      }
      if (promoted.isNotEmpty) {
        await _services.notifications.notifyUsers(
          promoted.map((r) => r.studentId),
          title: 'A seat opened up! 🎉',
          body: 'You are now registered for ${e.title}. Your QR ticket is ready in My Events.',
          eventId: e.id,
          type: 'waitlist',
        );
      }
      return (released.length, promoted.length);
    });
    return result ?? (0, 0);
  }

  // ── Attendee management ──
  Future<Registration?> removeAttendee(Registration r) async {
    final e = _event;
    return guard<Registration?>(() async {
      final promoted = await _services.registrations.cancel(r);
      await _services.notifications.notifyUsers(
        [r.studentId],
        title: 'Registration removed',
        body: 'The organiser removed your registration for ${r.eventTitle}.',
        eventId: r.eventId,
        type: 'registration',
      );
      if (promoted != null && e != null) {
        await _services.notifications.notifyUsers(
          [promoted.studentId],
          title: 'A seat opened up! 🎉',
          body: 'You are now registered for ${e.title}.',
          eventId: e.id,
          type: 'waitlist',
        );
      }
      return promoted;
    });
  }

  // ── Tasks ──
  Future<void> addTask(String title, String owner) =>
      _services.tasks.add(CrewTask(id: '', eventId: eventId, title: title, owner: owner, status: TaskStatus.todo));
  Future<void> cycleTask(CrewTask t) {
    final next = switch (t.status) {
      TaskStatus.todo => TaskStatus.inProgress,
      TaskStatus.inProgress => TaskStatus.done,
      TaskStatus.done => TaskStatus.todo,
    };
    return _services.tasks.setStatus(t.id, next);
  }
  Future<void> deleteTask(CrewTask t) => _services.tasks.delete(t.id);

  // ── Announcements ──
  Future<bool> sendAnnouncement({
    required AnnouncementType type,
    required String title,
    required String body,
    required bool notifyStudents,
    required bool notifyVendors,
  }) async {
    final e = _event;
    if (e == null) return false;
    final ok = await run(() async {
      await _services.announcements.add(
        Announcement(
          id: '',
          eventId: e.id,
          eventTitle: e.title,
          organiserId: organiser.uid,
          type: type,
          title: title,
          body: body,
          notifyStudents: notifyStudents,
          notifyVendors: notifyVendors,
        ),
      );
      final recipients = <String>{};
      if (notifyStudents) {
        recipients.addAll(_registrations.where((r) => r.isActive || r.status == RegistrationStatus.attended).map((r) => r.studentId));
      }
      if (notifyVendors) {
        recipients.addAll(_vendorApps.where((a) => a.status == ApplicationStatus.approved).map((a) => a.vendorId));
      }
      if (recipients.isNotEmpty) {
        await _services.notifications.notifyUsers(
          recipients,
          title: '${e.title}: $title',
          body: body,
          eventId: e.id,
          type: 'announcement',
        );
      }
    });
    return ok;
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _regSub?.cancel();
    _taskSub?.cancel();
    _vendorSub?.cancel();
    super.dispose();
  }
}

/// Outcome shown in the scanner UI.
class ScanFeedback {
  const ScanFeedback({required this.result, required this.message, this.registration, this.offline = false});
  final CheckInResult result;
  final String message;
  final Registration? registration;
  final bool offline;

  bool get isSuccess => result == CheckInResult.success;
}

/// QR check-in with duplicate detection, manual search, walk-ins and an
/// offline queue that reconciles against server records on reconnect.
class CheckInViewModel extends BaseViewModel {
  CheckInViewModel(this._services, this.staff, this.eventId) {
    _eventSub = _services.events.watch(eventId).listen((e) {
      _event = e;
      safeNotify();
    });
    _regSub = _services.registrations.watchByEvent(eventId).listen((r) {
      _registrations = r;
      safeNotify();
    });
    _connSub = Connectivity().onConnectivityChanged.listen((results) {
      final wasOnline = _online;
      _online = !results.contains(ConnectivityResult.none) && results.isNotEmpty;
      safeNotify();
      if (!wasOnline && _online) syncOfflineQueue();
    });
    Connectivity().checkConnectivity().then((results) {
      _online = !results.contains(ConnectivityResult.none) && results.isNotEmpty;
      safeNotify();
    });
    _refreshQueueCount();
  }

  final AppServices _services;
  final AppUser staff;
  final String eventId;

  StreamSubscription? _eventSub;
  StreamSubscription? _regSub;
  StreamSubscription? _connSub;

  Event? _event;
  List<Registration> _registrations = const [];
  bool _online = true;
  bool _syncing = false;
  int _queued = 0;
  ScanFeedback? _last;
  final List<ScanFeedback> _history = [];
  String _lastPayload = '';
  DateTime _lastScanAt = DateTime(2000);

  Event? get event => _event;
  bool get online => _online;
  bool get syncing => _syncing;
  int get queuedCount => _queued;
  ScanFeedback? get lastFeedback => _last;
  List<ScanFeedback> get history => List.unmodifiable(_history);
  int get attendedCount => _registrations.where((r) => r.status == RegistrationStatus.attended).length;
  int get registeredCount => _registrations.where((r) => r.status == RegistrationStatus.registered || r.status == RegistrationStatus.attended).length;

  /// Attendee list for manual search (name or TP number).
  List<Registration> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return _registrations
        .where((r) => r.status != RegistrationStatus.cancelled)
        .where((r) => r.studentName.toLowerCase().contains(q) || r.studentTp.toLowerCase().contains(q))
        .take(20)
        .toList();
  }

  /// Called by the scanner for each detected barcode.
  Future<void> handleScan(String payload) async {
    // Debounce repeated frames of the same code.
    final now = DateTime.now();
    if (payload == _lastPayload && now.difference(_lastScanAt) < const Duration(seconds: 3)) return;
    _lastPayload = payload;
    _lastScanAt = now;

    if (!_online) {
      await _queueOffline(payload);
      return;
    }
    try {
      final outcome = await _services.registrations
          .checkInByPayload(payload: payload, expectedEventId: eventId, staffUid: staff.uid)
          .timeout(const Duration(seconds: 6));
      _push(ScanFeedback(result: outcome.result, message: _messageFor(outcome), registration: outcome.registration));
    } on TimeoutException {
      // Network is flaky: fall back to the offline queue.
      await _queueOffline(payload);
    } catch (e) {
      // Firestore unavailable → treat as offline rather than losing the scan.
      final msg = e.toString().toLowerCase();
      if (msg.contains('unavailable') || msg.contains('network') || msg.contains('socket')) {
        await _queueOffline(payload);
      } else {
        _push(ScanFeedback(result: CheckInResult.invalid, message: 'Scan failed: $e'));
      }
    }
  }

  Future<void> _queueOffline(String payload) async {
    // Validate locally against the cached registration list so the crew
    // gets instant feedback even without network.
    final ticket = _decodeLocal(payload);
    if (ticket == null) {
      _push(const ScanFeedback(result: CheckInResult.invalid, message: 'Not a UniEvent ticket.', offline: true));
      return;
    }
    if (ticket.status == RegistrationStatus.attended) {
      _push(ScanFeedback(result: CheckInResult.duplicate, message: 'Already checked in (cached)', registration: ticket, offline: true));
      return;
    }
    await _services.offlineQueue.enqueue(
      QueuedScan(payload: payload, eventId: eventId, scannedAt: DateTime.now(), staffUid: staff.uid, registrationId: ticket.id),
    );
    await _refreshQueueCount();
    _push(ScanFeedback(result: CheckInResult.success, message: 'Checked in offline — will sync', registration: ticket, offline: true));
  }

  Registration? _decodeLocal(String payload) {
    final parts = payload.split('|');
    if (parts.length != 4 || parts[0] != 'UNIEVENT' || parts[1] != eventId) return null;
    final match = _registrations.where((r) => r.id == parts[2] && r.ticketCode == parts[3]);
    return match.isEmpty ? null : match.first;
  }

  /// Replays queued scans. The server decides duplicates/conflicts.
  Future<void> syncOfflineQueue() async {
    if (_syncing) return;
    _syncing = true;
    safeNotify();
    try {
      final queue = await _services.offlineQueue.load(eventId);
      for (final q in queue) {
        try {
          final outcome = await _services.registrations.checkInByPayload(
            payload: q.payload,
            expectedEventId: eventId,
            staffUid: q.staffUid,
            scannedAt: q.scannedAt,
          );
          await _services.offlineQueue.remove(eventId, q.payload);
          if (outcome.result == CheckInResult.duplicate) {
            _history.insert(
              0,
              ScanFeedback(
                result: CheckInResult.duplicate,
                message: 'Synced: ${outcome.registration?.studentName ?? 'ticket'} was already checked in on another device.',
                registration: outcome.registration,
              ),
            );
          }
        } catch (_) {
          // Keep in queue; try again on next sync.
        }
      }
    } finally {
      _syncing = false;
      await _refreshQueueCount();
      safeNotify();
    }
  }

  Future<void> _refreshQueueCount() async {
    _queued = await _services.offlineQueue.count(eventId);
    safeNotify();
  }

  Future<void> manualCheckIn(Registration r) async {
    final outcome = await guard(() => _services.registrations.checkInManually(reg: r, staffUid: staff.uid));
    if (outcome != null) {
      _push(ScanFeedback(result: outcome.result, message: _messageFor(outcome), registration: outcome.registration ?? r));
    }
  }

  Future<bool> registerWalkIn(String name, String tp) async {
    final e = _event;
    if (e == null) return false;
    final reg = await guard(() => _services.registrations.registerWalkIn(event: e, name: name, tpNumber: tp, staffUid: staff.uid));
    if (reg != null) {
      _push(ScanFeedback(result: CheckInResult.success, message: 'Walk-in checked in', registration: reg));
    }
    return reg != null;
  }

  String _messageFor(CheckInOutcome o) => switch (o.result) {
        CheckInResult.success => 'Checked in',
        CheckInResult.duplicate => 'Duplicate ticket — already checked in',
        CheckInResult.invalid => o.message ?? 'Invalid ticket',
        CheckInResult.wrongEvent => 'Ticket is for a different event',
        CheckInResult.notRegistered => o.message ?? 'Not registered',
      };

  void _push(ScanFeedback f) {
    _last = f;
    _history.insert(0, f);
    if (_history.length > 50) _history.removeLast();
    safeNotify();
  }

  void clearLast() {
    _last = null;
    safeNotify();
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _regSub?.cancel();
    _connSub?.cancel();
    super.dispose();
  }
}

/// Vendor applications across the organiser's events.
class VendorManagementViewModel extends BaseViewModel {
  VendorManagementViewModel(this._services, this.organiser) {
    _sub = _services.vendorApplications.watchByOrganiser(organiser.uid).listen((a) {
      _apps = a;
      safeNotify();
    });
  }

  final AppServices _services;
  final AppUser organiser;
  StreamSubscription? _sub;
  List<VendorApplication>? _apps;

  bool get loading => _apps == null;
  List<VendorApplication> get all => _apps ?? const [];
  List<VendorApplication> get pending => all.where((a) => a.status == ApplicationStatus.pending).toList();
  List<VendorApplication> get approved => all.where((a) => a.status == ApplicationStatus.approved).toList();
  List<VendorApplication> get rejected => all.where((a) => a.status == ApplicationStatus.rejected).toList();

  Future<bool> review(
    VendorApplication app, {
    required ApplicationStatus status,
    String? booth,
    String? arrival,
    String? parking,
    String? setup,
    String? note,
  }) async {
    final ok = await run(() async {
      await _services.vendorApplications.review(
        id: app.id,
        status: status,
        boothNumber: booth,
        arrivalTime: arrival,
        parkingDetails: parking,
        setupInstructions: setup,
        note: note,
      );
      await _services.notifications.notifyUsers(
        [app.vendorId],
        title: status == ApplicationStatus.approved
            ? 'Application approved — ${app.eventTitle}'
            : 'Application update — ${app.eventTitle}',
        body: status == ApplicationStatus.approved
            ? 'Booth ${booth ?? 'TBC'} • Arrive ${arrival ?? 'TBC'}. Open the event for setup instructions.'
            : (note?.isNotEmpty == true ? note! : 'Your application was not successful this time.'),
        eventId: app.eventId,
        type: 'vendor',
      );
    });
    return ok;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Budget lines for one event.
class BudgetViewModel extends BaseViewModel {
  BudgetViewModel(this._services, this.eventId) {
    _sub = _services.budgets.watchByEvent(eventId).listen((b) {
      _lines = b;
      safeNotify();
    });
  }

  final AppServices _services;
  final String eventId;
  StreamSubscription? _sub;
  List<BudgetLine>? _lines;

  bool get loading => _lines == null;
  List<BudgetLine> get lines => _lines ?? const [];
  double get planned => lines.fold(0, (s, l) => s + l.planned);
  double get actual => lines.fold(0, (s, l) => s + l.actual);
  Map<String, (double, double)> get byCategory {
    final m = <String, (double, double)>{};
    for (final l in lines) {
      final cur = m[l.category] ?? (0.0, 0.0);
      m[l.category] = (cur.$1 + l.planned, cur.$2 + l.actual);
    }
    return m;
  }

  Future<bool> add(String category, String description, double planned, double actual) async {
    final ok = await run(
      () => _services.budgets.add(BudgetLine(id: '', eventId: eventId, category: category, description: description, planned: planned, actual: actual)),
    );
    return ok;
  }

  Future<bool> update(BudgetLine l, {double? planned, double? actual, String? description}) async {
    final ok = await run(
      () => _services.budgets.update(l.id, {
        if (planned != null) 'planned': planned,
        if (actual != null) 'actual': actual,
        if (description != null) 'description': description,
      }),
    );
    return ok;
  }

  Future<bool> attachReceipt(BudgetLine l) async {
    final ok = await run(() async {
      final url = await _services.storage.pickAndUpload('receipts/$eventId');
      if (url != null) await _services.budgets.update(l.id, {'receiptUrl': url});
    });
    return ok;
  }

  Future<bool> delete(BudgetLine l) async {
    final ok = await run(() => _services.budgets.delete(l.id));
    return ok;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Post-event report.
class ReportViewModel extends BaseViewModel {
  ReportViewModel(this._services, this.eventId) {
    load();
  }

  final AppServices _services;
  final String eventId;
  EventReportData? _data;
  List<Event> _previous = const [];

  EventReportData? get data => _data;
  List<Event> get previousEvents => _previous;

  Future<void> load() async {
    await guard(() async {
      final event = await _services.events.get(eventId);
      if (event == null) throw Exception('Event not found');
      final results = await Future.wait([
        _services.registrations.fetchByEvent(eventId),
        _services.feedback.fetchByEvent(eventId),
        _services.budgets.fetchByEvent(eventId),
        _services.orders.watchByEvent(eventId).first,
      ]);
      _data = EventReportData(
        event: event,
        registrations: results[0] as List<Registration>,
        feedback: results[1] as List<EventFeedback>,
        budget: results[2] as List<BudgetLine>,
        orders: results[3] as List<VendorOrder>,
      );
      final hist = await _services.events.watchByOrganiser(event.organiserId).first;
      _previous = hist.where((e) => e.id != eventId && e.status == EventStatus.ended).take(5).toList();
    });
  }

  Future<bool> exportPdf() async {
    if (_data == null) return false;
    final ok = await run(() => _services.reports.sharePdf(_data!));
    return ok;
  }
}

/// Student Affairs approval dashboard.
class StudentAffairsViewModel extends BaseViewModel {
  StudentAffairsViewModel(this._services, this.reviewer) {
    _sub = _services.proposals.watchForReview().listen((p) {
      _proposals = p;
      safeNotify();
    });
  }

  final AppServices _services;
  final AppUser reviewer;
  StreamSubscription? _sub;
  List<Proposal>? _proposals;

  bool get loading => _proposals == null;
  List<Proposal> get all => _proposals ?? const [];
  List<Proposal> get queue => all.where((p) => p.status == ProposalStatus.submitted).toList();
  List<Proposal> get decided => all.where((p) => p.status != ProposalStatus.submitted).toList();

  Future<bool> decide(Proposal p, ProposalStatus status, String comment) async {
    final ok = await run(() async {
      await _services.proposals.review(id: p.id, status: status, reviewerUid: reviewer.uid, comment: comment);
      await _services.notifications.notifyUsers(
        [p.organiserId],
        title: 'Proposal ${status.label.toLowerCase()}: ${p.eventTitle}',
        body: comment.isEmpty ? 'Student Affairs reviewed your proposal.' : comment,
        type: 'proposal',
      );
    });
    return ok;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

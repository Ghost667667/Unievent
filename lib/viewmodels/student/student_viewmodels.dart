import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/order_rules.dart';
import '../../models/models.dart';
import '../../repositories/event_repository.dart';
import '../../repositories/order_repository.dart';
import '../../repositories/registration_repository.dart';
import '../../services/app_services.dart';
import '../../services/integration_services.dart';

/// Base class with busy/error plumbing shared by the ViewModels below.
abstract class BaseViewModel extends ChangeNotifier {
  bool _busy = false;
  String? _error;
  bool _disposed = false;

  bool get busy => _busy;
  String? get error => _error;

  @protected
  Future<T?> guard<T>(Future<T> Function() action) async {
    _busy = true;
    _error = null;
    safeNotify();
    try {
      return await action();
    } on RegistrationException catch (e) {
      _error = e.message;
    } on OrderException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      debugPrint('ViewModel error: $e');
    } finally {
      _busy = false;
      safeNotify();
    }
    return null;
  }

  /// Like [guard] for actions with no return value: true on success.
  @protected
  Future<bool> run(Future<void> Function() action) async {
    var ok = false;
    await guard(() async {
      await action();
      ok = true;
    });
    return ok;
  }

  void clearError() {
    _error = null;
    safeNotify();
  }

  @protected
  void safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Explore / Home feed: upcoming events with client-side filtering and
/// a simple interest-based recommendation.
class EventFeedViewModel extends BaseViewModel {
  EventFeedViewModel(this._services, this.student) {
    _sub = _services.events.watchUpcoming().listen(
      (events) {
        _all = events;
        safeNotify();
      },
      onError: (Object e) {
        _error = e.toString();
        safeNotify();
      },
    );
    _regSub = _services.registrations.watchByStudent(student.uid).listen((r) {
      _registrations = r;
      safeNotify();
    });
  }

  final AppServices _services;
  final AppUser student;
  StreamSubscription<List<Event>>? _sub;
  StreamSubscription<List<Registration>>? _regSub;

  List<Event>? _all;
  List<Registration> _registrations = const [];
  EventFilter _filter = const EventFilter();

  bool get loading => _all == null;
  EventFilter get filter => _filter;
  List<Event> get all => _all ?? const [];

  List<Event> get filtered => all.where(_filter.matches).toList();

  List<Event> get upcoming => all.take(10).toList();

  /// Events matching the student's interests or followed organisers.
  List<Event> get recommended {
    final interests = student.interests.map((i) => i.toLowerCase()).toSet();
    final following = student.followingOrganiserIds.toSet();
    final mine = _registrations.map((r) => r.eventId).toSet();
    final list = all
        .where((e) => !mine.contains(e.id))
        .where(
          (e) =>
              interests.contains(e.category.toLowerCase()) ||
              following.contains(e.organiserId),
        )
        .toList();
    // Followed organisers first, then soonest.
    list.sort((a, b) {
      final af = following.contains(a.organiserId) ? 0 : 1;
      final bf = following.contains(b.organiserId) ? 0 : 1;
      if (af != bf) return af - bf;
      return a.startTime.compareTo(b.startTime);
    });
    return list;
  }

  /// The student's next registered event with its registration.
  (Event, Registration)? get nextRegistered {
    final active = _registrations
        .where((r) => r.status == RegistrationStatus.registered)
        .toList();
    for (final e in all) {
      final reg = active.where((r) => r.eventId == e.id);
      if (reg.isNotEmpty) return (e, reg.first);
    }
    return null;
  }

  Registration? registrationFor(String eventId) {
    final match = _registrations.where((r) => r.eventId == eventId && r.isActive);
    return match.isEmpty ? null : match.first;
  }

  List<String> get venues =>
      all.map((e) => e.venue).toSet().toList()..sort();

  void setFilter(EventFilter f) {
    _filter = f;
    safeNotify();
  }

  void setQuery(String q) => setFilter(_filter.copyWith(query: q));

  void clearFilters() => setFilter(EventFilter(query: _filter.query));

  /// [currentlySaved] comes from the live AuthViewModel user so it is never
  /// stale.
  Future<void> toggleSave(String eventId, {required bool currentlySaved}) =>
      _services.users.toggleSavedEvent(student.uid, eventId, !currentlySaved);

  Future<void> toggleFollow(
    String organiserId, {
    required bool currentlyFollowing,
  }) =>
      _services.users
          .toggleFollowOrganiser(student.uid, organiserId, !currentlyFollowing);

  @override
  void dispose() {
    _sub?.cancel();
    _regSub?.cancel();
    super.dispose();
  }
}

/// Event details: registration, waitlist, vendors, announcements, weather.
class EventDetailsViewModel extends BaseViewModel {
  EventDetailsViewModel(this._services, this.student, this.eventId) {
    _eventSub = _services.events.watch(eventId).listen((e) {
      _event = e;
      _loaded = true;
      if (e != null && _weather == null && !_weatherTried) _loadWeather(e);
      safeNotify();
    });
    _regSub = _services.registrations
        .watchForStudent(eventId, student.uid)
        .listen((r) {
      _registration = r;
      safeNotify();
    });
    _vendorSub = _services.vendorApplications
        .watchApprovedForEvent(eventId)
        .listen((v) {
      _vendors = v;
      safeNotify();
    });
    _annSub = _services.announcements.watchByEvent(eventId).listen((a) {
      _announcements = a;
      safeNotify();
    });
  }

  final AppServices _services;
  final AppUser student;
  final String eventId;

  StreamSubscription? _eventSub;
  StreamSubscription? _regSub;
  StreamSubscription? _vendorSub;
  StreamSubscription? _annSub;

  Event? _event;
  bool _loaded = false;
  Registration? _registration;
  List<VendorApplication> _vendors = const [];
  List<Announcement> _announcements = const [];
  WeatherForecast? _weather;
  bool _weatherTried = false;

  Event? get event => _event;
  bool get loaded => _loaded;
  Registration? get registration => _registration;
  List<VendorApplication> get vendors => _vendors;
  List<Announcement> get announcements => _announcements;
  WeatherForecast? get weather => _weather;

  bool get isRegistered =>
      _registration?.status == RegistrationStatus.registered ||
      _registration?.status == RegistrationStatus.attended;
  bool get isWaitlisted => _registration?.status == RegistrationStatus.waitlisted;

  Future<void> _loadWeather(Event e) async {
    _weatherTried = true;
    _weather = await _services.weather.forecastFor(e);
    safeNotify();
  }

  /// Registers (or joins the waitlist). Returns the registration on success.
  Future<Registration?> register() async {
    final e = _event;
    if (e == null) return null;
    return guard(() async {
      final reg = await _services.registrations.register(
        event: e,
        student: student,
      );
      await _services.notifications.notifyUsers(
        [student.uid],
        title: reg.status == RegistrationStatus.waitlisted
            ? 'You are on the waitlist'
            : 'Registration confirmed',
        body: reg.status == RegistrationStatus.waitlisted
            ? 'We will notify you the moment a seat opens for ${e.title}.'
            : 'Your QR ticket for ${e.title} is ready in My Events.',
        eventId: e.id,
        type: 'registration',
      );
      return reg;
    });
  }

  Future<bool> cancelRegistration() async {
    final reg = _registration;
    final e = _event;
    if (reg == null || e == null) return false;
    final result = await guard(() async {
      final promoted = await _services.registrations.cancel(reg);
      if (promoted != null) {
        await _services.notifications.notifyUsers(
          [promoted.studentId],
          title: 'A seat opened up! 🎉',
          body: 'You have been moved off the waitlist and are now registered for ${e.title}.',
          eventId: e.id,
          type: 'waitlist',
        );
      }
      return true;
    });
    return result ?? false;
  }

  Future<void> toggleSave({required bool currentlySaved}) =>
      _services.users.toggleSavedEvent(student.uid, eventId, !currentlySaved);

  Future<void> toggleFollow({required bool currentlyFollowing}) {
    final orgId = _event?.organiserId;
    if (orgId == null) return Future.value();
    return _services.users
        .toggleFollowOrganiser(student.uid, orgId, !currentlyFollowing);
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _regSub?.cancel();
    _vendorSub?.cancel();
    _annSub?.cancel();
    super.dispose();
  }
}

/// Digital ticket actions.
class TicketViewModel extends BaseViewModel {
  TicketViewModel(this._services, this.registrationId) {
    _sub = _services.registrations.watch(registrationId).listen((r) async {
      _registration = r;
      _loaded = true;
      if (r != null && (_event == null || _event!.id != r.eventId)) {
        _eventSub?.cancel();
        _eventSub = _services.events.watch(r.eventId).listen((e) {
          _event = e;
          safeNotify();
        });
      }
      safeNotify();
    });
  }

  final AppServices _services;
  final String registrationId;
  StreamSubscription? _sub;
  StreamSubscription? _eventSub;
  Registration? _registration;
  Event? _event;
  bool _loaded = false;

  Registration? get registration => _registration;
  Event? get event => _event;
  bool get loaded => _loaded;

  Future<bool> confirmAttendance() async {
    final r = _registration;
    if (r == null) return false;
    final ok = await run(() => _services.registrations.confirmAttendance(r));
    return ok;
  }

  Future<Registration?> cancel() async {
    final r = _registration;
    final e = _event;
    if (r == null) return null;
    return guard<Registration?>(() async {
      final promoted = await _services.registrations.cancel(r);
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

  Future<void> openMaps() async {
    if (_event != null) await _services.maps.openDirections(_event!);
  }

  Future<void> addToCalendar(String ticketNumber) async {
    if (_event != null) {
      await _services.calendar.addToGoogleCalendar(_event!, ticketNumber: ticketNumber);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _eventSub?.cancel();
    super.dispose();
  }
}

/// Vendor menu + cart + sandbox checkout for one vendor at one event.
class VendorMenuViewModel extends BaseViewModel {
  VendorMenuViewModel(
    this._services,
    this.student,
    this.eventId,
    this.vendorId,
  ) {
    _productSub = _services.products.watchMenu(vendorId).listen((p) {
      _products = p;
      // Drop cart lines that sold out underneath us.
      _cart.removeWhere((id, qty) {
        final match = p.where((x) => x.id == id);
        return match.isEmpty || match.first.quantity <= 0;
      });
      safeNotify();
    });
    _services.events.get(eventId).then((e) {
      _event = e;
      safeNotify();
    });
    _services.users.get(vendorId).then((v) {
      _vendor = v;
      safeNotify();
    });
    _appSub = _services.vendorApplications.watchByEvent(eventId).listen((apps) {
      final mine = apps.where((a) => a.vendorId == vendorId);
      _application = mine.isEmpty ? null : mine.first;
      safeNotify();
    });
  }

  final AppServices _services;
  final AppUser student;
  final String eventId;
  final String vendorId;

  StreamSubscription? _productSub;
  StreamSubscription? _appSub;
  List<Product>? _products;
  Event? _event;
  AppUser? _vendor;
  VendorApplication? _application;
  final Map<String, int> _cart = {};
  String _paymentMethod = SandboxPaymentService.methods.first;

  List<Product> get products => _products ?? const [];
  bool get loading => _products == null;
  Event? get event => _event;
  AppUser? get vendor => _vendor;
  VendorApplication? get application => _application;
  Map<String, int> get cart => Map.unmodifiable(_cart);
  String get paymentMethod => _paymentMethod;
  int get cartCount => _cart.values.fold(0, (a, b) => a + b);

  double get total {
    var t = 0.0;
    for (final e in _cart.entries) {
      final p = products.where((x) => x.id == e.key);
      if (p.isNotEmpty) t += p.first.price * e.value;
    }
    return t;
  }

  int qtyOf(String productId) => _cart[productId] ?? 0;

  void setPaymentMethod(String m) {
    _paymentMethod = m;
    safeNotify();
  }

  void increment(Product p) {
    final current = _cart[p.id] ?? 0;
    if (p.quantity <= 0) {
      _error = '${p.name} is sold out.';
      safeNotify();
      return;
    }
    if (current + 1 > p.quantity) {
      _error = 'Only ${p.quantity} × ${p.name} available.';
      safeNotify();
      return;
    }
    _cart[p.id] = current + 1;
    _error = null;
    safeNotify();
  }

  void decrement(Product p) {
    final current = _cart[p.id] ?? 0;
    if (current <= 1) {
      _cart.remove(p.id);
    } else {
      _cart[p.id] = current - 1;
    }
    safeNotify();
  }

  void clearCart() {
    _cart.clear();
    safeNotify();
  }

  /// Sandbox payment then order placement (stock deducted transactionally).
  Future<VendorOrder?> checkout({String? cardLastDigits}) async {
    final e = _event;
    if (e == null || _cart.isEmpty) return null;
    final validation = OrderRules.validateCart(_cart, products);
    if (!validation.ok) {
      _error = validation.problems.join('\n');
      safeNotify();
      return null;
    }
    return guard(() async {
      final pay = await _services.payments.pay(
        amountRm: total,
        method: _paymentMethod,
        cardLastDigits: cardLastDigits,
      );
      if (!pay.success) throw OrderException(pay.error ?? 'Payment failed.');
      final order = await _services.orders.placeOrder(
        event: e,
        student: student,
        vendorId: vendorId,
        vendorName: _vendor?.displayName ?? products.first.vendorName,
        quantities: Map.of(_cart),
        paymentReference: pay.reference!,
        boothNumber: _application?.boothNumber,
      );
      _cart.clear();
      await _services.notifications.notifyUsers(
        [vendorId],
        title: 'New pre-order ${order.orderNumber}',
        body: '${student.fullName} ordered ${order.itemCount} item(s) for ${e.title}.',
        eventId: e.id,
        type: 'order',
      );
      return order;
    });
  }

  @override
  void dispose() {
    _productSub?.cancel();
    _appSub?.cancel();
    super.dispose();
  }
}

/// Post-event feedback.
class FeedbackViewModel extends BaseViewModel {
  FeedbackViewModel(this._services, this.student, this.eventId) {
    _services.events.get(eventId).then((e) {
      _event = e;
      safeNotify();
    });
    _existingSub =
        _services.feedback.watchMine(eventId, student.uid).listen((f) {
      _existing = f;
      if (f != null) {
        eventRating = f.eventRating;
        comment = f.comment;
        vendorRatings.addAll(f.vendorRatings);
      }
      safeNotify();
    });
    _ordersSub = _services.orders.watchByStudent(student.uid).listen((o) {
      final vendorsAtEvent = <String, String>{};
      for (final order in o.where((x) => x.eventId == eventId)) {
        vendorsAtEvent[order.vendorId] = order.vendorName;
      }
      _vendors = vendorsAtEvent;
      safeNotify();
    });
  }

  final AppServices _services;
  final AppUser student;
  final String eventId;
  StreamSubscription? _existingSub;
  StreamSubscription? _ordersSub;

  Event? _event;
  EventFeedback? _existing;
  Map<String, String> _vendors = const {};

  int eventRating = 0;
  String comment = '';
  final Map<String, int> vendorRatings = {};

  Event? get event => _event;
  EventFeedback? get existing => _existing;
  Map<String, String> get vendors => _vendors;

  void setEventRating(int r) {
    eventRating = r;
    safeNotify();
  }

  void setVendorRating(String vendorId, int r) {
    vendorRatings[vendorId] = r;
    safeNotify();
  }

  Future<bool> submit() async {
    if (eventRating == 0) {
      _error = 'Please choose a star rating.';
      safeNotify();
      return false;
    }
    final ok = await run(
      () => _services.feedback.submit(
        EventFeedback(
          id: EventFeedback.makeId(eventId, student.uid),
          eventId: eventId,
          studentId: student.uid,
          eventRating: eventRating,
          comment: comment.trim(),
          vendorRatings: Map.of(vendorRatings),
        ),
      ),
    );
    return ok;
  }

  @override
  void dispose() {
    _existingSub?.cancel();
    _ordersSub?.cancel();
    super.dispose();
  }
}

/// Profile editing shared by all roles (role-specific fields are optional).
class ProfileViewModel extends BaseViewModel {
  ProfileViewModel(this._services);
  final AppServices _services;

  Future<bool> save(String uid, Map<String, dynamic> fields) async {
    final ok = await run(() => _services.users.update(uid, fields));
    return ok;
  }

  Future<String?> uploadPhoto(String uid, {required String field}) async {
    return guard<String?>(() async {
      final url = await _services.storage.pickAndUpload('avatars/$uid');
      if (url != null) await _services.users.update(uid, {field: url});
      return url;
    });
  }
}

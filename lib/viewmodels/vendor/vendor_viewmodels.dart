import 'dart:async';

import '../../models/models.dart';
import '../../services/app_services.dart';
import '../../services/storage_service.dart';
import '../student/student_viewmodels.dart' show BaseViewModel;

/// Vendor dashboard: products, orders, applications and derived analytics.
/// Shared across the five vendor tabs so stats stay consistent.
class VendorDashboardViewModel extends BaseViewModel {
  VendorDashboardViewModel(this._services, this.vendor) {
    _productSub = _services.products.watchByVendor(vendor.uid).listen((p) {
      _products = p;
      safeNotify();
    });
    _orderSub = _services.orders.watchByVendor(vendor.uid).listen((o) {
      _orders = o;
      safeNotify();
    });
    _appSub = _services.vendorApplications.watchByVendor(vendor.uid).listen((a) {
      _applications = a;
      safeNotify();
    });
    _eventSub = _services.events.watchAcceptingVendors().listen((e) {
      _openEvents = e;
      safeNotify();
    });
  }

  final AppServices _services;
  final AppUser vendor;
  StreamSubscription? _productSub;
  StreamSubscription? _orderSub;
  StreamSubscription? _appSub;
  StreamSubscription? _eventSub;

  List<Product>? _products;
  List<VendorOrder>? _orders;
  List<VendorApplication>? _applications;
  List<Event>? _openEvents;

  bool get loading => _products == null || _orders == null || _applications == null;
  List<Product> get products => _products ?? const [];
  List<VendorOrder> get orders => _orders ?? const [];
  List<VendorApplication> get applications => _applications ?? const [];
  List<Event> get openEvents => _openEvents ?? const [];

  // ── Stats ──
  List<VendorOrder> get completedOrders => orders.where((o) => o.status != OrderStatus.cancelled).toList();
  double get totalSales => completedOrders.fold(0, (s, o) => s + o.total);
  int get totalOrders => completedOrders.length;
  int get cancelledOrders => orders.where((o) => o.status == OrderStatus.cancelled).length;
  int get eventsParticipated => applications.where((a) => a.status == ApplicationStatus.approved).length;
  int get availableProducts => products.where((p) => p.isActive && p.quantity > 0).length;
  int get totalStock => products.fold(0, (s, p) => s + p.quantity);
  List<Product> get lowStock => products.where((p) => p.stockStatus == StockStatus.lowStock).toList();
  List<Product> get soldOut => products.where((p) => p.stockStatus == StockStatus.soldOut).toList();

  List<VendorOrder> get activeOrders => orders.where((o) => !o.status.isTerminal).toList();
  List<VendorOrder> get recentOrders => orders.take(5).toList();

  /// Approved upcoming participations.
  List<VendorApplication> get upcomingParticipations => applications
      .where((a) => a.status == ApplicationStatus.approved && (a.eventStartTime == null || a.eventStartTime!.isAfter(DateTime.now().subtract(const Duration(hours: 12)))))
      .toList()
    ..sort((a, b) => (a.eventStartTime ?? DateTime(2100)).compareTo(b.eventStartTime ?? DateTime(2100)));

  /// Bestsellers: productId → (name, qty, revenue).
  List<(String, int, double)> get bestsellers {
    final map = <String, (String, int, double)>{};
    for (final o in completedOrders) {
      for (final i in o.items) {
        final cur = map[i.productId] ?? (i.name, 0, 0.0);
        map[i.productId] = (i.name, cur.$2 + i.quantity, cur.$3 + i.lineTotal);
      }
    }
    final list = map.values.toList()..sort((a, b) => b.$2.compareTo(a.$2));
    return list;
  }

  /// Sales per event: eventTitle → (orders, revenue).
  Map<String, (int, double)> get salesByEvent {
    final m = <String, (int, double)>{};
    for (final o in completedOrders) {
      final cur = m[o.eventTitle] ?? (0, 0.0);
      m[o.eventTitle] = (cur.$1 + 1, cur.$2 + o.total);
    }
    return m;
  }

  /// Sales by day for the last 7 days (for the analytics line chart).
  List<(DateTime, double)> get salesLast7Days {
    final today = DateTime.now();
    return List.generate(7, (i) {
      final day = DateTime(today.year, today.month, today.day).subtract(Duration(days: 6 - i));
      final total = completedOrders
          .where((o) => o.createdAt != null && o.createdAt!.year == day.year && o.createdAt!.month == day.month && o.createdAt!.day == day.day)
          .fold(0.0, (s, o) => s + o.total);
      return (day, total);
    });
  }

  ApplicationStatus? applicationStatusFor(String eventId) {
    final m = applications.where((a) => a.eventId == eventId);
    return m.isEmpty ? null : m.first.status;
  }

  VendorApplication? applicationFor(String eventId) {
    final m = applications.where((a) => a.eventId == eventId);
    return m.isEmpty ? null : m.first;
  }

  // ── Orders ──
  Future<bool> advanceOrder(VendorOrder o) async {
    final ok = await run(() async {
      await _services.orders.advance(o);
      final next = o.status.next!;
      if (next == OrderStatus.ready) {
        await _services.notifications.notifyUsers(
          [o.studentId],
          title: 'Order ${o.orderNumber} is ready! 🎉',
          body: o.collectionNote ?? 'Collect it from ${o.vendorName} now.',
          eventId: o.eventId,
          type: 'order',
        );
      }
    });
    return ok;
  }

  Future<bool> cancelOrder(VendorOrder o) async {
    final ok = await run(() async {
      await _services.orders.cancel(o, byStudent: false);
      await _services.notifications.notifyUsers(
        [o.studentId],
        title: 'Order ${o.orderNumber} cancelled',
        body: '${o.vendorName} cancelled your order. Your sandbox payment is refunded.',
        eventId: o.eventId,
        type: 'order',
      );
    });
    return ok;
  }

  // ── Inventory ──
  Future<bool> setQuantity(Product p, int qty) => run(() => _services.products.setQuantity(p.id, qty));
  Future<bool> deleteProduct(Product p) => run(() => _services.products.delete(p.id));
  Future<bool> toggleActive(Product p) => run(() => _services.products.update(p.copyWith(isActive: !p.isActive)));

  // ── Events ──
  Future<bool> apply(Event e, String message) async {
    final ok = await run(() async {
      await _services.vendorApplications.apply(
        VendorApplication(
          id: VendorApplication.makeId(e.id, vendor.uid),
          eventId: e.id,
          eventTitle: e.title,
          eventStartTime: e.startTime,
          organiserId: e.organiserId,
          vendorId: vendor.uid,
          vendorName: vendor.displayName,
          productCategory: vendor.productCategory ?? 'Other',
          message: message,
          isStudentVendor: vendor.isStudentVendor,
          status: ApplicationStatus.pending,
        ),
      );
      await _services.notifications.notifyUsers(
        [e.organiserId],
        title: 'New vendor application',
        body: '${vendor.displayName} applied to ${e.title}.',
        eventId: e.id,
        type: 'vendor',
      );
    });
    return ok;
  }

  Future<bool> withdraw(VendorApplication a) => run(() => _services.vendorApplications.withdraw(a.id));
  Future<bool> checkInAtEvent(VendorApplication a) => run(() => _services.vendorApplications.vendorCheckIn(a.id));

  Future<int> loadSampleData() async {
    final n = await guard(() => _services.seed.seedForVendor(vendor));
    return n ?? 0;
  }

  @override
  void dispose() {
    _productSub?.cancel();
    _orderSub?.cancel();
    _appSub?.cancel();
    _eventSub?.cancel();
    super.dispose();
  }
}

/// Add / edit a product including image upload.
class ProductFormViewModel extends BaseViewModel {
  ProductFormViewModel(this._services, this.vendor);
  final AppServices _services;
  final AppUser vendor;

  PickedImage? imageFile;

  Future<void> pickImage() async {
    final f = await _services.storage.pickImage();
    if (f != null) {
      imageFile = f;
      safeNotify();
    }
  }

  Future<bool> save({
    Product? existing,
    required String name,
    required String description,
    required String category,
    required double price,
    required int quantity,
    required int lowStockThreshold,
  }) async {
    return run(() async {
      var imageUrl = existing?.imageUrl;
      if (imageFile != null) {
        imageUrl = await _services.storage.upload(imageFile!, 'products/${vendor.uid}');
      }
      final product = Product(
        id: existing?.id ?? '',
        vendorId: vendor.uid,
        vendorName: vendor.displayName,
        name: name,
        description: description,
        category: category,
        price: price,
        quantity: quantity,
        lowStockThreshold: lowStockThreshold,
        soldCount: existing?.soldCount ?? 0,
        imageUrl: imageUrl,
        isActive: existing?.isActive ?? true,
        createdAt: existing?.createdAt,
      );
      if (existing == null) {
        await _services.products.create(product);
      } else {
        await _services.products.update(product);
      }
    });
  }
}

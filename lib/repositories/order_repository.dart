import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/order_rules.dart';
import '../models/models.dart';

class OrderException implements Exception {
  OrderException(this.message);
  final String message;
  @override
  String toString() => message;
}

class OrderRepository {
  OrderRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _orders =>
      _db.collection('orders');
  CollectionReference<Map<String, dynamic>> get _products =>
      _db.collection('products');

  Stream<List<VendorOrder>> watchByStudent(String studentId) => _orders
      .where('studentId', isEqualTo: studentId)
      .snapshots()
      .map((s) => _sorted(s.docs.map(VendorOrder.fromDoc)));

  Stream<List<VendorOrder>> watchByVendor(String vendorId) => _orders
      .where('vendorId', isEqualTo: vendorId)
      .snapshots()
      .map((s) => _sorted(s.docs.map(VendorOrder.fromDoc)));

  Stream<List<VendorOrder>> watchByEvent(String eventId) => _orders
      .where('eventId', isEqualTo: eventId)
      .snapshots()
      .map((s) => _sorted(s.docs.map(VendorOrder.fromDoc)));

  Stream<VendorOrder?> watch(String id) => _orders
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? VendorOrder.fromDoc(d) : null);

  List<VendorOrder> _sorted(Iterable<VendorOrder> orders) =>
      orders.toList()
        ..sort(
          (a, b) => (b.createdAt ?? DateTime(2000))
              .compareTo(a.createdAt ?? DateTime(2000)),
        );

  /// Places a pre-order. Stock is deducted inside a transaction so it can
  /// never go negative, even under concurrent orders.
  Future<VendorOrder> placeOrder({
    required Event event,
    required AppUser student,
    required String vendorId,
    required String vendorName,
    required Map<String, int> quantities,
    required String paymentReference,
    String? boothNumber,
  }) async {
    final orderRef = _orders.doc();
    final productIds = quantities.keys.toList();

    return _db.runTransaction<VendorOrder>((tx) async {
      final items = <OrderItem>[];
      final updates = <DocumentReference<Map<String, dynamic>>, int>{};

      for (final id in productIds) {
        final ref = _products.doc(id);
        final snap = await tx.get(ref);
        if (!snap.exists) {
          throw OrderException('One of the products is no longer available.');
        }
        final p = Product.fromDoc(snap);
        final qty = quantities[id]!;
        if (qty <= 0) continue;
        if (!p.isActive) {
          throw OrderException('${p.name} is not available right now.');
        }
        if (p.quantity < qty) {
          throw OrderException(
            p.quantity == 0
                ? '${p.name} is sold out.'
                : 'Only ${p.quantity} × ${p.name} left.',
          );
        }
        updates[ref] = OrderRules.deductStock(p.quantity, qty);
        items.add(
          OrderItem(
            productId: p.id,
            name: p.name,
            unitPrice: p.price,
            quantity: qty,
          ),
        );
      }
      if (items.isEmpty) throw OrderException('Your cart is empty.');

      for (final e in updates.entries) {
        final sold = quantities[e.key.id]!;
        tx.update(e.key, {
          'quantity': e.value,
          'soldCount': FieldValue.increment(sold),
        });
      }

      final order = VendorOrder(
        id: orderRef.id,
        orderNumber: OrderRules.orderNumberFromId(orderRef.id),
        eventId: event.id,
        eventTitle: event.title,
        vendorId: vendorId,
        vendorName: vendorName,
        studentId: student.uid,
        studentName: student.fullName,
        items: items,
        total: OrderRules.cartTotal(items),
        status: OrderStatus.pending,
        paymentReference: paymentReference,
        boothNumber: boothNumber,
        collectionNote: boothNumber == null
            ? 'Collect at the vendor booth when your order is Ready.'
            : 'Collect at booth $boothNumber when your order is Ready.',
        createdAt: DateTime.now(),
      );
      tx.set(orderRef, order.toMap());
      return order;
    });
  }

  /// Vendor moves the order forward (Pending → Preparing → Ready → Collected).
  Future<void> advance(VendorOrder order) async {
    final next = order.status.next;
    if (next == null || !OrderRules.canTransition(order.status, next)) {
      throw OrderException('Order is already ${order.status.label.toLowerCase()}.');
    }
    await _orders.doc(order.id).update({
      'status': next.value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Cancels an order and restores stock. [byStudent] enforces the stricter
  /// student rule (Pending only).
  Future<void> cancel(VendorOrder order, {required bool byStudent}) async {
    final allowed = byStudent
        ? OrderRules.studentCanCancel(order.status)
        : OrderRules.canTransition(order.status, OrderStatus.cancelled);
    if (!allowed) {
      throw OrderException(
        byStudent
            ? 'Orders can only be cancelled while they are still Pending.'
            : 'This order can no longer be cancelled.',
      );
    }
    final batch = _db.batch();
    batch.update(_orders.doc(order.id), {
      'status': OrderStatus.cancelled.value,
      'updatedAt': FieldValue.serverTimestamp(),
      'cancelledBy': byStudent ? 'student' : 'vendor',
    });
    for (final item in order.items) {
      batch.update(_products.doc(item.productId), {
        'quantity': FieldValue.increment(item.quantity),
        'soldCount': FieldValue.increment(-item.quantity),
      });
    }
    await batch.commit();
  }
}

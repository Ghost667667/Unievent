import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';

class ProductRepository {
  ProductRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _products =>
      _db.collection('products');

  Stream<List<Product>> watchByVendor(String vendorId) => _products
      .where('vendorId', isEqualTo: vendorId)
      .snapshots()
      .map(
        (s) => s.docs.map(Product.fromDoc).toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
      );

  /// Active products for the student-facing menu.
  Stream<List<Product>> watchMenu(String vendorId) => _products
      .where('vendorId', isEqualTo: vendorId)
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map((s) => s.docs.map(Product.fromDoc).toList());

  Future<List<Product>> fetchByVendor(String vendorId) async {
    final snap = await _products.where('vendorId', isEqualTo: vendorId).get();
    return snap.docs.map(Product.fromDoc).toList();
  }

  Future<String> create(Product p) async {
    final ref = _products.doc();
    await ref.set(p.toMap());
    return ref.id;
  }

  Future<void> update(Product p) => _products.doc(p.id).update(p.toMap());

  Future<void> delete(String id) => _products.doc(id).delete();

  /// Quick quantity update from the inventory screen.
  Future<void> setQuantity(String id, int quantity) =>
      _products.doc(id).update({'quantity': quantity < 0 ? 0 : quantity});

  /// Restocks after an order is cancelled.
  Future<void> restock(String id, int qty) => _products.doc(id).update({
        'quantity': FieldValue.increment(qty),
        'soldCount': FieldValue.increment(-qty),
      });
}

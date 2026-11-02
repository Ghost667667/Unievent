import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import 'enums.dart';
import 'firestore_helpers.dart';

class OrderItem extends Equatable {
  const OrderItem({
    required this.productId,
    required this.name,
    required this.unitPrice,
    required this.quantity,
  });

  final String productId;
  final String name;
  final double unitPrice;
  final int quantity;

  double get lineTotal => unitPrice * quantity;

  factory OrderItem.fromMap(Map<String, dynamic> m) => OrderItem(
        productId: m['productId'] as String? ?? '',
        name: m['name'] as String? ?? '',
        unitPrice: toDouble(m['unitPrice']),
        quantity: toInt(m['quantity']),
      );

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'name': name,
        'unitPrice': unitPrice,
        'quantity': quantity,
      };

  @override
  List<Object?> get props => [productId, quantity];
}

/// A student's pre-order from one vendor at one event. `orders/{id}`.
class VendorOrder extends Equatable {
  const VendorOrder({
    required this.id,
    required this.orderNumber,
    required this.eventId,
    required this.eventTitle,
    required this.vendorId,
    required this.vendorName,
    required this.studentId,
    required this.studentName,
    required this.items,
    required this.total,
    required this.status,
    this.paymentReference,
    this.paymentMethod = 'Sandbox card',
    this.collectionNote,
    this.boothNumber,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String orderNumber;
  final String eventId;
  final String eventTitle;
  final String vendorId;
  final String vendorName;
  final String studentId;
  final String studentName;
  final List<OrderItem> items;
  final double total;
  final OrderStatus status;
  final String? paymentReference;
  final String paymentMethod;
  final String? collectionNote;
  final String? boothNumber;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  int get itemCount => items.fold(0, (total, i) => total + i.quantity);

  factory VendorOrder.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      VendorOrder.fromMap(doc.id, doc.data() ?? {});

  factory VendorOrder.fromMap(String id, Map<String, dynamic> m) => VendorOrder(
        id: id,
        orderNumber: m['orderNumber'] as String? ?? '',
        eventId: m['eventId'] as String? ?? '',
        eventTitle: m['eventTitle'] as String? ?? '',
        vendorId: m['vendorId'] as String? ?? '',
        vendorName: m['vendorName'] as String? ?? '',
        studentId: m['studentId'] as String? ?? '',
        studentName: m['studentName'] as String? ?? '',
        items: (m['items'] as List?)
                ?.map((e) => OrderItem.fromMap(Map<String, dynamic>.from(e)))
                .toList() ??
            const [],
        total: toDouble(m['total']),
        status: OrderStatus.fromValue(m['status'] as String?),
        paymentReference: m['paymentReference'] as String?,
        paymentMethod: m['paymentMethod'] as String? ?? 'Sandbox card',
        collectionNote: m['collectionNote'] as String?,
        boothNumber: m['boothNumber'] as String?,
        createdAt: tsToDate(m['createdAt']),
        updatedAt: tsToDate(m['updatedAt']),
      );

  Map<String, dynamic> toMap() => {
        'orderNumber': orderNumber,
        'eventId': eventId,
        'eventTitle': eventTitle,
        'vendorId': vendorId,
        'vendorName': vendorName,
        'studentId': studentId,
        'studentName': studentName,
        'items': items.map((i) => i.toMap()).toList(),
        'total': total,
        'status': status.value,
        'paymentReference': paymentReference,
        'paymentMethod': paymentMethod,
        'collectionNote': collectionNote,
        'boothNumber': boothNumber,
        'createdAt': createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt!),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  @override
  List<Object?> get props => [id, status, total];
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import 'enums.dart';
import 'firestore_helpers.dart';

/// A product a vendor sells. Stored in `products/{id}`.
class Product extends Equatable {
  const Product({
    required this.id,
    required this.vendorId,
    required this.vendorName,
    required this.name,
    required this.price,
    required this.quantity,
    this.description = '',
    this.category = 'Food',
    this.imageUrl,
    this.lowStockThreshold = 5,
    this.soldCount = 0,
    this.isActive = true,
    this.createdAt,
  });

  final String id;
  final String vendorId;
  final String vendorName;
  final String name;
  final String description;
  final String category;

  /// Price in Malaysian Ringgit.
  final double price;
  final int quantity;
  final int lowStockThreshold;
  final int soldCount;
  final String? imageUrl;
  final bool isActive;
  final DateTime? createdAt;

  StockStatus get stockStatus => stockStatusFor(quantity, lowStockThreshold);

  /// Pure function so it can be unit tested without Firestore.
  static StockStatus stockStatusFor(int quantity, int threshold) {
    if (quantity <= 0) return StockStatus.soldOut;
    if (quantity <= threshold) return StockStatus.lowStock;
    return StockStatus.available;
  }

  factory Product.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Product.fromMap(doc.id, doc.data() ?? {});

  factory Product.fromMap(String id, Map<String, dynamic> m) => Product(
        id: id,
        vendorId: m['vendorId'] as String? ?? '',
        vendorName: m['vendorName'] as String? ?? '',
        name: m['name'] as String? ?? '',
        description: m['description'] as String? ?? '',
        category: m['category'] as String? ?? 'Food',
        price: toDouble(m['price']),
        quantity: toInt(m['quantity']),
        lowStockThreshold: toInt(m['lowStockThreshold'], 5),
        soldCount: toInt(m['soldCount']),
        imageUrl: m['imageUrl'] as String?,
        isActive: m['isActive'] as bool? ?? true,
        createdAt: tsToDate(m['createdAt']),
      );

  Map<String, dynamic> toMap() => {
        'vendorId': vendorId,
        'vendorName': vendorName,
        'name': name,
        'nameLower': name.toLowerCase(),
        'description': description,
        'category': category,
        'price': price,
        'quantity': quantity,
        'lowStockThreshold': lowStockThreshold,
        'soldCount': soldCount,
        'imageUrl': imageUrl,
        'isActive': isActive,
        'createdAt': createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt!),
      };

  Product copyWith({
    String? name,
    String? description,
    String? category,
    double? price,
    int? quantity,
    int? lowStockThreshold,
    String? imageUrl,
    bool? isActive,
  }) =>
      Product(
        id: id,
        vendorId: vendorId,
        vendorName: vendorName,
        name: name ?? this.name,
        description: description ?? this.description,
        category: category ?? this.category,
        price: price ?? this.price,
        quantity: quantity ?? this.quantity,
        lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
        soldCount: soldCount,
        imageUrl: imageUrl ?? this.imageUrl,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
      );

  @override
  List<Object?> get props => [id, name, price, quantity];
}

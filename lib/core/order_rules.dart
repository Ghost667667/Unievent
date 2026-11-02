import '../models/enums.dart';
import '../models/order.dart';
import '../models/product.dart';

/// Result of validating a cart against current stock.
class CartValidation {
  const CartValidation({required this.ok, this.problems = const []});
  final bool ok;
  final List<String> problems;
}

/// Pure business rules for orders and inventory.
class OrderRules {
  OrderRules._();

  /// Can the order move from [from] to [to]?
  static bool canTransition(OrderStatus from, OrderStatus to) {
    if (from.isTerminal) return false;
    if (to == OrderStatus.cancelled) {
      // Vendors may cancel until the order is Ready; students may cancel
      // only while Pending (see [studentCanCancel]).
      return from == OrderStatus.pending || from == OrderStatus.preparing;
    }
    return from.next == to;
  }

  static bool studentCanCancel(OrderStatus status) =>
      status == OrderStatus.pending;

  /// Validates requested quantities against stock.
  static CartValidation validateCart(
    Map<String, int> requested,
    List<Product> products,
  ) {
    final problems = <String>[];
    for (final entry in requested.entries) {
      final matches = products.where((p) => p.id == entry.key);
      final product = matches.isEmpty ? null : matches.first;
      if (product == null) {
        problems.add('A product in your cart is no longer available.');
        continue;
      }
      if (entry.value <= 0) {
        problems.add('${product.name}: quantity must be at least 1.');
      } else if (product.quantity <= 0) {
        problems.add('${product.name} is sold out.');
      } else if (entry.value > product.quantity) {
        problems.add(
          '${product.name}: only ${product.quantity} left.',
        );
      }
    }
    return CartValidation(ok: problems.isEmpty, problems: problems);
  }

  static double cartTotal(List<OrderItem> items) =>
      items.fold(0, (sum, i) => sum + i.lineTotal);

  /// New stock level after deducting [qty]; never negative.
  static int deductStock(int current, int qty) {
    if (qty > current) {
      throw StateError('Insufficient stock: requested $qty, available $current');
    }
    return current - qty;
  }

  /// Human-readable order number, e.g. `UE-4F2A9C`.
  static String orderNumberFromId(String id) =>
      'UE-${id.substring(0, id.length < 6 ? id.length : 6).toUpperCase()}';
}

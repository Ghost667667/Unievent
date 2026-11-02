import 'package:flutter_test/flutter_test.dart';
import 'package:unievent/core/order_rules.dart';
import 'package:unievent/core/ticket_codec.dart';
import 'package:unievent/core/validators.dart';
import 'package:unievent/models/models.dart';

void main() {
  group('TicketCodec', () {
    test('generates unique codes of the right length and alphabet', () {
      final a = TicketCodec.generateCode();
      final b = TicketCodec.generateCode();
      expect(a.length, TicketCodec.codeLength);
      expect(a, isNot(b));
      expect(RegExp(r'^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]+$').hasMatch(a), isTrue);
    });

    test('round-trips encode/decode', () {
      final code = TicketCodec.generateCode();
      final payload = TicketCodec.encode(eventId: 'ev1', registrationId: 'ev1_stu1', code: code);
      final decoded = TicketCodec.decode(payload)!;
      expect(decoded.eventId, 'ev1');
      expect(decoded.registrationId, 'ev1_stu1');
      expect(decoded.code, code);
    });

    test('rejects foreign or malformed QR payloads', () {
      expect(TicketCodec.decode('https://example.com'), isNull);
      expect(TicketCodec.decode('UNIEVENT|ev1|reg1'), isNull);
      expect(TicketCodec.decode('UNIEVENT|ev1|reg1|short'), isNull);
      expect(TicketCodec.decode('OTHER|ev1|reg1|ABCDEFGHJKLMNPQR'), isNull);
    });

    test('short number is readable', () {
      expect(TicketCodec.shortNumber('ABCDEFGHJKLMNPQR'), '#ABCD-EF');
    });
  });

  group('OrderStatus transitions', () {
    test('forward pipeline', () {
      expect(OrderStatus.pending.next, OrderStatus.preparing);
      expect(OrderStatus.preparing.next, OrderStatus.ready);
      expect(OrderStatus.ready.next, OrderStatus.collected);
      expect(OrderStatus.collected.next, isNull);
      expect(OrderStatus.cancelled.next, isNull);
    });

    test('canTransition enforces business rules', () {
      expect(OrderRules.canTransition(OrderStatus.pending, OrderStatus.preparing), isTrue);
      expect(OrderRules.canTransition(OrderStatus.pending, OrderStatus.ready), isFalse);
      expect(OrderRules.canTransition(OrderStatus.preparing, OrderStatus.cancelled), isTrue);
      expect(OrderRules.canTransition(OrderStatus.ready, OrderStatus.cancelled), isFalse);
      expect(OrderRules.canTransition(OrderStatus.collected, OrderStatus.cancelled), isFalse);
    });

    test('students may only cancel pending orders', () {
      expect(OrderRules.studentCanCancel(OrderStatus.pending), isTrue);
      expect(OrderRules.studentCanCancel(OrderStatus.preparing), isFalse);
    });
  });

  group('Inventory', () {
    final products = [
      const Product(id: 'p1', vendorId: 'v', vendorName: 'V', name: 'Wrap', price: 9.5, quantity: 3),
      const Product(id: 'p2', vendorId: 'v', vendorName: 'V', name: 'Tote', price: 18, quantity: 0),
    ];

    test('stock status thresholds', () {
      expect(Product.stockStatusFor(0, 5), StockStatus.soldOut);
      expect(Product.stockStatusFor(5, 5), StockStatus.lowStock);
      expect(Product.stockStatusFor(6, 5), StockStatus.available);
    });

    test('validateCart blocks sold-out and over-stock', () {
      final ok = OrderRules.validateCart({'p1': 2}, products);
      expect(ok.ok, isTrue);
      final bad = OrderRules.validateCart({'p1': 4, 'p2': 1}, products);
      expect(bad.ok, isFalse);
      expect(bad.problems.length, 2);
    });

    test('deductStock never goes negative', () {
      expect(OrderRules.deductStock(3, 3), 0);
      expect(() => OrderRules.deductStock(3, 4), throwsStateError);
    });

    test('cart total', () {
      final items = [
        const OrderItem(productId: 'p1', name: 'Wrap', unitPrice: 9.5, quantity: 2),
        const OrderItem(productId: 'p3', name: 'Lassi', unitPrice: 5, quantity: 1),
      ];
      expect(OrderRules.cartTotal(items), 24);
    });
  });

  group('Validators', () {
    test('email', () {
      expect(Validators.email('massa@apu.edu.my'), isNull);
      expect(Validators.email('nope'), isNotNull);
    });
    test('password strength', () {
      expect(Validators.password('abc'), isNotNull);
      expect(Validators.password('abcdefgh'), isNotNull);
      expect(Validators.password('Abcdefg1'), isNull);
    });
    test('TP number format', () {
      expect(Validators.studentId('TP087014'), isNull);
      expect(Validators.studentId('tp087014'), isNull);
      expect(Validators.studentId('087014'), isNotNull);
    });
  });
}

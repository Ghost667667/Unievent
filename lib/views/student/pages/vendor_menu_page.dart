import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/formatters.dart';
import '../../../models/models.dart';
import '../../../navigation/app_router.dart';
import '../../../services/app_services.dart';
import '../../../services/integration_services.dart';
import '../../../theme/app_colors.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../viewmodels/student/student_viewmodels.dart';
import '../../../widgets/common_widgets.dart';

/// Vendor menu with cart and sandbox checkout.
class VendorMenuPage extends StatelessWidget {
  const VendorMenuPage({super.key, required this.eventId, required this.vendorId});
  final String eventId;
  final String vendorId;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthViewModel>().user!;
    return ChangeNotifierProvider(
      create: (ctx) => VendorMenuViewModel(ctx.read<AppServices>(), user, eventId, vendorId),
      child: const _MenuBody(),
    );
  }
}

class _MenuBody extends StatelessWidget {
  const _MenuBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<VendorMenuViewModel>();
    final theme = Theme.of(context);
    final vendorName = vm.vendor?.displayName ?? (vm.products.isEmpty ? 'Vendor' : vm.products.first.vendorName);

    if (vm.error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && vm.error != null) {
          showAppSnackBar(context, vm.error!, error: true);
          vm.clearError();
        }
      });
    }

    final grouped = <String, List<Product>>{};
    for (final p in vm.products) {
      grouped.putIfAbsent(p.category, () => []).add(p);
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(vendorName),
            if (vm.event != null)
              Text(
                '${vm.event!.title}${vm.application?.boothNumber != null ? ' • Booth ${vm.application!.boothNumber}' : ''}',
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
      body: vm.loading
          ? const LoadingView()
          : vm.products.isEmpty
              ? const EmptyState(icon: Icons.menu_book_outlined, title: 'Menu not published yet')
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceTint,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 18, color: AppColors.indigo),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Pre-order now and collect at the booth when your order is marked Ready. Payments are simulated (sandbox).',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (final entry in grouped.entries) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(0, 20, 0, 10),
                        child: Text(entry.key, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      ),
                      ...entry.value.map(
                        (p) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _MenuItem(product: p, vm: vm),
                        ),
                      ),
                    ],
                  ],
                ),
      bottomSheet: vm.cartCount == 0 ? null : _CartBar(vm: vm),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.product, required this.vm});
  final Product product;
  final VendorMenuViewModel vm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final qty = vm.qtyOf(product.id);
    final status = product.stockStatus;
    final soldOut = status == StockStatus.soldOut;

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 84,
              height: 84,
              child: product.imageUrl == null
                  ? Container(color: AppColors.surfaceTint, child: const Icon(Icons.fastfood_outlined, color: AppColors.indigo))
                  : CachedNetworkImage(
                      imageUrl: product.imageUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(color: AppColors.surfaceTint, child: const Icon(Icons.fastfood_outlined, color: AppColors.indigo)),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, decoration: soldOut ? TextDecoration.lineThrough : null)),
                if (product.description.isNotEmpty)
                  Text(product.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(Fmt.rm(product.price), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: AppColors.indigo)),
                    const SizedBox(width: 8),
                    if (status != StockStatus.available)
                      StatusChip(
                        label: soldOut ? 'Sold Out' : 'Low Stock • ${product.quantity} left',
                        color: soldOut ? AppColors.red : AppColors.orange,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: soldOut
                      ? const Text('Unavailable', style: TextStyle(color: AppColors.textSecondary, fontSize: 12))
                      : qty == 0
                          ? FilledButton.tonal(
                              onPressed: () => vm.increment(product),
                              style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                              child: const Text('Add'),
                            )
                          : Container(
                              decoration: BoxDecoration(color: AppColors.surfaceTint, borderRadius: BorderRadius.circular(999)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(icon: const Icon(Icons.remove, size: 18), onPressed: () => vm.decrement(product), visualDensity: VisualDensity.compact),
                                  Text('$qty', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                                  IconButton(icon: const Icon(Icons.add, size: 18), onPressed: qty >= product.quantity ? null : () => vm.increment(product), visualDensity: VisualDensity.compact),
                                ],
                              ),
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CartBar extends StatelessWidget {
  const _CartBar({required this.vm});
  final VendorMenuViewModel vm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(20, 14, 20, 14 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [BoxShadow(color: AppColors.midnight.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, -6))],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${vm.cartCount} item${vm.cartCount == 1 ? '' : 's'}', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                Text(Fmt.rm(vm.total), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          TextButton(onPressed: vm.clearCart, child: const Text('Clear')),
          const SizedBox(width: 6),
          FilledButton.icon(
            onPressed: () => _checkout(context),
            icon: const Icon(Icons.shopping_bag_outlined),
            label: const Text('Checkout'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
          ),
        ],
      ),
    );
  }

  Future<void> _checkout(BuildContext context) async {
    final order = await showModalBottomSheet<VendorOrder>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ChangeNotifierProvider.value(value: vm, child: const _CheckoutSheet()),
    );
    if (order != null && context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: AppColors.green, size: 48),
          title: const Text('Order placed!'),
          content: Text(
            '${order.orderNumber} • ${Fmt.rm(order.total)}\n\n${order.collectionNote ?? ''}\nWe will notify you when it is ready.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Keep browsing')),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.go(Routes.studentOrders);
              },
              child: const Text('Track order'),
            ),
          ],
        ),
      );
    }
  }
}

class _CheckoutSheet extends StatefulWidget {
  const _CheckoutSheet();

  @override
  State<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<_CheckoutSheet> {
  final _card = TextEditingController(text: '4242');

  @override
  void dispose() {
    _card.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<VendorMenuViewModel>();
    final theme = Theme.of(context);
    final lines = vm.cart.entries.map((e) {
      final p = vm.products.firstWhere((x) => x.id == e.key);
      return (p, e.value);
    }).toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Checkout', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: AppColors.orange.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                const Icon(Icons.science_outlined, size: 16, color: AppColors.orange),
                const SizedBox(width: 6),
                Expanded(child: Text(SandboxPaymentService.label, style: theme.textTheme.labelSmall?.copyWith(color: AppColors.orange, fontWeight: FontWeight.w700))),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ...lines.map(
            (l) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Text('${l.$2}×', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(l.$1.name)),
                  Text(Fmt.rm(l.$1.price * l.$2)),
                ],
              ),
            ),
          ),
          const Divider(height: 20),
          Row(
            children: [
              Text('Total', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(Fmt.rm(vm.total), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: AppColors.indigo)),
            ],
          ),
          const SizedBox(height: 16),
          Text('Payment method', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: SandboxPaymentService.methods.map((m) => ButtonSegment(value: m, label: Text(m.replaceFirst('Sandbox ', '')))).toList(),
            selected: {vm.paymentMethod},
            onSelectionChanged: (s) => vm.setPaymentMethod(s.first),
          ),
          if (vm.paymentMethod == SandboxPaymentService.methods.first) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _card,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: const InputDecoration(
                labelText: 'Test card — last 4 digits',
                helperText: 'Any digits succeed; 0000 simulates a declined card.',
                prefixIcon: Icon(Icons.credit_card),
                counterText: '',
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (vm.error != null) ...[
            Text(vm.error!, style: const TextStyle(color: AppColors.red)),
            const SizedBox(height: 8),
          ],
          BusyButton(
            label: 'Pay ${Fmt.rm(vm.total)} (sandbox)',
            icon: Icons.lock_outline,
            busy: vm.busy,
            onPressed: () async {
              final order = await vm.checkout(cardLastDigits: _card.text);
              if (order != null && context.mounted) Navigator.pop(context, order);
            },
          ),
        ],
      ),
    );
  }
}

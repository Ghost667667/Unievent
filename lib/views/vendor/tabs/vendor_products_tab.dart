import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/formatters.dart';
import '../../../models/models.dart';
import '../../../navigation/app_router.dart';
import '../../../theme/app_colors.dart';
import '../../../viewmodels/vendor/vendor_viewmodels.dart';
import '../../../widgets/common_widgets.dart';

/// Product Management + Inventory view.
class VendorProductsTab extends StatelessWidget {
  const VendorProductsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<VendorDashboardViewModel>();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Products'),
          bottom: const TabBar(tabs: [Tab(text: 'Catalogue'), Tab(text: 'Inventory')]),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push(Routes.productNew),
          icon: const Icon(Icons.add),
          label: const Text('Add product'),
        ),
        body: vm.loading
            ? const LoadingView()
            : TabBarView(
                children: [
                  _Catalogue(vm: vm),
                  _Inventory(vm: vm),
                ],
              ),
      ),
    );
  }
}

class _Catalogue extends StatelessWidget {
  const _Catalogue({required this.vm});
  final VendorDashboardViewModel vm;

  @override
  Widget build(BuildContext context) {
    if (vm.products.isEmpty) {
      return EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'No products yet',
        message: 'Add the items you sell so students can pre-order before the event.',
        action: FilledButton.icon(onPressed: () => context.push(Routes.productNew), icon: const Icon(Icons.add), label: const Text('Add first product')),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 240, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.72),
      itemCount: vm.products.length,
      itemBuilder: (context, i) => ProductCard(product: vm.products[i], vm: vm),
    );
  }
}

/// Product card: picture, name, price, quantity, stock status, edit, delete.
class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, required this.vm});
  final Product product;
  final VendorDashboardViewModel vm;

  static Color stockColor(StockStatus s) => switch (s) {
        StockStatus.available => AppColors.green,
        StockStatus.lowStock => AppColors.orange,
        StockStatus.soldOut => AppColors.red,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = product;
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () => context.push(Routes.productEdit(p.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  child: p.imageUrl == null
                      ? Container(color: AppColors.surfaceTint, child: const Icon(Icons.fastfood_outlined, color: AppColors.indigo, size: 36))
                      : CachedNetworkImage(imageUrl: p.imageUrl!, fit: BoxFit.cover, errorWidget: (_, __, ___) => Container(color: AppColors.surfaceTint, child: const Icon(Icons.broken_image_outlined, color: AppColors.indigo))),
                ),
                Positioned(
                  left: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: stockColor(p.stockStatus), borderRadius: BorderRadius.circular(999)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.white, shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        Text(p.stockStatus.label, style: const TextStyle(color: AppColors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
                if (!p.isActive)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: AppColors.midnight, borderRadius: BorderRadius.circular(999)),
                      child: const Text('Hidden', style: TextStyle(color: AppColors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                Text(p.category, style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(Fmt.rm(p.price), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: AppColors.indigo)),
                    const Spacer(),
                    Text('${p.quantity} left', style: theme.textTheme.labelSmall?.copyWith(color: stockColor(p.stockStatus), fontWeight: FontWeight.w700)),
                  ],
                ),
                Row(
                  children: [
                    IconButton(tooltip: 'Edit', visualDensity: VisualDensity.compact, icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => context.push(Routes.productEdit(p.id))),
                    IconButton(
                      tooltip: p.isActive ? 'Hide from menu' : 'Show on menu',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(p.isActive ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                      onPressed: () => vm.toggleActive(p),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Delete',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.red),
                      onPressed: () async {
                        final ok = await confirmDialog(context, title: 'Delete ${p.name}?', message: 'Existing orders keep their line items; the product disappears from your menu.', confirmLabel: 'Delete', destructive: true);
                        if (ok) await vm.deleteProduct(p);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Inventory extends StatelessWidget {
  const _Inventory({required this.vm});
  final VendorDashboardViewModel vm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sorted = [...vm.products]..sort((a, b) => a.quantity.compareTo(b.quantity));
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
      children: [
        Row(
          children: [
            Expanded(child: StatCard(label: 'Total stock', value: '${vm.totalStock}', icon: Icons.inventory_outlined)),
            const SizedBox(width: 10),
            Expanded(child: StatCard(label: 'Low stock', value: '${vm.lowStock.length}', icon: Icons.warning_amber_rounded, color: AppColors.orange)),
            const SizedBox(width: 10),
            Expanded(child: StatCard(label: 'Sold out', value: '${vm.soldOut.length}', icon: Icons.remove_shopping_cart_outlined, color: AppColors.red)),
          ],
        ),
        const SizedBox(height: 16),
        Text('Quick quantity updates', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        Text('Stock is also reduced automatically when students pre-order (backend transaction).', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 10),
        if (sorted.isEmpty) const Text('No products yet.', style: TextStyle(color: AppColors.textSecondary)),
        ...sorted.map(
          (p) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: ProductCard.stockColor(p.stockStatus), shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                        Text('${p.stockStatus.label} • sold ${p.soldCount}', style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.remove_circle_outline), onPressed: p.quantity <= 0 ? null : () => vm.setQuantity(p, p.quantity - 1)),
                  SizedBox(
                    width: 44,
                    child: GestureDetector(
                      onTap: () => _editQty(context, p),
                      child: Text('${p.quantity}', textAlign: TextAlign.center, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    ),
                  ),
                  IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.add_circle_outline), onPressed: () => vm.setQuantity(p, p.quantity + 1)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _editQty(BuildContext context, Product p) async {
    final c = TextEditingController(text: '${p.quantity}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Set quantity — ${p.name}'),
        content: TextField(controller: c, keyboardType: TextInputType.number, autofocus: true, decoration: const InputDecoration(labelText: 'Quantity')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    final n = int.tryParse(c.text);
    if (ok == true && n != null && n >= 0) await vm.setQuantity(p, n);
  }
}

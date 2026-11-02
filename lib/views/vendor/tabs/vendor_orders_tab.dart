import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/models.dart';
import '../../../theme/app_colors.dart';
import '../../../viewmodels/vendor/vendor_viewmodels.dart';
import '../../../widgets/common_widgets.dart';
import '../../student/tabs/orders_tab.dart' show OrderCard;

/// Order Management: Pending → Preparing → Ready → Collected, plus cancelled.
class VendorOrdersTab extends StatelessWidget {
  const VendorOrdersTab({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<VendorDashboardViewModel>();
    final groups = <OrderStatus, List<VendorOrder>>{
      for (final s in OrderStatus.values) s: vm.orders.where((o) => o.status == s).toList(),
    };
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Orders'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: OrderStatus.values.map((s) => Tab(text: '${s.label} (${groups[s]!.length})')).toList(),
          ),
        ),
        body: vm.loading
            ? const LoadingView()
            : Column(
                children: [
                  if (vm.error != null)
                    Container(
                      width: double.infinity,
                      color: AppColors.red.withValues(alpha: 0.1),
                      padding: const EdgeInsets.all(10),
                      child: Text(vm.error!, style: const TextStyle(color: AppColors.red)),
                    ),
                  Expanded(
                    child: TabBarView(
                      children: OrderStatus.values.map((s) => _OrderList(orders: groups[s]!, status: s, vm: vm)).toList(),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _OrderList extends StatelessWidget {
  const _OrderList({required this.orders, required this.status, required this.vm});
  final List<VendorOrder> orders;
  final OrderStatus status;
  final VendorDashboardViewModel vm;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No ${status.label.toLowerCase()} orders',
        message: status == OrderStatus.pending ? 'New pre-orders from students land here. Tap "Mark Preparing" to start.' : null,
      );
    }
    // Oldest first for the kitchen queue; newest first for history.
    final list = [...orders];
    if (!status.isTerminal) {
      list.sort((a, b) => (a.createdAt ?? DateTime(2000)).compareTo(b.createdAt ?? DateTime(2000)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final o = list[i];
        return OrderCard(
          order: o,
          onAdvance: vm.busy
              ? null
              : () async {
                  final ok = await vm.advanceOrder(o);
                  if (context.mounted && ok && o.status.next == OrderStatus.ready) {
                    showAppSnackBar(context, '${o.studentName} has been notified that ${o.orderNumber} is ready.', success: true);
                  }
                },
          onCancel: vm.busy
              ? null
              : () async {
                  final ok = await confirmDialog(context, title: 'Cancel ${o.orderNumber}?', message: 'Stock is restored and the student is notified and refunded (sandbox).', confirmLabel: 'Cancel order', destructive: true);
                  if (ok) await vm.cancelOrder(o);
                },
        );
      },
    );
  }
}

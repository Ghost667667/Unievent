import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/formatters.dart';
import '../../../core/order_rules.dart';
import '../../../models/models.dart';
import '../../../navigation/app_router.dart';
import '../../../repositories/order_repository.dart';
import '../../../services/app_services.dart';
import '../../../theme/app_colors.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../widgets/common_widgets.dart';

/// Student Orders: track pre-orders and find vendors to order from.
class StudentOrdersTab extends StatelessWidget {
  const StudentOrdersTab({super.key});

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();
    final user = context.watch<AuthViewModel>().user!;

    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
      body: StreamBuilder<List<VendorOrder>>(
        stream: services.orders.watchByStudent(user.uid),
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(message: snap.error.toString());
          if (!snap.hasData) return const LoadingView();
          final orders = snap.data!;
          final active = orders.where((o) => !o.status.isTerminal).toList();
          final past = orders.where((o) => o.status.isTerminal).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              _OrderHowTo(onBrowse: () => context.go(Routes.studentMyEvents)),
              if (orders.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: EmptyState(
                    icon: Icons.shopping_bag_outlined,
                    title: 'No orders yet',
                    message: 'Open an event → Vendors tab → pick a vendor to pre-order and skip the queue.',
                  ),
                ),
              if (active.isNotEmpty) ...[
                const SectionTitle('Active orders'),
                ...active.map(
                  (o) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: OrderCard(order: o, studentView: true),
                  ),
                ),
              ],
              if (past.isNotEmpty) ...[
                const SectionTitle('Past orders'),
                ...past.map(
                  (o) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: OrderCard(order: o, studentView: true),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _OrderHowTo extends StatelessWidget {
  const _OrderHowTo({required this.onBrowse});
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      color: AppColors.surfaceTint,
      child: Row(
        children: [
          const Icon(Icons.fastfood_outlined, color: AppColors.indigo, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pre-order and skip the queue', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                Text(
                  'Browse vendor menus from any event you are attending.',
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onBrowse, child: const Text('My Events')),
        ],
      ),
    );
  }
}

/// Order card shared by students (track) and vendors (manage).
class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    this.studentView = false,
    this.onAdvance,
    this.onCancel,
  });

  final VendorOrder order;
  final bool studentView;
  final VoidCallback? onAdvance;
  final VoidCallback? onCancel;

  static Color colorFor(OrderStatus s) => switch (s) {
        OrderStatus.pending => AppColors.textSecondary,
        OrderStatus.preparing => AppColors.orange,
        OrderStatus.ready => AppColors.green,
        OrderStatus.collected => AppColors.indigo,
        OrderStatus.cancelled => AppColors.red,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final services = context.read<AppServices>();
    final color = colorFor(order.status);

    Future<void> studentCancel() async {
      final ok = await confirmDialog(
        context,
        title: 'Cancel order?',
        message: 'Your sandbox payment will be refunded and stock released.',
        confirmLabel: 'Cancel order',
        destructive: true,
      );
      if (!ok || !context.mounted) return;
      try {
        await services.orders.cancel(order, byStudent: true);
        if (context.mounted) showAppSnackBar(context, 'Order ${order.orderNumber} cancelled.', success: true);
      } on OrderException catch (e) {
        if (context.mounted) showAppSnackBar(context, e.message, error: true);
      }
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.orderNumber,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.5),
                    ),
                    Text(
                      studentView ? order.vendorName : order.studentName,
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              StatusChip(label: order.status.label, color: color),
            ],
          ),
          const SizedBox(height: 10),
          _StatusTimeline(status: order.status),
          const SizedBox(height: 10),
          ...order.items.map(
            (i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Text('${i.quantity}×', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(i.name, style: theme.textTheme.bodySmall)),
                  Text(Fmt.rm(i.lineTotal), style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
          const Divider(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${order.eventTitle}${order.boothNumber != null ? ' • Booth ${order.boothNumber}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ),
              Text('Total ${Fmt.rm(order.total)}', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          if (order.status == OrderStatus.ready && studentView) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active, color: AppColors.green, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(order.collectionNote ?? 'Ready for collection!', style: theme.textTheme.bodySmall)),
                ],
              ),
            ),
          ],
          if (studentView && OrderRules.studentCanCancel(order.status))
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: studentCancel,
                style: TextButton.styleFrom(foregroundColor: AppColors.red),
                child: const Text('Cancel order'),
              ),
            ),
          if (!studentView && !order.status.isTerminal) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (OrderRules.canTransition(order.status, OrderStatus.cancelled))
                  TextButton(
                    onPressed: onCancel,
                    style: TextButton.styleFrom(foregroundColor: AppColors.red),
                    child: const Text('Cancel'),
                  ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: onAdvance,
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: Text('Mark ${order.status.next!.label}'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.status});
  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    if (status == OrderStatus.cancelled) {
      return Text(
        'This order was cancelled.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.red),
      );
    }
    const steps = [OrderStatus.pending, OrderStatus.preparing, OrderStatus.ready, OrderStatus.collected];
    final idx = steps.indexOf(status);
    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final done = (i ~/ 2) < idx;
          return Expanded(
            child: Container(height: 3, color: done ? AppColors.indigo : AppColors.divider),
          );
        }
        final s = i ~/ 2;
        final done = s <= idx;
        return Column(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? AppColors.indigo : AppColors.white,
                border: Border.all(color: done ? AppColors.indigo : AppColors.divider, width: 2),
              ),
              child: done ? const Icon(Icons.check, size: 12, color: AppColors.white) : null,
            ),
            const SizedBox(height: 3),
            Text(
              steps[s].label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 9,
                    color: done ? AppColors.indigo : AppColors.textSecondary,
                    fontWeight: s == idx ? FontWeight.w700 : FontWeight.w500,
                  ),
            ),
          ],
        );
      }),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../navigation/app_router.dart';
import '../../services/app_services.dart';
import '../../theme/app_colors.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/vendor/vendor_viewmodels.dart';
import '../../widgets/common_widgets.dart';
import '../shared/notifications_page.dart';
import '../shared/role_shell.dart';
import '../student/tabs/orders_tab.dart' show OrderCard;

export 'tabs/vendor_events_tab.dart';
export 'tabs/vendor_orders_tab.dart';
export 'tabs/vendor_products_tab.dart';
export 'tabs/vendor_profile_tab.dart';

/// Vendor shell: Home | Products | Orders | Events | Profile.
class VendorShell extends StatelessWidget {
  const VendorShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthViewModel>().user!;
    return ChangeNotifierProvider(
      key: ValueKey('vendor_${user.uid}'),
      create: (ctx) => VendorDashboardViewModel(ctx.read<AppServices>(), user),
      child: RoleShell(
        shell: shell,
        destinations: const [
          ShellDestination(label: 'Home', icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard),
          ShellDestination(label: 'Products', icon: Icons.inventory_2_outlined, selectedIcon: Icons.inventory_2),
          ShellDestination(label: 'Orders', icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long),
          ShellDestination(label: 'Events', icon: Icons.event_outlined, selectedIcon: Icons.event),
          ShellDestination(label: 'Profile', icon: Icons.person_outline, selectedIcon: Icons.person),
        ],
      ),
    );
  }
}

class VendorHomeTab extends StatelessWidget {
  const VendorHomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthViewModel>().user!;
    final vm = context.watch<VendorDashboardViewModel>();
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: GradientHeader(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Welcome, ${user.displayName}!', style: theme.textTheme.headlineSmall?.copyWith(color: AppColors.white, fontWeight: FontWeight.w700)),
                        Text('Here is how your stall is doing.', style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.white.withValues(alpha: 0.9))),
                      ],
                    ),
                  ),
                  const NotificationBell(),
                  UserAvatar(name: user.displayName, photoUrl: user.businessImageUrl ?? user.photoUrl, onTap: () => context.go(Routes.vendorProfile)),
                ],
              ),
            ),
          ),
          if (vm.loading)
            const SliverFillRemaining(child: LoadingView())
          else ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              sliver: SliverGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.25,
                children: [
                  StatCard(label: 'Total Sales (RM)', value: Fmt.rm(vm.totalSales).replaceFirst('RM ', ''), icon: Icons.payments_outlined, color: AppColors.green, onTap: () => context.push(Routes.vendorAnalytics)),
                  StatCard(label: 'Total Orders', value: '${vm.totalOrders}', icon: Icons.receipt_long_outlined, onTap: () => context.go(Routes.vendorOrders)),
                  StatCard(label: 'Events Participated', value: '${vm.eventsParticipated}', icon: Icons.event_available_outlined, color: AppColors.royalViolet, onTap: () => context.go(Routes.vendorEvents)),
                  StatCard(label: 'Available Products', value: '${vm.availableProducts}', icon: Icons.inventory_2_outlined, color: AppColors.electricBlue, onTap: () => context.go(Routes.vendorProducts)),
                ],
              ),
            ),
            const SliverToBoxAdapter(child: SectionTitle('Quick actions')),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(child: QuickAction(label: 'Add Product', icon: Icons.add_box_outlined, onTap: () => context.push(Routes.productNew))),
                    Expanded(child: QuickAction(label: 'Manage Products', icon: Icons.inventory_2_outlined, color: AppColors.electricBlue, onTap: () => context.go(Routes.vendorProducts))),
                    Expanded(child: QuickAction(label: 'View Orders', icon: Icons.receipt_long_outlined, color: AppColors.green, onTap: () => context.go(Routes.vendorOrders))),
                    Expanded(child: QuickAction(label: 'Apply to Event', icon: Icons.event_outlined, color: AppColors.orange, onTap: () => context.go(Routes.vendorEvents))),
                  ],
                ),
              ),
            ),
            if (vm.lowStock.isNotEmpty || vm.soldOut.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: AppCard(
                    color: AppColors.orange.withValues(alpha: 0.1),
                    onTap: () => context.go(Routes.vendorProducts),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppColors.orange),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${vm.lowStock.length} low stock • ${vm.soldOut.length} sold out — update inventory',
                            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: AppColors.orange),
                      ],
                    ),
                  ),
                ),
              ),
            SliverToBoxAdapter(child: SectionTitle('Upcoming events', action: 'Browse', onAction: () => context.go(Routes.vendorEvents))),
            if (vm.upcomingParticipations.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text('You have no approved events yet. Browse events accepting vendors and apply.', style: TextStyle(color: AppColors.textSecondary)),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList.separated(
                  itemCount: vm.upcomingParticipations.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final a = vm.upcomingParticipations[i];
                    return AppCard(
                      padding: const EdgeInsets.all(14),
                      onTap: () => context.push(Routes.vendorEventDetails(a.eventId)),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: AppColors.green.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.storefront, color: AppColors.green),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(a.eventTitle, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                                Text(
                                  '${a.eventStartTime == null ? '' : '${Fmt.date(a.eventStartTime!)} • '}Booth ${a.boothNumber ?? 'TBC'} • Arrive ${a.arrivalTime ?? 'TBC'}',
                                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          const StatusChip(label: 'Approved', color: AppColors.green),
                        ],
                      ),
                    );
                  },
                ),
              ),
            SliverToBoxAdapter(child: SectionTitle('Recent orders', action: 'All orders', onAction: () => context.go(Routes.vendorOrders))),
            if (vm.recentOrders.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text('Pre-orders from students will appear here.', style: TextStyle(color: AppColors.textSecondary)),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverList.separated(
                  itemCount: vm.recentOrders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final o = vm.recentOrders[i];
                    return OrderCard(
                      order: o,
                      onAdvance: () => vm.advanceOrder(o),
                      onCancel: () async {
                        final ok = await confirmDialog(context, title: 'Cancel order ${o.orderNumber}?', message: 'Stock will be restored and the student notified.', confirmLabel: 'Cancel order', destructive: true);
                        if (ok) await vm.cancelOrder(o);
                      },
                    );
                  },
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        ],
      ),
    );
  }
}

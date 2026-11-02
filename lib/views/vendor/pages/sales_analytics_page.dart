import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/formatters.dart';
import '../../../services/app_services.dart';
import '../../../theme/app_colors.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../viewmodels/vendor/vendor_viewmodels.dart';
import '../../../widgets/common_widgets.dart';

/// Sales analytics: totals, bestsellers, cancelled orders, remaining
/// inventory and per-event performance with simple charts.
class SalesAnalyticsPage extends StatelessWidget {
  const SalesAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthViewModel>().user!;
    final services = context.read<AppServices>();
    final existing = context.read<VendorDashboardViewModel?>();
    const body = _AnalyticsBody();
    if (existing != null) return body;
    return ChangeNotifierProvider(create: (_) => VendorDashboardViewModel(services, user), child: body);
  }
}

class _AnalyticsBody extends StatelessWidget {
  const _AnalyticsBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<VendorDashboardViewModel>();
    final theme = Theme.of(context);
    if (vm.loading) return Scaffold(appBar: AppBar(title: const Text('Sales Analytics')), body: const LoadingView());

    final last7 = vm.salesLast7Days;
    final maxY = last7.fold<double>(0, (m, e) => e.$2 > m ? e.$2 : m);
    final byEvent = vm.salesByEvent.entries.toList()..sort((a, b) => b.value.$2.compareTo(a.value.$2));

    return Scaffold(
      appBar: AppBar(title: const Text('Sales Analytics')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: [
              StatCard(label: 'Total sales', value: Fmt.rm(vm.totalSales), icon: Icons.payments_outlined, color: AppColors.green),
              StatCard(label: 'Orders', value: '${vm.totalOrders}', icon: Icons.receipt_long_outlined),
              StatCard(label: 'Cancelled orders', value: '${vm.cancelledOrders}', icon: Icons.cancel_outlined, color: AppColors.red),
              StatCard(label: 'Remaining inventory', value: '${vm.totalStock} units', icon: Icons.inventory_2_outlined, color: AppColors.electricBlue),
            ],
          ),
          const SizedBox(height: 20),
          _Section(
            'Sales — last 7 days',
            child: SizedBox(
              height: 190,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY <= 0 ? 50 : maxY * 1.25,
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (v, _) => Text(v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toStringAsFixed(0), style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= last7.length) return const SizedBox.shrink();
                          return Padding(padding: const EdgeInsets.only(top: 4), child: Text(Fmt.shortDate(last7[i].$1), style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)));
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(Fmt.rm(s.y), const TextStyle(color: AppColors.white, fontSize: 11))).toList(),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [for (var i = 0; i < last7.length; i++) FlSpot(i.toDouble(), last7[i].$2)],
                      isCurved: true,
                      color: AppColors.indigo,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(show: true, gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.indigo.withValues(alpha: 0.3), AppColors.indigo.withValues(alpha: 0)])),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _Section(
            'Bestselling products',
            child: vm.bestsellers.isEmpty
                ? const Text('No completed orders yet.', style: TextStyle(color: AppColors.textSecondary))
                : Column(
                    children: vm.bestsellers.take(6).toList().asMap().entries.map((entry) {
                      final i = entry.key;
                      final b = entry.value;
                      final maxQty = vm.bestsellers.first.$2;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            SizedBox(width: 22, child: Text('${i + 1}.', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800, color: AppColors.indigo))),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(b.$1, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 3),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(value: maxQty == 0 ? 0 : b.$2 / maxQty, minHeight: 6, backgroundColor: AppColors.divider, color: AppColors.orange),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('${b.$2} sold', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                                Text(Fmt.rm(b.$3), style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textSecondary)),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 20),
          _Section(
            'Event-specific performance',
            child: byEvent.isEmpty
                ? const Text('Sales are grouped by event once orders come in.', style: TextStyle(color: AppColors.textSecondary))
                : Column(
                    children: byEvent
                        .map(
                          (e) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                Expanded(child: Text(e.key, style: theme.textTheme.bodyMedium)),
                                Text('${e.value.$1} orders', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                                const SizedBox(width: 10),
                                Text(Fmt.rm(e.value.$2), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
          const SizedBox(height: 20),
          _Section(
            'Remaining inventory',
            child: vm.products.isEmpty
                ? const Text('No products.', style: TextStyle(color: AppColors.textSecondary))
                : Column(
                    children: vm.products
                        .map(
                          (p) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(child: Text(p.name, style: theme.textTheme.bodyMedium)),
                                StatusChip(
                                  label: '${p.quantity} left',
                                  color: p.quantity <= 0 ? AppColors.red : p.quantity <= p.lowStockThreshold ? AppColors.orange : AppColors.green,
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, {required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

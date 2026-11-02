import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/formatters.dart';
import '../../../core/validators.dart';
import '../../../models/models.dart';
import '../../../services/app_services.dart';
import '../../../theme/app_colors.dart';
import '../../../viewmodels/organiser/organiser_viewmodels.dart';
import '../../../widgets/common_widgets.dart';

/// Budget management: planned vs actual per category, receipts.
class BudgetPage extends StatelessWidget {
  const BudgetPage({super.key, required this.eventId});
  final String eventId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => BudgetViewModel(ctx.read<AppServices>(), eventId),
      child: const _BudgetBody(),
    );
  }
}

class _BudgetBody extends StatelessWidget {
  const _BudgetBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<BudgetViewModel>();
    final theme = Theme.of(context);
    final variance = vm.planned - vm.actual;

    return Scaffold(
      appBar: AppBar(title: const Text('Budget')),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _edit(context, vm, null), icon: const Icon(Icons.add), label: const Text('Budget line')),
      body: vm.loading
          ? const LoadingView()
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 90),
              children: [
                Row(
                  children: [
                    Expanded(child: StatCard(label: 'Planned', value: Fmt.rm(vm.planned), icon: Icons.flag_outlined)),
                    const SizedBox(width: 12),
                    Expanded(child: StatCard(label: 'Actual', value: Fmt.rm(vm.actual), icon: Icons.receipt_long_outlined, color: AppColors.electricBlue)),
                  ],
                ),
                const SizedBox(height: 12),
                AppCard(
                  color: (variance >= 0 ? AppColors.green : AppColors.red).withValues(alpha: 0.1),
                  child: Row(
                    children: [
                      Icon(variance >= 0 ? Icons.trending_down : Icons.trending_up, color: variance >= 0 ? AppColors.green : AppColors.red),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          variance >= 0 ? '${Fmt.rm(variance)} under budget' : '${Fmt.rm(-variance)} over budget',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: variance >= 0 ? AppColors.green : AppColors.red),
                        ),
                      ),
                    ],
                  ),
                ),
                if (vm.byCategory.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text('Planned vs actual by category', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  AppCard(child: SizedBox(height: 220, child: _BudgetChart(data: vm.byCategory))),
                ],
                const SizedBox(height: 18),
                Text('Budget lines', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                if (vm.lines.isEmpty)
                  const Text('Add planned expenses now; record actual spending and attach receipts as the event progresses.', style: TextStyle(color: AppColors.textSecondary))
                else
                  ...vm.lines.map(
                    (l) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppCard(
                        onTap: () => _edit(context, vm, l),
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(l.description.isEmpty ? l.category : l.description, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                                  Text(l.category, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Text('Planned ${Fmt.rm(l.planned)}', style: theme.textTheme.labelSmall),
                                      const SizedBox(width: 10),
                                      Text('Actual ${Fmt.rm(l.actual)}', style: theme.textTheme.labelSmall?.copyWith(color: l.actual > l.planned ? AppColors.red : AppColors.green, fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: l.receiptUrl == null ? 'Attach receipt' : 'View receipt',
                              icon: Icon(l.receiptUrl == null ? Icons.add_a_photo_outlined : Icons.receipt, color: l.receiptUrl == null ? AppColors.textSecondary : AppColors.green),
                              onPressed: () => l.receiptUrl == null ? vm.attachReceipt(l) : _viewReceipt(context, l.receiptUrl!),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  void _viewReceipt(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: ClipRRect(borderRadius: BorderRadius.circular(16), child: InteractiveViewer(child: Image.network(url, fit: BoxFit.contain))),
      ),
    );
  }

  Future<void> _edit(BuildContext context, BudgetViewModel vm, BudgetLine? existing) async {
    final desc = TextEditingController(text: existing?.description ?? '');
    final planned = TextEditingController(text: existing?.planned.toStringAsFixed(2) ?? '');
    final actual = TextEditingController(text: existing?.actual.toStringAsFixed(2) ?? '0');
    var category = existing?.category ?? kBudgetCategories.first;
    final key = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(existing == null ? 'Add budget line' : 'Edit budget line'),
          content: Form(
            key: key,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: kBudgetCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => category = v!),
                ),
                const SizedBox(height: 10),
                TextFormField(controller: desc, decoration: const InputDecoration(labelText: 'Description')),
                const SizedBox(height: 10),
                TextFormField(controller: planned, keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (v) => Validators.money(v, 'Planned'), decoration: const InputDecoration(labelText: 'Planned (RM)')),
                const SizedBox(height: 10),
                TextFormField(controller: actual, keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (v) => Validators.money(v, 'Actual'), decoration: const InputDecoration(labelText: 'Actual (RM)')),
              ],
            ),
          ),
          actions: [
            if (existing != null)
              TextButton(onPressed: () => Navigator.pop(ctx, 'delete'), style: TextButton.styleFrom(foregroundColor: AppColors.red), child: const Text('Delete')),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                if (key.currentState!.validate()) Navigator.pop(ctx, 'save');
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (result == 'delete' && existing != null) {
      await vm.delete(existing);
    } else if (result == 'save') {
      final p = double.parse(planned.text.trim());
      final a = double.parse(actual.text.trim());
      if (existing == null) {
        await vm.add(category, desc.text.trim(), p, a);
      } else {
        await vm.update(existing, planned: p, actual: a, description: desc.text.trim());
      }
    }
  }
}

class _BudgetChart extends StatelessWidget {
  const _BudgetChart({required this.data});
  final Map<String, (double, double)> data;

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList();
    final maxY = entries.fold<double>(0, (m, e) => [m, e.value.$1, e.value.$2].reduce((a, b) => a > b ? a : b)) * 1.2;
    return BarChart(
      BarChartData(
        maxY: maxY <= 0 ? 100 : maxY,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, _, rod, rodIndex) => BarTooltipItem(
              '${entries[group.x].key}\n${rodIndex == 0 ? 'Planned' : 'Actual'} ${Fmt.rm(rod.toY)}',
              const TextStyle(color: AppColors.white, fontSize: 11),
            ),
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= entries.length) return const SizedBox.shrink();
                final label = entries[i].key.split(' ').first;
                return Padding(padding: const EdgeInsets.only(top: 6), child: Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)));
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (var i = 0; i < entries.length; i++)
            BarChartGroupData(
              x: i,
              barsSpace: 4,
              barRods: [
                BarChartRodData(toY: entries[i].value.$1, color: AppColors.indigo.withValues(alpha: 0.45), width: 10, borderRadius: BorderRadius.circular(3)),
                BarChartRodData(toY: entries[i].value.$2, color: entries[i].value.$2 > entries[i].value.$1 ? AppColors.red : AppColors.electricBlue, width: 10, borderRadius: BorderRadius.circular(3)),
              ],
            ),
        ],
      ),
    );
  }
}

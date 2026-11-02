import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/formatters.dart';
import '../../../core/registration_rules.dart';
import '../../../models/models.dart';
import '../../../services/app_services.dart';
import '../../../services/report_service.dart';
import '../../../theme/app_colors.dart';
import '../../../viewmodels/organiser/organiser_viewmodels.dart';
import '../../../widgets/common_widgets.dart';

/// Post-event report with charts and PDF export for Student Affairs.
class EventReportPage extends StatelessWidget {
  const EventReportPage({super.key, required this.eventId});
  final String eventId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => ReportViewModel(ctx.read<AppServices>(), eventId),
      child: const _ReportBody(),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReportViewModel>();
    final d = vm.data;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Report'),
        actions: [
          IconButton(tooltip: 'Refresh', onPressed: vm.load, icon: const Icon(Icons.refresh)),
        ],
      ),
      bottomNavigationBar: d == null
          ? null
          : Padding(
              padding: EdgeInsets.fromLTRB(20, 10, 20, 10 + MediaQuery.of(context).padding.bottom),
              child: BusyButton(
                label: 'Export as PDF',
                icon: Icons.picture_as_pdf_outlined,
                busy: vm.busy,
                onPressed: () async {
                  final ok = await vm.exportPdf();
                  if (context.mounted && !ok) showAppSnackBar(context, vm.error ?? 'Export failed', error: true);
                },
              ),
            ),
      body: d == null
          ? (vm.error != null ? ErrorView(message: vm.error!, onRetry: vm.load) : const LoadingView(message: 'Compiling report…'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Text(d.event.title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                Text('${Fmt.date(d.event.startTime)} • ${d.event.venue}', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                if (!d.event.hasEnded)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.orange.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                      child: const Text('This event has not ended yet — figures are live and will change.', style: TextStyle(color: AppColors.orange, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.3,
                  children: [
                    StatCard(label: 'Registered', value: '${d.registered}', icon: Icons.how_to_reg_outlined),
                    StatCard(label: 'Actual attendance', value: '${d.attended}', icon: Icons.verified_outlined, color: AppColors.green),
                    StatCard(label: 'No-show rate', value: Fmt.percent(d.noShowRate), icon: Icons.person_off_outlined, color: AppColors.orange),
                    StatCard(label: 'Avg. rating', value: d.feedback.isEmpty ? '—' : '${d.averageRating.toStringAsFixed(1)} ★', icon: Icons.star_outline, color: AppColors.electricBlue),
                  ],
                ),

                const SizedBox(height: 20),
                _Section('Attendance', child: _AttendanceDonut(d: d)),

                if (d.arrivalsByQuarterHour.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _Section(
                    'Arrivals over time',
                    subtitle: d.peakArrivalMinute == null ? null : 'Peak arrival ${_offset(d.peakArrivalMinute!)} relative to start',
                    child: SizedBox(height: 200, child: _ArrivalsChart(d: d)),
                  ),
                ],

                const SizedBox(height: 20),
                _Section(
                  'Participant feedback',
                  subtitle: d.feedback.isEmpty ? 'No feedback yet' : '${d.feedback.length} response${d.feedback.length == 1 ? '' : 's'}',
                  child: d.feedback.isEmpty
                      ? const SizedBox.shrink()
                      : Column(
                          children: [
                            _RatingBars(dist: d.ratingDistribution),
                            const SizedBox(height: 10),
                            ...d.feedback.where((f) => f.comment.isNotEmpty).take(5).map(
                                  (f) => ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: Text('${f.eventRating}★', style: const TextStyle(color: AppColors.orange, fontWeight: FontWeight.w800)),
                                    title: Text('"${f.comment}"', style: theme.textTheme.bodySmall),
                                  ),
                                ),
                          ],
                        ),
                ),

                const SizedBox(height: 20),
                _Section(
                  'Budget summary',
                  child: Column(
                    children: [
                      _Row('Planned', Fmt.rm(d.plannedBudget)),
                      _Row('Actual', Fmt.rm(d.actualBudget)),
                      _Row('Variance', Fmt.rm(d.plannedBudget - d.actualBudget), color: d.plannedBudget - d.actualBudget >= 0 ? AppColors.green : AppColors.red),
                      _Row('Vendor pre-order revenue', Fmt.rm(d.vendorRevenue)),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                _Section(
                  'Event performance',
                  child: Column(
                    children: [
                      _Row('Fill rate', d.event.capacity == 0 ? '—' : Fmt.percent(d.registered / d.event.capacity * 100)),
                      _Row('Show-up rate', Fmt.percent(100 - d.noShowRate)),
                      _Row('Walk-ins', '${d.walkIns}'),
                      _Row('Pre-orders', '${d.orders.where((o) => o.status != OrderStatus.cancelled).length}'),
                    ],
                  ),
                ),

                if (vm.previousEvents.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _Section(
                    'Compared with your previous events',
                    child: Column(
                      children: vm.previousEvents
                          .map(
                            (e) => _Row(
                              e.title,
                              '${e.attendedCount}/${e.registeredCount} • ${Fmt.percent(RegistrationRules.noShowRate(registered: e.registeredCount, attended: e.attendedCount))} no-show',
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  String _offset(int minutes) {
    if (minutes == 0) return 'at start';
    final abs = minutes.abs();
    return '${minutes < 0 ? '' : '+'}${minutes < 0 ? '−' : ''}${abs ~/ 60 > 0 ? '${abs ~/ 60}h ' : ''}${abs % 60}m';
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, {required this.child, this.subtitle});
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          if (subtitle != null) Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _AttendanceDonut extends StatelessWidget {
  const _AttendanceDonut({required this.d});
  final EventReportData d;

  @override
  Widget build(BuildContext context) {
    final attended = d.attended;
    final noShow = (d.registered - attended).clamp(0, 1 << 30).toInt();
    final waitlisted = d.waitlisted;
    final cancelled = d.cancelled;
    final sections = [
      (attended, AppColors.green, 'Attended'),
      (noShow, AppColors.orange, 'No-show'),
      (waitlisted, AppColors.electricBlue, 'Waitlisted'),
      (cancelled, AppColors.textSecondary, 'Cancelled'),
    ].where((s) => s.$1 > 0).toList();
    if (sections.isEmpty) return const Text('No registrations recorded.', style: TextStyle(color: AppColors.textSecondary));
    return Row(
      children: [
        SizedBox(
          width: 140,
          height: 140,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 36,
              sections: sections.map((s) => PieChartSectionData(value: s.$1.toDouble(), color: s.$2, radius: 30, showTitle: false)).toList(),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: sections
                .map(
                  (s) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(width: 12, height: 12, decoration: BoxDecoration(color: s.$2, borderRadius: BorderRadius.circular(3))),
                        const SizedBox(width: 8),
                        Expanded(child: Text(s.$3, style: Theme.of(context).textTheme.bodySmall)),
                        Text('${s.$1}', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _ArrivalsChart extends StatelessWidget {
  const _ArrivalsChart({required this.d});
  final EventReportData d;

  @override
  Widget build(BuildContext context) {
    final buckets = d.arrivalsByQuarterHour.entries.toList();
    final maxY = buckets.fold<int>(0, (m, e) => e.value > m ? e.value : m).toDouble() * 1.25;
    return BarChart(
      BarChartData(
        maxY: maxY <= 0 ? 5 : maxY,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= buckets.length) return const SizedBox.shrink();
                final m = buckets[i].key;
                final label = m == 0 ? 'start' : '${m > 0 ? '+' : ''}${m}m';
                return Padding(padding: const EdgeInsets.only(top: 4), child: Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)));
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < buckets.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [BarChartRodData(toY: buckets[i].value.toDouble(), color: AppColors.indigo, width: 14, borderRadius: BorderRadius.circular(4))],
            ),
        ],
      ),
    );
  }
}

class _RatingBars extends StatelessWidget {
  const _RatingBars({required this.dist});
  final List<int> dist;

  @override
  Widget build(BuildContext context) {
    final total = dist.fold(0, (a, b) => a + b);
    return Column(
      children: List.generate(5, (i) {
        final stars = 5 - i;
        final n = dist[stars - 1];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              SizedBox(width: 28, child: Text('$stars★', style: const TextStyle(fontSize: 12, color: AppColors.orange, fontWeight: FontWeight.w700))),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: total == 0 ? 0 : n / total, minHeight: 8, backgroundColor: AppColors.divider, color: AppColors.orange),
                ),
              ),
              SizedBox(width: 30, child: Text(' $n', style: const TextStyle(fontSize: 12))),
            ],
          ),
        );
      }),
    );
  }
}

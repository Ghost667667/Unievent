import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/formatters.dart';
import '../../../models/models.dart';
import '../../../navigation/app_router.dart';
import '../../../theme/app_colors.dart';
import '../../../viewmodels/vendor/vendor_viewmodels.dart';
import '../../../widgets/common_widgets.dart';
import '../../../widgets/event_card.dart';

/// Vendor Events: browse events accepting vendors (filter by category/date)
/// and track application status.
class VendorEventsTab extends StatefulWidget {
  const VendorEventsTab({super.key});

  @override
  State<VendorEventsTab> createState() => _VendorEventsTabState();
}

class _VendorEventsTabState extends State<VendorEventsTab> {
  String? _category;
  DateTime? _date;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<VendorDashboardViewModel>();
    final theme = Theme.of(context);
    var events = vm.openEvents.where((e) {
      if (_category != null && e.category != _category) return false;
      if (_date != null && (e.startTime.year != _date!.year || e.startTime.month != _date!.month || e.startTime.day != _date!.day)) return false;
      if (_query.isNotEmpty && !e.title.toLowerCase().contains(_query.toLowerCase()) && !e.venue.toLowerCase().contains(_query.toLowerCase())) return false;
      return true;
    }).toList();
    final mine = [...vm.applications]..sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Events'),
          bottom: TabBar(tabs: [Tab(text: 'Accepting vendors (${events.length})'), Tab(text: 'My applications (${mine.length})')]),
        ),
        body: vm.loading
            ? const LoadingView()
            : TabBarView(
                children: [
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                        child: TextField(
                          onChanged: (v) => setState(() => _query = v),
                          decoration: const InputDecoration(hintText: 'Search events or venues', prefixIcon: Icon(Icons.search), isDense: true),
                        ),
                      ),
                      SizedBox(
                        height: 48,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                          children: [
                            ActionChip(
                              avatar: Icon(Icons.calendar_today_outlined, size: 16, color: _date == null ? AppColors.midnight : AppColors.white),
                              label: Text(_date == null ? 'Any date' : Fmt.shortDate(_date!)),
                              backgroundColor: _date == null ? null : AppColors.indigo,
                              labelStyle: TextStyle(color: _date == null ? AppColors.midnight : AppColors.white),
                              onPressed: () async {
                                final d = await showDatePicker(context: context, initialDate: _date ?? DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                                setState(() => _date = d);
                              },
                            ),
                            const SizedBox(width: 8),
                            ...kEventCategories.map(
                              (c) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(c),
                                  selected: _category == c,
                                  labelStyle: TextStyle(color: _category == c ? AppColors.white : AppColors.midnight),
                                  onSelected: (_) => setState(() => _category = _category == c ? null : c),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: events.isEmpty
                            ? const EmptyState(icon: Icons.event_busy_outlined, title: 'No events accepting vendors', message: 'Organisers enable vendor applications per event. Check back soon.')
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                                itemCount: events.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, i) => _OpenEventCard(event: events[i], status: vm.applicationStatusFor(events[i].id)),
                              ),
                      ),
                    ],
                  ),
                  mine.isEmpty
                      ? const EmptyState(icon: Icons.assignment_outlined, title: 'No applications yet', message: 'Apply to an event and track its status here: Pending → Approved / Rejected.')
                      : ListView.separated(
                          padding: const EdgeInsets.all(20),
                          itemCount: mine.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final a = mine[i];
                            final color = switch (a.status) {
                              ApplicationStatus.pending => AppColors.orange,
                              ApplicationStatus.approved => AppColors.green,
                              ApplicationStatus.rejected => AppColors.red,
                            };
                            return AppCard(
                              onTap: () => context.push(Routes.vendorEventDetails(a.eventId)),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                                    child: Icon(Icons.storefront_outlined, color: color),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(a.eventTitle, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                                        Text(
                                          a.eventStartTime == null ? '' : Fmt.dateTime(a.eventStartTime!),
                                          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                                        ),
                                        if (a.status == ApplicationStatus.approved)
                                          Text('Booth ${a.boothNumber ?? 'TBC'} • Arrive ${a.arrivalTime ?? 'TBC'}', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.green, fontWeight: FontWeight.w600)),
                                        if (a.status == ApplicationStatus.rejected && (a.organiserNote?.isNotEmpty ?? false))
                                          Text(a.organiserNote!, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.red)),
                                      ],
                                    ),
                                  ),
                                  StatusChip(label: a.status.label, color: color),
                                ],
                              ),
                            );
                          },
                        ),
                ],
              ),
      ),
    );
  }
}

class _OpenEventCard extends StatelessWidget {
  const _OpenEventCard({required this.event, required this.status});
  final Event event;
  final ApplicationStatus? status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = event;
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () => context.push(Routes.vendorEventDetails(e.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EventPoster(event: e, height: 120, borderRadius: const BorderRadius.vertical(top: Radius.circular(18))),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(e.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                    if (status != null)
                      StatusChip(
                        label: status!.label,
                        color: switch (status!) {
                          ApplicationStatus.pending => AppColors.orange,
                          ApplicationStatus.approved => AppColors.green,
                          ApplicationStatus.rejected => AppColors.red,
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('${Fmt.dateTime(e.startTime)} • ${e.venue}', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    StatusChip(label: e.category, color: AppColors.categoryColor(e.category)),
                    StatusChip(label: '~${e.registeredCount} registered • cap ${e.capacity}', color: AppColors.textSecondary, icon: Icons.people_outline),
                    StatusChip(label: e.vendorFee == 0 ? 'No fee' : 'Fee ${Fmt.rm(e.vendorFee)}', color: e.vendorFee == 0 ? AppColors.green : AppColors.indigo),
                    if (e.studentVendorsOnly) const StatusChip(label: 'Students only', color: AppColors.orange, icon: Icons.school_outlined),
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

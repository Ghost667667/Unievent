import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/formatters.dart';
import '../../../models/models.dart';
import '../../../navigation/app_router.dart';
import '../../../theme/app_colors.dart';
import '../../../viewmodels/organiser/organiser_viewmodels.dart';
import '../../../widgets/common_widgets.dart';

/// Vendor Management: Pending | Approved | Rejected applications.
class OrganiserVendorsTab extends StatelessWidget {
  const OrganiserVendorsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<VendorManagementViewModel>();
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Vendor Management'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Pending (${vm.pending.length})'),
              Tab(text: 'Approved (${vm.approved.length})'),
              Tab(text: 'Rejected (${vm.rejected.length})'),
            ],
          ),
        ),
        body: vm.loading
            ? const LoadingView()
            : TabBarView(
                children: [
                  _AppList(apps: vm.pending, empty: 'No pending applications', hint: 'Vendor applications for your events will appear here.'),
                  _AppList(apps: vm.approved, empty: 'No approved vendors', hint: 'Approve applications to assign booths and share logistics.'),
                  _AppList(apps: vm.rejected, empty: 'No rejected applications'),
                ],
              ),
      ),
    );
  }
}

class _AppList extends StatelessWidget {
  const _AppList({required this.apps, required this.empty, this.hint});
  final List<VendorApplication> apps;
  final String empty;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    if (apps.isEmpty) return EmptyState(icon: Icons.storefront_outlined, title: empty, message: hint);
    final sorted = [...apps]..sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => VendorApplicationTile(app: sorted[i]),
    );
  }
}

class VendorApplicationTile extends StatelessWidget {
  const VendorApplicationTile({super.key, required this.app, this.showEvent = true});
  final VendorApplication app;
  final bool showEvent;

  static Color colorFor(ApplicationStatus s) => switch (s) {
        ApplicationStatus.pending => AppColors.orange,
        ApplicationStatus.approved => AppColors.green,
        ApplicationStatus.rejected => AppColors.red,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: () => context.push(Routes.vendorReview(app.id)),
      child: Row(
        children: [
          UserAvatar(name: app.vendorName, radius: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(app.vendorName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                Text(
                  '${app.productCategory}${app.isStudentVendor ? ' • Student vendor' : ' • External'}',
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
                if (showEvent)
                  Text(
                    '${app.eventTitle}${app.eventStartTime != null ? ' • ${Fmt.shortDate(app.eventStartTime!)}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: AppColors.indigo),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusChip(label: app.status.label, color: colorFor(app.status)),
              if (app.boothNumber != null) ...[
                const SizedBox(height: 4),
                Text('Booth ${app.boothNumber}', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
              ],
              if (app.checkedInAt != null)
                const Text('Arrived ✓', style: TextStyle(color: AppColors.green, fontSize: 11, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

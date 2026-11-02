import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/formatters.dart';
import '../../../navigation/app_router.dart';
import '../../../theme/app_colors.dart';
import '../../../viewmodels/organiser/organiser_viewmodels.dart';
import '../../../widgets/common_widgets.dart';

/// Check-in tab: pick which event to scan for.
class OrganiserCheckinTab extends StatelessWidget {
  const OrganiserCheckinTab({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OrganiserDashboardViewModel>();
    final theme = Theme.of(context);
    final events = vm.upcoming;
    return Scaffold(
      appBar: AppBar(title: const Text('QR Check-in')),
      body: vm.loading
          ? const LoadingView()
          : events.isEmpty
              ? const EmptyState(icon: Icons.qr_code_scanner, title: 'No events to check in', message: 'Upcoming events will be listed here on the day.')
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    AppCard(
                      color: AppColors.surfaceTint,
                      child: Row(
                        children: [
                          const Icon(Icons.phonelink_ring_outlined, color: AppColors.indigo, size: 30),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Several crew phones can scan the same event at once. Scanning keeps working offline and syncs automatically.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Select an event', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    ...events.map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppCard(
                          onTap: () => context.push(Routes.eventCheckin(e.id)),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: AppColors.green.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                                child: const Icon(Icons.qr_code_scanner, color: AppColors.green),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(e.title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                                    Text('${Fmt.relative(e.startTime)} • ${Fmt.time(e.startTime)} • ${e.attendedCount}/${e.registeredCount} checked in', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

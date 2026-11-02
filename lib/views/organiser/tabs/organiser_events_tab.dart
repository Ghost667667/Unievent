import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/formatters.dart';
import '../../../models/models.dart';
import '../../../navigation/app_router.dart';
import '../../../theme/app_colors.dart';
import '../../../viewmodels/organiser/organiser_viewmodels.dart';
import '../../../widgets/common_widgets.dart';
import '../../../widgets/event_card.dart';
import '../organiser_shell.dart' show ProposalTile;

/// Events tab: Upcoming | Past | Proposals.
class OrganiserEventsTab extends StatelessWidget {
  const OrganiserEventsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OrganiserDashboardViewModel>();
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Event Management'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Upcoming (${vm.upcoming.length})'),
              Tab(text: 'Past (${vm.past.length})'),
              Tab(text: 'Proposals (${vm.proposals.length})'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push(Routes.proposalNew),
          icon: const Icon(Icons.add),
          label: const Text('Proposal'),
        ),
        body: vm.loading
            ? const LoadingView()
            : TabBarView(
                children: [
                  _EventList(events: vm.upcoming, empty: 'No upcoming events', hint: 'Create an event from an approved proposal.'),
                  _EventList(events: vm.past, empty: 'No past events', hint: 'Finished and cancelled events appear here with their reports.'),
                  vm.proposals.isEmpty
                      ? const EmptyState(icon: Icons.description_outlined, title: 'No proposals yet', message: 'Submit a Student Affairs proposal to get an event approved.')
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
                          itemCount: vm.proposals.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, i) => ProposalTile(proposal: vm.proposals[i]),
                        ),
                ],
              ),
      ),
    );
  }
}

class _EventList extends StatelessWidget {
  const _EventList({required this.events, required this.empty, required this.hint});
  final List<Event> events;
  final String empty;
  final String hint;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return EmptyState(icon: Icons.event_outlined, title: empty, message: hint);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
      itemCount: events.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => OrganiserEventTile(event: events[i]),
    );
  }
}

class OrganiserEventTile extends StatelessWidget {
  const OrganiserEventTile({super.key, required this.event});
  final Event event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = event;
    final statusColor = switch (e.status) {
      EventStatus.cancelled => AppColors.red,
      EventStatus.ended => AppColors.textSecondary,
      EventStatus.checkInOpen || EventStatus.live => AppColors.green,
      EventStatus.delayed => AppColors.orange,
      EventStatus.upcoming => AppColors.indigo,
    };
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () => context.push(Routes.eventManage(e.id)),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
            child: SizedBox(width: 96, height: 110, child: EventPoster(event: e, height: 110)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
                      StatusChip(label: e.status.label, color: statusColor),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${Fmt.dateTime(e.startTime)}\n${e.venue}', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _Mini(Icons.how_to_reg_outlined, '${e.registeredCount}/${e.capacity}'),
                      const SizedBox(width: 10),
                      _Mini(Icons.hourglass_top, '${e.waitlistCount}'),
                      const SizedBox(width: 10),
                      _Mini(Icons.verified_outlined, '${e.attendedCount}'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.indigo),
        const SizedBox(width: 3),
        Text(text, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/formatters.dart';
import '../../../core/ticket_codec.dart';
import '../../../models/models.dart';
import '../../../navigation/app_router.dart';
import '../../../services/app_services.dart';
import '../../../theme/app_colors.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../widgets/common_widgets.dart';

/// My Events: Upcoming | Waitlisted | Attended | Cancelled.
class StudentMyEventsTab extends StatelessWidget {
  const StudentMyEventsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();
    final user = context.watch<AuthViewModel>().user!;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Events'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Upcoming'),
              Tab(text: 'Waitlisted'),
              Tab(text: 'Attended'),
              Tab(text: 'Cancelled'),
            ],
          ),
        ),
        body: StreamBuilder<List<Registration>>(
          stream: services.registrations.watchByStudent(user.uid),
          builder: (context, snap) {
            if (snap.hasError) return ErrorView(message: snap.error.toString());
            if (!snap.hasData) return const LoadingView();
            final all = snap.data!;
            final now = DateTime.now();
            final upcoming = all
                .where(
                  (r) => r.status == RegistrationStatus.registered &&
                      (r.eventStartTime == null || r.eventStartTime!.add(const Duration(hours: 12)).isAfter(now)),
                )
                .toList();
            final waitlisted = all.where((r) => r.status == RegistrationStatus.waitlisted).toList();
            final attended = all.where((r) => r.status == RegistrationStatus.attended).toList()
              ..sort((a, b) => (b.eventStartTime ?? now).compareTo(a.eventStartTime ?? now));
            final cancelled = all.where((r) => r.status == RegistrationStatus.cancelled).toList();
            // Registered events that already finished without check-in.
            final missed = all
                .where(
                  (r) => r.status == RegistrationStatus.registered &&
                      r.eventStartTime != null &&
                      !r.eventStartTime!.add(const Duration(hours: 12)).isAfter(now),
                )
                .toList();

            return TabBarView(
              children: [
                _RegList(
                  items: upcoming,
                  empty: 'No upcoming events',
                  hint: 'Register for an event and your ticket will appear here.',
                  action: TextButton(
                    onPressed: () => context.go(Routes.studentExplore),
                    child: const Text('Explore events'),
                  ),
                ),
                _RegList(
                  items: waitlisted,
                  empty: 'No waitlisted events',
                  hint: 'When an event is full you can join its waitlist and we will move you in automatically.',
                ),
                _RegList(
                  items: [...attended, ...missed],
                  empty: 'No attended events yet',
                  hint: 'Events you check in to appear here with their feedback form.',
                ),
                _RegList(
                  items: cancelled,
                  empty: 'No cancelled registrations',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RegList extends StatelessWidget {
  const _RegList({
    required this.items,
    required this.empty,
    this.hint,
    this.action,
  });

  final List<Registration> items;
  final String empty;
  final String? hint;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return EmptyState(
        icon: Icons.confirmation_number_outlined,
        title: empty,
        message: hint,
        action: action,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _RegistrationTile(reg: items[i]),
    );
  }
}

class _RegistrationTile extends StatelessWidget {
  const _RegistrationTile({required this.reg});
  final Registration reg;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (color, icon) = switch (reg.status) {
      RegistrationStatus.registered => (AppColors.indigo, Icons.qr_code_2),
      RegistrationStatus.waitlisted => (AppColors.orange, Icons.hourglass_top),
      RegistrationStatus.attended => (AppColors.green, Icons.verified),
      RegistrationStatus.cancelled => (AppColors.textSecondary, Icons.cancel_outlined),
    };
    final ended = reg.eventStartTime != null &&
        reg.eventStartTime!.add(const Duration(hours: 12)).isBefore(DateTime.now());
    final showFeedback =
        reg.status == RegistrationStatus.attended || (reg.status == RegistrationStatus.registered && ended);

    return AppCard(
      onTap: () => reg.status == RegistrationStatus.cancelled
          ? context.push(Routes.eventDetails(reg.eventId))
          : context.push(Routes.ticket(reg.id)),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reg.eventTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                if (reg.eventStartTime != null)
                  Text(
                    '${Fmt.date(reg.eventStartTime!)} • ${Fmt.time(reg.eventStartTime!)}',
                    style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  ),
                if (reg.venue != null)
                  Text(
                    reg.venue!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    StatusChip(
                      label: reg.status == RegistrationStatus.waitlisted && reg.waitlistPosition != null
                          ? 'Waitlist #${reg.waitlistPosition}'
                          : reg.status.label,
                      color: color,
                    ),
                    if (reg.status == RegistrationStatus.registered)
                      StatusChip(
                        label: reg.confirmed ? 'Attendance confirmed' : TicketCodec.shortNumber(reg.ticketCode),
                        color: reg.confirmed ? AppColors.green : AppColors.textSecondary,
                        icon: reg.confirmed ? Icons.check : null,
                      ),
                    if (showFeedback)
                      ActionChip(
                        avatar: const Icon(Icons.star_outline, size: 16, color: AppColors.orange),
                        label: const Text('Rate event'),
                        onPressed: () => context.push(Routes.feedback(reg.eventId)),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

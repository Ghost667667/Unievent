import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../navigation/app_router.dart';
import '../../services/app_services.dart';
import '../../theme/app_colors.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/organiser/organiser_viewmodels.dart';
import '../../widgets/common_widgets.dart';
import '../shared/notifications_page.dart';
import '../shared/role_shell.dart';

export 'tabs/organiser_checkin_tab.dart';
export 'tabs/organiser_events_tab.dart';
export 'tabs/organiser_profile_tab.dart';
export 'tabs/organiser_vendors_tab.dart';

/// Organiser shell: Home | Events | Check-in | Vendors | Profile.
class OrganiserShell extends StatelessWidget {
  const OrganiserShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthViewModel>().user!;
    return MultiProvider(
      key: ValueKey('organiser_${user.uid}'),
      providers: [
        ChangeNotifierProvider(create: (ctx) => OrganiserDashboardViewModel(ctx.read<AppServices>(), user)),
        ChangeNotifierProvider(create: (ctx) => VendorManagementViewModel(ctx.read<AppServices>(), user)),
      ],
      child: RoleShell(
        shell: shell,
        destinations: const [
          ShellDestination(label: 'Home', icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard),
          ShellDestination(label: 'Events', icon: Icons.event_note_outlined, selectedIcon: Icons.event_note),
          ShellDestination(label: 'Check-in', icon: Icons.qr_code_scanner_outlined, selectedIcon: Icons.qr_code_scanner),
          ShellDestination(label: 'Vendors', icon: Icons.storefront_outlined, selectedIcon: Icons.storefront),
          ShellDestination(label: 'Profile', icon: Icons.person_outline, selectedIcon: Icons.person),
        ],
      ),
    );
  }
}

class OrganiserHomeTab extends StatelessWidget {
  const OrganiserHomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthViewModel>().user!;
    final vm = context.watch<OrganiserDashboardViewModel>();
    final theme = Theme.of(context);
    final current = vm.currentEvent;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: GradientHeader(
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
                              user.organisationName ?? 'Organiser Dashboard',
                              style: theme.textTheme.titleLarge?.copyWith(color: AppColors.white, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              'Welcome, ${user.firstName}',
                              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.white.withValues(alpha: 0.85)),
                            ),
                          ],
                        ),
                      ),
                      const NotificationBell(),
                      UserAvatar(name: user.fullName, photoUrl: user.photoUrl, onTap: () => context.go(Routes.organiserProfile)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (current != null)
                    _CurrentEventBanner(event: current)
                  else
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: AppColors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        children: [
                          const Icon(Icons.add_circle_outline, color: AppColors.white),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'No upcoming events. Submit a proposal to get started.',
                              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
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
                  StatCard(
                    label: 'Registered',
                    value: '${current?.registeredCount ?? 0}',
                    icon: Icons.how_to_reg_outlined,
                    color: AppColors.indigo,
                    onTap: current == null ? null : () => context.push(Routes.eventRegistrations(current.id)),
                  ),
                  StatCard(
                    label: 'Confirmed',
                    value: '${current?.confirmedCount ?? 0}',
                    icon: Icons.verified_outlined,
                    color: AppColors.green,
                    onTap: current == null ? null : () => context.push(Routes.eventRegistrations(current.id)),
                  ),
                  StatCard(
                    label: 'Forecast',
                    value: vm.forecast == null ? '—' : '${vm.forecast}',
                    icon: Icons.insights_outlined,
                    color: AppColors.electricBlue,
                    onTap: current == null ? null : () => _explainForecast(context, current, vm.forecast),
                  ),
                  StatCard(
                    label: 'Waitlist',
                    value: '${current?.waitlistCount ?? 0}',
                    icon: Icons.hourglass_top_outlined,
                    color: AppColors.orange,
                    onTap: current == null ? null : () => context.push(Routes.eventRegistrations(current.id)),
                  ),
                ],
              ),
            ),
            const SliverToBoxAdapter(child: SectionTitle('Quick actions')),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: QuickAction(
                        label: 'Create Event',
                        icon: Icons.add_box_outlined,
                        onTap: () => _createEvent(context, vm),
                      ),
                    ),
                    Expanded(
                      child: QuickAction(
                        label: 'Scan QR',
                        icon: Icons.qr_code_scanner,
                        color: AppColors.green,
                        onTap: () => current == null ? context.go(Routes.organiserCheckin) : context.push(Routes.eventCheckin(current.id)),
                      ),
                    ),
                    Expanded(
                      child: QuickAction(
                        label: 'Send Announcement',
                        icon: Icons.campaign_outlined,
                        color: AppColors.orange,
                        onTap: () => current == null
                            ? showAppSnackBar(context, 'Create an event first.')
                            : context.push(Routes.eventAnnouncements(current.id)),
                      ),
                    ),
                    Expanded(
                      child: QuickAction(
                        label: 'View Report',
                        icon: Icons.bar_chart_outlined,
                        color: AppColors.electricBlue,
                        onTap: () {
                          final target = vm.past.where((e) => e.status == EventStatus.ended).toList();
                          if (target.isEmpty && current == null) {
                            showAppSnackBar(context, 'Reports appear once an event has ended.');
                            return;
                          }
                          context.push(Routes.eventReport((target.isNotEmpty ? target.first : current!).id));
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (user.role == UserRole.studentAffairs)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: AppCard(
                    color: AppColors.midnight,
                    onTap: () => context.push(Routes.studentAffairs),
                    child: const Row(
                      children: [
                        Icon(Icons.verified_user_outlined, color: AppColors.white),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text('Student Affairs approval dashboard', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w700)),
                        ),
                        Icon(Icons.chevron_right, color: AppColors.white),
                      ],
                    ),
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: SectionTitle('Proposals', action: 'New proposal', onAction: () => context.push(Routes.proposalNew)),
            ),
            if (vm.proposals.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text('No proposals yet. Every event starts with a Student Affairs proposal.', style: TextStyle(color: AppColors.textSecondary)),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList.separated(
                  itemCount: vm.proposals.take(4).length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => ProposalTile(proposal: vm.proposals[i]),
                ),
              ),
            if (current != null) ...[
              SliverToBoxAdapter(
                child: SectionTitle('Crew task board • ${current.title}', action: 'Manage', onAction: () => context.push(Routes.eventManage(current.id))),
              ),
              SliverToBoxAdapter(child: _TaskPreview(eventId: current.id)),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ],
      ),
    );
  }

  void _createEvent(BuildContext context, OrganiserDashboardViewModel vm) {
    final approved = vm.proposals.where((p) => p.canCreateEvent).toList();
    if (approved.isEmpty) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Approval required'),
          content: const Text('Events are created from an approved Student Affairs proposal. Submit a proposal first, then create the event once it is approved.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.push(Routes.proposalNew);
              },
              child: const Text('New proposal'),
            ),
          ],
        ),
      );
      return;
    }
    if (approved.length == 1) {
      context.push(Routes.eventNew(proposalId: approved.first.id));
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const Padding(padding: EdgeInsets.all(8), child: Text('Create event from approved proposal', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
          ...approved.map(
            (p) => ListTile(
              leading: const Icon(Icons.check_circle, color: AppColors.green),
              title: Text(p.eventTitle),
              subtitle: Text(Fmt.date(p.proposedDate)),
              onTap: () {
                Navigator.pop(ctx);
                context.push(Routes.eventNew(proposalId: p.id));
              },
            ),
          ),
        ],
      ),
    );
  }

  void _explainForecast(BuildContext context, Event e, int? forecast) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Show-Up Forecast'),
        content: Text(
          'Expected attendance for ${e.title}: ${forecast ?? '—'} of ${e.registeredCount} registered.\n\n'
          'The forecast uses the show-up rate of your past ${e.category} events (or an industry default of 72% for free / 83% for paid events until you have history). '
          'Confirmed students count at 95%. Plan food and seating from this number, not the raw sign-up count.',
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Got it'))],
      ),
    );
  }
}

class _CurrentEventBanner extends StatelessWidget {
  const _CurrentEventBanner({required this.event});
  final Event event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppColors.white.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push(Routes.eventManage(event.id)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CURRENT EVENT • ${Fmt.relative(event.startTime).toUpperCase()}', style: theme.textTheme.labelSmall?.copyWith(color: AppColors.white.withValues(alpha: 0.8), letterSpacing: 1)),
                    const SizedBox(height: 2),
                    Text(event.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium?.copyWith(color: AppColors.white, fontWeight: FontWeight.w700)),
                    Text('${Fmt.dateTime(event.startTime)} • ${event.venue}', maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.white.withValues(alpha: 0.9))),
                  ],
                ),
              ),
              StatusChip(label: event.status.label, color: AppColors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskPreview extends StatelessWidget {
  const _TaskPreview({required this.eventId});
  final String eventId;

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();
    return StreamBuilder<List<CrewTask>>(
      stream: services.tasks.watchByEvent(eventId),
      builder: (context, snap) {
        final tasks = snap.data ?? const [];
        if (tasks.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text('No crew tasks yet. Add tasks from the event page.', style: TextStyle(color: AppColors.textSecondary)),
          );
        }
        final done = tasks.where((t) => t.status == TaskStatus.done).length;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(value: tasks.isEmpty ? 0 : done / tasks.length, minHeight: 6, backgroundColor: AppColors.divider, color: AppColors.green),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('$done/${tasks.length} done', style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
                const SizedBox(height: 8),
                ...tasks.take(4).map(
                  (t) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      t.status == TaskStatus.done ? Icons.check_circle : t.status == TaskStatus.inProgress ? Icons.timelapse : Icons.radio_button_unchecked,
                      color: t.status == TaskStatus.done ? AppColors.green : t.status == TaskStatus.inProgress ? AppColors.orange : AppColors.textSecondary,
                    ),
                    title: Text(t.title, style: TextStyle(decoration: t.status == TaskStatus.done ? TextDecoration.lineThrough : null)),
                    subtitle: Text(t.owner),
                    onTap: () => services.tasks.setStatus(
                      t.id,
                      switch (t.status) {
                        TaskStatus.todo => TaskStatus.inProgress,
                        TaskStatus.inProgress => TaskStatus.done,
                        TaskStatus.done => TaskStatus.todo,
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Proposal row shared by Home and Events tabs.
class ProposalTile extends StatelessWidget {
  const ProposalTile({super.key, required this.proposal});
  final Proposal proposal;

  static Color colorFor(ProposalStatus s) => switch (s) {
        ProposalStatus.draft => AppColors.textSecondary,
        ProposalStatus.submitted => AppColors.electricBlue,
        ProposalStatus.needsChanges => AppColors.orange,
        ProposalStatus.approved => AppColors.green,
        ProposalStatus.rejected => AppColors.red,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = proposal;
    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: () => context.push(Routes.proposalEdit(p.id)),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: colorFor(p.status).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.description_outlined, color: colorFor(p.status)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.eventTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                Text('${p.category} • ${Fmt.date(p.proposedDate)}', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                if (p.reviewerComment != null && p.status != ProposalStatus.approved)
                  Text(p.reviewerComment!, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.orange)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusChip(label: p.status.label, color: colorFor(p.status)),
              if (p.canCreateEvent) ...[
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => context.push(Routes.eventNew(proposalId: p.id)),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                  child: const Text('Create event →'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

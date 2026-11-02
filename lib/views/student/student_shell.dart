import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../navigation/app_router.dart';
import '../../services/app_services.dart';
import '../../theme/app_colors.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/student/student_viewmodels.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/event_card.dart';
import '../shared/notifications_page.dart';
import '../shared/role_shell.dart';
import 'register_flow.dart';

export 'tabs/explore_tab.dart';
export 'tabs/my_events_tab.dart';
export 'tabs/orders_tab.dart';
export 'tabs/profile_tab.dart';

/// Student dashboard shell: Home | Explore | My Events | Orders | Profile.
/// The [EventFeedViewModel] is shared by Home and Explore.
class StudentShell extends StatelessWidget {
  const StudentShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthViewModel>().user!;
    return ChangeNotifierProvider<EventFeedViewModel>(
      key: ValueKey('feed_${user.uid}'),
      create: (ctx) => EventFeedViewModel(ctx.read<AppServices>(), user),
      child: RoleShell(
        shell: shell,
        destinations: const [
          ShellDestination(label: 'Home', icon: Icons.home_outlined, selectedIcon: Icons.home),
          ShellDestination(label: 'Explore', icon: Icons.explore_outlined, selectedIcon: Icons.explore),
          ShellDestination(label: 'My Events', icon: Icons.confirmation_number_outlined, selectedIcon: Icons.confirmation_number),
          ShellDestination(label: 'Orders', icon: Icons.shopping_bag_outlined, selectedIcon: Icons.shopping_bag),
          ShellDestination(label: 'Profile', icon: Icons.person_outline, selectedIcon: Icons.person),
        ],
      ),
    );
  }
}

/// Home: greeting header, search, category chips, next event, feed.
class StudentHomeTab extends StatelessWidget {
  const StudentHomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthViewModel>().user!;
    final feed = context.watch<EventFeedViewModel>();
    final theme = Theme.of(context);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => Future<void>.delayed(const Duration(milliseconds: 400)),
        child: CustomScrollView(
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
                                'Hello, ${user.firstName}!',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                "Discover what's happening around campus.",
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const NotificationBell(),
                        UserAvatar(
                          name: user.fullName,
                          photoUrl: user.photoUrl,
                          onTap: () => context.go(Routes.studentProfile),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _SearchBar(
                      onTap: () => context.go(Routes.studentExplore),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 48,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  scrollDirection: Axis.horizontal,
                  itemCount: kEventCategories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final c = kEventCategories[i];
                    return ActionChip(
                      avatar: CircleAvatar(
                        radius: 5,
                        backgroundColor: AppColors.categoryColor(c),
                      ),
                      label: Text(c),
                      onPressed: () {
                        feed.setFilter(feed.filter.copyWith(category: c));
                        context.go(Routes.studentExplore);
                      },
                    );
                  },
                ),
              ),
            ),
            if (feed.loading)
              const SliverFillRemaining(child: LoadingView())
            else ...[
              if (feed.nextRegistered != null)
                SliverToBoxAdapter(
                  child: _NextEventCard(
                    event: feed.nextRegistered!.$1,
                    registration: feed.nextRegistered!.$2,
                  ),
                ),
              if (feed.recommended.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: SectionTitle('Recommended for you'),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 320,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      itemCount: feed.recommended.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 14),
                      itemBuilder: (context, i) {
                        final e = feed.recommended[i];
                        return SizedBox(
                          width: 280,
                          child: _FeedCard(event: e, compact: true),
                        );
                      },
                    ),
                  ),
                ),
              ],
              SliverToBoxAdapter(
                child: SectionTitle(
                  'Upcoming events',
                  action: 'See all',
                  onAction: () => context.go(Routes.studentExplore),
                ),
              ),
              if (feed.upcoming.isEmpty)
                const SliverToBoxAdapter(
                  child: EmptyState(
                    icon: Icons.event_busy_outlined,
                    title: 'No upcoming events',
                    message: 'Check back soon — organisers post new events every week.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  sliver: SliverList.separated(
                    itemCount: feed.upcoming.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, i) => _FeedCard(event: feed.upcoming[i]),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Wires an [EventCard] to the feed VM for register/save actions.
class _FeedCard extends StatelessWidget {
  const _FeedCard({required this.event, this.compact = false});
  final Event event;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<EventFeedViewModel>();
    final user = context.watch<AuthViewModel>().user!;
    final saved = user.savedEventIds.contains(event.id);
    return EventCard(
      event: event,
      registration: feed.registrationFor(event.id),
      saved: saved,
      onToggleSave: () => feed.toggleSave(event.id, currentlySaved: saved),
      onTap: () => context.push(Routes.eventDetails(event.id)),
      onRegister: () => registerForEvent(context, event),
      compact: compact,
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              const Icon(Icons.search, color: AppColors.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Search events, venues, clubs…',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ),
              const Icon(Icons.tune, color: AppColors.indigo, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextEventCard extends StatelessWidget {
  const _NextEventCard({required this.event, required this.registration});
  final Event event;
  final Registration registration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: AppCard(
        color: AppColors.midnight,
        onTap: () => context.push(Routes.ticket(registration.id)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.qr_code_2, color: AppColors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your next event • ${Fmt.relative(event.startTime)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.white.withValues(alpha: 0.75),
                    ),
                  ),
                  Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${Fmt.time(event.startTime)} • ${event.venue}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.white),
          ],
        ),
      ),
    );
  }
}

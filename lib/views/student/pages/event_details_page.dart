import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/formatters.dart';
import '../../../models/models.dart';
import '../../../navigation/app_router.dart';
import '../../../services/app_services.dart';
import '../../../theme/app_colors.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../viewmodels/student/student_viewmodels.dart';
import '../../../widgets/common_widgets.dart';
import '../../../widgets/event_card.dart';
import '../register_flow.dart';

class EventDetailsPage extends StatelessWidget {
  const EventDetailsPage({super.key, required this.eventId});
  final String eventId;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthViewModel>().user!;
    return ChangeNotifierProvider(
      create: (ctx) => EventDetailsViewModel(ctx.read<AppServices>(), user, eventId),
      child: const _EventDetailsBody(),
    );
  }
}

class _EventDetailsBody extends StatelessWidget {
  const _EventDetailsBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<EventDetailsViewModel>();
    final user = context.watch<AuthViewModel>().user!;
    final event = vm.event;
    final theme = Theme.of(context);

    if (!vm.loaded) return const Scaffold(body: LoadingView());
    if (event == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(icon: Icons.event_busy, title: 'Event not found'),
      );
    }

    final saved = user.savedEventIds.contains(event.id);
    final following = user.followingOrganiserIds.contains(event.organiserId);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (context, inner) => [
            SliverAppBar(
              expandedHeight: 260,
              pinned: true,
              backgroundColor: AppColors.indigo,
              foregroundColor: AppColors.white,
              actions: [
                IconButton(
                  tooltip: saved ? 'Unsave' : 'Save',
                  icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
                  onPressed: () => vm.toggleSave(currentlySaved: saved),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    EventPoster(event: event, height: 260),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xAA1E1B4B)],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              StatusChip(label: event.category, color: AppColors.white),
                              const SizedBox(width: 6),
                              StatusChip(
                                label: event.isFree ? 'Free' : Fmt.rm(event.price),
                                color: AppColors.white,
                              ),
                              const SizedBox(width: 6),
                              StatusChip(label: event.format, color: AppColors.white),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            event.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(child: _LiveBanner(event: event)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  children: [
                    _KeyFacts(event: event, registration: vm.registration),
                    const SizedBox(height: 14),
                    _OrganiserRow(
                      event: event,
                      following: following,
                      onFollow: () => vm.toggleFollow(currentlyFollowing: following),
                    ),
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(
                const TabBar(
                  tabs: [
                    Tab(text: 'About'),
                    Tab(text: 'Schedule'),
                    Tab(text: 'Vendors'),
                    Tab(text: 'Updates'),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            children: [
              _AboutTab(vm: vm),
              _ScheduleTab(event: event),
              _VendorsTab(vm: vm),
              _UpdatesTab(vm: vm),
            ],
          ),
        ),
        bottomNavigationBar: _RegisterBar(vm: vm),
      ),
    );
  }
}

class _LiveBanner extends StatelessWidget {
  const _LiveBanner({required this.event});
  final Event event;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    String? text;
    Color color = AppColors.indigo;
    IconData icon = Icons.info_outline;
    switch (event.status) {
      case EventStatus.cancelled:
        text = 'This event has been cancelled.';
        color = AppColors.red;
        icon = Icons.cancel_outlined;
      case EventStatus.checkInOpen:
        text = 'Check-in is open — have your QR ticket ready.';
        color = AppColors.green;
        icon = Icons.qr_code_scanner;
      case EventStatus.live:
        text = 'Happening now';
        color = AppColors.green;
        icon = Icons.play_circle_outline;
      case EventStatus.delayed:
        text = 'Running late — check Updates for the new time.';
        color = AppColors.orange;
        icon = Icons.schedule;
      case EventStatus.ended:
        text = 'This event has ended.';
        color = AppColors.textSecondary;
        icon = Icons.flag_outlined;
      case EventStatus.upcoming:
        final diff = event.startTime.difference(now);
        if (!diff.isNegative && diff.inHours < 3) {
          text = 'Starting soon';
          color = AppColors.orange;
          icon = Icons.schedule;
        } else if (event.isFull) {
          text = 'Fully booked • ${event.waitlistCount} on the waitlist';
          color = AppColors.orange;
          icon = Icons.people_outline;
        }
    }
    if (text == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: color.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyFacts extends StatelessWidget {
  const _KeyFacts({required this.event, required this.registration});
  final Event event;
  final Registration? registration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget fact(IconData icon, String title, String subtitle, {VoidCallback? onTap}) => InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceTint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: AppColors.indigo),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                      Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                if (onTap != null) const Icon(Icons.open_in_new, size: 16, color: AppColors.indigo),
              ],
            ),
          ),
        );

    final services = context.read<AppServices>();
    return AppCard(
      child: Column(
        children: [
          fact(Icons.calendar_today_outlined, Fmt.date(event.startTime), Fmt.timeRange(event.startTime, event.endTime)),
          fact(Icons.place_outlined, event.venue, 'Tap for Google Maps directions', onTap: () => services.maps.openDirections(event)),
          const Divider(height: 16),
          SeatIndicator(event: event, dense: false),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (registration != null && registration!.isActive)
                StatusChip(
                  label: registration!.status == RegistrationStatus.waitlisted
                      ? 'You are waitlisted #${registration!.waitlistPosition ?? '-'}'
                      : 'You are registered',
                  color: registration!.status == RegistrationStatus.waitlisted ? AppColors.orange : AppColors.green,
                  icon: Icons.check_circle,
                ),
              if (registration?.status == RegistrationStatus.attended)
                const StatusChip(label: 'Attended', color: AppColors.green, icon: Icons.verified),
              if (event.certificateOffered)
                const StatusChip(label: 'Certificate', color: AppColors.indigo, icon: Icons.workspace_premium_outlined),
              StatusChip(
                label: event.photographyAllowed ? 'Photos OK' : 'No photos',
                color: AppColors.textSecondary,
                icon: event.photographyAllowed ? Icons.photo_camera_outlined : Icons.no_photography_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrganiserRow extends StatelessWidget {
  const _OrganiserRow({required this.event, required this.following, required this.onFollow});
  final Event event;
  final bool following;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          UserAvatar(name: event.organiserName, radius: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Organised by', style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textSecondary)),
                Text(event.organiserName, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          FilledButton.tonal(
            onPressed: onFollow,
            style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
            child: Text(following ? 'Following' : 'Follow'),
          ),
        ],
      ),
    );
  }
}

class _AboutTab extends StatelessWidget {
  const _AboutTab({required this.vm});
  final EventDetailsViewModel vm;

  @override
  Widget build(BuildContext context) {
    final e = vm.event!;
    final theme = Theme.of(context);
    final weather = vm.weather;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text(e.description, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
        if (e.requirements.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('What to bring / requirements', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(e.requirements, style: theme.textTheme.bodyMedium),
        ],
        if (e.speakers.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('Speakers', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...e.speakers.map(
            (s) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: UserAvatar(name: s.name, photoUrl: s.photoUrl),
              title: Text(s.name),
              subtitle: s.title.isEmpty ? null : Text(s.title),
            ),
          ),
        ],
        if (weather != null) ...[
          const SizedBox(height: 18),
          AppCard(
            color: weather.rainLikely ? AppColors.orange.withValues(alpha: 0.1) : AppColors.surfaceTint,
            child: Row(
              children: [
                Icon(
                  weather.rainLikely ? Icons.umbrella_outlined : Icons.wb_sunny_outlined,
                  color: weather.rainLikely ? AppColors.orange : AppColors.indigo,
                  size: 32,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Forecast for event day: ${weather.summary}',
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${weather.minTempC.round()}–${weather.maxTempC.round()}°C • ${weather.rainChance}% chance of rain'
                        '${e.isOutdoor ? ' • Outdoor event' : ''}',
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Weather by Open-Meteo', style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textSecondary)),
          ),
        ],
      ],
    );
  }
}

class _ScheduleTab extends StatelessWidget {
  const _ScheduleTab({required this.event});
  final Event event;

  @override
  Widget build(BuildContext context) {
    if (event.schedule.isEmpty) {
      return const EmptyState(icon: Icons.schedule, title: 'Schedule coming soon', message: 'The organiser has not published an agenda yet.');
    }
    final theme = Theme.of(context);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: event.schedule.length,
      itemBuilder: (context, i) {
        final s = event.schedule[i];
        final last = i == event.schedule.length - 1;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 76,
                child: Text(s.time, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700, color: AppColors.indigo)),
              ),
              Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(color: AppColors.indigo, shape: BoxShape.circle),
                  ),
                  if (!last) Expanded(child: Container(width: 2, color: AppColors.divider)),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                      if (s.description.isNotEmpty)
                        Text(s.description, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _VendorsTab extends StatelessWidget {
  const _VendorsTab({required this.vm});
  final EventDetailsViewModel vm;

  @override
  Widget build(BuildContext context) {
    final vendors = vm.vendors;
    if (vendors.isEmpty) {
      return const EmptyState(
        icon: Icons.storefront_outlined,
        title: 'No vendors yet',
        message: 'Approved vendors, their menus and booth locations will appear here.',
      );
    }
    final services = context.read<AppServices>();
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: vendors.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final v = vendors[i];
        return StreamBuilder<List<Product>>(
          stream: services.products.watchMenu(v.vendorId),
          builder: (context, snap) {
            final products = snap.data ?? const [];
            return _VendorCard(
              application: v,
              products: products,
              onTap: () => context.push(Routes.vendorMenu(vm.eventId, v.vendorId)),
            );
          },
        );
      },
    );
  }
}

class _VendorCard extends StatelessWidget {
  const _VendorCard({required this.application, required this.products, required this.onTap});
  final VendorApplication application;
  final List<Product> products;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = products.take(3).toList();
    final lowStock = products.where((p) => p.stockStatus == StockStatus.lowStock).length;
    final soldOut = products.where((p) => p.stockStatus == StockStatus.soldOut).length;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(name: application.vendorName, radius: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(application.vendorName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    Text(
                      '${application.productCategory}${application.boothNumber != null ? ' • Booth ${application.boothNumber}' : ''}',
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
          if (preview.isNotEmpty) ...[
            const Divider(height: 18),
            ...preview.map(
              (p) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(child: Text(p.name, style: theme.textTheme.bodySmall)),
                    if (p.stockStatus != StockStatus.available) ...[
                      StatusChip(
                        label: p.stockStatus.label,
                        color: p.stockStatus == StockStatus.soldOut ? AppColors.red : AppColors.orange,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(Fmt.rm(p.price), style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            if (products.length > 3)
              Text('+${products.length - 3} more', style: theme.textTheme.labelSmall?.copyWith(color: AppColors.indigo)),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              const StatusChip(label: 'Sandbox payment', color: AppColors.textSecondary, icon: Icons.credit_card),
              const SizedBox(width: 6),
              if (lowStock > 0) StatusChip(label: '$lowStock low stock', color: AppColors.orange),
              if (soldOut > 0) ...[
                const SizedBox(width: 6),
                StatusChip(label: '$soldOut sold out', color: AppColors.red),
              ],
              const Spacer(),
              const Text('Pre-order →', style: TextStyle(color: AppColors.indigo, fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }
}

class _UpdatesTab extends StatelessWidget {
  const _UpdatesTab({required this.vm});
  final EventDetailsViewModel vm;

  @override
  Widget build(BuildContext context) {
    final items = vm.announcements;
    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.campaign_outlined,
        title: 'No updates yet',
        message: 'Venue or time changes and reminders from the organiser will show here.',
      );
    }
    final theme = Theme.of(context);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final a = items[i];
        final color = switch (a.type) {
          AnnouncementType.cancellation => AppColors.red,
          AnnouncementType.venueChange || AnnouncementType.timeChange => AppColors.orange,
          AnnouncementType.reminder => AppColors.green,
          AnnouncementType.general => AppColors.indigo,
        };
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StatusChip(label: a.type.label, color: color),
                  const Spacer(),
                  if (a.createdAt != null)
                    Text(Fmt.relative(a.createdAt!), style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 8),
              Text(a.title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(a.body, style: theme.textTheme.bodyMedium),
            ],
          ),
        );
      },
    );
  }
}

/// Persistent Register / Join Waitlist / View Ticket bar.
class _RegisterBar extends StatelessWidget {
  const _RegisterBar({required this.vm});
  final EventDetailsViewModel vm;

  @override
  Widget build(BuildContext context) {
    final e = vm.event!;
    final reg = vm.registration;
    Widget child;
    if (reg != null && reg.isActive) {
      child = Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: vm.busy
                  ? null
                  : () async {
                      final ok = await confirmDialog(
                        context,
                        title: 'Cancel registration?',
                        message: 'Your seat will go to the next student on the waitlist.',
                        confirmLabel: 'Cancel registration',
                        destructive: true,
                      );
                      if (!ok) return;
                      final done = await vm.cancelRegistration();
                      if (context.mounted) {
                        showAppSnackBar(
                          context,
                          done ? 'Registration cancelled.' : (vm.error ?? 'Could not cancel.'),
                          error: !done,
                          success: done,
                        );
                      }
                    },
              icon: const Icon(Icons.close, size: 18),
              label: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: () => context.push(Routes.ticket(reg.id)),
              icon: Icon(reg.status == RegistrationStatus.waitlisted ? Icons.hourglass_top : Icons.qr_code_2),
              label: Text(reg.status == RegistrationStatus.waitlisted ? 'Waitlist #${reg.waitlistPosition ?? '-'}' : 'View Ticket'),
            ),
          ),
        ],
      );
    } else if (reg?.status == RegistrationStatus.attended) {
      child = ElevatedButton.icon(
        onPressed: () => context.push(Routes.feedback(e.id)),
        icon: const Icon(Icons.star_outline),
        label: const Text('Rate this event'),
      );
    } else if (!e.registrationOpen) {
      child = const ElevatedButton(onPressed: null, child: Text('Registration closed'));
    } else {
      child = ElevatedButton.icon(
        key: const Key('details_register'),
        onPressed: () => registerForEvent(context, e),
        style: e.isFull ? ElevatedButton.styleFrom(backgroundColor: AppColors.orange) : null,
        icon: Icon(e.isFull ? Icons.hourglass_top : Icons.how_to_reg),
        label: Text(e.isFull ? 'Join Waitlist' : 'Register'),
      );
    }
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [BoxShadow(color: AppColors.midnight.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: child,
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate(this.tabBar);
  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Container(color: AppColors.cloud, child: tabBar);

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}

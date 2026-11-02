import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/formatters.dart';
import '../../../models/models.dart';
import '../../../services/app_services.dart';
import '../../../theme/app_colors.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../viewmodels/vendor/vendor_viewmodels.dart';
import '../../../widgets/common_widgets.dart';
import '../../../widgets/event_card.dart';

/// Event from the vendor's point of view: requirements, expected
/// attendance, facilities, fee, apply / track; approved vendors see booth,
/// arrival, parking and setup instructions plus organiser announcements.
class VendorEventDetailsPage extends StatelessWidget {
  const VendorEventDetailsPage({super.key, required this.eventId});
  final String eventId;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthViewModel>().user!;
    final services = context.read<AppServices>();
    // Reuse the shared dashboard VM when inside the shell; otherwise create.
    final existing = context.read<VendorDashboardViewModel?>();
    final body = _Body(eventId: eventId);
    if (existing != null) return body;
    return ChangeNotifierProvider(create: (_) => VendorDashboardViewModel(services, user), child: body);
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.eventId});
  final String eventId;

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();
    final vm = context.watch<VendorDashboardViewModel>();
    final user = context.watch<AuthViewModel>().user!;
    final theme = Theme.of(context);

    return StreamBuilder<Event?>(
      stream: services.events.watch(eventId),
      builder: (context, snap) {
        final e = snap.data;
        if (!snap.hasData && snap.connectionState == ConnectionState.waiting) return const Scaffold(body: LoadingView());
        if (e == null) return Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.event_busy, title: 'Event not found'));
        final app = vm.applicationFor(e.id);
        final eligible = !e.studentVendorsOnly || user.isStudentVendor;
        final categoryOk = e.allowedProductCategories.isEmpty || e.allowedProductCategories.contains(user.productCategory);

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor: AppColors.indigo,
                foregroundColor: AppColors.white,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      EventPoster(event: e, height: 200),
                      const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xCC1E1B4B)]))),
                      Positioned(
                        left: 20,
                        right: 20,
                        bottom: 14,
                        child: Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleLarge?.copyWith(color: AppColors.white, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
                sliver: SliverList.list(
                  children: [
                    if (app != null) _StatusCard(app: app, vm: vm),
                    if (app != null) const SizedBox(height: 14),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Event details', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          _kv(Icons.calendar_today_outlined, 'When', '${Fmt.date(e.startTime)} • ${Fmt.timeRange(e.startTime, e.endTime)}'),
                          _kv(Icons.place_outlined, 'Venue', e.venue),
                          _kv(Icons.groups_outlined, 'Organiser', e.organiserName),
                          _kv(Icons.people_outline, 'Expected attendance', '${e.registeredCount} registered of ${e.capacity} capacity'),
                          _kv(Icons.payments_outlined, 'Vendor fee', e.vendorFee == 0 ? 'Free' : Fmt.rm(e.vendorFee)),
                          _kv(Icons.chair_outlined, 'Facilities', e.vendorFacilities.isEmpty ? 'Not specified' : e.vendorFacilities.join(', ')),
                          _kv(Icons.category_outlined, 'Allowed products', e.allowedProductCategories.isEmpty ? 'Any' : e.allowedProductCategories.join(', ')),
                          _kv(Icons.rule_outlined, 'Requirements', e.vendorRequirements.isEmpty ? (e.studentVendorsOnly ? 'Student-run booths only (APU policy).' : '—') : e.vendorRequirements),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('About the event', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text(e.description, style: theme.textTheme.bodyMedium),
                        ],
                      ),
                    ),
                    if (app?.status == ApplicationStatus.approved) ...[
                      const SizedBox(height: 14),
                      Text('Organiser updates', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      StreamBuilder<List<Announcement>>(
                        stream: services.announcements.watchByEvent(e.id),
                        builder: (context, s) {
                          final items = (s.data ?? const <Announcement>[]).where((a) => a.notifyVendors).toList();
                          if (items.isEmpty) return const Text('No updates yet.', style: TextStyle(color: AppColors.textSecondary));
                          return Column(
                            children: items
                                .map(
                                  (a) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: AppCard(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              StatusChip(label: a.type.label, color: AppColors.indigo),
                                              const Spacer(),
                                              if (a.createdAt != null) Text(Fmt.relative(a.createdAt!), style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textSecondary)),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(a.title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                                          Text(a.body, style: theme.textTheme.bodySmall),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          );
                        },
                      ),
                    ],
                    if (!eligible || !categoryOk) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.orange.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                        child: Text(
                          !eligible
                              ? 'This event only accepts student-run booths. Update your profile if you are an APU student vendor.'
                              : 'Your product category (${user.productCategory ?? '—'}) is not in this event\'s allowed list. You can still apply; the organiser decides.',
                          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.orange, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: Container(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
            color: AppColors.white,
            child: app == null
                ? BusyButton(
                    label: e.acceptsVendors && !e.hasEnded ? 'Apply to participate' : 'Applications closed',
                    icon: Icons.storefront_outlined,
                    busy: vm.busy,
                    onPressed: e.acceptsVendors && !e.hasEnded && eligible ? () => _apply(context, vm, e) : null,
                  )
                : app.status == ApplicationStatus.pending
                    ? OutlinedButton.icon(
                        onPressed: vm.busy
                            ? null
                            : () async {
                                final ok = await confirmDialog(context, title: 'Withdraw application?', message: 'You can apply again later while applications are open.', confirmLabel: 'Withdraw', destructive: true);
                                if (ok) await vm.withdraw(app);
                              },
                        icon: const Icon(Icons.undo),
                        label: const Text('Withdraw application'),
                      )
                    : app.status == ApplicationStatus.approved && app.checkedInAt == null
                        ? BusyButton(
                            label: "I've arrived — check in booth",
                            icon: Icons.where_to_vote_outlined,
                            color: AppColors.green,
                            busy: vm.busy,
                            onPressed: () async {
                              final ok = await vm.checkInAtEvent(app);
                              if (context.mounted && ok) showAppSnackBar(context, 'Arrival recorded. The organiser can see you are set up.', success: true);
                            },
                          )
                        : ElevatedButton(onPressed: null, child: Text(app.status == ApplicationStatus.rejected ? 'Application rejected' : 'Checked in ✓')),
          ),
        );
      },
    );
  }

  Widget _kv(IconData icon, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: AppColors.indigo),
            const SizedBox(width: 10),
            SizedBox(width: 120, child: Text(k, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
            Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          ],
        ),
      );

  Future<void> _apply(BuildContext context, VendorDashboardViewModel vm, Event e) async {
    final msg = TextEditingController(text: 'We would love to join ${e.title}. Our menu is listed in UniEvent.');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apply to participate'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Fee: ${e.vendorFee == 0 ? 'Free' : Fmt.rm(e.vendorFee)} • The organiser will review your profile and menu.', style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(height: 12),
            TextField(controller: msg, maxLines: 3, decoration: const InputDecoration(labelText: 'Message to organiser')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit application')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final done = await vm.apply(e, msg.text.trim());
    if (context.mounted) showAppSnackBar(context, done ? 'Application submitted. You will be notified of the decision.' : (vm.error ?? 'Failed'), success: done, error: !done);
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.app, required this.vm});
  final VendorApplication app;
  final VendorDashboardViewModel vm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (app.status) {
      ApplicationStatus.pending => AppColors.orange,
      ApplicationStatus.approved => AppColors.green,
      ApplicationStatus.rejected => AppColors.red,
    };
    return AppCard(
      color: color.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                switch (app.status) {
                  ApplicationStatus.pending => Icons.hourglass_top,
                  ApplicationStatus.approved => Icons.verified,
                  ApplicationStatus.rejected => Icons.cancel_outlined,
                },
                color: color,
              ),
              const SizedBox(width: 8),
              Text('Application ${app.status.label.toLowerCase()}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: color)),
            ],
          ),
          if (app.status == ApplicationStatus.approved) ...[
            const SizedBox(height: 10),
            _row('Booth', app.boothNumber ?? 'To be confirmed'),
            _row('Arrival time', app.arrivalTime ?? 'To be confirmed'),
            _row('Parking', app.parkingDetails ?? '—'),
            _row('Setup', app.setupInstructions ?? '—'),
            if (app.checkedInAt != null) _row('Checked in', Fmt.dateTime(app.checkedInAt!)),
          ],
          if (app.organiserNote != null && app.organiserNote!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Organiser: ${app.organiserNote}', style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
          ],
          if (app.status == ApplicationStatus.pending)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('The organiser is reviewing your application. You will get a notification either way.', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
            ),
        ],
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 100, child: Text(k, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
            Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          ],
        ),
      );
}

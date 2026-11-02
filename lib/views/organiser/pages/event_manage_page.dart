import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/formatters.dart';
import '../../../models/models.dart';
import '../../../navigation/app_router.dart';
import '../../../services/app_services.dart';
import '../../../theme/app_colors.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../viewmodels/organiser/organiser_viewmodels.dart';
import '../../../widgets/common_widgets.dart';
import '../../../widgets/event_card.dart';
import '../tabs/organiser_vendors_tab.dart' show VendorApplicationTile;

/// Hub for one event: stats, status controls, Seat Rescue, crew tasks,
/// vendors and links to registrations / announcements / budget / report.
class EventManagePage extends StatelessWidget {
  const EventManagePage({super.key, required this.eventId});
  final String eventId;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthViewModel>().user!;
    return ChangeNotifierProvider(
      create: (ctx) => EventManageViewModel(ctx.read<AppServices>(), user, eventId),
      child: const _ManageBody(),
    );
  }
}

class _ManageBody extends StatelessWidget {
  const _ManageBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<EventManageViewModel>();
    final e = vm.event;
    final theme = Theme.of(context);
    if (!vm.loaded) return const Scaffold(body: LoadingView());
    if (e == null) return Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.event_busy, title: 'Event not found'));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.indigo,
            foregroundColor: AppColors.white,
            actions: [
              IconButton(tooltip: 'Edit event', icon: const Icon(Icons.edit_outlined), onPressed: () => context.push(Routes.eventEdit(e.id))),
              PopupMenuButton<String>(
                onSelected: (v) => _menu(context, vm, v),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'status', child: Text('Change live status')),
                  const PopupMenuItem(value: 'capacity', child: Text('Change capacity')),
                  const PopupMenuItem(value: 'deadline', child: Text('Registration deadline')),
                  if (!e.isCancelled && !e.hasEnded) const PopupMenuItem(value: 'cancel', child: Text('Cancel event', style: TextStyle(color: AppColors.red))),
                ],
              ),
            ],
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleLarge?.copyWith(color: AppColors.white, fontWeight: FontWeight.w800)),
                        Text('${Fmt.dateTime(e.startTime)} • ${e.venue}', maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.white)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            sliver: SliverList.list(
              children: [
                Row(
                  children: [
                    StatusChip(label: e.status.label, color: _statusColor(e.status)),
                    const SizedBox(width: 8),
                    StatusChip(label: e.isFree ? 'Free' : Fmt.rm(e.price), color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    if (e.allowWalkIns) const StatusChip(label: 'Walk-ins on', color: AppColors.green),
                    const Spacer(),
                    TextButton(onPressed: () => _menu(context, vm, 'status'), child: const Text('Set status')),
                  ],
                ),
                if (vm.error != null) ...[
                  const SizedBox(height: 8),
                  Text(vm.error!, style: const TextStyle(color: AppColors.red)),
                ],
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.3,
                  children: [
                    StatCard(label: 'Registered', value: '${e.registeredCount} / ${e.capacity}', icon: Icons.how_to_reg_outlined, onTap: () => context.push(Routes.eventRegistrations(e.id))),
                    StatCard(label: 'Confirmed', value: '${e.confirmedCount}', icon: Icons.verified_outlined, color: AppColors.green, onTap: () => context.push(Routes.eventRegistrations(e.id))),
                    StatCard(label: 'Forecast', value: vm.forecast == null ? '—' : '${vm.forecast}', icon: Icons.insights_outlined, color: AppColors.electricBlue),
                    StatCard(label: 'Waitlist', value: '${e.waitlistCount}', icon: Icons.hourglass_top_outlined, color: AppColors.orange, onTap: () => context.push(Routes.eventRegistrations(e.id))),
                  ],
                ),
                if (vm.showUpRate != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Forecast uses a ${(vm.showUpRate! * 100).round()}% historical show-up rate for ${e.category} events.',
                      style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
                    ),
                  ),

                const SizedBox(height: 18),
                _SeatRescueCard(vm: vm),

                const SizedBox(height: 18),
                Text('Manage', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                _NavTile(icon: Icons.people_outline, title: 'Registrations & attendance', subtitle: '${vm.attended.length} attended • ${vm.waitlisted.length} waiting', onTap: () => context.push(Routes.eventRegistrations(e.id))),
                _NavTile(icon: Icons.qr_code_scanner, title: 'QR check-in', subtitle: 'Scan tickets, manual search, offline queue', color: AppColors.green, onTap: () => context.push(Routes.eventCheckin(e.id))),
                _NavTile(icon: Icons.campaign_outlined, title: 'Announcements', subtitle: 'Venue / time changes, reminders', color: AppColors.orange, onTap: () => context.push(Routes.eventAnnouncements(e.id))),
                _NavTile(icon: Icons.account_balance_wallet_outlined, title: 'Budget', subtitle: 'Planned vs actual, receipts', color: AppColors.electricBlue, onTap: () => context.push(Routes.eventBudget(e.id))),
                _NavTile(icon: Icons.bar_chart_outlined, title: 'Post-event report', subtitle: 'Attendance, no-shows, feedback, PDF export', color: AppColors.midnight, onTap: () => context.push(Routes.eventReport(e.id))),

                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(child: Text('Crew task board', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                    TextButton.icon(onPressed: () => _addTask(context, vm), icon: const Icon(Icons.add, size: 18), label: const Text('Add task')),
                  ],
                ),
                if (vm.tasks.isEmpty)
                  const Text('Assign committee tasks so everyone can see what is done and what is pending.', style: TextStyle(color: AppColors.textSecondary))
                else
                  AppCard(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      children: vm.tasks
                          .map(
                            (t) => ListTile(
                              dense: true,
                              leading: IconButton(
                                onPressed: () => vm.cycleTask(t),
                                icon: Icon(
                                  t.status == TaskStatus.done ? Icons.check_circle : t.status == TaskStatus.inProgress ? Icons.timelapse : Icons.radio_button_unchecked,
                                  color: t.status == TaskStatus.done ? AppColors.green : t.status == TaskStatus.inProgress ? AppColors.orange : AppColors.textSecondary,
                                ),
                              ),
                              title: Text(t.title, style: TextStyle(decoration: t.status == TaskStatus.done ? TextDecoration.lineThrough : null)),
                              subtitle: Text('${t.owner} • ${t.status.label}'),
                              trailing: IconButton(icon: const Icon(Icons.delete_outline, size: 20), onPressed: () => vm.deleteTask(t)),
                            ),
                          )
                          .toList(),
                    ),
                  ),

                const SizedBox(height: 18),
                Text('Vendors (${vm.vendorApplications.length})', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                if (!e.acceptsVendors)
                  const Text('This event does not accept vendor applications. Enable it in Edit event.', style: TextStyle(color: AppColors.textSecondary))
                else if (vm.vendorApplications.isEmpty)
                  const Text('No vendor applications yet.', style: TextStyle(color: AppColors.textSecondary))
                else
                  ...vm.vendorApplications.map((a) => Padding(padding: const EdgeInsets.only(bottom: 10), child: VendorApplicationTile(app: a, showEvent: false))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(EventStatus s) => switch (s) {
        EventStatus.cancelled => AppColors.red,
        EventStatus.ended => AppColors.textSecondary,
        EventStatus.checkInOpen || EventStatus.live => AppColors.green,
        EventStatus.delayed => AppColors.orange,
        EventStatus.upcoming => AppColors.indigo,
      };

  Future<void> _menu(BuildContext context, EventManageViewModel vm, String action) async {
    final e = vm.event!;
    switch (action) {
      case 'status':
        final s = await showModalBottomSheet<EventStatus>(
          context: context,
          showDragHandle: true,
          builder: (ctx) => ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              const Padding(padding: EdgeInsets.all(8), child: Text('Live status banner', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
              ...EventStatus.values.where((s) => s != EventStatus.cancelled).map(
                (s) => ListTile(
                  leading: Icon(
                    s == e.status ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: s == e.status ? AppColors.indigo : AppColors.textSecondary,
                  ),
                  title: Text(s.label),
                  subtitle: Text(_statusHint(s)),
                  onTap: () => Navigator.pop(ctx, s),
                ),
              ),
            ],
          ),
        );
        if (s != null) await vm.setStatus(s);
      case 'capacity':
        final c = TextEditingController(text: '${e.capacity}');
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Change capacity'),
            content: TextField(controller: c, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Seats')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
            ],
          ),
        );
        final n = int.tryParse(c.text);
        if (ok == true && n != null && n > 0) {
          await vm.updateCapacity(n);
          if (context.mounted) showAppSnackBar(context, 'Capacity set to $n. Waitlisted students are promoted when seats free up.', success: true);
        }
      case 'deadline':
        if (!context.mounted) return;
        final d = await showDatePicker(context: context, initialDate: e.registrationDeadline ?? e.startTime, firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: e.startTime);
        if (d != null) await vm.updateDeadline(DateTime(d.year, d.month, d.day, 23, 59));
      case 'cancel':
        final reason = TextEditingController(text: 'Unfortunately this event has been cancelled. We apologise for the inconvenience.');
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Cancel event?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('All registered and waitlisted students will be notified immediately.'),
                const SizedBox(height: 12),
                TextField(controller: reason, maxLines: 3, decoration: const InputDecoration(labelText: 'Message to attendees')),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep event')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: AppColors.red), child: const Text('Cancel event')),
            ],
          ),
        );
        if (ok == true && context.mounted) {
          final done = await vm.cancelEvent(reason.text.trim());
          if (context.mounted) showAppSnackBar(context, done ? 'Event cancelled and attendees notified.' : 'Could not cancel.', success: done, error: !done);
        }
    }
  }

  String _statusHint(EventStatus s) => switch (s) {
        EventStatus.upcoming => 'Default before the day',
        EventStatus.checkInOpen => 'Tells students to have their QR ready',
        EventStatus.live => 'Event in progress',
        EventStatus.delayed => 'Shows a "running late" banner',
        EventStatus.ended => 'Unlocks feedback and the final report',
        EventStatus.cancelled => '',
      };

  Future<void> _addTask(BuildContext context, EventManageViewModel vm) async {
    final title = TextEditingController();
    final owner = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New crew task'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: title, autofocus: true, decoration: const InputDecoration(labelText: 'Task')),
            const SizedBox(height: 10),
            TextField(controller: owner, decoration: const InputDecoration(labelText: 'Owner (name or role)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, title.text.trim().isNotEmpty), child: const Text('Add')),
        ],
      ),
    );
    if (ok == true) await vm.addTask(title.text.trim(), owner.text.trim().isEmpty ? 'Unassigned' : owner.text.trim());
  }
}

class _SeatRescueCard extends StatelessWidget {
  const _SeatRescueCard({required this.vm});
  final EventManageViewModel vm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = vm.event!;
    final unconfirmed = vm.registered.where((r) => !r.confirmed).length;
    return AppCard(
      color: AppColors.orange.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_seat_outlined, color: AppColors.orange),
              const SizedBox(width: 8),
              Text('Seat Rescue', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              if (vm.seatRescueReleased)
                const StatusChip(label: 'Seats released', color: AppColors.green, icon: Icons.check)
              else if (vm.seatRescueSent)
                const StatusChip(label: 'Confirmations sent', color: AppColors.orange, icon: Icons.send),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Registrants are asked to confirm ~${e.seatRescueHoursBefore}h before the event. Unconfirmed seats are released to the waitlist ${e.seatRescueDeadlineHours}h before start. '
            'The scheduled Cloud Function runs this automatically; you can also trigger each step here.',
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Text('${vm.confirmed.length} confirmed • $unconfirmed unconfirmed • ${vm.waitlisted.length} waitlisted', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: vm.busy || !vm.canSendSeatRescue
                      ? null
                      : () async {
                          final n = await vm.sendSeatRescue();
                          if (context.mounted) showAppSnackBar(context, 'Confirmation request sent to $n students.', success: true);
                        },
                  icon: const Icon(Icons.send_outlined, size: 18),
                  label: const Text('Send requests'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: vm.busy || !vm.canReleaseSeats
                      ? null
                      : () async {
                          final ok = await confirmDialog(
                            context,
                            title: 'Release unconfirmed seats?',
                            message: '$unconfirmed unconfirmed registrations will be cancelled and up to ${vm.waitlisted.length} waitlisted students promoted.',
                            confirmLabel: 'Release',
                            destructive: true,
                          );
                          if (!ok) return;
                          final (released, promoted) = await vm.releaseSeats();
                          if (context.mounted) showAppSnackBar(context, 'Released $released seat(s), promoted $promoted student(s).', success: true);
                        },
                  style: FilledButton.styleFrom(backgroundColor: AppColors.orange),
                  icon: const Icon(Icons.swap_vert, size: 18),
                  label: const Text('Release seats'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.icon, required this.title, required this.subtitle, required this.onTap, this.color = AppColors.indigo});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

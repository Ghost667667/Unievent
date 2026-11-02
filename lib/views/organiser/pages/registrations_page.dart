import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/formatters.dart';
import '../../../models/models.dart';
import '../../../services/app_services.dart';
import '../../../theme/app_colors.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../viewmodels/organiser/organiser_viewmodels.dart';
import '../../../widgets/common_widgets.dart';

/// Registration Management: registered, confirmed, waitlisted, attended,
/// cancelled — with seats left, walk-in toggle and attendee removal.
class RegistrationsPage extends StatelessWidget {
  const RegistrationsPage({super.key, required this.eventId});
  final String eventId;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthViewModel>().user!;
    return ChangeNotifierProvider(
      create: (ctx) => EventManageViewModel(ctx.read<AppServices>(), user, eventId),
      child: const _RegistrationsBody(),
    );
  }
}

class _RegistrationsBody extends StatefulWidget {
  const _RegistrationsBody();

  @override
  State<_RegistrationsBody> createState() => _RegistrationsBodyState();
}

class _RegistrationsBodyState extends State<_RegistrationsBody> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<EventManageViewModel>();
    final e = vm.event;
    final theme = Theme.of(context);
    if (!vm.loaded || e == null) return const Scaffold(body: LoadingView());

    List<Registration> filter(List<Registration> list) {
      if (_query.isEmpty) return list;
      final q = _query.toLowerCase();
      return list.where((r) => r.studentName.toLowerCase().contains(q) || r.studentTp.toLowerCase().contains(q)).toList();
    }

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Registrations'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Registered (${vm.registered.length})'),
              Tab(text: 'Confirmed (${vm.confirmed.length})'),
              Tab(text: 'Waitlist (${vm.waitlisted.length})'),
              Tab(text: 'Attended (${vm.attended.length})'),
              Tab(text: 'Cancelled (${vm.cancelled.length})'),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: AppCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _Stat('Seats left', '${e.seatsLeft}', e.isFull ? AppColors.red : AppColors.green),
                        _Stat('Capacity', '${e.capacity}', AppColors.indigo),
                        _Stat('Attendance', '${e.attendedCount}', AppColors.electricBlue),
                        _Stat('No-shows', e.hasEnded ? '${(e.registeredCount - e.attendedCount).clamp(0, e.registeredCount)}' : '—', AppColors.orange),
                      ],
                    ),
                    const Divider(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Walk-ins', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                              Text('Register unregistered students at the door while seats remain', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        Switch(value: e.allowWalkIns, onChanged: vm.busy ? null : (v) => vm.toggleWalkIns(v)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(hintText: 'Search by name or TP number', prefixIcon: Icon(Icons.search)),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _List(items: filter(vm.registered), vm: vm, empty: 'No registered students yet'),
                  _List(items: filter(vm.confirmed), vm: vm, empty: 'No confirmations yet', hint: 'Students confirm from their ticket after a Seat Rescue request.'),
                  _List(items: filter(vm.waitlisted), vm: vm, empty: 'Waitlist is empty', hint: 'Students join automatically once the event is full.'),
                  _List(items: filter(vm.attended), vm: vm, empty: 'Nobody checked in yet'),
                  _List(items: filter(vm.cancelled), vm: vm, empty: 'No cancellations'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: color)),
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.items, required this.vm, required this.empty, this.hint});
  final List<Registration> items;
  final EventManageViewModel vm;
  final String empty;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return EmptyState(icon: Icons.people_outline, title: empty, message: hint);
    final theme = Theme.of(context);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final r = items[i];
        return AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              if (r.waitlistPosition != null && r.status == RegistrationStatus.waitlisted)
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.orange.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                  child: Text('#${r.waitlistPosition}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.orange, fontSize: 12)),
                )
              else
                UserAvatar(name: r.studentName, radius: 17),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.studentName, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                    Text(
                      [
                        if (r.studentTp.isNotEmpty) r.studentTp,
                        if (r.programme != null) r.programme!,
                        if (r.isWalkIn) 'Walk-in',
                        if (r.checkedInAt != null) 'in ${Fmt.time(r.checkedInAt!)}',
                      ].join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (r.status == RegistrationStatus.registered)
                StatusChip(label: r.confirmed ? 'Confirmed' : 'Unconfirmed', color: r.confirmed ? AppColors.green : AppColors.textSecondary),
              if (r.isActive)
                IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.person_remove_outlined, size: 20, color: AppColors.red),
                  onPressed: vm.busy
                      ? null
                      : () async {
                          final ok = await confirmDialog(context, title: 'Remove ${r.studentName}?', message: 'Their seat will go to the next waitlisted student.', confirmLabel: 'Remove', destructive: true);
                          if (ok) await vm.removeAttendee(r);
                        },
                ),
            ],
          ),
        );
      },
    );
  }
}

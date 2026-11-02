import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/formatters.dart';
import '../../../core/validators.dart';
import '../../../models/models.dart';
import '../../../services/app_services.dart';
import '../../../theme/app_colors.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../viewmodels/organiser/organiser_viewmodels.dart';
import '../../../widgets/common_widgets.dart';

/// Send announcements (venue/time change, reminder, cancellation, general)
/// to registered students and approved vendors; view history.
class AnnouncementsPage extends StatelessWidget {
  const AnnouncementsPage({super.key, required this.eventId});
  final String eventId;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthViewModel>().user!;
    return ChangeNotifierProvider(
      create: (ctx) => EventManageViewModel(ctx.read<AppServices>(), user, eventId),
      child: _AnnouncementsBody(eventId: eventId),
    );
  }
}

class _AnnouncementsBody extends StatelessWidget {
  const _AnnouncementsBody({required this.eventId});
  final String eventId;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<EventManageViewModel>();
    final services = context.read<AppServices>();
    return Scaffold(
      appBar: AppBar(title: const Text('Announcements')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: vm.event == null ? null : () => _compose(context, vm),
        icon: const Icon(Icons.campaign_outlined),
        label: const Text('Send'),
      ),
      body: StreamBuilder<List<Announcement>>(
        stream: services.announcements.watchByEvent(eventId),
        builder: (context, snap) {
          if (!snap.hasData) return const LoadingView();
          final items = snap.data!;
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.campaign_outlined,
              title: 'No announcements yet',
              message: 'Students and vendors get a push notification and see it on the Updates tab.',
              action: FilledButton(onPressed: vm.event == null ? null : () => _compose(context, vm), child: const Text('Send first announcement')),
            );
          }
          final theme = Theme.of(context);
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final a = items[i];
              return AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        StatusChip(label: a.type.label, color: _color(a.type)),
                        const Spacer(),
                        if (a.createdAt != null) Text(Fmt.dateTime(a.createdAt!), style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(a.title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(a.body),
                    const SizedBox(height: 8),
                    Text(
                      'Sent to ${[if (a.notifyStudents) 'students', if (a.notifyVendors) 'vendors'].join(' & ')}',
                      style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _color(AnnouncementType t) => switch (t) {
        AnnouncementType.cancellation => AppColors.red,
        AnnouncementType.venueChange || AnnouncementType.timeChange => AppColors.orange,
        AnnouncementType.reminder => AppColors.green,
        AnnouncementType.general => AppColors.indigo,
      };

  Future<void> _compose(BuildContext context, EventManageViewModel vm) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ChangeNotifierProvider.value(value: vm, child: const _ComposeSheet()),
    );
  }
}

class _ComposeSheet extends StatefulWidget {
  const _ComposeSheet();

  @override
  State<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<_ComposeSheet> {
  final _key = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  AnnouncementType _type = AnnouncementType.general;
  bool _students = true;
  bool _vendors = true;

  static const _templates = {
    AnnouncementType.venueChange: ('Venue changed', 'The event has moved to [new venue]. Please head there directly.'),
    AnnouncementType.timeChange: ('New start time', 'The event will now start at [new time]. Doors open 30 minutes before.'),
    AnnouncementType.reminder: ('See you tomorrow!', 'Reminder: the event starts at [time] at [venue]. Have your QR ticket ready for check-in.'),
    AnnouncementType.cancellation: ('Event cancelled', 'Unfortunately the event has been cancelled. We apologise for the inconvenience.'),
    AnnouncementType.general: ('', ''),
  };

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<EventManageViewModel>();
    final theme = Theme.of(context);
    final recipients = (_students ? vm.registered.length + vm.waitlisted.length + vm.attended.length : 0) +
        (_vendors ? vm.vendorApplications.where((a) => a.status == ApplicationStatus.approved).length : 0);

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _key,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Send announcement', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AnnouncementType.values.map((t) {
                  final sel = _type == t;
                  return ChoiceChip(
                    label: Text(t.label),
                    selected: sel,
                    labelStyle: TextStyle(color: sel ? AppColors.white : AppColors.midnight),
                    onSelected: (_) => setState(() {
                      _type = t;
                      final tpl = _templates[t]!;
                      if (tpl.$1.isNotEmpty) {
                        _title.text = tpl.$1;
                        _body.text = tpl.$2;
                      }
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              TextFormField(controller: _title, validator: (v) => Validators.required(v, 'Title'), decoration: const InputDecoration(labelText: 'Title')),
              const SizedBox(height: 12),
              TextFormField(controller: _body, maxLines: 4, validator: (v) => Validators.required(v, 'Message'), decoration: const InputDecoration(labelText: 'Message', alignLabelWithHint: true)),
              const SizedBox(height: 8),
              CheckboxListTile(contentPadding: EdgeInsets.zero, value: _students, onChanged: (v) => setState(() => _students = v ?? true), title: const Text('Notify registered & waitlisted students')),
              CheckboxListTile(contentPadding: EdgeInsets.zero, value: _vendors, onChanged: (v) => setState(() => _vendors = v ?? true), title: const Text('Notify approved vendors')),
              const SizedBox(height: 8),
              BusyButton(
                label: 'Send to $recipients recipient${recipients == 1 ? '' : 's'}',
                icon: Icons.send,
                busy: vm.busy,
                onPressed: () async {
                  if (!_key.currentState!.validate()) return;
                  final ok = await vm.sendAnnouncement(type: _type, title: _title.text.trim(), body: _body.text.trim(), notifyStudents: _students, notifyVendors: _vendors);
                  if (!context.mounted) return;
                  if (ok) {
                    Navigator.pop(context);
                    showAppSnackBar(context, 'Announcement sent.', success: true);
                  } else {
                    showAppSnackBar(context, vm.error ?? 'Could not send', error: true);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

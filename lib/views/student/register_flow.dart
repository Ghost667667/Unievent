import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../navigation/app_router.dart';
import '../../repositories/registration_repository.dart';
import '../../services/app_services.dart';
import '../../theme/app_colors.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/common_widgets.dart';

/// One-tap registration used from event cards and the details page.
/// Auto-fills the saved student profile, checks capacity in a transaction,
/// shows a confirmation sheet with the ticket shortcut, or joins the waitlist.
Future<Registration?> registerForEvent(BuildContext context, Event event) async {
  final services = context.read<AppServices>();
  final student = context.read<AuthViewModel>().user!;
  final willWaitlist = event.isFull;

  final proceed = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => _ConfirmSheet(event: event, student: student, waitlist: willWaitlist),
  );
  if (proceed != true || !context.mounted) return null;

  try {
    final reg = await services.registrations.register(event: event, student: student);
    await services.notifications.notifyUsers(
      [student.uid],
      title: reg.status == RegistrationStatus.waitlisted
          ? 'You are on the waitlist'
          : 'Registration confirmed',
      body: reg.status == RegistrationStatus.waitlisted
          ? 'We will notify you the moment a seat opens for ${event.title}.'
          : 'Your QR ticket for ${event.title} is ready in My Events.',
      eventId: event.id,
      type: 'registration',
    );
    if (!context.mounted) return reg;
    await showDialog<void>(
      context: context,
      builder: (ctx) => _SuccessDialog(registration: reg, event: event),
    );
    return reg;
  } on RegistrationException catch (e) {
    if (context.mounted) showAppSnackBar(context, e.message, error: true);
  } catch (e) {
    if (context.mounted) {
      showAppSnackBar(context, 'Could not register. Please try again.', error: true);
    }
  }
  return null;
}

class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({
    required this.event,
    required this.student,
    required this.waitlist,
  });

  final Event event;
  final AppUser student;
  final bool waitlist;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 110,
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ),
              Expanded(
                child: Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              waitlist ? 'Join the waitlist' : 'Confirm registration',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              waitlist
                  ? 'This event is fully booked. You will be registered automatically when a seat opens.'
                  : 'Your saved details will be used — no form to fill in.',
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            AppCard(
              color: AppColors.cloud,
              child: Column(
                children: [
                  row('Event', event.title),
                  row('When', Fmt.dateTime(event.startTime)),
                  row('Where', event.venue),
                  const Divider(height: 18),
                  row('Name', student.fullName),
                  row('TP Number', student.studentId ?? '—'),
                  row('Programme', student.programme ?? '—'),
                  row('Email', student.email),
                  if (!event.isFree) ...[
                    const Divider(height: 18),
                    row('Fee', '${Fmt.rm(event.price)} (pay at the door)'),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: waitlist
                  ? ElevatedButton.styleFrom(backgroundColor: AppColors.orange)
                  : null,
              child: Text(waitlist ? 'Join Waitlist' : 'Register Now'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessDialog extends StatelessWidget {
  const _SuccessDialog({required this.registration, required this.event});
  final Registration registration;
  final Event event;

  @override
  Widget build(BuildContext context) {
    final waitlisted = registration.status == RegistrationStatus.waitlisted;
    final theme = Theme.of(context);
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (waitlisted ? AppColors.orange : AppColors.green).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              waitlisted ? Icons.hourglass_top : Icons.check_circle,
              color: waitlisted ? AppColors.orange : AppColors.green,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            waitlisted ? "You're on the waitlist" : "You're registered!",
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            waitlisted
                ? 'Position #${registration.waitlistPosition ?? '-'}. We will move you in automatically and notify you when a seat frees up.'
                : 'Your unique QR ticket for ${event.title} is ready.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
        if (!waitlisted)
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              context.push(Routes.ticket(registration.id));
            },
            icon: const Icon(Icons.qr_code_2, size: 18),
            label: const Text('View ticket'),
          ),
      ],
    );
  }
}

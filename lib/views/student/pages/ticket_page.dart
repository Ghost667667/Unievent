import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/formatters.dart';
import '../../../core/ticket_codec.dart';
import '../../../models/models.dart';
import '../../../navigation/app_router.dart';
import '../../../services/app_services.dart';
import '../../../theme/app_colors.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../viewmodels/student/student_viewmodels.dart';
import '../../../widgets/common_widgets.dart';

class TicketPage extends StatelessWidget {
  const TicketPage({super.key, required this.registrationId});
  final String registrationId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => TicketViewModel(ctx.read<AppServices>(), registrationId),
      child: const _TicketBody(),
    );
  }
}

class _TicketBody extends StatelessWidget {
  const _TicketBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TicketViewModel>();
    final user = context.watch<AuthViewModel>().user!;
    final reg = vm.registration;
    final event = vm.event;
    final theme = Theme.of(context);

    if (!vm.loaded) return const Scaffold(body: LoadingView());
    if (reg == null) {
      return Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.error_outline, title: 'Ticket not found'));
    }

    final payload = TicketCodec.encode(eventId: reg.eventId, registrationId: reg.id, code: reg.ticketCode);
    final ticketNo = TicketCodec.shortNumber(reg.ticketCode);
    final waitlisted = reg.status == RegistrationStatus.waitlisted;
    final cancelled = reg.status == RegistrationStatus.cancelled;
    final attended = reg.status == RegistrationStatus.attended;
    final statusColor = switch (reg.status) {
      RegistrationStatus.registered => AppColors.green,
      RegistrationStatus.waitlisted => AppColors.orange,
      RegistrationStatus.attended => AppColors.indigo,
      RegistrationStatus.cancelled => AppColors.red,
    };
    final needsConfirmation =
        reg.status == RegistrationStatus.registered && !reg.confirmed && reg.confirmationRequestedAt != null;

    return Scaffold(
      backgroundColor: AppColors.midnight,
      appBar: AppBar(
        backgroundColor: AppColors.midnight,
        foregroundColor: AppColors.white,
        title: const Text('My Ticket'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          children: [
            if (needsConfirmation) ...[
              _SeatRescueBanner(vm: vm),
              const SizedBox(height: 14),
            ],
            if (event?.status == EventStatus.cancelled) ...[
              const _InfoBanner(
                color: AppColors.red,
                icon: Icons.cancel_outlined,
                text: 'The organiser cancelled this event. Check Updates for details.',
              ),
              const SizedBox(height: 14),
            ],
            // ── Ticket card ──
            ClipPath(
              clipper: _TicketClipper(notchY: 318),
              child: Container(
                color: AppColors.white,
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(gradient: AppColors.headerGradient),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('UNIEVENT TICKET', style: theme.textTheme.labelSmall?.copyWith(color: AppColors.white.withValues(alpha: 0.8), letterSpacing: 1.5)),
                              const Spacer(),
                              StatusChip(label: reg.status.label, color: AppColors.white),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(reg.eventTitle, style: theme.textTheme.headlineSmall?.copyWith(color: AppColors.white, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: _Field('Name', reg.studentName)),
                              Expanded(child: _Field('TP Number', reg.studentTp.isEmpty ? '—' : reg.studentTp)),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(child: _Field('Date', reg.eventStartTime == null ? '—' : Fmt.date(reg.eventStartTime!))),
                              Expanded(child: _Field('Time', reg.eventStartTime == null ? '—' : Fmt.time(reg.eventStartTime!))),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _Field('Venue', event?.venue ?? reg.venue ?? '—'),
                        ],
                      ),
                    ),
                    // perforation
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: List.generate(
                          30,
                          (i) => Expanded(
                            child: Container(
                              height: 1.5,
                              color: i.isEven ? AppColors.divider : Colors.transparent,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                      child: Column(
                        children: [
                          if (waitlisted)
                            _WaitlistPlaceholder(position: reg.waitlistPosition)
                          else
                            Opacity(
                              opacity: cancelled ? 0.25 : 1,
                              child: Semantics(
                                label: 'QR ticket $ticketNo',
                                child: QrImageView(
                                  data: payload,
                                  size: 210,
                                  backgroundColor: AppColors.white,
                                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.midnight),
                                  dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: AppColors.midnight),
                                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                                ),
                              ),
                            ),
                          const SizedBox(height: 10),
                          Text(ticketNo, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 2)),
                          Text(
                            attended
                                ? 'Checked in ${reg.checkedInAt == null ? '' : Fmt.dateTime(reg.checkedInAt!)}'
                                : cancelled
                                    ? 'This ticket is no longer valid'
                                    : waitlisted
                                        ? 'Your QR appears once you are registered'
                                        : reg.confirmed
                                            ? 'Attendance confirmed ✓'
                                            : 'Show this code at check-in',
                            style: theme.textTheme.bodySmall?.copyWith(color: statusColor, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Actions ──
            if (!cancelled && !waitlisted && !attended) ...[
              Row(
                children: [
                  Expanded(
                    child: _ActionTile(
                      icon: Icons.calendar_month_outlined,
                      label: 'Add to Google Calendar',
                      onTap: () => vm.addToCalendar(ticketNo),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionTile(
                      icon: Icons.map_outlined,
                      label: 'Open Google Maps',
                      onTap: vm.openMaps,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (!reg.confirmed)
                BusyButton(
                  label: 'Confirm Attendance',
                  icon: Icons.event_available,
                  busy: vm.busy,
                  color: AppColors.green,
                  onPressed: () async {
                    final ok = await vm.confirmAttendance();
                    if (context.mounted) {
                      showAppSnackBar(context, ok ? 'Thanks! Your seat is confirmed.' : (vm.error ?? 'Could not confirm.'), success: ok, error: !ok);
                    }
                  },
                ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: vm.busy
                    ? null
                    : () async {
                        final ok = await confirmDialog(
                          context,
                          title: 'Cancel registration?',
                          message: 'Your seat will be released to the next student on the waitlist.',
                          confirmLabel: 'Cancel registration',
                          destructive: true,
                        );
                        if (!ok) return;
                        await vm.cancel();
                        if (context.mounted) {
                          if (vm.error != null) {
                            showAppSnackBar(context, vm.error!, error: true);
                          } else {
                            showAppSnackBar(context, 'Registration cancelled.', success: true);
                            context.go(Routes.studentMyEvents);
                          }
                        }
                      },
                icon: const Icon(Icons.close, color: Color(0xFFFCA5A5)),
                label: const Text('Cancel Registration', style: TextStyle(color: Color(0xFFFCA5A5))),
              ),
            ],
            if (waitlisted)
              TextButton.icon(
                onPressed: vm.busy
                    ? null
                    : () async {
                        final ok = await confirmDialog(context, title: 'Leave waitlist?', message: 'You will lose your place in the queue.', confirmLabel: 'Leave', destructive: true);
                        if (!ok) return;
                        await vm.cancel();
                        if (context.mounted) context.go(Routes.studentMyEvents);
                      },
                icon: const Icon(Icons.close, color: Color(0xFFFCA5A5)),
                label: const Text('Leave Waitlist', style: TextStyle(color: Color(0xFFFCA5A5))),
              ),
            if (attended)
              ElevatedButton.icon(
                onPressed: () => context.push(Routes.feedback(reg.eventId)),
                icon: const Icon(Icons.star_outline),
                label: const Text('Rate this event'),
              ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.push(Routes.eventDetails(reg.eventId)),
              child: const Text('View event details & updates', style: TextStyle(color: AppColors.white)),
            ),
            if (user.uid != reg.studentId)
              Text('Viewing as ${user.fullName}', style: theme.textTheme.labelSmall?.copyWith(color: AppColors.white)),
          ],
        ),
      ),
    );
  }
}

class _SeatRescueBanner extends StatelessWidget {
  const _SeatRescueBanner({required this.vm});
  final TicketViewModel vm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.orange, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_seat, color: AppColors.white),
              const SizedBox(width: 8),
              Text('Still coming?', style: theme.textTheme.titleMedium?.copyWith(color: AppColors.white, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Please confirm your attendance. Unconfirmed seats are released to the waitlist a few hours before the event.',
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.white),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: vm.busy
                ? null
                : () async {
                    final ok = await vm.confirmAttendance();
                    if (context.mounted) showAppSnackBar(context, ok ? 'Seat confirmed. See you there!' : (vm.error ?? 'Try again.'), success: ok, error: !ok);
                  },
            style: FilledButton.styleFrom(backgroundColor: AppColors.white, foregroundColor: AppColors.orange),
            child: const Text("Yes, I'm coming"),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.color, required this.icon, required this.text});
  final Color color;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(icon, color: AppColors.white),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class _WaitlistPlaceholder extends StatelessWidget {
  const _WaitlistPlaceholder({required this.position});
  final int? position;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 210,
      height: 210,
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.4), width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.hourglass_top, size: 48, color: AppColors.orange),
          const SizedBox(height: 10),
          Text('Waitlist', style: theme.textTheme.titleMedium?.copyWith(color: AppColors.orange, fontWeight: FontWeight.w700)),
          Text('Position #${position ?? '-'}', style: theme.textTheme.headlineMedium?.copyWith(color: AppColors.orange, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textSecondary, letterSpacing: 1)),
        const SizedBox(height: 2),
        Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Column(
            children: [
              Icon(icon, color: AppColors.white),
              const SizedBox(height: 6),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rounded ticket with semicircular notches at the perforation line.
class _TicketClipper extends CustomClipper<Path> {
  _TicketClipper({required this.notchY});
  final double notchY;

  @override
  Path getClip(Size size) {
    const r = 22.0;
    const notch = 12.0;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(r)));
    final y = notchY.clamp(0.0, size.height);
    final notches = Path()
      ..addOval(Rect.fromCircle(center: Offset(0, y), radius: notch))
      ..addOval(Rect.fromCircle(center: Offset(size.width, y), radius: notch));
    return Path.combine(PathOperation.difference, path, notches);
  }

  @override
  bool shouldReclip(covariant _TicketClipper old) => old.notchY != notchY;
}

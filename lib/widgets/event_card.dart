import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'common_widgets.dart';

/// Poster image with gradient fallback (used by cards and detail pages).
class EventPoster extends StatelessWidget {
  const EventPoster({
    super.key,
    required this.event,
    this.height = 150,
    this.borderRadius,
  });

  final Event event;
  final double height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.categoryColor(event.category),
            AppColors.categoryColor(event.category).withValues(alpha: 0.6),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.event,
          color: AppColors.white.withValues(alpha: 0.7),
          size: height * 0.3,
        ),
      ),
    );
    final child = (event.posterUrl == null || event.posterUrl!.isEmpty)
        ? fallback
        : CachedNetworkImage(
            imageUrl: event.posterUrl!,
            height: height,
            width: double.infinity,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              height: height,
              color: AppColors.surfaceTint,
              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            errorWidget: (_, __, ___) => fallback,
          );
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: SizedBox(height: height, width: double.infinity, child: child),
    );
  }
}

/// Event card used on Home / Explore. Shows poster, name, category, date,
/// venue, seats, free/paid and a Register / Join Waitlist / status button.
class EventCard extends StatelessWidget {
  const EventCard({
    super.key,
    required this.event,
    required this.onTap,
    this.onRegister,
    this.registration,
    this.saved = false,
    this.onToggleSave,
    this.compact = false,
  });

  final Event event;
  final VoidCallback onTap;
  final VoidCallback? onRegister;
  final Registration? registration;
  final bool saved;
  final VoidCallback? onToggleSave;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final catColor = AppColors.categoryColor(event.category);

    return AppCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              EventPoster(
                event: event,
                height: compact ? 110 : 150,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppTheme.cardRadius),
                ),
              ),
              Positioned(
                left: 12,
                top: 12,
                child: Row(
                  children: [
                    _Pill(label: event.category, color: catColor),
                    const SizedBox(width: 6),
                    _Pill(
                      label: event.isFree ? 'Free' : Fmt.rm(event.price),
                      color: event.isFree ? AppColors.green : AppColors.midnight,
                    ),
                  ],
                ),
              ),
              if (onToggleSave != null)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Material(
                    color: AppColors.white.withValues(alpha: 0.9),
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: saved ? 'Unsave' : 'Save event',
                      visualDensity: VisualDensity.compact,
                      onPressed: onToggleSave,
                      icon: Icon(
                        saved ? Icons.bookmark : Icons.bookmark_border,
                        color: AppColors.indigo,
                        size: 20,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                _InfoRow(
                  icon: Icons.calendar_today_outlined,
                  text: '${Fmt.date(event.startTime)} • ${Fmt.time(event.startTime)}',
                ),
                const SizedBox(height: 4),
                _InfoRow(icon: Icons.place_outlined, text: event.venue),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: SeatIndicator(event: event)),
                    const SizedBox(width: 10),
                    _ActionButton(
                      event: event,
                      registration: registration,
                      onRegister: onRegister,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "12 of 80 left" with a progress bar; turns orange when nearly full.
class SeatIndicator extends StatelessWidget {
  const SeatIndicator({super.key, required this.event, this.dense = true});
  final Event event;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = event.capacity == 0
        ? 1.0
        : (event.registeredCount / event.capacity).clamp(0.0, 1.0);
    final left = event.seatsLeft;
    final color = event.isFull
        ? AppColors.red
        : ratio >= 0.8
            ? AppColors.orange
            : AppColors.green;
    final label = event.isFull
        ? 'Fully booked${event.waitlistCount > 0 ? ' • ${event.waitlistCount} waiting' : ''}'
        : '$left of ${event.capacity} seats left';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: (dense ? theme.textTheme.labelSmall : theme.textTheme.bodySmall)
              ?.copyWith(color: color, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 5,
            backgroundColor: AppColors.divider,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.event,
    required this.registration,
    required this.onRegister,
  });

  final Event event;
  final Registration? registration;
  final VoidCallback? onRegister;

  @override
  Widget build(BuildContext context) {
    final reg = registration;
    if (reg != null && reg.isActive) {
      final waitlisted = reg.status == RegistrationStatus.waitlisted;
      return StatusChip(
        label: waitlisted ? 'Waitlisted' : 'Registered',
        color: waitlisted ? AppColors.orange : AppColors.green,
        icon: waitlisted ? Icons.hourglass_top : Icons.check_circle,
      );
    }
    if (!event.registrationOpen) {
      return const StatusChip(label: 'Closed', color: AppColors.textSecondary);
    }
    final full = event.isFull;
    return FilledButton(
      onPressed: onRegister,
      style: FilledButton.styleFrom(
        backgroundColor: full ? AppColors.orange : AppColors.indigo,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        minimumSize: Size.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      child: Text(full ? 'Join Waitlist' : 'Register'),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ),
      ],
    );
  }
}

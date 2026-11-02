import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../navigation/app_router.dart';
import '../../services/app_services.dart';
import '../../theme/app_colors.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/common_widgets.dart';

/// In-app inbox shared by all roles.
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();
    final user = context.watch<AuthViewModel>().user!;
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: StreamBuilder<List<AppNotification>>(
        stream: services.users.watchNotifications(user.uid),
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(message: snap.error.toString());
          if (!snap.hasData) return const LoadingView();
          final items = snap.data!;
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none,
              title: 'No notifications yet',
              message: 'Event updates, reminders and order status changes will appear here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final n = items[i];
              return AppCard(
                color: n.read ? AppColors.white : AppColors.surfaceTint,
                onTap: () {
                  services.users.markNotificationRead(user.uid, n.id);
                  if (n.eventId != null) {
                    switch (user.role) {
                      case UserRole.student:
                        context.push(Routes.eventDetails(n.eventId!));
                      case UserRole.organiser:
                      case UserRole.studentAffairs:
                        context.push(Routes.eventManage(n.eventId!));
                      case UserRole.vendor:
                        context.push(Routes.vendorEventDetails(n.eventId!));
                    }
                  }
                },
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _color(n.type).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(_icon(n.type), color: _color(n.type), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            n.title,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: n.read ? FontWeight.w500 : FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(n.body, style: Theme.of(context).textTheme.bodySmall),
                          if (n.createdAt != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              Fmt.dateTime(n.createdAt!),
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                            ),
                          ],
                        ],
                      ),
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

  IconData _icon(String type) {
    switch (type) {
      case 'announcement':
        return Icons.campaign_outlined;
      case 'seat_rescue':
        return Icons.event_seat_outlined;
      case 'waitlist':
        return Icons.celebration_outlined;
      case 'order':
        return Icons.shopping_bag_outlined;
      case 'vendor':
        return Icons.storefront_outlined;
      case 'proposal':
        return Icons.assignment_turned_in_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _color(String type) {
    switch (type) {
      case 'seat_rescue':
        return AppColors.orange;
      case 'waitlist':
        return AppColors.green;
      case 'order':
        return AppColors.electricBlue;
      default:
        return AppColors.indigo;
    }
  }
}

/// Bell icon with unread badge for headers.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key, this.color = AppColors.white});
  final Color color;

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();
    final uid = context.watch<AuthViewModel>().user?.uid;
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<int>(
      stream: services.users.watchUnreadCount(uid),
      builder: (context, snap) {
        final count = snap.data ?? 0;
        return IconButton(
          tooltip: 'Notifications',
          onPressed: () => context.push(Routes.notifications),
          icon: Badge(
            isLabelVisible: count > 0,
            label: Text('$count'),
            backgroundColor: AppColors.orange,
            child: Icon(Icons.notifications_outlined, color: color),
          ),
        );
      },
    );
  }
}

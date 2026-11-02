import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../services/app_services.dart';
import '../../../theme/app_colors.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../viewmodels/student/student_viewmodels.dart';
import '../../../widgets/common_widgets.dart';

class FeedbackPage extends StatelessWidget {
  const FeedbackPage({super.key, required this.eventId});
  final String eventId;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthViewModel>().user!;
    return ChangeNotifierProvider(
      create: (ctx) => FeedbackViewModel(ctx.read<AppServices>(), user, eventId),
      child: const _FeedbackBody(),
    );
  }
}

class _FeedbackBody extends StatefulWidget {
  const _FeedbackBody();

  @override
  State<_FeedbackBody> createState() => _FeedbackBodyState();
}

class _FeedbackBodyState extends State<_FeedbackBody> {
  final _comment = TextEditingController();
  bool _seeded = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FeedbackViewModel>();
    final theme = Theme.of(context);
    if (!_seeded && vm.existing != null) {
      _comment.text = vm.existing!.comment;
      _seeded = true;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Event Feedback')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(vm.event?.title ?? '…', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              vm.existing != null ? 'Thanks! You can update your feedback below.' : 'How was it? Your feedback goes straight to the organiser.',
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            AppCard(
              child: Column(
                children: [
                  Text('Rate the event', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  StarRating(value: vm.eventRating, onChanged: vm.setEventRating, size: 40),
                  const SizedBox(height: 4),
                  Text(_label(vm.eventRating), style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Written review (optional)', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _comment,
                    maxLines: 4,
                    maxLength: 500,
                    onChanged: (v) => vm.comment = v,
                    decoration: const InputDecoration(hintText: 'What went well? What could be better?'),
                  ),
                ],
              ),
            ),
            if (vm.vendors.isNotEmpty) ...[
              const SizedBox(height: 14),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Rate the vendors you ordered from', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    ...vm.vendors.entries.map(
                      (v) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(child: Text(v.value, style: theme.textTheme.bodyMedium)),
                            StarRating(
                              value: vm.vendorRatings[v.key] ?? 0,
                              onChanged: (r) => vm.setVendorRating(v.key, r),
                              size: 24,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (vm.error != null) ...[
              Text(vm.error!, style: const TextStyle(color: AppColors.red)),
              const SizedBox(height: 8),
            ],
            BusyButton(
              label: vm.existing != null ? 'Update feedback' : 'Submit feedback',
              icon: Icons.send,
              busy: vm.busy,
              onPressed: () async {
                final ok = await vm.submit();
                if (!context.mounted) return;
                if (ok) {
                  showAppSnackBar(context, 'Thank you for your feedback!', success: true);
                  context.pop();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  String _label(int r) => switch (r) {
        0 => 'Tap a star',
        1 => 'Poor',
        2 => 'Fair',
        3 => 'Good',
        4 => 'Great',
        _ => 'Excellent!',
      };
}

/// Interactive 5-star rating.
class StarRating extends StatelessWidget {
  const StarRating({super.key, required this.value, this.onChanged, this.size = 28});
  final int value;
  final ValueChanged<int>? onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < value;
        return IconButton(
          onPressed: onChanged == null ? null : () => onChanged!(i + 1),
          iconSize: size,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(minWidth: size + 8, minHeight: size + 8),
          icon: Icon(filled ? Icons.star_rounded : Icons.star_outline_rounded, color: filled ? AppColors.orange : AppColors.divider),
        );
      }),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/formatters.dart';
import '../../../models/models.dart';
import '../../../services/app_services.dart';
import '../../../theme/app_colors.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../viewmodels/organiser/organiser_viewmodels.dart';
import '../../../widgets/common_widgets.dart';
import '../organiser_shell.dart' show ProposalTile;

/// Simulated Student Affairs approval dashboard. Only accounts with the
/// `student_affairs` role (provisioned by an admin) can act here; organisers
/// see a read-only explanation.
class StudentAffairsPage extends StatelessWidget {
  const StudentAffairsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthViewModel>().user!;
    if (user.role != UserRole.studentAffairs) {
      return Scaffold(
        appBar: AppBar(title: const Text('Student Affairs')),
        body: const EmptyState(
          icon: Icons.verified_user_outlined,
          title: 'Student Affairs accounts only',
          message: 'Proposal approval is reserved for Student Affairs staff. These accounts are created by an administrator (see README → Student Affairs account), not through public sign-up.',
        ),
      );
    }
    return ChangeNotifierProvider(
      create: (ctx) => StudentAffairsViewModel(ctx.read<AppServices>(), user),
      child: const _SABody(),
    );
  }
}

class _SABody extends StatelessWidget {
  const _SABody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<StudentAffairsViewModel>();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Proposal Approvals'),
          bottom: TabBar(tabs: [Tab(text: 'Queue (${vm.queue.length})'), Tab(text: 'Decided (${vm.decided.length})')]),
        ),
        body: vm.loading
            ? const LoadingView()
            : TabBarView(
                children: [
                  _List(items: vm.queue, vm: vm, empty: 'Nothing awaiting review'),
                  _List(items: vm.decided, vm: vm, empty: 'No decisions yet'),
                ],
              ),
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.items, required this.vm, required this.empty});
  final List<Proposal> items;
  final StudentAffairsViewModel vm;
  final String empty;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return EmptyState(icon: Icons.inbox_outlined, title: empty);
    final theme = Theme.of(context);
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final p = items[i];
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(p.eventTitle, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                  StatusChip(label: p.status.label, color: ProposalTile.colorFor(p.status)),
                ],
              ),
              Text('${p.organisationName} • ${p.organiserName}', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.indigo, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(p.description, style: theme.textTheme.bodySmall),
              if (p.objectives.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Objectives: ${p.objectives}', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  StatusChip(label: p.category, color: AppColors.categoryColor(p.category)),
                  StatusChip(label: Fmt.dateTime(p.proposedDate), color: AppColors.textSecondary, icon: Icons.schedule),
                  StatusChip(label: p.venue, color: AppColors.textSecondary, icon: Icons.place_outlined),
                  StatusChip(label: '${p.expectedAttendance} pax', color: AppColors.textSecondary, icon: Icons.people_outline),
                  StatusChip(label: Fmt.rm(p.budgetEstimate), color: AppColors.textSecondary, icon: Icons.account_balance_wallet_outlined),
                  if (p.needsVendors) const StatusChip(label: 'Vendor booths', color: AppColors.orange, icon: Icons.storefront_outlined),
                ],
              ),
              if (p.reviewerComment != null && p.reviewerComment!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('Your comment: ${p.reviewerComment}', style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
              ],
              if (p.status == ProposalStatus.submitted) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: vm.busy ? null : () => _decide(context, p, ProposalStatus.rejected),
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.red, side: const BorderSide(color: AppColors.red), minimumSize: const Size.fromHeight(44)),
                        child: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: vm.busy ? null : () => _decide(context, p, ProposalStatus.needsChanges),
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.orange, side: const BorderSide(color: AppColors.orange), minimumSize: const Size.fromHeight(44)),
                        child: const Text('Needs changes'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: vm.busy ? null : () => _decide(context, p, ProposalStatus.approved),
                        style: FilledButton.styleFrom(backgroundColor: AppColors.green, minimumSize: const Size.fromHeight(44)),
                        child: const Text('Approve'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _decide(BuildContext context, Proposal p, ProposalStatus status) async {
    final comment = TextEditingController(
      text: switch (status) {
        ProposalStatus.approved => 'Approved. Please coordinate venue booking with Facilities.',
        ProposalStatus.needsChanges => 'Please revise the budget breakdown and resubmit.',
        _ => '',
      },
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${status.label}: ${p.eventTitle}'),
        content: TextField(controller: comment, maxLines: 3, decoration: const InputDecoration(labelText: 'Comment to organiser')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final done = await vm.decide(p, status, comment.text.trim());
    if (context.mounted) showAppSnackBar(context, done ? 'Decision sent to the organiser.' : (vm.error ?? 'Failed'), success: done, error: !done);
  }
}

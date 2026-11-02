import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/formatters.dart';
import '../../../core/validators.dart';
import '../../../models/models.dart';
import '../../../navigation/app_router.dart';
import '../../../services/app_services.dart';
import '../../../theme/app_colors.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../widgets/common_widgets.dart';
import '../organiser_shell.dart' show ProposalTile;

/// Create / edit a Student Affairs event proposal. Draft → Submitted.
class ProposalFormPage extends StatefulWidget {
  const ProposalFormPage({super.key, this.proposalId});
  final String? proposalId;

  @override
  State<ProposalFormPage> createState() => _ProposalFormPageState();
}

class _ProposalFormPageState extends State<ProposalFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _objectives = TextEditingController();
  final _venue = TextEditingController();
  final _attendance = TextEditingController();
  final _budget = TextEditingController();
  String _category = kEventCategories.first;
  DateTime _date = DateTime.now().add(const Duration(days: 21));
  bool _needsVendors = false;
  Proposal? _existing;
  bool _loading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.proposalId != null) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final services = context.read<AppServices>();
    final user = context.read<AuthViewModel>().user!;
    final list = await services.proposals.watchByOrganiser(user.uid).first;
    final match = list.where((p) => p.id == widget.proposalId);
    if (match.isNotEmpty) {
      final p = match.first;
      _existing = p;
      _title.text = p.eventTitle;
      _description.text = p.description;
      _objectives.text = p.objectives;
      _venue.text = p.venue;
      _attendance.text = '${p.expectedAttendance}';
      _budget.text = p.budgetEstimate.toStringAsFixed(0);
      _category = p.category;
      _date = p.proposedDate;
      _needsVendors = p.needsVendors;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    for (final c in [_title, _description, _objectives, _venue, _attendance, _budget]) {
      c.dispose();
    }
    super.dispose();
  }

  Proposal _build(AppUser user) => Proposal(
        id: _existing?.id ?? '',
        organiserId: user.uid,
        organiserName: user.fullName,
        organisationName: user.organisationName ?? '',
        eventTitle: _title.text.trim(),
        category: _category,
        description: _description.text.trim(),
        objectives: _objectives.text.trim(),
        proposedDate: _date,
        venue: _venue.text.trim(),
        expectedAttendance: int.parse(_attendance.text.trim()),
        budgetEstimate: double.parse(_budget.text.trim()),
        needsVendors: _needsVendors,
        status: _existing?.status ?? ProposalStatus.draft,
        reviewerComment: _existing?.reviewerComment,
        reviewedBy: _existing?.reviewedBy,
        reviewedAt: _existing?.reviewedAt,
        submittedAt: _existing?.submittedAt,
        createdAt: _existing?.createdAt,
        eventId: _existing?.eventId,
      );

  Future<void> _save({required bool submit}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final services = context.read<AppServices>();
    final user = context.read<AuthViewModel>().user!;
    try {
      var p = _build(user);
      if (submit) p = p.copyWith(status: ProposalStatus.submitted);
      String id;
      if (_existing == null) {
        id = await services.proposals.create(p);
      } else {
        id = p.id;
        await services.proposals.save(p);
      }
      if (submit) await services.proposals.submit(id);
      if (!mounted) return;
      showAppSnackBar(context, submit ? 'Proposal submitted to Student Affairs.' : 'Draft saved.', success: true);
      context.pop();
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Could not save: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final readOnly = _existing != null && !_existing!.canEdit;

    return Scaffold(
      appBar: AppBar(
        title: Text(_existing == null ? 'New Proposal' : 'Proposal'),
        actions: [
          if (_existing != null && _existing!.status == ProposalStatus.draft)
            IconButton(
              tooltip: 'Delete draft',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await confirmDialog(context, title: 'Delete draft?', message: 'This cannot be undone.', confirmLabel: 'Delete', destructive: true);
                if (!ok || !context.mounted) return;
                await context.read<AppServices>().proposals.delete(_existing!.id);
                if (context.mounted) context.pop();
              },
            ),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  if (_existing != null) ...[
                    Row(
                      children: [
                        StatusChip(label: _existing!.status.label, color: ProposalTile.colorFor(_existing!.status)),
                        const SizedBox(width: 8),
                        if (_existing!.submittedAt != null)
                          Text('Submitted ${Fmt.date(_existing!.submittedAt!)}', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                      ],
                    ),
                    if (_existing!.reviewerComment != null && _existing!.reviewerComment!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ProposalTile.colorFor(_existing!.status).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Student Affairs comment', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(_existing!.reviewerComment!),
                          ],
                        ),
                      ),
                    ],
                    if (_existing!.canCreateEvent) ...[
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => context.push(Routes.eventNew(proposalId: _existing!.id)),
                        icon: const Icon(Icons.add_box_outlined),
                        label: const Text('Create the event'),
                      ),
                    ],
                    if (_existing!.eventId != null) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => context.push(Routes.eventManage(_existing!.eventId!)),
                        icon: const Icon(Icons.event_available),
                        label: const Text('Open event'),
                      ),
                    ],
                    const SizedBox(height: 20),
                  ],
                  Text('Event proposal form', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  Text('The same details Student Affairs requires on the paper template.', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _title,
                    readOnly: readOnly,
                    validator: (v) => Validators.required(v, 'Event title'),
                    decoration: const InputDecoration(labelText: 'Event title'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: kEventCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: readOnly ? null : (v) => setState(() => _category = v!),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _description,
                    readOnly: readOnly,
                    maxLines: 4,
                    validator: (v) => Validators.required(v, 'Description'),
                    decoration: const InputDecoration(labelText: 'Description', alignLabelWithHint: true),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _objectives,
                    readOnly: readOnly,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Objectives (optional)', alignLabelWithHint: true),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: readOnly
                        ? null
                        : () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _date,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (d == null || !context.mounted) return;
                            final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_date));
                            setState(() => _date = DateTime(d.year, d.month, d.day, t?.hour ?? 19, t?.minute ?? 0));
                          },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Proposed date & time', suffixIcon: Icon(Icons.calendar_today_outlined)),
                      child: Text(Fmt.dateTime(_date)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _venue,
                    readOnly: readOnly,
                    validator: (v) => Validators.required(v, 'Venue'),
                    decoration: const InputDecoration(labelText: 'Venue'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _attendance,
                          readOnly: readOnly,
                          keyboardType: TextInputType.number,
                          validator: (v) => Validators.positiveInt(v, 'Expected attendance'),
                          decoration: const InputDecoration(labelText: 'Expected attendance'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _budget,
                          readOnly: readOnly,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (v) => Validators.money(v, 'Budget'),
                          decoration: const InputDecoration(labelText: 'Budget estimate (RM)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Event will have vendor booths'),
                    subtitle: const Text('APU policy: student-run booths only'),
                    value: _needsVendors,
                    onChanged: readOnly ? null : (v) => setState(() => _needsVendors = v),
                  ),
                  const SizedBox(height: 16),
                  if (!readOnly) ...[
                    Row(
                      children: [
                        Expanded(
                          child: BusyButton(label: 'Save draft', outlined: true, busy: _saving, onPressed: () => _save(submit: false)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: BusyButton(label: 'Submit', icon: Icons.send, busy: _saving, onPressed: () => _save(submit: true)),
                        ),
                      ],
                    ),
                  ] else
                    Text(
                      _existing!.status == ProposalStatus.submitted
                          ? 'Waiting for Student Affairs review. You will be notified when the status changes.'
                          : 'This proposal is locked.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),
    );
  }
}

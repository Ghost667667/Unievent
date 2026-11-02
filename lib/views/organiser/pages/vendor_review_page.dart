import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/formatters.dart';
import '../../../models/models.dart';
import '../../../services/app_services.dart';
import '../../../theme/app_colors.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../viewmodels/organiser/organiser_viewmodels.dart';
import '../../../widgets/common_widgets.dart';
import '../tabs/organiser_vendors_tab.dart' show VendorApplicationTile;

/// Review one vendor application: details, menu, approve with booth &
/// logistics, or reject with a note. Approved vendors can be re-assigned.
class VendorReviewPage extends StatelessWidget {
  const VendorReviewPage({super.key, required this.applicationId});
  final String applicationId;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthViewModel>().user!;
    return ChangeNotifierProvider(
      create: (ctx) => VendorManagementViewModel(ctx.read<AppServices>(), user),
      child: _ReviewBody(applicationId: applicationId),
    );
  }
}

class _ReviewBody extends StatefulWidget {
  const _ReviewBody({required this.applicationId});
  final String applicationId;

  @override
  State<_ReviewBody> createState() => _ReviewBodyState();
}

class _ReviewBodyState extends State<_ReviewBody> {
  final _booth = TextEditingController();
  final _arrival = TextEditingController();
  final _parking = TextEditingController(text: 'Visitor car park B, show your approval notification at the gate.');
  final _setup = TextEditingController(text: 'Set up 60 minutes before doors open. Tables and chairs are provided; bring your own extension cords.');
  final _note = TextEditingController();
  bool _seeded = false;

  @override
  void dispose() {
    for (final c in [_booth, _arrival, _parking, _setup, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<VendorManagementViewModel>();
    final services = context.read<AppServices>();
    final theme = Theme.of(context);
    final match = vm.all.where((a) => a.id == widget.applicationId);
    if (vm.loading) return const Scaffold(body: LoadingView());
    if (match.isEmpty) return Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.error_outline, title: 'Application not found'));
    final app = match.first;
    if (!_seeded) {
      _booth.text = app.boothNumber ?? '';
      _arrival.text = app.arrivalTime ?? '';
      if (app.parkingDetails != null) _parking.text = app.parkingDetails!;
      if (app.setupInstructions != null) _setup.text = app.setupInstructions!;
      _note.text = app.organiserNote ?? '';
      _seeded = true;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Vendor Application')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          VendorApplicationTile(app: app),
          const SizedBox(height: 14),
          FutureBuilder<AppUser?>(
            future: services.users.get(app.vendorId),
            builder: (context, snap) {
              final v = snap.data;
              return AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Vendor details', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    _kv('Business', v?.businessName ?? app.vendorName),
                    _kv('Contact person', v?.fullName ?? '—'),
                    _kv('Phone', v?.contactNumber ?? '—'),
                    _kv('Email', v?.email ?? '—'),
                    _kv('Category', app.productCategory),
                    _kv('Student vendor', app.isStudentVendor ? 'Yes' : 'No — check APU policy'),
                    _kv('Eligibility', v?.eligibilityNotes ?? '—'),
                    if (app.message.isNotEmpty) ...[
                      const Divider(height: 18),
                      Text('Message from vendor', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(app.message),
                    ],
                    if (app.createdAt != null) ...[
                      const SizedBox(height: 8),
                      Text('Applied ${Fmt.dateTime(app.createdAt!)}', style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textSecondary)),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          StreamBuilder<List<Product>>(
            stream: services.products.watchByVendor(app.vendorId),
            builder: (context, snap) {
              final products = snap.data ?? const [];
              return AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Menu / products (${products.length})', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    if (products.isEmpty)
                      const Text('No products listed yet.', style: TextStyle(color: AppColors.textSecondary))
                    else
                      ...products.map(
                        (p) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Expanded(child: Text('${p.name} • ${p.category}', style: theme.textTheme.bodySmall)),
                              Text(Fmt.rm(p.price), style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Booth & logistics', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                Text('Shared with the vendor on approval.', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _booth, decoration: const InputDecoration(labelText: 'Booth number', hintText: 'B-04'))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: _arrival, decoration: const InputDecoration(labelText: 'Arrival time', hintText: '5:30 PM'))),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(controller: _parking, maxLines: 2, decoration: const InputDecoration(labelText: 'Parking details')),
                const SizedBox(height: 12),
                TextField(controller: _setup, maxLines: 3, decoration: const InputDecoration(labelText: 'Setup instructions')),
                const SizedBox(height: 12),
                TextField(controller: _note, maxLines: 2, decoration: const InputDecoration(labelText: 'Note to vendor (optional)')),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (vm.error != null) ...[Text(vm.error!, style: const TextStyle(color: AppColors.red)), const SizedBox(height: 8)],
          Row(
            children: [
              if (app.status != ApplicationStatus.rejected)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: vm.busy ? null : () => _decide(context, vm, app, ApplicationStatus.rejected),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.red, side: const BorderSide(color: AppColors.red)),
                    icon: const Icon(Icons.close),
                    label: const Text('Reject'),
                  ),
                ),
              if (app.status != ApplicationStatus.rejected) const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: BusyButton(
                  label: app.status == ApplicationStatus.approved ? 'Update booth & logistics' : 'Approve',
                  icon: Icons.check,
                  busy: vm.busy,
                  color: AppColors.green,
                  onPressed: () => _decide(context, vm, app, ApplicationStatus.approved),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 120, child: Text(k, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
            Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          ],
        ),
      );

  Future<void> _decide(BuildContext context, VendorManagementViewModel vm, VendorApplication app, ApplicationStatus status) async {
    if (status == ApplicationStatus.approved && _booth.text.trim().isEmpty) {
      showAppSnackBar(context, 'Assign a booth number before approving.', error: true);
      return;
    }
    final ok = await vm.review(
      app,
      status: status,
      booth: _booth.text.trim().isEmpty ? null : _booth.text.trim(),
      arrival: _arrival.text.trim().isEmpty ? null : _arrival.text.trim(),
      parking: _parking.text.trim(),
      setup: _setup.text.trim(),
      note: _note.text.trim(),
    );
    if (!context.mounted) return;
    if (ok) {
      showAppSnackBar(context, status == ApplicationStatus.approved ? 'Vendor approved and notified.' : 'Application rejected.', success: true);
      context.pop();
    }
  }
}

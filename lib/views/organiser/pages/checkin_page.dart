import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../../core/formatters.dart';
import '../../../core/validators.dart';
import '../../../models/models.dart';
import '../../../repositories/registration_repository.dart';
import '../../../services/app_services.dart';
import '../../../theme/app_colors.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../viewmodels/organiser/organiser_viewmodels.dart';
import '../../../widgets/common_widgets.dart';

/// QR Check-in: camera scanner, result overlay, duplicate / invalid warnings,
/// manual search, walk-ins, offline queue and sync status.
class CheckinPage extends StatelessWidget {
  const CheckinPage({super.key, required this.eventId});
  final String eventId;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthViewModel>().user!;
    return ChangeNotifierProvider(
      create: (ctx) => CheckInViewModel(ctx.read<AppServices>(), user, eventId),
      child: const _CheckinBody(),
    );
  }
}

class _CheckinBody extends StatefulWidget {
  const _CheckinBody();

  @override
  State<_CheckinBody> createState() => _CheckinBodyState();
}

class _CheckinBodyState extends State<_CheckinBody> {
  final MobileScannerController _scanner = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  bool _torch = false;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CheckInViewModel>();
    final theme = Theme.of(context);
    final e = vm.event;

    return Scaffold(
      backgroundColor: AppColors.midnight,
      appBar: AppBar(
        backgroundColor: AppColors.midnight,
        foregroundColor: AppColors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('QR Check-in'),
            if (e != null) Text(e.title, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.white.withValues(alpha: 0.8)), overflow: TextOverflow.ellipsis),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Torch',
            icon: Icon(_torch ? Icons.flash_on : Icons.flash_off),
            onPressed: () {
              _scanner.toggleTorch();
              setState(() => _torch = !_torch);
            },
          ),
          IconButton(tooltip: 'Switch camera', icon: const Icon(Icons.cameraswitch_outlined), onPressed: _scanner.switchCamera),
        ],
      ),
      body: Column(
        children: [
          _SyncBanner(vm: vm),
          Expanded(
            flex: 5,
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _scanner,
                  onDetect: (capture) {
                    for (final b in capture.barcodes) {
                      final raw = b.rawValue;
                      if (raw != null) vm.handleScan(raw);
                    }
                  },
                  errorBuilder: (context, error, child) => Container(
                    color: AppColors.midnight,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Camera unavailable (${error.errorCode.name}).\nUse manual search below.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.white),
                        ),
                      ),
                    ),
                  ),
                ),
                // Viewfinder
                Center(
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.white.withValues(alpha: 0.9), width: 3),
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(color: AppColors.midnight.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(999)),
                      child: Text('${vm.attendedCount} / ${vm.registeredCount} checked in', style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
                if (vm.lastFeedback != null)
                  Positioned(left: 16, right: 16, bottom: 16, child: _ResultOverlay(feedback: vm.lastFeedback!, onDismiss: vm.clearLast)),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Container(
              decoration: const BoxDecoration(color: AppColors.cloud, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    const TabBar(tabs: [Tab(text: 'Manual search'), Tab(text: 'Recent scans')]),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _ManualSearch(vm: vm),
                          _History(vm: vm),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncBanner extends StatelessWidget {
  const _SyncBanner({required this.vm});
  final CheckInViewModel vm;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String text;
    final IconData icon;
    if (!vm.online) {
      color = AppColors.orange;
      icon = Icons.cloud_off;
      text = 'Offline — scans are saved on this phone (${vm.queuedCount} queued) and sync when you reconnect.';
    } else if (vm.syncing) {
      color = AppColors.electricBlue;
      icon = Icons.sync;
      text = 'Syncing ${vm.queuedCount} offline scan(s)…';
    } else if (vm.queuedCount > 0) {
      color = AppColors.orange;
      icon = Icons.cloud_upload_outlined;
      text = '${vm.queuedCount} scan(s) waiting to sync.';
    } else {
      color = AppColors.green;
      icon = Icons.cloud_done_outlined;
      text = 'Online • all scans synced';
    }
    return Material(
      color: color,
      child: InkWell(
        onTap: vm.online && vm.queuedCount > 0 && !vm.syncing ? vm.syncOfflineQueue : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(icon, color: AppColors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(text, style: const TextStyle(color: AppColors.white, fontSize: 12, fontWeight: FontWeight.w600))),
              if (vm.online && vm.queuedCount > 0 && !vm.syncing) const Text('Sync now', style: TextStyle(color: AppColors.white, fontSize: 12, decoration: TextDecoration.underline)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultOverlay extends StatelessWidget {
  const _ResultOverlay({required this.feedback, required this.onDismiss});
  final ScanFeedback feedback;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (feedback.result) {
      CheckInResult.success => (AppColors.green, Icons.check_circle),
      CheckInResult.duplicate => (AppColors.orange, Icons.warning_amber_rounded),
      CheckInResult.invalid || CheckInResult.wrongEvent || CheckInResult.notRegistered => (AppColors.red, Icons.cancel),
    };
    final reg = feedback.registration;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 16)]),
      child: Row(
        children: [
          Icon(icon, color: AppColors.white, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${feedback.message}${feedback.offline ? ' • offline' : ''}',
                  style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w800, fontSize: 15),
                ),
                if (reg != null)
                  Text(
                    '${reg.studentName}${reg.studentTp.isNotEmpty ? ' • ${reg.studentTp}' : ''}',
                    style: const TextStyle(color: AppColors.white, fontSize: 13),
                  ),
                if (feedback.result == CheckInResult.duplicate && reg?.checkedInAt != null)
                  Text('First scanned ${Fmt.time(reg!.checkedInAt!)}', style: const TextStyle(color: AppColors.white, fontSize: 12)),
              ],
            ),
          ),
          IconButton(onPressed: onDismiss, icon: const Icon(Icons.close, color: AppColors.white)),
        ],
      ),
    );
  }
}

class _ManualSearch extends StatefulWidget {
  const _ManualSearch({required this.vm});
  final CheckInViewModel vm;

  @override
  State<_ManualSearch> createState() => _ManualSearchState();
}

class _ManualSearchState extends State<_ManualSearch> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final results = vm.search(_query.text);
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _query,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(hintText: 'Name or TP number', prefixIcon: Icon(Icons.search), isDense: true),
                ),
              ),
              if (vm.event?.allowWalkIns ?? false) ...[
                const SizedBox(width: 8),
                FilledButton.tonalIcon(onPressed: () => _walkIn(context), icon: const Icon(Icons.person_add_alt, size: 18), label: const Text('Walk-in')),
              ],
            ],
          ),
        ),
        Expanded(
          child: results.isEmpty
              ? Center(
                  child: Text(
                    _query.text.isEmpty ? 'Type to find a student when their QR will not scan.' : 'No matching registrations.',
                    style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: results.length,
                  itemBuilder: (context, i) {
                    final r = results[i];
                    final attended = r.status == RegistrationStatus.attended;
                    return ListTile(
                      dense: true,
                      leading: UserAvatar(name: r.studentName, radius: 16),
                      title: Text(r.studentName),
                      subtitle: Text('${r.studentTp} • ${r.status.label}'),
                      trailing: attended
                          ? const StatusChip(label: 'Checked in', color: AppColors.green, icon: Icons.check)
                          : r.status == RegistrationStatus.registered
                              ? FilledButton(
                                  onPressed: vm.busy ? null : () => vm.manualCheckIn(r),
                                  style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                                  child: const Text('Check in'),
                                )
                              : StatusChip(label: r.status.label, color: AppColors.orange),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _walkIn(BuildContext context) async {
    final name = TextEditingController();
    final tp = TextEditingController();
    final key = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Register walk-in'),
        content: Form(
          key: key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: name, autofocus: true, validator: (v) => Validators.required(v, 'Name'), decoration: const InputDecoration(labelText: 'Student name')),
              const SizedBox(height: 10),
              TextFormField(controller: tp, validator: Validators.studentId, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'TP number')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (key.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Check in'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final done = await widget.vm.registerWalkIn(name.text.trim(), tp.text.trim());
    if (context.mounted && !done) showAppSnackBar(context, widget.vm.error ?? 'Could not register walk-in', error: true);
  }
}

class _History extends StatelessWidget {
  const _History({required this.vm});
  final CheckInViewModel vm;

  @override
  Widget build(BuildContext context) {
    if (vm.history.isEmpty) {
      return Center(child: Text('Scans from this device appear here.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: vm.history.length,
      itemBuilder: (context, i) {
        final f = vm.history[i];
        final color = f.isSuccess ? AppColors.green : f.result == CheckInResult.duplicate ? AppColors.orange : AppColors.red;
        return ListTile(
          dense: true,
          leading: Icon(f.isSuccess ? Icons.check_circle_outline : Icons.error_outline, color: color),
          title: Text(f.registration?.studentName ?? 'Unknown ticket'),
          subtitle: Text(f.message),
          trailing: f.offline ? const StatusChip(label: 'Offline', color: AppColors.orange) : null,
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/validators.dart';
import '../../models/models.dart';
import '../../navigation/app_router.dart';
import '../../services/app_services.dart';
import '../../theme/app_colors.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/student/student_viewmodels.dart';
import '../../widgets/common_widgets.dart';
import '../auth/register_page.dart' show kProgrammes;

/// Profile screen shared by all roles; shows the fields relevant to the
/// signed-in user's role plus notification settings, password and logout.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, this.extraSections = const []});

  /// Role-specific extra cards (e.g. organiser's Student Affairs shortcut).
  final List<Widget> extraSections;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => ProfileViewModel(ctx.read<AppServices>()),
      child: _ProfileBody(extraSections: extraSections),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.extraSections});
  final List<Widget> extraSections;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final user = auth.user!;
    final vm = context.watch<ProfileViewModel>();
    final theme = Theme.of(context);
    final isVendor = user.role == UserRole.vendor;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: GradientHeader(
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        'Profile',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Log out',
                        onPressed: () async {
                          final ok = await confirmDialog(
                            context,
                            title: 'Log out?',
                            message: 'You can log back in any time.',
                            confirmLabel: 'Log out',
                          );
                          if (ok) await auth.signOut();
                        },
                        icon: const Icon(Icons.logout, color: AppColors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Stack(
                    children: [
                      UserAvatar(
                        name: user.displayName,
                        photoUrl: isVendor ? (user.businessImageUrl ?? user.photoUrl) : user.photoUrl,
                        radius: 44,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Material(
                          color: AppColors.orange,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: vm.busy
                                ? null
                                : () async {
                                    final url = await vm.uploadPhoto(
                                      user.uid,
                                      field: isVendor ? 'businessImageUrl' : 'photoUrl',
                                    );
                                    if (context.mounted && url != null) {
                                      showAppSnackBar(context, 'Photo updated', success: true);
                                    }
                                  },
                            child: const Padding(
                              padding: EdgeInsets.all(7),
                              child: Icon(Icons.camera_alt, size: 16, color: AppColors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    user.displayName,
                    style: theme.textTheme.titleLarge?.copyWith(color: AppColors.white, fontWeight: FontWeight.w700),
                  ),
                  Text(user.email, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.white.withValues(alpha: 0.85))),
                  const SizedBox(height: 6),
                  StatusChip(label: user.role.label, color: AppColors.white),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            sliver: SliverList.list(
              children: [
                if (vm.error != null) ...[
                  Text(vm.error!, style: const TextStyle(color: AppColors.red)),
                  const SizedBox(height: 8),
                ],
                ...extraSections.map((w) => Padding(padding: const EdgeInsets.only(bottom: 14), child: w)),
                _SectionCard(
                  title: 'Personal details',
                  icon: Icons.person_outline,
                  onEdit: () => _editDetails(context, user, vm),
                  rows: [
                    ('Full name', user.fullName),
                    if (user.role == UserRole.student) ...[
                      ('TP number', user.studentId ?? '—'),
                      ('Programme', user.programme ?? '—'),
                    ],
                    if (user.role == UserRole.organiser || user.role == UserRole.studentAffairs) ...[
                      ('Organisation', user.organisationName ?? '—'),
                      ('Position', user.position ?? '—'),
                    ],
                    if (isVendor) ...[
                      ('Business name', user.businessName ?? '—'),
                      ('Contact', user.contactNumber ?? '—'),
                      ('Category', user.productCategory ?? '—'),
                      ('Student vendor', user.isStudentVendor ? 'Yes' : 'No'),
                    ],
                  ],
                ),
                if (user.role == UserRole.student) ...[
                  const SizedBox(height: 14),
                  _InterestsCard(user: user, vm: vm),
                ],
                const SizedBox(height: 14),
                _NotificationCard(user: user, vm: vm),
                const SizedBox(height: 14),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.lock_outline, color: AppColors.indigo),
                        title: const Text('Change password'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _changePassword(context),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.notifications_outlined, color: AppColors.indigo),
                        title: const Text('Notification inbox'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(Routes.notifications),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.logout, color: AppColors.red),
                        title: const Text('Log out', style: TextStyle(color: AppColors.red)),
                        onTap: () async {
                          final ok = await confirmDialog(
                            context,
                            title: 'Log out?',
                            message: 'You can log back in any time.',
                            confirmLabel: 'Log out',
                          );
                          if (ok) await auth.signOut();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    'UniEvent • Every campus event, one tap away.',
                    style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editDetails(BuildContext context, AppUser user, ProfileViewModel vm) async {
    final name = TextEditingController(text: user.fullName);
    final a = TextEditingController(text: user.organisationName ?? user.businessName ?? '');
    final b = TextEditingController(text: user.position ?? user.contactNumber ?? '');
    final tp = TextEditingController(text: user.studentId ?? '');
    String? programme = kProgrammes.contains(user.programme) ? user.programme : null;
    String? category = kProductCategories.contains(user.productCategory) ? user.productCategory : null;
    final formKey = GlobalKey<FormState>();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Edit details', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: (v) => Validators.required(v, 'Full name'),
                ),
                const SizedBox(height: 12),
                if (user.role == UserRole.student) ...[
                  TextFormField(
                    controller: tp,
                    decoration: const InputDecoration(labelText: 'TP number'),
                    validator: Validators.studentId,
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: programme,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Programme'),
                    items: kProgrammes.map((p) => DropdownMenuItem(value: p, child: Text(p, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) => setState(() => programme = v),
                  ),
                ],
                if (user.role == UserRole.organiser || user.role == UserRole.studentAffairs) ...[
                  TextFormField(controller: a, decoration: const InputDecoration(labelText: 'Organisation / club')),
                  const SizedBox(height: 12),
                  TextFormField(controller: b, decoration: const InputDecoration(labelText: 'Position')),
                ],
                if (user.role == UserRole.vendor) ...[
                  TextFormField(
                    controller: a,
                    decoration: const InputDecoration(labelText: 'Business name'),
                    validator: (v) => Validators.required(v, 'Business name'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: b,
                    decoration: const InputDecoration(labelText: 'Contact number'),
                    validator: Validators.phone,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(labelText: 'Product category'),
                    items: kProductCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setState(() => category = v),
                  ),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
                  },
                  child: const Text('Save changes'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved != true || !context.mounted) return;

    final fields = <String, dynamic>{'fullName': name.text.trim()};
    switch (user.role) {
      case UserRole.student:
        fields['studentId'] = tp.text.trim().toUpperCase();
        fields['programme'] = programme;
      case UserRole.organiser:
      case UserRole.studentAffairs:
        fields['organisationName'] = a.text.trim();
        fields['position'] = b.text.trim();
      case UserRole.vendor:
        fields['businessName'] = a.text.trim();
        fields['contactNumber'] = b.text.trim();
        fields['productCategory'] = category;
    }
    final ok = await vm.save(user.uid, fields);
    if (context.mounted && ok) showAppSnackBar(context, 'Profile updated', success: true);
  }

  Future<void> _changePassword(BuildContext context) async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change password'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: current,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current password'),
                validator: (v) => Validators.required(v, 'Current password'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: next,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
                validator: Validators.password,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: confirm,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm new password'),
                validator: (v) => Validators.confirmPassword(v, next.text),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final auth = context.read<AuthViewModel>();
    final done = await auth.changePassword(current.text, next.text);
    if (!context.mounted) return;
    if (done) {
      showAppSnackBar(context, 'Password updated', success: true);
    } else {
      showAppSnackBar(context, auth.error ?? 'Could not update password', error: true);
    }
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.rows,
    this.onEdit,
  });

  final String title;
  final IconData icon;
  final List<(String, String)> rows;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.indigo, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
              if (onEdit != null) TextButton(onPressed: onEdit, child: const Text('Edit')),
            ],
          ),
          const SizedBox(height: 4),
          ...rows.map(
            (r) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(r.$1, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                  ),
                  Expanded(child: Text(r.$2, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InterestsCard extends StatelessWidget {
  const _InterestsCard({required this.user, required this.vm});
  final AppUser user;
  final ProfileViewModel vm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.favorite_border, color: AppColors.indigo, size: 20),
              const SizedBox(width: 8),
              Text('Event interests', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kEventCategories.map((c) {
              final sel = user.interests.contains(c);
              return FilterChip(
                label: Text(c),
                selected: sel,
                labelStyle: TextStyle(color: sel ? AppColors.white : AppColors.midnight),
                onSelected: (s) {
                  final next = [...user.interests];
                  s ? next.add(c) : next.remove(c);
                  vm.save(user.uid, {'interests': next});
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.user, required this.vm});
  final AppUser user;
  final ProfileViewModel vm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_outlined, color: AppColors.indigo, size: 20),
              const SizedBox(width: 8),
              Text('Notification preferences', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Push notifications'),
            subtitle: const Text('Announcements, order updates, waitlist changes'),
            value: user.notificationsEnabled,
            onChanged: (v) => vm.save(user.uid, {'notificationsEnabled': v}),
          ),
          if (user.role == UserRole.student) ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Reminder 1 day before'),
              value: user.reminderOneDay,
              onChanged: user.notificationsEnabled ? (v) => vm.save(user.uid, {'reminderOneDay': v}) : null,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Reminder 1 hour before'),
              value: user.reminderOneHour,
              onChanged: user.notificationsEnabled ? (v) => vm.save(user.uid, {'reminderOneHour': v}) : null,
            ),
          ],
        ],
      ),
    );
  }
}

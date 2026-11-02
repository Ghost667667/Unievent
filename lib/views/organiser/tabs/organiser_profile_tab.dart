import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../models/models.dart';
import '../../../navigation/app_router.dart';
import '../../../theme/app_colors.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../viewmodels/organiser/organiser_viewmodels.dart';
import '../../../widgets/common_widgets.dart';
import '../../shared/profile_page.dart';

class OrganiserProfileTab extends StatelessWidget {
  const OrganiserProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthViewModel>().user!;
    final vm = context.watch<OrganiserDashboardViewModel>();
    return ProfilePage(
      extraSections: [
        if (user.role == UserRole.studentAffairs)
          AppCard(
            color: AppColors.midnight,
            onTap: () => context.push(Routes.studentAffairs),
            child: const Row(
              children: [
                Icon(Icons.verified_user_outlined, color: AppColors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Student Affairs approval dashboard', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w700))),
                Icon(Icons.chevron_right, color: AppColors.white),
              ],
            ),
          ),
        AppCard(
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.dataset_outlined, color: AppColors.indigo),
            title: const Text('Load sample data'),
            subtitle: const Text('Adds demo events, a proposal, budget lines and crew tasks owned by you.'),
            trailing: vm.busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.chevron_right),
            onTap: vm.busy
                ? null
                : () async {
                    final n = await vm.loadSampleData();
                    if (context.mounted) {
                      showAppSnackBar(context, n > 0 ? 'Added $n sample events.' : (vm.error ?? 'Could not load sample data.'), success: n > 0, error: n == 0);
                    }
                  },
          ),
        ),
      ],
    );
  }
}

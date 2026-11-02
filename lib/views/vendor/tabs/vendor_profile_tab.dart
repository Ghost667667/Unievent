import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../navigation/app_router.dart';
import '../../../theme/app_colors.dart';
import '../../../viewmodels/vendor/vendor_viewmodels.dart';
import '../../../widgets/common_widgets.dart';
import '../../shared/profile_page.dart';

class VendorProfileTab extends StatelessWidget {
  const VendorProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<VendorDashboardViewModel>();
    return ProfilePage(
      extraSections: [
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.insights_outlined, color: AppColors.indigo),
                title: const Text('Sales analytics'),
                subtitle: const Text('Bestsellers, cancelled orders, event performance'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(Routes.vendorAnalytics),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.dataset_outlined, color: AppColors.indigo),
                title: const Text('Load sample products'),
                subtitle: const Text('Adds six demo products to your catalogue.'),
                trailing: vm.busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.chevron_right),
                onTap: vm.busy
                    ? null
                    : () async {
                        final n = await vm.loadSampleData();
                        if (context.mounted) showAppSnackBar(context, n > 0 ? 'Added $n sample products.' : (vm.error ?? 'Failed'), success: n > 0, error: n == 0);
                      },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

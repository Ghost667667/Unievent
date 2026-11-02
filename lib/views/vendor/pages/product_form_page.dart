import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/validators.dart';
import '../../../models/models.dart';
import '../../../services/app_services.dart';
import '../../../theme/app_colors.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../viewmodels/vendor/vendor_viewmodels.dart';
import '../../../widgets/common_widgets.dart';

/// Add or edit a product (name, description, picture, RM price, quantity,
/// category, low-stock threshold).
class ProductFormPage extends StatelessWidget {
  const ProductFormPage({super.key, this.productId});
  final String? productId;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthViewModel>().user!;
    return ChangeNotifierProvider(
      create: (ctx) => ProductFormViewModel(ctx.read<AppServices>(), user),
      child: _ProductForm(productId: productId),
    );
  }
}

class _ProductForm extends StatefulWidget {
  const _ProductForm({required this.productId});
  final String? productId;

  @override
  State<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<_ProductForm> {
  final _key = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _price = TextEditingController();
  final _qty = TextEditingController(text: '20');
  final _threshold = TextEditingController(text: '5');
  String _category = kProductCategories.first;
  Product? _existing;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.productId != null) {
      final user = context.read<AuthViewModel>().user!;
      final products = await context.read<AppServices>().products.fetchByVendor(user.uid);
      final m = products.where((p) => p.id == widget.productId);
      if (m.isNotEmpty) {
        final p = m.first;
        _existing = p;
        _name.text = p.name;
        _desc.text = p.description;
        _price.text = p.price.toStringAsFixed(2);
        _qty.text = '${p.quantity}';
        _threshold.text = '${p.lowStockThreshold}';
        _category = kProductCategories.contains(p.category) ? p.category : 'Other';
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    for (final c in [_name, _desc, _price, _qty, _threshold]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProductFormViewModel>();
    final theme = Theme.of(context);
    if (_loading) return const Scaffold(body: LoadingView());

    return Scaffold(
      appBar: AppBar(title: Text(_existing == null ? 'Add Product' : 'Edit Product')),
      body: Form(
        key: _key,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            GestureDetector(
              onTap: vm.pickImage,
              child: Container(
                height: 180,
                decoration: BoxDecoration(color: AppColors.surfaceTint, borderRadius: BorderRadius.circular(16)),
                clipBehavior: Clip.antiAlias,
                child: vm.imageFile != null
                    ? Image.memory(vm.imageFile!.bytes, fit: BoxFit.cover)
                    : (_existing?.imageUrl != null)
                        ? CachedNetworkImage(imageUrl: _existing!.imageUrl!, fit: BoxFit.cover)
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo_outlined, size: 40, color: AppColors.indigo),
                              SizedBox(height: 6),
                              Text('Upload product picture', style: TextStyle(color: AppColors.indigo, fontWeight: FontWeight.w600)),
                            ],
                          ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(onPressed: vm.pickImage, icon: const Icon(Icons.photo_library_outlined, size: 18), label: const Text('Choose picture')),
            ),
            TextFormField(controller: _name, validator: (v) => Validators.required(v, 'Product name'), decoration: const InputDecoration(labelText: 'Product name')),
            const SizedBox(height: 12),
            TextFormField(controller: _desc, maxLines: 3, decoration: const InputDecoration(labelText: 'Description (optional)', alignLabelWithHint: true)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: kProductCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => Validators.money(v, 'Price'),
                    decoration: const InputDecoration(labelText: 'Price (RM)', prefixText: 'RM '),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _qty,
                    onChanged: (_) => setState(() {}),
                    keyboardType: TextInputType.number,
                    validator: (v) => Validators.nonNegativeInt(v, 'Quantity'),
                    decoration: const InputDecoration(labelText: 'Available quantity'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _threshold,
              onChanged: (_) => setState(() {}),
              keyboardType: TextInputType.number,
              validator: (v) => Validators.nonNegativeInt(v, 'Threshold'),
              decoration: const InputDecoration(labelText: 'Low-stock warning at (units)', helperText: 'Shows an orange "Low Stock" tag to students at or below this number'),
            ),
            const SizedBox(height: 12),
            Text('Stock status preview', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            Builder(
              builder: (context) {
                final q = int.tryParse(_qty.text) ?? 0;
                final t = int.tryParse(_threshold.text) ?? 5;
                final s = Product.stockStatusFor(q, t);
                final c = switch (s) {
                  StockStatus.available => AppColors.green,
                  StockStatus.lowStock => AppColors.orange,
                  StockStatus.soldOut => AppColors.red,
                };
                return Align(alignment: Alignment.centerLeft, child: StatusChip(label: s.label, color: c, icon: Icons.circle));
              },
            ),
            const SizedBox(height: 24),
            if (vm.error != null) ...[Text(vm.error!, style: const TextStyle(color: AppColors.red)), const SizedBox(height: 8)],
            BusyButton(
              label: _existing == null ? 'Add product' : 'Save changes',
              icon: Icons.check,
              busy: vm.busy,
              onPressed: () async {
                if (!_key.currentState!.validate()) return;
                final ok = await vm.save(
                  existing: _existing,
                  name: _name.text.trim(),
                  description: _desc.text.trim(),
                  category: _category,
                  price: double.parse(_price.text.trim()),
                  quantity: int.parse(_qty.text.trim()),
                  lowStockThreshold: int.parse(_threshold.text.trim()),
                );
                if (!context.mounted) return;
                if (ok) {
                  showAppSnackBar(context, _existing == null ? 'Product added.' : 'Product updated.', success: true);
                  context.pop();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

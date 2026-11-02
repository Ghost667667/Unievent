import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/validators.dart';
import '../../models/models.dart';
import '../../navigation/app_router.dart';
import '../../theme/app_colors.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/common_widgets.dart';
import 'auth_widgets.dart';

const List<String> kProgrammes = [
  'BSc (Hons) Computer Science',
  'BSc (Hons) Software Engineering',
  'BSc (Hons) Information Technology',
  'BSc (Hons) Cyber Security',
  'BSc (Hons) Data Science',
  'BA (Hons) Business Management',
  'BA (Hons) Accounting & Finance',
  'BA (Hons) Design',
  'Diploma in ICT',
  'Other',
];

/// Registration with a role dropdown that reveals role-specific fields.
/// With [googleCompletion] the email/password fields are hidden and the
/// screen just completes the profile for an already-signed-in Google user.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, this.googleCompletion = false});

  final bool googleCompletion;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _studentId = TextEditingController();
  final _orgName = TextEditingController();
  final _position = TextEditingController();
  final _businessName = TextEditingController();
  final _contact = TextEditingController();
  final _eligibility = TextEditingController();

  UserRole? _role;
  String? _programme;
  String? _productCategory;
  final Set<String> _interests = {};
  bool _isStudentVendor = true;
  bool _roleError = false;

  @override
  void initState() {
    super.initState();
    if (widget.googleCompletion) {
      final fb = context.read<AuthViewModel>().firebaseUser;
      _name.text = fb?.displayName ?? '';
      _email.text = fb?.email ?? '';
    }
  }

  @override
  void dispose() {
    for (final c in [
      _name, _email, _password, _confirm, _studentId, _orgName, _position,
      _businessName, _contact, _eligibility,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _roleError = _role == null);
    final valid = _formKey.currentState!.validate();
    if (!valid || _role == null) return;
    if (_role == UserRole.student && _interests.isEmpty) {
      showAppSnackBar(context, 'Pick at least one event interest.', error: true);
      return;
    }

    final template = AppUser(
      uid: '',
      email: _email.text.trim(),
      fullName: _name.text.trim(),
      role: _role!,
      studentId: _role == UserRole.student ? _studentId.text.trim().toUpperCase() : null,
      programme: _role == UserRole.student ? _programme : null,
      interests: _role == UserRole.student ? _interests.toList() : const [],
      organisationName: _role == UserRole.organiser ? _orgName.text.trim() : null,
      position: _role == UserRole.organiser ? _position.text.trim() : null,
      businessName: _role == UserRole.vendor ? _businessName.text.trim() : null,
      contactNumber: _role == UserRole.vendor ? _contact.text.trim() : null,
      productCategory: _role == UserRole.vendor ? _productCategory : null,
      isStudentVendor: _role == UserRole.vendor && _isStudentVendor,
      eligibilityNotes: _role == UserRole.vendor ? _eligibility.text.trim() : null,
    );

    final auth = context.read<AuthViewModel>();
    final ok = widget.googleCompletion
        ? await auth.completeGoogleProfile(template)
        : await auth.register(
            email: _email.text,
            password: _password.text,
            template: template,
          );
    if (!mounted) return;
    if (ok) {
      showAppSnackBar(
        context,
        widget.googleCompletion
            ? 'Profile complete. Welcome to UniEvent!'
            : 'Account created! A verification email is on its way.',
        success: true,
      );
      // Router redirects to the matching dashboard.
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        leading: widget.googleCompletion
            ? IconButton(
                tooltip: 'Sign out',
                icon: const Icon(Icons.logout),
                onPressed: () => auth.signOut(),
              )
            : BackButton(
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go(Routes.welcome),
              ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AuthHeader(
                      title: widget.googleCompletion
                          ? 'Complete Your Profile'
                          : 'Create Your Account',
                      subtitle: 'Join the UniEvent community.',
                    ),
                    const SizedBox(height: 24),
                    if (auth.error != null) ...[
                      ErrorBanner(auth.error!),
                      const SizedBox(height: 16),
                    ],

                    // ── Role dropdown ──
                    Text(
                      'Select Your Role',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<UserRole>(
                      key: const Key('register_role'),
                      initialValue: _role,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      hint: const Text('Select your role'),
                      decoration: InputDecoration(
                        fillColor: AppColors.white,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _roleError ? AppColors.red : AppColors.indigo,
                            width: 1.4,
                          ),
                        ),
                        errorText: _roleError ? 'Please select your role' : null,
                      ),
                      selectedItemBuilder: (ctx) => UserRole.publicRoles
                          .map(
                            (r) => Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                r.label,
                                style: const TextStyle(
                                  color: AppColors.indigo,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      items: UserRole.publicRoles
                          .map(
                            (r) => DropdownMenuItem(
                              value: r,
                              child: Row(
                                children: [
                                  Icon(_roleIcon(r), size: 20, color: AppColors.indigo),
                                  const SizedBox(width: 10),
                                  Text(r.label),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (r) => setState(() {
                        _role = r;
                        _roleError = false;
                      }),
                    ),
                    const SizedBox(height: 20),

                    // ── Common fields ──
                    TextFormField(
                      key: const Key('register_name'),
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => Validators.required(v, 'Full name'),
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      key: const Key('register_email'),
                      controller: _email,
                      readOnly: widget.googleCompletion,
                      keyboardType: TextInputType.emailAddress,
                      validator: Validators.email,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                    ),
                    if (!widget.googleCompletion) ...[
                      const SizedBox(height: 14),
                      PasswordField(
                        key: const Key('register_password'),
                        controller: _password,
                        label: 'Password',
                        validator: Validators.password,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 14),
                      PasswordField(
                        key: const Key('register_confirm'),
                        controller: _confirm,
                        label: 'Confirm Password',
                        validator: (v) =>
                            Validators.confirmPassword(v, _password.text),
                        textInputAction: TextInputAction.next,
                      ),
                    ],

                    // ── Role-specific fields ──
                    AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      alignment: Alignment.topCenter,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: KeyedSubtree(
                          key: ValueKey(_role),
                          child: _roleFields(theme),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    BusyButton(
                      key: const Key('register_submit'),
                      label: widget.googleCompletion ? 'Finish' : 'Create Account',
                      busy: auth.busy,
                      onPressed: _submit,
                    ),
                    if (!widget.googleCompletion) ...[
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Already have an account?',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.go(Routes.login),
                            child: const Text('Log In'),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Student Affairs accounts are provisioned by the university '
                      'and cannot be created here.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _roleIcon(UserRole r) {
    switch (r) {
      case UserRole.student:
        return Icons.school_outlined;
      case UserRole.organiser:
        return Icons.event_available_outlined;
      case UserRole.vendor:
        return Icons.storefront_outlined;
      case UserRole.studentAffairs:
        return Icons.verified_user_outlined;
    }
  }

  Widget _roleFields(ThemeData theme) {
    switch (_role) {
      case null:
      case UserRole.studentAffairs:
        return const SizedBox(height: 0);
      case UserRole.student:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('register_student_id'),
              controller: _studentId,
              textCapitalization: TextCapitalization.characters,
              validator: Validators.studentId,
              decoration: const InputDecoration(
                labelText: 'Student ID / TP Number',
                hintText: 'TP012345',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _programme,
              isExpanded: true,
              validator: (v) => v == null ? 'Select your programme' : null,
              decoration: const InputDecoration(
                labelText: 'University Programme',
                prefixIcon: Icon(Icons.menu_book_outlined),
              ),
              items: kProgrammes
                  .map((p) => DropdownMenuItem(value: p, child: Text(p, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) => setState(() => _programme = v),
            ),
            const SizedBox(height: 16),
            Text(
              'Event Interests',
              style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kEventCategories.map((c) {
                final selected = _interests.contains(c);
                return FilterChip(
                  label: Text(c),
                  selected: selected,
                  labelStyle: TextStyle(
                    color: selected ? AppColors.white : AppColors.midnight,
                  ),
                  onSelected: (s) => setState(() {
                    s ? _interests.add(c) : _interests.remove(c);
                  }),
                );
              }).toList(),
            ),
          ],
        );
      case UserRole.organiser:
        return Column(
          children: [
            const SizedBox(height: 14),
            TextFormField(
              controller: _orgName,
              textCapitalization: TextCapitalization.words,
              validator: (v) => Validators.required(v, 'Organisation / club name'),
              decoration: const InputDecoration(
                labelText: 'Organisation / Club Name',
                prefixIcon: Icon(Icons.groups_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _position,
              textCapitalization: TextCapitalization.words,
              validator: (v) => Validators.required(v, 'Position'),
              decoration: const InputDecoration(
                labelText: 'Position',
                hintText: 'e.g. President, Events Director',
                prefixIcon: Icon(Icons.work_outline),
              ),
            ),
          ],
        );
      case UserRole.vendor:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 14),
            TextFormField(
              controller: _businessName,
              textCapitalization: TextCapitalization.words,
              validator: (v) => Validators.required(v, 'Business name'),
              decoration: const InputDecoration(
                labelText: 'Business Name',
                prefixIcon: Icon(Icons.storefront_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _contact,
              keyboardType: TextInputType.phone,
              validator: Validators.phone,
              decoration: const InputDecoration(
                labelText: 'Contact Number',
                hintText: '+60 12-345 6789',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _productCategory,
              validator: (v) => v == null ? 'Select a product category' : null,
              decoration: const InputDecoration(
                labelText: 'Product Category',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: kProductCategories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _productCategory = v),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('I am an APU student vendor'),
                subtitle: const Text(
                  'APU policy currently allows student-run booths only.',
                  style: TextStyle(fontSize: 12),
                ),
                value: _isStudentVendor,
                onChanged: (v) => setState(() => _isStudentVendor = v),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _eligibility,
              maxLines: 2,
              validator: (v) => Validators.required(v, 'Eligibility information'),
              decoration: const InputDecoration(
                labelText: 'Eligibility Information',
                hintText: _isStudentVendorHint,
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.fact_check_outlined),
              ),
            ),
          ],
        );
    }
  }

  static const String _isStudentVendorHint =
      'TP number, food-handling certificate no., SSM registration…';
}

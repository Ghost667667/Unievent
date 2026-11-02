import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/validators.dart';
import '../../navigation/app_router.dart';
import '../../theme/app_colors.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/common_widgets.dart';
import 'auth_widgets.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthViewModel>();
    final ok = await auth.signIn(_email.text, _password.text);
    if (!mounted) return;
    if (ok) {
      // Router redirects to the role dashboard once the profile loads.
      showAppSnackBar(context, 'Welcome back!', success: true);
    }
  }

  Future<void> _google() async {
    final auth = context.read<AuthViewModel>();
    final result = await auth.signInWithGoogle();
    if (!mounted) return;
    if (result == false) {
      // New Google user: router moves to /complete-profile automatically.
      showAppSnackBar(context, 'Almost there — choose your role to finish.');
    }
  }

  Future<void> _forgotPassword() async {
    final controller = TextEditingController(text: _email.text);
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset password'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email address'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Send link'),
          ),
        ],
      ),
    );
    if (email == null || !mounted) return;
    if (Validators.email(email) != null) {
      showAppSnackBar(context, 'Enter a valid email address.', error: true);
      return;
    }
    final ok = await context.read<AuthViewModel>().sendPasswordReset(email);
    if (!mounted) return;
    if (ok) {
      showAppSnackBar(context, 'Reset link sent to $email', success: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.canPop() ? context.pop() : context.go(Routes.welcome)),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AuthHeader(
                        title: 'Welcome Back!',
                        subtitle: 'Log in to continue your campus experience.',
                      ),
                      const SizedBox(height: 28),
                      if (auth.error != null) ...[
                        ErrorBanner(auth.error!),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        key: const Key('login_email'),
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        validator: Validators.email,
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: Icon(Icons.mail_outline),
                        ),
                      ),
                      const SizedBox(height: 14),
                      PasswordField(
                        key: const Key('login_password'),
                        controller: _password,
                        label: 'Password',
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Password is required' : null,
                        onSubmitted: (_) => _login(),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Checkbox(
                            value: auth.rememberMe,
                            onChanged: (v) => auth.rememberMe = v ?? true,
                          ),
                          const Expanded(
                            child: Text('Remember me', overflow: TextOverflow.ellipsis),
                          ),
                          TextButton(
                            onPressed: _forgotPassword,
                            child: const Text('Forgot Password?'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      BusyButton(
                        key: const Key('login_submit'),
                        label: 'Log In',
                        busy: auth.busy,
                        onPressed: _login,
                      ),
                      const SizedBox(height: 20),
                      const OrDivider(),
                      const SizedBox(height: 20),
                      GoogleSignInButton(onPressed: _google, busy: auth.busy),
                      const SizedBox(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account?",
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                          ),
                          TextButton(
                            onPressed: () => context.push(Routes.register),
                            child: const Text('Create Account'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

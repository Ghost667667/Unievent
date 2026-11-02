import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../navigation/app_router.dart';
import '../../theme/app_colors.dart';
import '../../widgets/unievent_logo.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  Animation<double> _fade(double start) => CurvedAnimation(
        parent: _controller,
        curve: Interval(start, (start + 0.5).clamp(0.0, 1.0), curve: Curves.easeOut),
      );

  Animation<Offset> _slide(double start) => Tween<Offset>(
        begin: const Offset(0, 0.15),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(start, (start + 0.5).clamp(0.0, 1.0), curve: Curves.easeOutCubic),
        ),
      );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.brandGradient),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 600;
              final logoSize = wide ? 140.0 : 112.0;
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      children: [
                        const Spacer(flex: 3),
                        FadeTransition(
                          opacity: _fade(0),
                          child: SlideTransition(
                            position: _slide(0),
                            child: UniEventLogo(size: logoSize),
                          ),
                        ),
                        const SizedBox(height: 28),
                        FadeTransition(
                          opacity: _fade(0.15),
                          child: SlideTransition(
                            position: _slide(0.15),
                            child: Text(
                              'UniEvent',
                              style: theme.textTheme.displaySmall?.copyWith(
                                color: AppColors.white,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        FadeTransition(
                          opacity: _fade(0.3),
                          child: SlideTransition(
                            position: _slide(0.3),
                            child: Column(
                              children: [
                                Text(
                                  'Every campus event, one tap away.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Discover, connect, and celebrate campus life.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: AppColors.white.withValues(alpha: 0.85),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(flex: 4),
                        FadeTransition(
                          opacity: _fade(0.45),
                          child: SlideTransition(
                            position: _slide(0.45),
                            child: Column(
                              children: [
                                ElevatedButton(
                                  key: const Key('welcome_login'),
                                  onPressed: () => context.push(Routes.login),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.white,
                                    foregroundColor: AppColors.indigo,
                                    minimumSize: const Size.fromHeight(56),
                                  ),
                                  child: const Text('Log In'),
                                ),
                                const SizedBox(height: 14),
                                OutlinedButton(
                                  key: const Key('welcome_create_account'),
                                  onPressed: () => context.push(Routes.register),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.white,
                                    side: const BorderSide(
                                      color: AppColors.white,
                                      width: 1.6,
                                    ),
                                    minimumSize: const Size.fromHeight(56),
                                  ),
                                  child: const Text('Create Account'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        FadeTransition(
                          opacity: _fade(0.5),
                          child: Text(
                            'Discover • Connect • Celebrate',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: AppColors.white.withValues(alpha: 0.75),
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:provider/provider.dart';
import 'package:unievent/models/models.dart';
import 'package:unievent/navigation/app_router.dart';
import 'package:unievent/services/app_services.dart';
import 'package:unievent/theme/app_theme.dart';
import 'package:unievent/viewmodels/auth_viewmodel.dart';
import 'package:unievent/views/auth/login_page.dart';
import 'package:unievent/views/auth/register_page.dart';
import 'package:unievent/views/auth/welcome_page.dart';
import 'package:unievent/widgets/event_card.dart';

import '../helpers/test_app.dart';

Widget _routed(AppServices services, AuthViewModel auth) {
  final router = buildRouter(auth);
  return MultiProvider(
    providers: [
      Provider<AppServices>.value(value: services),
      ChangeNotifierProvider<AuthViewModel>.value(value: auth),
    ],
    child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  );
}

void main() {
  group('Welcome page', () {
    testWidgets('shows branding and both buttons', (tester) async {
      final services = buildTestServices();
      await tester.pumpWidget(wrapWithProviders(services, const WelcomePage()));
      await tester.pumpAndSettle();

      expect(find.text('UniEvent'), findsOneWidget);
      expect(find.text('Every campus event, one tap away.'), findsOneWidget);
      expect(find.byKey(const Key('welcome_login')), findsOneWidget);
      expect(find.byKey(const Key('welcome_create_account')), findsOneWidget);
    });
  });

  group('Login page', () {
    testWidgets('validates empty fields before calling Firebase', (tester) async {
      final services = buildTestServices();
      await tester.pumpWidget(wrapWithProviders(services, const LoginPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('login_submit')));
      await tester.pumpAndSettle();

      expect(find.text('Email address is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('shows error for wrong credentials', (tester) async {
      final services = buildTestServices();
      await tester.pumpWidget(wrapWithProviders(services, const LoginPage()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('login_email')), 'nobody@apu.edu.my');
      await tester.enterText(find.byKey(const Key('login_password')), 'Password1');
      await tester.tap(find.byKey(const Key('login_submit')));
      await tester.pumpAndSettle();

      // MockFirebaseAuth signs in anyone, but there is no profile document.
      expect(find.textContaining('no profile'), findsOneWidget);
    });
  });

  group('Registration page', () {
    testWidgets('role dropdown reveals role-specific fields', (tester) async {
      final services = buildTestServices();
      await tester.pumpWidget(wrapWithProviders(services, const RegisterPage()));
      await tester.pumpAndSettle();

      expect(find.text('Select your role'), findsOneWidget);
      expect(find.byKey(const Key('register_student_id')), findsNothing);

      await tester.tap(find.byKey(const Key('register_role')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Student / Attendee').last);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('register_student_id')), findsOneWidget);
      expect(find.text('Event Interests'), findsOneWidget);

      await tester.tap(find.byKey(const Key('register_role')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vendor').last);
      await tester.pumpAndSettle();

      expect(find.text('Business Name'), findsOneWidget);
      expect(find.text('Contact Number'), findsOneWidget);
      expect(find.byKey(const Key('register_student_id')), findsNothing);
    });

    testWidgets('requires a role before submitting', (tester) async {
      final services = buildTestServices();
      await tester.pumpWidget(wrapWithProviders(services, const RegisterPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('register_submit')));
      await tester.pumpAndSettle();
      expect(find.text('Please select your role'), findsOneWidget);
    });
  });

  group('Role-based navigation', () {
    for (final (profile, expected) in [
      (testStudent(), 'Hello, Yunis!'),
      (testOrganiser(), 'Welcome, Leila'),
      (testVendor(), "Welcome, Massa's Kitchen!"),
    ]) {
      testWidgets('${profile.role.label} lands on their dashboard', (tester) async {
        await mockNetworkImagesFor(() async {
          final (services, _) = await signedInServices(profile);
          final auth = AuthViewModel(services);
          await tester.pumpWidget(_routed(services, auth));
          await tester.pumpAndSettle(const Duration(seconds: 1));
          expect(find.text(expected), findsOneWidget);
          auth.dispose();
        });
      });
    }
  });

  group('EventCard', () {
    testWidgets('shows Register when seats remain and Join Waitlist when full', (tester) async {
      await mockNetworkImagesFor(() async {
        final services = buildTestServices();
        await tester.pumpWidget(
          wrapWithProviders(
            services,
            Scaffold(
              body: ListView(
                children: [
                  EventCard(event: testEvent(capacity: 50, registered: 10), onTap: () {}, onRegister: () {}),
                  EventCard(event: testEvent(id: 'ev2', capacity: 50, registered: 50), onTap: () {}, onRegister: () {}),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Register'), findsOneWidget);
        expect(find.text('Join Waitlist'), findsOneWidget);
        expect(find.text('40 of 50 seats left'), findsOneWidget);
        expect(find.textContaining('Fully booked'), findsOneWidget);
      });
    });

    testWidgets('shows Registered chip when the student already holds a seat', (tester) async {
      await mockNetworkImagesFor(() async {
        final services = buildTestServices();
        await tester.pumpWidget(
          wrapWithProviders(
            services,
            Scaffold(
              body: EventCard(
                event: testEvent(),
                onTap: () {},
                registration: const Registration(
                  id: 'r',
                  eventId: 'ev1',
                  eventTitle: 't',
                  studentId: 's',
                  studentName: 'S',
                  studentTp: 'TP1',
                  status: RegistrationStatus.registered,
                  ticketCode: 'ABCDEFGHJKLMNPQR',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Registered'), findsOneWidget);
      });
    });
  });
}

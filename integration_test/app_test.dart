import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:unievent/main.dart';
import 'package:unievent/models/models.dart';

import '../test/helpers/test_app.dart';

/// End-to-end flow on a device/emulator using in-memory Firebase fakes, so it
/// runs without network or a real project:
///
///   flutter test integration_test/app_test.dart
///
/// Welcome → Create Account (Student) → Student dashboard → Explore shows the
/// event → Register → My Events shows the ticket.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('student signs up, registers and sees ticket', (tester) async {
    final services = buildTestServices();
    await services.events.save(testEvent(capacity: 30));

    await tester.pumpWidget(UniEventApp(services: services));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Welcome
    expect(find.text('Every campus event, one tap away.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('welcome_create_account')));
    await tester.pumpAndSettle();

    // Registration
    await tester.tap(find.byKey(const Key('register_role')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Student / Attendee').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('register_name')), 'Yunis Abdulrahman');
    await tester.enterText(find.byKey(const Key('register_email')), 'yunis@mail.apu.edu.my');
    await tester.enterText(find.byKey(const Key('register_password')), 'Password1');
    await tester.enterText(find.byKey(const Key('register_confirm')), 'Password1');
    await tester.enterText(find.byKey(const Key('register_student_id')), 'TP088620');

    // Programme dropdown
    await tester.tap(find.text('University Programme'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('BSc (Hons) Computer Science').last);
    await tester.pumpAndSettle();

    // Interests
    await tester.tap(find.widgetWithText(FilterChip, 'Cultural'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('register_submit')));
    await tester.tap(find.byKey(const Key('register_submit')));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Student dashboard
    expect(find.text('Hello, Yunis!'), findsOneWidget);

    // Register from the feed card
    await tester.tap(find.text('Register').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Register Now'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text("You're registered!"), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // My Events shows the ticket
    await tester.tap(find.text('My Events'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('Africa Day Cultural Night'), findsWidgets);

    final regs = await services.registrations.fetchByEvent('ev1');
    expect(regs.single.status, RegistrationStatus.registered);
  });
}

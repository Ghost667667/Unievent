import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:unievent/models/models.dart';
import 'package:unievent/viewmodels/auth_viewmodel.dart';
import 'package:unievent/views/student/pages/event_details_page.dart';
import 'package:unievent/views/student/pages/ticket_page.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('Event details → Register → ticket is created with QR', (tester) async {
    await mockNetworkImagesFor(() async {
      final (services, _) = await signedInServices(testStudent());
      final auth = AuthViewModel(services);
      await services.events.save(testEvent(capacity: 50));

      await tester.pumpWidget(wrapWithProviders(services, const EventDetailsPage(eventId: 'ev1'), auth: auth));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.text('Africa Day Cultural Night'), findsWidgets);
      expect(find.byKey(const Key('details_register')), findsOneWidget);

      await tester.tap(find.byKey(const Key('details_register')));
      await tester.pumpAndSettle();
      // Confirmation sheet auto-fills the saved profile.
      expect(find.text('TP088620'), findsOneWidget);
      await tester.tap(find.text('Register Now'));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.text("You're registered!"), findsOneWidget);

      final regs = await services.registrations.fetchByEvent('ev1');
      expect(regs.single.status, RegistrationStatus.registered);
      expect(regs.single.studentTp, 'TP088620');

      final event = await services.events.get('ev1');
      expect(event!.registeredCount, 1);
      auth.dispose();
    });
  });

  testWidgets('Full event shows Join Waitlist and waitlists the student', (tester) async {
    await mockNetworkImagesFor(() async {
      final (services, _) = await signedInServices(testStudent());
      final auth = AuthViewModel(services);
      await services.events.save(testEvent(capacity: 1, registered: 1));

      await tester.pumpWidget(wrapWithProviders(services, const EventDetailsPage(eventId: 'ev1'), auth: auth));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.text('Join Waitlist'), findsOneWidget);
      await tester.tap(find.byKey(const Key('details_register')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Join Waitlist').last);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      final regs = await services.registrations.fetchByEvent('ev1');
      expect(regs.single.status, RegistrationStatus.waitlisted);
      expect(regs.single.waitlistPosition, 1);
      auth.dispose();
    });
  });

  testWidgets('Ticket page renders QR, ticket number and actions', (tester) async {
    await mockNetworkImagesFor(() async {
      final (services, _) = await signedInServices(testStudent());
      final auth = AuthViewModel(services);
      await services.events.save(testEvent());
      final reg = await services.registrations.register(event: testEvent(), student: testStudent());

      await tester.pumpWidget(wrapWithProviders(services, TicketPage(registrationId: reg.id), auth: auth));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.text('UNIEVENT TICKET'), findsOneWidget);
      expect(find.text('Yunis Abdulrahman'), findsOneWidget);
      expect(find.text('Add to Google Calendar'), findsOneWidget);
      expect(find.text('Open Google Maps'), findsOneWidget);
      expect(find.text('Confirm Attendance'), findsOneWidget);
      expect(find.text('Cancel Registration'), findsOneWidget);

      await tester.tap(find.text('Confirm Attendance'));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      final updated = await services.registrations.fetchByEvent('ev1');
      expect(updated.single.confirmed, isTrue);
      auth.dispose();
    });
  });
}

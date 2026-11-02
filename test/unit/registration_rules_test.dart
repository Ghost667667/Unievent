import 'package:flutter_test/flutter_test.dart';
import 'package:unievent/core/registration_rules.dart';
import 'package:unievent/models/enums.dart';

void main() {
  group('RegistrationRules.decide', () {
    test('registers when seats remain', () {
      expect(
        RegistrationRules.decide(capacity: 10, registeredCount: 3, registrationOpen: true),
        RegistrationDecision.register,
      );
    });

    test('waitlists when at capacity', () {
      expect(
        RegistrationRules.decide(capacity: 10, registeredCount: 10, registrationOpen: true),
        RegistrationDecision.waitlist,
      );
    });

    test('closed when registration is not open', () {
      expect(
        RegistrationRules.decide(capacity: 10, registeredCount: 0, registrationOpen: false),
        RegistrationDecision.closed,
      );
    });

    test('already registered wins over everything', () {
      expect(
        RegistrationRules.decide(
          capacity: 10,
          registeredCount: 10,
          registrationOpen: false,
          existingStatus: RegistrationStatus.registered,
        ),
        RegistrationDecision.alreadyRegistered,
      );
      expect(
        RegistrationRules.decide(
          capacity: 10,
          registeredCount: 0,
          registrationOpen: true,
          existingStatus: RegistrationStatus.waitlisted,
        ),
        RegistrationDecision.alreadyRegistered,
      );
    });

    test('cancelled registration can register again', () {
      expect(
        RegistrationRules.decide(
          capacity: 10,
          registeredCount: 0,
          registrationOpen: true,
          existingStatus: RegistrationStatus.cancelled,
        ),
        RegistrationDecision.register,
      );
    });
  });

  group('RegistrationRules.seatsToPromote', () {
    test('promotes min(free, waitlist)', () {
      expect(RegistrationRules.seatsToPromote(capacity: 10, registeredCount: 7, waitlistCount: 5), 3);
      expect(RegistrationRules.seatsToPromote(capacity: 10, registeredCount: 7, waitlistCount: 2), 2);
    });
    test('zero when full or no waitlist', () {
      expect(RegistrationRules.seatsToPromote(capacity: 10, registeredCount: 10, waitlistCount: 5), 0);
      expect(RegistrationRules.seatsToPromote(capacity: 10, registeredCount: 2, waitlistCount: 0), 0);
    });
  });

  group('Seat Rescue timing', () {
    final start = DateTime(2026, 11, 20, 19);

    test('sends requests once inside the window', () {
      expect(
        RegistrationRules.shouldSendConfirmationRequests(
          now: start.subtract(const Duration(hours: 23)),
          eventStart: start,
          hoursBefore: 24,
          alreadySentAt: null,
        ),
        isTrue,
      );
      expect(
        RegistrationRules.shouldSendConfirmationRequests(
          now: start.subtract(const Duration(hours: 30)),
          eventStart: start,
          hoursBefore: 24,
          alreadySentAt: null,
        ),
        isFalse,
      );
      expect(
        RegistrationRules.shouldSendConfirmationRequests(
          now: start.subtract(const Duration(hours: 23)),
          eventStart: start,
          hoursBefore: 24,
          alreadySentAt: start.subtract(const Duration(hours: 24)),
        ),
        isFalse,
        reason: 'never sends twice',
      );
    });

    test('releases only after requests were sent and deadline passed', () {
      expect(
        RegistrationRules.shouldReleaseUnconfirmed(
          now: start.subtract(const Duration(hours: 5)),
          eventStart: start,
          sentAt: start.subtract(const Duration(hours: 24)),
          deadlineHoursBeforeEvent: 6,
          alreadyReleasedAt: null,
        ),
        isTrue,
      );
      expect(
        RegistrationRules.shouldReleaseUnconfirmed(
          now: start.subtract(const Duration(hours: 5)),
          eventStart: start,
          sentAt: null,
          deadlineHoursBeforeEvent: 6,
          alreadyReleasedAt: null,
        ),
        isFalse,
      );
    });
  });

  group('noShowRate', () {
    test('computes percentage and clamps', () {
      expect(RegistrationRules.noShowRate(registered: 100, attended: 72), 28);
      expect(RegistrationRules.noShowRate(registered: 0, attended: 0), 0);
      expect(RegistrationRules.noShowRate(registered: 10, attended: 12), 0);
    });
  });

  group('ShowUpForecast', () {
    test('uses defaults with insufficient history', () {
      expect(ShowUpForecast.showUpRate(history: const [], isFree: true), ShowUpForecast.defaultFreeRate);
      expect(ShowUpForecast.showUpRate(history: const [(100, 80)], isFree: false), ShowUpForecast.defaultPaidRate);
    });

    test('uses pooled history when enough events', () {
      final rate = ShowUpForecast.showUpRate(history: const [(100, 60), (100, 80)], isFree: true);
      expect(rate, closeTo(0.70, 0.0001));
    });

    test('forecast weights confirmed students higher', () {
      final f = ShowUpForecast.forecast(registeredCount: 100, confirmedCount: 50, showUpRate: 0.6);
      // 50*0.95 + 50*0.6 = 77.5 → 78
      expect(f, 78);
      expect(ShowUpForecast.forecast(registeredCount: 0, confirmedCount: 0, showUpRate: 0.7), 0);
    });
  });
}

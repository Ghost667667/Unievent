import '../models/enums.dart';

/// Outcome of attempting to register for an event.
enum RegistrationDecision { register, waitlist, closed, alreadyRegistered }

/// Pure business rules for capacity, waitlists and Seat Rescue.
/// No Firestore dependency, so these are unit-tested directly.
class RegistrationRules {
  RegistrationRules._();

  /// Decide what happens when a student taps Register.
  static RegistrationDecision decide({
    required int capacity,
    required int registeredCount,
    required bool registrationOpen,
    RegistrationStatus? existingStatus,
  }) {
    if (existingStatus == RegistrationStatus.registered ||
        existingStatus == RegistrationStatus.waitlisted) {
      return RegistrationDecision.alreadyRegistered;
    }
    if (!registrationOpen) return RegistrationDecision.closed;
    if (registeredCount < capacity) return RegistrationDecision.register;
    return RegistrationDecision.waitlist;
  }

  /// Number of seats that can be given to waitlisted students.
  static int seatsToPromote({
    required int capacity,
    required int registeredCount,
    required int waitlistCount,
  }) {
    final free = capacity - registeredCount;
    if (free <= 0 || waitlistCount <= 0) return 0;
    return free < waitlistCount ? free : waitlistCount;
  }

  /// Seat Rescue: whether confirmation requests should be sent now.
  static bool shouldSendConfirmationRequests({
    required DateTime now,
    required DateTime eventStart,
    required int hoursBefore,
    required DateTime? alreadySentAt,
  }) {
    if (alreadySentAt != null) return false;
    final sendAt = eventStart.subtract(Duration(hours: hoursBefore));
    return !now.isBefore(sendAt) && now.isBefore(eventStart);
  }

  /// Seat Rescue: whether unconfirmed seats should be released now.
  static bool shouldReleaseUnconfirmed({
    required DateTime now,
    required DateTime eventStart,
    required DateTime? sentAt,
    required int deadlineHoursBeforeEvent,
    required DateTime? alreadyReleasedAt,
  }) {
    if (sentAt == null || alreadyReleasedAt != null) return false;
    final releaseAt =
        eventStart.subtract(Duration(hours: deadlineHoursBeforeEvent));
    return !now.isBefore(releaseAt) && now.isBefore(eventStart);
  }

  /// No-show percentage (0–100) for a finished event.
  static double noShowRate({required int registered, required int attended}) {
    if (registered <= 0) return 0;
    final rate = (registered - attended) / registered * 100;
    return rate.clamp(0, 100).toDouble();
  }
}

/// Show-Up Forecast: predicts real turnout from the historical show-up
/// rate of past events of the same category (System Proposal §2.3).
class ShowUpForecast {
  ShowUpForecast._();

  /// Default rate used until the organiser has enough history.
  /// Industry data: free events ≈ 72% show-up (28% no-show), paid ≈ 83%.
  static const double defaultFreeRate = 0.72;
  static const double defaultPaidRate = 0.83;
  static const int minHistoryEvents = 2;

  /// [history] is a list of (registered, attended) pairs for past events of
  /// the same category.
  static double showUpRate({
    required List<(int registered, int attended)> history,
    required bool isFree,
  }) {
    final usable = history.where((h) => h.$1 > 0).toList();
    if (usable.length < minHistoryEvents) {
      return isFree ? defaultFreeRate : defaultPaidRate;
    }
    var registered = 0;
    var attended = 0;
    for (final h in usable) {
      registered += h.$1;
      attended += h.$2;
    }
    return (attended / registered).clamp(0.05, 1.0).toDouble();
  }

  static int forecast({
    required int registeredCount,
    required int confirmedCount,
    required double showUpRate,
  }) {
    if (registeredCount <= 0) return 0;
    // Confirmed students are treated as near-certain (95%); the rest follow
    // the historical rate.
    final unconfirmed = (registeredCount - confirmedCount).clamp(0, registeredCount);
    final value = confirmedCount * 0.95 + unconfirmed * showUpRate;
    return value.round().clamp(0, registeredCount).toInt();
  }
}

/// Shared enumerations for UniEvent. Every enum stores a stable `value`
/// string in Firestore so renaming a Dart identifier never breaks data.
library;

enum UserRole {
  student('student', 'Student / Attendee'),
  organiser('organiser', 'Event Organiser'),
  vendor('vendor', 'Vendor'),
  studentAffairs('student_affairs', 'Student Affairs');

  const UserRole(this.value, this.label);
  final String value;
  final String label;

  static UserRole fromValue(String? v) =>
      UserRole.values.firstWhere((r) => r.value == v, orElse: () => student);

  /// Roles a user may choose at public sign-up. Student Affairs accounts are
  /// provisioned by an administrator (see README).
  static List<UserRole> get publicRoles => [student, organiser, vendor];
}

enum ProposalStatus {
  draft('draft', 'Draft'),
  submitted('submitted', 'Submitted'),
  needsChanges('needs_changes', 'Needs Changes'),
  approved('approved', 'Approved'),
  rejected('rejected', 'Rejected');

  const ProposalStatus(this.value, this.label);
  final String value;
  final String label;

  static ProposalStatus fromValue(String? v) => ProposalStatus.values
      .firstWhere((s) => s.value == v, orElse: () => draft);
}

enum EventStatus {
  upcoming('upcoming', 'Upcoming'),
  checkInOpen('check_in_open', 'Check-in open'),
  live('live', 'Live'),
  delayed('delayed', 'Delayed'),
  ended('ended', 'Ended'),
  cancelled('cancelled', 'Cancelled');

  const EventStatus(this.value, this.label);
  final String value;
  final String label;

  static EventStatus fromValue(String? v) =>
      EventStatus.values.firstWhere((s) => s.value == v, orElse: () => upcoming);
}

enum RegistrationStatus {
  registered('registered', 'Registered'),
  waitlisted('waitlisted', 'Waitlisted'),
  attended('attended', 'Attended'),
  cancelled('cancelled', 'Cancelled');

  const RegistrationStatus(this.value, this.label);
  final String value;
  final String label;

  static RegistrationStatus fromValue(String? v) => RegistrationStatus.values
      .firstWhere((s) => s.value == v, orElse: () => registered);
}

enum OrderStatus {
  pending('pending', 'Pending'),
  preparing('preparing', 'Preparing'),
  ready('ready', 'Ready'),
  collected('collected', 'Collected'),
  cancelled('cancelled', 'Cancelled');

  const OrderStatus(this.value, this.label);
  final String value;
  final String label;

  static OrderStatus fromValue(String? v) =>
      OrderStatus.values.firstWhere((s) => s.value == v, orElse: () => pending);

  /// Next status in the fulfilment pipeline, or null if terminal.
  OrderStatus? get next {
    switch (this) {
      case pending:
        return preparing;
      case preparing:
        return ready;
      case ready:
        return collected;
      case collected:
      case cancelled:
        return null;
    }
  }

  bool get isTerminal => this == collected || this == cancelled;
}

enum ApplicationStatus {
  pending('pending', 'Pending'),
  approved('approved', 'Approved'),
  rejected('rejected', 'Rejected');

  const ApplicationStatus(this.value, this.label);
  final String value;
  final String label;

  static ApplicationStatus fromValue(String? v) => ApplicationStatus.values
      .firstWhere((s) => s.value == v, orElse: () => pending);
}

enum StockStatus {
  available('Available'),
  lowStock('Low Stock'),
  soldOut('Sold Out');

  const StockStatus(this.label);
  final String label;
}

enum TaskStatus {
  todo('todo', 'To do'),
  inProgress('in_progress', 'In progress'),
  done('done', 'Done');

  const TaskStatus(this.value, this.label);
  final String value;
  final String label;

  static TaskStatus fromValue(String? v) =>
      TaskStatus.values.firstWhere((s) => s.value == v, orElse: () => todo);
}

enum AnnouncementType {
  venueChange('venue_change', 'Venue change'),
  timeChange('time_change', 'Time change'),
  reminder('reminder', 'Reminder'),
  cancellation('cancellation', 'Cancellation'),
  general('general', 'Announcement');

  const AnnouncementType(this.value, this.label);
  final String value;
  final String label;

  static AnnouncementType fromValue(String? v) => AnnouncementType.values
      .firstWhere((s) => s.value == v, orElse: () => general);
}

/// Event categories used for filters and card accents.
const List<String> kEventCategories = [
  'Cultural',
  'Career',
  'Technical',
  'Creative',
  'Sports',
  'Social',
];

/// Product categories for vendors.
const List<String> kProductCategories = [
  'Food',
  'Beverages',
  'Snacks',
  'Merchandise',
  'Crafts',
  'Services',
  'Other',
];

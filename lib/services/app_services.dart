import 'package:cloud_firestore/cloud_firestore.dart';

import '../repositories/event_repository.dart';
import '../repositories/misc_repositories.dart';
import '../repositories/order_repository.dart';
import '../repositories/product_repository.dart';
import '../repositories/registration_repository.dart';
import '../repositories/user_repository.dart';
import 'auth_service.dart';
import 'integration_services.dart';
import 'notification_service.dart';
import 'offline_checkin_queue.dart';
import 'report_service.dart';
import 'seed_service.dart';
import 'storage_service.dart';

/// Simple composition root. Everything the ViewModels need is created once
/// here and provided at the top of the widget tree, so tests can build an
/// [AppServices] with fakes (FakeFirebaseFirestore, MockFirebaseAuth…).
class AppServices {
  AppServices({
    required this.auth,
    required this.users,
    required this.events,
    required this.registrations,
    required this.products,
    required this.orders,
    required this.proposals,
    required this.vendorApplications,
    required this.tasks,
    required this.budgets,
    required this.announcements,
    required this.feedback,
    required this.storage,
    required this.notifications,
    required this.maps,
    required this.calendar,
    required this.weather,
    required this.payments,
    required this.offlineQueue,
    required this.reports,
    required this.seed,
  });

  factory AppServices.production({FirebaseFirestore? firestore}) {
    final db = firestore ?? FirebaseFirestore.instance;
    final users = UserRepository(firestore: db);
    return AppServices(
      auth: AuthService(firestore: db),
      users: users,
      events: EventRepository(firestore: db),
      registrations: RegistrationRepository(firestore: db),
      products: ProductRepository(firestore: db),
      orders: OrderRepository(firestore: db),
      proposals: ProposalRepository(firestore: db),
      vendorApplications: VendorApplicationRepository(firestore: db),
      tasks: TaskRepository(firestore: db),
      budgets: BudgetRepository(firestore: db),
      announcements: AnnouncementRepository(firestore: db),
      feedback: FeedbackRepository(firestore: db),
      storage: StorageService(),
      notifications: NotificationService(users: users),
      maps: MapsService(),
      calendar: CalendarService(),
      weather: WeatherService(),
      payments: SandboxPaymentService(),
      offlineQueue: OfflineCheckInQueue(),
      reports: ReportService(),
      seed: SeedService(firestore: db),
    );
  }

  final AuthService auth;
  final UserRepository users;
  final EventRepository events;
  final RegistrationRepository registrations;
  final ProductRepository products;
  final OrderRepository orders;
  final ProposalRepository proposals;
  final VendorApplicationRepository vendorApplications;
  final TaskRepository tasks;
  final BudgetRepository budgets;
  final AnnouncementRepository announcements;
  final FeedbackRepository feedback;
  final StorageService storage;
  final NotificationService notifications;
  final MapsService maps;
  final CalendarService calendar;
  final WeatherService weather;
  final SandboxPaymentService payments;
  final OfflineCheckInQueue offlineQueue;
  final ReportService reports;
  final SeedService seed;
}

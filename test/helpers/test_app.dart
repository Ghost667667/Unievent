import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:unievent/models/models.dart';
import 'package:unievent/repositories/event_repository.dart';
import 'package:unievent/repositories/misc_repositories.dart';
import 'package:unievent/repositories/order_repository.dart';
import 'package:unievent/repositories/product_repository.dart';
import 'package:unievent/repositories/registration_repository.dart';
import 'package:unievent/repositories/user_repository.dart';
import 'package:unievent/services/app_services.dart';
import 'package:unievent/services/auth_service.dart';
import 'package:unievent/services/integration_services.dart';
import 'package:unievent/services/notification_service.dart';
import 'package:unievent/services/offline_checkin_queue.dart';
import 'package:unievent/services/report_service.dart';
import 'package:unievent/services/seed_service.dart';
import 'package:unievent/services/storage_service.dart';
import 'package:unievent/theme/app_theme.dart';
import 'package:unievent/viewmodels/auth_viewmodel.dart';

/// Builds an [AppServices] wired to in-memory fakes. No Firebase app needed.
AppServices buildTestServices({
  FakeFirebaseFirestore? firestore,
  MockFirebaseAuth? auth,
}) {
  GoogleFonts.config.allowRuntimeFetching = false;
  final db = firestore ?? FakeFirebaseFirestore();
  final users = UserRepository(firestore: db);
  return AppServices(
    auth: AuthService(
      auth: auth ?? MockFirebaseAuth(),
      firestore: db,
      googleSignIn: GoogleSignIn(),
    ),
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
    notifications: NotificationService(users: users, enabled: false),
    maps: MapsService(),
    calendar: CalendarService(),
    weather: WeatherService(),
    payments: SandboxPaymentService(),
    offlineQueue: OfflineCheckInQueue(),
    reports: ReportService(),
    seed: SeedService(firestore: db),
  );
}

/// Seeds a signed-in user with a profile document and returns the services.
Future<(AppServices, MockFirebaseAuth)> signedInServices(AppUser profile) async {
  final db = FakeFirebaseFirestore();
  final mockUser = MockUser(
    uid: profile.uid,
    email: profile.email,
    displayName: profile.fullName,
    isEmailVerified: true,
  );
  final auth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);
  await db.collection('users').doc(profile.uid).set(profile.toMap());
  return (buildTestServices(firestore: db, auth: auth), auth);
}

/// Wraps [child] in the providers every screen expects.
Widget wrapWithProviders(AppServices services, Widget child, {AuthViewModel? auth}) {
  GoogleFonts.config.allowRuntimeFetching = false;
  final authVm = auth ?? AuthViewModel(services);
  return MultiProvider(
    providers: [
      Provider<AppServices>.value(value: services),
      ChangeNotifierProvider<AuthViewModel>.value(value: authVm),
    ],
    child: MaterialApp(theme: AppTheme.light(), home: child),
  );
}

AppUser testStudent() => const AppUser(
      uid: 'stu1',
      email: 'yunis@mail.apu.edu.my',
      fullName: 'Yunis Abdulrahman',
      role: UserRole.student,
      studentId: 'TP088620',
      programme: 'BSc (Hons) Computer Science',
      interests: ['Technical', 'Cultural'],
    );

AppUser testOrganiser() => const AppUser(
      uid: 'org1',
      email: 'leila@mail.apu.edu.my',
      fullName: 'Leila Awino',
      role: UserRole.organiser,
      organisationName: 'APU Student Council',
      position: 'President',
    );

AppUser testVendor() => const AppUser(
      uid: 'ven1',
      email: 'massa@mail.apu.edu.my',
      fullName: 'Massa Coulibaly',
      role: UserRole.vendor,
      businessName: 'Massa\'s Kitchen',
      contactNumber: '+60123456789',
      productCategory: 'Food',
      isStudentVendor: true,
    );

Event testEvent({String id = 'ev1', int capacity = 50, int registered = 0}) => Event(
      id: id,
      title: 'Africa Day Cultural Night',
      description: 'Music, dance and food.',
      category: 'Cultural',
      organiserId: 'org1',
      organiserName: 'APU Student Council',
      startTime: DateTime.now().add(const Duration(days: 5)),
      endTime: DateTime.now().add(const Duration(days: 5, hours: 3)),
      venue: 'APU Auditorium 1',
      capacity: capacity,
      registeredCount: registered,
    );

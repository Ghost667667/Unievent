import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/enums.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../views/auth/login_page.dart';
import '../views/auth/register_page.dart';
import '../views/auth/welcome_page.dart';
import '../views/organiser/organiser_shell.dart';
import '../views/organiser/pages/announcements_page.dart';
import '../views/organiser/pages/budget_page.dart';
import '../views/organiser/pages/checkin_page.dart';
import '../views/organiser/pages/event_form_page.dart';
import '../views/organiser/pages/event_manage_page.dart';
import '../views/organiser/pages/event_report_page.dart';
import '../views/organiser/pages/proposal_form_page.dart';
import '../views/organiser/pages/registrations_page.dart';
import '../views/organiser/pages/student_affairs_page.dart';
import '../views/organiser/pages/vendor_review_page.dart';
import '../views/shared/notifications_page.dart';
import '../views/shared/splash_page.dart';
import '../views/student/pages/event_details_page.dart';
import '../views/student/pages/feedback_page.dart';
import '../views/student/pages/ticket_page.dart';
import '../views/student/pages/vendor_menu_page.dart';
import '../views/student/student_shell.dart';
import '../views/vendor/pages/product_form_page.dart';
import '../views/vendor/pages/sales_analytics_page.dart';
import '../views/vendor/pages/vendor_event_details_page.dart';
import '../views/vendor/vendor_shell.dart';

/// Route names used across the app so navigation never relies on raw strings
/// in widgets.
class Routes {
  Routes._();
  static const splash = '/';
  static const welcome = '/welcome';
  static const login = '/login';
  static const register = '/register';
  static const completeProfile = '/complete-profile';

  // Student
  static const studentHome = '/student/home';
  static const studentExplore = '/student/explore';
  static const studentMyEvents = '/student/my-events';
  static const studentOrders = '/student/orders';
  static const studentProfile = '/student/profile';
  static String eventDetails(String id) => '/student/event/$id';
  static String ticket(String regId) => '/student/ticket/$regId';
  static String feedback(String eventId) => '/student/feedback/$eventId';
  static String vendorMenu(String eventId, String vendorId) =>
      '/student/event/$eventId/vendor/$vendorId';

  // Organiser
  static const organiserHome = '/organiser/home';
  static const organiserEvents = '/organiser/events';
  static const organiserCheckin = '/organiser/checkin';
  static const organiserVendors = '/organiser/vendors';
  static const organiserProfile = '/organiser/profile';
  static const proposalNew = '/organiser/proposal/new';
  static String proposalEdit(String id) => '/organiser/proposal/$id';
  static String eventNew({String? proposalId}) =>
      '/organiser/event/new${proposalId == null ? '' : '?proposalId=$proposalId'}';
  static String eventManage(String id) => '/organiser/event/$id';
  static String eventEdit(String id) => '/organiser/event/$id/edit';
  static String eventRegistrations(String id) => '/organiser/event/$id/registrations';
  static String eventAnnouncements(String id) => '/organiser/event/$id/announcements';
  static String eventBudget(String id) => '/organiser/event/$id/budget';
  static String eventReport(String id) => '/organiser/event/$id/report';
  static String eventCheckin(String id) => '/organiser/checkin/$id';
  static String vendorReview(String applicationId) =>
      '/organiser/vendors/$applicationId';
  static const studentAffairs = '/organiser/student-affairs';

  // Vendor
  static const vendorHome = '/vendor/home';
  static const vendorProducts = '/vendor/products';
  static const vendorOrders = '/vendor/orders';
  static const vendorEvents = '/vendor/events';
  static const vendorProfile = '/vendor/profile';
  static const productNew = '/vendor/product/new';
  static String productEdit(String id) => '/vendor/product/$id';
  static String vendorEventDetails(String id) => '/vendor/event/$id';
  static const vendorAnalytics = '/vendor/analytics';

  static const notifications = '/notifications';

  static String homeFor(UserRole role) {
    switch (role) {
      case UserRole.student:
        return studentHome;
      case UserRole.organiser:
      case UserRole.studentAffairs:
        return organiserHome;
      case UserRole.vendor:
        return vendorHome;
    }
  }
}

GoRouter buildRouter(AuthViewModel auth) {
  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: auth,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final isAuthRoute = loc == Routes.welcome ||
          loc == Routes.login ||
          loc == Routes.register ||
          loc == Routes.completeProfile;

      switch (auth.status) {
        case AuthStatus.loading:
          return loc == Routes.splash ? null : Routes.splash;
        case AuthStatus.signedOut:
          return isAuthRoute && loc != Routes.completeProfile
              ? null
              : Routes.welcome;
        case AuthStatus.needsRole:
          return loc == Routes.completeProfile ? null : Routes.completeProfile;
        case AuthStatus.signedIn:
          final role = auth.user!.role;
          final home = Routes.homeFor(role);
          if (isAuthRoute || loc == Routes.splash) return home;
          // Keep users inside their own module.
          final prefix = '/${home.split('/')[1]}';
          if (!loc.startsWith(prefix) && loc != Routes.notifications) {
            return home;
          }
          return null;
      }
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, __) => const SplashPage()),
      GoRoute(path: Routes.welcome, builder: (_, __) => const WelcomePage()),
      GoRoute(path: Routes.login, builder: (_, __) => const LoginPage()),
      GoRoute(path: Routes.register, builder: (_, __) => const RegisterPage()),
      GoRoute(
        path: Routes.completeProfile,
        builder: (_, __) => const RegisterPage(googleCompletion: true),
      ),
      GoRoute(
        path: Routes.notifications,
        builder: (_, __) => const NotificationsPage(),
      ),

      // ───────────── Student ─────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => StudentShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.studentHome,
                builder: (_, __) => const StudentHomeTab(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.studentExplore,
                builder: (_, __) => const StudentExploreTab(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.studentMyEvents,
                builder: (_, __) => const StudentMyEventsTab(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.studentOrders,
                builder: (_, __) => const StudentOrdersTab(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.studentProfile,
                builder: (_, __) => const StudentProfileTab(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/student/event/:id',
        builder: (_, s) => EventDetailsPage(eventId: s.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'vendor/:vendorId',
            builder: (_, s) => VendorMenuPage(
              eventId: s.pathParameters['id']!,
              vendorId: s.pathParameters['vendorId']!,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/student/ticket/:regId',
        builder: (_, s) => TicketPage(registrationId: s.pathParameters['regId']!),
      ),
      GoRoute(
        path: '/student/feedback/:eventId',
        builder: (_, s) => FeedbackPage(eventId: s.pathParameters['eventId']!),
      ),

      // ───────────── Organiser ─────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => OrganiserShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.organiserHome,
                builder: (_, __) => const OrganiserHomeTab(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.organiserEvents,
                builder: (_, __) => const OrganiserEventsTab(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.organiserCheckin,
                builder: (_, __) => const OrganiserCheckinTab(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.organiserVendors,
                builder: (_, __) => const OrganiserVendorsTab(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.organiserProfile,
                builder: (_, __) => const OrganiserProfileTab(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: Routes.proposalNew,
        builder: (_, __) => const ProposalFormPage(),
      ),
      GoRoute(
        path: '/organiser/proposal/:id',
        builder: (_, s) => ProposalFormPage(proposalId: s.pathParameters['id']),
      ),
      GoRoute(
        path: '/organiser/event/new',
        builder: (_, s) =>
            EventFormPage(proposalId: s.uri.queryParameters['proposalId']),
      ),
      GoRoute(
        path: '/organiser/event/:id',
        builder: (_, s) => EventManagePage(eventId: s.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (_, s) => EventFormPage(eventId: s.pathParameters['id']),
          ),
          GoRoute(
            path: 'registrations',
            builder: (_, s) =>
                RegistrationsPage(eventId: s.pathParameters['id']!),
          ),
          GoRoute(
            path: 'announcements',
            builder: (_, s) =>
                AnnouncementsPage(eventId: s.pathParameters['id']!),
          ),
          GoRoute(
            path: 'budget',
            builder: (_, s) => BudgetPage(eventId: s.pathParameters['id']!),
          ),
          GoRoute(
            path: 'report',
            builder: (_, s) => EventReportPage(eventId: s.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: '/organiser/checkin/:eventId',
        builder: (_, s) => CheckinPage(eventId: s.pathParameters['eventId']!),
      ),
      GoRoute(
        path: '/organiser/vendors/:applicationId',
        builder: (_, s) =>
            VendorReviewPage(applicationId: s.pathParameters['applicationId']!),
      ),
      GoRoute(
        path: Routes.studentAffairs,
        builder: (_, __) => const StudentAffairsPage(),
      ),

      // ───────────── Vendor ─────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => VendorShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.vendorHome,
                builder: (_, __) => const VendorHomeTab(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.vendorProducts,
                builder: (_, __) => const VendorProductsTab(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.vendorOrders,
                builder: (_, __) => const VendorOrdersTab(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.vendorEvents,
                builder: (_, __) => const VendorEventsTab(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.vendorProfile,
                builder: (_, __) => const VendorProfileTab(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: Routes.productNew,
        builder: (_, __) => const ProductFormPage(),
      ),
      GoRoute(
        path: '/vendor/product/:id',
        builder: (_, s) => ProductFormPage(productId: s.pathParameters['id']),
      ),
      GoRoute(
        path: '/vendor/event/:id',
        builder: (_, s) =>
            VendorEventDetailsPage(eventId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.vendorAnalytics,
        builder: (_, __) => const SalesAnalyticsPage(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.uri}')),
    ),
  );
}

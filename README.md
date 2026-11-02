# UniEvent

**Every campus event, one tap away.** · *Discover • Connect • Celebrate*

A cross-platform Flutter + Firebase application that connects **students**, **event organisers** and **vendors** around the whole campus-event lifecycle: proposal approval → promotion & discovery → registration & waitlists → Seat Rescue → QR check-in (offline-capable) → vendor pre-orders → feedback → post-event PDF report.

Built for CT124-3-2-MAE Mobile App Engineering (APU) from the *UniEvent System Proposal* and *Generative Research* documents.

---

## Contents

1. [Features by role](#features-by-role)
2. [Architecture](#architecture)
3. [Project structure](#project-structure)
4. [Firebase setup](#firebase-setup)
5. [Third-party integrations & configuration](#third-party-integrations--configuration)
6. [Running the app](#running-the-app)
7. [Sample data & demo accounts](#sample-data--demo-accounts)
8. [Firestore data model](#firestore-data-model)
9. [Security rules](#security-rules)
10. [Cloud Functions](#cloud-functions)
11. [Testing](#testing)
12. [Known limitations](#known-limitations)

---

## Features by role

### Student / Attendee
| Area | What works |
|---|---|
| Home | Gradient greeting header, notification bell with unread badge, search bar, category chips, **next registered event** card (links to ticket), **recommended** feed (interests + followed organisers), upcoming feed |
| Explore | Search + filters (category, date, venue, free/paid, organiser), save events, follow clubs/organisers |
| Event details | Poster, key facts, live status banner, organiser row with Follow, four tabs — **About** (description, requirements, speakers, Open-Meteo weather), **Schedule**, **Vendors** (menus, prices, low-stock/sold-out tags, booth), **Updates** (announcements) — persistent Register / Join Waitlist / View Ticket bar |
| Registration | One-tap with auto-filled profile, transactional capacity check, waitlist with position, confirmation dialog, cancel → automatic waitlist promotion |
| My Events | Upcoming / Waitlisted / Attended / Cancelled tabs, each with ticket access and "Rate event" |
| Digital ticket | Unique QR (`UNIEVENT\|eventId\|registrationId\|code`), ticket number, Add to Google Calendar, Open Google Maps, Confirm Attendance (Seat Rescue), Cancel Registration |
| Orders | Vendor menu → cart → **sandbox** payment → order tracking Pending → Preparing → Ready → Collected; cancel while Pending |
| Feedback | 5-star event rating, optional review, per-vendor ratings |
| Profile | Photo, name, TP number, programme, interests, password, notification & reminder preferences, logout |

### Event Organiser
| Area | What works |
|---|---|
| Home | Current-event header, **Registered / Confirmed / Forecast / Waitlist** stat cards, quick actions (Create Event, Scan QR, Send Announcement, View Report), proposals list, crew task board |
| Proposals | Draft → Submitted → Needs Changes → Approved; create event only from an approved proposal |
| Student Affairs dashboard | Simulated approval queue (role `student_affairs`) with Approve / Needs changes / Reject + comment → organiser notified |
| Event management | Create/edit event (poster upload, capacity, price, deadline, walk-ins, speakers, agenda, vendor settings), live status (Check-in open / Live / Delayed / Ended), cancel with notifications |
| Registrations | Registered / Confirmed / Waitlist / Attended / Cancelled, search, seats left, walk-in toggle, remove attendee (promotes waitlist) |
| Seat Rescue | Send confirmation requests (~24h before) and release unconfirmed seats (6h before) — manual buttons + scheduled Cloud Function |
| Show-Up Forecast | Historical show-up rate of same-category past events (defaults 72 % free / 83 % paid until history exists) |
| QR check-in | `mobile_scanner` camera, success / duplicate / invalid / wrong-event feedback, manual search by name or TP, walk-in registration, **offline queue** with sync status banner and server-side reconciliation |
| Announcements | Venue change / time change / reminder / cancellation / general with templates → in-app + push to students and vendors |
| Vendor management | Pending / Approved / Rejected, review vendor profile & menu, assign booth, arrival time, parking, setup instructions |
| Budget | Planned vs actual lines by category, receipt photo upload, variance, bar chart |
| Report | Attendance donut, arrivals-over-time chart, no-show %, rating distribution, budget summary, event performance, comparison with previous events, **Export as PDF** |

### Vendor
| Area | What works |
|---|---|
| Home | **Total Sales (RM) / Total Orders / Events Participated / Available Products**, quick actions, low-stock alert, upcoming approved events, recent orders |
| Products | Add/edit/delete with photo, RM price, quantity, category, low-stock threshold; hide/show on menu; stock status Available (green) / Low Stock (orange) / Sold Out (red) |
| Inventory | Totals, low-stock & sold-out counts, ± quick quantity updates; stock deducted/restored by orders in **Firestore transactions** (never negative) |
| Orders | Tabs per status; Mark Preparing / Ready / Collected; cancel with stock restore; student notified when Ready |
| Events | Browse events accepting vendors (filter by category/date/search), requirements, expected attendance, facilities, fee, apply, track Pending / Approved / Rejected, booth & logistics, "I've arrived" check-in |
| Analytics | 7-day sales line chart, bestsellers, cancelled orders, remaining inventory, per-event performance |
| Profile | Business info & image, contact, category, notifications, security, sample data, logout |

---

## Architecture

**MVVM with Provider**, as specified in the proposal.

```
View (Flutter widgets)  ──watch──▶  ViewModel (ChangeNotifier)
                                        │ calls
                                        ▼
                               Repository (per collection)
                                        │ uses
                                        ▼
                     Services (Auth, Storage, FCM, Maps, Calendar,
                      Open-Meteo, Sandbox payments, Offline queue, PDF)
                                        │
                                        ▼
                                  Firebase / HTTP
```

* **Models** are immutable, `Equatable`, with `fromDoc`/`toMap`. Enums store a stable string `value`.
* **Core** (`lib/core`) holds pure business rules — capacity/waitlist decisions, Seat Rescue timing, Show-Up Forecast, ticket codec, order state machine, cart validation — with no Firebase dependency so they are unit-tested directly.
* **Repositories** own every Firestore read/write. Anything that touches capacity, waitlist, attendance or stock runs in a **transaction** (`runTransaction`) so two phones can't double-book a seat, double-scan a ticket or oversell an item.
* **AppServices** is the composition root; tests inject `FakeFirebaseFirestore` + `MockFirebaseAuth`.
* **Navigation** uses `go_router` with a role-aware redirect: unauthenticated → Welcome; Google user without profile → Complete Profile; otherwise `/student`, `/organiser` or `/vendor` shells (each a `StatefulShellRoute` with a 5-item bottom bar, auto-switching to a `NavigationRail` on tablets).

---

## Project structure

```
lib/
├── main.dart                     # Firebase init, providers, MaterialApp.router
├── firebase_options.dart         # PLACEHOLDER – replace via flutterfire configure
├── core/                         # pure business rules (tested)
│   ├── registration_rules.dart   # capacity, waitlist, Seat Rescue, forecast
│   ├── order_rules.dart          # order state machine, cart & stock rules
│   ├── ticket_codec.dart         # QR payload encode/decode
│   ├── validators.dart, formatters.dart
├── models/                       # AppUser, Event, Registration, Proposal, Product,
│                                 # VendorOrder, VendorApplication, CrewTask, BudgetLine,
│                                 # Announcement, EventFeedback, AppNotification, enums
├── repositories/                 # user, event, registration, product, order, misc
├── services/                     # auth, storage, notifications (FCM), integrations
│                                 # (Maps, Calendar, Open-Meteo, sandbox payments),
│                                 # offline check-in queue, PDF report, seed data
├── viewmodels/
│   ├── auth_viewmodel.dart
│   ├── student/ organiser/ vendor/
├── views/
│   ├── auth/      welcome, login, register (role dropdown)
│   ├── shared/    splash, role shell, notifications inbox, profile
│   ├── student/   shell + tabs + pages (details, ticket, vendor menu, feedback)
│   ├── organiser/ shell + tabs + pages (proposal, event form/manage, registrations,
│   │              check-in, announcements, budget, report, vendor review, Student Affairs)
│   └── vendor/    shell + tabs + pages (product form, event details, analytics)
├── widgets/                      # logo (CustomPaint ticket-with-star), cards, chips…
├── theme/                        # palette + Material 3 theme (Poppins)
└── navigation/app_router.dart
test/
├── unit/        registration rules, ticket & order rules, repositories (fake Firestore)
├── widget/      auth screens, role navigation, event card, student flow
└── helpers/     test AppServices with fakes
integration_test/app_test.dart     # end-to-end sign-up → register → ticket
functions/                         # Cloud Functions (TypeScript)
firestore.rules · storage.rules · firestore.indexes.json · firebase.json
```

---

## Firebase setup

> The repo ships **without** platform folders and with a placeholder `firebase_options.dart`. Follow these steps once.

### 1. Prerequisites
* Flutter 3.24+ (`flutter --version`), Dart 3.5+
* Node 20 (for Cloud Functions)
* A Firebase project — <https://console.firebase.google.com>

### 2. Generate platform folders
```bash
cd unievent
flutter create . --org com.unievent --platforms=android,ios
flutter pub get
```

### 3. Connect Firebase
```bash
dart pub global activate flutterfire_cli
flutterfire configure            # select your project, Android + iOS
```
This overwrites `lib/firebase_options.dart` and drops `google-services.json` / `GoogleService-Info.plist` into place.

### 4. Enable products in the Firebase console
| Product | Setting |
|---|---|
| **Authentication** | Sign-in methods: **Email/Password** and **Google** |
| **Cloud Firestore** | Create database (production mode), region `asia-southeast1` recommended |
| **Storage** | Create default bucket |
| **Cloud Messaging** | Enabled by default; for iOS upload your APNs key |

### 5. Deploy rules, indexes and functions
```bash
npm i -g firebase-tools
firebase login
firebase use <your-project-id>
firebase deploy --only firestore:rules,firestore:indexes,storage
cd functions && npm install && npm run build && cd ..
firebase deploy --only functions
```

### 6. Android specifics
* `android/app/build.gradle`: `minSdkVersion 23`, `multiDexEnabled true`.
* Add to `android/app/src/main/AndroidManifest.xml` inside `<application>`:
  ```xml
  <meta-data android:name="com.google.android.geo.API_KEY" android:value="YOUR_MAPS_KEY"/>
  <meta-data android:name="com.google.firebase.messaging.default_notification_channel_id" android:value="unievent_default"/>
  ```
  and `<uses-permission android:name="android.permission.CAMERA"/>` for QR scanning.
* Google Sign-In needs your **SHA-1/SHA-256** in Firebase → Project settings → Android app (`cd android && ./gradlew signingReport`).

### 7. iOS specifics
`ios/Runner/Info.plist`:
```xml
<key>NSCameraUsageDescription</key><string>Scan QR tickets at check-in</string>
<key>NSPhotoLibraryUsageDescription</key><string>Upload posters, product photos and receipts</string>
<key>CFBundleURLTypes</key> <!-- REVERSED_CLIENT_ID from GoogleService-Info.plist for Google Sign-In -->
```
Podfile platform `13.0` or higher. Enable *Push Notifications* and *Background Modes → Remote notifications* capabilities.

---

## Third-party integrations & configuration

| Integration | Package | Where | Credentials |
|---|---|---|---|
| Google Maps directions | `url_launcher` (Maps URL scheme) + `google_maps_flutter` dependency | `MapsService.openDirections` — ticket & event details | Maps SDK key only needed if you embed a `GoogleMap` widget; the directions deep link works without a key |
| Google Calendar | `url_launcher` to `calendar.google.com/calendar/render?action=TEMPLATE` | `CalendarService.addToGoogleCalendar` | None. To write via the Calendar API instead, add `googleapis` + the `calendar.events` scope to `GoogleSignIn(scopes: …)` and swap the service body |
| Open-Meteo weather | `http` | `WeatherService.forecastFor` (About tab, up to 16 days ahead) | None (free API) |
| QR tickets | `qr_flutter` | `TicketPage` | — |
| QR scanning | `mobile_scanner` | `CheckinPage` | Camera permission |
| Push notifications | `firebase_messaging` + Cloud Function `onNotificationCreated` | `NotificationService` | FCM enabled; APNs key for iOS |
| PDF report | `pdf`, `printing` | `ReportService` | — |
| Payments | **Sandbox only** — `SandboxPaymentService` | Vendor menu checkout | No real money. Any test card digits succeed; `0000` simulates a decline. Swap in Stripe/Billplz behind the same `pay()` signature to go live |

---

## Running the app

```bash
flutter pub get
flutter run                      # Android emulator / iOS simulator / device
```

Recommended demo flow (three accounts, three devices or one device logging in/out):

1. **Organiser** → Profile → *Load sample data* (6 events incl. 2 past ones, a proposal, budget, tasks).
2. **Vendor** → Profile → *Load sample products* → Events → apply to *Africa Day Cultural Night*.
3. **Organiser** → Vendors → approve, assign booth `B-04`.
4. **Student** → Home → Register for Africa Day → My Events → ticket → Vendors tab → pre-order → sandbox pay.
5. **Vendor** → Orders → Mark Preparing → Ready (student is notified).
6. **Organiser** → Check-in → scan the student's QR (or manual search) → duplicate scan shows a warning. Toggle airplane mode to see the offline queue and sync banner.
7. **Organiser** → event → Seat Rescue → Send requests / Release seats; → Report → Export PDF.

---

## Sample data & demo accounts

* Sample data is written by `SeedService` (organiser: events/proposals/budget/tasks/announcement; vendor: products) from the Profile tab. Documents use deterministic ids so re-running overwrites rather than duplicates.
* **Student Affairs account** — not available through public sign-up (as required). Create one:
  1. Register normally as an *Event Organiser*.
  2. In Firebase console → Firestore → `users/{uid}` set `role` to `student_affairs`.
  3. Sign out/in. The Home and Profile tabs now show the **Student Affairs approval dashboard**.
  The security rules only allow `student_affairs` to change proposal status.

---

## Firestore data model

| Collection | Doc id | Key fields | Written by |
|---|---|---|---|
| `users` | `uid` | `role`, `fullName`, `email`, `studentId`, `programme`, `interests[]`, `savedEventIds[]`, `followingOrganiserIds[]`, `organisationName`, `businessName`, `productCategory`, `isStudentVendor`, `fcmTokens[]`, notification prefs | owner |
| `users/{uid}/notifications` | auto | `title`, `body`, `eventId`, `type`, `read` | any signed-in user (→ FCM via function) |
| `proposals` | auto | `organiserId`, `eventTitle`, `status` (draft/submitted/needs_changes/approved/rejected), `reviewerComment`, `eventId` | organiser, Student Affairs |
| `events` | auto / `sample_*` | `title`, `category`, `startTime`, `endTime`, `venue`, `latitude/longitude`, `posterUrl`, `capacity`, `registeredCount`, `confirmedCount`, `waitlistCount`, `attendedCount`, `price`, `status`, `registrationDeadline`, `allowWalkIns`, vendor settings, `speakers[]`, `schedule[]`, Seat Rescue stamps | organiser; counters via transactions |
| `registrations` | `${eventId}_${studentId}` | `status` (registered/waitlisted/attended/cancelled), `ticketCode`, `confirmed`, `confirmationRequestedAt`, `waitlistPosition`, `checkedInAt`, `checkedInBy`, `isWalkIn`, denormalised event fields | student, organiser crew |
| `products` | auto | `vendorId`, `name`, `price`, `quantity`, `lowStockThreshold`, `soldCount`, `imageUrl`, `isActive` | vendor; stock via transactions |
| `orders` | auto | `orderNumber`, `eventId`, `vendorId`, `studentId`, `items[]`, `total`, `status`, `paymentReference`, `boothNumber` | student creates, vendor updates |
| `vendorApplications` | `${eventId}_${vendorId}` | `status`, `boothNumber`, `arrivalTime`, `parkingDetails`, `setupInstructions`, `checkedInAt` | vendor, organiser |
| `tasks` | auto | `eventId`, `title`, `owner`, `status` | organiser |
| `budgets` | auto | `eventId`, `category`, `planned`, `actual`, `receiptUrl` | organiser |
| `announcements` | auto | `eventId`, `type`, `title`, `body`, `notifyStudents`, `notifyVendors` | organiser |
| `feedback` | `${eventId}_${studentId}` | `eventRating`, `comment`, `vendorRatings{}` | student |

Composite indexes are declared in `firestore.indexes.json`.

---

## Security rules

`firestore.rules` implements server-side role-based permissions:

* Roles are read from `users/{uid}.role`; a user can never change their own role, and public sign-up is limited to `student | organiser | vendor`.
* Organisers can only modify **their own** events/proposals/tasks/budgets; only `student_affairs` can set proposal status.
* Students can create exactly one registration per event (doc id enforced), may only cancel/confirm their own, and may only decrement/increment counters on `events` and `products` through the fields transactions touch.
* Vendors own their products and applications; order status changes are limited to the vendor (forward) and the student (cancel while pending).
* `storage.rules` restricts uploads to images < 8 MB in owner-scoped folders.

---

## Cloud Functions

`functions/src/index.ts` (Node 20, Firebase Functions v2):

| Function | Trigger | Purpose |
|---|---|---|
| `onNotificationCreated` | Firestore create `users/{uid}/notifications/{id}` | Sends FCM multicast to the user's `fcmTokens`, prunes dead tokens |
| `seatRescueScheduler` | every 30 min | Sends confirmation requests `seatRescueHoursBefore` (24h) before start; releases unconfirmed seats `seatRescueDeadlineHours` (6h) before and promotes the waitlist |
| `eventReminders` | every 30 min | 1-day and 1-hour reminders honouring each student's reminder preferences |
| `onRegistrationCancelled` | Firestore update `registrations/{id}` | Safety-net waitlist promotion if a cancellation bypassed the client transaction |
| `markEndedEvents` | hourly | Sets `status = ended` after `endTime` and prompts attendees for feedback |

The app also performs Seat Rescue and waitlist promotion client-side (organiser buttons / cancel transaction) so the demo works before functions are deployed.

---

## Testing

```bash
flutter test                              # unit + widget tests
flutter test integration_test/app_test.dart   # end-to-end on a connected device/emulator
```

| Suite | Covers |
|---|---|
| `test/unit/registration_rules_test.dart` | register/waitlist decision, seats to promote, Seat Rescue timing, no-show %, Show-Up Forecast |
| `test/unit/ticket_and_order_rules_test.dart` | QR codec (round-trip, tamper/foreign rejection), order status machine, student cancel rule, stock status, cart validation, non-negative stock, validators |
| `test/unit/repositories_test.dart` (FakeFirebaseFirestore) | capacity limits, waitlist promotion on cancel, duplicate registration, closed events, unique tickets, **QR validation + duplicate check-in prevention**, wrong event, walk-ins, Seat Rescue release, order placement deducting stock transactionally, over-sell rejection, cancel restores stock, status pipeline |
| `test/widget/auth_widgets_test.dart` | Welcome, login validation & error, role dropdown reveals fields, role-based navigation to each dashboard, EventCard Register / Join Waitlist / Registered |
| `test/widget/student_flow_test.dart` | Event details → register → ticket; full event → waitlist; ticket actions & confirm attendance |
| `integration_test/app_test.dart` | Sign-up → dashboard → register → My Events |

Firebase permissions are enforced by `firestore.rules`; to test them run the emulator (`firebase emulators:start`) and use `@firebase/rules-unit-testing`, or exercise the app against the emulator with `FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080)`.

---

## Known limitations

* Payments are simulated (sandbox) by design — no gateway is integrated.
* Student Affairs approval is simulated inside UniEvent; it does not connect to APU systems.
* The Show-Up Forecast relies on history; it uses industry defaults until an organiser has ≥2 ended events in a category.
* Push notifications depend on device settings and on deploying the Cloud Functions; in-app notifications always work.
* `firebase_options.dart` is a placeholder — the app will not start until `flutterfire configure` has been run.

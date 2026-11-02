import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/app_services.dart';
import '../services/auth_service.dart';

enum AuthStatus { loading, signedOut, needsRole, signedIn }

/// Holds the signed-in user and their Firestore profile. The router listens
/// to this to redirect between Welcome, Login and the role dashboards.
class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this._services) {
    _authSub = _services.auth.authStateChanges.listen(_onAuthChanged);
  }

  final AppServices _services;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<AppUser?>? _profileSub;

  AuthStatus _status = AuthStatus.loading;
  AppUser? _user;
  User? _firebaseUser;
  bool _busy = false;
  String? _error;
  bool _rememberMe = true;

  /// True while register()/completeGoogleProfile() is writing the profile so
  /// the auth-state listener doesn't briefly flip to [AuthStatus.needsRole].
  bool _creatingProfile = false;

  AuthStatus get status => _status;
  AppUser? get user => _user;
  User? get firebaseUser => _firebaseUser;
  bool get busy => _busy;
  String? get error => _error;
  bool get rememberMe => _rememberMe;
  bool get isSignedIn => _status == AuthStatus.signedIn && _user != null;
  UserRole? get role => _user?.role;

  set rememberMe(bool v) {
    _rememberMe = v;
    notifyListeners();
  }

  Future<void> _onAuthChanged(User? fbUser) async {
    _firebaseUser = fbUser;
    await _profileSub?.cancel();
    if (fbUser == null) {
      _user = null;
      _status = AuthStatus.signedOut;
      notifyListeners();
      return;
    }
    final profile = await _services.auth.fetchProfile(fbUser.uid);
    if (profile == null) {
      if (_creatingProfile) return; // register() will apply the profile.
      _status = AuthStatus.needsRole;
      notifyListeners();
      return;
    }
    _applyProfile(profile);
    await _services.notifications.registerToken(fbUser.uid);
  }

  /// Sets the signed-in user and keeps the profile document live so saved
  /// events, follows, interests and settings update everywhere instantly.
  void _applyProfile(AppUser profile) {
    _user = profile;
    _status = AuthStatus.signedIn;
    _profileSub?.cancel();
    _profileSub = _services.users.watch(profile.uid).listen((p) {
      if (p != null) {
        _user = p;
        notifyListeners();
      }
    });
    notifyListeners();
  }

  Future<bool> signIn(String email, String password) async {
    return _run(() async {
      await _services.auth.signInWithEmail(email, password);
      // _onAuthChanged completes the profile load.
    });
  }

  Future<bool> register({
    required String email,
    required String password,
    required AppUser template,
  }) async {
    _creatingProfile = true;
    try {
      return await _run(() async {
        final profile = await _services.auth.register(
          email: email,
          password: password,
          profileTemplate: template,
        );
        _applyProfile(profile);
        await _services.notifications.registerToken(profile.uid);
      });
    } finally {
      _creatingProfile = false;
    }
  }

  /// Returns true when a profile already exists (go to dashboard) and false
  /// when the Google user still needs to pick a role.
  Future<bool?> signInWithGoogle() async {
    bool? hasProfile;
    final ok = await _run(() async {
      final result = await _services.auth.signInWithGoogle();
      hasProfile = result.profile != null;
      if (result.profile != null) _applyProfile(result.profile!);
    });
    return ok ? hasProfile : null;
  }

  /// Finishes a Google sign-up by saving the chosen role profile.
  Future<bool> completeGoogleProfile(AppUser template) async {
    final fb = _firebaseUser;
    if (fb == null) return false;
    return _run(() async {
      final profile = AppUser(
        uid: fb.uid,
        email: fb.email ?? template.email,
        fullName: template.fullName.isNotEmpty
            ? template.fullName
            : (fb.displayName ?? ''),
        role: template.role,
        photoUrl: fb.photoURL,
        studentId: template.studentId,
        programme: template.programme,
        interests: template.interests,
        organisationName: template.organisationName,
        position: template.position,
        businessName: template.businessName,
        contactNumber: template.contactNumber,
        productCategory: template.productCategory,
        isStudentVendor: template.isStudentVendor,
        eligibilityNotes: template.eligibilityNotes,
      );
      await _services.auth.completeGoogleProfile(profile);
      _applyProfile(profile);
      await _services.notifications.registerToken(profile.uid);
    });
  }

  Future<bool> sendPasswordReset(String email) =>
      _run(() => _services.auth.sendPasswordReset(email));

  Future<bool> changePassword(String current, String next) =>
      _run(() => _services.auth.changePassword(current, next));

  Future<void> signOut() async {
    final uid = _firebaseUser?.uid;
    if (uid != null) await _services.notifications.unregisterToken(uid);
    await _services.auth.signOut();
  }

  Future<bool> _run(Future<void> Function() action) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = 'Something went wrong. Please try again.';
      debugPrint('Auth error: $e');
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }
}

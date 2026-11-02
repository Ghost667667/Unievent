import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/models.dart';

/// Thrown with a user-friendly message for the UI to show.
class AuthException implements Exception {
  AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Wraps Firebase Authentication and the `users` collection.
class AuthService {
  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance,
        _google = googleSignIn ?? GoogleSignIn(scopes: const ['email']);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final GoogleSignIn _google;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  Future<AppUser?> fetchProfile(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromDoc(doc);
  }

  Stream<AppUser?> watchProfile(String uid) => _users
      .doc(uid)
      .snapshots()
      .map((d) => d.exists ? AppUser.fromDoc(d) : null);

  Future<AppUser> signInWithEmail(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final profile = await fetchProfile(cred.user!.uid);
      if (profile == null) {
        throw AuthException(
          'Your account has no profile yet. Please create an account.',
        );
      }
      return profile;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_message(e));
    }
  }

  /// Creates the auth user, then the profile document with the chosen role.
  Future<AppUser> register({
    required String email,
    required String password,
    required AppUser profileTemplate,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = cred.user!.uid;
      await cred.user!.updateDisplayName(profileTemplate.fullName);
      // Email verification: sent but not blocking so the demo stays usable.
      try {
        await cred.user!.sendEmailVerification();
      } catch (_) {}

      final profile = AppUser(
        uid: uid,
        email: email.trim(),
        fullName: profileTemplate.fullName,
        role: profileTemplate.role,
        studentId: profileTemplate.studentId,
        programme: profileTemplate.programme,
        interests: profileTemplate.interests,
        organisationName: profileTemplate.organisationName,
        position: profileTemplate.position,
        businessName: profileTemplate.businessName,
        contactNumber: profileTemplate.contactNumber,
        productCategory: profileTemplate.productCategory,
        isStudentVendor: profileTemplate.isStudentVendor,
        eligibilityNotes: profileTemplate.eligibilityNotes,
      );
      await _users.doc(uid).set(profile.toMap());
      return profile;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_message(e));
    }
  }

  /// Google Sign-In. Returns the profile if one exists, or null when the
  /// Google account is new and still needs to choose a role.
  Future<({User user, AppUser? profile})> signInWithGoogle() async {
    try {
      final account = await _google.signIn();
      if (account == null) throw AuthException('Google sign-in was cancelled.');
      final gAuth = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: gAuth.accessToken,
        idToken: gAuth.idToken,
      );
      final cred = await _auth.signInWithCredential(credential);
      final user = cred.user!;
      final profile = await fetchProfile(user.uid);
      return (user: user, profile: profile);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_message(e));
    }
  }

  /// Completes a Google sign-up by creating the role profile.
  Future<AppUser> completeGoogleProfile(AppUser profile) async {
    await _users.doc(profile.uid).set(profile.toMap());
    return profile;
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_message(e));
    }
  }

  Future<void> changePassword(String current, String next) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw AuthException('You are not signed in.');
    }
    try {
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: current,
      );
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(next);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_message(e));
    }
  }

  Future<void> signOut() async {
    try {
      await _google.signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  String _message(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Please choose a stronger password.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'No internet connection. Check your network and try again.';
      case 'requires-recent-login':
        return 'Please log in again before changing your password.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}

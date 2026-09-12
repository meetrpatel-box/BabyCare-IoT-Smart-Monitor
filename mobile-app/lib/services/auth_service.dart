import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';

/// Authentication service for Firebase Auth operations
/// Ported from React Native authService.ts
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // GoogleSignIn is only available on mobile (requires web client ID configuration)
  GoogleSignIn? _googleSignIn;

  AuthService() {
    if (!kIsWeb) {
      _googleSignIn = GoogleSignIn();
    }
  }

  /// Get current user
  User? get currentUser => _auth.currentUser;

  /// Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign up with email and password
  Future<UserCredential> signUpWithEmailPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name if provided
      if (displayName != null && credential.user != null) {
        await credential.user!.updateDisplayName(displayName);
      }

      // Create user document in Firestore
      if (credential.user != null) {
        await _createUserDocument(credential.user!, displayName: displayName);
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Sign in with email and password
  Future<UserCredential> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update last login in background — non-critical timestamp, don't block login
      if (credential.user != null) {
        _updateLastLogin(credential.user!.uid)
            .catchError((e) => debugPrint('updateLastLogin error: $e'));
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Sign in with Google
  Future<UserCredential> signInWithGoogle() async {
    if (_googleSignIn == null) {
      throw Exception('Google Sign-In is not available on this platform');
    }

    try {
      // Sign out from the GoogleSignIn state so the account picker always
      // shows and the user can choose between multiple Google accounts.
      // This does NOT revoke Firebase auth or disconnect the account.
      try {
        await _googleSignIn!.signOut();
      } catch (_) {}

      // Show account picker — timeout after 60 s to avoid infinite hang
      final GoogleSignInAccount? googleUser =
          await _googleSignIn!.signIn().timeout(
                const Duration(seconds: 60),
                onTimeout: () => null,
              );

      if (googleUser == null) {
        throw Exception('Google Sign-In cancelled');
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      // Create/update Firestore doc in background — don't block sign-in
      if (userCredential.user != null) {
        _userDocumentExists(userCredential.user!.uid).then((exists) {
          if (!exists) {
            return _createUserDocument(
              userCredential.user!,
              displayName: userCredential.user!.displayName,
            );
          } else {
            return _updateLastLogin(userCredential.user!.uid);
          }
        }).catchError((e) => debugPrint('Google post-auth error: $e'));
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception('Google Sign-In failed: $e');
    }
  }

  /// Sign in with phone number - start verification
  Future<void> signInWithPhoneNumber({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(PhoneAuthCredential credential) onVerificationCompleted,
    required Function(FirebaseAuthException e) onVerificationFailed,
    required Function(String verificationId) onCodeAutoRetrievalTimeout,
    int? forceResendingToken,
  }) async {
    debugPrint('📱 [PhoneAuth] Requesting OTP for $phoneNumber');
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (credential) {
        debugPrint('📱 [PhoneAuth] Auto-verification completed');
        onVerificationCompleted(credential);
      },
      verificationFailed: (e) {
        debugPrint(
            '📱 [PhoneAuth] Verification failed — code: ${e.code}, message: ${e.message}');
        onVerificationFailed(e);
      },
      codeSent: (verificationId, resendToken) {
        debugPrint('📱 [PhoneAuth] OTP code sent successfully');
        onCodeSent(verificationId, resendToken);
      },
      codeAutoRetrievalTimeout: (verificationId) {
        debugPrint('📱 [PhoneAuth] Auto-retrieval timeout');
        onCodeAutoRetrievalTimeout(verificationId);
      },
      forceResendingToken: forceResendingToken,
      timeout: const Duration(seconds: 60),
    );
  }

  /// Verify phone OTP and sign in
  Future<UserCredential> verifyPhoneOTP({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      // Create user document if new user
      if (userCredential.user != null) {
        final exists = await _userDocumentExists(userCredential.user!.uid);
        if (!exists) {
          await _createUserDocument(userCredential.user!);
        } else {
          await _updateLastLogin(userCredential.user!.uid);
        }
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Delete account
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user signed in');

    // Delete user document
    await _firestore.collection('users').doc(user.uid).delete();

    // Delete auth account
    await user.delete();
  }

  /// Get Firestore user data
  Future<UserModel?> getFirestoreUser(String userId) async {
    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .get()
        .timeout(const Duration(seconds: 8));
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  /// Update Firestore user data
  Future<void> updateFirestoreUser(
      String userId, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(userId).update(data);
  }

  /// Create family for existing user (migration helper)
  Future<void> createFamilyForExistingUser(
      String userId, String? displayName) async {
    // Create a family for the existing user
    final familyRef = await _firestore.collection('families').add({
      'name': "${displayName ?? 'My'} Family",
      'members': [userId],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdBy': userId,
    });

    debugPrint('✅ Created family: ${familyRef.id}');

    // Create a default baby for the new family
    final babyRef = await _firestore.collection('babies').add({
      'name': 'Baby',
      'familyId': familyRef.id,
      'dateOfBirth': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(days: 30))), // 1 month old
      'gender': 'unknown',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'profilePhotoUrl': null,
    });

    debugPrint('✅ Created baby: ${babyRef.id}');

    // Update user's familyIds
    await _firestore.collection('users').doc(userId).update({
      'familyIds': [familyRef.id],
    });

    debugPrint('✅ Updated user familyIds');
  }

  /// Create user document in Firestore
  Future<void> _createUserDocument(User user, {String? displayName}) async {
    // Create a family for the new user
    final familyRef = await _firestore.collection('families').add({
      'name': "${displayName ?? user.displayName ?? 'My'} Family",
      'members': [user.uid],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdBy': user.uid,
    });

    debugPrint('✅ Created family: ${familyRef.id}');

    // Create a default baby for the new family
    final babyRef = await _firestore.collection('babies').add({
      'name': 'Baby',
      'familyId': familyRef.id,
      'dateOfBirth': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(days: 30))), // 1 month old
      'gender': 'unknown',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'profilePhotoUrl': null,
    });

    debugPrint('✅ Created baby: ${babyRef.id}');

    final userModel = UserModel(
      id: user.uid,
      email: user.email ?? '',
      phoneNumber: user.phoneNumber,
      displayName: displayName ?? user.displayName,
      photoUrl: user.photoURL,
      createdAt: DateTime.now(),
      lastLoginAt: DateTime.now(),
      preferences: UserPreferences(),
      familyIds: [familyRef.id],
    );

    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(userModel.toFirestore());

    debugPrint('✅ Created user with familyId: ${familyRef.id}');
  }

  /// Check if user document exists
  Future<bool> _userDocumentExists(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    return doc.exists;
  }

  /// Update last login timestamp
  Future<void> _updateLastLogin(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'lastLoginAt': FieldValue.serverTimestamp(),
    });
  }

  /// Handle Firebase Auth exceptions
  Exception _handleAuthException(FirebaseAuthException e) {
    debugPrint(
        '🔥 [Auth] FirebaseAuthException — code: ${e.code}, message: ${e.message}');
    switch (e.code) {
      // ── Email/password ────────────────────────────────────────────────────
      case 'email-already-in-use':
        return Exception('This email is already registered');
      case 'invalid-email':
        return Exception('Invalid email address');
      case 'operation-not-allowed':
        return Exception(
            'This sign-in method is not enabled. Please contact support.');
      case 'weak-password':
        return Exception('Password is too weak');
      case 'user-disabled':
        return Exception('This account has been disabled');
      case 'user-not-found':
        return Exception('No account found with this email');
      case 'wrong-password':
        return Exception('Incorrect password');
      // ── Phone auth ────────────────────────────────────────────────────────
      case 'invalid-phone-number':
        return Exception(
            'Invalid phone number. Please include your country code (e.g. +91XXXXXXXXXX).');
      case 'missing-phone-number':
        return Exception('Please enter a phone number.');
      case 'quota-exceeded':
        return Exception('SMS quota exceeded. Please try again later.');
      case 'too-many-requests':
        return Exception(
            'Too many requests. Please wait a few minutes and try again.');
      case 'missing-app-credential':
      case 'missing-client-identifier':
      case 'app-not-authorized':
        return Exception(
            'This app is not authorized for phone authentication. Please contact support.');
      case 'captcha-check-failed':
        return Exception('Security verification failed. Please try again.');
      case 'invalid-verification-code':
        return Exception(
            'Invalid verification code. Please check the code and try again.');
      case 'invalid-verification-id':
        return Exception(
            'Verification session expired. Please request a new code.');
      case 'session-expired':
      case 'code-expired':
        return Exception(
            'Verification code has expired. Please request a new one.');
      case 'network-request-failed':
        return Exception(
            'Network error. Please check your connection and try again.');
      case 'invalid-app-credential':
        return Exception('App verification failed. Please contact support.');
      // ── Generic ───────────────────────────────────────────────────────────
      default:
        return Exception(e.message?.isNotEmpty == true
            ? e.message!
            : 'An error occurred (${e.code}). Please try again.');
    }
  }
}

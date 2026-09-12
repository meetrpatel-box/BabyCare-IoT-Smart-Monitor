import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/pin_service.dart';
import '../services/biometric_service.dart';
import '../services/auth/session_manager.dart';

/// Authentication state provider.
///
/// Startup flow:
/// 1. Subscribe to Firebase authStateChanges immediately.
/// 2. Firebase fires the first event with the cached user (or null) very quickly.
/// 3. On first event: check PIN, load Firestore user if needed, then set isLoading=false.
/// 4. Router redirects based on resolved state.
///
/// This removes the previous double-flash caused by _attemptAutoLogin() setting
/// isLoading=false before authStateChanges had a chance to fire.
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final SessionManager _sessionManager = SessionManager.instance;

  User? _currentUser;
  UserModel? _firestoreUser;
  bool _isLoading = true; // true until first auth state event resolves
  bool _isAuthenticated = false;
  bool _requiresPinEntry = false;
  String? _error;
  String? _pendingVerificationId;
  String? _pendingPhoneNumber;

  StreamSubscription<User?>? _authSubscription;
  VoidCallback? _onUserLoaded;

  AuthProvider() {
    _init();
  }

  // ── Getters ─────────────────────────────────────────────────────────────────

  User? get currentUser => _currentUser;
  UserModel? get firestoreUser => _firestoreUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  bool get requiresPinEntry => _requiresPinEntry;
  String? get error => _error;
  String? get userId => _currentUser?.uid;
  String? get pendingVerificationId => _pendingVerificationId;
  String? get pendingPhoneNumber => _pendingPhoneNumber;

  // ── Initialization ───────────────────────────────────────────────────────────

  void _init() {
    // Firebase already persists auth state across restarts.
    // authStateChanges fires the first event immediately (from cache) — no
    // pre-check or session-manager initialization needed at startup.
    _authSubscription =
        _authService.authStateChanges.listen(_onAuthStateChanged);
  }

  // ── Auth state listener ──────────────────────────────────────────────────────

  Future<void> _onAuthStateChanged(User? user) async {
    _currentUser = user;

    if (user != null) {
      // Hold the loading state so the router doesn't flash the welcome screen
      // while we resolve PIN / Firestore user.
      _isLoading = true;
      notifyListeners();

      // PIN check is a local secure-storage read — fast (~20ms)
      final hasPinSetup = await PinService.hasPinSetup(user.uid);

      if (hasPinSetup) {
        _requiresPinEntry = true;
        _isAuthenticated = false;
        _isLoading = false;
        notifyListeners();
      } else {
        _requiresPinEntry = false;
        _isAuthenticated = true;
        try {
          await _loadFirestoreUser(user.uid);
        } catch (e) {
          debugPrint('❌ Auth state handler error: $e');
        } finally {
          _isLoading = false;
          notifyListeners();
        }
      }

      // Save session metadata in background — non-blocking
      // saveSession() handles its own errors internally
      _sessionManager.saveSession(user: user, loginMethod: 'firebase').ignore();

      // Start proactive token refresh
      _sessionManager.startAutoRefresh();
    } else {
      _firestoreUser = null;
      _isAuthenticated = false;
      _requiresPinEntry = false;
      _sessionManager.stopAutoRefresh();
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Firestore user ───────────────────────────────────────────────────────────

  Future<void> _loadFirestoreUser(String userId) async {
    try {
      _firestoreUser = await _authService.getFirestoreUser(userId);
      notifyListeners();
      _onUserLoaded?.call();

      // Run family migration in background for users without familyIds
      if (_firestoreUser != null &&
          (_firestoreUser!.familyIds.isEmpty ||
              _firestoreUser!.familyIds.every((id) => id.isEmpty))) {
        debugPrint('🔧 Running family migration in background');
        _runFamilyMigration(userId);
      }
    } catch (e) {
      debugPrint('Error loading Firestore user: $e');
    }
  }

  Future<void> _runFamilyMigration(String userId) async {
    try {
      await _authService.createFamilyForExistingUser(
          userId, _firestoreUser!.displayName);
      _firestoreUser = await _authService.getFirestoreUser(userId);
      debugPrint(
          '✅ Migration complete: familyIds = ${_firestoreUser!.familyIds}');
      notifyListeners();
      _onUserLoaded?.call();
    } catch (e) {
      debugPrint('Migration error: $e');
    }
  }

  void setOnUserLoaded(VoidCallback callback) {
    _onUserLoaded = callback;
  }

  Future<void> refreshFirestoreUser() async {
    if (_currentUser != null) {
      await _loadFirestoreUser(_currentUser!.uid);
    }
  }

  // ── Sign-up / sign-in methods ────────────────────────────────────────────────

  Future<void> signUpWithEmailPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.signUpWithEmailPassword(
        email: email,
        password: password,
        displayName: displayName,
      );
      // authStateChanges listener handles the rest — no manual notifyListeners needed
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.signInWithEmailPassword(
        email: email,
        password: password,
      );
      // authStateChanges listener handles state + router redirect
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.signInWithGoogle();
      // authStateChanges listener handles state + router redirect
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signInWithPhoneNumber({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(String error) onError,
    int? forceResendingToken,
  }) async {
    _isLoading = true;
    _error = null;
    _pendingPhoneNumber = phoneNumber;
    notifyListeners();

    try {
      await _authService.signInWithPhoneNumber(
        phoneNumber: phoneNumber,
        onCodeSent: (verificationId, resendToken) {
          debugPrint('📱 [AuthProvider] Code sent — verificationId received');
          _pendingVerificationId = verificationId;
          _isLoading = false;
          notifyListeners(); // router redirect picks this up → navigates to OTP
          onCodeSent(verificationId, resendToken);
        },
        onVerificationCompleted: (credential) async {
          debugPrint('📱 [AuthProvider] Auto-verification — signing in');
          try {
            await FirebaseAuth.instance.signInWithCredential(credential);
            _pendingVerificationId = null;
            _pendingPhoneNumber = null;
          } catch (e) {
            debugPrint(
                '📱 [AuthProvider] Auto-verification sign-in failed: $e');
          }
        },
        onVerificationFailed: (e) {
          debugPrint(
              '📱 [AuthProvider] Verification failed — ${e.code}: ${e.message}');
          _error = e.message;
          _isLoading = false;
          _pendingVerificationId = null;
          _pendingPhoneNumber = null;
          notifyListeners();
          onError(e.message ?? 'Phone verification failed. Please try again.');
        },
        onCodeAutoRetrievalTimeout: (_) {
          debugPrint('📱 [AuthProvider] Auto-retrieval timeout');
          _isLoading = false;
          notifyListeners();
        },
        forceResendingToken: forceResendingToken,
      );
    } catch (e) {
      debugPrint('📱 [AuthProvider] signInWithPhoneNumber exception: $e');
      _error = e.toString();
      _isLoading = false;
      _pendingVerificationId = null;
      _pendingPhoneNumber = null;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> verifyPhoneOTP({
    required String verificationId,
    required String smsCode,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.verifyPhoneOTP(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      _pendingVerificationId = null;
      _pendingPhoneNumber = null;
      // Firebase auth state fires before _createUserDocument completes for new
      // phone users, so the Firestore user doc may not exist yet. Reload it
      // explicitly after the doc has been created.
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await _loadFirestoreUser(uid);
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // ── PIN / Biometric ──────────────────────────────────────────────────────────

  Future<void> setupPin(String pin) async {
    if (_currentUser == null) throw Exception('No user signed in');
    await PinService.storePin(pin, _currentUser!.uid);
  }

  Future<PinVerificationResult> verifyPin(String pin) async {
    if (_currentUser == null) {
      return PinVerificationResult(success: false, error: 'No user signed in');
    }

    final result = await PinService.verifyPin(pin, _currentUser!.uid);

    if (result.success) {
      _requiresPinEntry = false;
      _isAuthenticated = true;
      await _loadFirestoreUser(_currentUser!.uid);
      notifyListeners();
    }

    return result;
  }

  Future<bool> authenticateWithBiometrics() async {
    if (_currentUser == null) return false;

    final result = await BiometricService.authenticate();

    if (result.success) {
      _requiresPinEntry = false;
      _isAuthenticated = true;
      await _loadFirestoreUser(_currentUser!.uid);
      notifyListeners();
      return true;
    }

    return false;
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    if (_currentUser == null) return;
    await BiometricService.setBiometricEnabled(_currentUser!.uid, enabled);
  }

  Future<bool> isBiometricEnabled() async {
    if (_currentUser == null) return false;
    return BiometricService.isBiometricEnabled(_currentUser!.uid);
  }

  // ── Password reset ───────────────────────────────────────────────────────────

  Future<void> sendPasswordResetEmail(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.sendPasswordResetEmail(email);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // ── Sign-out ─────────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Stop token refresh timer and clear stored session metadata
      await _sessionManager.clearSession();

      // Sign out from Firebase — fires authStateChanges(null) which clears state
      await _authService.signOut();
    } catch (e) {
      debugPrint('Sign-out error: $e');
    }
    // authStateChanges(null) listener will clear _currentUser, _firestoreUser,
    // _isAuthenticated, _requiresPinEntry and call notifyListeners().
  }

  // ── Profile ──────────────────────────────────────────────────────────────────

  Future<void> updateProfile({String? displayName, String? photoUrl}) async {
    if (_currentUser == null) return;

    final data = <String, dynamic>{};
    if (displayName != null) data['displayName'] = displayName;
    if (photoUrl != null) data['photoUrl'] = photoUrl;

    await _authService.updateFirestoreUser(_currentUser!.uid, data);
    await refreshFirestoreUser();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

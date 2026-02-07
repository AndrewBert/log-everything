import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/logger.dart';

// CP: Result of anonymous auth attempt
class AnonymousAuthResult extends Equatable {
  final AnonymousAuthStatus status;
  final String? uid;
  final String? errorMessage;

  const AnonymousAuthResult._({
    required this.status,
    this.uid,
    this.errorMessage,
  });

  factory AnonymousAuthResult.success(String uid) => AnonymousAuthResult._(
    status: AnonymousAuthStatus.success,
    uid: uid,
  );

  factory AnonymousAuthResult.requiresConnection() => const AnonymousAuthResult._(
    status: AnonymousAuthStatus.requiresConnection,
  );

  factory AnonymousAuthResult.failed(String message) => AnonymousAuthResult._(
    status: AnonymousAuthStatus.failed,
    errorMessage: message,
  );

  @override
  List<Object?> get props => [status, uid, errorMessage];
}

enum AnonymousAuthStatus {
  success,
  requiresConnection,
  failed,
}

// CP: Abstract interface for anonymous Firebase authentication
abstract class AnonymousAuthService {
  /// Returns true if user has any Firebase auth (anonymous or signed-in)
  bool hasAuthentication();

  /// Ensures anonymous auth exists. Only call when hasAuthentication() is false.
  Future<AnonymousAuthResult> ensureAnonymousAuth();
}

// CP: Firebase implementation of anonymous auth
class FirebaseAnonymousAuthService implements AnonymousAuthService {
  final FirebaseAuth _firebaseAuth;

  FirebaseAnonymousAuthService({
    FirebaseAuth? firebaseAuth,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  @override
  bool hasAuthentication() {
    return _firebaseAuth.currentUser != null;
  }

  @override
  Future<AnonymousAuthResult> ensureAnonymousAuth() async {
    try {
      // CP: Check if already authenticated
      if (_firebaseAuth.currentUser != null) {
        AppLogger.info('[AnonymousAuthService] User already authenticated: ${_firebaseAuth.currentUser!.uid}');
        return AnonymousAuthResult.success(_firebaseAuth.currentUser!.uid);
      }

      // CP: Create anonymous account
      final credential = await _firebaseAuth.signInAnonymously();

      if (credential.user == null) {
        return AnonymousAuthResult.failed('Anonymous sign-in returned no user');
      }

      AppLogger.info('[AnonymousAuthService] Anonymous auth created: ${credential.user!.uid}');
      return AnonymousAuthResult.success(credential.user!.uid);
    } on FirebaseAuthException catch (e) {
      AppLogger.error('[AnonymousAuthService] Firebase auth error', error: e);

      // CP: Check for network-related errors
      if (_isNetworkError(e.code)) {
        return AnonymousAuthResult.requiresConnection();
      }

      return AnonymousAuthResult.failed(e.message ?? 'Authentication failed');
    } catch (e) {
      AppLogger.error('[AnonymousAuthService] Unexpected error', error: e);

      // CP: Check if error message indicates network issue
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('network') ||
          errorString.contains('internet') ||
          errorString.contains('connection') ||
          errorString.contains('offline')) {
        return AnonymousAuthResult.requiresConnection();
      }

      return AnonymousAuthResult.failed('Authentication failed. Please try again.');
    }
  }

  // CP: Check if Firebase error code indicates network issue
  bool _isNetworkError(String? code) {
    if (code == null) return false;

    const networkErrorCodes = [
      'network-request-failed',
      'internal-error', // CP: Often indicates network issues
      'too-many-requests', // CP: Can happen with network issues
    ];

    return networkErrorCodes.contains(code);
  }
}

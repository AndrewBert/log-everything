import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:myapp/utils/logger.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

// CP: Domain model for authenticated user
class AuthUser {
  final String uid;
  final String? displayName;
  final String? email;
  final String? photoUrl;

  const AuthUser({
    required this.uid,
    this.displayName,
    this.email,
    this.photoUrl,
  });

  factory AuthUser.fromFirebase(User firebaseUser) {
    return AuthUser(
      uid: firebaseUser.uid,
      displayName: firebaseUser.displayName,
      email: firebaseUser.email,
      photoUrl: firebaseUser.photoURL,
    );
  }
}

// CP: Custom exceptions for auth operations
class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

class AuthCancelledException implements Exception {}

// CP: Abstract interface for authentication
abstract class AuthService {
  AuthUser? get currentUser;
  Stream<AuthUser?> get authStateChanges;
  Future<AuthUser> signInWithGoogle();
  Future<AuthUser> signInWithApple();
  Future<void> signOut();
}

// CP: Firebase implementation using google_sign_in v7 API
class FirebaseAuthService implements AuthService {
  final FirebaseAuth _firebaseAuth;
  bool _googleSignInInitialized = false;

  // CP: Web Client ID from Firebase - required for Android
  static const String _serverClientId =
      '951334134238-ui2amk1dq2tgivdl3jafq7qsb68impsv.apps.googleusercontent.com';

  FirebaseAuthService({
    FirebaseAuth? firebaseAuth,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  @override
  AuthUser? get currentUser {
    final user = _firebaseAuth.currentUser;
    return user != null ? AuthUser.fromFirebase(user) : null;
  }

  @override
  Stream<AuthUser?> get authStateChanges {
    return _firebaseAuth.authStateChanges().map(
          (user) => user != null ? AuthUser.fromFirebase(user) : null,
        );
  }

  // CP: Initialize GoogleSignIn once with serverClientId for Android
  Future<void> _ensureGoogleSignInInitialized() async {
    if (!_googleSignInInitialized) {
      await GoogleSignIn.instance.initialize(serverClientId: _serverClientId);
      _googleSignInInitialized = true;
    }
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    try {
      await _ensureGoogleSignInInitialized();

      // CP: google_sign_in v7 uses instance.authenticate()
      final googleUser = await GoogleSignIn.instance.authenticate();

      // CP: v7 API - authentication is a direct property, not async
      final googleAuth = googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final userCredential = await _firebaseAuth.signInWithCredential(credential);

      if (userCredential.user == null) {
        throw AuthException('Sign in failed - no user returned');
      }

      AppLogger.info('User signed in: ${userCredential.user!.email}');
      return AuthUser.fromFirebase(userCredential.user!);
    } on FirebaseAuthException catch (e) {
      AppLogger.error('Firebase auth error', error: e);
      throw AuthException(e.message ?? 'Sign in failed');
    } on AuthCancelledException {
      rethrow;
    } catch (e) {
      AppLogger.error('Unexpected sign in error', error: e);
      throw AuthException('Sign in failed. Please try again.');
    }
  }

  @override
  Future<AuthUser> signInWithApple() async {
    try {
      // CP: Generate a secure random nonce for Apple Sign-In
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      final userCredential = await _firebaseAuth.signInWithCredential(oauthCredential);

      if (userCredential.user == null) {
        throw AuthException('Sign in failed - no user returned');
      }

      // CP: Apple only provides name on first sign-in, so update profile if available
      if (appleCredential.givenName != null || appleCredential.familyName != null) {
        final displayName = [
          appleCredential.givenName,
          appleCredential.familyName,
        ].where((s) => s != null).join(' ');

        if (displayName.isNotEmpty) {
          await userCredential.user!.updateDisplayName(displayName);
        }
      }

      AppLogger.info('User signed in with Apple: ${userCredential.user!.email}');
      return AuthUser.fromFirebase(userCredential.user!);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw AuthCancelledException();
      }
      AppLogger.error('Apple sign in error', error: e);
      throw AuthException(e.message);
    } on FirebaseAuthException catch (e) {
      AppLogger.error('Firebase auth error', error: e);
      throw AuthException(e.message ?? 'Sign in failed');
    } catch (e) {
      AppLogger.error('Unexpected Apple sign in error', error: e);
      throw AuthException('Sign in failed. Please try again.');
    }
  }

  // CP: Generate a cryptographically secure random nonce
  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  // CP: SHA256 hash the nonce for Apple Sign-In
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  @override
  Future<void> signOut() async {
    try {
      await Future.wait([
        _firebaseAuth.signOut(),
        GoogleSignIn.instance.signOut(),
      ]);
      AppLogger.info('User signed out');
    } catch (e) {
      AppLogger.error('Sign out error', error: e);
      throw AuthException('Sign out failed. Please try again.');
    }
  }
}

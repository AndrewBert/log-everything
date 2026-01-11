import 'package:myapp/settings/services/auth_service.dart';

/// CP: Test data constants for auth-related tests.
class AuthTestData {
  AuthTestData._();

  /// Standard test user without photo
  static const testUser = AuthUser(
    uid: 'test-user-id-123',
    displayName: 'Test User',
    email: 'test@example.com',
    photoUrl: null,
  );

  /// Test user with profile photo URL
  static const userWithPhoto = AuthUser(
    uid: 'test-user-id-456',
    displayName: 'Photo User',
    email: 'photo@example.com',
    photoUrl: 'https://example.com/photo.jpg',
  );

  /// Test user with minimal data (no display name)
  static const userMinimal = AuthUser(
    uid: 'test-user-id-789',
    displayName: null,
    email: 'minimal@example.com',
    photoUrl: null,
  );

  /// Apple sign-in user (may have display name set later)
  static const appleUser = AuthUser(
    uid: 'apple-user-id-001',
    displayName: 'Apple User',
    email: 'apple@privaterelay.appleid.com',
    photoUrl: null,
  );
}

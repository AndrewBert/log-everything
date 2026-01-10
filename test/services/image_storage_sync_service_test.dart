import 'dart:async';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:myapp/services/image_storage_sync_service.dart';
import 'package:myapp/settings/services/auth_service.dart';

import '../mocks.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthService mockAuthService;
  late MockFirebaseStorage mockStorage;
  late MockReference mockRef;
  late FirebaseImageStorageSyncService service;
  late Directory tempDir;

  setUp(() async {
    mockAuthService = MockAuthService();
    mockStorage = MockFirebaseStorage();
    mockRef = MockReference();

    // CP: Set up the mock chain: storage.ref().child(path)
    when(mockStorage.ref()).thenReturn(mockRef);
    when(mockRef.child(any)).thenReturn(mockRef);

    service = FirebaseImageStorageSyncService(
      authService: mockAuthService,
      storage: mockStorage,
    );

    // CP: Create temp directory for file tests
    tempDir = Directory.systemTemp.createTempSync('image_sync_test_');
  });

  tearDown(() async {
    // CP: Clean up temp directory
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  // CP: Helper to create a mock user using real AuthUser type
  void stubSignedInUser(String uid) {
    final user = AuthUser(uid: uid);
    when(mockAuthService.currentUser).thenReturn(user);
  }

  void stubNotSignedIn() {
    when(mockAuthService.currentUser).thenReturn(null);
  }

  group('uploadImage', () {
    test(
      'Given user not signed in, When uploadImage called, Then returns null',
      () async {
        // Given
        stubNotSignedIn();
        final testFile = File('${tempDir.path}/test.jpg');
        await testFile.writeAsBytes([0xFF, 0xD8, 0xFF]); // JPEG magic bytes

        // When
        final result = await service.uploadImage(testFile, 'test-uuid');

        // Then
        expect(result, isNull);
        verifyNever(mockRef.putFile(any, any));
      },
    );

    test(
      'Given file does not exist, When uploadImage called, Then returns null',
      () async {
        // Given
        stubSignedInUser('uid123');
        final nonExistentFile = File('${tempDir.path}/does_not_exist.jpg');

        // When
        final result = await service.uploadImage(nonExistentFile, 'test-uuid');

        // Then
        expect(result, isNull);
        verifyNever(mockRef.putFile(any, any));
      },
    );

    test(
      'Given invalid UUID format, When uploadImage called, Then returns null',
      () async {
        // Given
        stubSignedInUser('uid123');
        final testFile = File('${tempDir.path}/test.jpg');
        await testFile.writeAsBytes([0xFF, 0xD8, 0xFF]);

        // When - UUID with invalid characters
        final result = await service.uploadImage(testFile, 'uuid@with/special');

        // Then
        expect(result, isNull);
        verifyNever(mockRef.putFile(any, any));
      },
    );

    test(
      'Given valid file and UUID, When uploadImage succeeds, Then returns cloud path',
      () async {
        // Given
        stubSignedInUser('uid123');
        final testFile = File('${tempDir.path}/test.jpg');
        await testFile.writeAsBytes([0xFF, 0xD8, 0xFF]);
        when(mockRef.putFile(any, any)).thenAnswer((_) => MockUploadTask.success());

        // When
        final result = await service.uploadImage(testFile, 'abc-123');

        // Then
        expect(result, equals('users/uid123/images/abc-123.jpg'));
        verify(mockRef.child('users/uid123/images/abc-123.jpg')).called(1);
        verify(mockRef.putFile(any, any)).called(1);
      },
    );

    test(
      'Given non-retryable Firebase error, When uploadImage called, Then returns null immediately',
      () async {
        // Given
        stubSignedInUser('uid123');
        final testFile = File('${tempDir.path}/test.jpg');
        await testFile.writeAsBytes([0xFF, 0xD8, 0xFF]);
        when(mockRef.putFile(any, any)).thenThrow(
          FirebaseException(
            plugin: 'firebase_storage',
            code: 'permission-denied',
            message: 'Permission denied',
          ),
        );

        // When
        final result = await service.uploadImage(testFile, 'test-uuid');

        // Then
        expect(result, isNull);
        // Only called once - no retries for non-retryable errors
        verify(mockRef.putFile(any, any)).called(1);
      },
    );

    test(
      'Given retryable error then success, When uploadImage called, Then retries and returns path',
      () async {
        // Given
        stubSignedInUser('uid123');
        final testFile = File('${tempDir.path}/test.jpg');
        await testFile.writeAsBytes([0xFF, 0xD8, 0xFF]);

        var callCount = 0;
        when(mockRef.putFile(any, any)).thenAnswer((_) {
          callCount++;
          if (callCount < 2) {
            return MockUploadTask.error(
              FirebaseException(
                plugin: 'firebase_storage',
                code: 'network-error',
                message: 'Network failed',
              ),
            );
          }
          return MockUploadTask.success();
        });

        // When
        final result = await service.uploadImage(testFile, 'test-uuid');

        // Then
        expect(result, equals('users/uid123/images/test-uuid.jpg'));
        verify(mockRef.putFile(any, any)).called(2); // First fail, second success
      },
    );

    test(
      'Given all retries fail, When uploadImage called, Then returns null after max retries',
      () async {
        // Given
        stubSignedInUser('uid123');
        final testFile = File('${tempDir.path}/test.jpg');
        await testFile.writeAsBytes([0xFF, 0xD8, 0xFF]);
        when(mockRef.putFile(any, any)).thenThrow(
          FirebaseException(
            plugin: 'firebase_storage',
            code: 'unknown',
            message: 'Unknown error',
          ),
        );

        // When
        final result = await service.uploadImage(testFile, 'test-uuid');

        // Then
        expect(result, isNull);
        verify(mockRef.putFile(any, any)).called(3); // 3 retry attempts
      },
    );
  });

  group('downloadImage', () {
    test(
      'Given user not signed in, When downloadImage called, Then returns false',
      () async {
        // Given
        stubNotSignedIn();

        // When
        final result = await service.downloadImage(
          'users/uid123/images/test.jpg',
          '${tempDir.path}/local.jpg',
        );

        // Then
        expect(result, isFalse);
        verifyNever(mockRef.writeToFile(any));
      },
    );

    test(
      'Given invalid path format (wrong UID), When downloadImage called, Then returns false',
      () async {
        // Given
        stubSignedInUser('uid123');

        // When - Path belongs to different user
        final result = await service.downloadImage(
          'users/other-uid/images/test.jpg',
          '${tempDir.path}/local.jpg',
        );

        // Then
        expect(result, isFalse);
        verifyNever(mockRef.writeToFile(any));
      },
    );

    test(
      'Given path traversal attempt, When downloadImage called, Then returns false',
      () async {
        // Given
        stubSignedInUser('uid123');

        // When - Path with traversal
        final result = await service.downloadImage(
          'users/uid123/../other/images/test.jpg',
          '${tempDir.path}/local.jpg',
        );

        // Then
        expect(result, isFalse);
        verifyNever(mockRef.writeToFile(any));
      },
    );

    test(
      'Given invalid file extension, When downloadImage called, Then returns false',
      () async {
        // Given
        stubSignedInUser('uid123');

        // When - Wrong file extension
        final result = await service.downloadImage(
          'users/uid123/images/test.png',
          '${tempDir.path}/local.jpg',
        );

        // Then
        expect(result, isFalse);
        verifyNever(mockRef.writeToFile(any));
      },
    );

    test(
      'Given valid path, When downloadImage succeeds, Then returns true',
      () async {
        // Given
        stubSignedInUser('uid123');
        when(mockRef.writeToFile(any)).thenAnswer((_) => MockDownloadTask.success());

        // When
        final result = await service.downloadImage(
          'users/uid123/images/abc-123.jpg',
          '${tempDir.path}/local.jpg',
        );

        // Then
        expect(result, isTrue);
        verify(mockRef.child('users/uid123/images/abc-123.jpg')).called(1);
        verify(mockRef.writeToFile(any)).called(1);
      },
    );

    test(
      'Given retryable error then success, When downloadImage called, Then retries and returns true',
      () async {
        // Given
        stubSignedInUser('uid123');
        var callCount = 0;
        when(mockRef.writeToFile(any)).thenAnswer((_) {
          callCount++;
          if (callCount < 2) {
            return MockDownloadTask.error(
              FirebaseException(
                plugin: 'firebase_storage',
                code: 'timeout',
                message: 'Request timed out',
              ),
            );
          }
          return MockDownloadTask.success();
        });

        // When
        final result = await service.downloadImage(
          'users/uid123/images/test.jpg',
          '${tempDir.path}/local.jpg',
        );

        // Then
        expect(result, isTrue);
        verify(mockRef.writeToFile(any)).called(2);
      },
    );

    test(
      'Given Firebase error, When downloadImage called, Then returns false',
      () async {
        // Given
        stubSignedInUser('uid123');
        when(mockRef.writeToFile(any)).thenThrow(
          FirebaseException(
            plugin: 'firebase_storage',
            code: 'object-not-found',
            message: 'File not found',
          ),
        );

        // When
        final result = await service.downloadImage(
          'users/uid123/images/test.jpg',
          '${tempDir.path}/local.jpg',
        );

        // Then
        expect(result, isFalse);
      },
    );
  });

  group('deleteImage', () {
    test(
      'Given user not signed in, When deleteImage called, Then returns false',
      () async {
        // Given
        stubNotSignedIn();

        // When
        final result = await service.deleteImage('users/uid123/images/test.jpg');

        // Then
        expect(result, isFalse);
        verifyNever(mockRef.delete());
      },
    );

    test(
      'Given invalid path format, When deleteImage called, Then returns false',
      () async {
        // Given
        stubSignedInUser('uid123');

        // When - Path belongs to different user
        final result = await service.deleteImage('users/other-uid/images/test.jpg');

        // Then
        expect(result, isFalse);
        verifyNever(mockRef.delete());
      },
    );

    test(
      'Given valid path, When deleteImage succeeds, Then returns true',
      () async {
        // Given
        stubSignedInUser('uid123');
        when(mockRef.delete()).thenAnswer((_) async {});

        // When
        final result = await service.deleteImage('users/uid123/images/test.jpg');

        // Then
        expect(result, isTrue);
        verify(mockRef.child('users/uid123/images/test.jpg')).called(1);
        verify(mockRef.delete()).called(1);
      },
    );

    test(
      'Given object-not-found error, When deleteImage called, Then returns true (idempotent)',
      () async {
        // Given
        stubSignedInUser('uid123');
        when(mockRef.delete()).thenThrow(
          FirebaseException(
            plugin: 'firebase_storage',
            code: 'object-not-found',
            message: 'Object not found',
          ),
        );

        // When
        final result = await service.deleteImage('users/uid123/images/test.jpg');

        // Then - 404 is treated as success (file already deleted)
        expect(result, isTrue);
      },
    );

    test(
      'Given other Firebase error, When deleteImage called, Then returns false',
      () async {
        // Given
        stubSignedInUser('uid123');
        when(mockRef.delete()).thenThrow(
          FirebaseException(
            plugin: 'firebase_storage',
            code: 'permission-denied',
            message: 'Permission denied',
          ),
        );

        // When
        final result = await service.deleteImage('users/uid123/images/test.jpg');

        // Then
        expect(result, isFalse);
      },
    );
  });

  group('getDownloadUrl', () {
    test(
      'Given user not signed in, When getDownloadUrl called, Then returns null',
      () async {
        // Given
        stubNotSignedIn();

        // When
        final result = await service.getDownloadUrl('users/uid123/images/test.jpg');

        // Then
        expect(result, isNull);
        verifyNever(mockRef.getDownloadURL());
      },
    );

    test(
      'Given invalid path format, When getDownloadUrl called, Then returns null',
      () async {
        // Given
        stubSignedInUser('uid123');

        // When - Path belongs to different user
        final result = await service.getDownloadUrl('users/other-uid/images/test.jpg');

        // Then
        expect(result, isNull);
        verifyNever(mockRef.getDownloadURL());
      },
    );

    test(
      'Given valid path, When getDownloadUrl succeeds, Then returns URL',
      () async {
        // Given
        stubSignedInUser('uid123');
        when(mockRef.getDownloadURL()).thenAnswer(
          (_) async => 'https://firebasestorage.googleapis.com/test-url',
        );

        // When
        final result = await service.getDownloadUrl('users/uid123/images/test.jpg');

        // Then
        expect(result, equals('https://firebasestorage.googleapis.com/test-url'));
        verify(mockRef.child('users/uid123/images/test.jpg')).called(1);
        verify(mockRef.getDownloadURL()).called(1);
      },
    );

    test(
      'Given Firebase error, When getDownloadUrl called, Then returns null',
      () async {
        // Given
        stubSignedInUser('uid123');
        when(mockRef.getDownloadURL()).thenThrow(
          FirebaseException(
            plugin: 'firebase_storage',
            code: 'object-not-found',
            message: 'Object not found',
          ),
        );

        // When
        final result = await service.getDownloadUrl('users/uid123/images/test.jpg');

        // Then
        expect(result, isNull);
      },
    );
  });
}

// CP: Mock classes for Firebase Storage tasks
// These wrap a Completer to be awaitable like real Tasks
class MockUploadTask extends Mock implements UploadTask {
  final Completer<TaskSnapshot> _completer = Completer();

  MockUploadTask.success() {
    _completer.complete(MockTaskSnapshot());
  }

  MockUploadTask.error(Object error) {
    _completer.completeError(error);
  }

  @override
  Future<S> then<S>(
    FutureOr<S> Function(TaskSnapshot) onValue, {
    Function? onError,
  }) {
    return _completer.future.then(onValue, onError: onError);
  }

  @override
  Future<TaskSnapshot> whenComplete(FutureOr<void> Function() action) {
    return _completer.future.whenComplete(action);
  }

  @override
  Future<TaskSnapshot> catchError(Function onError, {bool Function(Object)? test}) {
    return _completer.future.catchError(onError, test: test);
  }

  @override
  Stream<TaskSnapshot> get snapshotEvents => Stream.empty();

  @override
  Stream<TaskSnapshot> asStream() => _completer.future.asStream();
}

class MockDownloadTask extends Mock implements DownloadTask {
  final Completer<TaskSnapshot> _completer = Completer();

  MockDownloadTask.success() {
    _completer.complete(MockTaskSnapshot());
  }

  MockDownloadTask.error(Object error) {
    _completer.completeError(error);
  }

  @override
  Future<S> then<S>(
    FutureOr<S> Function(TaskSnapshot) onValue, {
    Function? onError,
  }) {
    return _completer.future.then(onValue, onError: onError);
  }

  @override
  Future<TaskSnapshot> whenComplete(FutureOr<void> Function() action) {
    return _completer.future.whenComplete(action);
  }

  @override
  Future<TaskSnapshot> catchError(Function onError, {bool Function(Object)? test}) {
    return _completer.future.catchError(onError, test: test);
  }

  @override
  Stream<TaskSnapshot> get snapshotEvents => Stream.empty();

  @override
  Stream<TaskSnapshot> asStream() => _completer.future.asStream();
}

class MockTaskSnapshot extends Mock implements TaskSnapshot {}

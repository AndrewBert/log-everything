import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:uuid/uuid.dart';
import 'package:myapp/services/device_id_service.dart';

import '../mocks.mocks.dart';

void main() {
  late MockFlutterSecureStorage mockSecureStorage;
  late SecureStorageDeviceIdService deviceIdService;

  const testDeviceId = 'test-device-id-123';
  const storageKey = 'log_everything_device_id';

  setUp(() {
    mockSecureStorage = MockFlutterSecureStorage();
    deviceIdService = SecureStorageDeviceIdService(
      secureStorage: mockSecureStorage,
      uuid: const Uuid(),
    );
  });

  group('DeviceIdService', () {
    group('getDeviceId', () {
      test('returns existing ID from secure storage', () async {
        // Given: secure storage has an existing device ID
        when(mockSecureStorage.read(key: storageKey))
            .thenAnswer((_) async => testDeviceId);

        // When: getDeviceId is called
        final result = await deviceIdService.getDeviceId();

        // Then: returns the stored ID
        expect(result, equals(testDeviceId));
        verify(mockSecureStorage.read(key: storageKey)).called(1);
        verifyNever(mockSecureStorage.write(key: anyNamed('key'), value: anyNamed('value')));
      });

      test('generates and stores new ID when storage is empty', () async {
        // Given: secure storage has no device ID
        when(mockSecureStorage.read(key: storageKey))
            .thenAnswer((_) async => null);
        when(mockSecureStorage.write(key: anyNamed('key'), value: anyNamed('value')))
            .thenAnswer((_) async {});

        // When: getDeviceId is called
        final result = await deviceIdService.getDeviceId();

        // Then: returns a new UUID and stores it
        expect(result, isNotEmpty);
        expect(result.length, equals(36)); // UUID v4 format
        verify(mockSecureStorage.write(key: storageKey, value: result)).called(1);
      });

      test('generates new ID when storage returns empty string', () async {
        // Given: secure storage returns empty string
        when(mockSecureStorage.read(key: storageKey))
            .thenAnswer((_) async => '');
        when(mockSecureStorage.write(key: anyNamed('key'), value: anyNamed('value')))
            .thenAnswer((_) async {});

        // When: getDeviceId is called
        final result = await deviceIdService.getDeviceId();

        // Then: returns a new UUID
        expect(result, isNotEmpty);
        expect(result.length, equals(36));
      });

      test('returns cached ID on subsequent calls', () async {
        // Given: secure storage has an existing device ID
        when(mockSecureStorage.read(key: storageKey))
            .thenAnswer((_) async => testDeviceId);

        // When: getDeviceId is called twice
        final result1 = await deviceIdService.getDeviceId();
        final result2 = await deviceIdService.getDeviceId();

        // Then: returns same ID and only reads from storage once
        expect(result1, equals(testDeviceId));
        expect(result2, equals(testDeviceId));
        verify(mockSecureStorage.read(key: storageKey)).called(1);
      });

      test('returns fallback ID on storage read error', () async {
        // Given: secure storage throws an error
        when(mockSecureStorage.read(key: storageKey))
            .thenThrow(Exception('Storage error'));

        // When: getDeviceId is called
        final result = await deviceIdService.getDeviceId();

        // Then: returns a fallback UUID (not empty)
        expect(result, isNotEmpty);
        expect(result.length, equals(36));
      });
    });

    group('hasDeviceId', () {
      test('returns true when device ID exists in storage', () async {
        // Given: secure storage has a device ID
        when(mockSecureStorage.read(key: storageKey))
            .thenAnswer((_) async => testDeviceId);

        // When: hasDeviceId is called
        final result = await deviceIdService.hasDeviceId();

        // Then: returns true
        expect(result, isTrue);
      });

      test('returns false when storage is empty', () async {
        // Given: secure storage has no device ID
        when(mockSecureStorage.read(key: storageKey))
            .thenAnswer((_) async => null);

        // When: hasDeviceId is called
        final result = await deviceIdService.hasDeviceId();

        // Then: returns false
        expect(result, isFalse);
      });

      test('returns false when storage has empty string', () async {
        // Given: secure storage returns empty string
        when(mockSecureStorage.read(key: storageKey))
            .thenAnswer((_) async => '');

        // When: hasDeviceId is called
        final result = await deviceIdService.hasDeviceId();

        // Then: returns false
        expect(result, isFalse);
      });

      test('returns true when ID is cached (without hitting storage)', () async {
        // Given: device ID is already cached from previous getDeviceId call
        when(mockSecureStorage.read(key: storageKey))
            .thenAnswer((_) async => testDeviceId);
        await deviceIdService.getDeviceId(); // Prime the cache

        // When: hasDeviceId is called
        final result = await deviceIdService.hasDeviceId();

        // Then: returns true without additional storage read
        expect(result, isTrue);
        // Only one read from the getDeviceId call
        verify(mockSecureStorage.read(key: storageKey)).called(1);
      });

      test('returns false on storage error', () async {
        // Given: secure storage throws an error
        when(mockSecureStorage.read(key: storageKey))
            .thenThrow(Exception('Storage error'));

        // When: hasDeviceId is called
        final result = await deviceIdService.hasDeviceId();

        // Then: returns false
        expect(result, isFalse);
      });
    });
  });
}

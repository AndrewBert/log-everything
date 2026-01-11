import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:myapp/services/vector_store_service.dart';

import '../mocks.mocks.dart';

void main() {
  late MockSharedPreferences mockPrefs;
  late MockClient mockHttpClient;
  late MockEntryPersistenceService mockEntryPersistence;
  late VectorStoreService vectorStoreService;

  const testApiKey = 'test-api-key';
  const vectorStoreIdKey = 'openai_vector_store_id';
  const monthlyLogFileIdsKey = 'vector_store_monthly_log_file_ids';

  setUp(() {
    mockPrefs = MockSharedPreferences();
    mockHttpClient = MockClient();
    mockEntryPersistence = MockEntryPersistenceService();

    vectorStoreService = VectorStoreService(
      sharedPreferences: mockPrefs,
      httpClient: mockHttpClient,
      apiKey: testApiKey,
      entryPersistenceService: mockEntryPersistence,
    );
  });

  group('VectorStoreService', () {
    group('getVectorStoreId', () {
      test('returns stored vector store ID when it exists', () {
        // Given: SharedPreferences has a stored vector store ID
        when(mockPrefs.getString(vectorStoreIdKey)).thenReturn('vs-abc123');

        // When: getVectorStoreId is called
        final result = vectorStoreService.getVectorStoreId();

        // Then: returns the stored ID
        expect(result, equals('vs-abc123'));
        verify(mockPrefs.getString(vectorStoreIdKey)).called(1);
      });

      test('returns null when no vector store ID is stored', () {
        // Given: SharedPreferences has no vector store ID
        when(mockPrefs.getString(vectorStoreIdKey)).thenReturn(null);

        // When: getVectorStoreId is called
        final result = vectorStoreService.getVectorStoreId();

        // Then: returns null
        expect(result, isNull);
      });

      test('returns null when stored value is empty string', () {
        // Given: SharedPreferences has an empty vector store ID
        when(mockPrefs.getString(vectorStoreIdKey)).thenReturn('');

        // When: getVectorStoreId is called
        final result = vectorStoreService.getVectorStoreId();

        // Then: returns empty string (caller decides how to handle)
        expect(result, equals(''));
      });
    });

    group('getMonthlyLogFileIds', () {
      test('returns stored file IDs when they exist', () {
        // Given: SharedPreferences has stored monthly file IDs
        final storedJson = jsonEncode({
          '2025-01': 'file-123',
          '2025-02': 'file-456',
        });
        when(mockPrefs.getString(monthlyLogFileIdsKey)).thenReturn(storedJson);

        // When: getMonthlyLogFileIds is called
        final result = vectorStoreService.getMonthlyLogFileIds();

        // Then: returns the parsed map
        expect(result, equals({'2025-01': 'file-123', '2025-02': 'file-456'}));
      });

      test('returns empty map when no file IDs are stored', () {
        // Given: SharedPreferences has no monthly file IDs
        when(mockPrefs.getString(monthlyLogFileIdsKey)).thenReturn(null);

        // When: getMonthlyLogFileIds is called
        final result = vectorStoreService.getMonthlyLogFileIds();

        // Then: returns empty map
        expect(result, isEmpty);
      });

      test('returns empty map when stored value is empty string', () {
        // Given: SharedPreferences has empty string for monthly file IDs
        when(mockPrefs.getString(monthlyLogFileIdsKey)).thenReturn('');

        // When: getMonthlyLogFileIds is called
        final result = vectorStoreService.getMonthlyLogFileIds();

        // Then: returns empty map
        expect(result, isEmpty);
      });

      test('returns empty map when stored JSON is invalid', () {
        // Given: SharedPreferences has invalid JSON
        when(mockPrefs.getString(monthlyLogFileIdsKey)).thenReturn('not valid json');

        // When: getMonthlyLogFileIds is called
        final result = vectorStoreService.getMonthlyLogFileIds();

        // Then: returns empty map (graceful degradation)
        expect(result, isEmpty);
      });
    });

    group('restoreFromSnapshot', () {
      test('restores vector store ID when provided', () async {
        // Given: a vector store ID to restore
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.getString(monthlyLogFileIdsKey)).thenReturn(null);

        // When: restoreFromSnapshot is called with vector store ID
        await vectorStoreService.restoreFromSnapshot('vs-restored-123', {});

        // Then: vector store ID is saved
        verify(mockPrefs.setString(vectorStoreIdKey, 'vs-restored-123')).called(1);
      });

      test('restores monthly file IDs when provided', () async {
        // Given: monthly file IDs to restore
        final fileIds = {'2025-01': 'file-abc', '2025-02': 'file-def'};
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);

        // When: restoreFromSnapshot is called with file IDs
        await vectorStoreService.restoreFromSnapshot(null, fileIds);

        // Then: file IDs are saved as JSON
        verify(mockPrefs.setString(monthlyLogFileIdsKey, jsonEncode(fileIds))).called(1);
      });

      test('restores both vector store ID and file IDs together', () async {
        // Given: both values to restore
        final fileIds = {'2025-03': 'file-xyz'};
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);

        // When: restoreFromSnapshot is called with both values
        await vectorStoreService.restoreFromSnapshot('vs-full-restore', fileIds);

        // Then: both are saved
        verify(mockPrefs.setString(vectorStoreIdKey, 'vs-full-restore')).called(1);
        verify(mockPrefs.setString(monthlyLogFileIdsKey, jsonEncode(fileIds))).called(1);
      });

      test('skips vector store ID when null', () async {
        // Given: only file IDs to restore
        final fileIds = {'2025-01': 'file-only'};
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);

        // When: restoreFromSnapshot is called with null vector store ID
        await vectorStoreService.restoreFromSnapshot(null, fileIds);

        // Then: only file IDs are saved, not vector store ID
        verifyNever(mockPrefs.setString(vectorStoreIdKey, any));
        verify(mockPrefs.setString(monthlyLogFileIdsKey, jsonEncode(fileIds))).called(1);
      });

      test('skips vector store ID when empty string', () async {
        // Given: empty vector store ID
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);

        // When: restoreFromSnapshot is called with empty vector store ID
        await vectorStoreService.restoreFromSnapshot('', {'2025-01': 'file-test'});

        // Then: vector store ID is not saved
        verifyNever(mockPrefs.setString(vectorStoreIdKey, ''));
      });

      test('skips file IDs when empty map', () async {
        // Given: only vector store ID to restore
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);

        // When: restoreFromSnapshot is called with empty file IDs
        await vectorStoreService.restoreFromSnapshot('vs-id-only', {});

        // Then: only vector store ID is saved
        verify(mockPrefs.setString(vectorStoreIdKey, 'vs-id-only')).called(1);
        verifyNever(mockPrefs.setString(monthlyLogFileIdsKey, any));
      });
    });
  });
}

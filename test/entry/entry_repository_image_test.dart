import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:myapp/entry/entry.dart';
import 'package:myapp/entry/repository/entry_repository.dart';
import 'package:myapp/services/timer_factory.dart';

import '../mocks.mocks.dart';

/// CP: Tests for EntryRepository image sync functionality
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockEntryPersistenceService mockPersistenceService;
  late MockAiService mockAiService;
  late MockVectorStoreService mockVectorStoreService;
  late MockImageStorageService mockImageStorageService;
  late MockImageStorageSyncService mockImageStorageSyncService;
  late MockFirestoreSyncService mockFirestoreSyncService;
  late EntryRepository repository;
  late Directory tempDir;

  setUp(() async {
    mockPersistenceService = MockEntryPersistenceService();
    mockAiService = MockAiService();
    mockVectorStoreService = MockVectorStoreService();
    mockImageStorageService = MockImageStorageService();
    mockImageStorageSyncService = MockImageStorageSyncService();
    mockFirestoreSyncService = MockFirestoreSyncService();

    // CP: Default stubs for persistence service
    when(mockPersistenceService.loadEntries()).thenAnswer((_) async => []);
    when(mockPersistenceService.loadCategories()).thenAnswer((_) async => []);
    when(mockPersistenceService.saveEntries(any)).thenAnswer((_) async {});
    when(mockPersistenceService.saveCategories(any)).thenAnswer((_) async {});

    // CP: Default stubs for cloud services - startListening takes a String uid
    when(mockFirestoreSyncService.startListening(any)).thenReturn(null);
    when(mockFirestoreSyncService.syncEntry(any, any)).thenAnswer((_) async {});
    when(mockFirestoreSyncService.syncCategory(any, any)).thenAnswer((_) async {});

    // CP: Create temp directory for file tests
    tempDir = Directory.systemTemp.createTempSync('entry_repo_image_test_');

    repository = EntryRepository(
      persistenceService: mockPersistenceService,
      aiService: mockAiService,
      vectorStoreService: mockVectorStoreService,
      timerFactory: _FakeTimerFactory(),
      imageStorageService: mockImageStorageService,
      imageStorageSyncService: mockImageStorageSyncService,
      firestoreSyncService: mockFirestoreSyncService,
    );
  });

  tearDown(() async {
    repository.dispose();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('downloadCloudImage', () {
    test(
      'Given entry without cloudImagePath, When downloadCloudImage called, Then returns existing imagePath',
      () async {
        // Given
        await repository.initialize();
        final entry = Entry(
          id: 'test-id',
          text: 'Test entry',
          timestamp: DateTime.now(),
          category: 'Work',
          imagePath: 'local/test.jpg',
        );

        // When
        final result = await repository.downloadCloudImage(entry);

        // Then
        expect(result, equals('local/test.jpg'));
        verifyNever(mockImageStorageSyncService.downloadImage(any, any));
      },
    );

    test(
      'Given entry with valid local cache, When downloadCloudImage called, Then returns cached path without downloading',
      () async {
        // Given
        await repository.initialize();
        final testFile = File('${tempDir.path}/cached.jpg');
        await testFile.writeAsBytes([0xFF, 0xD8, 0xFF]); // JPEG magic bytes

        final entry = Entry(
          id: 'test-id',
          text: 'Test entry',
          timestamp: DateTime.now(),
          category: 'Work',
          imagePath: 'cached.jpg',
          cloudImagePath: 'users/uid123/images/test-id.jpg',
        );

        when(mockImageStorageService.getFullPath('cached.jpg'))
            .thenAnswer((_) async => testFile.path);

        // When
        final result = await repository.downloadCloudImage(entry);

        // Then
        expect(result, equals('cached.jpg'));
        verifyNever(mockImageStorageSyncService.downloadImage(any, any));
      },
    );

    test(
      'Given entry with corrupted cache (0 bytes), When downloadCloudImage called, Then re-downloads from cloud',
      () async {
        // Given
        // Create empty file (corrupted)
        final corruptedFile = File('${tempDir.path}/corrupted.jpg');
        await corruptedFile.writeAsBytes([]);

        // Create path for download
        final downloadPath = '${tempDir.path}/test-id.jpg';

        final entry = Entry(
          id: 'test-id',
          text: 'Test entry',
          timestamp: DateTime.now(),
          category: 'Work',
          imagePath: 'corrupted.jpg',
          cloudImagePath: 'users/uid123/images/test-id.jpg',
        );

        // CP: Add entry to repository so it can be updated
        when(mockPersistenceService.loadEntries()).thenAnswer((_) async => [entry]);
        await repository.initialize();

        when(mockImageStorageService.getFullPath('corrupted.jpg'))
            .thenAnswer((_) async => corruptedFile.path);
        when(mockImageStorageService.getFullPath('test-id.jpg'))
            .thenAnswer((_) async => downloadPath);
        when(mockImageStorageSyncService.downloadImage(
          'users/uid123/images/test-id.jpg',
          downloadPath,
        )).thenAnswer((_) async => true);

        // When
        final result = await repository.downloadCloudImage(entry);

        // Then
        expect(result, equals('test-id.jpg'));
        verify(mockImageStorageSyncService.downloadImage(any, any)).called(1);
      },
    );

    test(
      'Given successful download, When downloadCloudImage called, Then updates entry and returns path',
      () async {
        // Given
        final downloadPath = '${tempDir.path}/new-download.jpg';
        final entry = Entry(
          id: 'test-id',
          text: 'Test entry',
          timestamp: DateTime.now(),
          category: 'Work',
          cloudImagePath: 'users/uid123/images/test-id.jpg',
        );

        // CP: Add entry to repository
        when(mockPersistenceService.loadEntries()).thenAnswer((_) async => [entry]);
        await repository.initialize();

        when(mockImageStorageService.getFullPath('test-id.jpg'))
            .thenAnswer((_) async => downloadPath);
        when(mockImageStorageSyncService.downloadImage(
          'users/uid123/images/test-id.jpg',
          downloadPath,
        )).thenAnswer((_) async => true);

        // When
        final result = await repository.downloadCloudImage(entry);

        // Then
        expect(result, equals('test-id.jpg'));
        verify(mockImageStorageSyncService.downloadImage(
          'users/uid123/images/test-id.jpg',
          downloadPath,
        )).called(1);

        // Verify entry was updated
        final updatedEntry = repository.currentEntries.firstWhere((e) => e.id == 'test-id');
        expect(updatedEntry.imagePath, equals('test-id.jpg'));
      },
    );

    test(
      'Given download fails, When downloadCloudImage called, Then returns null',
      () async {
        // Given
        final downloadPath = '${tempDir.path}/failed.jpg';
        final entry = Entry(
          id: 'test-id',
          text: 'Test entry',
          timestamp: DateTime.now(),
          category: 'Work',
          cloudImagePath: 'users/uid123/images/test-id.jpg',
        );

        when(mockPersistenceService.loadEntries()).thenAnswer((_) async => [entry]);
        await repository.initialize();

        when(mockImageStorageService.getFullPath('test-id.jpg'))
            .thenAnswer((_) async => downloadPath);
        when(mockImageStorageSyncService.downloadImage(any, any))
            .thenAnswer((_) async => false);

        // When
        final result = await repository.downloadCloudImage(entry);

        // Then
        expect(result, isNull);
      },
    );
  });
}

/// CP: Fake timer factory for testing - timers don't fire
class _FakeTimerFactory implements TimerFactory {
  @override
  Timer createTimer(Duration duration, void Function() callback) {
    // For testing, return a cancelled timer that doesn't fire
    return Timer(Duration.zero, () {});
  }
}

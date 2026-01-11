import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/services/snapshot_service.dart';
import 'package:myapp/entry/entry.dart';
import 'package:myapp/entry/category.dart';

void main() {
  group('Snapshot', () {
    test('creates snapshot with required fields', () {
      // Given: required data for a snapshot
      final entries = [
        Entry(
          text: 'Test entry',
          timestamp: DateTime(2025, 1, 1, 12, 0),
          category: 'Work',
        ),
      ];
      final categories = [
        const Category(name: 'Work', description: 'Work tasks'),
      ];
      final createdAt = DateTime(2025, 1, 10, 10, 0);

      // When: snapshot is created
      final snapshot = Snapshot(
        deviceId: 'device-123',
        entries: entries,
        categories: categories,
        createdAt: createdAt,
      );

      // Then: all fields are set correctly
      expect(snapshot.deviceId, equals('device-123'));
      expect(snapshot.entries.length, equals(1));
      expect(snapshot.categories.length, equals(1));
      expect(snapshot.entryCount, equals(1));
      expect(snapshot.categoryCount, equals(1));
      expect(snapshot.createdAt, equals(createdAt));
      expect(snapshot.expiresAt, isNull);
      expect(snapshot.vectorStoreId, isNull);
      expect(snapshot.monthlyLogFileIds, isEmpty);
    });

    test('creates snapshot with optional vector store data', () {
      // Given: snapshot with vector store info
      final snapshot = Snapshot(
        deviceId: 'device-123',
        entries: [],
        categories: [],
        vectorStoreId: 'vs-abc123',
        monthlyLogFileIds: {'2025-01': 'file-123', '2025-02': 'file-456'},
        createdAt: DateTime.now(),
      );

      // Then: vector store data is preserved
      expect(snapshot.vectorStoreId, equals('vs-abc123'));
      expect(snapshot.monthlyLogFileIds.length, equals(2));
      expect(snapshot.monthlyLogFileIds['2025-01'], equals('file-123'));
    });

    test('isExpired returns false when expiresAt is null', () {
      // Given: snapshot without expiration
      final snapshot = Snapshot(
        deviceId: 'device-123',
        entries: [],
        categories: [],
        createdAt: DateTime.now(),
        expiresAt: null,
      );

      // Then: snapshot is not expired
      expect(snapshot.isExpired, isFalse);
    });

    test('isExpired returns false when expiresAt is in the future', () {
      // Given: snapshot with future expiration
      final snapshot = Snapshot(
        deviceId: 'device-123',
        entries: [],
        categories: [],
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 7)),
      );

      // Then: snapshot is not expired
      expect(snapshot.isExpired, isFalse);
    });

    test('isExpired returns true when expiresAt is in the past', () {
      // Given: snapshot with past expiration
      final snapshot = Snapshot(
        deviceId: 'device-123',
        entries: [],
        categories: [],
        createdAt: DateTime.now().subtract(const Duration(days: 14)),
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
      );

      // Then: snapshot is expired
      expect(snapshot.isExpired, isTrue);
    });

    test('entryCount and categoryCount return correct counts', () {
      // Given: snapshot with multiple entries and categories
      final entries = List.generate(
        5,
        (i) => Entry(
          text: 'Entry $i',
          timestamp: DateTime.now(),
          category: 'Misc',
        ),
      );
      final categories = [
        const Category(name: 'Work'),
        const Category(name: 'Personal'),
        const Category(name: 'Health'),
      ];

      final snapshot = Snapshot(
        deviceId: 'device-123',
        entries: entries,
        categories: categories,
        createdAt: DateTime.now(),
      );

      // Then: counts are correct
      expect(snapshot.entryCount, equals(5));
      expect(snapshot.categoryCount, equals(3));
    });
  });
}

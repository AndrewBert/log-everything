import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/entry/entry.dart';

void main() {
  group('Entry cloudImagePath', () {
    final testDate = DateTime(2024, 1, 15, 10, 30);

    group('JSON serialization', () {
      test(
        'Given entry with cloudImagePath, When toJson called, Then cloudImagePath is included',
        () {
          // Given
          final entry = Entry(
            text: 'Test entry',
            timestamp: testDate,
            category: 'Work',
            imagePath: 'images/test.jpg',
            cloudImagePath: 'users/uid123/images/abc-123.jpg',
          );

          // When
          final json = entry.toJson();

          // Then
          expect(json['cloudImagePath'], equals('users/uid123/images/abc-123.jpg'));
          expect(json['imagePath'], equals('images/test.jpg'));
        },
      );

      test(
        'Given entry without cloudImagePath, When toJson called, Then cloudImagePath is null',
        () {
          // Given
          final entry = Entry(
            text: 'Test entry',
            timestamp: testDate,
            category: 'Work',
            imagePath: 'images/test.jpg',
          );

          // When
          final json = entry.toJson();

          // Then
          expect(json['cloudImagePath'], isNull);
          expect(json['imagePath'], equals('images/test.jpg'));
        },
      );

      test(
        'Given JSON with cloudImagePath, When fromJson called, Then cloudImagePath is parsed',
        () {
          // Given
          final json = {
            'text': 'Test entry',
            'timestamp': testDate.toIso8601String(),
            'category': 'Work',
            'imagePath': 'images/test.jpg',
            'cloudImagePath': 'users/uid123/images/abc-123.jpg',
          };

          // When
          final entry = Entry.fromJson(json);

          // Then
          expect(entry.cloudImagePath, equals('users/uid123/images/abc-123.jpg'));
          expect(entry.imagePath, equals('images/test.jpg'));
        },
      );

      test(
        'Given JSON without cloudImagePath, When fromJson called, Then cloudImagePath is null',
        () {
          // Given
          final json = {
            'text': 'Test entry',
            'timestamp': testDate.toIso8601String(),
            'category': 'Work',
            'imagePath': 'images/test.jpg',
          };

          // When
          final entry = Entry.fromJson(json);

          // Then
          expect(entry.cloudImagePath, isNull);
          expect(entry.imagePath, equals('images/test.jpg'));
        },
      );
    });

    group('copyWith', () {
      test(
        'Given entry without cloudImagePath, When copyWith with cloudImagePath, Then cloudImagePath is updated',
        () {
          // Given
          final entry = Entry(
            text: 'Test entry',
            timestamp: testDate,
            category: 'Work',
            imagePath: 'images/test.jpg',
          );

          // When
          final updated = entry.copyWith(
            cloudImagePath: 'users/uid123/images/abc-123.jpg',
          );

          // Then
          expect(updated.cloudImagePath, equals('users/uid123/images/abc-123.jpg'));
          expect(updated.imagePath, equals('images/test.jpg'));
          // Original unchanged
          expect(entry.cloudImagePath, isNull);
        },
      );

      test(
        'Given entry with cloudImagePath, When copyWith with clearCloudImagePath true, Then cloudImagePath is null',
        () {
          // Given
          final entry = Entry(
            text: 'Test entry',
            timestamp: testDate,
            category: 'Work',
            imagePath: 'images/test.jpg',
            cloudImagePath: 'users/uid123/images/abc-123.jpg',
          );

          // When
          final updated = entry.copyWith(clearCloudImagePath: true);

          // Then
          expect(updated.cloudImagePath, isNull);
          expect(updated.imagePath, equals('images/test.jpg'));
        },
      );

      test(
        'Given entry with cloudImagePath, When copyWith without cloudImagePath param, Then cloudImagePath is preserved',
        () {
          // Given
          final entry = Entry(
            text: 'Test entry',
            timestamp: testDate,
            category: 'Work',
            cloudImagePath: 'users/uid123/images/abc-123.jpg',
          );

          // When
          final updated = entry.copyWith(text: 'Updated text');

          // Then
          expect(updated.cloudImagePath, equals('users/uid123/images/abc-123.jpg'));
          expect(updated.text, equals('Updated text'));
        },
      );
    });

    group('Equatable', () {
      test(
        'Given two entries with same cloudImagePath, When compared, Then they are equal',
        () {
          // Given
          final entry1 = Entry(
            id: 'same-id',
            text: 'Test entry',
            timestamp: testDate,
            category: 'Work',
            cloudImagePath: 'users/uid123/images/abc-123.jpg',
          );
          final entry2 = Entry(
            id: 'same-id',
            text: 'Test entry',
            timestamp: testDate,
            category: 'Work',
            cloudImagePath: 'users/uid123/images/abc-123.jpg',
          );

          // Then
          expect(entry1, equals(entry2));
          expect(entry1.hashCode, equals(entry2.hashCode));
        },
      );

      test(
        'Given two entries with different cloudImagePath, When compared, Then they are not equal',
        () {
          // Given
          final entry1 = Entry(
            id: 'same-id',
            text: 'Test entry',
            timestamp: testDate,
            category: 'Work',
            cloudImagePath: 'users/uid123/images/abc-123.jpg',
          );
          final entry2 = Entry(
            id: 'same-id',
            text: 'Test entry',
            timestamp: testDate,
            category: 'Work',
            cloudImagePath: 'users/uid123/images/different.jpg',
          );

          // Then
          expect(entry1, isNot(equals(entry2)));
        },
      );

      test(
        'Given entry with cloudImagePath and entry without, When compared, Then they are not equal',
        () {
          // Given
          final entry1 = Entry(
            id: 'same-id',
            text: 'Test entry',
            timestamp: testDate,
            category: 'Work',
            cloudImagePath: 'users/uid123/images/abc-123.jpg',
          );
          final entry2 = Entry(
            id: 'same-id',
            text: 'Test entry',
            timestamp: testDate,
            category: 'Work',
          );

          // Then
          expect(entry1, isNot(equals(entry2)));
        },
      );
    });
  });
}

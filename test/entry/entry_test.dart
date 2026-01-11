import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/entry/entry.dart';
import 'package:myapp/dashboard_v2/model/insight.dart';
import 'package:myapp/dashboard_v2/model/simple_insight.dart';

void main() {
  group('Entry', () {
    final testDate = DateTime(2024, 1, 15, 10, 30);

    group('JSON serialization with simpleInsight', () {
      test('should serialize with both old and new insight formats', () {
        final entry = Entry(
          text: 'Test entry',
          timestamp: testDate,
          category: 'Work',
          insight: ComprehensiveInsight(
            entryId: 'test-id',
            entryText: 'Test entry',
            insights: [],
            generatedAt: testDate,
          ),
          simpleInsight: SimpleInsight(
            content: 'Nice work!',
            generatedAt: testDate,
          ),
        );

        final json = entry.toJson();

        expect(json['insight'], isNotNull);
        expect(json['simpleInsight'], isNotNull);
        expect(json['simpleInsight']['content'], 'Nice work!');
      });

      test('should deserialize old format only', () {
        final json = {
          'text': 'Test entry',
          'timestamp': testDate.toIso8601String(),
          'category': 'Work',
          'insight': {
            'entryId': 'test-id',
            'entryText': 'Test entry',
            'insights': [],
            'generatedAt': testDate.toIso8601String(),
          },
        };

        final entry = Entry.fromJson(json);

        expect(entry.insight, isNotNull);
        expect(entry.simpleInsight, isNull);
      });

      test('should deserialize new format only', () {
        final json = {
          'text': 'Test entry',
          'timestamp': testDate.toIso8601String(),
          'category': 'Work',
          'simpleInsight': {
            'content': 'Nice work!',
            'generatedAt': testDate.toIso8601String(),
          },
        };

        final entry = Entry.fromJson(json);

        expect(entry.insight, isNull);
        expect(entry.simpleInsight, isNotNull);
        expect(entry.simpleInsight!.content, 'Nice work!');
      });

      test('should deserialize with both formats', () {
        final json = {
          'text': 'Test entry',
          'timestamp': testDate.toIso8601String(),
          'category': 'Work',
          'insight': {
            'entryId': 'test-id',
            'entryText': 'Test entry',
            'insights': [],
            'generatedAt': testDate.toIso8601String(),
          },
          'simpleInsight': {
            'content': 'Nice work!',
            'generatedAt': testDate.toIso8601String(),
          },
        };

        final entry = Entry.fromJson(json);

        expect(entry.insight, isNotNull);
        expect(entry.simpleInsight, isNotNull);
      });
    });

    group('getCurrentInsight', () {
      test('should prefer new format when both exist', () {
        final entry = Entry(
          text: 'Test entry',
          timestamp: testDate,
          category: 'Work',
          insight: ComprehensiveInsight(
            entryId: 'test-id',
            entryText: 'Test entry',
            insights: [
              Insight(
                id: '1',
                type: InsightType.summary,
                title: 'Summary',
                content: 'Old insight content',
                generatedAt: testDate,
              ),
            ],
            generatedAt: testDate,
          ),
          simpleInsight: SimpleInsight(
            content: 'New insight content',
            generatedAt: testDate,
          ),
        );

        final current = entry.getCurrentInsight();

        expect(current, isNotNull);
        expect(current!.content, 'New insight content');
      });

      test('should convert old format when new format not present', () {
        final entry = Entry(
          text: 'Test entry',
          timestamp: testDate,
          category: 'Work',
          insight: ComprehensiveInsight(
            entryId: 'test-id',
            entryText: 'Test entry',
            insights: [
              Insight(
                id: '1',
                type: InsightType.summary,
                title: 'Summary',
                content: 'Old insight content',
                generatedAt: testDate,
              ),
            ],
            generatedAt: testDate,
          ),
        );

        final current = entry.getCurrentInsight();

        expect(current, isNotNull);
        expect(current!.content, 'Old insight content');
      });

      test('should return null when neither format exists', () {
        final entry = Entry(
          text: 'Test entry',
          timestamp: testDate,
          category: 'Work',
        );

        final current = entry.getCurrentInsight();

        expect(current, isNull);
      });
    });

    group('copyWith with simpleInsight', () {
      test('should copy with new simpleInsight', () {
        final entry = Entry(
          text: 'Test entry',
          timestamp: testDate,
          category: 'Work',
        );

        final updated = entry.copyWith(
          simpleInsight: SimpleInsight(
            content: 'New insight',
            generatedAt: testDate,
          ),
        );

        expect(updated.simpleInsight, isNotNull);
        expect(updated.simpleInsight!.content, 'New insight');
      });

      test('should clear simpleInsight when clearSimpleInsight is true', () {
        final entry = Entry(
          text: 'Test entry',
          timestamp: testDate,
          category: 'Work',
          simpleInsight: SimpleInsight(
            content: 'Existing insight',
            generatedAt: testDate,
          ),
        );

        final updated = entry.copyWith(clearSimpleInsight: true);

        expect(updated.simpleInsight, isNull);
      });
    });

    group('hasImage', () {
      test('Given entry with local imagePath only, When hasImage called, Then returns true', () {
        final entry = Entry(
          text: 'Test entry',
          timestamp: testDate,
          category: 'Work',
          imagePath: 'local/test.jpg',
        );

        expect(entry.hasImage, isTrue);
      });

      test('Given entry with cloudImagePath only, When hasImage called, Then returns true', () {
        final entry = Entry(
          text: 'Test entry',
          timestamp: testDate,
          category: 'Work',
          cloudImagePath: 'users/uid123/images/test.jpg',
        );

        expect(entry.hasImage, isTrue);
      });

      test('Given entry with both imagePath and cloudImagePath, When hasImage called, Then returns true', () {
        final entry = Entry(
          text: 'Test entry',
          timestamp: testDate,
          category: 'Work',
          imagePath: 'local/test.jpg',
          cloudImagePath: 'users/uid123/images/test.jpg',
        );

        expect(entry.hasImage, isTrue);
      });

      test('Given entry with neither imagePath nor cloudImagePath, When hasImage called, Then returns false', () {
        final entry = Entry(
          text: 'Test entry',
          timestamp: testDate,
          category: 'Work',
        );

        expect(entry.hasImage, isFalse);
      });
    });
  });
}

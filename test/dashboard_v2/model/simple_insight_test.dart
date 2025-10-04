import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/dashboard_v2/model/simple_insight.dart';

void main() {
  group('SimpleInsight', () {
    final testDate = DateTime(2024, 1, 15, 10, 30);
    final testInsight = SimpleInsight(
      content: 'Nice work on that project! 🎉',
      generatedAt: testDate,
    );

    group('JSON serialization', () {
      test('toJson should serialize correctly', () {
        final json = testInsight.toJson();

        expect(json['content'], 'Nice work on that project! 🎉');
        expect(json['generatedAt'], testDate.toIso8601String());
      });

      test('fromJson should deserialize correctly', () {
        final json = {
          'content': 'Nice work on that project! 🎉',
          'generatedAt': testDate.toIso8601String(),
        };

        final insight = SimpleInsight.fromJson(json);

        expect(insight.content, 'Nice work on that project! 🎉');
        expect(insight.generatedAt, testDate);
      });

      test('round trip serialization should preserve data', () {
        final json = testInsight.toJson();
        final deserialized = SimpleInsight.fromJson(json);

        expect(deserialized, testInsight);
      });
    });

    group('equality', () {
      test('should be equal when content and date are the same', () {
        final insight1 = SimpleInsight(
          content: 'Test content',
          generatedAt: testDate,
        );
        final insight2 = SimpleInsight(
          content: 'Test content',
          generatedAt: testDate,
        );

        expect(insight1, insight2);
      });

      test('should not be equal when content differs', () {
        final insight1 = SimpleInsight(
          content: 'Content 1',
          generatedAt: testDate,
        );
        final insight2 = SimpleInsight(
          content: 'Content 2',
          generatedAt: testDate,
        );

        expect(insight1, isNot(insight2));
      });

      test('should not be equal when date differs', () {
        final insight1 = SimpleInsight(
          content: 'Same content',
          generatedAt: testDate,
        );
        final insight2 = SimpleInsight(
          content: 'Same content',
          generatedAt: testDate.add(Duration(hours: 1)),
        );

        expect(insight1, isNot(insight2));
      });
    });

    group('toString', () {
      test('should include content', () {
        final str = testInsight.toString();

        expect(str, contains('SimpleInsight'));
        expect(str, contains('Nice work on that project! 🎉'));
      });
    });
  });
}

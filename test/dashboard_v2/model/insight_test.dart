import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/dashboard_v2/model/insight.dart';
import 'package:myapp/dashboard_v2/model/simple_insight.dart';

void main() {
  group('ComprehensiveInsight', () {
    final testDate = DateTime(2024, 1, 15, 10, 30);

    group('toSimpleInsight', () {
      test('should use recommendation when present', () {
        final comprehensiveInsight = ComprehensiveInsight(
          entryId: 'test-id',
          entryText: 'Test entry',
          insights: [
            Insight(
              id: '1',
              type: InsightType.summary,
              title: 'Summary',
              content: 'This is a summary',
              generatedAt: testDate,
            ),
            Insight(
              id: '2',
              type: InsightType.recommendation,
              title: 'Recommendation',
              content: 'Try this approach!',
              generatedAt: testDate,
            ),
          ],
          generatedAt: testDate,
        );

        final simpleInsight = comprehensiveInsight.toSimpleInsight();

        expect(simpleInsight.content, 'Try this approach!');
        expect(simpleInsight.generatedAt, testDate);
      });

      test('should use summary when no recommendation', () {
        final comprehensiveInsight = ComprehensiveInsight(
          entryId: 'test-id',
          entryText: 'Test entry',
          insights: [
            Insight(
              id: '1',
              type: InsightType.summary,
              title: 'Summary',
              content: 'This is a summary',
              generatedAt: testDate,
            ),
            Insight(
              id: '2',
              type: InsightType.emotion,
              title: 'Emotion',
              content: 'Feeling happy',
              generatedAt: testDate,
            ),
          ],
          generatedAt: testDate,
        );

        final simpleInsight = comprehensiveInsight.toSimpleInsight();

        expect(simpleInsight.content, 'This is a summary');
        expect(simpleInsight.generatedAt, testDate);
      });

      test('should fallback to "No insight available" when empty insights', () {
        final comprehensiveInsight = ComprehensiveInsight(
          entryId: 'test-id',
          entryText: 'Test entry',
          insights: [],
          generatedAt: testDate,
        );

        final simpleInsight = comprehensiveInsight.toSimpleInsight();

        expect(simpleInsight.content, 'No insight available');
        expect(simpleInsight.generatedAt, testDate);
      });

      test('should fallback when recommendation is empty string', () {
        final comprehensiveInsight = ComprehensiveInsight(
          entryId: 'test-id',
          entryText: 'Test entry',
          insights: [
            Insight(
              id: '1',
              type: InsightType.summary,
              title: 'Summary',
              content: 'This is a summary',
              generatedAt: testDate,
            ),
            Insight(
              id: '2',
              type: InsightType.recommendation,
              title: 'Recommendation',
              content: '',
              generatedAt: testDate,
            ),
          ],
          generatedAt: testDate,
        );

        final simpleInsight = comprehensiveInsight.toSimpleInsight();

        expect(simpleInsight.content, 'This is a summary');
        expect(simpleInsight.generatedAt, testDate);
      });
    });
  });
}

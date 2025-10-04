# Insights Simplification - Implementation Plan

## Overview
This plan details the step-by-step implementation to migrate from the complex `ComprehensiveInsight` system (5 insight types, vector store searches, complex prompts) to a simplified `SimpleInsight` system (single insight string, minimal prompt, optional vector store).

## Final Design Decisions

### Data Structure
```dart
class SimpleInsight extends Equatable {
  final String content;           // "Nice work on that project! 🎉"
  final DateTime generatedAt;

  const SimpleInsight({
    required this.content,
    required this.generatedAt,
  });

  @override
  List<Object?> get props => [content, generatedAt];
}
```

**Rationale:**
- No type field needed - tone is conveyed in the text itself
- Minimal structure = fewer tokens, simpler code
- Extensible if needed later (can add optional fields)

### AI Response Format
```json
{
  "content": "Nice work on that project! 🎉"
}
```

Uses existing OpenAI API structure with simplified JSON response.

### Backwards Compatibility Strategy
- Keep old `ComprehensiveInsight? insight` field in Entry
- Add new `SimpleInsight? simpleInsight` field in Entry
- Provide migration helper to convert old → new on-the-fly
- Remove old field in future cleanup PR (after 1-2 weeks)

### Vector Store
- Keep infrastructure (SharedPreferences, tools config)
- Don't use in new insight generation (skip the search)
- Easy to re-enable later if pattern detection is desired

## Implementation Steps

### Step 1: Create SimpleInsight Model

**File:** `lib/dashboard_v2/model/simple_insight.dart`

```dart
import 'package:equatable/equatable.dart';

class SimpleInsight extends Equatable {
  final String content;
  final DateTime generatedAt;

  const SimpleInsight({
    required this.content,
    required this.generatedAt,
  });

  @override
  List<Object?> get props => [content, generatedAt];

  // JSON serialization
  Map<String, dynamic> toJson() => {
    'content': content,
    'generatedAt': generatedAt.toIso8601String(),
  };

  factory SimpleInsight.fromJson(Map<String, dynamic> json) => SimpleInsight(
    content: json['content'] as String,
    generatedAt: DateTime.parse(json['generatedAt'] as String),
  );

  @override
  String toString() => 'SimpleInsight(content: $content)';
}
```

**Tests to add:** `test/dashboard_v2/model/simple_insight_test.dart`
- Test JSON serialization
- Test JSON deserialization
- Test equality comparison
- Test toString

---

### Step 2: Add Migration Helper to ComprehensiveInsight

**File:** `lib/dashboard_v2/model/insight.dart`

Add this method to the `ComprehensiveInsight` class:

```dart
import 'simple_insight.dart'; // Add import at top

// Add to ComprehensiveInsight class
SimpleInsight toSimpleInsight() {
  // Priority: recommendation > summary > first available
  final primaryInsight = getPrimaryInsight();

  final content = primaryInsight?.content ?? 'No insight available';

  return SimpleInsight(
    content: content,
    generatedAt: generatedAt,
  );
}
```

**Tests to add:** `test/dashboard_v2/model/insight_test.dart`
- Test migration with recommendation present
- Test migration with only summary
- Test migration with empty insights
- Test fallback to "No insight available"

---

### Step 3: Update Entry Model

**File:** `lib/entry/entry.dart`

1. Add import:
```dart
import '../dashboard_v2/model/simple_insight.dart';
```

2. Add new field to Entry class:
```dart
class Entry extends Equatable {
  final String text;
  final DateTime timestamp;
  final String category;
  final bool isNew;
  final bool isCompleted;
  final bool isTask;
  final ComprehensiveInsight? insight;        // OLD - keep for backwards compat
  final SimpleInsight? simpleInsight;         // NEW - preferred format

  const Entry({
    required this.text,
    required this.timestamp,
    required this.category,
    this.isNew = false,
    this.isCompleted = false,
    this.isTask = false,
    this.insight,
    this.simpleInsight,  // Add parameter
  });
```

3. Update `fromJson()`:
```dart
factory Entry.fromJson(Map<String, dynamic> json) {
  // Parse old format (for backwards compatibility)
  ComprehensiveInsight? oldInsight;
  if (json['insight'] != null) {
    oldInsight = ComprehensiveInsight.fromJson(json['insight'] as Map<String, dynamic>);
  }

  // Parse new format
  SimpleInsight? newInsight;
  if (json['simpleInsight'] != null) {
    newInsight = SimpleInsight.fromJson(json['simpleInsight'] as Map<String, dynamic>);
  }

  return Entry(
    text: json['text'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    category: json['category'] as String? ?? 'Unknown',
    isNew: json['isNew'] as bool? ?? false,
    isCompleted: json['isCompleted'] as bool? ?? false,
    isTask: json['isTask'] as bool? ?? false,
    insight: oldInsight,
    simpleInsight: newInsight,
  );
}
```

4. Update `toJson()`:
```dart
Map<String, dynamic> toJson() {
  return {
    'text': text,
    'timestamp': timestamp.toIso8601String(),
    'category': category,
    'isNew': isNew,
    'isCompleted': isCompleted,
    'isTask': isTask,
    'insight': insight?.toJson(),              // Keep old format for now
    'simpleInsight': simpleInsight?.toJson(),   // Add new format
  };
}
```

5. Update `copyWith()`:
```dart
Entry copyWith({
  String? text,
  DateTime? timestamp,
  String? category,
  bool? isNew,
  bool? isCompleted,
  bool? isTask,
  ComprehensiveInsight? insight,
  bool clearInsight = false,
  SimpleInsight? simpleInsight,
  bool clearSimpleInsight = false,
}) {
  return Entry(
    text: text ?? this.text,
    timestamp: timestamp ?? this.timestamp,
    category: category ?? this.category,
    isNew: isNew ?? this.isNew,
    isCompleted: isCompleted ?? this.isCompleted,
    isTask: isTask ?? this.isTask,
    insight: clearInsight ? null : (insight ?? this.insight),
    simpleInsight: clearSimpleInsight ? null : (simpleInsight ?? this.simpleInsight),
  );
}
```

6. Add helper method:
```dart
/// Returns the current insight, preferring new format over old.
/// Converts old ComprehensiveInsight to SimpleInsight on-the-fly if needed.
SimpleInsight? getCurrentInsight() {
  // Prefer new format
  if (simpleInsight != null) return simpleInsight;

  // Fallback: convert old format on-the-fly
  if (insight != null) return insight!.toSimpleInsight();

  return null;
}
```

7. Update `props`:
```dart
@override
List<Object?> get props => [
  text,
  timestamp,
  category,
  isNew,
  isCompleted,
  isTask,
  insight,
  simpleInsight,  // Add to equality
];
```

**Tests to add/update:** `test/entry/entry_test.dart`
- Test JSON serialization with both formats
- Test JSON deserialization with old format only
- Test JSON deserialization with new format only
- Test JSON deserialization with both formats
- Test `getCurrentInsight()` prefers new format
- Test `getCurrentInsight()` converts old format
- Test `getCurrentInsight()` returns null when neither exists
- Test `copyWith()` with new fields

---

### Step 4: Update AI Service Interface

**File:** `lib/services/ai_service.dart`

1. Add import at top:
```dart
import '../dashboard_v2/model/simple_insight.dart';
```

2. Add new method to `AiService` interface (keep old one for now):
```dart
/// Generates a simple, playful insight for a log entry.
///
/// Takes the [entryText] to analyze and [entryId] for identification.
/// Optionally takes [currentDate] to provide temporal context.
/// Returns a [SimpleInsight] with a brief (1-2 sentence) helpful insight.
///
/// The AI uses a playful, friendly tone by default, with sensitivity on
/// serious topics (health, anxiety, relationships).
///
/// Note: This method does NOT use vector store search for pattern detection.
/// Historical pattern analysis may be added in a future update.
Future<SimpleInsight> generateSimpleInsight(
  String entryText,
  String entryId,
  {DateTime? currentDate}
);
```

---

### Step 5: Implement New AI Service Method

**File:** `lib/services/ai_service.dart`

Add this implementation to the `OpenAiService` class:

```dart
@override
Future<SimpleInsight> generateSimpleInsight(
  String entryText,
  String entryId,
  {DateTime? currentDate}
) async {
  if (_apiKey == 'YOUR_API_KEY_NOT_FOUND') {
    throw AiServiceException('OpenAI API Key not found.');
  }

  AppLogger.info(
    "Generating simple insight for entry: '${entryText.substring(0, entryText.length > 50 ? 50 : entryText.length)}...'",
  );

  final dateString = currentDate != null
    ? " Today's date is ${currentDate.toLocal().toString().split(' ')[0]}."
    : "";

  final prompt = '''Analyze this log entry and provide a brief, helpful insight.

"$entryText"

Default tone: Playful and warm, like a witty friend who cares.
Be helpful when there's something actionable. Be encouraging for wins.
Avoid sarcasm on sensitive topics (health issues, sadness, anxiety, relationships).

Keep it to 1-2 sentences max.

Return ONLY a JSON object with this structure:
{
  "content": "Your brief insight here"
}''';

  final systemContent = "You are a helpful assistant that provides brief, engaging insights on personal log entries. Keep responses to 1-2 sentences for display on small UI cards.$dateString";

  final requestBody = {
    'model': _defaultModelId,
    'input': [
      {
        'role': 'system',
        'content': systemContent,
      },
      {
        'role': 'user',
        'content': prompt,
      },
    ],
    'text': {
      'format': {
        'type': 'json_object',  // Use simple json_object format (not json_schema)
      },
    },
    'metadata': {
      'request_type': 'simple_insight_generation',
      'app_name': 'log-everything',
      'timestamp': DateTime.now().toIso8601String(),
      'model_used': _defaultModelId,
    },
  };

  // Note: NOT including vector store tools - no historical pattern analysis

  AppLogger.info('Sending simple insight request with model: ${requestBody['model']}');

  try {
    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode(requestBody),
    );

    AppLogger.info('Simple insight API response received. Status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final responseBody = jsonDecode(response.body);

      if (responseBody['status'] != 'completed' || responseBody['error'] != null) {
        final errorMsg =
            'OpenAI request failed or returned an error. Status: ${responseBody['status']}. Error: ${responseBody['error']}';
        AppLogger.error(errorMsg);
        throw AiServiceException(errorMsg);
      }

      // Parse response (same structure as other methods)
      if (responseBody['output'] != null &&
          responseBody['output'] is List &&
          (responseBody['output'] as List).isNotEmpty) {

        Map<String, dynamic>? messageOutputElement;
        for (final item in responseBody['output'] as List) {
          if (item is Map<String, dynamic> && item['type'] == 'message') {
            messageOutputElement = item;
            break;
          }
        }

        if (messageOutputElement != null) {
          final dynamic content = messageOutputElement['content'];
          if (content != null && content is List && content.isNotEmpty) {
            String? jsonOutputString;
            for (final item in content) {
              if (item is Map<String, dynamic> &&
                  item['type'] == 'output_text' &&
                  item['text'] != null) {
                jsonOutputString = item['text'] as String;
                break;
              }
            }

            if (jsonOutputString != null) {
              AppLogger.info('Successfully generated simple insight');

              try {
                final json = jsonDecode(jsonOutputString);
                final content = json['content'] as String? ?? 'Insight generated.';

                return SimpleInsight(
                  content: content,
                  generatedAt: DateTime.now(),
                );
              } catch (e) {
                AppLogger.error('Failed to parse simple insight JSON', error: e);
                throw AiServiceException('Failed to parse insight response', underlyingError: e);
              }
            }
          }
        }
      }

      throw AiServiceException('Unexpected response format from OpenAI');
    } else {
      String errorMessage;
      try {
        final errorBody = jsonDecode(response.body);
        errorMessage = errorBody['error']?['message'] ?? 'Unknown error occurred';
      } catch (_) {
        errorMessage = 'HTTP ${response.statusCode}: ${response.body}';
      }
      AppLogger.error('Failed to generate simple insight. Status: ${response.statusCode}, Error: $errorMessage');
      throw AiServiceException(
        'Failed to generate insight: $errorMessage',
        underlyingError: response.body,
      );
    }
  } catch (e, stackTrace) {
    if (e is AiServiceException) {
      rethrow;
    }
    AppLogger.error('Error generating simple insight', error: e, stackTrace: stackTrace);
    throw AiServiceException(
      'Failed to generate insight: ${e.toString()}',
      underlyingError: e,
    );
  }
}
```

**Tests to add:** `test/services/ai_service_test.dart`
- Test successful insight generation
- Test API key missing
- Test API error handling
- Test JSON parsing
- Test fallback content when parsing fails

---

### Step 6: Update Entry Repository

**File:** `lib/entry/entry_repository.dart`

Find where `generateEntryInsights()` is called and update to use new method:

```dart
// OLD (find and replace):
final comprehensiveInsight = await _aiService.generateEntryInsights(
  entry.text,
  entryId,
  currentDate: DateTime.now(),
);

updatedEntry = entry.copyWith(insight: comprehensiveInsight);

// NEW:
final simpleInsight = await _aiService.generateSimpleInsight(
  entry.text,
  entryId,
  currentDate: DateTime.now(),
);

updatedEntry = entry.copyWith(simpleInsight: simpleInsight);
```

**Tests to update:** `test/entry/entry_repository_test.dart`
- Update mocks to return `SimpleInsight` instead of `ComprehensiveInsight`
- Verify new insight is stored in `simpleInsight` field
- Test that old entries with `insight` field still load correctly

---

### Step 7: Update UI Components

**Files to update:**
- `lib/dashboard_v2/widgets/insight_card.dart` (or wherever insights are displayed)

Find where insights are displayed and update to use `getCurrentInsight()`:

```dart
// OLD (find this pattern):
final insight = entry.insight?.getPrimaryInsight();
final insightText = insight?.content ?? 'No insight';

// NEW:
final insight = entry.getCurrentInsight();
final insightText = insight?.content ?? 'No insight';
```

**UI Styling:**
- Use a single icon for all insights (e.g., ✨ or 💡)
- Can detect emojis in content and adjust styling if needed
- Keep card design minimal and clean

**Tests to update:**
- Update widget tests to provide `SimpleInsight` instead of `ComprehensiveInsight`
- Test display with new format
- Test display with old format (should auto-convert)
- Test display with no insight

---

### Step 8: Update Mocks for Testing

**File:** `test/mocks.dart`

Update the `@GenerateMocks` annotation to include `SimpleInsight`:

```dart
@GenerateMocks([
  // ... existing mocks ...
  AiService, // This already exists, just ensure it includes new method
])
```

Then regenerate mocks:
```bash
dart run build_runner build --delete-conflicting-outputs
```

---

### Step 9: Integration Testing

**Tests to run:**
1. Create new entry → should generate `SimpleInsight`
2. Load old entry with `ComprehensiveInsight` → should display via `getCurrentInsight()`
3. Mixed entries (old + new) → both should display correctly
4. No insight → should handle gracefully
5. AI service errors → should handle gracefully

**Manual testing:**
1. Create several new entries with different tones (happy, sad, question, task)
2. Verify insights are brief (1-2 sentences)
3. Verify playful tone on casual entries
4. Verify sensitive tone on serious entries
5. Compare old vs new storage size in SharedPreferences

---

### Step 10: Measure Success

**Metrics to track:**
- [ ] Token usage per insight (compare old vs new)
- [ ] Insight generation speed (should be faster without vector store)
- [ ] Storage size reduction (JSON payload)
- [ ] User feedback on insight quality/personality

**Expected improvements:**
- ~50%+ reduction in tokens per insight generation
- ~75% reduction in storage size per insight
- Faster generation (no vector store search)
- More engaging/less robotic insights

---

## Future Cleanup (Separate PR)

After 1-2 weeks of testing the new system:

1. **Remove old insight field from Entry:**
   - Delete `ComprehensiveInsight? insight` field
   - Remove from `fromJson()`, `toJson()`, `copyWith()`, `props`
   - Rename `simpleInsight` → `insight` (simpler name)

2. **Delete old models:**
   - Delete `InsightType` enum
   - Delete `Insight` class
   - Delete `ComprehensiveInsight` class
   - Keep migration logic in git history for reference

3. **Remove old AI method:**
   - Delete `generateEntryInsights()` from `AiService` interface
   - Delete implementation from `OpenAiService`
   - Keep `generateSimpleInsight()` as the only insight method

4. **Update all tests:**
   - Remove tests for old models
   - Clean up any remaining references

---

## Rollback Plan

If issues arise with the new system:

1. **Immediate rollback:**
   - Revert to calling `generateEntryInsights()` in repository
   - UI will still work (both fields present in Entry)
   - No data loss (both formats stored)

2. **Partial rollback:**
   - Keep new model but adjust prompt
   - Can toggle between methods based on feature flag
   - Vector store can be re-enabled easily

3. **Data safety:**
   - Old insights preserved in storage
   - New insights in separate field
   - No destructive migrations until cleanup phase

---

## Timeline Estimate

- **Step 1-3** (Models & Migration): 1-2 hours
- **Step 4-5** (AI Service): 2-3 hours
- **Step 6-7** (Repository & UI): 2-3 hours
- **Step 8-9** (Testing): 2-4 hours
- **Total**: 7-12 hours of development

Plus 1-2 weeks of real-world testing before cleanup.

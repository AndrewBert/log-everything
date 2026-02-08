# Contract: AiService — Rephrase Toggle Prompt Selection

## No Interface Change

The `AiService.extractEntries()` abstract method signature remains unchanged:
```dart
Future<List<EntryPrototype>> extractEntries(
  String text,
  List<Category> categories,
);
```

## Implementation Change: OpenAiService.extractEntries()

The method reads the preference from `_prefs` and selects the appropriate system prompt:

```dart
// Read preference (default true for backwards compatibility)
final bool rephraseEnabled = _prefs.getBool('ai_rephrase_enabled') ?? true;

// Select prompt variant
final String textCleaningInstruction = rephraseEnabled
    ? 'Minimal text cleaning - remove filler words (um, uh) but preserve meaning.'
    : 'IMPORTANT: Return the user\'s text EXACTLY as written. Do NOT clean, rephrase, or remove any words (including filler words like um, uh). Preserve the original text verbatim in each text_segment.';
```

The `textCleaningInstruction` is interpolated into the system prompt at the position currently occupied by the hardcoded "Minimal text cleaning..." line (ai_service.dart:272).

## Behavioral Contract

| rephraseEnabled | Input | Expected text_segment |
|-----------------|-------|-----------------------|
| `true` | "um went to store uh to buy milk" | "Went to store to buy milk" |
| `false` | "um went to store uh to buy milk" | "um went to store uh to buy milk" |

In both cases, `category` and `is_task` detection remain unchanged.

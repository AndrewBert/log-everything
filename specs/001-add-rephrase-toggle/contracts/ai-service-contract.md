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

The method reads the preference from `_prefs` and selects between **two fully distinct system prompt strings**. This is NOT a single-line substitution — the entire prompt text differs to avoid contradictory instructions.

```dart
// Read preference (default true for backwards compatibility)
final bool rephraseEnabled = _prefs.getBool('ai_rephrase_enabled') ?? true;

// Select the full system prompt based on preference
final systemPrompt = rephraseEnabled
    ? _buildRephrasePrompt(categoriesListString)
    : _buildVerbatimPrompt(categoriesListString);
```

### Prompt Variant A: Rephrase enabled (current behavior)

This is the existing prompt, unchanged. Key characteristics:
- `"text: cleaned and organized version of the input"`
- `"Minimal text cleaning - remove filler words (um, uh) but preserve meaning."`
- Splitting examples show rephrased text

### Prompt Variant B: Verbatim mode (rephrase disabled)

A distinct prompt that is consistent throughout. **All** references to text cleaning, rephrasing, and organization are replaced:

Key differences from Variant A:
1. **Description line**: `"text: the exact text segment from the user's input, preserved verbatim"` (replaces "cleaned and organized version")
2. **Text handling instruction**: `"IMPORTANT: Return the user's text EXACTLY as written. Do NOT clean, rephrase, remove filler words, fix grammar, or change any wording. Copy the relevant text segment character-for-character from the input."` (replaces "Minimal text cleaning...")
3. **Splitting examples** show verbatim text preservation:
   ```
   Example: "Work was crazy today with like all these meetings... still need to finish the presentation ugh"
     -> Entry 1: "Work was crazy today with like all these meetings" (is_task: false)
     -> Entry 2: "still need to finish the presentation ugh" (is_task: true)
   ```
   Note: filler words ("like"), informal language ("ugh"), and original phrasing are all preserved.

### Why two full prompts instead of a line swap

The staff review identified that a single-line substitution creates contradictory instructions — the AI receives "return text EXACTLY as written" alongside "cleaned and organized version" and rephrased few-shot examples. Few-shot examples are extremely strong signals to LLMs and would likely override a single contradictory instruction. Two fully distinct prompts eliminate this conflict.

## Scope

This toggle affects ONLY `extractEntries()`. Other AI methods are NOT affected:
- `analyzeImage()` — always generates descriptions/titles (different purpose)
- `getChatResponse()` / `streamChatResponse()` — chat, not entry processing
- `generateEntryInsights()` / `generateSimpleInsight()` — insight generation
- `generatePromptSuggestions()` — prompt suggestions

## Testability Note

Since `OpenAiService` reads the preference from its injected `_prefs`, testing the two prompt paths requires mocking `SharedPreferences` at construction time. This is consistent with the existing pattern (vector store ID is read the same way). If a third preference is added to `OpenAiService` in the future, consider introducing a `PromptPreferences` object parameter to make dependencies explicit.

## Behavioral Contract

| rephraseEnabled | Input | Expected text_segment |
|-----------------|-------|-----------------------|
| `true` | "um went to store uh to buy milk" | "Went to store to buy milk" |
| `false` | "um went to store uh to buy milk" | "um went to store uh to buy milk" |
| `true` | "had coffee, need to call mom" | Split: "Had coffee" + "Call mom" |
| `false` | "had coffee, need to call mom" | Split: "had coffee" + "need to call mom" |

In all cases, `category` and `is_task` detection remain unchanged.

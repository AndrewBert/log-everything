# Tasks: AI Rephrase Toggle

**Input**: Design documents from `/specs/001-add-rephrase-toggle/`
**Prerequisites**: plan.md, research.md, data-model.md, contracts/

## Phase 3.1: State & Data Model

- [x] T001 Add `rephraseEnabled` field to `SettingsState` in `lib/settings/cubit/settings_state.dart`
  - Add `final bool rephraseEnabled` with default `true` to constructor
  - Add `bool? rephraseEnabled` parameter to `copyWith()`
  - Add `rephraseEnabled` to `props` list
  - Wire through in `copyWith` return: `rephraseEnabled: rephraseEnabled ?? this.rephraseEnabled`

- [x] T002 [P] Add widget key to `lib/utils/widget_keys.dart`
  - Add `const Key rephraseToggle = ValueKey('settings_rephrase_toggle');` (top-level const, matching existing pattern)

## Phase 3.2: Cubit Logic

- [x] T003 Add SharedPreferences dependency and `toggleRephrase()` to `SettingsCubit` in `lib/settings/cubit/settings_cubit.dart`
  - Add `final SharedPreferences _prefs;` field
  - Add `required SharedPreferences sharedPreferences` to constructor, assign to `_prefs`
  - In `_init()`, read preference: `final rephraseEnabled = _prefs.getBool('ai_rephrase_enabled') ?? true;` and include in the initial emit
  - Add `toggleRephrase()` method that flips `state.rephraseEnabled`, writes to `_prefs`, and emits new state

- [x] T004 Update `SettingsPage` to pass `SharedPreferences` to `SettingsCubit` in `lib/settings/pages/settings_page.dart`
  - Add `import 'package:shared_preferences/shared_preferences.dart';`
  - In the `BlocProvider` create callback, add `sharedPreferences: GetIt.instance<SharedPreferences>()` to the `SettingsCubit` constructor call

## Phase 3.3: AI Service — Two Distinct Prompts

- [x] T005 Create two fully distinct system prompt methods in `lib/services/ai_service.dart`
  - Extract the existing system prompt (lines 231-277) into a private method `String _buildRephrasePrompt(String categoriesListString)` — this is Variant A, unchanged
  - Create a new private method `String _buildVerbatimPrompt(String categoriesListString)` — Variant B with ALL rephrasing references replaced:
    - "cleaned and organized version of the input" → "the exact text segment from the user's input, preserved verbatim"
    - "Minimal text cleaning - remove filler words (um, uh) but preserve meaning." → "IMPORTANT: Return the user's text EXACTLY as written. Do NOT clean, rephrase, remove filler words, fix grammar, or change any wording. Copy the relevant text segment character-for-character from the input."
    - Rewrite the entry splitting example to show verbatim preservation:
      ```
      Example: "Work was crazy today with like all these meetings... still need to finish the presentation ugh"
        → Entry 1: "Work was crazy today with like all these meetings" (is_task: false)
        → Entry 2: "still need to finish the presentation ugh" (is_task: true)
      ```
  - In `extractEntries()`, read preference and select prompt:
    ```dart
    final bool rephraseEnabled = _prefs.getBool('ai_rephrase_enabled') ?? true;
    final systemPrompt = rephraseEnabled
        ? _buildRephrasePrompt(categoriesListString)
        : _buildVerbatimPrompt(categoriesListString);
    ```
  - Replace the inline `systemPrompt` variable assignment with the conditional call
  - **Critical**: Do NOT just swap one line — the entire prompt must be internally consistent (per staff review)

## Phase 3.4: UI — Settings Toggle

- [x] T006 Add rephrase toggle to `GeneralSection` in `lib/settings/widgets/general_section.dart`
  - Add imports: `SettingsCubit`, `widget_keys.dart` (for `rephraseToggle`)
  - Add a `BlocBuilder<SettingsCubit, SettingsState>` wrapping a `SwitchListTile` as the first item in the Column's children list (above "What's New")
  - Use `buildWhen: (prev, current) => prev.rephraseEnabled != current.rephraseEnabled` for targeted rebuilds
  - SwitchListTile properties:
    - `key: rephraseToggle`
    - `secondary: const Icon(Icons.auto_fix_high)`
    - `title: const Text('AI Text Cleanup')`
    - `subtitle: const Text('Let AI clean up filler words and rephrase your entries')`
    - `value: state.rephraseEnabled`
    - `onChanged: (_) => context.read<SettingsCubit>().toggleRephrase()`

## Phase 3.5: Polish & Validation

- [x] T007 Run `flutter analyze` to verify no lint errors or warnings introduced
- [ ] T008 User validates feature in running Flutter app per quickstart.md scenarios

## Dependencies

- T001 (state) before T003 (cubit) — cubit emits new state field
- T002 (widget key) is independent [P] — can run with T001
- T003 (cubit) before T004 (settings page) — page passes new constructor param
- T005 (AI service) is independent of T001-T004 — different file, no shared state
- T004 + T005 before T006 (UI) — UI needs cubit method + AI service ready
- T006 before T007 (analyze) — all code must be written first

## Parallel Execution Groups

```
# Group 1: Can run in parallel (different files, no dependencies)
T001: lib/settings/cubit/settings_state.dart
T002: lib/utils/widget_keys.dart

# Group 2: After T001 completes
T003: lib/settings/cubit/settings_cubit.dart

# Group 3: Can run in parallel (independent files, T003 must be done for T004)
T004: lib/settings/pages/settings_page.dart
T005: lib/services/ai_service.dart

# Group 4: After T004 + T005 complete
T006: lib/settings/widgets/general_section.dart

# Group 5: After all code tasks
T007: flutter analyze
T008: User validation
```

## Validation Checklist

- [ ] SettingsState extends Equatable with `rephraseEnabled` in props
- [ ] SettingsCubit uses `part`/`part of` with state file
- [ ] No services registered in GetIt for this feature (SharedPreferences already registered)
- [ ] Cubit provided via BlocProvider (not GetIt)
- [ ] Widget key defined as top-level const in utils file
- [ ] Two fully distinct prompts (not a line swap)
- [ ] `flutter analyze` passes

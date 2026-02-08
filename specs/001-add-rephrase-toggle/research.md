# Research: AI Rephrase Toggle

## Decision 1: Where to store the preference
**Decision**: SharedPreferences via the existing key-value store pattern.
**Rationale**: The app already uses SharedPreferences for all persistent settings (vector store IDs, category colors, onboarding state). Adding a boolean key is trivial and consistent.
**Alternatives considered**:
- Firestore cloud sync for the preference — rejected; this is a device-level preference, not user data. Different devices may want different settings.
- Dedicated PreferencesService — rejected; over-engineering for a single boolean.

## Decision 2: How the preference reaches the AI prompt
**Decision**: `AiService` reads the preference directly from its injected `SharedPreferences` (`_prefs`) when building the system prompt in `extractEntries()`.
**Rationale**: `OpenAiService` already has `_prefs` injected (used for vector store ID retrieval). Reading one more key is consistent with the existing pattern. No signature changes needed on `extractEntries()`, keeping the interface stable.
**Alternatives considered**:
- Add `bool rephraseEnabled` parameter to `extractEntries()` — rejected; would require changes to the abstract interface, all callers, and all test mocks. Clean but high blast radius for a simple preference read.
- Have `EntryRepository` pass the flag — rejected; `EntryRepository` doesn't have direct `SharedPreferences` access and shouldn't need it for this.

## Decision 3: Two fully distinct system prompts (not a line swap)
**Decision**: Two complete, self-consistent system prompt strings — extracted into `_buildRephrasePrompt()` and `_buildVerbatimPrompt()` private methods — selected by an `if` statement based on the preference.
**Rationale**: User explicitly requested "two system prompts" to avoid the AI doing extra work. Staff review confirmed that a single-line substitution would create contradictory instructions (the "cleaned and organized version" description and rephrased few-shot examples would conflict with a "return verbatim" instruction). LLMs follow few-shot examples strongly, so the entire prompt must be internally consistent.
**Alternatives considered**:
- Single prompt with conditional line swap — rejected; creates contradictory instructions that the AI may not follow correctly. Few-shot examples showing rephrased text would override a verbatim instruction.
- Single prompt with conditional paragraph — rejected; same contradictory instruction problem.

## Decision 4: Where the toggle lives in the UI
**Decision**: `GeneralSection` widget in the Settings page, managed through `SettingsCubit`.
**Rationale**: User requested Settings page. `GeneralSection` already holds app-level preferences (What's New, Onboarding reset). The toggle fits naturally here.
**Alternatives considered**:
- New "AI Preferences" section — rejected; only one toggle for now, doesn't warrant its own section.
- Per-entry toggle in input area — rejected by user; may be added later.

## Decision 5: How SettingsCubit manages the preference
**Decision**: Add `SharedPreferences` as a dependency to `SettingsCubit`. Read the preference on init, expose it in `SettingsState`, and persist on toggle.
**Rationale**: Follows BLoC-First pattern — state is in the cubit, UI reads it via `BlocBuilder`. SharedPreferences is already registered in GetIt and readily available.
**Alternatives considered**:
- Read preference directly in GeneralSection widget — rejected; violates the BLoC-First principle (state should flow through cubits, not be read in widgets).

## Key Code Locations

| Component | File | Lines | Role |
|-----------|------|-------|------|
| System prompt | `lib/services/ai_service.dart` | 231-277 | Current single prompt with "Minimal text cleaning" instruction |
| extractEntries() | `lib/services/ai_service.dart` | 174-432 | AI call that uses the prompt |
| _processEntryWithAI() | `lib/entry/repository/entry_repository.dart` | 246-358 | Calls extractEntries() |
| SettingsCubit | `lib/settings/cubit/settings_cubit.dart` | 14-311 | Settings state management |
| SettingsState | `lib/settings/cubit/settings_state.dart` | 19-67 | State class |
| GeneralSection | `lib/settings/widgets/general_section.dart` | 1-108 | Settings UI (currently StatefulWidget) |
| locator.dart | `lib/locator.dart` | 29-118 | DI registration |

## Pre-existing Observations
- `GeneralSection` is a `StatefulWidget` (violates Constitution Principle III). This feature will not fix that — it's a pre-existing issue outside scope.
- The `SharedPreferences` key naming convention in the codebase uses snake_case strings (e.g., `openai_vector_store_id`, `category_colors_v1`). The new key should follow: `ai_rephrase_enabled`.

## Staff Review Notes (2026-02-08)

### Addressed
1. **Prompt contradiction (blocker)**: Original plan proposed a single-line swap, but the rest of the prompt says "cleaned and organized version" and shows rephrased examples. Fixed: now two fully distinct prompts.
2. **Race condition claim (blocker)**: Spec incorrectly claimed mid-processing toggle has no effect. Fixed: spec now states the setting is read at processing time, not submission time.
3. **analyzeImage() scope gap**: Plan now explicitly scopes the toggle to `extractEntries()` only. Image analysis is unaffected.
4. **Toggle subtitle UX**: Reworded from "Clean up filler words..." to "Let AI clean up filler words..." which reads naturally in both on/off states.
5. **Widget key pattern**: Corrected to top-level `const Key` with `ValueKey` matching existing file conventions.

### Acknowledged (not blocked)
- **Hidden prefs accumulation in AiService**: Currently two prefs read internally (vector store ID, rephrase toggle). If a third appears, introduce a `PromptPreferences` object to make dependencies explicit.
- **SettingsCubit scope creep**: Already handles auth, recovery, and now preferences. If more preferences land, consider splitting into a dedicated `PreferencesCubit`.
- **Per-entry override future**: If per-entry override is added later, it would require parameter-passing instead of internal pref reading. Current approach is fine for global-only setting.

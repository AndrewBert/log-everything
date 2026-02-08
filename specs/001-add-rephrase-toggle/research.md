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

## Decision 3: Two system prompts vs. conditional prompt modification
**Decision**: Two distinct system prompt strings selected by an `if` statement based on the preference.
**Rationale**: User explicitly requested "two system prompts" to avoid the AI doing extra work. A fully separate prompt makes the behavioral difference clear and avoids subtle bugs from string interpolation.
**Alternatives considered**:
- Single prompt with conditional paragraph — rejected; user explicitly wanted two prompts for clarity. Also risks the AI still doing cleanup if the conditional text is ambiguous.

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

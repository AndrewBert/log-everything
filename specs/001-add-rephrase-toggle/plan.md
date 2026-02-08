# Implementation Plan: AI Rephrase Toggle

**Branch**: `claude/add-rephrase-toggle-QwgeA` | **Date**: 2026-02-08 | **Spec**: `specs/001-add-rephrase-toggle/spec.md`
**Input**: Feature specification from `specs/001-add-rephrase-toggle/spec.md`

## Summary
Add a persistent toggle to the Settings page that controls whether the AI cleans/rephrases entry text during categorization. When disabled, the AI still categorizes, detects tasks, and splits entries, but returns text segments verbatim. Implemented via two system prompt variants in `OpenAiService.extractEntries()`, with the preference stored in SharedPreferences and managed through `SettingsCubit`.

## Technical Context
**Language/Version**: Dart 3.x / Flutter
**Primary Dependencies**: flutter_bloc, get_it, shared_preferences, http, equatable
**Storage**: SharedPreferences (new key: `ai_rephrase_enabled`)
**Testing**: User-led testing (Constitution Principle V)
**Target Platform**: iOS (primary), Android
**Project Type**: Mobile (Flutter)
**Constraints**: No new services or DI registrations required beyond adding SharedPreferences to SettingsCubit constructor
**Scale/Scope**: 4 files modified, 0 new files created

## Constitution Check
*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### I. BLoC-First Architecture
- [x] All state management uses BLoC/Cubit pattern (no StatefulWidgets)
- [x] State classes extend Equatable
- [x] Cubit and state files use `part`/`part of` directives

### II. Service Layer Separation
- [x] Services registered in GetIt (`lib/locator.dart`)
- [x] Cubits provided via BlocProvider (NOT in GetIt)
- [x] Clear boundaries between UI state and business logic

### III. Stateless UI Only
- [x] All new widgets are StatelessWidget
- [x] Private methods organized below `build()` method
- [x] Widget keys defined in `lib/utils/*_keys.dart` files

*Note: GeneralSection is a pre-existing StatefulWidget — not addressed in this feature.*

### IV. Clean Code Standards
- [x] Comments prefixed with "CP" when needed
- [x] Using `Color.withValues()` (not withOpacity)
- [x] 120 char line width with trailing commas
- [x] No unnecessary comments

### V. User-Led Testing
- [x] Implementation focus only (user handles testing)
- [x] No test files created unless explicitly requested

### VI. AI-First Development
- [x] AI integration via `AiService` where intelligence needed
- [x] Vector store sync is debounced and non-blocking
- [x] Graceful degradation with user feedback on errors

## Project Structure

### Documentation (this feature)
```
specs/001-add-rephrase-toggle/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Phase 0 research findings
├── data-model.md        # Data model changes
├── quickstart.md        # Manual validation steps
└── contracts/
    ├── settings-cubit-contract.md
    ├── ai-service-contract.md
    └── general-section-contract.md
```

### Source Code (files to modify)
```
lib/
├── services/ai_service.dart                    # Two system prompt variants
├── settings/
│   ├── cubit/settings_cubit.dart               # Add toggleRephrase(), SharedPreferences dep
│   ├── cubit/settings_state.dart               # Add rephraseEnabled field
│   └── widgets/general_section.dart            # Add SwitchListTile
├── locator.dart                                # Pass SharedPreferences to SettingsCubit callsite
└── utils/widget_keys.dart                      # Add rephraseToggle key
```

*Note: SettingsCubit is NOT registered in locator.dart (it's provided via BlocProvider in SettingsPage). The SettingsPage widget will need to pass SharedPreferences from GetIt when creating SettingsCubit.*

## Phase 0: Outline & Research
**Status**: Complete — see `research.md`

Key decisions:
1. SharedPreferences for storage (key: `ai_rephrase_enabled`)
2. AiService reads preference directly from its injected `_prefs`
3. Two distinct system prompt strings (user's explicit preference)
4. Toggle in GeneralSection of Settings page
5. SettingsCubit manages preference state with SharedPreferences dependency

## Phase 1: Design & Contracts
**Status**: Complete — see `data-model.md`, `contracts/`, `quickstart.md`

### Changes by file:

**1. `lib/settings/cubit/settings_state.dart`** — Add `rephraseEnabled` field
- Add `final bool rephraseEnabled` with default `true`
- Update `copyWith()` to include `bool? rephraseEnabled`
- Update `props` list

**2. `lib/settings/cubit/settings_cubit.dart`** — Add preference management
- Add `SharedPreferences _prefs` field and constructor parameter
- Read `ai_rephrase_enabled` in `_init()` and emit in initial state
- Add `toggleRephrase()` method

**3. `lib/settings/pages/settings_page.dart`** — Pass SharedPreferences to cubit
- Add `GetIt.instance<SharedPreferences>()` to SettingsCubit constructor call

**4. `lib/services/ai_service.dart`** — Two fully distinct system prompts
- Extract current prompt into `_buildRephrasePrompt(String categoriesListString)` private method
- Create `_buildVerbatimPrompt(String categoriesListString)` with ALL references to cleaning/rephrasing replaced:
  - "cleaned and organized version" → "the exact text segment from the user's input, preserved verbatim"
  - "Minimal text cleaning..." → "Return the user's text EXACTLY as written..."
  - Splitting examples rewritten to show verbatim preservation (with filler words intact)
- In `extractEntries()`, read `_prefs.getBool('ai_rephrase_enabled') ?? true` and select prompt
- **Critical**: A single-line swap is NOT sufficient — the entire prompt must be consistent to avoid contradictory instructions that confuse the model (per staff review)

**5. `lib/settings/widgets/general_section.dart`** — Add toggle UI
- Add `BlocBuilder<SettingsCubit, SettingsState>` wrapping the SwitchListTile
- Place toggle above "What's New" in the list

**6. `lib/utils/widget_keys.dart`** — Add key
- Add `const Key rephraseToggle = ValueKey('settings_rephrase_toggle');` (matching existing top-level const pattern)

## Phase 2: Task Planning Approach
*This section describes what the /tasks command will do — DO NOT execute during /plan*

**Task Generation Strategy**:
- Generate tasks from Phase 1 design (contracts, data model)
- Order: State → Cubit → Service → UI (dependency order)
- Mark independent tasks with [P] for parallel execution

**Ordering Strategy**:
- Dependency order: State changes before Cubit, Cubit before UI
- AiService change is independent of Settings changes → parallelizable
- Widget key addition is independent → parallelizable

**Estimated Output**: 6-8 ordered tasks in tasks.md

**IMPORTANT**: This phase is executed by the /tasks command, NOT by /plan

## Complexity Tracking
No constitutional violations. This feature is minimal:
- 0 new files
- 0 new services
- 0 new DI registrations (SharedPreferences is already registered)
- 1 new SharedPreferences key
- 1 new state field
- 1 new cubit method
- 2 private prompt-builder methods in AiService (+ conditional selection)
- 1 new UI toggle

## Progress Tracking

**Phase Status**:
- [x] Phase 0: Research complete (/plan command)
- [x] Phase 1: Design complete (/plan command)
- [x] Phase 2: Task planning complete (/plan command — describe approach only)
- [ ] Phase 3: Tasks generated (/tasks command)
- [ ] Phase 4: Implementation complete
- [ ] Phase 5: Validation passed

**Gate Status**:
- [x] Initial Constitution Check: PASS
- [x] Post-Design Constitution Check: PASS
- [x] All NEEDS CLARIFICATION resolved
- [x] Complexity deviations documented (none needed)

---
*Based on Constitution v1.0.0 — See `.specify/memory/constitution.md`*

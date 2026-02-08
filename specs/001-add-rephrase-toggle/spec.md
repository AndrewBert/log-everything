# Feature Specification: AI Rephrase Toggle

**Feature Branch**: `claude/add-rephrase-toggle-QwgeA`
**Created**: 2026-02-08
**Status**: Final

## Clarifications

### Session 1 (2026-02-08 brainstorm)
- **Q: Which approach for disabling rephrasing?** A: Option A — two system prompts. When toggle is off, the AI prompt instructs it to return text segments verbatim without cleanup. This avoids extra AI work compared to ignoring the AI's output.
- **Q: Where should the toggle live?** A: Settings page, as a persistent preference. No per-entry override needed for now.
- **Q: What happens with multi-entry splits when rephrasing is off?** A: Still split. The AI determines boundaries and categories, but returns each text segment verbatim (no filler word removal, no cleaning).
- **Q: What is the default?** A: Rephrase enabled (current behavior preserved for existing users).

---

## User Scenarios

### Primary User Story
As a user logging entries, I want the option to disable AI text cleanup so that my entries are stored exactly as I wrote them, while still getting automatic categorization and task detection.

### Acceptance Scenarios
1. **Given** a user with rephrase enabled (default), **When** they log an entry, **Then** the AI cleans and rephrases the text as it does today.
2. **Given** a user who has disabled rephrase in Settings, **When** they log an entry, **Then** the AI categorizes and splits the entry but preserves the original text verbatim in each segment.
3. **Given** a user who toggles rephrase off, **When** they close and reopen the app, **Then** the preference persists (rephrase remains off).
4. **Given** a user who toggles rephrase off and logs "um went to the store and uh picked up groceries", **When** the entry is processed, **Then** the stored text retains the filler words exactly as typed.

### Edge Cases & Error Handling
- Toggling the setting mid-processing: the setting is read at AI processing time, not at submission time. If a user toggles between submission and processing, the entry uses whichever value is active when the AI call executes. In practice this is an extremely narrow window.
- If the AI fails to process (regardless of rephrase setting), existing retry/fallback logic applies unchanged.
- Image analysis (photo entries with notes) is NOT affected by this toggle — image descriptions and titles are always AI-generated. This toggle only governs text entry categorization via `extractEntries()`.
- Voice-to-text entries: the toggle preserves the *transcribed* text (output of speech recognition), not the literal audio. If a user dictates "um went to the store," the transcription artifacts are preserved when rephrase is off.

## Requirements

### Functional Requirements
- **FR-001**: System MUST provide a toggle in the Settings page to enable/disable AI text rephrasing.
- **FR-002**: The toggle MUST default to enabled (preserving current behavior).
- **FR-003**: The preference MUST persist across app restarts via SharedPreferences.
- **FR-004**: When rephrasing is disabled, the AI MUST still categorize entries, detect tasks, and split multi-entry input into segments.
- **FR-005**: When rephrasing is disabled, the AI MUST return text segments verbatim without cleanup (no filler word removal, no rewording).
- **FR-006**: The system MUST use a distinct system prompt for each mode to avoid unnecessary AI processing.

### Key Entities
- **Rephrase Preference**: A boolean setting (`true` = rephrase on, `false` = rephrase off), persisted in SharedPreferences and managed by SettingsCubit.

---

## Review & Acceptance Checklist

### Content Quality
- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

### Requirement Completeness
- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements describe user-facing behavior clearly
- [x] Success criteria are measurable through app usage
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified
- [x] UI/UX expectations defined where relevant

---

## Execution Status

- [x] User description parsed
- [x] Key concepts extracted
- [x] Ambiguities marked
- [x] User scenarios defined
- [x] Requirements generated
- [x] Entities identified
- [x] Review checklist passed

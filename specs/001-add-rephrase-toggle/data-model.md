# Data Model: AI Rephrase Toggle

## Entities

### 1. Rephrase Preference (SharedPreferences)

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `ai_rephrase_enabled` | `bool` | `true` | Whether AI should clean/rephrase entry text segments |

**Storage**: SharedPreferences (same store as all other app preferences)
**Scope**: Device-local, not synced to cloud

### 2. SettingsState (updated)

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| `currentUser` | `AuthUser?` | `null` | Existing |
| `isLoading` | `bool` | `false` | Existing |
| `isSigningIn` | `bool` | `false` | Existing |
| `isSigningOut` | `bool` | `false` | Existing |
| `errorMessage` | `String?` | `null` | Existing |
| `recoveryInfo` | `RecoveryInfo?` | `null` | Existing |
| `isRecovering` | `bool` | `false` | Existing |
| **`rephraseEnabled`** | **`bool`** | **`true`** | **New — AI text cleanup preference** |

**copyWith changes**: Add `bool? rephraseEnabled` parameter.
**props changes**: Add `rephraseEnabled` to Equatable props list.

### 3. System Prompt Variants (AiService)

Two prompt variants exist within `OpenAiService.extractEntries()`:

**Variant A (rephraseEnabled = true)**: Current prompt — includes "Minimal text cleaning - remove filler words (um, uh) but preserve meaning."

**Variant B (rephraseEnabled = false)**: New prompt — replaces the text cleaning line with "IMPORTANT: Return the user's text EXACTLY as written. Do NOT clean, rephrase, or remove any words (including filler words like um, uh). Preserve the original text verbatim in each text_segment."

## State Transitions

```
App Launch
  → SettingsCubit._init() reads SharedPreferences['ai_rephrase_enabled']
  → Default true if key doesn't exist
  → Emits SettingsState(rephraseEnabled: true/false)

User Toggles Setting
  → SettingsCubit.toggleRephrase()
  → Writes new value to SharedPreferences
  → Emits updated SettingsState

Entry Processing
  → AiService.extractEntries() reads SharedPreferences['ai_rephrase_enabled']
  → Selects system prompt variant A or B
  → Returns EntryPrototype list (text segments are verbatim or cleaned)
```

## No Schema Migrations Required
- The Entry model is unchanged
- No new database tables or collections
- SharedPreferences key is new and defaults gracefully when absent

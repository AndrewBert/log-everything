# Plan: Auto-Save Note Editing

## Overview
Remove Save/Cancel buttons and implement auto-save for note editing with AI insight regeneration on exit only.

## Changes Needed

### 1. Remove Save/Cancel Buttons
**File:** `lib/dashboard_v2/pages/entry_details_page.dart`
- Remove the Save/Cancel button Row (lines 307-337)
- Keep edit mode UI clean with just the TextField

### 2. Add Debounced Auto-Save (Text Only)
**File:** `lib/dashboard_v2/cubit/entry_details_cubit.dart`
- Add `Timer?` field for debouncing
- Create `_autoSaveText()` method - saves text only, no AI regeneration
- Modify `updateEditedText()` to trigger debounced auto-save (500ms)
- Cancel existing timer on each keystroke

### 3. Add Full Save on Exit (With AI Regeneration)
**File:** `lib/dashboard_v2/cubit/entry_details_cubit.dart`
- Create `finalizeEdit()` method - saves text + triggers AI insight regeneration
- Call on focus loss and navigation away

**File:** `lib/dashboard_v2/pages/entry_details_page.dart`
- Add `onFocusLost` callback to TextField
- Wrap page in `PopScope` widget to intercept back button/gestures
- Call `finalizeEdit()` in both cases

### 4. Stay in Edit Mode
**File:** `lib/dashboard_v2/cubit/entry_details_cubit.dart`
- Don't set `isEditing: false` after auto-save
- Keep TextField focused and active

### 5. Add Subtle Save Indicator
**File:** `lib/dashboard_v2/cubit/entry_details_state.dart`
- Add `SaveStatus` enum: `idle`, `saving`, `saved`
- Add `saveStatus` field to state

**File:** `lib/dashboard_v2/cubit/entry_details_cubit.dart`
- Emit `saveStatus: saving` during auto-save
- Emit `saveStatus: saved` after successful save
- Auto-reset to `idle` after 2 seconds

**File:** `lib/dashboard_v2/pages/entry_details_page.dart`
- Add subtle indicator widget (e.g., small text near category chip)
- Show "Saving..." / "Saved ✓" based on state

### 6. Change Enter Key Behavior
**File:** `lib/dashboard_v2/pages/entry_details_page.dart`
- Remove `onSubmitted` callback from TextField
- Set `textInputAction: TextInputAction.newline`
- Allow multi-line notes

### 7. Update Repository to Skip AI Regeneration
**File:** `lib/entry/repository/entry_repository.dart`
- Add optional `bool skipAiRegeneration = false` parameter to `updateEntry()`
- Only trigger vector store sync if `skipAiRegeneration` is false
- Keep lightweight saves fast

## Implementation Flow

### While Typing (Auto-Save)
1. User types → `updateEditedText()` called
2. Cancel existing debounce timer
3. Start new 500ms timer
4. When timer fires → `_autoSaveText()` saves to repository (skip AI)
5. Show "Saving..." → "Saved ✓" indicator

### On Exit (Full Save)
1. User taps back or loses focus → `finalizeEdit()` called
2. Save final text to repository
3. Trigger AI insight regeneration
4. Navigate away or unfocus field

## Benefits
- ✅ Never lose data - auto-saves while typing
- ✅ Efficient - AI only regenerates once on exit
- ✅ Clean UX - no buttons cluttering the interface
- ✅ Subtle feedback - users know changes are saved
- ✅ Multi-line support - Enter key works naturally
- ✅ Handles all exit cases - back button, gestures, focus loss
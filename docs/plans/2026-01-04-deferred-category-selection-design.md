# Deferred Category Selection via Snackbar

## Problem

Users are asked to create or select categories too early in onboarding. When categories are introduced upfront, people over-select things they think they'll use but don't actually care about. This creates clutter and friction.

## Goals

- Reduce premature decisions
- Keep the experience lightweight
- Let categories emerge from real usage, not theoretical selections
- Avoid users organizing an app they haven't learned to trust

## Solution

When the AI processes an entry and can't match it to any existing category, the entry is saved under Misc (non-blocking), and a snackbar prompts the user to optionally refile it.

## Flow

```
User logs entry → AI processes → No category match found
    ↓
Entry saved under Misc (as usual)
    ↓
Snackbar appears: "What kind of note is this?" [Categorize]
    ↓
User taps → Enhanced picker dialog opens
    ↓
[+ Create new] at top, existing categories below
    ↓
User picks or creates → Entry is refiled
```

If user ignores the snackbar, entry stays in Misc. No pressure.

## Component: Snackbar Trigger

**When it appears:**
- After AI categorization completes
- Only when the result is Misc (no match found)
- Entry is already saved — snackbar is just an opportunity to refile

**Snackbar content:**
- Message: "What kind of note is this?"
- Action button: "Categorize"
- Duration: Standard snackbar timing (~4 seconds), dismissible

**Where the logic lives:**
- After entry processing, if category == Misc, emit state that tells UI to show snackbar
- Snackbar passes the entry reference so it can be refiled

## Component: Enhanced Category Picker

**Based on:** Existing `ChangeCategoryDialog` with modifications

**Structure:**
```
┌─────────────────────────────────┐
│  What kind of note is this?    │
├─────────────────────────────────┤
│  [+ Create new category]       │  ← Top, prominent
├─────────────────────────────────┤
│  Work 💼                        │
│  Personal 👤                    │
│  Health 🏥                      │
│  ...existing categories...      │
└─────────────────────────────────┘
```

**Behavior:**
- Tapping existing category → refiled immediately, dialog closes
- Tapping "Create new category" → navigates to `AddCategoryPage`
- After creating new category, entry is refiled to that category

**Changes to existing `ChangeCategoryDialog`:**
- Add optional `title` parameter (default: "Change Category")
- Add "Create new category" option at the top
- Handle navigation to `AddCategoryPage` and return new category name

## Edge Cases

**User dismisses snackbar:**
- Entry stays in Misc. No retry, no nagging.

**User cancels category creation:**
- Dialog closes, entry stays in Misc.

**Multiple entries processed quickly:**
- Only show one snackbar for the most recent entry. Avoid spam.

**Entry deleted before user taps "Categorize":**
- Dialog handles gracefully — if entry no longer exists, close without error.

**No existing categories yet (fresh user):**
- Picker shows only "Create new category" option. Natural first-category moment.

## Out of Scope (Phase 1)

- Changes to onboarding flow (kept as-is for now)
- AI-suggested category names
- Batch categorization UI

## Related

- GitHub Issue: https://github.com/AndrewBert/log-everything/issues/20

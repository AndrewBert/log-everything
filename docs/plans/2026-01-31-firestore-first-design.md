# Firestore-First Architecture Design

**Date:** 2026-01-31
**Issue:** #31
**Status:** Approved

## Overview

Replace the custom SharedPreferences + Firestore sync architecture with Firestore as the sole source of truth, using Firebase Anonymous Authentication to allow immediate note-taking without sign-in.

## Goals

- Users can start taking notes immediately without creating an account
- Single source of truth (Firestore) eliminates sync complexity
- Stay within Spark (free) tier quotas via pagination
- Safe migration path with 30-day local backup

## Architecture

### Data Flow

```
┌─────────────────────────────────────────────────────────┐
│                      App Launch                          │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
              ┌─────────────────────────┐
              │ Has Firebase Auth UID?  │
              └─────────────────────────┘
                     │            │
                    no           yes
                     │            │
                     ▼            │
         ┌─────────────────────┐  │
         │ Create Anonymous    │  │
         │ Account (silent)    │  │
         └─────────────────────┘  │
                     │            │
                     └─────┬──────┘
                           ▼
              ┌─────────────────────────┐
              │ Firestore (paginated)   │
              │ • First 50 entries      │
              │ • Load more on scroll   │
              │ • Offline cache active  │
              └─────────────────────────┘
```

### Component Changes

| Component | Change |
|-----------|--------|
| `EntryRepository` | Remove dual-write logic, add pagination state |
| `EntryPersistenceService` | Delete after migration period (keep 30 days as backup) |
| `FirestoreSyncService` | Rename to `FirestoreService`, simplify to direct CRUD with pagination |
| `locator.dart` | Add anonymous auth initialization |
| **New:** `AuthBootstrapService` | Handles anonymous account creation on first launch |
| **New:** `MigrationService` | One-time SharedPreferences → Firestore migration |
| **New:** `MigrationRecoverySection` | Settings UI for restoring from local backup |
| **New:** `AccountConflictDialog` | User choice for merge/cloud/local on conflict |
| **New:** `ConnectRequiredScreen` | First launch offline blocking screen |

## Pagination Strategy

### Implementation

```dart
// Initial load: most recent 50 entries
Query query = firestore
    .collection('users/$uid/entries')
    .orderBy('timestamp', descending: true)
    .limit(50);

// Load more: after last visible entry
Query nextPage = query.startAfterDocument(lastDoc);
```

### Quota Budget (Spark Tier)

| Action | Reads |
|--------|-------|
| App open (first 50) | 50 |
| Scroll to load 50 more | 50 |
| Add new entry | 0 (writes don't count) |
| Real-time update (1 entry changed) | 1 |

With 100 users on Spark (50,000 reads/day):
- 500 reads/user/day budget
- 500 reads = 10 app opens with full scroll
- Comfortable margin

### Dashboard UX

Infinite scroll - loads more entries automatically as user scrolls.

## Migration

### Scenarios

**Scenario A: Existing user updates the app (has local data, no account)**

1. Detect SharedPreferences has entries
2. Create anonymous Firebase account
3. Migrate SharedPreferences → Firestore (under anonymous UID)
4. Set `migration_backup_created_at` flag (do NOT delete SharedPreferences yet)
5. App runs on Firestore-only

**Scenario B: Existing user already signed in**

1. User already authenticated → skip anonymous creation
2. Merge any remaining SharedPreferences data into Firestore (cloud wins on conflicts)
3. Set `migration_backup_created_at` flag
4. App runs on Firestore-only

**Scenario C: Brand new user**

1. Create anonymous Firebase account (silent)
2. All writes go directly to Firestore
3. No migration needed

### Safeguard: 30-Day Local Backup

SharedPreferences data is NOT deleted immediately after migration. Instead:

1. Keep local data for 30 days
2. Show recovery option in Settings during this window
3. Auto-expire after 30 days (or manual confirmation)

**Settings UI during backup window:**

```
┌─────────────────────────────────────┐
│ ⚠️ Migration Recovery               │
│                                     │
│ Having issues with your notes?      │
│ Restore from local backup           │
│ (47 entries from Jan 15, 2026)      │
│                                     │
│ [Restore]     Expires in 23 days    │
└─────────────────────────────────────┘
```

## Error Handling

### First Launch (No Network)

Anonymous auth requires one network call. Show blocking screen:

```
┌─────────────────────────────────────┐
│                                     │
│     📡                              │
│                                     │
│  Connect to get started             │
│                                     │
│  Log Everything needs internet      │
│  for first-time setup.              │
│                                     │
│  [Retry]                            │
│                                     │
└─────────────────────────────────────┘
```

### Subsequent Launches (Offline)

- Firestore cache serves data instantly
- Writes queue locally, sync when back online
- No user-facing error needed (silent)

### Account Conflict Resolution

When anonymous user signs into a Google account that already has data, show choice dialog:

```
┌─────────────────────────────────────────────────┐
│  ⚠️  Account Already Has Notes                  │
├─────────────────────────────────────────────────┤
│                                                 │
│  The Google account you selected already has    │
│  notes from another device.                     │
│                                                 │
│  ┌───────────────┬───────────────┐              │
│  │ On this device│ In the cloud  │              │
│  ├───────────────┼───────────────┤              │
│  │ 7 entries     │ 42 entries    │              │
│  │ 3 categories  │ 8 categories  │              │
│  │ Since Jan 15  │ Since Dec 3   │              │
│  └───────────────┴───────────────┘              │
│                                                 │
│  What would you like to do?                     │
│                                                 │
│  ┌─────────────────────────────────────────┐    │
│  │ 🔗  Merge both                          │    │
│  │     Keep all 49 entries from both       │    │
│  └─────────────────────────────────────────┘    │
│                                                 │
│  ┌─────────────────────────────────────────┐    │
│  │ ☁️  Keep cloud only                     │    │
│  │     Use the 42 entries from your        │    │
│  │     account, discard local              │    │
│  └─────────────────────────────────────────┘    │
│                                                 │
│  ┌─────────────────────────────────────────┐    │
│  │ 📱  Keep local only                     │    │
│  │     Replace cloud with 7 entries        │    │
│  │     from this device                    │    │
│  └─────────────────────────────────────────┘    │
│                                                 │
│  [Cancel]                                       │
│                                                 │
└─────────────────────────────────────────────────┘
```

**"Keep local" requires confirmation** (destructive action).

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Anonymous account loss (uninstall before sign-in) | User loses data | Gentle nudge after X entries to sign in |
| Cold start on new device | Empty state until network fetch | Show loading indicator during initial sync |
| Account linking collision | Data conflict | User chooses resolution (this design) |
| Firestore quotas | App stops working | Pagination keeps usage low; monitor in Firebase Console |
| First launch offline | Can't create anonymous account | Blocking "Connect to get started" screen |

## Testing

| Scenario | Test Type |
|----------|-----------|
| Anonymous auth on first launch | Widget test (mocked Firebase) |
| Pagination loads 50, then more on scroll | Widget test |
| Offline write queues, syncs on reconnect | Integration test |
| Migration from SharedPreferences | Unit test |
| Account linking (no conflict) | Widget test |
| Account linking (with conflict) | Widget test |
| Migration recovery from Settings | Widget test |

## Files to Create/Modify

| File | Action |
|------|--------|
| `lib/services/auth_bootstrap_service.dart` | **New** |
| `lib/services/migration_service.dart` | **New** |
| `lib/services/firestore_service.dart` | **Rename/Simplify** from FirestoreSyncService |
| `lib/entry/repository/entry_repository.dart` | **Simplify** |
| `lib/services/entry_persistence_service.dart` | **Delete after 30 days** |
| `lib/settings/widgets/migration_recovery_section.dart` | **New** |
| `lib/dialogs/account_conflict_dialog.dart` | **New** |
| `lib/widgets/connect_required_screen.dart` | **New** |

## Out of Scope

- Blaze plan upgrade (stay on Spark for now)
- AI-suggested categories during migration
- Multi-device real-time sync indicators

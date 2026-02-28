# Release Management

## What's New Dialog
- Located at `lib/dialogs/whats_new_dialog.dart`
- Update the `changes` list with recent features (keep concise, 3-4 items max)
- Update the title section to reflect the theme of the update (e.g., "The Gesture Update")
- Focus on user-facing improvements, not technical architecture changes

## TestFlight Deployment
Use `/deploy` skill for full TestFlight workflow (includes version bump, changelog, Fastlane, git tagging).

## Google Play Deployment
Use `/deploy-android` skill for full Play Store workflow (build, changelog, Fastlane, git tagging).

### Gotchas
- **Draft state**: New apps require `release_status: "draft"` in `android/fastlane/Fastfile` until first Play review passes. After that, switch to `"completed"` for auto-rollout.
- **Build number**: The `+N` in `pubspec.yaml` must strictly increase per upload. If a manual upload used +1, Fastlane needs +2.
- **Privacy policy**: Required even for internal testing when using sensitive permissions (RECORD_AUDIO). Set in Play Console → Policy and programs → App content.
- **Strip debug symbols warning**: `flutter build appbundle --release` may warn about failing to strip debug symbols — this is non-fatal, AAB still builds. Fix by installing Android cmdline-tools (issue #69).
- **`fastlane supply init`**: Known bug in Fastlane 2.230.0 crashes on image download, but text metadata downloads fine. Not a blocker.

## Dashboard V2 Migration Status

### Current Status: STAGED REPLACEMENT ACTIVE
- **Main route now uses DashboardV2Page** (replaced HomePage)
- **Old components preserved** as backup in commented imports
- **Backup branch**: `pre-dashboard-v2-swap` contains pre-migration state

### Old Components (Kept as backup, commented out):
- `lib/pages/home_page.dart` + `home_page_cubit.dart`
- `lib/widgets/entries_list.dart`
- `lib/widgets/filter_section.dart`
- `lib/widgets/input_area.dart`
- Associated imports in `main.dart`

### Phase 2 Cleanup (Scheduled after testing):
- Delete old widget files if dashboard v2 proves stable
- Remove commented imports
- Update/remove old tests that reference deleted components
- Clean up any remaining old dependencies

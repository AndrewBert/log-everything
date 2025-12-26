# Release Management

## What's New Dialog
- Located at `lib/dialogs/whats_new_dialog.dart`
- Update the `changes` list with recent features (keep concise, 3-4 items max)
- Update the title section to reflect the theme of the update (e.g., "The Gesture Update")
- Focus on user-facing improvements, not technical architecture changes

## TestFlight Deployment
Use `/deploy` skill for full TestFlight workflow (includes version bump, changelog, Fastlane, git tagging).

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

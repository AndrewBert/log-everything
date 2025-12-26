---
name: deploy
description: Execute the complete TestFlight deployment workflow for this Flutter iOS app. Use when the user asks to deploy, release, publish, or upload the app to TestFlight, or says things like "deploy to testflight", "release a new build", "push to beta testers", or "upload to app store connect".
---

# Deploy to TestFlight

Deploy this Flutter app to TestFlight using Fastlane.

## Workflow

### 1. Code Quality Check

```bash
flutter analyze
```

Stop if errors are found. Warnings are acceptable.

### 2. Version Check

Read current version from `pubspec.yaml`. Ask user:
- Bump version? If yes, update `pubspec.yaml`
- Update What's New dialog? If yes, edit `lib/dialogs/whats_new_dialog.dart`

### 3. Build

```bash
flutter build ipa --release
```

Verify IPA created at `build/ios/ipa/myapp.ipa`.

### 4. Deploy

Extract changelog from the latest version section in `lib/dialogs/whats_new_dialog.dart` (the `_v*Changes` list for the current version).

```bash
cd ios && fastlane beta_with_changelog changelog:"<extracted changelog>"
```

### 5. Confirm

Report success with:
- Version deployed
- Changelog used
- Note: Build available in TestFlight after Apple processing (~10-30 min)

## Fastlane Setup

Located in `ios/fastlane/`:
- `Appfile` - Bundle identifier
- `Fastfile` - Deployment lanes (`beta`, `beta_with_changelog`)
- `AuthKey_*.p8` - App Store Connect API key (gitignored)

## Quick Deploy (No Prompts)

For rapid deployment without version/changelog prompts:

```bash
flutter build ipa --release && cd ios && fastlane beta
```

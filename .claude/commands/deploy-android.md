Execute the complete Google Play internal testing deployment workflow: check code quality, optionally bump version, build AAB, and upload to Play Store.

## Workflow Steps

1. **Prerequisites Check**
   - Verify `android/fastlane/play-store-credentials.json` exists
   - If missing, show setup instructions from `android/fastlane/README.md` step 3 (Google Play Service Account) and stop
   - If `android/fastlane/metadata/` directory doesn't exist, run:
     ```bash
     cd android && fastlane supply init
     ```
     This bootstraps local metadata from the Play Store listing (one-time setup)

2. **Code Quality Check**
   - Run `flutter analyze` to check for issues
   - Stop if there are any errors

3. **Version Management**
   - Check current version in `pubspec.yaml`
   - Ask if user wants to bump the version
   - If yes, update pubspec.yaml
   - The build number (`+N`) must increment for every Play Store upload

4. **What's New Dialog**
   - Ask if user wants to update the What's New dialog (`lib/dialogs/whats_new_dialog.dart`)
   - If yes, update the dialog content

5. **Build**
   - Run `flutter build appbundle --release`
   - Verify AAB was created at `build/app/outputs/bundle/release/app-release.aab`

6. **Generate Changelog**
   - Get commits since last tag: `git log $(git describe --tags --abbrev=0 2>/dev/null || git rev-list --max-parents=0 HEAD)..HEAD --oneline`
   - Present commits to user and ask them to confirm or edit the changelog text

7. **Write Changelog File**
   - Extract the build number from `pubspec.yaml` (the number after `+`)
   - Create the changelog directory if needed:
     ```bash
     mkdir -p android/fastlane/metadata/android/en-US/changelogs
     ```
   - Write the confirmed changelog text to `android/fastlane/metadata/android/en-US/changelogs/<buildNumber>.txt`
   - Play Store changelog limit is 500 characters — truncate if needed

8. **Deploy to Play Store**
   - Run:
     ```bash
     cd android && fastlane beta_with_changelog
     ```

9. **Git Commit & Tag**
   - Stage changed files (`pubspec.yaml`, changelog file, `whats_new_dialog.dart` if updated)
   - Create a commit with the changes
   - Check if tag `v<version>` already exists (it may exist from an iOS deploy of the same version)
   - If tag doesn't exist, create it: `git tag -a v<version> -m "Release <version>"`
   - Push commit and tag (if new): `git push && git push origin v<version>`

## Fastlane Configuration

The fastlane setup is in `android/fastlane/`:
- `Appfile` - Package name (`com.logsplitter.app`) and credentials path
- `Fastfile` - Deployment lanes
- `play-store-credentials.json` - Google Play service account key (gitignored)

## Prerequisites

- **Service account credentials**: `android/fastlane/play-store-credentials.json` (see `android/fastlane/README.md` step 3)
- **Upload keystore**: `android/upload-keystore.jks` with matching `android/key.properties`
- **Metadata directory**: Auto-bootstrapped on first deploy via `fastlane supply init`

## Available Lanes

- `fastlane beta` - Deploy without changelog
- `fastlane beta_with_changelog` - Deploy with changelog (used by this command)
- `fastlane promote_to_beta` - Promote internal track to beta

## Expected Output

After successful deployment:
- AAB uploaded to Google Play internal testing track
- Changelog set for the build in Play Store
- Git tag created and pushed (e.g., v1.3.1) — unless it already exists from iOS deploy
- Build available to internal testers after Google Play processing (~minutes)

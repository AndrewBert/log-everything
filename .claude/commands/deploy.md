Execute the complete TestFlight deployment workflow: check code quality, optionally bump version, build, and upload to TestFlight.

## Workflow Steps

1. **Code Quality Check**
   - Run `flutter analyze` to check for issues
   - Stop if there are any errors

2. **Version Management**
   - Check current version in `pubspec.yaml`
   - Ask if user wants to bump the version
   - If yes, update pubspec.yaml

3. **What's New Dialog**
   - Read current What's New content from `lib/dialogs/whats_new_dialog.dart`
   - Ask if user wants to update it with new features
   - If yes, update the dialog content

4. **Build**
   - Run `flutter build ipa --release`
   - Verify IPA was created at `build/ios/ipa/myapp.ipa`

5. **Deploy to TestFlight**
   - Extract changelog from the latest version section in What's New dialog
   - Run fastlane from the ios directory:
     ```bash
     cd ios && fastlane beta_with_changelog changelog:"<changelog from whats new>"
     ```

## Fastlane Configuration

The fastlane setup is in `ios/fastlane/`:
- `Appfile` - App identifier
- `Fastfile` - Deployment lanes
- `AuthKey_*.p8` - App Store Connect API key (gitignored)

## Available Lanes

- `fastlane beta` - Deploy without changelog
- `fastlane beta_with_changelog changelog:"..."` - Deploy with changelog

## Expected Output

After successful deployment:
- Build uploaded to App Store Connect
- Changelog set for the build
- External testers notified automatically
- Build available in TestFlight after Apple processing (~10-30 minutes)

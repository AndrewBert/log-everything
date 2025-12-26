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
   - Ask if user wants to update the What's New dialog (`lib/dialogs/whats_new_dialog.dart`)
   - If yes, update the dialog content

4. **Build**
   - Run `flutter build ipa --release`
   - Verify IPA was created at `build/ios/ipa/myapp.ipa`

5. **Generate Changelog**
   - Get commits since last tag: `git log $(git describe --tags --abbrev=0 2>/dev/null || git rev-list --max-parents=0 HEAD)..HEAD --oneline`
   - Present commits to user and ask them to confirm or edit the changelog text

6. **Deploy to TestFlight**
   - Run fastlane with user-confirmed changelog:
     ```bash
     cd ios && fastlane beta_with_changelog changelog:"<user-confirmed changelog>"
     ```

7. **Tag Release**
   - Create git tag: `git tag -a v<version> -m "Release <version>"`
   - Push tag: `git push origin v<version>`

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
- Git tag created and pushed (e.g., v1.3.1)
- Changelog set for the build
- External testers notified automatically
- Build available in TestFlight after Apple processing (~10-30 minutes)

# Development Commands

## Core Flutter Commands
```bash
# Run the app in development mode
flutter run

# Run tests
flutter test

# Run a specific test file
flutter test test/home_page_test.dart

# Analyze code for lints and errors
flutter analyze

# Format code (preserves trailing commas, 120 char line width)
dart format lib/ test/

# Generate mocks for testing
dart run build_runner build

# Clean and rebuild
flutter clean && flutter pub get

# Build IPA for iOS release
flutter build ipa --release
```

## Testing Policy
- Claude does not build or run the Flutter app - user handles testing
- Focus on implementation and code analysis only
- User will test changes and provide feedback

## Environment Setup
- Requires `.env` file in root directory with OpenAI API key
- App loads `.env` on startup but gracefully falls back if missing
- Dependencies configured via `configureDependencies()` in `locator.dart`

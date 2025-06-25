# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Core Flutter Commands
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

### Testing Policy
- Claude does not build or run the Flutter app - user handles testing
- Focus on implementation and code analysis only
- User will test changes and provide feedback

### Environment Setup
- Requires `.env` file in root directory with OpenAI API key
- App loads `.env` on startup but gracefully falls back if missing
- Dependencies configured via `configureDependencies()` in `locator.dart`

## Architecture Overview

This is a **personal logging application** with AI-powered categorization and chat functionality. The app follows clean architecture principles with the BLoC pattern for state management.

### State Management Pattern
- **Framework**: BLoC/Cubit pattern using `flutter_bloc`
- **Main Cubits**: `EntryCubit` (core business logic), `ChatCubit` (AI conversations), `VoiceInputCubit` (speech input), `OnboardingCubit` (user setup), `HomePageCubit` (UI coordination)
- **State Classes**: Use `part`/`part of` directives to link cubit and state files (not imports)
- **Dependency**: Cubits injected via `BlocProvider`/`MultiBlocProvider` at widget level

### Service Layer Architecture
```
UI Layer (Widgets + Cubits)
    ↓
Repository Layer (EntryRepository) 
    ↓
Service Layer (AiService, VectorStoreService, PersistenceService)
    ↓
External APIs (OpenAI, Local Storage)
```

### Key Services
- **AiService**: OpenAI integration for entry categorization and chat responses
- **VectorStoreService**: Syncs logs to OpenAI vector store for AI chat queries (debounced, monthly files)
- **EntryPersistenceService**: Local storage via SharedPreferences with JSON serialization
- **AudioRecorderService & SpeechService**: Voice-to-text input pipeline
- **EntryRepository**: Coordinates between UI and services, main business logic hub

### Dependency Injection
- Uses **GetIt** service locator pattern
- Services registered in `lib/locator.dart` via `configureDependencies()`
- Only register services in DI container, not Cubits (use `BlocProvider` instead)
- Services are lazy singletons, SharedPreferences is async singleton

## Code Conventions

### Widget Architecture
- **StatelessWidget only** - no StatefulWidgets
- **Private methods** organized below `build()` method in widgets
- **Key Usage**: Define widget keys in `lib/utils/*_keys.dart` files, import for reuse

### State Management Rules
- **BLoC Events**: Only create if originating from UI layer
- **Cubits**: Handle all business logic and state management
- **State Classes**: Extend `Equatable` for value-based equality
- **copyWith**: Use dedicated bool parameters (e.g., `clearController`) to explicitly set fields to null

### Code Style
- **Comments**: Prefix with `"CP"` when adding comments
- **Barrel Files**: Use for managing exports/imports
- **withOpacity**: Deprecated - use `Color.withValues()` instead
- **Trailing Commas**: Preserved by formatter (120 char line width)
- **Avoid Unnecessary Comments**: Dont litter the codebase with comments explaining easy to understand code

### Testing Approach
- **No Cubit-Specific Tests**: Never test cubits directly - test the behavior they enable
- **Test Structure**: Use Given/When/Then format with descriptive test names
- **Widget Tests**: Use `find.byKey` with `ValueKey`s defined in `lib/utils/*_keys.dart`
- **Mocking**: Generated via `mockito` and `build_runner` 
- **Mock Setup**: Add services to `@GenerateMocks` annotation in `test/mocks.dart`
- **Test DI**: Use `test_di_registrar.dart` for test-specific service registration
- **Test Organization**: 
  - Feature tests: `test/chat/`, `test/dialogs/`, `test/pages/`, `test/widgets/`
  - Integration tests: Root `test/` directory (e.g., `ai_categorization_test.dart`, `entry_management_test.dart`)

## Data Architecture

### Local Storage
- **Primary**: SharedPreferences with JSON serialization
- **Models**: Entry (text, timestamp, category, isNew), Category (name, description)
- **Versioning**: Migration support via version keys

### AI Integration
- **Categorization**: Text input → AI categorization → structured entries
- **Chat**: Natural language queries against logged data via vector store
- **Voice Input**: Speech → Text → AI categorization pipeline

### Background Operations
- **Vector Store Sync**: Debounced, non-blocking synchronization
- **Monthly Aggregation**: Automatic file organization for AI search
- **Error Handling**: Graceful degradation with user feedback

## Common Development Patterns

### Adding New Features
1. Define models in appropriate domain folder (`lib/entry/`, `lib/chat/`, etc.)
2. Create cubit + state with `part`/`part of` pattern
3. Add service layer if external integration needed
4. Register services in `locator.dart` (not cubits)
5. Create UI with StatelessWidget + BlocBuilder/BlocListener
6. Add widget keys to relevant `lib/utils/*_keys.dart` file
7. Write tests with mocked dependencies

### Testing New Components
1. Add mocks to `test/mocks.dart` `@GenerateMocks` annotation
2. Run `dart run build_runner build` to generate mocks
3. Use `find.byKey` with predefined keys from utils
4. Mock services, provide cubits via `BlocProvider` in tests

### Error Prevention
- Always check widget `mounted` state before setState-like operations
- Use `Equatable` for state classes to ensure proper equality checks
- Handle null cases in `copyWith` methods explicitly
- Test error scenarios and fallback behaviors

## Release Management

### iOS Release Checklist
When asked to create an IPA for iOS release, Claude should:

1. **Ask about version bump**: "Do you want me to bump the version number in pubspec.yaml?"
2. **Ask about What's New dialog**: "Do you want me to update the What's New dialog (lib/dialogs/whats_new_dialog.dart) with recent features?"
3. **Then proceed with**: `flutter build ipa --release`

### What's New Dialog Updates
- Located at `lib/dialogs/whats_new_dialog.dart`
- Update the `changes` list with recent features (keep concise, 3-4 items max)
- Update the title section to reflect the theme of the update (e.g., "The Gesture Update")
- Focus on user-facing improvements, not technical architecture changes
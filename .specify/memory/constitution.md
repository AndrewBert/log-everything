<!--
Sync Impact Report:
Version: 0.0.0 → 1.0.0 (MAJOR - Initial ratification)

Modified Principles:
- [PRINCIPLE_1] → I. BLoC-First Architecture
- [PRINCIPLE_2] → II. Service Layer Separation
- [PRINCIPLE_3] → III. Stateless UI Only
- [PRINCIPLE_4] → IV. Clean Code Standards
- [PRINCIPLE_5] → V. User-Led Testing
- Added: VI. AI-First Development

Added Sections:
- Development Workflow
- Flutter-Specific Constraints

Removed Sections:
- [SECTION_2_NAME] (replaced with Flutter-Specific Constraints)
- [SECTION_3_NAME] (replaced with Development Workflow)

Templates Requiring Updates:
- ✅ plan-template.md (pending - add Flutter/BLoC constitutional checks)
- ✅ spec-template.md (pending - remove test requirements, focus on user scenarios)
- ✅ tasks-template.md (pending - Flutter workflow: models → services → cubits → UI)

Follow-up TODOs:
- Update templates to align with Flutter/BLoC principles
- Add Dashboard V2 migration status to runtime guidance if needed
-->

# Log Everything Insights Constitution

## Core Principles

### I. BLoC-First Architecture
All state management MUST use the BLoC/Cubit pattern via `flutter_bloc`. StatefulWidgets are forbidden. State classes MUST extend `Equatable` for value-based equality. Cubit and state files MUST use `part`/`part of` directives (not imports).

**Rationale**: Consistent state management enables predictable data flow, testable business logic, and clear separation of concerns in the Flutter UI layer.

### II. Service Layer Separation
Services MUST be registered in the DI container via GetIt (`lib/locator.dart`). Cubits MUST NOT be registered in GetIt; they MUST be provided via `BlocProvider`/`MultiBlocProvider` at the widget level. Services are lazy singletons; SharedPreferences is async singleton.

**Rationale**: Clear dependency boundaries prevent coupling between UI state and business logic, enabling independent testing and reuse.

### III. Stateless UI Only
All widgets MUST be StatelessWidget. No StatefulWidgets permitted. Private methods MUST be organized below the `build()` method. Widget keys MUST be defined in `lib/utils/*_keys.dart` files and imported for reuse.

**Rationale**: Stateless widgets enforce unidirectional data flow through BLoC, eliminating hidden state mutations and race conditions.

### IV. Clean Code Standards
Code style MUST follow these rules:
- Comments prefixed with "CP" when adding explanatory notes
- Barrel files for managing exports/imports
- Use `Color.withValues()` (withOpacity is deprecated)
- Trailing commas preserved by formatter (120 char line width)
- Avoid unnecessary comments explaining obvious code

**Rationale**: Consistent formatting and minimal noise improve code readability and reduce cognitive load during development.

### V. User-Led Testing
Claude Code focuses on implementation and code analysis only. User handles all testing and validation in the running Flutter app. No test files are created unless explicitly requested by user.

**Rationale**: Optimizes development flow for personal projects where the developer is the primary tester and can validate features interactively.

### VI. AI-First Development
All features requiring intelligence MUST integrate with OpenAI via `AiService`. Entry categorization and chat responses MUST use AI. Vector store synchronization MUST be debounced and non-blocking. Background operations MUST gracefully degrade with user feedback on errors.

**Rationale**: AI capabilities are core to the app's value proposition; ensuring robust integration patterns prevents degraded user experience.

## Development Workflow

### Adding New Features
1. Define models in appropriate domain folder (`lib/entry/`, `lib/chat/`, `lib/dashboard_v2/`, etc.)
2. Create cubit + state with `part`/`part of` pattern
3. Add service layer if external integration needed (AI, persistence, etc.)
4. Register services in `locator.dart` (NOT cubits)
5. Create UI with StatelessWidget + BlocBuilder/BlocListener
6. Add widget keys to relevant `lib/utils/*_keys.dart` file
7. User tests changes and provides feedback

### Service Registration
Services registered in DI container:
- `AiService`: OpenAI integration for categorization and chat
- `VectorStoreService`: Syncs logs to OpenAI vector store (debounced, monthly files)
- `EntryPersistenceService`: Local storage via SharedPreferences with JSON
- `AudioRecorderService` & `SpeechService`: Voice-to-text pipeline
- `EntryRepository`: Coordinates between UI and services (main business logic hub)

### Release Management
When creating iOS release builds:
1. Ask user about version bump in `pubspec.yaml`
2. Ask user about updating What's New dialog (`lib/dialogs/whats_new_dialog.dart`)
3. Update changes list (keep concise, 3-4 items max)
4. Focus on user-facing improvements, not architecture changes
5. Execute: `flutter build ipa --release`

## Flutter-Specific Constraints

### Architecture Pattern
Clean architecture with repository pattern:
```
UI Layer (Widgets + Cubits)
    ↓
Repository Layer (EntryRepository)
    ↓
Service Layer (AiService, VectorStoreService, PersistenceService)
    ↓
External APIs (OpenAI, Local Storage)
```

### State Management Rules
- BLoC Events: Only create if originating from UI layer
- Cubits: Handle all business logic and state management
- State Classes: Extend `Equatable` for value-based equality
- copyWith: Use dedicated bool parameters (e.g., `clearController`) to explicitly set fields to null

### Data Storage
- Primary: SharedPreferences with JSON serialization
- Models: Entry (text, timestamp, category, isNew), Category (name, description)
- Versioning: Migration support via version keys
- Background sync: Vector store updates are debounced and non-blocking

### AI Integration Requirements
- Categorization: Text input → AI categorization → structured entries
- Chat: Natural language queries against logged data via vector store
- Voice Input: Speech → Text → AI categorization pipeline
- Error Handling: Graceful degradation with user feedback

### Environment Setup
- Requires `.env` file in root directory with OpenAI API key
- App loads `.env` on startup but gracefully falls back if missing
- Dependencies configured via `configureDependencies()` in `locator.dart`

### Code Style Specifics
- **StatelessWidget only** - no StatefulWidgets
- **Private methods** organized below `build()` method in widgets
- **Key Usage**: Define widget keys in `lib/utils/*_keys.dart` files, import for reuse
- **withOpacity**: Deprecated - use `Color.withValues()` instead
- **Trailing Commas**: Preserved by formatter (120 char line width)

## Governance

This constitution supersedes all other development practices. All feature development and code reviews MUST verify compliance with these principles.

Amendments require:
1. Documentation of rationale
2. Version bump per semantic versioning
3. Propagation to all dependent templates

Complexity deviations MUST be justified. Any violation of core principles requires explicit reasoning in planning documents.

Runtime development guidance is maintained in `CLAUDE.md` for AI assistant context.

**Version**: 1.0.0 | **Ratified**: 2025-10-04 | **Last Amended**: 2025-10-04

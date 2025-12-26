# Architecture Overview

This is a **personal logging application** with AI-powered categorization and chat functionality. The app follows clean architecture principles with the BLoC pattern for state management.

## Service Layer Architecture
```
UI Layer (Widgets + Cubits)
    ↓
Repository Layer (EntryRepository)
    ↓
Service Layer (AiService, VectorStoreService, PersistenceService)
    ↓
External APIs (OpenAI, Local Storage)
```

## Key Services
- **AiService**: OpenAI integration for entry categorization and chat responses
- **VectorStoreService**: Syncs logs to OpenAI vector store for AI chat queries (debounced, monthly files)
- **EntryPersistenceService**: Local storage via SharedPreferences with JSON serialization
- **AudioRecorderService & SpeechService**: Voice-to-text input pipeline
- **EntryRepository**: Coordinates between UI and services, main business logic hub

## Dependency Injection
- Uses **GetIt** service locator pattern
- Services registered in `lib/locator.dart` via `configureDependencies()`
- Only register services in DI container, not Cubits (use `BlocProvider` instead)
- Services are lazy singletons, SharedPreferences is async singleton

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

## Adding New Features
1. Define models in appropriate domain folder (`lib/entry/`, `lib/chat/`, etc.)
2. Create cubit + state with `part`/`part of` pattern
3. Add service layer if external integration needed
4. Register services in `locator.dart` (not cubits)
5. Create UI with StatelessWidget + BlocBuilder/BlocListener
6. Add widget keys to relevant `lib/utils/*_keys.dart` file
7. Write tests with mocked dependencies

## Error Prevention
- Use `Equatable` for state classes to ensure proper equality checks
- Handle null cases in `copyWith` methods explicitly
- Test error scenarios and fallback behaviors

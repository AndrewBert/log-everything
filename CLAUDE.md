# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A personal logging application with AI-powered categorization and chat functionality. Built with Flutter using clean architecture and the BLoC pattern.

## Quick Reference

```bash
flutter run                      # Run app
flutter test                     # Run all tests
flutter test test/path_test.dart # Run single test file
flutter analyze                  # Check lints
dart run build_runner build      # Generate mocks after adding to @GenerateMocks
```

## Project Rules

Detailed instructions are organized in `.claude/rules/`:

| File | Description |
|------|-------------|
| `architecture.md` | Service layer, DI patterns, data architecture |
| `flutter.md` | Widget conventions, state management, code style (scoped to `lib/**/*.dart`) |
| `testing.md` | Test approach, mocking, organization (scoped to `test/**/*.dart`) |
| `commands.md` | Flutter commands, testing policy, environment setup |
| `release.md` | iOS release checklist, What's New dialog, Dashboard V2 migration status |
| `debug-api.md` | Debug HTTP API endpoints reference (localhost:8888) |

## Key Conventions

- **Comment prefix**: Use `"CP"` when adding inline comments
- **Testing philosophy**: Never test cubits directly—test the behavior they enable through widget tests
- **Test helper**: Use `WidgetTestScope` class in `test/helpers/widget_test_scope.dart` for widget test setup
- **DI pattern**: Register services (not cubits) in `lib/locator.dart`; provide cubits via `BlocProvider`
- **State files**: Use `part`/`part of` directives to link cubit and state files

## Domain Structure

```
lib/
├── entry/           # Core entry model, EntryCubit, EntryRepository
├── chat/            # AI chat feature (ChatCubit, ChatMessage)
├── dashboard_v2/    # Main UI (replaced original HomePage)
├── search/          # Search functionality
├── onboarding/      # User onboarding flow
├── snackbar/        # Global snackbar system
├── intent_detection/# Input intent classification
├── settings/        # Settings and AuthService
├── services/        # Core services (AI, persistence, vector store, etc.)
├── widgets/         # Shared widgets (voice_input)
└── utils/           # Keys files (*_keys.dart), helpers
```

## Context7 Usage

Always use Context7 MCP tools (`resolve-library-id` and `query-docs`) when code generation, setup/configuration steps, or library/API documentation is needed.

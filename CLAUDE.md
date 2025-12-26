# Log Everything

A personal logging application with AI-powered categorization and chat functionality. Built with Flutter using clean architecture and the BLoC pattern.

## Project Rules

Detailed instructions are organized in `.claude/rules/`:

| File | Description |
|------|-------------|
| `commands.md` | Flutter commands, testing policy, environment setup |
| `architecture.md` | Service layer, DI patterns, data architecture |
| `flutter.md` | Widget conventions, state management, code style (scoped to `lib/**/*.dart`) |
| `testing.md` | Test approach, mocking, organization (scoped to `test/**/*.dart`) |
| `release.md` | iOS release checklist, What's New dialog, migration status |
| `debug-api.md` | Debug HTTP API endpoints reference |

## Quick Reference

```bash
flutter run              # Run app
flutter test             # Run tests
flutter analyze          # Check lints
dart run build_runner build  # Generate mocks
flutter build ipa --release  # Build iOS release
```

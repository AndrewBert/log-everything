---
paths: test/**/*.dart
---

# Testing Approach

## Core Principles
- **No Cubit-Specific Tests**: Never test cubits directly - test the behavior they enable
- **Test Structure**: Use Given/When/Then format with descriptive test names

## Widget Tests
- Use `find.byKey` with `ValueKey`s defined in `lib/utils/*_keys.dart`
- Mock services, provide cubits via `BlocProvider` in tests

## Mocking
- Generated via `mockito` and `build_runner`
- **Mock Setup**: Add services to `@GenerateMocks` annotation in `test/mocks.dart`
- **Test DI**: Use `test_di_registrar.dart` for test-specific service registration

## Test Organization
- Feature tests: `test/chat/`, `test/dialogs/`, `test/pages/`, `test/widgets/`
- Integration tests: Root `test/` directory (e.g., `ai_categorization_test.dart`, `entry_management_test.dart`)

## Testing New Components
1. Add mocks to `test/mocks.dart` `@GenerateMocks` annotation
2. Run `dart run build_runner build` to generate mocks
3. Use `find.byKey` with predefined keys from utils
4. Mock services, provide cubits via `BlocProvider` in tests

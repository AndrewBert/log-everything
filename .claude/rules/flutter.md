---
paths: lib/**/*.dart
---

# Flutter Code Conventions

## Widget Architecture
- **Prefer StatelessWidget + Cubit** for complex state management
- **StatefulWidget is fine** for simple local UI state (e.g., toggle visibility, text controllers)
- **Private methods** organized below `build()` method in widgets
- **Key Usage**: Define widget keys in `lib/utils/*_keys.dart` files, import for reuse

## State Management Pattern
- **Framework**: BLoC/Cubit pattern using `flutter_bloc`
- **Main Cubits**: `EntryCubit` (core business logic), `ChatCubit` (AI conversations), `VoiceInputCubit` (speech input), `OnboardingCubit` (user setup), `HomePageCubit` (UI coordination)
- **State Classes**: Use `part`/`part of` directives to link cubit and state files (not imports)
- **Dependency**: Cubits injected via `BlocProvider`/`MultiBlocProvider` at widget level

## State Management Rules
- **BLoC Events**: Only create if originating from UI layer
- **Cubits**: Handle all business logic and state management
- **State Classes**: Extend `Equatable` for value-based equality
- **copyWith**: Use dedicated bool parameters (e.g., `clearController`) to explicitly set fields to null

## Code Style
- **TextField Unfocus**: Use `onTapOutside` + wrap siblings with `TextFieldTapRegion`
- **Comments**: Prefix with `"CP"` when adding comments
- **Barrel Files**: Use for managing exports/imports
- **withOpacity**: Deprecated - use `Color.withValues()` instead
- **Trailing Commas**: Preserved by formatter (120 char line width)
- **Avoid Unnecessary Comments**: Dont litter the codebase with comments explaining easy to understand code
- **SnackBar with actions**: Always set `persist: false` on SnackBars that have a `SnackBarAction` unless you want them to stay on screen indefinitely. Flutter defaults `persist` to `action != null`.

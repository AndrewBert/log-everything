**Copilot Instructions**

This project uses **Flutter** and **Dart**.

### 🧱 General Guidelines
- Use only `StatelessWidget`s.  
- Use **Cubits** and **Blocs** for all state management.  
- Prefix any comments you write with `"CP"`.  
- Only create Bloc events if they originate from the **UI layer**.  
- Use **barrel files** to manage exports and imports.
- 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss. Color withValues(
      {double? alpha,
      double? red,
      double? green,
      double? blue,
      ColorSpace? colorSpace})
-  **When using `copyWith`, passing `null` as a parameter does _not_ update the field to `null` if your implementation uses nullable parameters with default values. If you need to explicitly set a field to `null`, add a dedicated `bool` parameter (e.g., `clearController`) to your `copyWith` method to clear that specific field.**
- When asked to refactor code, avoid causing a regression in functionality. If it does happen, call it out loudly.
- When creating a new cubit and state, use "part 'test_state.dart';" and "part of 'test_cubit.dart';" to link them instead of imports
- Organize private methods below the build method in widgets
- If you recognize a mistake you made and fix it, update this file copilot-instructions.md with a rule so it is avoided in the future

# Copilot Coding Rules and Guidelines

## Flutter Widget Testing
- When writing Flutter widget tests, always prefer using `find.byKey` with well-defined `ValueKey`s for important widgets and actions, instead of relying on widget type or ancestor relationships. This makes tests more robust and less likely to break if the widget tree changes.
- When adding `ValueKey`s to widgets, define them in a relevant `_keys.dart` file within the `lib/utils/` directory (e.g., `app_bar_keys.dart`, `widget_keys.dart`) and import this file to use the key constants. This promotes reusability and avoids string literals for keys.

## Object Equality
- When comparing objects for equality, always override the `==` operator and `hashCode` method in your classes. This ensures that equality checks are meaningful and consistent.
- For value-based equality in Dart classes (e.g., for models or state objects used in tests or collections), prefer extending the `Equatable` class from the `equatable` package over manually overriding `operator==` and `hashCode`. This reduces boilerplate and potential errors.


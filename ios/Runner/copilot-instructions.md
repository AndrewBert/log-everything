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


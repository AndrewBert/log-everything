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

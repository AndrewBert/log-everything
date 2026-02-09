# Contract: SettingsCubit — Rephrase Toggle

## New Method: toggleRephrase()

```dart
/// Toggles the AI rephrase preference and persists to SharedPreferences.
void toggleRephrase() {
  final newValue = !state.rephraseEnabled;
  _prefs.setBool('ai_rephrase_enabled', newValue);
  emit(state.copyWith(rephraseEnabled: newValue));
}
```

## Init Behavior Change

On `_init()`, read the preference:
```dart
final rephraseEnabled = _prefs.getBool('ai_rephrase_enabled') ?? true;
emit(state.copyWith(rephraseEnabled: rephraseEnabled));
```

## New Dependency

`SettingsCubit` constructor gains `SharedPreferences` parameter:
```dart
SettingsCubit({
  required SharedPreferences sharedPreferences, // NEW
  required AuthService authService,
  required EntryRepository entryRepository,
  required DeviceIdService deviceIdService,
  required SnapshotService snapshotService,
  required VectorStoreService vectorStoreService,
})
```

## State Contract

```dart
// SettingsState gains:
final bool rephraseEnabled; // default: true

// copyWith gains:
bool? rephraseEnabled,

// props gains:
rephraseEnabled
```

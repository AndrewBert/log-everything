# Contract: GeneralSection — Rephrase Toggle UI

## New UI Element

A `SwitchListTile` added to the GeneralSection widget, positioned above "What's New":

```dart
SwitchListTile(
  secondary: const Icon(Icons.auto_fix_high),
  title: const Text('AI Text Cleanup'),
  subtitle: const Text('Clean up filler words and rephrase entries'),
  value: state.rephraseEnabled,
  onChanged: (_) => context.read<SettingsCubit>().toggleRephrase(),
),
```

## Data Flow

```
SettingsState.rephraseEnabled
  → BlocBuilder<SettingsCubit, SettingsState> in GeneralSection
  → SwitchListTile value
  → onChanged calls SettingsCubit.toggleRephrase()
  → New state emitted → UI rebuilds
```

## Widget Key

Add to an appropriate keys file (e.g., `lib/utils/widget_keys.dart`):
```dart
static const rephraseToggle = Key('settings_rephrase_toggle');
```

## Access Requirements

GeneralSection must have access to SettingsCubit via BlocProvider. Currently it does NOT — it's a child of SettingsPage which provides SettingsCubit. The BlocBuilder needs to wrap the toggle within GeneralSection.

Since GeneralSection is currently a StatefulWidget (pre-existing), the toggle can read from the cubit via `context.read<SettingsCubit>()` and rebuild via `BlocBuilder`.

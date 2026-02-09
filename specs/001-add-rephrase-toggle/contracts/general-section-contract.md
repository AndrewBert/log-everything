# Contract: GeneralSection — Rephrase Toggle UI

## New UI Element

A `SwitchListTile` added to the GeneralSection widget, positioned above "What's New":

```dart
BlocBuilder<SettingsCubit, SettingsState>(
  buildWhen: (prev, current) => prev.rephraseEnabled != current.rephraseEnabled,
  builder: (context, state) {
    return SwitchListTile(
      key: rephraseToggle,
      secondary: const Icon(Icons.auto_fix_high),
      title: const Text('AI Text Cleanup'),
      subtitle: const Text('Let AI clean up filler words and rephrase your entries'),
      value: state.rephraseEnabled,
      onChanged: (_) => context.read<SettingsCubit>().toggleRephrase(),
    );
  },
),
```

Note on subtitle wording: "Let AI clean up..." reads naturally in both toggle states — ON means "yes, let it," OFF means "no, don't let it." This avoids confusing the user when the toggle is OFF.

## Data Flow

```
SettingsState.rephraseEnabled
  → BlocBuilder<SettingsCubit, SettingsState> in GeneralSection
  → SwitchListTile value
  → onChanged calls SettingsCubit.toggleRephrase()
  → New state emitted → UI rebuilds
```

## Widget Key

Add to `lib/utils/widget_keys.dart` (matching existing top-level const pattern):
```dart
const Key rephraseToggle = ValueKey('settings_rephrase_toggle');
```

## Access Requirements

GeneralSection must have access to SettingsCubit via BlocProvider. It already does — it's a child of SettingsPage which provides SettingsCubit via `BlocProvider`. The `BlocBuilder` wraps just the toggle for targeted rebuilds via `buildWhen`.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myapp/dialogs/whats_new_dialog.dart';
import 'package:myapp/onboarding/onboarding.dart';
import 'package:myapp/settings/cubit/settings_cubit.dart';
import 'package:myapp/utils/widget_keys.dart';
import 'package:package_info_plus/package_info_plus.dart';

class GeneralSection extends StatefulWidget {
  const GeneralSection({super.key});

  @override
  State<GeneralSection> createState() => _GeneralSectionState();
}

class _GeneralSectionState extends State<GeneralSection> {
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      setState(() => _appVersion = info.version);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'GENERAL',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
          ),
        ),
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
        ListTile(
          leading: const Icon(Icons.new_releases_outlined),
          title: const Text("What's New"),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showDialog(
            context: context,
            builder: (_) => WhatsNewDialog(currentVersion: _appVersion),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.restart_alt),
          title: const Text('Reset Onboarding'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showResetOnboardingConfirmation(context),
        ),
        if (_appVersion.isNotEmpty)
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Version'),
            trailing: Text(
              _appVersion,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
      ],
    );
  }

  void _showResetOnboardingConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reset Onboarding'),
          content: const Text(
            'This will reset your onboarding progress and show the setup screens again. '
            'Your entries and categories will not be affected.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).pop(); // Close settings page
                final onboardingCubit = context.read<OnboardingCubit>();
                await onboardingCubit.resetOnboarding();
              },
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
  }
}

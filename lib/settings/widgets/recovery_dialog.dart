import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:myapp/settings/cubit/settings_cubit.dart';

/// CP: Dialog shown when data loss is detected after sign-in, offering recovery from snapshot.
class RecoveryDialog extends StatelessWidget {
  final RecoveryInfo recoveryInfo;

  const RecoveryDialog({super.key, required this.recoveryInfo});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy h:mm a');

    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Data Recovery Available'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'It looks like some data may have been lost during sign-in. '
                'We found a backup from before the sign-in attempt.',
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoRow(
                      label: 'Entries',
                      value: '${recoveryInfo.entryCount}',
                    ),
                    const SizedBox(height: 4),
                    _InfoRow(
                      label: 'Categories',
                      value: '${recoveryInfo.categoryCount}',
                    ),
                    const SizedBox(height: 4),
                    _InfoRow(
                      label: 'Backup created',
                      value: dateFormat.format(recoveryInfo.snapshotCreatedAt),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Would you like to restore your data from this backup?',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: state.isRecovering
                  ? null
                  : () {
                      context.read<SettingsCubit>().dismissRecovery();
                      Navigator.of(context).pop();
                    },
              child: const Text('No, Continue Without'),
            ),
            FilledButton(
              onPressed: state.isRecovering
                  ? null
                  : () async {
                      await context.read<SettingsCubit>().confirmRecovery();
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Restored ${recoveryInfo.entryCount} entries'),
                          ),
                        );
                      }
                    },
              child: state.isRecovering
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Restore Data'),
            ),
          ],
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myapp/settings/cubit/settings_cubit.dart';
import 'package:myapp/utils/logger.dart';

class AccountSection extends StatelessWidget {
  const AccountSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'ACCOUNT',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
              ),
            ),
            if (state.isAuthenticated)
              _buildSignedInView(context, state)
            else
              _buildSignedOutView(context, state),
          ],
        );
      },
    );
  }

  Widget _buildSignedInView(BuildContext context, SettingsState state) {
    final user = state.currentUser!;

    return Column(
      children: [
        ListTile(
          leading: user.photoUrl != null
              ? CircleAvatar(
                  backgroundImage: NetworkImage(user.photoUrl!),
                  onBackgroundImageError: (exception, stackTrace) {
                    AppLogger.error('Failed to load user photo', error: exception);
                  },
                )
              : CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(
                    Icons.person,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
          title: Text(user.displayName ?? 'User'),
          subtitle: Text(user.email ?? ''),
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Sign out'),
          enabled: !state.isSigningOut,
          trailing: state.isSigningOut
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          onTap: () => _showSignOutConfirmation(context),
        ),
      ],
    );
  }

  void _showSignOutConfirmation(BuildContext context) {
    showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'All local data will be cleared from this device. '
          'Your data is safely stored in the cloud and will be restored when you sign in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(true);
              context.read<SettingsCubit>().signOut();
            },
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  Widget _buildSignedOutView(BuildContext context, SettingsState state) {
    return ListTile(
      leading: const Icon(Icons.login),
      title: const Text('Sign in'),
      subtitle: const Text('Sync your data across devices'),
      enabled: !state.isSigningIn,
      trailing: state.isSigningIn
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right),
      onTap: () => _showSignInOptions(context),
    );
  }

  void _showSignInOptions(BuildContext context) {
    final cubit = context.read<SettingsCubit>();

    showModalBottomSheet<void>(
      context: context,
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Sign in with',
                    style: Theme.of(bottomSheetContext).textTheme.titleMedium,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.apple),
                  title: const Text('Apple'),
                  onTap: () {
                    Navigator.of(bottomSheetContext).pop();
                    cubit.signInWithApple();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.g_mobiledata),
                  title: const Text('Google'),
                  onTap: () {
                    Navigator.of(bottomSheetContext).pop();
                    cubit.signInWithGoogle();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

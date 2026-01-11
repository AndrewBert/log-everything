import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../utils/onboarding_keys.dart';
import '../cubit/onboarding_cubit.dart';

class WelcomeStep extends StatelessWidget {
  const WelcomeStep({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingCubit, OnboardingState>(
      buildWhen: (prev, curr) =>
          prev.isSigningIn != curr.isSigningIn ||
          prev.authErrorMessage != curr.authErrorMessage ||
          prev.signedInUser != curr.signedInUser,
      builder: (context, state) {
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // CP: App logo/icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(60),
                  ),
                  child: Icon(Icons.edit_note, size: 60, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(height: 32),
                // CP: Welcome title
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: Theme.of(context).textTheme.headlineMedium,
                    children: [
                      TextSpan(
                        text: 'Welcome to ',
                        style: TextStyle(color: Theme.of(context).textTheme.headlineMedium?.color),
                      ),
                      TextSpan(
                        text: 'Log',
                        style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: ' Splitter',
                        style: TextStyle(color: Theme.of(context).textTheme.headlineMedium?.color),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // CP: Welcome description
                Text(
                  'Your intelligent logging companion that helps you capture thoughts, organize them automatically, and chat with your memories.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[600], height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                // CP: Features preview
                _buildFeaturesList(context),
                const SizedBox(height: 32),
                // CP: Sign-in section for returning users
                _buildSignInSection(context, state),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeaturesList(BuildContext context) {
    final features = [
      {
        'icon': Icons.auto_awesome,
        'title': 'Smart Logging',
        'description': 'AI automatically categorizes your entries',
      },
      {
        'icon': Icons.chat_bubble_outline,
        'title': 'Chat with Logs',
        'description': 'Ask questions about your past entries',
      },
      {'icon': Icons.category_outlined, 'title': 'Custom Categories', 'description': 'Organize entries your way'},
    ];

    return Column(
      children:
          features.map((feature) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(feature['icon'] as IconData, color: Theme.of(context).colorScheme.primary, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          feature['title'] as String,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          feature['description'] as String,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
    );
  }

  Widget _buildSignInSection(BuildContext context, OnboardingState state) {
    // CP: If already signed in during onboarding, show confirmation
    if (state.signedInUser != null) {
      return Column(
        key: OnboardingKeys.signedInConfirmation,
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 32),
          const SizedBox(height: 8),
          Text(
            'Signed in as ${state.signedInUser!.email ?? state.signedInUser!.displayName ?? 'User'}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.green[700]),
          ),
        ],
      );
    }

    return Column(
      children: [
        // CP: Divider with "or"
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey[300])),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('or', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[500])),
            ),
            Expanded(child: Divider(color: Colors.grey[300])),
          ],
        ),
        const SizedBox(height: 24),
        // CP: "Already have an account?" text
        Text(
          'Already have an account?',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.grey[700]),
        ),
        const SizedBox(height: 16),
        // CP: Sign-in buttons or loading indicator
        if (state.isSigningIn)
          Padding(
            key: OnboardingKeys.signInLoadingIndicator,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: const CircularProgressIndicator(),
          )
        else
          Column(
            children: [
              // CP: Google Sign-In button
              _buildSignInButton(
                context,
                key: OnboardingKeys.signInWithGoogleButton,
                icon: Icons.g_mobiledata,
                label: 'Sign in with Google',
                onTap: () => context.read<OnboardingCubit>().signInWithGoogle(),
              ),
              // CP: Apple Sign-In button (iOS only)
              if (Platform.isIOS) ...[
                const SizedBox(height: 12),
                _buildSignInButton(
                  context,
                  key: OnboardingKeys.signInWithAppleButton,
                  icon: Icons.apple,
                  label: 'Sign in with Apple',
                  onTap: () => context.read<OnboardingCubit>().signInWithApple(),
                ),
              ],
            ],
          ),
        // CP: Error message display
        if (state.authErrorMessage != null) ...[
          const SizedBox(height: 16),
          Container(
            key: OnboardingKeys.authErrorContainer,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.authErrorMessage!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
                IconButton(
                  key: OnboardingKeys.authErrorDismissButton,
                  icon: const Icon(Icons.close, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => context.read<OnboardingCubit>().clearAuthError(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSignInButton(
    BuildContext context, {
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return OutlinedButton(
      key: key,
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        side: BorderSide(color: Colors.grey[300]!),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: Colors.grey[700]),
          const SizedBox(width: 12),
          Text(label, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[700])),
        ],
      ),
    );
  }
}

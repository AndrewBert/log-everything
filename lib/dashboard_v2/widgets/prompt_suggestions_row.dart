import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myapp/dashboard_v2/cubit/dashboard_v2_cubit.dart';

class PromptSuggestionsRow extends StatelessWidget {
  const PromptSuggestionsRow({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardV2Cubit, DashboardV2State>(
      buildWhen: (prev, current) => prev.promptSuggestions != current.promptSuggestions,
      builder: (context, state) {
        final prompts = state.promptSuggestions;

        // CP: Hide entirely when no prompts
        if (prompts.isEmpty) {
          return const SizedBox.shrink();
        }

        return _PromptChipsRow(prompts: prompts);
      },
    );
  }
}

class _PromptChipsRow extends StatelessWidget {
  final List<String> prompts;

  const _PromptChipsRow({required this.prompts});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: prompts.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final prompt = prompts[index];
          return _PromptChip(
            prompt: prompt,
            onTap: () {
              HapticFeedback.lightImpact();
              context.read<DashboardV2Cubit>().navigateToChatWithPrompt(context, prompt);
            },
          )
              .animate()
              .fadeIn(
                duration: 300.ms,
                delay: (index * 100).ms,
              )
              .slideX(
                begin: 0.1,
                end: 0,
                duration: 300.ms,
                delay: (index * 100).ms,
                curve: Curves.easeOut,
              );
        },
      ),
    );
  }
}

class _PromptChip extends StatelessWidget {
  final String prompt;
  final VoidCallback onTap;

  const _PromptChip({
    required this.prompt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome,
                size: 14,
                color: theme.colorScheme.primary.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 6),
              Text(
                prompt,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

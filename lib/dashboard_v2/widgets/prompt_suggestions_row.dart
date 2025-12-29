import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myapp/dashboard_v2/cubit/dashboard_v2_cubit.dart';

// CP: Warm editorial color palette matching app aesthetic
class _PromptColors {
  static const warmAmber = Color(0xFFF59E0B);
  static const warmCharcoal = Color(0xFF292524);
  static const warmStone = Color(0xFF78716C);
  static const warmSurface = Color(0xFFFFFBEB);
}

class PromptSuggestionsRow extends StatelessWidget {
  const PromptSuggestionsRow({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardV2Cubit, DashboardV2State>(
      buildWhen: (prev, current) =>
          prev.promptSuggestions != current.promptSuggestions ||
          prev.isInputBarFocused != current.isInputBarFocused ||
          prev.inputBarHasText != current.inputBarHasText,
      builder: (context, state) {
        final prompts = state.promptSuggestions;
        final shouldShow = state.isInputBarFocused && !state.inputBarHasText && prompts.isNotEmpty;

        // CP: Animate in/out based on visibility
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: shouldShow ? _PromptChipsRow(prompts: prompts) : const SizedBox.shrink(),
        );
      },
    );
  }
}

class _PromptChipsRow extends StatelessWidget {
  final List<String> prompts;

  const _PromptChipsRow({required this.prompts});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        // CP: Gradient fade from page background to transparent at top
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.3, 1.0],
          colors: [
            Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.0),
            Theme.of(context).scaffoldBackgroundColor,
            Theme.of(context).scaffoldBackgroundColor,
          ],
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 16, right: 16, top: 8),
        itemCount: prompts.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
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
                duration: 400.ms,
                delay: (index * 80).ms,
                curve: Curves.easeOut,
              )
              .slideY(
                begin: 0.3,
                end: 0,
                duration: 400.ms,
                delay: (index * 80).ms,
                curve: Curves.easeOutCubic,
              )
              .scale(
                begin: const Offset(0.9, 0.9),
                end: const Offset(1, 1),
                duration: 400.ms,
                delay: (index * 80).ms,
                curve: Curves.easeOutCubic,
              );
        },
      ),
    );
  }
}

class _PromptChip extends StatefulWidget {
  final String prompt;
  final VoidCallback onTap;

  const _PromptChip({
    required this.prompt,
    required this.onTap,
  });

  @override
  State<_PromptChip> createState() => _PromptChipState();
}

class _PromptChipState extends State<_PromptChip> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _PromptColors.warmSurface,
                _PromptColors.warmSurface.withValues(alpha: 0.95),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: _PromptColors.warmAmber.withValues(alpha: 0.25),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _PromptColors.warmAmber.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                widget.prompt,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _PromptColors.warmCharcoal,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 10,
                color: _PromptColors.warmStone.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

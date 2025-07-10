import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myapp/entry/cubit/entry_cubit.dart';
import 'package:myapp/widgets/voice_input/cubit/voice_input_cubit.dart';
import 'package:myapp/widgets/voice_input/cubit/voice_input_state.dart';

class FloatingInputBar extends StatefulWidget {
  const FloatingInputBar({super.key});

  @override
  State<FloatingInputBar> createState() => _FloatingInputBarState();
}

class _FloatingInputBarState extends State<FloatingInputBar> with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isSubmitting = false;
  bool _isExpanded = false;
  bool _hasText = false;

  late AnimationController _animationController;
  late AnimationController _waveformController;
  late Animation<double> _widthAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _waveformController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _widthAnimation =
        Tween<double>(
          begin: 0.8, // CC: Start at 80% width
          end: 1.0, // CC: Expand to full width
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _focusNode.addListener(_onFocusChange);
    _textController.addListener(_onTextChanged);
  }

  void _onFocusChange() {
    setState(() {
      _isExpanded = _focusNode.hasFocus;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _onTextChanged() {
    setState(() {
      _hasText = _textController.text.isNotEmpty;
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _waveformController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      await context.read<EntryCubit>().addEntry(text);
      _textController.clear();
      _focusNode.unfocus();
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding entry: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _buildRecordingIndicator(ThemeData theme) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          // CC: Recording icon with subtle animation
          AnimatedBuilder(
            animation: _waveformController,
            builder: (context, child) {
              return Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.error.withValues(
                    alpha: 0.15 + (_waveformController.value * 0.1),
                  ),
                ),
                child: Icon(
                  Icons.mic,
                  color: theme.colorScheme.error,
                  size: 24,
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recording...',
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Tap to stop',
                  style: TextStyle(
                    color: theme.colorScheme.error.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // CC: Stop button
          Container(
            margin: const EdgeInsets.only(right: 8),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.error,
            ),
            child: Icon(
              Icons.stop_rounded,
              color: theme.colorScheme.onError,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocConsumer<VoiceInputCubit, VoiceInputState>(
      listenWhen: (prev, current) =>
          prev.transcribedText != current.transcribedText &&
          current.transcribedText != null &&
          current.transcribedText!.isNotEmpty,
      listener: (context, state) {
        // CC: Append transcribed text to existing text
        if (state.transcribedText != null) {
          final currentText = _textController.text;
          final newText = currentText.isEmpty ? state.transcribedText! : '$currentText ${state.transcribedText!}';
          _textController.text = newText;
          // CC: Move cursor to end
          _textController.selection = TextSelection.fromPosition(
            TextPosition(offset: newText.length),
          );
        }
      },
      builder: (context, voiceState) {
        final isRecording = voiceState.isRecording;
        final isTranscribing = voiceState.transcriptionStatus == TranscriptionStatus.transcribing;

        // CC: Start/stop waveform animation based on recording state
        if (isRecording && !_waveformController.isAnimating) {
          _waveformController.repeat();
        } else if (!isRecording && _waveformController.isAnimating) {
          _waveformController.stop();
          _waveformController.reset();
        }

        return Align(
          alignment: Alignment.bottomCenter,
          child: AnimatedBuilder(
            animation: _widthAnimation,
            builder: (context, child) {
              return FractionallySizedBox(
                widthFactor: _widthAnimation.value,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  height: 56,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: Stack(
                      children: [
                        // CC: Show recording indicator when recording
                        if (isRecording)
                          Positioned.fill(
                            child: _buildRecordingIndicator(theme),
                          ),

                        // CC: Show input field when not recording
                        if (!isRecording)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              children: [
                                // CC: Voice input button - hide when focused or has text
                                if (!_hasText && !_isExpanded) ...[
                                  IconButton(
                                    onPressed: isTranscribing
                                        ? null
                                        : () {
                                            context.read<VoiceInputCubit>().startRecording();
                                            _focusNode.unfocus();
                                          },
                                    icon: isTranscribing
                                        ? SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: theme.colorScheme.primary,
                                            ),
                                          )
                                        : Icon(
                                            Icons.mic,
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                    tooltip: 'Start Recording',
                                  ),
                                ],

                                // CC: Text input field
                                Expanded(
                                  child: TextField(
                                    controller: _textController,
                                    focusNode: _focusNode,
                                    decoration: InputDecoration(
                                      hintText: "Add log",
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: _hasText ? 16 : 12,
                                        vertical: 16,
                                      ),
                                    ),
                                    textAlign: _isExpanded || _hasText ? TextAlign.start : TextAlign.center,
                                    textInputAction: TextInputAction.send,
                                    onSubmitted: (_) => _handleSubmit(),
                                    maxLines: 1,
                                    keyboardType: TextInputType.multiline,
                                    textCapitalization: TextCapitalization.sentences,
                                    onTapOutside: (_) {
                                      _focusNode.unfocus();
                                    },
                                  ),
                                ),

                                // CC: Send button
                                IconButton(
                                  onPressed: (_isSubmitting || isTranscribing || !_hasText) ? null : _handleSubmit,
                                  icon: _isSubmitting
                                      ? SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: theme.colorScheme.primary,
                                          ),
                                        )
                                      : Icon(
                                          Icons.send_rounded,
                                          color: _hasText
                                              ? theme.colorScheme.primary
                                              : theme.colorScheme.onSurface.withValues(alpha: 0.38),
                                        ),
                                  tooltip: 'Send',
                                ),
                              ],
                            ),
                          ),

                        // CC: Make recording indicator tappable
                        if (isRecording)
                          Positioned.fill(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(28),
                                onTap: () {
                                  context.read<VoiceInputCubit>().stopRecording();
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

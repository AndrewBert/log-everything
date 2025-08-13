import 'dart:async';
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
  bool _justTranscribed = false;
  bool _textOverflows = false;
  Timer? _transcriptionReviewTimer;

  late AnimationController _animationController;
  late AnimationController _waveformController;
  late AnimationController _pulseController;
  late AnimationController _heightController;
  late Animation<double> _widthAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _heightAnimation;
  double _currentTextHeight = 56.0;

  // TODO: QUICK FIX - To temporarily disable height animation issues:
  // 1. Comment out all _updateTextHeight() calls
  // 2. Change Container back to AnimatedContainer with duration: 300ms
  // 3. Use maxHeight: _isExpanded ? 200 : 56 instead of _heightAnimation.value

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

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _heightController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _widthAnimation =
        Tween<double>(
          begin: 0.9, // CC: Start at 90% width (wider compact state)
          end: 1.0, // CC: Expand to full width
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _pulseAnimation =
        Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(
          CurvedAnimation(
            parent: _pulseController,
            curve: Curves.easeInOut,
          ),
        );

    _heightAnimation =
        Tween<double>(
          begin: 56.0,
          end: 200.0,
        ).animate(
          CurvedAnimation(
            parent: _heightController,
            curve: Curves.easeInOutCubic,
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
        _pulseController.stop();
        _pulseController.reset();
        // CC: Cancel review timer if user focuses the field
        _transcriptionReviewTimer?.cancel();
        _justTranscribed = false;

        // CC: Calculate and animate to required height
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateTextHeight();
        });
      } else {
        // CC: Don't collapse immediately if just transcribed
        if (!_justTranscribed) {
          _animationController.reverse();

          // CC: Animate height back to single line
          // TODO: This collapse animation is not visible - investigate why
          // Possible issues:
          // 1. _heightController.forward(from: 0) might be resetting animation
          // 2. Container doesn't animate, need AnimatedContainer
          // 3. Animation duration might be too fast
          _currentTextHeight = 56.0;
          _heightAnimation =
              Tween<double>(
                begin: _heightAnimation.value,
                end: 56.0,
              ).animate(
                CurvedAnimation(
                  parent: _heightController,
                  curve: Curves.easeInOutCubic,
                ),
              );
          _heightController.forward(from: 0);
        }
        // CC: Scroll text field to beginning when unfocused
        if (_textController.text.isNotEmpty) {
          // CC: Need postFrameCallback to fix text visibility bug where beginning is cut off
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // CC: Force TextField to scroll to start by selecting then deselecting
            _textController.selection = TextSelection(
              baseOffset: 0,
              extentOffset: 1,
            );
            _textController.selection = const TextSelection.collapsed(offset: 0);
          });
          _pulseController.repeat(reverse: true);
        }
      }
    });
  }

  void _onTextChanged() {
    setState(() {
      _hasText = _textController.text.isNotEmpty;
      // CC: Start/stop pulse animation based on text presence
      if (_hasText && !_isExpanded) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    });

    // CC: Calculate required height for multi-line text
    if (_isExpanded) {
      _updateTextHeight();
    }

    // CC: Overflow will be checked by LayoutBuilder
    if (_isExpanded || !_hasText) {
      // CC: Reset overflow state when expanded or no text
      setState(() {
        _textOverflows = false;
      });
    }
  }

  void _checkTextOverflow(double availableWidth) {
    // CC: Calculate if text overflows based on available width
    if (!_hasText || _isExpanded) {
      setState(() {
        _textOverflows = false;
      });
      return;
    }

    final textSpan = TextSpan(
      text: _textController.text,
      style: Theme.of(context).textTheme.bodyLarge,
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );

    textPainter.layout(maxWidth: double.infinity);

    // CC: Account for text field padding and gradient space
    final textFieldPadding = _hasText ? 4.0 : 12.0; // Left padding
    final rightPadding = 16.0;
    final gradientSpace = 25.0; // Space needed for gradient/ellipsis
    final totalPadding = textFieldPadding + rightPadding + gradientSpace;

    final shouldOverflow = textPainter.width > (availableWidth - totalPadding);

    if (_textOverflows != shouldOverflow) {
      setState(() {
        _textOverflows = shouldOverflow;
      });
    }
  }

  void _updateTextHeight() {
    // TODO: Height animation for multi-line text expansion is causing issues:
    // 1. App bar color changes as if scrolling (Material 3 scroll behavior)
    // 2. Consider disabling or simplifying this animation for now
    // 3. The animation from expanded to compact view is NOT working properly:
    //    - Not visible when tapping outside to unfocus
    //    - Not visible when voice recording timer expires
    //    - Seems to just snap instead of animating smoothly
    //
    // DEBUGGING HINTS:
    // - Check if Container vs AnimatedContainer is the issue
    // - Verify _heightAnimation.value is actually changing during collapse
    // - Check if setState is being called at the right times
    // - Consider using a single AnimatedContainer with dynamic height instead

    // CC: Calculate the required height based on text content
    final textSpan = TextSpan(
      text: _textController.text.isEmpty ? 'Add log' : _textController.text,
      style: Theme.of(context).textTheme.bodyLarge,
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      maxLines: 6,
    );

    // CC: Calculate available width more accurately
    final screenWidth = MediaQuery.of(context).size.width;
    final containerMargin = 32.0; // 16 * 2
    final containerPadding = 16.0; // 8 * 2
    final iconSpace = _hasText ? 144.0 : 96.0; // Space for send button and clear button when text present
    final availableWidth = (screenWidth * _widthAnimation.value) - containerMargin - containerPadding - iconSpace;

    textPainter.layout(maxWidth: availableWidth > 0 ? availableWidth : 100);

    // CC: Calculate height with vertical padding (16 * 2 = 32)
    final lineHeight = textPainter.computeLineMetrics().isNotEmpty
        ? textPainter.computeLineMetrics().first.height
        : 24.0;
    final numberOfLines = (textPainter.height / lineHeight).ceil().clamp(1, 6);
    final calculatedHeight = (56.0 + ((numberOfLines - 1) * 24.0)).clamp(56.0, 200.0);

    if ((calculatedHeight - _currentTextHeight).abs() > 1.0) {
      _currentTextHeight = calculatedHeight;

      // CC: Update height animation with new target
      _heightAnimation =
          Tween<double>(
            begin: _heightAnimation.value,
            end: calculatedHeight,
          ).animate(
            CurvedAnimation(
              parent: _heightController,
              curve: Curves.easeInOutCubic,
            ),
          );

      _heightController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _transcriptionReviewTimer?.cancel();
    _animationController.dispose();
    _waveformController.dispose();
    _pulseController.dispose();
    _heightController.dispose();
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

      // CC: Reset transcription state and cancel timer when submitting
      _transcriptionReviewTimer?.cancel();
      setState(() {
        _justTranscribed = false;
        _isExpanded = false;
      });
      _animationController.reverse();
      _pulseController.stop();
      _pulseController.reset();

      // CC: Animate height back to single line
      _currentTextHeight = 56.0;
      _heightAnimation =
          Tween<double>(
            begin: _heightAnimation.value,
            end: 56.0,
          ).animate(
            CurvedAnimation(
              parent: _heightController,
              curve: Curves.easeInOutCubic,
            ),
          );
      _heightController.forward(from: 0);
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
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            // CC: Cancel button - similar to clear text button
            IconButton(
              onPressed: () {
                context.read<VoiceInputCubit>().cancelRecording();
                HapticFeedback.lightImpact();
              },
              icon: Icon(
                Icons.close,
                color: theme.colorScheme.onPrimaryContainer,
                size: 20,
              ),
              tooltip: 'Cancel',
            ),
            // CC: Simple pulsing dot
            AnimatedBuilder(
              animation: _waveformController,
              builder: (context, child) {
                return Container(
                  margin: const EdgeInsets.only(right: 12),
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(
                      alpha: 0.5 + (_waveformController.value * 0.5),
                    ),
                    shape: BoxShape.circle,
                  ),
                );
              },
            ),
            Expanded(
              child: Text(
                'Recording...',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            // CC: Stop button - will transcribe
            IconButton(
              onPressed: () {
                context.read<VoiceInputCubit>().stopRecording();
              },
              icon: Icon(
                Icons.stop_rounded,
                color: theme.colorScheme.primary,
              ),
              tooltip: 'Stop & Transcribe',
            ),
          ],
        ),
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

          // CC: Keep field expanded for review
          setState(() {
            _justTranscribed = true;
            _isExpanded = true;
          });
          _animationController.forward();

          // CC: Calculate and animate to required height
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _updateTextHeight();
          });
          // CC: Cancel any existing timer
          _transcriptionReviewTimer?.cancel();

          // CC: Start new timer to collapse after 4 seconds
          _transcriptionReviewTimer = Timer(const Duration(seconds: 4), () {
            if (mounted && _justTranscribed && !_focusNode.hasFocus) {
              setState(() {
                _isExpanded = false;
                _justTranscribed = false;
              });
              _animationController.reverse();

              // CC: Animate height back to single line
              _currentTextHeight = 56.0;
              _heightAnimation =
                  Tween<double>(
                    begin: _heightAnimation.value,
                    end: 56.0,
                  ).animate(
                    CurvedAnimation(
                      parent: _heightController,
                      curve: Curves.easeInOutCubic,
                    ),
                  );
              _heightController.forward(from: 0);

              // CC: Overflow will be checked by LayoutBuilder on next frame
            }
          });
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
                child: AnimatedBuilder(
                  animation: Listenable.merge([_pulseAnimation, _heightAnimation]),
                  builder: (context, child) {
                    // TODO: Animation issue - changing from AnimatedContainer to Container
                    // broke the smooth collapse animation. The height animation controller
                    // might not be properly animating the collapse. Consider reverting to
                    // AnimatedContainer or fixing the height animation controller logic.
                    return Container(
                      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      constraints: BoxConstraints(
                        minHeight: 56,
                        maxHeight: _heightAnimation.value,
                      ),
                      decoration: BoxDecoration(
                        color: _hasText && !_isExpanded
                            ? theme.colorScheme.primaryContainer
                            : theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(28),
                        border: _hasText && !_isExpanded
                            ? Border.all(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.2 + (_pulseAnimation.value * 0.2),
                                ),
                                width: 1.5,
                              )
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: _hasText && !_isExpanded
                                ? theme.colorScheme.primary.withValues(alpha: 0.2)
                                : Colors.black.withValues(alpha: 0.1),
                            blurRadius: _hasText && !_isExpanded ? 12 : 10,
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
                                    // CC: Clear button - show when has text and not focused
                                    if (_hasText && !_isExpanded) ...[
                                      IconButton(
                                        onPressed: () {
                                          _textController.clear();
                                          _transcriptionReviewTimer?.cancel();
                                          setState(() {
                                            _justTranscribed = false;
                                            _textOverflows = false;
                                          });
                                          HapticFeedback.lightImpact();
                                        },
                                        icon: Icon(
                                          Icons.close,
                                          color: _hasText && !_isExpanded
                                              ? theme.colorScheme.onPrimaryContainer
                                              : theme.colorScheme.onSurfaceVariant,
                                          size: 20,
                                        ),
                                        tooltip: 'Clear',
                                      ),
                                    ],

                                    // CC: Text input field with overflow indicator
                                    Expanded(
                                      child: LayoutBuilder(
                                        builder: (context, constraints) {
                                          // CC: Check overflow whenever layout changes
                                          if (_hasText && !_isExpanded) {
                                            WidgetsBinding.instance.addPostFrameCallback((_) {
                                              _checkTextOverflow(constraints.maxWidth);
                                            });
                                          }

                                          return Stack(
                                            alignment: Alignment.centerRight,
                                            children: [
                                              TextField(
                                                controller: _textController,
                                                focusNode: _focusNode,
                                                decoration: InputDecoration(
                                                  hintText: _justTranscribed ? "Review transcription..." : "Add log",
                                                  hintStyle: TextStyle(
                                                    color: _hasText && !_isExpanded
                                                        ? theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.6)
                                                        : null,
                                                  ),
                                                  border: InputBorder.none,
                                                  contentPadding: EdgeInsets.only(
                                                    left: _isExpanded
                                                        ? 16
                                                        : (_hasText
                                                              ? 4
                                                              : 48), // CC: Add padding to center when empty (48px = icon button width)
                                                    right: _hasText && !_isExpanded && _textOverflows ? 25 : 16,
                                                    top: 16,
                                                    bottom: 16,
                                                  ),
                                                ),
                                                style: TextStyle(
                                                  color: _hasText && !_isExpanded
                                                      ? theme.colorScheme.onPrimaryContainer
                                                      : null,
                                                ),
                                                textAlign: _isExpanded || _hasText ? TextAlign.start : TextAlign.center,
                                                textInputAction: TextInputAction.newline,
                                                onSubmitted: (_) => _handleSubmit(),
                                                minLines: 1,
                                                maxLines: _isExpanded ? 6 : 1,
                                                keyboardType: TextInputType.multiline,
                                                textCapitalization: TextCapitalization.sentences,
                                                onTap: () {
                                                  // CC: Move cursor to end when tapping collapsed field with text
                                                  if (!_isExpanded && _hasText) {
                                                    _textController.selection = TextSelection.fromPosition(
                                                      TextPosition(offset: _textController.text.length),
                                                    );
                                                  }
                                                },
                                                onTapOutside: (_) {
                                                  _focusNode.unfocus();
                                                },
                                              ),
                                              // CC: Gradient fade indicator for text overflow
                                              if (_hasText && !_isExpanded && _textOverflows)
                                                Positioned(
                                                  right: 0,
                                                  top: 0,
                                                  bottom: 0,
                                                  child: IgnorePointer(
                                                    child: Container(
                                                      width: 24,
                                                      decoration: BoxDecoration(
                                                        gradient: LinearGradient(
                                                          begin: Alignment.centerLeft,
                                                          end: Alignment.centerRight,
                                                          colors: [
                                                            theme.colorScheme.primaryContainer.withValues(alpha: 0),
                                                            theme.colorScheme.primaryContainer.withValues(alpha: 0.9),
                                                            theme.colorScheme.primaryContainer,
                                                          ],
                                                          stops: const [0.0, 0.5, 1.0],
                                                        ),
                                                      ),
                                                      child: Center(
                                                        child: Text(
                                                          '…',
                                                          style: TextStyle(
                                                            color: theme.colorScheme.onPrimaryContainer,
                                                            fontWeight: FontWeight.w600,
                                                            fontSize: 16,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          );
                                        },
                                      ),
                                    ),

                                    // CC: Send button when has text, Mic button when empty
                                    if (_hasText) ...[
                                      // Send button
                                      IconButton(
                                        onPressed: (_isSubmitting || isTranscribing) ? null : _handleSubmit,
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
                                                color: theme.colorScheme.primary,
                                              ),
                                        tooltip: 'Send',
                                      ),
                                    ] else ...[
                                      // Mic button when no text
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
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}

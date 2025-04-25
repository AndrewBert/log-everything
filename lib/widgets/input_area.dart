import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myapp/pages/cubit/home_screen_cubit.dart';
import 'package:myapp/pages/cubit/home_screen_state.dart';
import 'voice_input/voice_input.dart'; // Assuming VoiceInputSection is in the same directory

class InputArea extends StatefulWidget {
  final void Function(String text) onSendPressed;
  final void Function({
    required BuildContext context,
    required Widget content,
    Duration? duration,
    SnackBarAction? action,
    Color? backgroundColor,
  })
  showSnackBar;

  const InputArea({
    super.key,
    required this.onSendPressed,
    required this.showSnackBar,
  });

  @override
  State<InputArea> createState() => _InputAreaState();
}

class _InputAreaState extends State<InputArea> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _inputFocusNode.addListener(_onInputFocusChange);
  }

  @override
  void dispose() {
    _textController.dispose();
    _inputFocusNode.removeListener(_onInputFocusChange);
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _onInputFocusChange() {
    // Update HomeScreenCubit about focus state
    if (mounted && context.mounted) {
      context.read<HomeScreenCubit>().setInputFocus(_inputFocusNode.hasFocus);
    }
  }

  void _handleLocalSend() {
    final currentText = _textController.text.trim();
    // Call the callback passed from HomePage
    widget.onSendPressed(currentText);

    // Clear text and unfocus - managed locally now
    _textController.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeScreenCubit, HomeScreenState>(
      buildWhen:
          (prev, current) => prev.isInputFocused != current.isInputFocused,
      builder: (context, homeScreenState) {
        final isInputFocused = homeScreenState.isInputFocused;

        return Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Material(
            elevation: 8.0,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20.0),
                topRight: Radius.circular(20.0),
              ),
            ),
            child: Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 8,
                top: 12,
                // Add MediaQuery padding.bottom to account for safe area
                bottom:
                    MediaQuery.of(context).viewInsets.bottom +
                    MediaQuery.of(context).padding.bottom +
                    12,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20.0),
                  topRight: Radius.circular(20.0),
                ),
              ),
              child: TextField(
                focusNode: _inputFocusNode,
                controller: _textController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25.0),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  // Replace deprecated surfaceVariant
                  fillColor: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest // Use replacement
                      // Replace deprecated withOpacity
                      .withAlpha((255 * 0.6).round()),
                  labelText: isInputFocused ? 'Enter log entry' : null,
                  hintText: 'What happened?...',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.only(right: 4.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        VoiceInput(
                          textController: _textController,
                          inputFocusNode: _inputFocusNode,
                          isInputFocused: isInputFocused,
                          showSnackBar: (
                            BuildContext
                            ctx, { // Context from VoiceInputSection
                            required Widget content,
                            Duration? duration,
                            SnackBarAction? action,
                            Color? backgroundColor,
                          }) {
                            // Call the HomePage's snackbar function using the InputArea's context
                            widget.showSnackBar(
                              context:
                                  context, // Use context from InputArea build method
                              content: content,
                              duration: duration, // Pass nullable duration
                              action: action,
                              backgroundColor: backgroundColor,
                            );
                          },
                        ),
                        IconButton(
                          onPressed: _handleLocalSend,
                          icon: const Icon(Icons.send_rounded),
                          color: Theme.of(context).colorScheme.primary,
                          iconSize: 28,
                          tooltip: 'Add Entry',
                        ),
                      ],
                    ),
                  ),
                ),
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                onSubmitted: (_) => _handleLocalSend(),
                minLines: 1,
                maxLines: 5,
                onTapOutside: (_) {
                  if (_inputFocusNode.hasFocus) {
                    FocusScope.of(context).unfocus();
                  }
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

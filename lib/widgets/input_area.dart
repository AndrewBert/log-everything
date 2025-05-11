import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myapp/pages/cubit/home_page_cubit.dart';
import 'package:myapp/pages/cubit/home_page_state.dart';
import 'voice_input/voice_input.dart';
import 'package:myapp/chat/chat.dart';

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
    if (mounted &&
        context.mounted &&
        !context.read<HomePageCubit>().state.isChatOpen) {
      context.read<HomePageCubit>().setInputFocus(_inputFocusNode.hasFocus);
    }
  }

  void _handleLocalSend() {
    final currentText = _textController.text.trim();
    final homePageCubit = context.read<HomePageCubit>();
    final chatCubit = context.read<ChatCubit>();

    if (homePageCubit.state.isChatOpen) {
      if (currentText.isNotEmpty) {
        chatCubit.addUserMessage(currentText);
      }
    } else {
      widget.onSendPressed(currentText);
    }

    _textController.clear();
    if (!homePageCubit.state.isChatOpen && _inputFocusNode.hasFocus) {
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomePageCubit, HomePageState>(
      buildWhen:
          (prev, current) =>
              prev.isInputFocused != current.isInputFocused ||
              prev.isChatOpen != current.isChatOpen,
      builder: (context, homeScreenState) {
        final isInputFocused = homeScreenState.isInputFocused;
        final isChatOpen = homeScreenState.isChatOpen;

        final String hintText =
            isChatOpen ? 'Type your message...' : 'What happened?...';
        final String labelText =
            isChatOpen
                ? 'Chatting...'
                : (isInputFocused ? 'Enter log entry' : 'What happened?...');

        return Material(
          elevation: 8.0,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20.0),
              topRight: Radius.circular(20.0),
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20.0),
                topRight: Radius.circular(20.0),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 8,
                    top: 8,
                    bottom: 4.0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          focusNode: _inputFocusNode,
                          controller: _textController,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25.0),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withAlpha((255 * 0.6).round()),
                            labelText:
                                (isInputFocused || isChatOpen)
                                    ? labelText
                                    : null,
                            hintText: hintText,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          onSubmitted: (_) => _handleLocalSend(),
                          minLines: 1,
                          maxLines: 5,
                          onTapOutside: (_) {
                            if (_inputFocusNode.hasFocus && !isChatOpen) {
                              FocusScope.of(context).unfocus();
                            }
                          },
                          onTap: () {
                            if (isChatOpen && !_inputFocusNode.hasFocus) {
                              _inputFocusNode.requestFocus();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(
                    left: 16.0,
                    right: 16.0,
                    top: 0,
                    bottom:
                        MediaQuery.of(context).viewInsets.bottom > 0
                            ? 8.0
                            : MediaQuery.of(context).padding.bottom + 8.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      TextButton.icon(
                        icon: Icon(
                          isChatOpen
                              ? Icons.forum_rounded
                              : Icons.forum_outlined,
                        ),
                        label: Text(isChatOpen ? 'Close Chat' : 'AI Chat'),
                        style: TextButton.styleFrom(
                          foregroundColor:
                              isChatOpen
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 4.0,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () {
                          context.read<HomePageCubit>().toggleChatOpen();
                          if (!isChatOpen) {
                            _inputFocusNode.requestFocus();
                          } else {
                            if (_inputFocusNode.hasFocus) {
                              FocusScope.of(context).unfocus();
                            }
                          }
                        },
                      ),
                      const Spacer(),
                      if (!isChatOpen)
                        VoiceInput(
                          textController: _textController,
                          inputFocusNode: _inputFocusNode,
                          isInputFocused: isInputFocused,
                          showSnackBar: (
                            BuildContext ctx, {
                            required Widget content,
                            Duration? duration,
                            SnackBarAction? action,
                            Color? backgroundColor,
                          }) {
                            widget.showSnackBar(
                              context: context,
                              content: content,
                              duration: duration,
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
                        tooltip: isChatOpen ? 'Send Message' : 'Add Entry',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

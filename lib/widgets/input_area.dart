import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myapp/pages/cubit/home_page_cubit.dart';
import 'package:myapp/pages/cubit/home_page_state.dart';
import 'package:myapp/entry/cubit/entry_cubit.dart';
import 'voice_input/voice_input.dart';
import 'voice_input/cubit/voice_input_cubit.dart';
import 'voice_input/cubit/voice_input_state.dart';
import 'package:myapp/chat/chat.dart';
import 'package:myapp/utils/widget_keys.dart';

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

  const InputArea({super.key, required this.onSendPressed, required this.showSnackBar});

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
    if (mounted && context.mounted) {
      context.read<HomePageCubit>().setInputFocus(_inputFocusNode.hasFocus);
    }
  }

  // CP: Handle editing mode submission
  void _handleEditingSubmit() {
    final currentText = _textController.text.trim();
    final entryCubit = context.read<EntryCubit>();
    final editingEntry = entryCubit.state.editingEntry;

    if (editingEntry != null) {
      final taskStatus = entryCubit.state.editingIsTask;
      entryCubit.finishEditingEntry(currentText, editingEntry.category, isTask: taskStatus);
      _textController.clear();
      if (_inputFocusNode.hasFocus) {
        // CP: Use focusedChild?.unfocus() for more reliable behavior
        FocusScope.of(context).focusedChild?.unfocus();
      }

      // CP: Only show success message if text was not empty (actual update occurred)
      if (currentText.isNotEmpty) {
        widget.showSnackBar(
          context: context,
          content: const Text('Entry updated'),
          duration: const Duration(seconds: 1),
        );
      }
    }
  }

  // CP: Handle canceling edit mode
  void _handleEditingCancel() {
    context.read<EntryCubit>().cancelEditingEntry();
    _textController.clear();
    if (_inputFocusNode.hasFocus) {
      // CP: Use focusedChild?.unfocus() for more reliable behavior
      FocusScope.of(context).focusedChild?.unfocus();
    }
  }

  void _handleLocalSend() {
    final entryCubit = context.read<EntryCubit>();

    // CP: Handle editing mode submission
    if (entryCubit.state.isEditingMode) {
      _handleEditingSubmit();
      return;
    }

    final currentText = _textController.text.trim();
    final homePageCubit = context.read<HomePageCubit>();
    final chatCubit = context.read<ChatCubit>();
    final voiceCubit = context.read<VoiceInputCubit>();

    if (homePageCubit.state.isChatOpen) {
      // CP: Handle voice recording during chat send
      if (voiceCubit.state.isRecording) {
        HapticFeedback.mediumImpact();
        voiceCubit.stopRecordingAndSendToChat(currentText, chatCubit);
        _textController.clear();
        return;
      }

      // CP: Regular chat text send with streaming
      if (currentText.isNotEmpty) {
        chatCubit.addUserMessageStreaming(currentText);
      }
    } else {
      widget.onSendPressed(currentText);
    }

    _textController.clear();
    if (!homePageCubit.state.isChatOpen && _inputFocusNode.hasFocus) {
      // CP: Use focusedChild?.unfocus() for more reliable behavior
      FocusScope.of(context).focusedChild?.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        // CP: Listen for editing mode changes to populate text field
        BlocListener<EntryCubit, EntryState>(
          listenWhen: (prev, current) =>
              prev.editingEntry != current.editingEntry || prev.isEditingMode != current.isEditingMode,
          listener: (context, state) {
            if (state.isEditingMode && state.editingEntry != null) {
              // CP: Populate text field with entry text when starting edit mode
              _textController.text = state.editingEntry!.text;
              // CP: Auto-focus and show keyboard
              if (!_inputFocusNode.hasFocus) {
                _inputFocusNode.requestFocus();
              }
            } else if (!state.isEditingMode) {
              // CP: Clear text field when exiting edit mode
              if (_textController.text.isNotEmpty && context.read<HomePageCubit>().state.isChatOpen == false) {
                _textController.clear();
              }
            }
          },
        ),
      ],
      child: BlocBuilder<EntryCubit, EntryState>(
        buildWhen: (prev, current) =>
            prev.isEditingMode != current.isEditingMode || prev.editingEntry != current.editingEntry,
        builder: (context, entryState) {
          return BlocBuilder<VoiceInputCubit, VoiceInputState>(
            builder: (context, voiceState) {
              return BlocBuilder<HomePageCubit, HomePageState>(
                buildWhen: (prev, current) =>
                    prev.isInputFocused != current.isInputFocused || prev.isChatOpen != current.isChatOpen,
                builder: (context, homeScreenState) {
                  final isInputFocused = homeScreenState.isInputFocused;
                  final isChatOpen = homeScreenState.isChatOpen;
                  final isEditingMode = entryState.isEditingMode;
                  final isTranscribing = voiceState.transcriptionStatus == TranscriptionStatus.transcribing;

                  // CP: Determine input behavior based on mode and voice state
                  String hintText;
                  String labelText;

                  if (isEditingMode) {
                    hintText = 'Edit your entry...';
                    labelText = 'Editing Entry';
                  } else if (isChatOpen) {
                    if (isTranscribing) {
                      hintText = 'Processing voice...';
                      labelText = 'Transcribing...';
                    } else {
                      hintText = 'Ask anything';
                      labelText = 'Chatting...';
                    }
                  } else {
                    hintText = 'What\'s on your mind?';
                    labelText = isInputFocused ? 'Enter log entry' : 'What happened?...';
                  }

                  return TextFieldTapRegion(
                    child: Material(
                      elevation: isChatOpen ? 0.0 : 8.0, // CP: Remove shadow in chat mode
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(isChatOpen ? 0.0 : 20.0),
                          topRight: Radius.circular(isChatOpen ? 0.0 : 20.0),
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          // CP: Change background color when editing
                          color: isEditingMode
                              ? Theme.of(context).colorScheme.primaryContainer.withAlpha(77) // 0.3 * 255
                              : Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(isChatOpen ? 0.0 : 20.0),
                            topRight: Radius.circular(isChatOpen ? 0.0 : 20.0),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: EdgeInsets.only(left: 16, right: 8, top: 8, bottom: 4.0),
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
                                        // CP: Different fill color when editing
                                        fillColor: isEditingMode
                                            ? Theme.of(context).colorScheme.primary.withAlpha(25)
                                            : Theme.of(
                                                context,
                                              ).colorScheme.surfaceContainerHighest.withAlpha((255 * 0.6).round()),
                                        labelText: (isInputFocused || isChatOpen || isEditingMode) ? labelText : null,
                                        hintText: hintText,
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        // CP: Show editing indicator with icon
                                        prefixIcon: isEditingMode
                                            ? Icon(
                                                Icons.edit_outlined,
                                                color: Theme.of(context).colorScheme.primary,
                                                size: 20,
                                              )
                                            : null,
                                      ),
                                      keyboardType: TextInputType.multiline,
                                      textInputAction: TextInputAction.newline,
                                      onSubmitted: (_) => _handleLocalSend(),
                                      minLines: 1,
                                      maxLines: 5,
                                      onTapOutside: (_) {
                                        if (_inputFocusNode.hasFocus && !isChatOpen && !isEditingMode) {
                                          FocusScope.of(context).unfocus();
                                        }
                                      },
                                      onTap: () {
                                        if ((isChatOpen || isEditingMode) && !_inputFocusNode.hasFocus) {
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
                                bottom: MediaQuery.of(context).viewInsets.bottom > 0
                                    ? 8.0
                                    : MediaQuery.of(context).padding.bottom + 8.0,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  // CP: Show cancel button when editing
                                  if (isEditingMode) ...[
                                    TextButton.icon(
                                      icon: Icon(Icons.close, size: 18),
                                      label: const Text('Cancel'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Theme.of(context).colorScheme.error.withAlpha(192),
                                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      onPressed: _handleEditingCancel,
                                    ),
                                    const SizedBox(width: 12.0),
                                    // CP: Task toggle button when editing
                                    BlocBuilder<EntryCubit, EntryState>(
                                      buildWhen: (prev, current) => prev.editingIsTask != current.editingIsTask,
                                      builder: (context, state) {
                                        final isTask = state.editingIsTask ?? false;
                                        return Container(
                                          decoration: BoxDecoration(
                                            color: isTask
                                                ? Theme.of(context).colorScheme.primaryContainer.withAlpha(128)
                                                : Theme.of(context).colorScheme.surfaceContainerHigh.withAlpha(128),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                              color: isTask
                                                  ? Theme.of(context).colorScheme.primary.withAlpha(128)
                                                  : Theme.of(context).colorScheme.outline.withAlpha(64),
                                              width: 1.5,
                                            ),
                                          ),
                                          child: TextButton.icon(
                                            icon: Icon(
                                              isTask ? Icons.check_circle : Icons.circle_outlined,
                                              size: 18,
                                            ),
                                            label: Text(
                                              isTask ? 'Task' : 'Note',
                                              style: const TextStyle(fontWeight: FontWeight.w600),
                                            ),
                                            style: TextButton.styleFrom(
                                              foregroundColor: isTask
                                                  ? Theme.of(context).colorScheme.primary
                                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                                              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              minimumSize: Size.zero,
                                            ),
                                            onPressed: () {
                                              HapticFeedback.lightImpact();
                                              context.read<EntryCubit>().toggleEditingTaskStatus();
                                            },
                                          ),
                                        );
                                      },
                                    ),
                                  ] else ...[
                                    TextButton.icon(
                                      key: chatToggleButton,
                                      icon: Icon(isChatOpen ? Icons.forum_rounded : Icons.forum_outlined),
                                      label: Text(isChatOpen ? 'Close Chat' : 'Chat'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: isChatOpen
                                            ? Theme.of(context).colorScheme.primary
                                            : Theme.of(context).colorScheme.onSurfaceVariant,
                                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      onPressed: () {
                                        context.read<HomePageCubit>().toggleChatOpen();
                                      },
                                    ),
                                  ],
                                  const Spacer(),
                                  // CP: Hide voice input only when editing (allow in chat mode)
                                  if (!isEditingMode)
                                    VoiceInput(
                                      textController: _textController,
                                      inputFocusNode: _inputFocusNode,
                                      isInputFocused: isInputFocused,
                                      showSnackBar:
                                          (
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
                                  BlocBuilder<VoiceInputCubit, VoiceInputState>(
                                    builder: (context, voiceState) {
                                      return BlocBuilder<ChatCubit, ChatState>(
                                        builder: (context, chatState) {
                                          final isLoading = chatState.isLoading;
                                          final messages = chatState.messages;
                                          final lastIsUser =
                                              messages.isNotEmpty && messages.last.sender == ChatSender.user;
                                          final isTranscribing =
                                              voiceState.transcriptionStatus == TranscriptionStatus.transcribing;
                                          final shouldDisableSend =
                                              (isChatOpen && (isLoading || lastIsUser || isTranscribing)) ||
                                              (isEditingMode && _textController.text.trim().isEmpty);

                                          // CP: Change icon and tooltip based on mode and voice state
                                          IconData sendIcon;
                                          String tooltip;
                                          Color? iconColor;

                                          if (isEditingMode) {
                                            sendIcon = Icons.check_rounded;
                                            tooltip = 'Save Changes';
                                            iconColor = Theme.of(context).colorScheme.primary;
                                          } else if (isChatOpen) {
                                            if (isTranscribing) {
                                              sendIcon = Icons.hourglass_bottom;
                                              tooltip = 'Processing voice...';
                                              iconColor = Colors.orange.shade700;
                                            } else {
                                              sendIcon = Icons.send_rounded;
                                              tooltip = 'Send Message';
                                              iconColor = Theme.of(context).colorScheme.primary;
                                            }
                                          } else {
                                            sendIcon = Icons.send_rounded;
                                            tooltip = 'Add Entry';
                                            iconColor = Theme.of(context).colorScheme.primary;
                                          }

                                          return IconButton(
                                            onPressed: shouldDisableSend ? null : _handleLocalSend,
                                            icon: isTranscribing
                                                ? SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2.5,
                                                      color: iconColor,
                                                    ),
                                                  )
                                                : Icon(sendIcon),
                                            color: iconColor,
                                            iconSize: 28,
                                            tooltip: tooltip,
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

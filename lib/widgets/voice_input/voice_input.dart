import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myapp/utils/logger.dart';
import 'package:permission_handler/permission_handler.dart';

import 'cubit/voice_input_cubit.dart';
import 'cubit/voice_input_state.dart';

// Define a type for the snackbar callback
typedef ShowSnackBarCallback =
    void Function(
      BuildContext context, {
      required Widget content,
      Duration duration,
      SnackBarAction? action,
      Color? backgroundColor,
    });

class VoiceInput extends StatelessWidget {
  final TextEditingController textController;
  final FocusNode inputFocusNode;
  final bool isInputFocused;
  final ShowSnackBarCallback showSnackBar;

  const VoiceInput({
    super.key,
    required this.textController,
    required this.inputFocusNode,
    required this.isInputFocused,
    required this.showSnackBar,
  });

  @override
  Widget build(BuildContext context) {
    return BlocListener<VoiceInputCubit, VoiceInputState>(
      listenWhen: (previous, current) {
        // Listen for status changes, errors
        bool permissionChanged =
            previous.micPermissionStatus != current.micPermissionStatus;
        bool errorChanged =
            previous.errorMessage != current.errorMessage &&
            current.errorMessage != null;
        bool transcriptionStatusChanged =
            previous.transcriptionStatus != current.transcriptionStatus;

        return permissionChanged || errorChanged || transcriptionStatusChanged;
      },
      listener: (context, state) {
        final messenger = ScaffoldMessenger.of(context);

        // Hide snackbars on status change (unless transcribing)
        if (state.transcriptionStatus != TranscriptionStatus.transcribing) {
          messenger.hideCurrentSnackBar();
        }

        // Permission Denied while trying to record
        if ((state.micPermissionStatus == PermissionStatus.denied ||
                state.micPermissionStatus ==
                    PermissionStatus.permanentlyDenied) &&
            state.isRecording) {
          // Ensure previous snackbars are hidden before showing a new one
          messenger.hideCurrentSnackBar();
          showSnackBar(
            context,
            content: const Text(
              'Microphone permission is required for voice input.',
            ),
          );
        }

        // Handle errors
        if (state.errorMessage != null) {
          messenger.hideCurrentSnackBar();
          showSnackBar(
            context,
            content: Text(state.errorMessage!),
            backgroundColor: Colors.red,
          );
          // Clear the error state in the cubit after showing it
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              context.read<VoiceInputCubit>().clearErrorState();
            }
          });
        }

        // Handle transcription status updates
        if (state.transcriptionStatus == TranscriptionStatus.transcribing) {
          messenger.hideCurrentSnackBar();
          showSnackBar(
            context,
            content: const Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 15),
                Text('Transcribing audio...'),
              ],
            ),
            duration: const Duration(seconds: 10),
          );
        }

        // Handle successful FOREGROUND transcription (Append text ONLY)
        if (state.transcriptionStatus == TranscriptionStatus.success &&
            state.transcribedText != null &&
            state.transcribedText!.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            final currentText = textController.text;
            final newText = state.transcribedText!;
            String combinedText;
            // Append logic
            if (currentText.isEmpty) {
              combinedText = newText;
            } else if (currentText.endsWith(' ') ||
                currentText.endsWith('\n')) {
              combinedText = currentText + newText;
            } else {
              combinedText = '$currentText $newText';
            }
            // Directly update the text controller
            textController.text = combinedText;
            // Move cursor to the end
            textController.selection = TextSelection.fromPosition(
              TextPosition(offset: textController.text.length),
            );
            // Clear the transcribed text from the cubit state after using it
            context.read<VoiceInputCubit>().clearTranscribedText();
          });
        }
      },
      child: BlocBuilder<VoiceInputCubit, VoiceInputState>(
        builder: (context, state) {
          AppLogger.debug(
            '[VoiceInput Widget Build] isRecording: ${state.isRecording}, status: ${state.transcriptionStatus}',
          ); // <-- Add log
          // Format recording duration for display
          String recordingTimeDisplay = '';
          bool approachingLimit = false;
          if (state.isRecording) {
            final duration = state.recordingDuration;
            final minutes = duration.inMinutes.toString().padLeft(2, '0');
            final seconds = (duration.inSeconds % 60).toString().padLeft(
              2,
              '0',
            );
            recordingTimeDisplay = '$minutes:$seconds';
            approachingLimit = duration.inSeconds > 270; // 4:30
          }

          // Show hourglass if transcribing (foreground only now)
          bool isTranscribing =
              state.transcriptionStatus == TranscriptionStatus.transcribing;

          return Row(
            mainAxisSize: MainAxisSize.min, // Take minimum horizontal space
            children: [
              // Show timer when recording
              if (state.isRecording)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 2.0,
                  ),
                  margin: const EdgeInsets.only(right: 8.0), // Add spacing
                  decoration: BoxDecoration(
                    color:
                        approachingLimit
                            ? Colors.red.withAlpha((255 * 0.2).round())
                            : Colors.grey.withAlpha((255 * 0.2).round()),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    recordingTimeDisplay,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: approachingLimit ? Colors.red : Colors.black87,
                    ),
                  ),
                ),
              // Microphone Button
              IconButton(
                icon: Icon(
                  state.isRecording
                      ? Icons.stop_circle_outlined
                      : (isTranscribing ? Icons.hourglass_bottom : Icons.mic),
                  color:
                      state.isRecording
                          ? Colors.red
                          : (isTranscribing
                              ? Colors.orange.shade700
                              : Theme.of(context).colorScheme.primary),
                ),
                tooltip:
                    state.isRecording
                        ? 'Stop Recording'
                        : (isTranscribing
                            ? 'Processing recording...'
                            : 'Start Voice Input'),
                iconSize: 30,
                // Disable button while transcribing
                onPressed:
                    isTranscribing
                        ? null
                        : () {
                          if (state.isRecording) {
                            _stopRecording(context);
                          } else {
                            _startRecording(context);
                          }
                        },
              ),
            ],
          );
        },
      ),
    );
  }

  void _startRecording(BuildContext context) {
    // Always attempt to start recording via the Cubit
    context.read<VoiceInputCubit>().startRecording();
  }

  void _stopRecording(BuildContext context) {
    context.read<VoiceInputCubit>().stopRecording();
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../cubit/voice_input_cubit.dart';
import '../cubit/voice_input_state.dart';

// Define a type for the snackbar callback
typedef ShowSnackBarCallback =
    void Function(
      BuildContext context, {
      required Widget content,
      Duration duration,
      SnackBarAction? action,
      Color? backgroundColor,
    });

// Define a type for the transcription completion callback
typedef TranscriptionCompleteCallback = void Function(String transcribedText);

class VoiceInputSection extends StatelessWidget {
  final TextEditingController textController;
  final FocusNode inputFocusNode;
  final bool isInputFocused;
  final ShowSnackBarCallback showSnackBar;
  final TranscriptionCompleteCallback
  onTranscriptionComplete; // Add the definition

  const VoiceInputSection({
    super.key,
    required this.textController,
    required this.inputFocusNode,
    required this.isInputFocused,
    required this.showSnackBar,
    required this.onTranscriptionComplete, // Add to constructor
  });

  @override
  Widget build(BuildContext context) {
    // Listener for handling state changes like errors, permissions, status
    return BlocListener<VoiceInputCubit, VoiceInputState>(
      listenWhen: (previous, current) {
        // Only trigger for changes in status or new errors
        bool permissionChanged =
            previous.micPermissionStatus != current.micPermissionStatus;
        bool errorChanged =
            previous.errorMessage != current.errorMessage &&
            current.errorMessage != null;
        bool transcriptionStatusChanged =
            previous.transcriptionStatus != current.transcriptionStatus;
        // Also listen for successful transcription to trigger auto-submit
        bool transcriptionSucceeded =
            previous.transcriptionStatus != TranscriptionStatus.success &&
            current.transcriptionStatus == TranscriptionStatus.success &&
            current.transcribedText != null &&
            current.transcribedText!.isNotEmpty;

        return permissionChanged ||
            errorChanged ||
            transcriptionStatusChanged ||
            transcriptionSucceeded;
      },
      listener: (context, state) {
        final messenger = ScaffoldMessenger.of(
          context,
        ); // Get messenger instance

        // --- Hide Snackbars on Status Change ---
        // Hide any existing snackbar if we are no longer transcribing or if successful
        if (state.transcriptionStatus != TranscriptionStatus.transcribing) {
          messenger.hideCurrentSnackBar();
        }
        // --- End Hide Snackbars ---

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

        // Handle errors (from recording, transcription, etc.)
        if (state.errorMessage != null) {
          // Ensure previous snackbars are hidden before showing a new one
          messenger.hideCurrentSnackBar();
          showSnackBar(
            context,
            content: Text(state.errorMessage!),
            backgroundColor: Colors.red,
          );
          // Clear the error in the cubit after showing it
          context.read<VoiceInputCubit>().clearTranscribedText();
        }

        // Handle transcription status updates
        if (state.transcriptionStatus == TranscriptionStatus.transcribing) {
          // Ensure previous snackbars are hidden before showing a new one
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
            duration: const Duration(seconds: 10), // Show longer
          );
        }

        // Handle successful transcription (Auto-submit)
        if (state.transcriptionStatus == TranscriptionStatus.success &&
            state.transcribedText != null &&
            state.transcribedText!.isNotEmpty) {
          // Use WidgetsBinding to ensure this runs after the build phase
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final currentText = textController.text;
            final newText = state.transcribedText!;
            String combinedText;
            if (currentText.isEmpty) {
              combinedText = newText;
            } else if (currentText.endsWith(' ')) {
              combinedText = currentText + newText;
            } else {
              combinedText = '$currentText $newText';
            }
            // Call the callback with the combined text
            onTranscriptionComplete(combinedText);
            // Clear the text from the cubit state after using it
            context.read<VoiceInputCubit>().clearTranscribedText();
          });
        }
      },
      // Builder for the actual UI (button, timer)
      child: BlocBuilder<VoiceInputCubit, VoiceInputState>(
        builder: (context, state) {
          // REMOVED: Handling setting transcribed text into the TextField here
          // It's now handled in the BlocListener for auto-submission

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
                            ? Colors.red.withOpacity(0.2)
                            : Colors.grey.withOpacity(0.2),
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
                  state.isRecording ? Icons.stop_circle_outlined : Icons.mic,
                  color:
                      state.isRecording
                          ? Colors.red
                          : Theme.of(context).colorScheme.primary,
                ),
                tooltip:
                    state.isRecording
                        ? 'Stop Recording (${approachingLimit ? "Auto-stops at 5:00" : ""})'
                        : 'Start Voice Input',
                iconSize: 30,
                onPressed: () {
                  context.read<VoiceInputCubit>().toggleRecording();
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

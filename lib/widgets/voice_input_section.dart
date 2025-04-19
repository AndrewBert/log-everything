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

class VoiceInputSection extends StatelessWidget {
  final TextEditingController textController;
  final FocusNode inputFocusNode;
  final bool isInputFocused;
  final ShowSnackBarCallback showSnackBar;

  const VoiceInputSection({
    super.key,
    required this.textController,
    required this.inputFocusNode,
    required this.isInputFocused,
    required this.showSnackBar,
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

        return permissionChanged || errorChanged || transcriptionStatusChanged;
      },
      listener: (context, state) {
        // Permission Denied while trying to record
        if ((state.micPermissionStatus == PermissionStatus.denied ||
                state.micPermissionStatus ==
                    PermissionStatus.permanentlyDenied) &&
            state.isRecording) {
          showSnackBar(
            context,
            content: const Text(
              'Microphone permission is required for voice input.',
            ),
          );
        }

        // Handle errors (from recording, transcription, etc.)
        if (state.errorMessage != null) {
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
        } else if (state.transcriptionStatus == TranscriptionStatus.success) {
          // Show success message (will replace the 'transcribing' one)
          showSnackBar(
            context,
            content: const Text('Transcription successful!'),
            duration: const Duration(seconds: 2),
          );
        }
      },
      // Builder for the actual UI (button, timer)
      child: BlocBuilder<VoiceInputCubit, VoiceInputState>(
        builder: (context, state) {
          // Handle setting transcribed text into the TextField
          if (state.transcriptionStatus == TranscriptionStatus.success &&
              state.transcribedText != null &&
              state.transcribedText!.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              textController.text = state.transcribedText!;
              textController.selection = TextSelection.fromPosition(
                TextPosition(offset: textController.text.length),
              );
              // Clear the text from the cubit state after using it
              context.read<VoiceInputCubit>().clearTranscribedText();
              // Optionally request focus back to the input field
              // inputFocusNode.requestFocus();
            });
          }

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

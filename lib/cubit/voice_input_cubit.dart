import 'dart:async'; // Added for Timer
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../speech_service.dart';
import '../utils/logger.dart';
import 'voice_input_state.dart';
// Import EntryCubit to add entry directly
import 'entry_cubit.dart';

class VoiceInputCubit extends Cubit<VoiceInputState> {
  final AudioRecorder _audioRecorder;
  final SpeechService _speechService;
  final EntryCubit _entryCubit; // Add EntryCubit dependency

  Timer? _recordingTimer;
  static const Duration _maxRecordingDuration = Duration(minutes: 5);
  static const Duration _minRecordingDuration = Duration(seconds: 1);

  VoiceInputCubit({
    required AudioRecorder audioRecorder,
    required SpeechService speechService,
    required EntryCubit entryCubit, // Inject EntryCubit
  }) : _audioRecorder = audioRecorder,
       _speechService = speechService,
       _entryCubit = entryCubit, // Store EntryCubit
       super(const VoiceInputState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    final status = await Permission.microphone.status;
    emit(state.copyWith(micPermissionStatus: status));
    _audioRecorder.onStateChanged().listen((recordState) {
      AppLogger.debug('AudioRecorder state changed: $recordState');
      // Optionally update state based on recorder state if needed
    });
  }

  Future<void> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    emit(state.copyWith(micPermissionStatus: status));
    if (status.isPermanentlyDenied) {
      AppLogger.warning('Microphone permission permanently denied.');
      // Optionally guide user to settings
    }
  }

  Future<void> toggleRecording() async {
    if (state.isRecording) {
      await stopRecording(); // Normal stop triggers foreground transcription
    } else {
      await startRecording();
    }
  }

  Future<void> startRecording() async {
    AppLogger.info("Attempting to start recording...");
    if (state.micPermissionStatus != PermissionStatus.granted) {
      await requestMicrophonePermission();
      if (state.micPermissionStatus != PermissionStatus.granted) {
        AppLogger.warning(
          "Microphone permission not granted. Cannot start recording.",
        );
        emit(
          state.copyWith(
            isRecording: false,
            errorMessage: 'Microphone permission required.',
          ),
        );
        return;
      }
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final path =
          '${directory.path}/recording-${DateTime.now().millisecondsSinceEpoch}.m4a';
      const config = RecordConfig(encoder: AudioEncoder.aacLc);

      await _audioRecorder.start(config, path: path);
      AppLogger.info("Recording started, path: $path");
      emit(
        state.copyWith(
          isRecording: true,
          recordingStartTime: DateTime.now(),
          recordingDuration: Duration.zero,
          clearErrorMessage: true,
          transcriptionStatus: TranscriptionStatus.idle, // Reset status
          clearTranscribedText: true, // Clear previous text
          clearAudioPath: true, // Clear previous path
        ),
      );
      _startRecordingTimer();
    } catch (e) {
      AppLogger.error("Error starting recording", error: e);
      emit(
        state.copyWith(
          errorMessage: 'Error starting recording: $e',
          isRecording: false,
        ),
      );
    }
  }

  // Stop recording and transcribe in FOREGROUND (updates text field via state)
  Future<void> stopRecording() async {
    AppLogger.info("Stopping recording (foreground transcription)");
    if (!state.isRecording) return;

    _cancelRecordingTimer();
    final recordingDuration = _calculateRecordingDuration();
    final bool isTooShort = recordingDuration < _minRecordingDuration;

    try {
      final path = await _audioRecorder.stop();
      AppLogger.info("Recording stopped, audio path: $path");

      emit(
        state.copyWith(
          isRecording: false,
          audioPath: path,
          clearRecordingTime: true,
          errorMessage:
              isTooShort ? 'Recording too short (less than 1 second)' : null,
          clearErrorMessage: !isTooShort, // Clear error if not too short
        ),
      );

      if (!isTooShort && path != null) {
        await transcribeAudio(); // Triggers foreground flow
      } else {
        // Handle too short or null path
        if (isTooShort) {
          AppLogger.info("Skipping transcription: recording too short.");
        } else {
          AppLogger.error("Failed to save recording, path is null.");
          emit(state.copyWith(errorMessage: 'Failed to save recording.'));
        }
        // Clean up state if transcription is skipped
        emit(
          state.copyWith(
            clearAudioPath: true,
            transcriptionStatus: TranscriptionStatus.idle,
          ),
        );
      }
    } catch (e) {
      AppLogger.error("Error stopping recording", error: e);
      emit(
        state.copyWith(
          errorMessage: 'Error stopping recording: $e',
          isRecording: false,
          clearRecordingTime: true,
          clearAudioPath: true,
          transcriptionStatus: TranscriptionStatus.idle,
        ),
      );
    }
  }

  // NEW: Stop recording, transcribe, combine with initial text, and add entry
  Future<void> stopRecordingAndCombine(String initialText) async {
    AppLogger.info(
      "Stopping recording to combine with initial text: '$initialText'",
    );
    if (!state.isRecording) return;

    _cancelRecordingTimer();
    final recordingDuration = _calculateRecordingDuration();
    final bool isTooShort = recordingDuration < _minRecordingDuration;
    String? audioPath;

    try {
      audioPath = await _audioRecorder.stop();
      AppLogger.info("Recording stopped for combine, audio path: $audioPath");

      // Update state immediately to reflect recording stopped
      // Set status to transcribing temporarily for UI feedback (optional)
      emit(
        state.copyWith(
          isRecording: false,
          clearRecordingTime: true,
          audioPath: audioPath, // Keep path temporarily
          clearErrorMessage: true,
          transcriptionStatus:
              (!isTooShort && audioPath != null)
                  ? TranscriptionStatus
                      .transcribing // Show transcribing indicator
                  : TranscriptionStatus.idle,
        ),
      );

      if (!isTooShort && audioPath != null) {
        // Perform transcription
        try {
          final transcription = await _speechService.transcribeAudio(
            audioPath,
            language: 'en',
          );

          String combinedText =
              initialText; // Start with the text from the field
          if (transcription != null && transcription.isNotEmpty) {
            AppLogger.info('Transcription successful: "$transcription"');
            // Combine with initial text, adding a space if needed
            if (combinedText.isNotEmpty &&
                !combinedText.endsWith(' ') &&
                !combinedText.endsWith('\n')) {
              combinedText += ' ';
            }
            combinedText += transcription;
          } else {
            AppLogger.warning(
              'Transcription failed or returned empty text. Using only initial text.',
            );
            // Optionally show an error or just proceed with initial text
          }

          if (combinedText.isNotEmpty) {
            AppLogger.info('Adding combined entry: "$combinedText"');
            _entryCubit.addEntry(combinedText);
            // Reset state after successful processing
            emit(
              state.copyWith(
                transcriptionStatus: TranscriptionStatus.idle,
                clearAudioPath: true,
              ),
            );
          } else {
            AppLogger.warning('Combined text is empty, not adding entry.');
            emit(
              state.copyWith(
                transcriptionStatus: TranscriptionStatus.idle,
                clearAudioPath: true,
              ),
            );
          }
        } catch (e) {
          AppLogger.error("Transcription error during combine", error: e);
          // Add entry with only the initial text if transcription failed?
          if (initialText.isNotEmpty) {
            AppLogger.warning(
              'Adding entry with only initial text due to transcription error.',
            );
            _entryCubit.addEntry(initialText);
          }
          emit(
            state.copyWith(
              transcriptionStatus: TranscriptionStatus.error,
              errorMessage: 'Transcription error: $e',
              clearAudioPath: true,
            ),
          );
        }
      } else {
        // Handle too short or null path for combine
        if (isTooShort) {
          AppLogger.info(
            "Skipping transcription for combine: recording too short.",
          );
          // Add entry with only the initial text if it exists
          if (initialText.isNotEmpty) {
            AppLogger.info(
              'Adding entry with only initial text (recording too short).',
            );
            _entryCubit.addEntry(initialText);
          }
        } else {
          AppLogger.error(
            "Failed to save recording for combine, path is null.",
          );
          if (initialText.isNotEmpty) {
            AppLogger.warning(
              'Adding entry with only initial text (failed to save recording).',
            );
            _entryCubit.addEntry(initialText);
          }
          // Optionally emit an error state
          emit(state.copyWith(errorMessage: 'Failed to save recording.'));
        }
        // Ensure state is cleaned up
        emit(
          state.copyWith(
            clearAudioPath: true,
            transcriptionStatus: TranscriptionStatus.idle,
          ),
        );
      }
    } catch (e) {
      AppLogger.error("Error stopping recording for combine", error: e);
      if (initialText.isNotEmpty) {
        AppLogger.warning(
          'Adding entry with only initial text due to stop error.',
        );
        _entryCubit.addEntry(initialText);
      }
      emit(
        state.copyWith(
          errorMessage: 'Error stopping recording: $e',
          isRecording: false,
          clearRecordingTime: true,
          clearAudioPath: true,
          transcriptionStatus: TranscriptionStatus.idle,
        ),
      );
    }
  }

  // Transcribe for FOREGROUND (updates text field)
  Future<void> transcribeAudio() async {
    AppLogger.info("Starting foreground transcription");
    if (state.audioPath == null || state.audioPath!.isEmpty) {
      AppLogger.error("Cannot transcribe: audio path is null or empty.");
      emit(
        state.copyWith(
          transcriptionStatus: TranscriptionStatus.error,
          errorMessage: 'No audio file found to transcribe.',
        ),
      );
      return;
    }

    // Ensure status is just 'transcribing' for foreground
    emit(state.copyWith(transcriptionStatus: TranscriptionStatus.transcribing));

    try {
      final transcription = await _speechService.transcribeAudio(
        state.audioPath!,
        language: 'en',
      );

      if (transcription != null && transcription.isNotEmpty) {
        AppLogger.info('Foreground transcription successful: "$transcription"');
        emit(
          state.copyWith(
            transcribedText: transcription,
            transcriptionStatus: TranscriptionStatus.success,
            clearAudioPath: true, // Clear path after successful transcription
          ),
        );
      } else {
        AppLogger.error(
          'Foreground transcription failed or returned empty text.',
        );
        emit(
          state.copyWith(
            transcriptionStatus: TranscriptionStatus.error,
            errorMessage: 'Transcription failed or returned empty text.',
            clearAudioPath: true,
          ),
        );
      }
    } catch (e) {
      AppLogger.error("Foreground transcription error", error: e);
      emit(
        state.copyWith(
          transcriptionStatus: TranscriptionStatus.error,
          errorMessage: 'Transcription error: $e',
          clearAudioPath: true,
        ),
      );
    }
  }

  // Helper to calculate duration
  Duration _calculateRecordingDuration() {
    if (state.recordingStartTime == null) return Duration.zero;
    return DateTime.now().difference(state.recordingStartTime!);
  }

  void _startRecordingTimer() {
    _cancelRecordingTimer(); // Ensure no duplicate timers
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final duration = _calculateRecordingDuration();
      emit(state.copyWith(recordingDuration: duration));

      if (duration >= _maxRecordingDuration) {
        AppLogger.info(
          "Max recording duration reached. Stopping automatically.",
        );
        stopRecording(); // Normal stop for foreground transcription
      }
    });
  }

  void _cancelRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
  }

  // Call this from UI listener after using the transcribed text
  void clearTranscribedText() {
    emit(state.copyWith(clearTranscribedText: true));
  }

  // Call this from UI listener after showing an error message
  void clearErrorState() {
    emit(state.copyWith(clearErrorMessage: true));
  }

  @override
  Future<void> close() {
    _cancelRecordingTimer();
    _audioRecorder.dispose();
    return super.close();
  }
}

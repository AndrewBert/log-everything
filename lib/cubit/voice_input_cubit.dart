import 'dart:async'; // Added for Timer
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:flutter/services.dart'; // Import for HapticFeedback

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
      AppLogger.warning(
        '[requestMicrophonePermission] Microphone permission permanently denied.',
      );
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
    AppLogger.info("[startRecording] Attempting to start recording...");
    HapticFeedback.mediumImpact(); // Trigger haptic feedback immediately
    // Add a significant delay to test timing theory
    await Future.delayed(const Duration(seconds: 2));

    PermissionStatus currentStatus = await Permission.microphone.status;
    if (currentStatus != state.micPermissionStatus) {
      emit(state.copyWith(micPermissionStatus: currentStatus));
    }

    if (currentStatus != PermissionStatus.granted) {
      await requestMicrophonePermission(); // This logs the result internally
      // Re-check status *immediately* after requesting
      currentStatus = await Permission.microphone.status;
      if (currentStatus != state.micPermissionStatus) {
        emit(state.copyWith(micPermissionStatus: currentStatus));
      }

      if (currentStatus != PermissionStatus.granted) {
        AppLogger.warning(
          "[startRecording] Microphone permission still not granted ($currentStatus). Cannot start recording.",
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

  Future<void> stopRecording() async {
    AppLogger.info("Stopping recording (foreground transcription)");
    if (!state.isRecording) return;
    HapticFeedback.lightImpact(); // Add haptic feedback on stop

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
        if (isTooShort) {
          AppLogger.info("Skipping transcription: recording too short.");
        } else {
          AppLogger.error("Failed to save recording, path is null.");
          emit(state.copyWith(errorMessage: 'Failed to save recording.'));
        }
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

  Future<void> stopRecordingAndCombine(String initialText) async {
    AppLogger.info(
      "Stopping recording to combine with initial text: '$initialText'",
    );
    if (!state.isRecording) return;
    HapticFeedback.lightImpact(); // Add haptic feedback on stop (for combine)

    _cancelRecordingTimer();
    final recordingDuration = _calculateRecordingDuration();
    final bool isTooShort = recordingDuration < _minRecordingDuration;
    String? audioPath;

    try {
      audioPath = await _audioRecorder.stop();
      AppLogger.info("Recording stopped for combine, audio path: $audioPath");

      emit(
        state.copyWith(
          isRecording: false,
          clearRecordingTime: true,
          audioPath: audioPath,
          clearErrorMessage: true,
          transcriptionStatus:
              (!isTooShort && audioPath != null)
                  ? TranscriptionStatus.transcribing
                  : TranscriptionStatus.idle,
        ),
      );

      if (!isTooShort && audioPath != null) {
        try {
          final transcription = await _speechService.transcribeAudio(
            audioPath,
            language: 'en',
          );

          String combinedText = initialText;
          if (transcription != null && transcription.isNotEmpty) {
            AppLogger.info('Transcription successful: "$transcription"');
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
          }

          if (combinedText.isNotEmpty) {
            AppLogger.info('Adding combined entry: "$combinedText"');
            _entryCubit.addEntry(combinedText);
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
        if (isTooShort) {
          AppLogger.info(
            "Skipping transcription for combine: recording too short.",
          );
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
          emit(state.copyWith(errorMessage: 'Failed to save recording.'));
        }
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

    emit(state.copyWith(transcriptionStatus: TranscriptionStatus.transcribing));

    try {
      final transcription = await _speechService.transcribeAudio(
        state.audioPath!,
        language: 'en',
      );

      if (transcription != null && transcription.isNotEmpty) {
        AppLogger.info('Foreground transcription successful: "$transcription"');
        HapticFeedback.lightImpact(); // Haptic feedback on successful transcription
        emit(
          state.copyWith(
            transcribedText: transcription,
            transcriptionStatus: TranscriptionStatus.success,
            clearAudioPath: true,
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

  Duration _calculateRecordingDuration() {
    if (state.recordingStartTime == null) return Duration.zero;
    return DateTime.now().difference(state.recordingStartTime!);
  }

  void _startRecordingTimer() {
    _cancelRecordingTimer();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final duration = _calculateRecordingDuration();
      emit(state.copyWith(recordingDuration: duration));

      if (duration >= _maxRecordingDuration) {
        AppLogger.info(
          "Max recording duration reached. Stopping automatically.",
        );
        stopRecording();
      }
    });
  }

  void _cancelRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
  }

  void clearTranscribedText() {
    emit(state.copyWith(clearTranscribedText: true));
  }

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

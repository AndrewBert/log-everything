import 'dart:async';
import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myapp/services/permission_service.dart';
import 'package:permission_handler/permission_handler.dart';
// Remove path_provider import if only used by service now
// import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart'; // Keep for RecordConfig, AudioEncoder, RecordState
import 'package:flutter/services.dart';

import '../../../speech_service.dart';
import '../../../utils/logger.dart';
import 'voice_input_state.dart';
import '../../../entry/cubit/entry_cubit.dart';
import '../../../entry/repository/entry_repository.dart';
import '../../../locator.dart';
import '../../../entry/entry.dart';
import '../../../services/audio_recorder_service.dart'; // Import the service
import '../../../chat/cubit/chat_cubit.dart';

class VoiceInputCubit extends Cubit<VoiceInputState> {
  // Change type to the service abstraction
  final AudioRecorderService _audioRecorderService;
  final SpeechService _speechService;
  final EntryRepository _entryRepository;
  final EntryCubit _entryCubit;
  final PermissionService _permissionService;

  Timer? _recordingTimer;
  StreamSubscription<RecordState>? _recordStateSubscription;
  static const Duration _maxRecordingDuration = Duration(minutes: 5);
  static const Duration _minRecordingDuration = Duration(seconds: 1);

  VoiceInputCubit({required EntryCubit entryCubit})
    // Fetch the service implementation from the locator
    : _audioRecorderService = getIt<AudioRecorderService>(),
      _speechService = getIt<SpeechService>(),
      _entryRepository = getIt<EntryRepository>(),
      _permissionService = getIt<PermissionService>(),
      _entryCubit = entryCubit,
      super(const VoiceInputState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    final status = await _permissionService.getMicrophoneStatus();
    emit(state.copyWith(micPermissionStatus: status));
    // CC: Cancel any existing subscription before creating a new one
    _recordStateSubscription?.cancel();
    // Listen to state changes from the service
    _recordStateSubscription = _audioRecorderService.onStateChanged().listen((recordState) {
      // CC: Currently not handling state changes, but keeping subscription for future use
    });
  }

  Future<void> requestMicrophonePermission() async {
    final status = await _permissionService.requestMicrophonePermission();
    emit(state.copyWith(micPermissionStatus: status));
    if (status.isPermanentlyDenied) {
      AppLogger.warn('[requestMicrophonePermission] Microphone permission permanently denied.');
    }
  }

  Future<void> toggleRecording() async {
    AppLogger.info("[toggleRecording] Called. Current state isRecording: ${state.isRecording}");
    if (state.isRecording) {
      AppLogger.info("[toggleRecording] Calling stopRecording...");
      await stopRecording();
    } else {
      AppLogger.info("[toggleRecording] Calling startRecording...");
      await startRecording();
    }
    AppLogger.info("[toggleRecording] Finished.");
  }

  Future<void> startRecording() async {
    AppLogger.info("[startRecording] Attempting to start recording...");
    HapticFeedback.mediumImpact();

    PermissionStatus currentStatus = await _permissionService.getMicrophoneStatus();
    if (currentStatus != state.micPermissionStatus) {
      emit(state.copyWith(micPermissionStatus: currentStatus));
    }

    if (currentStatus != PermissionStatus.granted) {
      await requestMicrophonePermission();
      currentStatus = await _permissionService.getMicrophoneStatus();
      if (currentStatus != state.micPermissionStatus) {
        emit(state.copyWith(micPermissionStatus: currentStatus));
      }

      if (currentStatus != PermissionStatus.granted) {
        AppLogger.warn(
          "[startRecording] Microphone permission still not granted ($currentStatus). Cannot start recording.",
        );
        emit(state.copyWith(isRecording: false, errorMessage: 'Microphone permission required.'));
        return;
      }
    }

    try {
      // Use service to generate path
      final path = await _audioRecorderService.generateRecordingPath();
      const config = RecordConfig(encoder: AudioEncoder.aacLc);

      // Use service to start recording
      await _audioRecorderService.start(config, path: path);
      AppLogger.info("Recording started, path: $path");
      emit(
        state.copyWith(
          isRecording: true,
          recordingStartTime: clock.now(),
          recordingDuration: Duration.zero,
          clearErrorMessage: true,
          transcriptionStatus: TranscriptionStatus.idle,
          clearTranscribedText: true,
          clearAudioPath: true,
        ),
      );
      _startRecordingTimer();
    } catch (e) {
      AppLogger.error("Error starting recording", error: e);
      emit(state.copyWith(errorMessage: 'Error starting recording: $e', isRecording: false));
    }
    AppLogger.info("[startRecording] Finished.");
  }

  Future<void> cancelRecording() async {
    AppLogger.info("[cancelRecording] Called.");
    if (!state.isRecording) return;
    HapticFeedback.lightImpact();

    _cancelRecordingTimer();

    try {
      // Use service to stop recording
      await _audioRecorderService.stop();
      AppLogger.info("Recording cancelled");

      emit(
        state.copyWith(
          isRecording: false,
          clearRecordingTime: true,
          clearAudioPath: true,
          clearErrorMessage: true,
          transcriptionStatus: TranscriptionStatus.idle,
        ),
      );
    } catch (e) {
      AppLogger.error("Error cancelling recording", error: e);
      emit(
        state.copyWith(
          errorMessage: 'Error cancelling recording: $e',
          isRecording: false,
          clearRecordingTime: true,
          clearAudioPath: true,
          transcriptionStatus: TranscriptionStatus.idle,
        ),
      );
    }
    AppLogger.info("[cancelRecording] Finished.");
  }

  Future<void> stopRecording() async {
    AppLogger.info("[stopRecording] Called.");
    // Check service if it's recording (optional, state.isRecording should suffice)
    // if (!await _audioRecorderService.isRecording()) return;
    if (!state.isRecording) return;
    HapticFeedback.lightImpact();

    _cancelRecordingTimer();
    final recordingDuration = _calculateRecordingDuration();
    final bool isTooShort = recordingDuration < _minRecordingDuration;

    try {
      // Use service to stop recording
      final path = await _audioRecorderService.stop();
      AppLogger.info("Recording stopped, audio path: $path");
      emit(
        state.copyWith(
          isRecording: false,
          audioPath: path,
          clearRecordingTime: true,
          errorMessage: isTooShort ? 'Recording too short (less than 1 second)' : null,
          clearErrorMessage: !isTooShort,
        ),
      );

      if (!isTooShort && path != null) {
        await transcribeAudio();
      } else {
        if (isTooShort) {
          AppLogger.info("Skipping transcription: recording too short.");
        } else {
          AppLogger.error("Failed to save recording, path is null.");
          emit(state.copyWith(errorMessage: 'Failed to save recording.'));
        }
        emit(state.copyWith(clearAudioPath: true, transcriptionStatus: TranscriptionStatus.idle));
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
    AppLogger.info("[stopRecording] Finished.");
  }

  Future<void> stopRecordingAndCombine(String initialText, DateTime processingTimestamp) async {
    AppLogger.info("Stopping recording to combine with initial text: '$initialText'");
    if (!state.isRecording) return;
    HapticFeedback.lightImpact();

    _cancelRecordingTimer();
    final recordingDuration = _calculateRecordingDuration();
    final bool isTooShort = recordingDuration < _minRecordingDuration;
    String? audioPath;

    try {
      // Use service to stop recording
      audioPath = await _audioRecorderService.stop();
      AppLogger.info("Recording stopped for combine, audio path: $audioPath");

      emit(state.copyWith(isRecording: false, clearRecordingTime: true, audioPath: audioPath, clearErrorMessage: true));

      List<Entry> finalEntries = [];
      String combinedText = initialText;

      if (!isTooShort && audioPath != null) {
        try {
          final transcription = await _speechService.transcribeAudio(audioPath, language: 'en');
          if (transcription != null && transcription.isNotEmpty) {
            AppLogger.info('Transcription successful: "$transcription"');
            if (combinedText.isNotEmpty && !combinedText.endsWith(' ') && !combinedText.endsWith('\n')) {
              combinedText += ' ';
            }
            combinedText += transcription;
          } else {
            AppLogger.warn('Transcription failed or returned empty text. Using only initial text.');
          }
        } catch (e) {
          AppLogger.error("Transcription error during combine", error: e);
          emit(state.copyWith(errorMessage: 'Transcription error: $e'));
        }
      } else {
        if (isTooShort) {
          AppLogger.info("Skipping transcription for combine: recording too short.");
        } else {
          AppLogger.error("Failed to save recording for combine, path is null.");
          emit(state.copyWith(errorMessage: 'Failed to save recording.'));
        }
      }

      if (combinedText.isNotEmpty) {
        AppLogger.info(
          'Calling repository to process combined entry: "$combinedText" (Timestamp: $processingTimestamp)',
        );
        try {
          final result = await _entryRepository.processCombinedEntry(combinedText, processingTimestamp);
          finalEntries = result.entries;
          final splitCount = result.splitCount;

          // CP: Handle split notification for voice input
          if (splitCount > 1) {
            AppLogger.info('[Voice Split Detection] Repository detected $splitCount split entries');
            _entryCubit.emit(_entryCubit.state.copyWith(splitNotification: 'Entry split into $splitCount items'));
          }

          _entryCubit.finalizeProcessing(finalEntries);
        } catch (e) {
          AppLogger.error("Error processing combined entry in repository", error: e);
          _entryCubit.finalizeProcessing([]);
          emit(state.copyWith(errorMessage: 'Failed to process entry.'));
        }
      } else {
        AppLogger.warn('Combined text is empty, finalizing state without adding entry.');
        final currentEntries = _entryRepository.currentEntries
            .where((e) => e.timestamp != processingTimestamp)
            .toList();
        _entryCubit.finalizeProcessing(currentEntries);
      }

      emit(state.copyWith(clearAudioPath: true));
    } catch (e) {
      // Handle error stopping recording
      AppLogger.error("Error stopping recording for combine", error: e);
      final currentEntries = _entryRepository.currentEntries.where((e) => e.timestamp != processingTimestamp).toList();
      _entryCubit.finalizeProcessing(currentEntries);
      emit(
        state.copyWith(
          errorMessage: 'Error stopping recording: $e',
          isRecording: false,
          clearRecordingTime: true,
          clearAudioPath: true,
        ),
      );
    }
  }

  Future<void> stopRecordingAndSendToChat(String initialText, ChatCubit chatCubit) async {
    AppLogger.info("Stopping recording to combine with initial text for chat: '$initialText'");
    if (!state.isRecording) return;
    HapticFeedback.lightImpact();

    _cancelRecordingTimer();
    final recordingDuration = _calculateRecordingDuration();
    final bool isTooShort = recordingDuration < _minRecordingDuration;
    String? audioPath;

    try {
      // Use service to stop recording
      audioPath = await _audioRecorderService.stop();
      AppLogger.info("Recording stopped for chat, audio path: $audioPath");

      emit(state.copyWith(isRecording: false, clearRecordingTime: true, audioPath: audioPath, clearErrorMessage: true));

      String combinedText = initialText;

      if (!isTooShort && audioPath != null) {
        // CP: Set transcribing state for visual feedback
        emit(state.copyWith(transcriptionStatus: TranscriptionStatus.transcribing));

        try {
          final transcription = await _speechService.transcribeAudio(audioPath, language: 'en');
          if (transcription != null && transcription.isNotEmpty) {
            AppLogger.info('Chat transcription successful: "$transcription"');
            if (combinedText.isNotEmpty && !combinedText.endsWith(' ') && !combinedText.endsWith('\n')) {
              combinedText += ' ';
            }
            combinedText += transcription;
          } else {
            AppLogger.warn('Chat transcription failed or returned empty text. Using only initial text.');
          }
        } catch (e) {
          AppLogger.error("Chat transcription error", error: e);
          emit(state.copyWith(errorMessage: 'Transcription error: $e', transcriptionStatus: TranscriptionStatus.error));
          // Still send the initial text even if transcription fails
        }
      } else {
        if (isTooShort) {
          AppLogger.info("Skipping transcription for chat: recording too short.");
        } else {
          AppLogger.error("Failed to save recording for chat, path is null.");
          emit(state.copyWith(errorMessage: 'Failed to save recording.'));
        }
      }

      // Send combined text to chat if not empty
      if (combinedText.isNotEmpty) {
        AppLogger.info('Sending combined text to chat: "$combinedText"');
        chatCubit.addUserMessage(combinedText);
        // CP: Set success state for brief visual feedback
        emit(state.copyWith(transcriptionStatus: TranscriptionStatus.success));
      } else {
        AppLogger.warn('Combined text is empty, not sending to chat.');
      }

      // CP: Clear transcription status after processing
      emit(state.copyWith(clearAudioPath: true, transcriptionStatus: TranscriptionStatus.idle));
    } catch (e) {
      AppLogger.error("Error stopping recording for chat", error: e);
      emit(
        state.copyWith(
          errorMessage: 'Error stopping recording: $e',
          isRecording: false,
          clearRecordingTime: true,
          clearAudioPath: true,
          transcriptionStatus: TranscriptionStatus.error,
        ),
      );
    }
  }

  Future<void> transcribeAudio() async {
    // ... (transcription logic remains the same, uses _speechService) ...
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
      final transcription = await _speechService.transcribeAudio(state.audioPath!, language: 'en');

      if (transcription != null && transcription.isNotEmpty) {
        AppLogger.info('Foreground transcription successful: "$transcription"');
        HapticFeedback.lightImpact();
        emit(
          state.copyWith(
            transcribedText: transcription,
            transcriptionStatus: TranscriptionStatus.success,
            clearAudioPath: true,
          ),
        );
      } else {
        AppLogger.error('Foreground transcription failed or returned empty text.');
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
    final now = clock.now();
    final startTime = state.recordingStartTime;
    if (startTime == null) return Duration.zero;
    final duration = now.difference(startTime);
    return duration;
  }

  void _startRecordingTimer() {
    _cancelRecordingTimer();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final duration = _calculateRecordingDuration();
      emit(state.copyWith(recordingDuration: duration));

      if (duration >= _maxRecordingDuration) {
        AppLogger.info("Max recording duration reached. Stopping automatically.");
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
    _recordStateSubscription?.cancel();
    _audioRecorderService.dispose();
    return super.close();
  }
}

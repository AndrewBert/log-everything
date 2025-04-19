import 'dart:async'; // Added for Timer
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../speech_service.dart';
import '../utils/logger.dart';
import 'voice_input_state.dart';

class VoiceInputCubit extends Cubit<VoiceInputState> {
  final AudioRecorder _audioRecorder;
  final SpeechService _speechService;

  // Timer-related fields
  Timer? _recordingTimer;
  static const Duration _maxRecordingDuration = Duration(minutes: 5);
  static const Duration _minRecordingDuration = Duration(seconds: 1);

  VoiceInputCubit({
    required AudioRecorder audioRecorder,
    required SpeechService speechService,
  }) : _audioRecorder = audioRecorder,
       _speechService = speechService,
       super(const VoiceInputState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    // First check permission using AudioRecorder as it's more accurate
    final recorderHasPermission = await _audioRecorder.hasPermission();

    // If AudioRecorder says we have permission, use that instead of Permission plugin
    if (recorderHasPermission) {
      AppLogger.info(
        "Microphone permission granted according to AudioRecorder",
      );
      emit(state.copyWith(micPermissionStatus: PermissionStatus.granted));
    } else {
      // Fallback to checking with the permission plugin
      final permissionStatus = await Permission.microphone.status;
      AppLogger.info("Initial microphone permission status: $permissionStatus");
      emit(state.copyWith(micPermissionStatus: permissionStatus));
    }
  }

  // Request microphone permission
  Future<void> requestMicrophonePermission() async {
    AppLogger.info("Requesting microphone permission");
    final status = await Permission.microphone.request();
    AppLogger.info("Microphone permission request result: $status");
    emit(state.copyWith(micPermissionStatus: status));
  }

  // Toggle recording state
  Future<void> toggleRecording() async {
    if (state.isRecording) {
      await stopRecording();
    } else {
      await startRecording();
    }
  }

  // Start recording audio
  Future<void> startRecording() async {
    AppLogger.info("Starting recording process");
    final hasPermission = await _audioRecorder.hasPermission();
    AppLogger.info("AudioRecorder hasPermission: $hasPermission");

    if (!hasPermission) {
      await requestMicrophonePermission();
      // Check again after requesting
      if (!await _audioRecorder.hasPermission()) {
        AppLogger.error("Microphone permission still denied after request");
        emit(
          state.copyWith(
            errorMessage: 'Cannot record without microphone permission.',
          ),
        );
        return;
      }
    } else if (state.micPermissionStatus != PermissionStatus.granted) {
      // Update the permission status if AudioRecorder says we have permission but state doesn't show it
      AppLogger.info(
        "Updating permission status to granted based on AudioRecorder",
      );
      emit(state.copyWith(micPermissionStatus: PermissionStatus.granted));
    }

    try {
      final Directory tempDir = await getTemporaryDirectory();
      final audioPath = '${tempDir.path}/temp_audio.m4a';

      // Ensure directory exists (mainly for robustness)
      final file = File(audioPath);
      if (await file.exists()) {
        await file.delete(); // Delete previous recording if exists
      }

      // Start recording to file
      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: audioPath,
      );

      // Short delay to ensure the file is created before checking existence
      await Future.delayed(const Duration(milliseconds: 100));

      // Check if recording actually started
      bool isRecording = await _audioRecorder.isRecording();
      AppLogger.info("Recording started: $isRecording");
      if (isRecording) {
        final now = DateTime.now();
        emit(
          state.copyWith(
            isRecording: true,
            audioPath: audioPath,
            errorMessage: null,
            // Update permission status to granted since recording started successfully
            micPermissionStatus: PermissionStatus.granted,
            recordingStartTime: now,
            recordingDuration: Duration.zero,
          ),
        );

        // Start the timer to track recording duration
        _startRecordingTimer();
      } else {
        AppLogger.error("Failed to start recording");
        emit(state.copyWith(errorMessage: 'Failed to start recording.'));
      }
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

  // Stop recording audio
  Future<void> stopRecording() async {
    AppLogger.info("Stopping recording");
    if (!state.isRecording) return;

    _cancelRecordingTimer();

    // Check recording duration
    final now = DateTime.now();
    final recordingDuration =
        state.recordingStartTime != null
            ? now.difference(state.recordingStartTime!)
            : Duration.zero;
    final bool isTooShort =
        recordingDuration.inMilliseconds < 1000; // Less than 1 second

    try {
      final path = await _audioRecorder.stop();
      AppLogger.info("Recording stopped, audio path: $path");

      emit(
        state.copyWith(
          isRecording: false,
          audioPath: path,
          recordingStartTime: null,
          recordingDuration: Duration.zero,
          // Set a message for recordings that are too short
          errorMessage:
              isTooShort ? 'Recording too short (less than 1 second)' : null,
        ),
      );

      // Only transcribe if recording is long enough and path exists
      if (!isTooShort && path != null) {
        await transcribeAudio();
      } else if (isTooShort) {
        AppLogger.info(
          "Skipping transcription for recording less than 1 second",
        );
      } else if (path == null) {
        AppLogger.error("Failed to save recording");
        emit(state.copyWith(errorMessage: 'Failed to save recording.'));
      }
    } catch (e) {
      AppLogger.error("Error stopping recording", error: e);
      emit(
        state.copyWith(
          errorMessage: 'Error stopping recording: $e',
          isRecording: false,
          recordingStartTime: null,
          recordingDuration: Duration.zero,
        ),
      );
    }
  }

  // Start timer to track recording duration
  void _startRecordingTimer() {
    _cancelRecordingTimer(); // Cancel any existing timer

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!state.isRecording || state.recordingStartTime == null) {
        _cancelRecordingTimer();
        return;
      }

      final now = DateTime.now();
      final duration = now.difference(state.recordingStartTime!);

      // Update the recording duration
      emit(state.copyWith(recordingDuration: duration));

      // Track if minimum duration has passed
      if (duration >= _minRecordingDuration) {}

      // Auto-stop recording if maximum duration is reached
      if (duration >= _maxRecordingDuration) {
        AppLogger.info(
          "Maximum recording duration reached (5 minutes). Auto-stopping.",
        );
        timer.cancel();
        stopRecording();
      }
    });
  }

  // Cancel the recording timer
  void _cancelRecordingTimer() {
    if (_recordingTimer != null && _recordingTimer!.isActive) {
      _recordingTimer!.cancel();
      _recordingTimer = null;
    }
  }

  // Transcribe recorded audio
  Future<void> transcribeAudio() async {
    AppLogger.info("Starting transcription");
    if (state.audioPath == null || state.audioPath!.isEmpty) {
      AppLogger.error("No audio file found to transcribe");
      emit(state.copyWith(errorMessage: 'No audio file found to transcribe.'));
      return;
    }

    emit(state.copyWith(transcriptionStatus: TranscriptionStatus.transcribing));

    try {
      final transcription = await _speechService.transcribeAudio(
        state.audioPath!,
      );

      if (transcription != null && transcription.isNotEmpty) {
        final previewText =
            transcription.length > 30
                ? "${transcription.substring(0, 30)}..."
                : transcription;
        AppLogger.info("Transcription successful: \"$previewText\"");
        emit(
          state.copyWith(
            transcribedText: transcription,
            transcriptionStatus: TranscriptionStatus.success,
          ),
        );
      } else {
        AppLogger.error("Transcription failed or returned empty text");
        emit(
          state.copyWith(
            transcriptionStatus: TranscriptionStatus.error,
            errorMessage: 'Transcription failed or returned empty text.',
          ),
        );
      }
    } catch (e) {
      AppLogger.error("Transcription error", error: e);
      emit(
        state.copyWith(
          transcriptionStatus: TranscriptionStatus.error,
          errorMessage: 'Transcription error: $e',
        ),
      );
    }
  }

  // Clear the transcribed text and errors
  void clearTranscribedText() {
    AppLogger.info("Clearing transcribed text");
    emit(
      state.copyWith(
        transcribedText: null,
        errorMessage: null,
        transcriptionStatus: TranscriptionStatus.idle,
      ),
    );
  }

  @override
  Future<void> close() async {
    _cancelRecordingTimer();
    await _audioRecorder.dispose();
    super.close();
  }
}

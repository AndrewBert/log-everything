import 'package:equatable/equatable.dart';
import 'package:permission_handler/permission_handler.dart';

enum TranscriptionStatus {
  idle,
  transcribing, // Foreground transcription (updates text field)
  success, // Foreground transcription completed
  error,
}

class VoiceInputState extends Equatable {
  final bool isRecording;
  final String? audioPath;
  final String? transcribedText; // Only used for foreground transcription
  final String? errorMessage;
  final PermissionStatus micPermissionStatus;
  final TranscriptionStatus transcriptionStatus;
  final DateTime? recordingStartTime;
  final Duration recordingDuration;

  const VoiceInputState({
    this.isRecording = false,
    this.audioPath,
    this.transcribedText,
    this.errorMessage,
    this.micPermissionStatus = PermissionStatus.denied,
    this.transcriptionStatus = TranscriptionStatus.idle,
    this.recordingStartTime,
    this.recordingDuration = Duration.zero,
  });

  VoiceInputState copyWith({
    bool? isRecording,
    String? audioPath,
    String? transcribedText,
    String? errorMessage,
    PermissionStatus? micPermissionStatus,
    TranscriptionStatus? transcriptionStatus,
    DateTime? recordingStartTime,
    Duration? recordingDuration,
    bool clearAudioPath = false,
    bool clearTranscribedText = false,
    bool clearErrorMessage = false,
    bool clearRecordingTime = false,
  }) {
    return VoiceInputState(
      isRecording: isRecording ?? this.isRecording,
      audioPath: clearAudioPath ? null : audioPath ?? this.audioPath,
      transcribedText:
          clearTranscribedText ? null : transcribedText ?? this.transcribedText,
      errorMessage:
          clearErrorMessage ? null : errorMessage ?? this.errorMessage,
      micPermissionStatus: micPermissionStatus ?? this.micPermissionStatus,
      transcriptionStatus: transcriptionStatus ?? this.transcriptionStatus,
      recordingStartTime:
          clearRecordingTime
              ? null
              : recordingStartTime ?? this.recordingStartTime,
      recordingDuration:
          clearRecordingTime
              ? Duration.zero
              : recordingDuration ?? this.recordingDuration,
    );
  }

  @override
  List<Object?> get props => [
    isRecording,
    audioPath,
    transcribedText,
    errorMessage,
    micPermissionStatus,
    transcriptionStatus,
    recordingStartTime,
    recordingDuration,
  ];
}

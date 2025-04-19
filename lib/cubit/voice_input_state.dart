import 'package:permission_handler/permission_handler.dart';

enum TranscriptionStatus { idle, transcribing, success, error }

class VoiceInputState {
  final bool isRecording;
  final String? audioPath;
  final PermissionStatus micPermissionStatus;
  final TranscriptionStatus transcriptionStatus;
  final String? errorMessage;
  final String? transcribedText;
  final DateTime? recordingStartTime;
  final Duration recordingDuration;

  const VoiceInputState({
    this.isRecording = false,
    this.audioPath,
    this.micPermissionStatus = PermissionStatus.denied,
    this.transcriptionStatus = TranscriptionStatus.idle,
    this.errorMessage,
    this.transcribedText,
    this.recordingStartTime,
    this.recordingDuration = Duration.zero,
  });

  VoiceInputState copyWith({
    bool? isRecording,
    String? audioPath,
    PermissionStatus? micPermissionStatus,
    TranscriptionStatus? transcriptionStatus,
    String? errorMessage,
    String? transcribedText,
    DateTime? recordingStartTime,
    Duration? recordingDuration,
  }) {
    return VoiceInputState(
      isRecording: isRecording ?? this.isRecording,
      audioPath: audioPath ?? this.audioPath,
      micPermissionStatus: micPermissionStatus ?? this.micPermissionStatus,
      transcriptionStatus: transcriptionStatus ?? this.transcriptionStatus,
      errorMessage: errorMessage ?? this.errorMessage,
      transcribedText: transcribedText ?? this.transcribedText,
      recordingStartTime: recordingStartTime ?? this.recordingStartTime,
      recordingDuration: recordingDuration ?? this.recordingDuration,
    );
  }
}

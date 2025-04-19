import 'package:permission_handler/permission_handler.dart';

enum TranscriptionStatus { idle, transcribing, success, error }

class VoiceInputState {
  final bool isRecording;
  final String? audioPath;
  final PermissionStatus micPermissionStatus;
  final TranscriptionStatus transcriptionStatus;
  final String? errorMessage;
  final String? transcribedText;

  const VoiceInputState({
    this.isRecording = false,
    this.audioPath,
    this.micPermissionStatus = PermissionStatus.denied,
    this.transcriptionStatus = TranscriptionStatus.idle,
    this.errorMessage,
    this.transcribedText,
  });

  VoiceInputState copyWith({
    bool? isRecording,
    String? audioPath,
    PermissionStatus? micPermissionStatus,
    TranscriptionStatus? transcriptionStatus,
    String? errorMessage,
    String? transcribedText,
  }) {
    return VoiceInputState(
      isRecording: isRecording ?? this.isRecording,
      audioPath: audioPath ?? this.audioPath,
      micPermissionStatus: micPermissionStatus ?? this.micPermissionStatus,
      transcriptionStatus: transcriptionStatus ?? this.transcriptionStatus,
      errorMessage: errorMessage ?? this.errorMessage,
      transcribedText: transcribedText ?? this.transcribedText,
    );
  }
}

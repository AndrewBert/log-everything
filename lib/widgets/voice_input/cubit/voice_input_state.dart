import 'package:equatable/equatable.dart'; // <-- Import Equatable
import 'package:permission_handler/permission_handler.dart';

enum TranscriptionStatus { idle, transcribing, success, error }

// Extend Equatable
class VoiceInputState extends Equatable {
  final bool isRecording;
  final DateTime? recordingStartTime;
  final Duration recordingDuration;
  final String? audioPath;
  final String? transcribedText;
  final String? errorMessage;
  final PermissionStatus micPermissionStatus;
  final TranscriptionStatus transcriptionStatus;

  const VoiceInputState({
    this.isRecording = false,
    this.recordingStartTime,
    this.recordingDuration = Duration.zero,
    this.audioPath,
    this.transcribedText,
    this.errorMessage,
    this.micPermissionStatus = PermissionStatus.denied,
    this.transcriptionStatus = TranscriptionStatus.idle,
  });

  // Implement props getter
  @override
  List<Object?> get props => [
    isRecording,
    recordingStartTime,
    recordingDuration,
    audioPath,
    transcribedText,
    errorMessage,
    micPermissionStatus,
    transcriptionStatus,
  ];

  VoiceInputState copyWith({
    bool? isRecording,
    DateTime? recordingStartTime,
    Duration? recordingDuration,
    String? audioPath,
    String? transcribedText,
    String? errorMessage,
    PermissionStatus? micPermissionStatus,
    TranscriptionStatus? transcriptionStatus,
    bool clearRecordingTime = false,
    bool clearAudioPath = false,
    bool clearTranscribedText = false,
    bool clearErrorMessage = false,
  }) {
    return VoiceInputState(
      isRecording: isRecording ?? this.isRecording,
      recordingStartTime: clearRecordingTime ? null : recordingStartTime ?? this.recordingStartTime,
      recordingDuration: clearRecordingTime ? Duration.zero : recordingDuration ?? this.recordingDuration,
      audioPath: clearAudioPath ? null : audioPath ?? this.audioPath,
      transcribedText: clearTranscribedText ? null : transcribedText ?? this.transcribedText,
      errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
      micPermissionStatus: micPermissionStatus ?? this.micPermissionStatus,
      transcriptionStatus: transcriptionStatus ?? this.transcriptionStatus,
    );
  }
}

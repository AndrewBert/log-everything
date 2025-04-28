import 'dart:async';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart'; // For date formatting in filename

/// Abstract interface for audio recording operations.
abstract class AudioRecorderService {
  /// Starts recording audio to the specified path.
  Future<void> start(RecordConfig config, {required String path});

  /// Stops the current recording.
  /// Returns the path to the recorded file, or null if not recording or error.
  Future<String?> stop();

  /// Checks if recording is currently in progress.
  Future<bool> isRecording();

  /// Provides a stream of recording state changes.
  Stream<RecordState> onStateChanged();

  /// Disposes of the recorder resources.
  void dispose();

  /// Generates a unique file path for a new recording.
  Future<String> generateRecordingPath();
}

/// Implementation of [AudioRecorderService] using the 'record' package.
class AudioRecorderServiceImpl implements AudioRecorderService {
  final AudioRecorder _recorder;

  AudioRecorderServiceImpl() : _recorder = AudioRecorder();

  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    await _recorder.start(config, path: path);
  }

  @override
  Future<String?> stop() async {
    return await _recorder.stop();
  }

  @override
  Future<bool> isRecording() async {
    return await _recorder.isRecording();
  }

  @override
  Stream<RecordState> onStateChanged() {
    return _recorder.onStateChanged();
  }

  @override
  void dispose() {
    _recorder.dispose();
  }

  @override
  Future<String> generateRecordingPath() async {
    DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    // Using m4a as it's common for voice recordings on mobile
    final path = '\${directory.path}/recording_\$timestamp.m4a';
    return path;
  }
}

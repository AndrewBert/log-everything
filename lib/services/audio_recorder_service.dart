import 'dart:async';
import 'dart:io'; // Import dart:io for Directory
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart'; // For date formatting in filename
import 'package:path/path.dart' as p; // Import path package

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
  StreamController<RecordState>? _stateStreamController;
  StreamSubscription<RecordState>? _recorderStateSubscription;

  AudioRecorderServiceImpl() : _recorder = AudioRecorder() {
    _initializeStateStream();
  }

  void _initializeStateStream() {
    // CC: Create a broadcast stream controller to allow multiple listeners
    _stateStreamController = StreamController<RecordState>.broadcast();
    
    // CC: Forward events from the recorder to our broadcast stream
    _recorderStateSubscription = _recorder.onStateChanged().listen(
      (state) => _stateStreamController?.add(state),
      onError: (error) => _stateStreamController?.addError(error),
    );
  }

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
    // CC: Return the broadcast stream instead of the single-subscription stream
    return _stateStreamController?.stream ?? const Stream.empty();
  }

  @override
  void dispose() {
    _recorderStateSubscription?.cancel();
    _stateStreamController?.close();
    _recorder.dispose();
  }

  @override
  Future<String> generateRecordingPath() async {
    // Get the application documents directory.
    final Directory directory = await getApplicationDocumentsDirectory();
    // Format the current timestamp.
    final String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    // Construct the path correctly using the path package for cross-platform compatibility
    // and interpolating the actual directory path and timestamp string.
    // Using m4a as it's common for voice recordings on mobile
    final String filePath = p.join(directory.path, 'recording_$timestamp.m4a');
    // Ensure the directory exists (optional but good practice)
    // await Directory(p.dirname(filePath)).create(recursive: true);
    return filePath;
  }
}

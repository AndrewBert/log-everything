import 'package:mockito/annotations.dart';
import 'package:myapp/services/audio_recorder_service.dart';
import 'package:myapp/speech_service.dart';
import 'package:record/record.dart';
import 'package:myapp/services/permission_service.dart';
import 'package:myapp/services/entry_persistence_service.dart'; // Import persistence service
import 'package:myapp/services/ai_service.dart'; // Import AI service

// Generate mocks for the services needed
@GenerateMocks([
  SpeechService,
  AudioRecorder, // Keep if used directly
  PermissionService,
  EntryPersistenceService, // Add persistence service
  AiService, // Add AI service
  AudioRecorderService, // Add audio recorder service
])
void main() {}

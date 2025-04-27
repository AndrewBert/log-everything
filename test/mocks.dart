import 'package:mockito/annotations.dart';
import 'package:myapp/entry/repository/entry_repository.dart';
import 'package:myapp/speech_service.dart';
import 'package:record/record.dart';
import 'package:myapp/services/permission_service.dart';

// Generate mocks for the Cubits and Repository
@GenerateMocks([
  EntryRepository,
  SpeechService,
  AudioRecorder,
  PermissionService, // Add PermissionService
])
void main() {}

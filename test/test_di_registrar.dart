import 'package:myapp/entry/repository/entry_repository.dart'; // Import REAL repository
import 'package:myapp/services/ai_categorization_service.dart'; // Import AI service
import 'package:myapp/services/audio_recorder_service.dart';
import 'package:myapp/services/entry_persistence_service.dart'; // Import Persistence service
import 'package:myapp/services/permission_service.dart'; // Import Permission service
import 'package:myapp/speech_service.dart'; // Import Speech service base/interface

import 'package:myapp/locator.dart'; // Import your locator instance

import 'mocks.mocks.dart'; // Import generated mocks

/// Sets up dependencies in the GetIt locator for testing.
/// Registers REAL EntryRepository with MOCKED persistence and AI services.
Future<void> setupTestDependencies({
  bool allowReassignment = true,
  // Mocks for services needed by REAL repository and other components
  required MockEntryPersistenceService persistenceService,
  required MockAiCategorizationService aiService,
  required MockSpeechService speechService,
  // Use MockAudioRecorderService if that's the abstraction used,
  // or MockAudioRecorder if Record is used directly. Adjust as needed.
  required MockAudioRecorderService audioRecorder,
  required MockPermissionService permissionService,
  // Add other mocks as needed
}) async {
  // Reset GetIt before registering mocks for a clean slate
  await locator.reset();
  locator.allowReassignment = allowReassignment;

  // --- Register Mocks for Services ---
  locator.registerSingleton<EntryPersistenceService>(persistenceService);
  locator.registerSingleton<AiCategorizationService>(aiService);
  locator.registerSingleton<SpeechService>(speechService);
  locator.registerSingleton<AudioRecorderService>(audioRecorder);
  locator.registerSingleton<PermissionService>(permissionService);
  // Register other mocks if needed

  // --- Register REAL EntryRepository ---
  // It depends on the mocked services registered above.
  locator.registerSingleton<EntryRepository>(
    EntryRepository(
      persistenceService: locator<EntryPersistenceService>(),
      aiService: locator<AiCategorizationService>(),
    ),
  );

  // DO NOT Register REAL Cubits here. They will be created in BlocProviders.
}

// Optional: Keep reset function if used elsewhere
Future<void> resetTestDependencies() async {
  await locator.reset();
}

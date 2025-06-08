import 'package:myapp/entry/repository/entry_repository.dart'; // Import REAL repository
import 'package:myapp/locator.dart';
import 'package:myapp/services/ai_service.dart'; // Import AI service
import 'package:myapp/services/audio_recorder_service.dart';
import 'package:myapp/services/entry_persistence_service.dart'; // Import Persistence service
import 'package:myapp/services/permission_service.dart'; // Import Permission service
import 'package:myapp/services/vector_store_service.dart'; // CP: Import VectorStoreService
import 'package:myapp/speech_service.dart'; // Import Speech service base/interface
import 'package:shared_preferences/shared_preferences.dart'; // CP: Import SharedPreferences
import 'package:http/http.dart' as http; // CP: Import http

import 'mocks.mocks.dart'; // Import generated mocks

/// Sets up dependencies in the GetIt getIt for testing.
/// Registers REAL EntryRepository with MOCKED persistence and AI services.
Future<void> setupTestDependencies({
  bool allowReassignment = true,
  // Mocks for services needed by REAL repository and other components
  required MockEntryPersistenceService persistenceService,
  required MockAiService aiService,
  required MockSpeechService speechService,
  // Use MockAudioRecorderService if that's the abstraction used,
  // or MockAudioRecorder if Record is used directly. Adjust as needed.
  required MockAudioRecorderService audioRecorder,
  required MockPermissionService permissionService,
  required MockVectorStoreService vectorStoreService, // CP: Add vectorStoreService mock
  required MockSharedPreferences sharedPreferences, // CP: Add SharedPreferences mock
  required http.Client httpClient, // CP: Add http.Client mock
  // Add other mocks as needed
}) async {
  // Reset GetIt before registering mocks for a clean slate
  await getIt.reset();
  getIt.allowReassignment = allowReassignment;

  // --- Register Mocks for Services ---
  getIt.registerSingleton<EntryPersistenceService>(persistenceService);
  getIt.registerSingleton<AiService>(aiService);
  getIt.registerSingleton<SpeechService>(speechService);
  getIt.registerSingleton<AudioRecorderService>(audioRecorder);
  getIt.registerSingleton<PermissionService>(permissionService);
  getIt.registerSingleton<VectorStoreService>(vectorStoreService); // CP: Register VectorStoreService mock
  getIt.registerSingleton<SharedPreferences>(sharedPreferences); // CP: Register SharedPreferences mock
  getIt.registerSingleton<http.Client>(httpClient); // CP: Register http.Client mock

  // --- Register REAL EntryRepository ---
  // It depends on the mocked services registered above.
  getIt.registerSingleton<EntryRepository>(
    EntryRepository(
      persistenceService: getIt<EntryPersistenceService>(),
      aiService: getIt<AiService>(),
      vectorStoreService: getIt<VectorStoreService>(), // CP: Pass VectorStoreService mock
    ),
  );

  // DO NOT Register REAL Cubits here. They will be created in BlocProviders.
}

// Optional: Keep reset function if used elsewhere
Future<void> resetTestDependencies() async {
  await getIt.reset();
}

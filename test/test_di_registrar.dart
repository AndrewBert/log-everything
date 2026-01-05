import 'package:myapp/entry/repository/entry_repository.dart'; // Import REAL repository
import 'package:myapp/locator.dart';
import 'package:myapp/services/ai_service.dart'; // Import AI service
import 'package:myapp/services/audio_recorder_service.dart';
import 'package:myapp/services/entry_persistence_service.dart'; // Import Persistence service
import 'package:myapp/services/permission_service.dart'; // Import Permission service
import 'package:myapp/services/vector_store_service.dart'; // CP: Import VectorStoreService
import 'package:myapp/services/image_storage_service.dart'; // Import ImageStorageService
import 'package:myapp/services/timer_factory.dart'; // CP: Import TimerFactory
import 'package:myapp/services/firestore_sync_service.dart'; // CP: Import FirestoreSyncService
import 'package:myapp/intent_detection/services/intent_detection_service.dart'; // CP: Import IntentDetectionService
import 'package:myapp/speech_service.dart'; // Import Speech service base/interface
import 'package:shared_preferences/shared_preferences.dart'; // CP: Import SharedPreferences
import 'package:http/http.dart' as http; // CP: Import http
import 'package:myapp/snackbar/cubit/snackbar_cubit.dart';
import 'package:myapp/snackbar/services/snackbar_service.dart';

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
  required MockImageStorageService imageStorageService, // Add imageStorageService mock
  required MockSharedPreferences sharedPreferences, // CP: Add SharedPreferences mock
  required http.Client httpClient, // CP: Add http.Client mock
  MockFirestoreSyncService? firestoreSyncService, // CP: Add FirestoreSyncService mock (optional)
  MockIntentDetectionService? intentDetectionService, // CP: Add IntentDetectionService mock (optional)
  // Add other mocks as needed
}) async {
  // Reset GetIt before registering mocks for a clean slate
  await getIt.reset();
  getIt.allowReassignment = allowReassignment;

  // CP: Create default mocks if not provided
  final effectiveFirestoreSyncService = firestoreSyncService ?? MockFirestoreSyncService();
  final effectiveIntentDetectionService = intentDetectionService ?? MockIntentDetectionService();

  // --- Register Mocks for Services ---
  getIt.registerSingleton<EntryPersistenceService>(persistenceService);
  getIt.registerSingleton<AiService>(aiService);
  getIt.registerSingleton<SpeechService>(speechService);
  getIt.registerSingleton<AudioRecorderService>(audioRecorder);
  getIt.registerSingleton<PermissionService>(permissionService);
  getIt.registerSingleton<VectorStoreService>(vectorStoreService); // CP: Register VectorStoreService mock
  getIt.registerSingleton<ImageStorageService>(imageStorageService); // Register ImageStorageService mock
  getIt.registerSingleton<SharedPreferences>(sharedPreferences); // CP: Register SharedPreferences mock
  getIt.registerSingleton<http.Client>(httpClient); // CP: Register http.Client mock
  getIt.registerSingleton<FirestoreSyncService>(effectiveFirestoreSyncService); // CP: Register FirestoreSyncService mock
  getIt.registerSingleton<IntentDetectionService>(effectiveIntentDetectionService); // CP: Register IntentDetectionService mock

  // --- Register TimerFactory for testing ---
  getIt.registerSingleton<TimerFactory>(TestTimerFactory()); // CP: Register test TimerFactory

  // --- Register Snackbar services ---
  getIt.registerSingleton<SnackbarCubit>(SnackbarCubit());
  getIt.registerSingleton<SnackbarService>(SnackbarService(getIt<SnackbarCubit>()));

  // --- Register REAL EntryRepository ---
  // It depends on the mocked services registered above.
  getIt.registerSingleton<EntryRepository>(
    EntryRepository(
      persistenceService: getIt<EntryPersistenceService>(),
      aiService: getIt<AiService>(),
      vectorStoreService: getIt<VectorStoreService>(), // CP: Pass VectorStoreService mock
      timerFactory: getIt<TimerFactory>(), // CP: Pass TimerFactory for tests
      imageStorageService: getIt<ImageStorageService>(), // Pass ImageStorageService mock
      firestoreSyncService: effectiveFirestoreSyncService, // CP: Pass FirestoreSyncService mock
    ),
  );

  // DO NOT Register REAL Cubits here. They will be created in BlocProviders.
}

// Optional: Keep reset function if used elsewhere
Future<void> resetTestDependencies() async {
  await getIt.reset();
}

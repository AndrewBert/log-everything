import 'package:get_it/get_it.dart';
import 'package:myapp/services/ai_categorization_service.dart';
import 'package:myapp/services/entry_persistence_service.dart';
import 'package:myapp/speech_service.dart';
import 'package:myapp/entry/repository/entry_repository.dart';
import 'package:myapp/services/permission_service.dart'; // Import PermissionService
import 'package:myapp/services/audio_recorder_service.dart'; // Import AudioRecorderService

// Create a GetIt instance
GetIt locator = GetIt.instance;

void setupLocator() {
  // Register services
  locator.registerLazySingleton<AiCategorizationService>(
    () => OpenAiCategorizationService(),
  );
  locator.registerLazySingleton<EntryPersistenceService>(
    () => SharedPreferencesEntryPersistenceService(),
  );
  locator.registerLazySingleton(() => SpeechService());

  locator.registerLazySingleton<PermissionService>(
    () => PermissionServiceImpl(),
  );

  locator.registerLazySingleton<AudioRecorderService>(
    () => AudioRecorderServiceImpl(),
  );

  locator.registerLazySingleton(
    () => EntryRepository(
      persistenceService: locator<EntryPersistenceService>(),
      aiService: locator<AiCategorizationService>(),
    ),
  );
}

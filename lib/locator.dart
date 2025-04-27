import 'package:get_it/get_it.dart';
import 'package:myapp/services/ai_categorization_service.dart';
import 'package:myapp/services/entry_persistence_service.dart';
import 'package:myapp/speech_service.dart';
import 'package:record/record.dart';
import 'package:myapp/entry/repository/entry_repository.dart';
import 'package:myapp/services/permission_service.dart'; // Import PermissionService

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
  locator.registerLazySingleton(() => AudioRecorder());
  // Register PermissionService
  locator.registerLazySingleton<PermissionService>(
    () => PermissionServiceImpl(),
  );

  // Register EntryRepository as a lazy singleton
  // It fetches its dependencies (services) from the locator when created
  locator.registerLazySingleton(
    () => EntryRepository(
      persistenceService: locator<EntryPersistenceService>(),
      aiService: locator<AiCategorizationService>(),
    ),
  );
}

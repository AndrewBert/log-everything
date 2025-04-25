import 'package:get_it/get_it.dart';
import 'package:myapp/services/ai_categorization_service.dart';
import 'package:myapp/services/entry_persistence_service.dart';
import 'package:myapp/speech_service.dart';
import 'package:record/record.dart';
import 'package:myapp/entry/cubit/entry_cubit.dart'; // <-- Import EntryCubit

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

  // Register EntryCubit as a lazy singleton
  // It will fetch its dependencies (services) from the locator when created
  locator.registerLazySingleton(() => EntryCubit());
}

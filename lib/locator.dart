import 'package:get_it/get_it.dart';
import 'package:myapp/services/ai_service.dart';
import 'package:myapp/services/entry_persistence_service.dart';
import 'package:myapp/speech_service.dart';
import 'package:myapp/entry/repository/entry_repository.dart';
import 'package:myapp/services/permission_service.dart';
import 'package:myapp/services/audio_recorder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies() async {
  // Register services
  getIt.registerSingletonAsync<SharedPreferences>(
    () => SharedPreferences.getInstance(),
  );
  await getIt.isReady<SharedPreferences>(); // Ensure SharedPreferences is ready

  getIt.registerLazySingleton<AiService>(() => OpenAiService());
  getIt.registerLazySingleton<EntryPersistenceService>(
    () => SharedPreferencesEntryPersistenceService(),
  );
  getIt.registerLazySingleton<SpeechService>(() => SpeechService());

  getIt.registerLazySingleton<PermissionService>(() => PermissionServiceImpl());

  getIt.registerLazySingleton<AudioRecorderService>(
    () => AudioRecorderServiceImpl(),
  );

  getIt.registerLazySingleton(
    () => EntryRepository(
      persistenceService: getIt<EntryPersistenceService>(),
      aiService: getIt<AiService>(),
    ),
  );
}

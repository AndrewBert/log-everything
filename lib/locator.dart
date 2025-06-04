import 'package:flutter_dotenv/flutter_dotenv.dart'; // CP: Add this import
import 'package:get_it/get_it.dart';
import 'package:myapp/services/ai_service.dart';
import 'package:myapp/services/entry_persistence_service.dart';
import 'package:myapp/speech_service.dart';
import 'package:myapp/entry/repository/entry_repository.dart';
import 'package:myapp/services/permission_service.dart';
import 'package:myapp/services/audio_recorder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:myapp/services/vector_store_service.dart'; // CP: Corrected package name

final getIt = GetIt.instance;

Future<void> configureDependencies() async {
  // CP: Load the API key from dotenv
  final String openAIApiKey = dotenv.env['OPENAI_API_KEY'] ?? 'FALLBACK_API_KEY_NOT_FOUND';

  // Register services
  getIt.registerSingletonAsync<SharedPreferences>(() => SharedPreferences.getInstance());
  await getIt.isReady<SharedPreferences>(); // Ensure SharedPreferences is ready

  // CP: Register http.Client
  getIt.registerFactory<http.Client>(() => http.Client());

  // CP: Updated OpenAiService registration to include SharedPreferences
  getIt.registerLazySingleton<AiService>(
    () => OpenAiService(sharedPreferences: getIt<SharedPreferences>()),
  ); // CP: Removed apiKey, assuming OpenAiService handles it internally

  // CP: Register VectorStoreService
  getIt.registerLazySingleton<VectorStoreService>(
    () => VectorStoreService(
      sharedPreferences: getIt<SharedPreferences>(),
      httpClient: getIt<http.Client>(),
      apiKey: openAIApiKey, // CP: Use the API key loaded from .env
      // CP: Provide EntryPersistenceService to VectorStoreService
      entryPersistenceService: getIt<EntryPersistenceService>(),
    ),
  );

  getIt.registerLazySingleton<EntryPersistenceService>(() => SharedPreferencesEntryPersistenceService());
  getIt.registerLazySingleton<SpeechService>(() => SpeechService());

  getIt.registerLazySingleton<PermissionService>(() => PermissionServiceImpl());

  getIt.registerLazySingleton<AudioRecorderService>(() => AudioRecorderServiceImpl());

  getIt.registerLazySingleton(
    () => EntryRepository(
      persistenceService: getIt<EntryPersistenceService>(),
      aiService: getIt<AiService>(),
      vectorStoreService: getIt<VectorStoreService>(), // CP: Injected VectorStoreService
    ),
  );
}

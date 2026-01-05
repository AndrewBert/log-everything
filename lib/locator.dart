import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_it/get_it.dart';
import 'package:myapp/services/ai_service.dart';
import 'package:myapp/services/entry_persistence_service.dart';
import 'package:myapp/speech_service.dart';
import 'package:myapp/entry/repository/entry_repository.dart';
import 'package:myapp/services/permission_service.dart';
import 'package:myapp/services/audio_recorder_service.dart';
import 'package:myapp/services/timer_factory.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:myapp/services/vector_store_service.dart'; // CP: Corrected package name
import 'package:myapp/snackbar/cubit/snackbar_cubit.dart';
import 'package:myapp/snackbar/services/snackbar_service.dart';
import 'package:myapp/intent_detection/services/intent_detection_service.dart';
import 'package:myapp/services/debug_http_server.dart';
import 'package:myapp/services/image_storage_service.dart';
import 'package:myapp/settings/services/auth_service.dart';
import 'package:myapp/utils/app_lifecycle_observer.dart';
import 'package:myapp/services/firestore_sync_service.dart';

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

  // Register TimerFactory for production use
  getIt.registerLazySingleton<TimerFactory>(() => RealTimerFactory());

  // Register SnackbarCubit and SnackbarService
  getIt.registerLazySingleton<SnackbarCubit>(() => SnackbarCubit());
  getIt.registerLazySingleton<SnackbarService>(() => SnackbarService(getIt<SnackbarCubit>()));

  // Register IntentDetectionService
  getIt.registerLazySingleton<IntentDetectionService>(() => IntentDetectionService());

  // Register ImageStorageService
  getIt.registerLazySingleton<ImageStorageService>(() => LocalImageStorageService());

  // CP: Register AuthService for Firebase authentication
  getIt.registerLazySingleton<AuthService>(() => FirebaseAuthService());

  // CP: Register FirestoreSyncService for cloud sync
  getIt.registerLazySingleton<FirestoreSyncService>(() => FirestoreSyncService());

  getIt.registerLazySingleton(
    () => EntryRepository(
      persistenceService: getIt<EntryPersistenceService>(),
      aiService: getIt<AiService>(),
      vectorStoreService: getIt<VectorStoreService>(), // CP: Injected VectorStoreService
      timerFactory: getIt<TimerFactory>(), // CP: Injected TimerFactory
      imageStorageService: getIt<ImageStorageService>(),
      firestoreSyncService: getIt<FirestoreSyncService>(), // CP: Injected for cloud sync
    ),
  );

  // CC: Register AppLifecycleObserver for background processing handling
  getIt.registerLazySingleton<AppLifecycleObserver>(
    () => AppLifecycleObserver(entryRepository: getIt<EntryRepository>()),
  );

  if (kDebugMode) {
    getIt.registerLazySingleton<DebugHttpServer>(
      () => DebugHttpServer(repository: getIt<EntryRepository>()),
    );
  }
}

import 'package:get_it/get_it.dart';
import 'package:mockito/mockito.dart';
import 'package:myapp/entry/repository/entry_repository.dart';
import 'package:myapp/speech_service.dart';
import 'package:record/record.dart';
import 'package:myapp/locator.dart'; // Import your app's locator

// Import mocks (assuming they are generated or defined in mocks.dart)
import 'mocks.mocks.dart'; // Adjust if your mock file is named differently

/// Sets up mocked dependencies in the GetIt locator for testing.
Future<void> setupTestDependencies({
  bool allowReassignment = true,
  // Allow passing specific mocks if needed for certain tests
  MockEntryRepository? entryRepository,
  MockSpeechService? speechService,
  MockAudioRecorder? audioRecorder,
  // Add other mocks as needed (e.g., SharedPreferences, PackageInfo)
}) async {
  // Reset GetIt before registering mocks for a clean slate
  await locator.reset();
  locator.allowReassignment = allowReassignment;

  // Register Mocks - Create instances or use provided ones
  locator.registerLazySingleton<EntryRepository>(
    () => entryRepository ?? MockEntryRepository(),
  );
  locator.registerLazySingleton<SpeechService>(
    () => speechService ?? MockSpeechService(),
  );
  // Use MockAudioRecorder directly as Record() constructor might do setup
  locator.registerLazySingleton<AudioRecorder>(
    () => audioRecorder ?? MockAudioRecorder(),
  );

  // Register other mocks as needed (e.g., SharedPreferences, PackageInfo)
  // Example:
  // locator.registerLazySingleton<SharedPreferences>(() => sharedPreferences ?? MockSharedPreferences());
  // locator.registerLazySingleton<PackageInfo>(() => packageInfo ?? MockPackageInfo());

  // DO NOT Register REAL Cubits here. They will be created in BlocProviders
  // and fetch their dependencies (the mocks above) from the locator.
}

import 'package:myapp/entry/repository/entry_repository.dart';
import 'package:myapp/speech_service.dart';
import 'package:record/record.dart';
import 'package:myapp/locator.dart';
import 'package:myapp/services/permission_service.dart';

import 'mocks.mocks.dart';

/// Sets up mocked dependencies in the GetIt locator for testing.
Future<void> setupTestDependencies({
  bool allowReassignment = true,
  // Allow passing specific mocks if needed for certain tests
  MockEntryRepository? entryRepository,
  MockSpeechService? speechService,
  MockAudioRecorder? audioRecorder,
  MockPermissionService? permissionService, // Add permission service mock
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
  // Register mock permission service
  locator.registerLazySingleton<PermissionService>(
    () => permissionService ?? MockPermissionService(),
  );

  // Register other mocks as needed (e.g., SharedPreferences, PackageInfo)
  // Example:
  // locator.registerLazySingleton<SharedPreferences>(() => sharedPreferences ?? MockSharedPreferences());
  // locator.registerLazySingleton<PackageInfo>(() => packageInfo ?? MockPackageInfo());

  // DO NOT Register REAL Cubits here. They will be created in BlocProviders
  // and fetch their dependencies (the mocks above) from the locator.
}

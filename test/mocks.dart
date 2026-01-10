import 'package:mockito/annotations.dart';
import 'package:myapp/services/audio_recorder_service.dart';
import 'package:myapp/speech_service.dart';
import 'package:record/record.dart';
import 'package:myapp/services/permission_service.dart';
import 'package:myapp/services/entry_persistence_service.dart'; // Import persistence service
import 'package:myapp/services/ai_service.dart'; // Import AI service
import 'package:myapp/services/vector_store_service.dart'; // Import VectorStore service
import 'package:myapp/services/image_storage_service.dart'; // Import ImageStorage service
import 'package:myapp/services/firestore_sync_service.dart'; // CP: Import FirestoreSyncService
import 'package:myapp/services/device_id_service.dart'; // CP: Import DeviceIdService
import 'package:myapp/services/snapshot_service.dart'; // CP: Import SnapshotService
import 'package:myapp/intent_detection/services/intent_detection_service.dart'; // CP: Import IntentDetectionService
import 'package:shared_preferences/shared_preferences.dart'; // Import SharedPreferences
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // CP: Import for DeviceIdService tests
import 'package:http/http.dart' as http; // CP: Import http for mock generation
import 'package:myapp/chat/cubit/chat_cubit.dart'; // CP: Import ChatCubit for mock generation
import 'package:myapp/intent_detection/services/intent_detection_service.dart';
import 'package:myapp/settings/services/auth_service.dart';
import 'package:myapp/settings/cubit/settings_cubit.dart'; // CP: Import SettingsCubit for mock generation

// Generate mocks for the services needed
@GenerateMocks([
  SpeechService,
  AudioRecorder, // Keep if used directly
  PermissionService,
  EntryPersistenceService, // Add persistence service
  AiService, // Add AI service
  AudioRecorderService, // Add audio recorder service
  VectorStoreService, // CP: Add VectorStoreService for mock generation
  ImageStorageService, // Add ImageStorageService for mock generation
  FirestoreSyncService, // CP: Add FirestoreSyncService for mock generation
  DeviceIdService, // CP: Add DeviceIdService for mock generation
  SnapshotService, // CP: Add SnapshotService for mock generation
  FlutterSecureStorage, // CP: Add FlutterSecureStorage for DeviceIdService tests
  IntentDetectionService, // CP: Add IntentDetectionService for mock generation
  SharedPreferences, // CP: Add SharedPreferences for mock generation
  http.Client, // CP: Add http.Client for mock generation
  ChatCubit, // CP: Add ChatCubit for mock generation
  AuthService, // CP: Add AuthService for mock generation
  SettingsCubit, // CP: Add SettingsCubit for recovery dialog tests
])
void main() {}

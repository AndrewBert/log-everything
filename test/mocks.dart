import 'package:mockito/annotations.dart';
import 'package:myapp/services/audio_recorder_service.dart';
import 'package:myapp/speech_service.dart';
import 'package:record/record.dart';
import 'package:myapp/services/permission_service.dart';
import 'package:myapp/services/entry_persistence_service.dart';
import 'package:myapp/services/ai_service.dart';
import 'package:myapp/services/vector_store_service.dart';
import 'package:myapp/services/image_storage_service.dart';
import 'package:myapp/services/image_storage_sync_service.dart';
import 'package:myapp/services/firestore_sync_service.dart';
import 'package:myapp/services/device_id_service.dart';
import 'package:myapp/services/snapshot_service.dart';
import 'package:myapp/intent_detection/services/intent_detection_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:myapp/chat/cubit/chat_cubit.dart';
import 'package:myapp/settings/services/auth_service.dart';
import 'package:myapp/settings/cubit/settings_cubit.dart';
import 'package:firebase_storage/firebase_storage.dart'; // CP: For image sync tests

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
  ImageStorageSyncService, // CP: Add ImageStorageSyncService for mock generation
  FirestoreSyncService, // CP: Add FirestoreSyncService for mock generation
  DeviceIdService, // CP: Add DeviceIdService for mock generation
  SnapshotService, // CP: Add SnapshotService for mock generation
  FlutterSecureStorage, // CP: Add FlutterSecureStorage for DeviceIdService tests
  IntentDetectionService, // CP: Add IntentDetectionService for mock generation
  SharedPreferences, // CP: Add SharedPreferences for mock generation
  http.Client, // CP: Add http.Client for mock generation
  ChatCubit, // CP: Add ChatCubit for mock generation
  AuthService,
  SettingsCubit,
  FirebaseStorage, // CP: For image sync tests
  Reference, // CP: For mocking storage.ref().child() chain
])
void main() {}

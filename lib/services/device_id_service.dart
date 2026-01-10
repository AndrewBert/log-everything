import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import '../utils/logger.dart';

/// Service for generating and persisting a stable device identifier.
///
/// The device ID is stored in iOS Keychain / Android Keystore, which means:
/// - It survives app reinstalls
/// - It's secure and not accessible by other apps
/// - It's tied to the device, not the user
abstract class DeviceIdService {
  /// Gets the device ID, generating one if it doesn't exist.
  Future<String> getDeviceId();

  /// Checks if a device ID exists without creating one.
  Future<bool> hasDeviceId();
}

class SecureStorageDeviceIdService implements DeviceIdService {
  static const String _deviceIdKey = 'log_everything_device_id';

  final FlutterSecureStorage _secureStorage;
  final Uuid _uuid;

  // CP: Cache the device ID in memory to avoid repeated secure storage reads
  String? _cachedDeviceId;

  SecureStorageDeviceIdService({
    FlutterSecureStorage? secureStorage,
    Uuid? uuid,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _uuid = uuid ?? const Uuid();

  @override
  Future<String> getDeviceId() async {
    // CP: Return cached value if available
    if (_cachedDeviceId != null) {
      return _cachedDeviceId!;
    }

    try {
      String? deviceId = await _secureStorage.read(key: _deviceIdKey);

      if (deviceId == null || deviceId.isEmpty) {
        // CP: Generate a new UUID for this device
        deviceId = _uuid.v4();
        await _secureStorage.write(key: _deviceIdKey, value: deviceId);
        AppLogger.info('[DeviceIdService] Generated new device ID: $deviceId');
      } else {
        AppLogger.info('[DeviceIdService] Retrieved existing device ID: $deviceId');
      }

      _cachedDeviceId = deviceId;
      return deviceId;
    } catch (e) {
      AppLogger.error('[DeviceIdService] Error accessing secure storage', error: e);
      // CP: Fall back to generating a new ID (won't persist if storage fails)
      final fallbackId = _uuid.v4();
      AppLogger.warn('[DeviceIdService] Using fallback device ID: $fallbackId');
      return fallbackId;
    }
  }

  @override
  Future<bool> hasDeviceId() async {
    if (_cachedDeviceId != null) {
      return true;
    }

    try {
      final deviceId = await _secureStorage.read(key: _deviceIdKey);
      return deviceId != null && deviceId.isNotEmpty;
    } catch (e) {
      AppLogger.error('[DeviceIdService] Error checking for device ID', error: e);
      return false;
    }
  }
}

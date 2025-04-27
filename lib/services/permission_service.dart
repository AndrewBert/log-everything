import 'package:permission_handler/permission_handler.dart';

/// Abstract interface for handling permissions.
abstract class PermissionService {
  /// Gets the current status of the microphone permission.
  Future<PermissionStatus> getMicrophoneStatus();

  /// Requests microphone permission from the user.
  Future<PermissionStatus> requestMicrophonePermission();
}

/// Concrete implementation of [PermissionService] using the permission_handler package.
class PermissionServiceImpl implements PermissionService {
  @override
  Future<PermissionStatus> getMicrophoneStatus() {
    return Permission.microphone.status;
  }

  @override
  Future<PermissionStatus> requestMicrophonePermission() {
    return Permission.microphone.request();
  }
}

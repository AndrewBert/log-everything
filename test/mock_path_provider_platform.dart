// --- Mock Platform Interface for path_provider ---
// Create a mock class that implements the necessary methods
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:mockito/mockito.dart';

class MockPathProviderPlatform extends Mock
    with
        MockPlatformInterfaceMixin // Use MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  // Mock the methods you expect to be called
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return '/fake/documents/path'; // Return a fake path
  }

  // Mock other methods if needed (e.g., getTemporaryPath)
  // @override
  // Future<String?> getTemporaryPath() async {
  //   return '/fake/temporary/path';
  // }
}

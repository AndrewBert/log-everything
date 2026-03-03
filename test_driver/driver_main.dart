// CP: Separate entrypoint for flutter_driver integration.
// Enables the Driver extension before starting the app so that
// flutter_driver commands (tap, enterText, screenshot, etc.) work.
// Run with: flutter run --target test_driver/driver_main.dart
import 'package:flutter_driver/driver_extension.dart';
import 'package:myapp/main.dart' as app;

void main() {
  enableFlutterDriverExtension();
  app.main();
}

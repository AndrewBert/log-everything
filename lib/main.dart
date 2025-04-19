import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart'; // Import Intl
import 'package:record/record.dart';

import 'cubit/entry_cubit.dart';
import 'cubit/voice_input_cubit.dart';
import 'screens/home_screen.dart'; // Import the new home screen
import 'services/ai_categorization_service.dart'; // Import the AI service
import 'speech_service.dart';
import 'utils/category_colors.dart'; // Import the category colors utility
import 'utils/logger.dart'; // Import logger

Future<void> main() async {
  // Ensure Flutter bindings are initialized first
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables before the app starts
  try {
    await dotenv.load(fileName: ".env");
    AppLogger.info('Environment variables loaded successfully.');
  } catch (e) {
    AppLogger.error('Could not load .env file, using fallback keys.', error: e);
    // Handle error or proceed without .env
  }

  // Initialize the category colors system
  await CategoryColors.initialize();

  // Set the default locale for the entire app
  Intl.defaultLocale = 'en_US';

  // Create the AI service instance
  final aiService = OpenAiCategorizationService();

  // Run the app
  runApp(MyApp(aiService: aiService)); // Pass service to MyApp
}

class MyApp extends StatelessWidget {
  final AiCategorizationService aiService; // Accept the service

  const MyApp({super.key, required this.aiService}); // Update constructor

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<EntryCubit>(
          // Pass the service instance to the Cubit
          create: (context) => EntryCubit(aiService: aiService),
        ),
        BlocProvider<VoiceInputCubit>(
          create:
              (context) => VoiceInputCubit(
                audioRecorder: AudioRecorder(),
                speechService: SpeechService(),
              ),
        ),
      ],
      child: MaterialApp(
        title: 'Log Splitter', // Consider updating title if needed
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
          dividerTheme: const DividerThemeData(space: 1, thickness: 1),
          useMaterial3: true, // Keep Material 3 enabled
        ),
        // Use the new HomeScreen widget
        home: const MyHomePage(title: 'Log Splitter'), // Keep title consistent
      ),
    );
  }
}

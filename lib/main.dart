import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart'; // Import Intl
import 'package:record/record.dart';

import 'cubit/entry_cubit.dart';
import 'cubit/home_screen_cubit.dart'; // Import HomeScreenCubit
import 'cubit/voice_input_cubit.dart';
import 'pages/home_page.dart'; // Import the new home screen
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

  // Initialize services
  final aiService = OpenAiCategorizationService();
  final audioRecorder = AudioRecorder();
  final speechService = SpeechService();

  // Create Cubit instances
  final entryCubit = EntryCubit(aiService: aiService);
  final homeScreenCubit = HomeScreenCubit();
  // Inject EntryCubit into VoiceInputCubit
  final voiceInputCubit = VoiceInputCubit(
    audioRecorder: audioRecorder,
    speechService: speechService,
    entryCubit: entryCubit,
  );

  // Run the app
  runApp(
    MyApp(
      entryCubit: entryCubit,
      homeScreenCubit: homeScreenCubit,
      voiceInputCubit: voiceInputCubit,
    ),
  );
}

class MyApp extends StatelessWidget {
  final EntryCubit entryCubit;
  final HomeScreenCubit homeScreenCubit;
  final VoiceInputCubit voiceInputCubit;

  const MyApp({
    super.key,
    required this.entryCubit,
    required this.homeScreenCubit,
    required this.voiceInputCubit,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: entryCubit),
        BlocProvider.value(value: homeScreenCubit),
        BlocProvider.value(value: voiceInputCubit),
      ],
      child: MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
          dividerTheme: const DividerThemeData(space: 1, thickness: 1),
          useMaterial3: true, // Keep Material 3 enabled
        ),
        // Use the new HomeScreen widget
        home: const HomePage(), // Keep title consistent
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:myapp/pages/cubit/home_screen_cubit.dart';
import 'package:myapp/widgets/voice_input/cubit/voice_input_cubit.dart';
import 'package:myapp/pages/home_page.dart';
import 'package:myapp/services/ai_categorization_service.dart';
import 'package:myapp/speech_service.dart';
import 'package:myapp/utils/category_colors.dart';
import 'package:myapp/utils/logger.dart';
import 'package:record/record.dart'; // <-- Add record import
import 'entry/cubit/entry_cubit.dart';

// Make main async
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
    AppLogger.info('Environment variables loaded successfully.');
  } catch (e) {
    AppLogger.error('Could not load .env file, using fallback keys.', error: e);
  }

  await CategoryColors.initialize();

  Intl.defaultLocale = 'en_US';

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Instantiate concrete services and dependencies
    final aiService =
        OpenAiCategorizationService(); // Use concrete implementation
    final speechService = SpeechService();
    final audioRecorder = AudioRecorder(); // Instantiate AudioRecorder

    // Create EntryCubit instance first to pass it to VoiceInputCubit
    final entryCubit = EntryCubit(aiService: aiService);

    return MultiBlocProvider(
      providers: [
        // Provide the existing EntryCubit instance
        BlocProvider<EntryCubit>.value(value: entryCubit),
        BlocProvider<VoiceInputCubit>(
          create:
              (context) => VoiceInputCubit(
                speechService: speechService,
                audioRecorder: audioRecorder,
                entryCubit: entryCubit, // Pass the created EntryCubit instance
              ),
        ),
        BlocProvider<HomeScreenCubit>(create: (context) => HomeScreenCubit()),
      ],
      child: MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
          dividerTheme: const DividerThemeData(space: 1, thickness: 1),
          useMaterial3: true,
        ),
        home: HomePage(),
      ),
    );
  }
}

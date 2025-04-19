import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart'; // Import Intl
import 'package:record/record.dart';

import 'cubit/entry_cubit.dart';
import 'cubit/voice_input_cubit.dart';
import 'screens/home_screen.dart'; // Import the new home screen
import 'speech_service.dart';

Future<void> main() async {
  // Ensure Flutter bindings are initialized first
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables before the app starts
  // This is necessary because EntryCubit reads from dotenv.env on creation
  await dotenv.load(fileName: ".env");

  // Set the default locale for the entire app
  Intl.defaultLocale = 'en_US';

  // Run the app
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => EntryCubit()),
        BlocProvider(
          create:
              (context) => VoiceInputCubit(
                audioRecorder: AudioRecorder(),
                speechService: SpeechService(),
              ),
        ),
      ],
      child: MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          dividerTheme: const DividerThemeData(space: 1, thickness: 1),
        ),
        // Use the new HomeScreen widget
        home: const MyHomePage(title: 'Log Everything'),
      ),
    );
  }
}

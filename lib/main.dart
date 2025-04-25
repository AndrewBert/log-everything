import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:myapp/pages/cubit/home_screen_cubit.dart';
import 'package:myapp/widgets/voice_input/cubit/voice_input_cubit.dart';
import 'package:myapp/pages/home_page.dart';
import 'package:myapp/utils/category_colors.dart';
import 'package:myapp/utils/logger.dart';
import 'entry/cubit/entry_cubit.dart';
import 'entry/repository/entry_repository.dart'; // <-- Import repository
import 'locator.dart';

// Make main async
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setupLocator(); // <-- Call the setup function here

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
    return MultiBlocProvider(
      providers: [
        // Create EntryCubit, injecting the repository from the locator
        BlocProvider<EntryCubit>(
          create:
              (context) =>
                  EntryCubit(entryRepository: locator<EntryRepository>()),
        ),
        BlocProvider<VoiceInputCubit>(
          create:
              (context) => VoiceInputCubit(), // Already uses locator internally
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

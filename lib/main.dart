import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:myapp/pages/cubit/home_page_cubit.dart';
import 'package:myapp/services/ai_service.dart';
import 'package:myapp/widgets/voice_input/cubit/voice_input_cubit.dart';
import 'package:myapp/pages/home_page.dart';
import 'package:myapp/utils/category_colors.dart';
import 'package:myapp/utils/logger.dart';
import 'chat/chat.dart';
import 'entry/cubit/entry_cubit.dart';
import 'entry/repository/entry_repository.dart';
import 'locator.dart';

// Make main async
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureDependencies();

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
        BlocProvider<EntryCubit>(
          create:
              (context) =>
                  EntryCubit(entryRepository: getIt<EntryRepository>()),
        ),
        BlocProvider<VoiceInputCubit>(
          // CP: Get EntryCubit from context and pass it to constructor
          create:
              (context) =>
                  VoiceInputCubit(entryCubit: context.read<EntryCubit>()),
        ),
        // CP: Provide ChatCubit with AiService dependency
        BlocProvider<ChatCubit>(
          create: (context) => ChatCubit(aiService: getIt<AiService>()),
        ),
        BlocProvider<HomePageCubit>(
          create:
              (context) => HomePageCubit(chatCubit: context.read<ChatCubit>()),
        ),
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

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
// import 'package:myapp/pages/cubit/home_page_cubit.dart'; // CC: Commented out for staged replacement
import 'package:myapp/services/ai_service.dart';
import 'package:myapp/widgets/voice_input/cubit/voice_input_cubit.dart';
// import 'package:myapp/pages/home_page.dart'; // CC: Commented out for staged replacement
import 'package:myapp/dashboard_v2/dashboard_v2_barrel.dart';
import 'package:myapp/utils/category_colors.dart';
import 'package:myapp/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chat/chat.dart';
import 'entry/cubit/entry_cubit.dart';
import 'entry/repository/entry_repository.dart';
import 'onboarding/onboarding.dart';
import 'locator.dart';
import 'snackbar/cubit/snackbar_cubit.dart';

// Make main async
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
    AppLogger.info('Environment variables loaded successfully.');
    await configureDependencies();
    AppLogger.info('Dependencies configured.');
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
        BlocProvider<EntryCubit>(create: (context) => EntryCubit(entryRepository: getIt<EntryRepository>())),
        BlocProvider<VoiceInputCubit>(create: (context) => VoiceInputCubit(entryCubit: context.read<EntryCubit>())),
        BlocProvider<ChatCubit>(create: (context) => ChatCubit(aiService: getIt<AiService>())),
        // BlocProvider<HomePageCubit>(create: (context) => HomePageCubit(chatCubit: context.read<ChatCubit>())), // CC: Commented out for staged replacement
        BlocProvider<OnboardingCubit>(
          create:
              (context) => OnboardingCubit(
                sharedPreferences: getIt<SharedPreferences>(),
                entryCubit: context.read<EntryCubit>(),
              ),
        ),
        BlocProvider<SnackbarCubit>(create: (context) => getIt<SnackbarCubit>()),
      ],
      child: MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
          dividerTheme: const DividerThemeData(space: 1, thickness: 1),
          useMaterial3: true,
        ),
        home: const AppRootWithSnackbar(),
      ),
    );
  }
}

class AppRootWithSnackbar extends StatelessWidget {
  const AppRootWithSnackbar({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppRoot();
  }
}

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<OnboardingCubit, OnboardingState>(
      listenWhen:
          (prev, current) =>
              prev.currentStep != OnboardingStep.completed && current.currentStep == OnboardingStep.completed,
      listener: (context, state) {
        AppLogger.info('[AppRoot] Onboarding completed, showing home page');
      },
      child: BlocBuilder<OnboardingCubit, OnboardingState>(
        builder: (context, state) {
          final onboardingCubit = context.read<OnboardingCubit>();

          if (onboardingCubit.isOnboardingCompleted()) {
            return const DashboardV2Page();
          } else {
            return const OnboardingPage();
          }
        },
      ),
    );
  }
}

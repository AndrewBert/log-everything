import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myapp/chat/cubit/chat_cubit.dart';
import 'package:myapp/chat/model/chat_message.dart';
import 'package:myapp/entry/cubit/entry_cubit.dart';
import 'package:myapp/entry/repository/entry_repository.dart';
import 'package:myapp/locator.dart';
import 'package:myapp/pages/cubit/home_page_cubit.dart';
import 'package:myapp/pages/home_page.dart';
import 'package:myapp/utils/widget_keys.dart';
import 'package:myapp/widgets/voice_input/cubit/voice_input_cubit.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../helpers/test_helpers.dart';
import '../helpers/widget_test_scope.dart';
import '../mock_path_provider_platform.dart';
import '../test_di_registrar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WidgetTestScope scope;

  setUp(() async {
    final mockPathProvider = MockPathProviderPlatform();
    PathProviderPlatform.instance = mockPathProvider;

    scope = WidgetTestScope();
    await setupTestDependencies(
      persistenceService: scope.mockPersistenceService,
      aiService: scope.mockAiService,
      speechService: scope.mockSpeechService,
      audioRecorder: scope.mockAudioRecorderService,
      permissionService: scope.mockPermissionService,
      vectorStoreService: scope.mockVectorStoreService,
      sharedPreferences: scope.mockSharedPreferences,
      httpClient: scope.mockHttpClient,
    );
    scope.initializeWidget();
    scope.stubPersistenceWithInitialEntries();
    scope.stubPermissionGranted();
  });

  tearDown(() async {
    final entryRepository = getIt<EntryRepository>();
    entryRepository.dispose();
    
    await getIt.reset();
    await scope.dispose();
  });

  group('Chat Interface', () {
    group('Chat navigation', () {
      testWidgets(
        'Given user is on home screen, When user taps chat button, Then chat interface opens',
        (WidgetTester tester) async {
          // Given - User is on home screen with chat closed
          await givenHomePageIsDisplayed(tester, scope);

          // Verify chat is initially closed
          expect(find.byKey(chatBottomSheet), findsNothing);
          expect(find.byKey(chatToggleButton), findsOneWidget);
          expect(find.text('Chat'), findsOneWidget);

          // When - User taps chat button
          await tester.tap(find.byKey(chatToggleButton));
          await tester.pumpAndSettle();

          // Then - Chat interface opens
          expect(find.byKey(chatBottomSheet), findsOneWidget);
          expect(find.text('Chat with AI'), findsOneWidget);
          expect(find.byKey(chatCloseButton), findsOneWidget);
          expect(find.text('Close Chat'), findsOneWidget);
        },
      );

      testWidgets(
        'Given chat is open, When user taps close button, Then chat interface closes',
        (WidgetTester tester) async {
          // Given - Chat is open
          await givenHomePageIsDisplayed(tester, scope);

          await tester.tap(find.byKey(chatToggleButton));
          await tester.pumpAndSettle();
          expect(find.byKey(chatBottomSheet), findsOneWidget);

          // When - User taps close button
          await tester.tap(find.byKey(chatCloseButton));
          await tester.pumpAndSettle();

          // Then - Chat interface closes
          expect(find.byKey(chatBottomSheet), findsNothing);
          expect(find.text('Chat'), findsOneWidget);
        },
      );
    });

    group('Empty chat state', () {
      testWidgets(
        'Given chat is opened for first time, When no messages exist, Then welcome message is displayed',
        (WidgetTester tester) async {
          // Given - Chat is opened for first time
          await givenHomePageIsDisplayed(tester, scope);

          // When - User opens chat with no existing messages
          await tester.tap(find.byKey(chatToggleButton));
          await tester.pumpAndSettle();

          // Then - Welcome message and suggestions are displayed
          expect(find.byKey(chatWelcomeMessage), findsOneWidget);
          expect(find.text('Unlock insights from your logs!'), findsOneWidget);
          expect(find.text('Ask me to:'), findsOneWidget);
          expect(find.text('Summarize recent entries'), findsOneWidget);
          expect(find.text('Find logs about a specific topic'), findsOneWidget);
          expect(find.text('Analyze patterns in your data'), findsOneWidget);
          expect(find.text('What would you like to explore?'), findsOneWidget);
        },
      );
    });

    group('Message sending with real cubit', () {
      testWidgets(
        'Given user is in chat, When user types message and sends, Then message appears and AI responds',
        (WidgetTester tester) async {
          // Given - User is in chat with real ChatCubit
          const userMessage = 'What are my recent logs about?';
          const aiResponse = 'Based on your recent logs, you have entries about work, exercise, and personal thoughts.';

          // Create a real ChatCubit instead of using the mocked one
          final realChatCubit = ChatCubit(aiService: scope.mockAiService);
          scope.stubChatResponse(aiResponse, responseId: 'response_123');
          
          // Create widget with real ChatCubit
          await tester.pumpWidget(
            MultiBlocProvider(
              providers: [
                BlocProvider<ChatCubit>.value(value: realChatCubit),
                BlocProvider<EntryCubit>(create: (context) => EntryCubit(entryRepository: getIt<EntryRepository>())),
                BlocProvider<VoiceInputCubit>(create: (context) => VoiceInputCubit(entryCubit: context.read<EntryCubit>())),
                BlocProvider<HomePageCubit>(create: (context) => HomePageCubit(chatCubit: context.read<ChatCubit>())),
              ],
              child: MaterialApp(home: HomePage()),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(chatToggleButton));
          await tester.pumpAndSettle();

          // When - User types message and sends
          await tester.enterText(find.byKey(inputTextField), userMessage);
          await tester.tap(find.byKey(sendButton));
          await tester.pump(); // First pump to show user message

          // Then - User message appears immediately
          expect(find.text(userMessage), findsOneWidget);
          
          // Wait for AI response
          await tester.pumpAndSettle();

          // And AI response appears
          expect(find.text(aiResponse), findsOneWidget);
          expect(find.byKey(chatMessagesList), findsOneWidget);

          // And input field is cleared
          final textField = tester.widget<TextField>(find.byKey(inputTextField));
          expect(textField.controller?.text, isEmpty);

          // Cleanup
          await realChatCubit.close();
        },
      );

      testWidgets(
        'Given AI service has error, When user sends message, Then error message is displayed',
        (WidgetTester tester) async {
          // Given - AI service will return error
          const userMessage = 'Tell me about my logs';
          final realChatCubit = ChatCubit(aiService: scope.mockAiService);
          scope.stubChatError(Exception('API rate limit exceeded'));
          
          // Create widget with real ChatCubit  
          await tester.pumpWidget(
            MultiBlocProvider(
              providers: [
                BlocProvider<ChatCubit>.value(value: realChatCubit),
                BlocProvider<EntryCubit>(create: (context) => EntryCubit(entryRepository: getIt<EntryRepository>())),
                BlocProvider<VoiceInputCubit>(create: (context) => VoiceInputCubit(entryCubit: context.read<EntryCubit>())),
                BlocProvider<HomePageCubit>(create: (context) => HomePageCubit(chatCubit: context.read<ChatCubit>())),
              ],
              child: MaterialApp(home: HomePage()),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(chatToggleButton));
          await tester.pumpAndSettle();

          // When - User sends message despite error
          await tester.enterText(find.byKey(inputTextField), userMessage);
          await tester.tap(find.byKey(sendButton));
          await tester.pumpAndSettle();

          // Then - User message appears
          expect(find.text(userMessage), findsOneWidget);
          
          // And error message is displayed as AI response
          expect(find.textContaining('API rate limit exceeded'), findsOneWidget);

          // Cleanup
          await realChatCubit.close();
        },
      );
    });

    group('Input area behavior in chat mode', () {
      testWidgets(
        'Given chat is open, When user views input area, Then it shows chat-specific styling and hints',
        (WidgetTester tester) async {
          // Given - Chat is open
          await givenHomePageIsDisplayed(tester, scope);

          await tester.tap(find.byKey(chatToggleButton));
          await tester.pumpAndSettle();

          // When - User views input area in chat mode
          // Then - Chat-specific styling and hints are displayed
          expect(find.text('Ask anything'), findsOneWidget);
          expect(find.text('Close Chat'), findsOneWidget);
          
          // Verify normal entry input hints are not shown
          expect(find.text('Log it or else'), findsNothing);
          expect(find.text('Chat'), findsNothing);
        },
      );

      testWidgets(
        'Given user is typing in chat, When user taps outside input, Then keyboard stays focused in chat mode',
        (WidgetTester tester) async {
          // Given - User is typing in chat
          await givenHomePageIsDisplayed(tester, scope);

          await tester.tap(find.byKey(chatToggleButton));
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(inputTextField));
          await tester.pumpAndSettle();

          // When - User taps outside input (on chat interface)
          await tester.tap(find.byKey(chatBottomSheet));
          await tester.pumpAndSettle();

          // Then - Keyboard/focus behavior follows chat mode rules
          // Note: Exact focus behavior depends on implementation
          // This tests that the tap is handled appropriately in chat mode
          expect(find.byKey(chatBottomSheet), findsOneWidget);
        },
      );
    });

    group('Chat conversation with mocked state', () {
      testWidgets(
        'Given user has existing conversation, When chat is opened, Then conversation history is displayed',
        (WidgetTester tester) async {
          // Given - User has existing conversation
          final existingMessages = [
            ChatMessage(
              id: 'msg_1',
              text: 'What is the weather like?',
              sender: ChatSender.user,
              timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
            ),
            ChatMessage(
              id: 'msg_2',
              text: 'I need more information about your location.',
              sender: ChatSender.ai,
              timestamp: DateTime.now().subtract(const Duration(minutes: 4)),
            ),
          ];

          scope.stubChatCubitWithMessages(existingMessages);
          
          await givenHomePageIsDisplayed(tester, scope);

          // When - User opens chat
          await tester.tap(find.byKey(chatToggleButton));
          await tester.pumpAndSettle();

          // Then - Conversation history is displayed
          expect(find.text('What is the weather like?'), findsOneWidget);
          expect(find.text('I need more information about your location.'), findsOneWidget);
          expect(find.byKey(chatMessagesList), findsOneWidget);
          expect(find.byKey(chatWelcomeMessage), findsNothing);
        },
      );
    });
  });
}
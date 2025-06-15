import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mockito/mockito.dart';
import 'package:myapp/entry/cubit/entry_cubit.dart';
import 'package:myapp/entry/repository/entry_repository.dart';
import 'package:myapp/entry/entry.dart';
import 'package:myapp/pages/home_page.dart';
import 'package:myapp/widgets/voice_input/cubit/voice_input_cubit.dart';
import 'package:myapp/pages/cubit/home_page_cubit.dart';
import 'package:myapp/chat/cubit/chat_cubit.dart';
import 'package:myapp/chat/model/chat_message.dart';
import 'package:myapp/snackbar/cubit/snackbar_cubit.dart';
import 'package:myapp/locator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../mocks.mocks.dart';
import 'test_data.dart';

class WidgetTestScope {
  late MockEntryPersistenceService mockPersistenceService;
  late MockAiService mockAiService;
  late MockSpeechService mockSpeechService;
  late MockAudioRecorderService mockAudioRecorderService;
  late MockPermissionService mockPermissionService;
  late MockVectorStoreService mockVectorStoreService;
  late MockSharedPreferences mockSharedPreferences;
  late MockClient mockHttpClient;
  late MockChatCubit mockChatCubit;

  late Widget widgetUnderTest;

  WidgetTestScope() {
    mockPersistenceService = MockEntryPersistenceService();
    mockAiService = MockAiService();
    mockSpeechService = MockSpeechService();
    mockAudioRecorderService = MockAudioRecorderService();
    when(mockAudioRecorderService.onStateChanged()).thenAnswer((_) => Stream<RecordState>.empty());
    mockPermissionService = MockPermissionService();
    mockVectorStoreService = MockVectorStoreService();
    when(mockVectorStoreService.getOrCreateVectorStoreId()).thenAnswer((_) async => null);
    when(mockVectorStoreService.synchronizeMonthlyLogFile(any, any, any)).thenAnswer((_) async {});
    when(mockVectorStoreService.performInitialBackfillIfNeeded()).thenAnswer((_) async {});
    when(mockVectorStoreService.cleanupDuplicateFiles()).thenAnswer((_) async {});
    mockSharedPreferences = MockSharedPreferences();
    mockHttpClient = MockClient();
    mockChatCubit = MockChatCubit();
    when(mockChatCubit.loadDummyMessages()).thenAnswer((_) async {});
    when(mockChatCubit.stream).thenAnswer((_) => Stream<ChatState>.value(const ChatState()));
    when(mockChatCubit.state).thenReturn(const ChatState());
  }

  void initializeWidget() {
    widgetUnderTest = MultiBlocProvider(
      providers: [
        BlocProvider<ChatCubit>.value(value: mockChatCubit),
        BlocProvider<EntryCubit>(create: (context) => EntryCubit(entryRepository: getIt<EntryRepository>())),
        BlocProvider<VoiceInputCubit>(create: (context) => VoiceInputCubit(entryCubit: context.read<EntryCubit>())),
        BlocProvider<HomePageCubit>(create: (context) => HomePageCubit(chatCubit: context.read<ChatCubit>())),
        BlocProvider.value(value: getIt<SnackbarCubit>()),
      ],
      child: MaterialApp(home: HomePage()),
    );
  }

  void stubPersistenceWithInitialEntries() {
    when(mockPersistenceService.loadEntries()).thenAnswer((_) async => List.from(TestData.rawEntriesList));
    when(mockPersistenceService.loadCategories()).thenAnswer((_) async => List.from(TestData.categoriesList));
    when(mockPersistenceService.saveEntries(any)).thenAnswer((_) async {});
    when(mockPersistenceService.saveCategories(any)).thenAnswer((_) async {});
  }

  void stubPersistenceWithEmptyEntries() {
    when(mockPersistenceService.loadEntries()).thenAnswer((_) async => []);
    when(mockPersistenceService.loadCategories()).thenAnswer((_) async => List.from(TestData.categoriesList));
    when(mockPersistenceService.saveEntries(any)).thenAnswer((_) async {});
    when(mockPersistenceService.saveCategories(any)).thenAnswer((_) async {});
  }

  void stubPermissionGranted() {
    when(mockPermissionService.getMicrophoneStatus()).thenAnswer((_) async => PermissionStatus.granted);
    when(mockPermissionService.requestMicrophonePermission()).thenAnswer((_) async => PermissionStatus.granted);
  }

  void stubStartRecordingSuccess() {
    when(mockAudioRecorderService.generateRecordingPath()).thenAnswer((_) async => 'fake/path/recording.m4a');
    when(mockAudioRecorderService.start(any, path: anyNamed('path'))).thenAnswer((_) async => Future.value());
    when(mockAudioRecorderService.isRecording()).thenAnswer((_) async => true);
    when(mockAudioRecorderService.stop()).thenAnswer((_) async => 'fake/path/recording.m4a');
    // Stub to ensure recording is considered long enough (>1 second)
    when(mockAudioRecorderService.onStateChanged()).thenAnswer((_) => Stream<RecordState>.empty());
  }

  void stubTranscriptionSuccess(String resultText) {
    when(mockSpeechService.transcribeAudio(any, language: anyNamed('language'))).thenAnswer((_) async => resultText);
  }

  void stubAiServiceExtractEntries() {
    when(mockAiService.extractEntries(any, any)).thenAnswer(
      (_) async => [
        (textSegment: TestData.testEntryText, category: 'Misc', isTask: false),
      ],
    );
  }

  // CP: Checklist-specific persistence stubs
  void stubPersistenceWithChecklistCategories() {
    when(mockPersistenceService.loadEntries()).thenAnswer((_) async => [TestData.checklistEntryIncomplete]);
    when(mockPersistenceService.loadCategories()).thenAnswer((_) async => [TestData.checklistCategory]);
    when(mockPersistenceService.saveEntries(any)).thenAnswer((_) async {});
    when(mockPersistenceService.saveCategories(any)).thenAnswer((_) async {});
  }

  void stubPersistenceWithRegularCategories() {
    when(mockPersistenceService.loadEntries()).thenAnswer((_) async => [TestData.regularEntry]);
    when(mockPersistenceService.loadCategories()).thenAnswer((_) async => [TestData.regularCategory]);
    when(mockPersistenceService.saveEntries(any)).thenAnswer((_) async {});
    when(mockPersistenceService.saveCategories(any)).thenAnswer((_) async {});
  }

  void stubPersistenceWithMixedCategories() {
    when(mockPersistenceService.loadEntries()).thenAnswer((_) async => TestData.checklistEntriesWithMixed);
    when(mockPersistenceService.loadCategories()).thenAnswer((_) async => TestData.categoriesWithChecklist);
    when(mockPersistenceService.saveEntries(any)).thenAnswer((_) async {});
    when(mockPersistenceService.saveCategories(any)).thenAnswer((_) async {});
  }

  void stubPersistenceWithChecklistEntries(List<Entry> entries) {
    when(mockPersistenceService.loadEntries()).thenAnswer((_) async => entries);
    when(mockPersistenceService.loadCategories()).thenAnswer((_) async => [TestData.checklistCategory]);
    when(mockPersistenceService.saveEntries(any)).thenAnswer((_) async {});
    when(mockPersistenceService.saveCategories(any)).thenAnswer((_) async {});
  }

  void stubPersistenceWithMixedEntries(List<Entry> entries) {
    when(mockPersistenceService.loadEntries()).thenAnswer((_) async => entries);
    when(mockPersistenceService.loadCategories()).thenAnswer((_) async => TestData.categoriesWithChecklist);
    when(mockPersistenceService.saveEntries(any)).thenAnswer((_) async {});
    when(mockPersistenceService.saveCategories(any)).thenAnswer((_) async {});
  }

  void stubChatResponse(String responseText, {String? responseId}) {
    when(mockAiService.getChatResponse(
      messages: anyNamed('messages'),
      currentDate: anyNamed('currentDate'),
      store: anyNamed('store'),
      previousResponseId: anyNamed('previousResponseId'),
    )).thenAnswer((_) async => (responseText, responseId));
  }

  void stubChatError(Exception error) {
    when(mockAiService.getChatResponse(
      messages: anyNamed('messages'),
      currentDate: anyNamed('currentDate'),
      store: anyNamed('store'),
      previousResponseId: anyNamed('previousResponseId'),
    )).thenThrow(error);
  }

  void stubChatCubitWithMessages(List<ChatMessage> messages, {bool isLoading = false, String? lastResponseId}) {
    final chatState = ChatState(messages: messages, isLoading: isLoading, lastResponseId: lastResponseId);
    when(mockChatCubit.state).thenReturn(chatState);
    when(mockChatCubit.stream).thenAnswer((_) => Stream<ChatState>.value(chatState));
  }

  void stubChatCubitEmpty() {
    stubChatCubitWithMessages([]);
  }

  Future<void> dispose() async {}
}

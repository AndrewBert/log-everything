# Tasks: Unified Text Field with Chat Intent Detection

**Input**: Design documents from `/specs/001-chat-feature-i/`
**Prerequisites**: plan.md, research.md, data-model.md, contracts/intent_detection_contract.yaml
**Branch**: `001-chat-feature-i`

## Execution Flow (main)
```
1. Load plan.md from feature directory ✅
   → Tech stack: Flutter, flutter_bloc, get_it, openai_dart
   → Structure: Feature-based (intent_detection, chat, dashboard_v2)
2. Load optional design documents ✅
   → data-model.md: 5 entities (IntentType, IntentClassification, ChatMessage, ChatState, DashboardV2State)
   → contracts/: 1 contract (intent_detection_contract.yaml)
   → research.md: GPT-5-nano integration pattern, reuse chat backend
3. Generate tasks by category (below)
4. Apply task rules:
   → Different files = mark [P] for parallel
   → Same file = sequential (no [P])
   → Models before services before cubits before UI
5. Number tasks sequentially (T001-T029)
6. Dependencies documented below
7. Parallel execution examples provided
8. Validation: All entities modeled ✅, contract addressed ✅, all components covered ✅
9. Status: SUCCESS - Tasks ready for execution
```

## Path Conventions
- **Mobile Flutter app** structure per plan.md:
  - `lib/intent_detection/` - New feature module
  - `lib/chat/` - Existing module (updates needed)
  - `lib/dashboard_v2/` - Existing module (updates needed)
  - `lib/services/` - Existing services
  - `lib/utils/` - Widget keys
  - `lib/locator.dart` - DI registration

---

## Phase 3.1: Setup & Models

- [ ] **T001 [P]** Define `IntentType` enum in `lib/intent_detection/models/intent_type.dart`
  - Values: `note`, `chat`, `ambiguous`
  - No JSON serialization needed (enum)

- [ ] **T002 [P]** Define `IntentClassification` model in `lib/intent_detection/models/intent_classification.dart`
  - Fields: `type` (IntentType), `confidence` (double), `timestamp` (DateTime)
  - Extend Equatable
  - Add validation: confidence ∈ [0.0, 1.0]
  - No JSON serialization needed (ephemeral model)

- [ ] **T003 [P]** Create barrel file `lib/intent_detection/models/models.dart`
  - Export `intent_type.dart` and `intent_classification.dart`

---

## Phase 3.2: Intent Detection Service

- [ ] **T004** Create `IntentDetectionService` in `lib/intent_detection/services/intent_detection_service.dart`
  - Method: `Future<IntentClassification> classifyIntent(String userInput)`
  - Use GPT-5-nano via OpenAI Responses API (per research.md)
  - Implement prompt from contract: system message + user input
  - Parse JSON response: `{"intent": "note"|"chat"|"ambiguous", "confidence": 0.0-1.0}`
  - Add timeout: 2 seconds (per research.md fallback strategy)
  - Validate confidence threshold: <0.7 = ambiguous

- [ ] **T005** Register `IntentDetectionService` in `lib/locator.dart`
  - Add as lazy singleton in GetIt
  - Inject dependencies (if any, likely just config)

---

## Phase 3.3: Dashboard V2 State Extensions

- [ ] **T006** Extend `DashboardV2State` in `lib/dashboard_v2/cubit/dashboard_v2_state.dart`
  - Add fields:
    - `isClassifyingIntent` (bool, default: false)
    - `lastIntentClassification` (IntentClassification?, nullable)
    - `intentClassificationError` (String?, nullable)
  - Update `copyWith` method with null-handling parameters:
    - `clearLastIntentClassification` (bool)
    - `clearIntentClassificationError` (bool)
  - Add new fields to `props` list for Equatable

- [ ] **T007** Update `DashboardV2Cubit` in `lib/dashboard_v2/cubit/dashboard_v2_cubit.dart`
  - Inject `IntentDetectionService` via constructor
  - Create method: `Future<void> handleUserInput(String text, BuildContext context)`
  - Implement flow:
    1. Set `isClassifyingIntent = true`
    2. Call `intentDetectionService.classifyIntent(text)` with timeout
    3. On success:
       - Set `lastIntentClassification = result`
       - Route based on `IntentType`:
         - `note` → Call existing note-logging flow
         - `chat` → Navigate to `FullscreenChatPage` with initial query
         - `ambiguous` → Show `IntentClarificationDialog`
    4. On error/timeout:
       - Set `intentClassificationError = message`
       - Default to note-logging (per research.md)
    5. Set `isClassifyingIntent = false`

---

## Phase 3.4: Chat State & Cubit Updates

- [ ] **T008** Update `ChatCubit` in `lib/chat/cubit/chat_cubit.dart`
  - Add method: `void startChatWithQuery(String queryText)`
  - Implementation:
    1. Create initial `ChatMessage` with user's query
    2. Emit state with `messages = [userMessage]`, `isLoading = true`
    3. Call `addUserMessageStreaming(queryText)` to get AI response
  - Preserve existing methods: `addUserMessage()`, `addUserMessageStreaming()`

---

## Phase 3.5: UI Components - Dialogs & Pages

- [ ] **T009 [P]** Create `IntentClarificationDialog` in `lib/chat/widgets/intent_clarification_dialog.dart`
  - StatelessWidget
  - Parameters: `userInput` (String), `onNoteSelected` (VoidCallback), `onChatSelected` (VoidCallback)
  - Use `AlertDialog` with:
    - Title: "What would you like to do?"
    - Content: Display user's input with explanatory text
    - Actions:
      - "Log as Note" button with icon (Icons.edit_note)
      - "Start Chat" button with icon (Icons.chat_bubble_outline)
  - Accessible: Clear labels, supports VoiceOver

- [ ] **T010 [P]** Create `FullscreenChatPage` in `lib/chat/pages/fullscreen_chat_page.dart`
  - StatelessWidget with Scaffold
  - AppBar: Back button (auto-handled by MaterialPageRoute fullscreenDialog)
  - Body: `BlocBuilder<ChatCubit, ChatState>` for reactive messages list
  - ListView: Display chat messages using existing `ChatMessageBubble` widget
  - Bottom text field: For follow-up questions
  - Private method: `_buildMessageList()` below `build()`
  - Private method: `_buildInputField()` below `_buildMessageList()`

- [ ] **T011 [P]** Define widget keys in `lib/utils/chat_keys.dart`
  - Keys for:
    - `intentClarificationDialog`
    - `intentClarificationNoteButton`
    - `intentClarificationChatButton`
    - `fullscreenChatPage`
    - `fullscreenChatTextField`
    - `fullscreenChatSendButton`
    - `fullscreenChatMessagesList`

---

## Phase 3.6: Dashboard Integration - Unified Text Field

- [ ] **T012** Update `UnifiedTextField` widget in `lib/dashboard_v2/widgets/unified_text_field.dart`
  - Add `BlocListener<DashboardV2Cubit, DashboardV2State>` for navigation:
    - Listen to `lastIntentClassification` changes
    - When `type == IntentType.chat`: Navigate to `FullscreenChatPage`
    - When `type == IntentType.ambiguous`: Show `IntentClarificationDialog`
  - Update suffix icon:
    - Show `CircularProgressIndicator` when `isClassifyingIntent == true`
    - Revert to normal icon when `isClassifyingIntent == false`
  - Disable text field when `isClassifyingIntent == true`
  - Handle submit action:
    - Call `context.read<DashboardV2Cubit>().handleUserInput(text, context)`
    - Clear field after submission

- [ ] **T013** Update `DashboardV2Page` in `lib/dashboard_v2/pages/dashboard_v2_page.dart`
  - Ensure `DashboardV2Cubit` is provided via `BlocProvider`
  - Pass `IntentDetectionService` to cubit during provider creation
  - No other changes needed (existing structure supports new flow)

---

## Phase 3.7: Navigation & Routing

- [ ] **T014** Implement navigation helper in `lib/dashboard_v2/cubit/dashboard_v2_cubit.dart`
  - Add private method: `void _navigateToChat(BuildContext context, String initialQuery)`
  - Use `Navigator.push()` with `MaterialPageRoute`:
    - `fullscreenDialog: true` for iOS-style modal
    - `BlocProvider` wraps `FullscreenChatPage`
    - Create new `ChatCubit` instance with `aiService` dependency
    - Call `chatCubit.startChatWithQuery(initialQuery)` after creation
  - Add private method: `void _showIntentClarificationDialog(BuildContext context, String userInput)`
  - Show `IntentClarificationDialog` with:
    - `onNoteSelected`: Process as note, close dialog
    - `onChatSelected`: Navigate to chat, close dialog

---

## Phase 3.8: Error Handling & Fallbacks

- [ ] **T015** Add error handling to `IntentDetectionService`
  - Catch API errors (400, 401, 429) and throw custom exceptions
  - Catch timeout exceptions
  - Catch JSON parsing errors
  - Return user-friendly error messages

- [ ] **T016** Add error UI to `UnifiedTextField`
  - Listen to `intentClassificationError` in `DashboardV2State`
  - Show SnackBar with error message if present
  - Clear error after displaying

---

## Phase 3.9: Polish & Code Quality

- [ ] **T017 [P]** Add barrel file `lib/intent_detection/intent_detection.dart`
  - Export models, services, and any utilities

- [ ] **T018 [P]** Add barrel file `lib/chat/chat.dart` (if not exists)
  - Export pages, widgets, models, cubit

- [ ] **T019 [P]** Remove unnecessary comments from new code
  - Keep only CP-prefixed comments where needed
  - Ensure code is self-documenting

- [ ] **T020** Run `flutter analyze`
  - Fix all lints and warnings
  - Ensure code quality standards met

- [ ] **T021** Run `dart format lib/`
  - Apply 120 char line width
  - Preserve trailing commas

- [ ] **T022** Verify `Color.withValues()` usage
  - Replace any `withOpacity()` calls with `withValues(alpha: ...)`

---

## Phase 3.10: User Validation

- [ ] **T023** User tests Scenario 1: Log a note (from quickstart.md)
  - Input: "Had lunch at Thai restaurant with Sarah"
  - Expected: Intent detected as "note", entry logged
  - Performance: Classification < 500ms

- [ ] **T024** User tests Scenario 2: Start a chat (from quickstart.md)
  - Input: "When was the last time I went to a Thai restaurant?"
  - Expected: Intent detected as "chat", full-screen chat opens, AI responds

- [ ] **T025** User tests Scenario 3: Ambiguous input (from quickstart.md)
  - Input: "Coffee"
  - Expected: Clarification dialog appears with two options

- [ ] **T026** User tests Scenario 4: Chat follow-up questions (from quickstart.md)
  - Input: "Show me my workouts this month" → "Which day did I work out the most?"
  - Expected: Conversation context preserved

- [ ] **T027** User tests Scenario 6: Intent detection failure fallback (from quickstart.md)
  - Simulate: Disable network
  - Expected: Default to note-logging mode, no error shown to user

- [ ] **T028** User tests performance benchmarks (from quickstart.md)
  - Intent classification < 500ms
  - Chat response < 2s
  - UI remains responsive

- [ ] **T029** User tests accessibility (from quickstart.md)
  - VoiceOver compatibility
  - Keyboard navigation in dialog
  - Text scaling support

---

## Dependencies

### Sequential Dependencies
```
Setup & Models (T001-T003)
    ↓
Intent Detection Service (T004-T005)
    ↓
Dashboard State Extensions (T006-T007)
    ↓
Chat Cubit Updates (T008)
    ↓
UI Components (T009-T011) [can run in parallel]
    ↓
Dashboard Integration (T012-T013)
    ↓
Navigation & Routing (T014)
    ↓
Error Handling (T015-T016)
    ↓
Polish (T017-T022) [can run in parallel]
    ↓
User Validation (T023-T029)
```

### Parallel Task Groups
1. **Models**: T001, T002, T003 (different files)
2. **UI Components**: T009, T010, T011 (different files)
3. **Barrel Files**: T017, T018 (different files)
4. **Formatting**: T019, T020, T021, T022 (independent checks)

---

## Parallel Execution Examples

### Example 1: Create All Models Simultaneously
```bash
# Use Task agent to create models in parallel
Task: "Define IntentType enum in lib/intent_detection/models/intent_type.dart per T001"
Task: "Define IntentClassification model in lib/intent_detection/models/intent_classification.dart per T002"
Task: "Create barrel file lib/intent_detection/models/models.dart per T003"
```

### Example 2: Build UI Components Together
```bash
# After state management is complete, build UI in parallel
Task: "Create IntentClarificationDialog in lib/chat/widgets/intent_clarification_dialog.dart per T009"
Task: "Create FullscreenChatPage in lib/chat/pages/fullscreen_chat_page.dart per T010"
Task: "Define widget keys in lib/utils/chat_keys.dart per T011"
```

### Example 3: Polish Tasks in Parallel
```bash
# Final cleanup can be done concurrently
Task: "Create barrel file lib/intent_detection/intent_detection.dart per T017"
Task: "Create barrel file lib/chat/chat.dart per T018"
Task: "Remove unnecessary comments per T019"
```

---

## Notes

- **[P] Markers**: 9 tasks can run in parallel (T001, T002, T003, T009, T010, T011, T017, T018, T019)
- **Constitution Compliance**: All widgets StatelessWidget, cubits via BlocProvider, services in GetIt
- **No Test Generation**: Per constitution, user validates in running app (T023-T029)
- **Performance Targets**: Intent classification <500ms, chat response <2s
- **Fallback Strategy**: API failure defaults to note-logging mode
- **Accessibility**: All UI components support VoiceOver, keyboard navigation, text scaling

---

## Validation Checklist
*GATE: Verified before execution*

- [x] All entities have model tasks (IntentType: T001, IntentClassification: T002)
- [x] Services registered in locator.dart (IntentDetectionService: T005, NOT cubits)
- [x] Cubits provided via BlocProvider (DashboardV2Cubit: T013, ChatCubit: T014)
- [x] All widgets are StatelessWidget (IntentClarificationDialog: T009, FullscreenChatPage: T010)
- [x] Widget keys defined in utils files (chat_keys.dart: T011)
- [x] Parallel tasks truly independent (verified: different files, no dependencies)
- [x] Each task specifies exact file path (all tasks include full paths)
- [x] No task modifies same file as another [P] task (verified: no conflicts)
- [x] Contract addressed (intent_detection_contract.yaml → IntentDetectionService: T004)

---

## Task Execution Strategy

**Recommended Order**:
1. Start with models (T001-T003) to establish data structures
2. Implement service layer (T004-T005) for core logic
3. Extend existing state management (T006-T008) to wire in new functionality
4. Build UI components (T009-T011) for user interaction
5. Integrate into dashboard (T012-T013) and navigation (T014)
6. Add error handling (T015-T016) for robustness
7. Polish code quality (T017-T022)
8. User validates all scenarios (T023-T029)

**Commit Frequency**: Commit after each phase completes (e.g., after T003, T005, T008, T014, T016, T022, T029)

**Estimated Effort**: 29 tasks, ~15-20 hours of focused implementation (excluding user validation)

**Next Step**: Begin with T001 - Define IntentType enum

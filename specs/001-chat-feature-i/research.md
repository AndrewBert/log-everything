# Research: Unified Text Field with Chat Intent Detection

**Date**: 2025-10-05
**Feature**: 001-chat-feature-i

## 1. GPT-4o-nano Integration for Intent Classification

### Decision
Use OpenAI's `gpt-5-nano` model (already defined in `AiService`) for real-time intent classification with a simple binary prompt.

### Rationale
- Model constant already exists: `OpenAiService.gpt5Nano` = `'gpt-5-nano'`
- Fast, lightweight model suitable for <500ms classification target
- Existing API infrastructure supports structured JSON output
- Same request/response pattern as `extractEntries()` method

### Implementation Pattern
```dart
// Prompt Design
final systemPrompt = """You are an intent classifier that determines if user input is a NOTE or a CHAT question.

NOTE: A statement to be logged (e.g., "Had coffee with Sarah", "Feeling good today")
CHAT: A question about existing logs (e.g., "When did I last have coffee?", "Show my workouts")

Return JSON: { "intent": "note" | "chat" | "ambiguous", "confidence": 0.0-1.0 }

Mark as "ambiguous" if confidence < 0.7""";

// Request Body
{
  'model': 'gpt-5-nano',
  'input': [
    {'role': 'system', 'content': systemPrompt},
    {'role': 'user', 'content': userInput}
  ],
  'text': {
    'format': {
      'type': 'json_object'
    }
  },
  'metadata': {
    'request_type': 'intent_classification',
    'app_name': 'log-everything'
  }
}
```

### Expected Latency
- Target: <500ms (per performance goals)
- Model optimized for speed over accuracy
- Blocking UI acceptable per clarifications

### Error Handling
- API failure → Default to note-logging mode (per clarification)
- Timeout (>2s) → Default to note-logging mode
- Ambiguous result → Show clarification dialog (per clarification)

## 2. Existing Chat Backend Analysis

### Reusable Components

#### AiService (lib/services/ai_service.dart)
**Existing Methods**:
- ✅ `getChatResponse()` - Non-streaming chat (lines 417-600)
  - Takes: `List<ChatMessage>`, `DateTime?`, `bool store`, `String? previousResponseId`
  - Returns: `(String text, String? responseId)`
  - Features: Vector store search, conversation chaining, error handling

- ✅ `streamChatResponse()` - Streaming chat with SSE (lines 602-766)
  - Same parameters as `getChatResponse()`
  - Returns: `Stream<ChatStreamEvent>` (delta, completed, error events)
  - Features: Real-time streaming, typewriter effect support

**Models** (lines 134-142):
```dart
static const gpt5Mini = 'gpt-5-mini';  // Current chat model
static const gpt5Nano = 'gpt-5-nano';  // Available for intent detection
```

**Vector Store Integration** (lines 435-483):
- Retrieves `openai_vector_store_id` from SharedPreferences
- Enables File Search tool for log querying
- Existing infrastructure - no changes needed

#### ChatCubit (lib/chat/cubit/chat_cubit.dart)
**Existing Functionality**:
- ✅ `addUserMessage()` - Non-streaming chat (lines 21-70)
- ✅ `addUserMessageStreaming()` - Streaming with typewriter effect (lines 72-254)
- ✅ State management: messages list, loading state, response chaining
- ✅ Error handling with user-friendly messages

**ChatMessage Model** (lib/chat/model/chat_message.dart):
```dart
class ChatMessage extends Equatable {
  final String id;
  final String text;
  final ChatSender sender;  // enum: user, ai
  final DateTime timestamp;
}
```

### Required Modifications
1. **ChatCubit**: Add method to initialize chat from query text
   ```dart
   void startChatWithQuery(String queryText) {
     // Clear previous messages (optional)
     // Add initial query as user message
     // Trigger streaming response
   }
   ```

2. **Chat History Persistence**: Already handled via OpenAI API
   - `store: true` parameter persists conversations server-side
   - `previousResponseId` chains conversations
   - Per clarification: retrieve from OpenAI, not local storage

### Alternatives Considered
- **Local chat persistence**: Rejected - per clarification, use OpenAI API
- **WebSocket streaming**: Rejected - SSE already implemented and working
- **Custom AI service**: Rejected - reuse existing `AiService` infrastructure

## 3. Full-Screen Chat UI Patterns in Flutter

### Decision
Use `MaterialPageRoute` with `Navigator.push()` for full-screen modal transition.

### Navigation Pattern
```dart
// From DashboardV2Cubit or UnifiedTextField
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (context) => BlocProvider(
      create: (context) => ChatCubit(aiService: getIt<AiService>())
        ..startChatWithQuery(initialQuery),
      child: const FullscreenChatPage(),
    ),
    fullscreenDialog: true,  // iOS-style modal presentation
  ),
);
```

### Design Pattern
**FullscreenChatPage** (new file: `lib/chat/pages/fullscreen_chat_page.dart`):
- StatelessWidget with Scaffold
- AppBar with back button (auto-handled by `fullscreenDialog: true`)
- ListView for chat messages (reuse existing `ChatMessageBubble` if available)
- Bottom text field for follow-up questions
- BlocBuilder<ChatCubit, ChatState> for reactive UI

### Passing Initial Query
Per clarification: Display original query as first message
```dart
class ChatCubit {
  void startChatWithQuery(String queryText) {
    final userMessage = ChatMessage(
      id: _uuid.v4(),
      text: queryText,
      sender: ChatSender.user,
      timestamp: DateTime.now(),
    );
    emit(state.copyWith(messages: [userMessage], isLoading: true));

    // Trigger AI response
    addUserMessageStreaming(queryText);
  }
}
```

### Back Navigation
- User presses back button → `Navigator.pop(context)`
- Returns to dashboard with unified text field ready
- Chat session persists in OpenAI (per clarification)

### Alternatives Considered
- **BottomSheet**: Rejected - not full-screen as specified
- **Custom Route Transition**: Rejected - MaterialPageRoute sufficient
- **Dedicated Navigator**: Rejected - single-stack navigation adequate

## 4. Intent Ambiguity UX Patterns

### Decision
Use `AlertDialog` with two action buttons for binary choice.

### Dialog Design
**IntentClarificationDialog** (new file: `lib/chat/widgets/intent_clarification_dialog.dart`):
```dart
class IntentClarificationDialog extends StatelessWidget {
  final String userInput;
  final VoidCallback onNoteSelected;
  final VoidCallback onChatSelected;

  // AlertDialog with:
  // - Title: "What would you like to do?"
  // - Content: Display user's text with icon indicators
  // - Actions: [Log as Note] [Start Chat]
}
```

### User Flow
1. User submits text → Intent detection runs (blocking)
2. Result = "ambiguous" → Show dialog
3. User taps "Log as Note" → Process as note entry
4. User taps "Start Chat" → Navigate to full-screen chat

### Dialog Structure
```dart
AlertDialog(
  title: Text('What would you like to do?'),
  content: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('"$userInput"'),
      SizedBox(height: 16),
      Text('Is this a note to log or a question about your logs?'),
    ],
  ),
  actions: [
    TextButton(
      onPressed: onNoteSelected,
      child: Row(children: [
        Icon(Icons.edit_note),
        Text('Log as Note'),
      ]),
    ),
    TextButton(
      onPressed: onChatSelected,
      child: Row(children: [
        Icon(Icons.chat_bubble_outline),
        Text('Start Chat'),
      ]),
    ),
  ],
)
```

### Accessibility
- Clear button labels with semantic meaning
- Icons + text for visual clarity
- Keyboard navigation support (auto-handled by AlertDialog)
- VoiceOver compatible (StatelessWidget pattern)

### Alternatives Considered
- **BottomSheet**: Rejected - less prominent for important decision
- **Inline buttons**: Rejected - blocks text field UX
- **Swipe gestures**: Rejected - not accessible, unclear affordance

## 5. Loading State Management During Intent Detection

### Decision
Reuse existing AI analysis loading state from note categorization flow.

### Existing Implementation
The app already has a loading indicator for when AI analyzes user notes for categorization. This same loading state can be reused for intent detection with minimal changes.

**Current State** (from existing note flow):
- TextField disabled during AI processing
- Loading indicator displayed (likely in suffix or as overlay)
- User sees "Analyzing..." or similar feedback
- Handles both success and error states

### Integration Approach
```dart
// DashboardV2Cubit - minimal changes needed
Future<void> handleUserInput(String text) async {
  // Trigger existing loading state
  emit(state.copyWith(isLoading: true));  // Existing field

  try {
    // New: Intent detection (uses same loading UI)
    final intent = await _intentDetectionService.classifyIntent(text)
      .timeout(Duration(seconds: 2));

    // Route based on intent
    if (intent.type == IntentType.note) {
      // Continue with existing note flow (already has loading)
      await _processAsNote(text);
    } else if (intent.type == IntentType.chat) {
      emit(state.copyWith(isLoading: false));
      // Navigate to chat (loading stops)
    } else {
      // Show ambiguity dialog (loading stops)
      emit(state.copyWith(isLoading: false));
    }
  } catch (e) {
    // Existing error handling applies
    emit(state.copyWith(isLoading: false));
  }
}
```

### Benefits of Reuse
- **Consistent UX**: Same loading experience for AI operations
- **No new UI code**: Existing loading indicator just works
- **Error handling**: Existing timeout/error UI applies to intent detection
- **Faster implementation**: No new loading state design needed

### Visual Feedback Timeline
1. User taps submit → Existing loading state activates
2. Intent detection runs (0-500ms) → Same UI as note categorization
3. Result received → Route based on intent OR continue to note flow
4. Note flow → Loading continues through categorization (existing)
5. Chat flow → Loading stops, navigate to chat
6. Timeout/Error → Existing error handling, default to note

### Alternatives Considered
- **Separate loading state for intent**: Rejected - unnecessary duplication when existing state works
- **Different visual indicator**: Rejected - consistent UX is better
- **No loading indicator**: Rejected - user needs feedback during blocking operation

---

## Summary of Decisions

| Research Area | Decision | Key Rationale |
|--------------|----------|---------------|
| Intent Detection Model | GPT-5-nano via existing AiService | Fast, lightweight, infrastructure ready |
| Chat Backend | Reuse existing ChatCubit + AiService | Full streaming support, vector store integrated |
| Full-Screen Navigation | MaterialPageRoute with fullscreenDialog | Standard Flutter pattern, iOS-friendly |
| Ambiguity Dialog | AlertDialog with binary choice | Clear, accessible, blocking UI flow |
| Loading State | Reuse existing AI analysis loader | Consistent UX, no new UI code needed |

## Integration Architecture

```
User Input (Unified Text Field)
    ↓
Intent Detection (GPT-5-nano, <500ms)
    ↓
    ├─→ "note" → Existing note-logging flow
    ├─→ "chat" → Navigator.push(FullscreenChatPage)
    └─→ "ambiguous" → Show IntentClarificationDialog
            ├─→ User selects "Note" → Note-logging flow
            └─→ User selects "Chat" → Navigator.push(FullscreenChatPage)

FullscreenChatPage
    ↓
ChatCubit (existing)
    ↓
AiService.streamChatResponse() (existing)
    ↓
Vector Store Search (existing) → Chat Response
```

## No Additional Dependencies Required
All functionality implementable with:
- ✅ Existing `flutter_bloc`, `get_it`, `equatable`
- ✅ Existing `AiService` infrastructure
- ✅ Existing `ChatCubit` and `ChatMessage` models
- ✅ Standard Flutter widgets (MaterialPageRoute, AlertDialog, TextField)

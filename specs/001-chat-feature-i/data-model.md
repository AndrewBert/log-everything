# Data Model: Unified Text Field with Chat Intent Detection

**Feature**: 001-chat-feature-i
**Date**: 2025-10-05

## Entity Definitions

### 1. IntentType (Enum)
**Location**: `lib/intent_detection/models/intent_type.dart`

```dart
enum IntentType {
  note,       // User wants to log a note
  chat,       // User wants to start a chat
  ambiguous,  // AI cannot determine intent with confidence
}
```

**Purpose**: Represents the three possible intent classifications from AI analysis.

**Validation Rules**:
- Must be one of the three enum values
- No null values allowed

---

### 2. IntentClassification (Model)
**Location**: `lib/intent_detection/models/intent_classification.dart`

```dart
class IntentClassification extends Equatable {
  final IntentType type;
  final double confidence;
  final DateTime timestamp;

  const IntentClassification({
    required this.type,
    required this.confidence,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [type, confidence, timestamp];
}
```

**Fields**:
- `type`: The determined intent (note/chat/ambiguous)
- `confidence`: AI confidence score (0.0 to 1.0)
- `timestamp`: When classification was performed

**Validation Rules**:
- `confidence`: Must be between 0.0 and 1.0 inclusive
- `type` = `ambiguous` when `confidence < 0.7`
- `timestamp`: Must not be in the future

**Relationships**:
- Produced by `IntentDetectionService`
- Consumed by `DashboardV2Cubit` to route user input

---

### 3. ChatMessage (Existing Model - No Changes)
**Location**: `lib/chat/model/chat_message.dart`

```dart
class ChatMessage extends Equatable {
  final String id;
  final String text;
  final ChatSender sender;  // enum: user, ai
  final DateTime timestamp;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.sender,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [id, text, sender, timestamp];
}
```

**Usage in Feature**:
- Initial query displayed as first message in chat (sender: user)
- AI responses appended to conversation (sender: ai)
- Persisted via OpenAI API (not local storage)

**No Modifications Required**: Existing model supports all feature requirements.

---

### 4. ChatState (Existing - Minor Extension)
**Location**: `lib/chat/cubit/chat_state.dart`

**Current Fields** (existing):
```dart
class ChatState extends Equatable {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? lastResponseId;
  final String? streamingMessageId;
  // ...
}
```

**Potential Addition** (if initial query needs tracking):
```dart
class ChatState extends Equatable {
  // ... existing fields ...
  final String? initialQuery;  // Optional: track the query that started the chat

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.lastResponseId,
    this.streamingMessageId,
    this.initialQuery,  // New field
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? lastResponseId,
    String? streamingMessageId,
    String? initialQuery,
    bool clearStreamingMessageId = false,
    bool clearInitialQuery = false,  // New parameter
  }) {
    // ... implementation ...
  }
}
```

**Decision**: Defer this addition to implementation phase. Current state may be sufficient if initial query is added as first ChatMessage.

---

### 5. DashboardV2State (Existing - Extension Required)
**Location**: `lib/dashboard_v2/cubit/dashboard_v2_state.dart`

**Required Extension**:
```dart
class DashboardV2State extends Equatable {
  // ... existing fields (insights, entries, etc.) ...

  // NEW: Intent detection fields
  final bool isClassifyingIntent;
  final IntentClassification? lastIntentClassification;
  final String? intentClassificationError;

  const DashboardV2State({
    // ... existing parameters ...
    this.isClassifyingIntent = false,
    this.lastIntentClassification,
    this.intentClassificationError,
  });

  DashboardV2State copyWith({
    // ... existing parameters ...
    bool? isClassifyingIntent,
    IntentClassification? lastIntentClassification,
    String? intentClassificationError,
    bool clearLastIntentClassification = false,
    bool clearIntentClassificationError = false,
  }) {
    // ... implementation ...
  }

  @override
  List<Object?> get props => [
    // ... existing props ...
    isClassifyingIntent,
    lastIntentClassification,
    intentClassificationError,
  ];
}
```

**Field Purpose**:
- `isClassifyingIntent`: Triggers loading UI in unified text field
- `lastIntentClassification`: Stores result for routing decision
- `intentClassificationError`: Displays error if classification fails

---

## State Transitions

### Intent Detection Flow
```
1. User submits text
   ↓
2. DashboardV2State: isClassifyingIntent = true
   ↓
3. IntentDetectionService.classifyIntent(text)
   ↓
4a. Success → DashboardV2State: lastIntentClassification = result, isClassifyingIntent = false
4b. Error → DashboardV2State: intentClassificationError = message, isClassifyingIntent = false
   ↓
5. Route based on IntentType:
   - note → Existing note-logging flow
   - chat → Navigate to FullscreenChatPage
   - ambiguous → Show IntentClarificationDialog
```

### Chat Session Flow
```
1. Chat intent detected (or user selects "Start Chat")
   ↓
2. Navigator.push(FullscreenChatPage)
   ↓
3. ChatCubit.startChatWithQuery(userInput)
   ↓
4. ChatState: messages = [userMessage], isLoading = true
   ↓
5. ChatCubit.addUserMessageStreaming(userInput)
   ↓
6. Stream<ChatStreamEvent> from AiService
   ↓
7. ChatState: messages updated with AI response, isLoading = false
   ↓
8. User asks follow-up → Repeat steps 5-7
   ↓
9. User closes chat → Navigator.pop()
   ↓
10. ChatState persists in OpenAI (previous_response_id chaining)
```

---

## Persistence Strategy

### Local Storage (SharedPreferences)
- **Not Used**: Per clarification, chat history retrieved from OpenAI API
- **Intent Classification**: Ephemeral, not persisted (only used for routing)
- **Dashboard State**: Existing entry persistence unchanged

### Remote Storage (OpenAI API)
- **Chat Sessions**:
  - `store: true` parameter in `getChatResponse()` / `streamChatResponse()`
  - `previous_response_id` chains conversations across app restarts
  - Retrieved via API when user reopens chat

- **Vector Store**:
  - Existing `openai_vector_store_id` from SharedPreferences
  - Used for File Search during chat responses
  - No changes required

---

## Data Flow Diagram

```
User Input (Text Field)
    ↓
IntentDetectionService.classifyIntent()
    ↓
IntentClassification { type, confidence, timestamp }
    ↓
    ├─→ type = note → DashboardV2Cubit.addEntry()
    │                      ↓
    │                  Entry saved to SharedPreferences
    │
    ├─→ type = chat → Navigator.push(FullscreenChatPage)
    │                      ↓
    │                  ChatCubit.startChatWithQuery(text)
    │                      ↓
    │                  ChatState { messages: [userMessage], isLoading: true }
    │                      ↓
    │                  AiService.streamChatResponse()
    │                      ↓
    │                  ChatState { messages: [userMessage, aiMessage] }
    │                      ↓
    │                  Session persisted to OpenAI (store: true)
    │
    └─→ type = ambiguous → show IntentClarificationDialog
                               ↓
                           User selects → Restart flow with chosen intent
```

---

## Validation Summary

| Entity | Key Validations | Error Handling |
|--------|----------------|----------------|
| IntentType | Must be valid enum value | Compile-time check |
| IntentClassification | confidence ∈ [0.0, 1.0] | Service validates |
| ChatMessage | id is unique UUID | Cubit generates |
| ChatState | messages list not null | Default to empty list |
| DashboardV2State | intent fields nullable | Null = no active classification |

---

## Migration Notes

**No Database Migration Required**:
- New models are ephemeral (IntentClassification)
- Chat persistence handled by OpenAI API
- Existing SharedPreferences schema unchanged
- No breaking changes to existing data structures

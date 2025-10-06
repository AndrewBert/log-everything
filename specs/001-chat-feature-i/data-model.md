# Data Model: Unified Text Field with Chat Intent Detection

**Feature**: 001-chat-feature-i
**Date**: 2025-10-05

## Overview
This document defines the data entities for the dual-mode text field feature, including intent classification models and chat-related extensions.

---

## 1. IntentType (Enum)

**Purpose**: Represents the three possible intent classifications for user input.

**Values**:
- `note` - User input should be logged as an entry
- `chat` - User input should trigger a chat session
- `ambiguous` - Intent cannot be confidently determined

**File Location**: `lib/intent_detection/models/intent_type.dart`

**Implementation**:
```dart
enum IntentType {
  note,
  chat,
  ambiguous,
}
```

**Usage**:
```dart
if (classification.type == IntentType.chat) {
  // Navigate to full-screen chat
}
```

---

## 2. IntentClassification (Model)

**Purpose**: Represents the AI's classification result for a given user input.

**Fields**:
| Field | Type | Required | Description | Validation |
|-------|------|----------|-------------|------------|
| `type` | `IntentType` | Yes | The classified intent (note/chat/ambiguous) | Must be valid enum value |
| `confidence` | `double` | Yes | AI's confidence score | Must be 0.0 ≤ confidence ≤ 1.0 |
| `timestamp` | `DateTime` | Yes | When classification occurred | Non-null |

**File Location**: `lib/intent_detection/models/intent_classification.dart`

**Immutability**: Immutable value object (extends Equatable)

**Validation Rules**:
- Confidence must be in range [0.0, 1.0]
- Confidence < 0.7 → treat as ambiguous regardless of `type`

**Implementation**:
```dart
import 'package:equatable/equatable.dart';
import 'intent_type.dart';

class IntentClassification extends Equatable {
  final IntentType type;
  final double confidence;
  final DateTime timestamp;

  const IntentClassification({
    required this.type,
    required this.confidence,
    required this.timestamp,
  }) : assert(confidence >= 0.0 && confidence <= 1.0, 'Confidence must be between 0.0 and 1.0');

  @override
  List<Object?> get props => [type, confidence, timestamp];
}
```

**Lifecycle**: Ephemeral - not persisted, only used during intent detection flow

---

## 3. DashboardV2State Extensions

**Purpose**: Extend existing `DashboardV2State` to track intent classification status.

**New Fields**:
| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `isClassifyingIntent` | `bool` | `false` | True when AI classification is in progress |
| `lastIntentClassification` | `IntentClassification?` | `null` | Most recent classification result |
| `intentClassificationError` | `String?` | `null` | Error message if classification fails |

**File Location**: `lib/dashboard_v2/cubit/dashboard_v2_state.dart` (existing file)

**State Transitions**:
```
Initial State (isClassifyingIntent: false)
  ↓ (user submits text)
Classifying State (isClassifyingIntent: true)
  ↓ (classification complete)
Success State (lastIntentClassification: result, isClassifyingIntent: false)
  OR
Error State (intentClassificationError: message, isClassifyingIntent: false)
```

**copyWith Additions**:
```dart
DashboardV2State copyWith({
  bool? isClassifyingIntent,
  IntentClassification? lastIntentClassification,
  String? intentClassificationError,
  bool clearLastIntentClassification = false,  // Explicit null setter
  bool clearIntentClassificationError = false,  // Explicit null setter
  // ... existing parameters
}) {
  return DashboardV2State(
    isClassifyingIntent: isClassifyingIntent ?? this.isClassifyingIntent,
    lastIntentClassification: clearLastIntentClassification
        ? null
        : (lastIntentClassification ?? this.lastIntentClassification),
    intentClassificationError: clearIntentClassificationError
        ? null
        : (intentClassificationError ?? this.intentClassificationError),
    // ... existing fields
  );
}
```

---

## 4. ChatMessage (Existing Model)

**Purpose**: Represents a single message in a chat conversation.

**File Location**: `lib/chat/model/chat_message.dart` (existing)

**Fields** (no changes needed):
- `id`: String (UUID)
- `text`: String (message content)
- `sender`: ChatSender (user or ai)
- `timestamp`: DateTime

**Usage in This Feature**:
- Initial query message created with `ChatMessage(text: userQuery, sender: ChatSender.user)`
- AI responses appended to `ChatState.messages` list
- Displayed in FullscreenChatPage's ListView

---

## 5. ChatState Extensions

**Purpose**: Existing `ChatState` already supports this feature without modifications.

**Existing Fields Used**:
| Field | Type | Usage in This Feature |
|-------|------|----------------------|
| `messages` | `List<ChatMessage>` | Stores conversation history including initial query |
| `isLoading` | `bool` | Shows loading state while AI generates response |
| `lastResponseId` | `String?` | Chains conversation across app restarts |
| `streamingMessageId` | `String?` | Tracks which message is currently streaming |

**File Location**: `lib/chat/cubit/chat_state.dart` (existing)

**No Changes Required**: Existing fields cover all chat persistence and streaming needs.

---

## 6. FloatingInputBar State Extensions

**Purpose**: Extend existing widget state to handle intent classification feedback.

**File Location**: `lib/dashboard_v2/widgets/floating_input_bar.dart` (existing, StatefulWidget)

**Existing State Used**:
- `_isSubmitting` → repurposed to read `DashboardV2State.isClassifyingIntent`
- `_textController` → source of user input to classify
- Loading indicator pattern → reused for classification feedback

**No New State Fields**: All state managed in `DashboardV2State` (BLoC pattern)

---

## Entity Relationships

```
User Input (String, max 2000 chars)
    ↓
IntentClassification
    ├─ type: IntentType.note → Log Entry Flow (existing)
    ├─ type: IntentType.chat → ChatState.messages (new initial message)
    └─ type: IntentType.ambiguous → IntentClarificationDialog → User Choice
                                      ├─ "Note" → Log Entry Flow
                                      └─ "Chat" → ChatState.messages

ChatState.messages (List<ChatMessage>)
    ├─ Persisted via OpenAI lastResponseId
    └─ Displayed in FullscreenChatPage
```

---

## Persistence Strategy

| Entity | Storage | Lifetime | Retrieval |
|--------|---------|----------|-----------|
| `IntentClassification` | None (ephemeral) | Single request cycle | N/A |
| `ChatState.messages` | OpenAI servers (via responseId) | Indefinite | Via `lastResponseId` parameter |
| `DashboardV2State` | In-memory (BLoC) | App session | N/A |

**Note**: No local storage (SharedPreferences) needed for this feature per spec requirements.

---

## Validation Summary

| Model | Validation Rule | Error Handling |
|-------|----------------|----------------|
| `IntentClassification` | 0.0 ≤ confidence ≤ 1.0 | Assert in constructor |
| `IntentClassification` | confidence < 0.7 | Treat as ambiguous (business logic) |
| User Input | length ≤ 2000 chars | TextField maxLength enforcement |
| User Input | Non-empty, non-whitespace | Submit button disabled |

---

## Next Steps
- Phase 1 continues: Create contracts/, quickstart.md, update CLAUDE.md
- Phase 2 (via /tasks): Generate implementation tasks from this data model

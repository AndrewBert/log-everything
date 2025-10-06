# Research: Unified Text Field with Chat Intent Detection

**Feature**: 001-chat-feature-i
**Date**: 2025-10-05
**Status**: Complete

## Research Findings

### 1. GPT-5-nano Integration for Intent Classification

**Decision**: Use GPT-5-nano via OpenAI Responses API with structured JSON output for binary classification

**Rationale**:
- GPT-5-nano is optimized for fast, lightweight tasks like intent classification
- Structured JSON output ensures consistent parsing ({"intent": "note"|"chat"|"ambiguous", "confidence": 0.0-1.0})
- Sub-500ms latency requirement aligns with model's capabilities
- Existing `AiService` already handles OpenAI API authentication and error patterns

**Implementation Pattern**:
```dart
// Prompt template for intent detection
final systemPrompt = '''You are an intent classifier for a personal logging app.
Classify user input as either:
- "note": A statement to be logged (observations, activities, thoughts)
- "chat": A question about past logs (queries, requests for information)
- "ambiguous": Cannot confidently determine intent

Respond with JSON: {"intent": "note"|"chat"|"ambiguous", "confidence": 0.0-1.0}

Examples:
Input: "Had coffee with Sarah" → {"intent": "note", "confidence": 0.95}
Input: "When did I last have coffee?" → {"intent": "chat", "confidence": 0.92}
Input: "Coffee" → {"intent": "ambiguous", "confidence": 0.45}
''';

// API call structure
final response = await http.post(
  Uri.parse('https://api.openai.com/v1/chat/completions'),
  headers: {'Authorization': 'Bearer $apiKey', 'Content-Type': 'application/json'},
  body: jsonEncode({
    'model': 'gpt-5-nano',
    'messages': [
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': userInput},
    ],
    'temperature': 0.3, // Low temperature for consistent classification
    'max_tokens': 50, // Small response for efficiency
  }),
);
```

**Error Handling**:
- Timeout after 2 seconds → default to note-logging mode
- Confidence < 0.7 → treat as ambiguous, show clarification dialog
- API errors (401, 429, 500) → default to note-logging mode

**Alternatives Considered**:
- Local ML model (TensorFlow Lite): Rejected due to larger app size and lower accuracy
- Keyword matching: Rejected as per user clarification - AI-only classification required
- GPT-4o: Rejected due to higher latency (>500ms typical) and cost

---

### 2. Existing Chat Backend Analysis

**Decision**: Reuse existing `ChatCubit` and `AiService.streamChatResponse()` without modifications

**Rationale**:
- `ChatCubit` already implements full chat lifecycle:
  - Message history management (`state.messages`)
  - AI response streaming (`addUserMessageStreaming()`)
  - Response chaining (`state.lastResponseId`)
  - Error handling with user-friendly messages
- `AiService` provides:
  - Vector store search integration (searches user logs automatically)
  - Server-sent events (SSE) streaming for real-time responses
  - Conversation persistence via OpenAI's response IDs
- No backend changes needed - only frontend routing/UI updates required

**Reusable Components**:
1. `ChatMessage` model (lib/chat/model/chat_message.dart) - already handles user/AI messages
2. `ChatState.messages` - conversation history
3. `ChatState.lastResponseId` - maintains conversation context across sessions
4. `AiService.streamChatResponse()` - streams AI responses with SSE
5. `ChatSender` enum (user, ai) - message attribution

**Required Frontend Additions**:
- New method: `ChatCubit.startChatWithQuery(String initialQuery)`:
  - Creates initial user message
  - Calls `addUserMessageStreaming()` to trigger AI response
  - Emits state with `isLoading = true` during classification
- Full-screen chat page to display `ChatState.messages` list

**Chat History Persistence**:
- Already implemented via OpenAI's `previousResponseId` parameter
- Each response gets a unique ID from OpenAI servers
- On app restart, previous `lastResponseId` is passed to chain conversation
- No local storage needed (per spec clarification)

**Alternatives Considered**:
- Creating new `IntentChatCubit`: Rejected due to duplication with existing ChatCubit
- Local chat history storage: Rejected per spec clarification (retrieve from OpenAI only)

---

### 3. Full-Screen Chat UI Patterns in Flutter

**Decision**: Use `MaterialPageRoute` with `fullscreenDialog: true` for iOS-style modal presentation

**Rationale**:
- `fullscreenDialog: true` provides native iOS modal behavior:
  - Slides up from bottom
  - Automatic "Close" button in AppBar
  - Back gesture support
- Maintains Flutter navigation stack for state preservation
- Simpler than custom transitions or bottom sheets

**Implementation Pattern**:
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (context) => BlocProvider(
      create: (context) {
        final chatCubit = ChatCubit(aiService: getIt<AiService>());
        chatCubit.startChatWithQuery(initialQuery); // Trigger first response
        return chatCubit;
      },
      child: FullscreenChatPage(),
    ),
  ),
);
```

**Passing Initial Query**:
- Create new `ChatCubit` instance in route's `BlocProvider.create()`
- Call `chatCubit.startChatWithQuery(initialQuery)` immediately after creation
- Initial query appears as first user message in chat history
- AI response streams immediately (per spec requirement)

**Back Navigation**:
- Automatic via AppBar's back button (iOS close button)
- Returns to dashboard with unified text field ready for new input
- Chat state disposed when route pops (fresh state on next chat)

**Alternatives Considered**:
- BottomSheet: Rejected due to limited screen space for conversation
- Custom route transition: Rejected for unnecessary complexity
- Persistent chat state: Rejected per spec (fresh chat on each trigger)

---

### 4. Intent Ambiguity UX Patterns

**Decision**: Use `AlertDialog` with two action buttons for binary choice

**Rationale**:
- `AlertDialog` is familiar, accessible, and blocks background interaction (per spec requirement)
- Two clear action buttons match the binary choice (note vs chat)
- Built-in accessibility support (VoiceOver, TalkBack)
- Lightweight compared to `BottomSheet` or custom modals

**Implementation Pattern**:
```dart
void _showIntentClarificationDialog(BuildContext context, String userInput) {
  showDialog(
    context: context,
    barrierDismissible: false, // Force user to make a choice
    builder: (context) => AlertDialog(
      title: const Text('What would you like to do?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your input is:'),
          const SizedBox(height: 8),
          Text(
            '"$userInput"',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          const Text('Would you like to log this as a note or start a chat?'),
        ],
      ),
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.edit_note),
          label: const Text('Log as Note'),
          onPressed: () {
            Navigator.pop(context);
            // Process as note
            context.read<DashboardV2Cubit>().logAsNote(userInput);
          },
        ),
        TextButton.icon(
          icon: const Icon(Icons.chat_bubble_outline),
          label: const Text('Start Chat'),
          onPressed: () {
            Navigator.pop(context);
            // Navigate to chat
            context.read<DashboardV2Cubit>().navigateToChat(context, userInput);
          },
        ),
      ],
    ),
  );
}
```

**Accessibility Considerations**:
- Icon + label buttons for visual + semantic clarity
- VoiceOver reads title, content, and button labels in order
- Keyboard navigation supported by default
- High contrast mode compatible

**Alternatives Considered**:
- BottomSheet: Rejected due to accidental dismissal risk
- Custom modal: Rejected for unnecessary complexity and accessibility burden
- Inline toggle: Rejected per spec (always AI classification first)

---

### 5. Loading State Management During Intent Detection

**Decision**: Reuse existing `FloatingInputBar` loading indicator pattern + disabled TextField

**Rationale**:
- `FloatingInputBar` (lib/dashboard_v2/widgets/floating_input_bar.dart) already has `_isSubmitting` state
- Pattern: CircularProgressIndicator in suffix + disabled TextField during async operations
- Matches existing voice input loading UX (consistent user experience)
- No new UI components needed

**Implementation Pattern**:
```dart
// In DashboardV2State:
final class DashboardV2State extends Equatable {
  final bool isClassifyingIntent; // NEW field
  final IntentClassification? lastIntentClassification; // NEW field
  final String? intentClassificationError; // NEW field
  // ... existing fields
}

// In FloatingInputBar widget:
BlocBuilder<DashboardV2Cubit, DashboardV2State>(
  builder: (context, state) {
    return TextField(
      enabled: !state.isClassifyingIntent, // Disable during classification
      decoration: InputDecoration(
        suffixIcon: state.isClassifyingIntent
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.send),
      ),
      onSubmitted: (text) {
        context.read<DashboardV2Cubit>().handleUserInput(text, context);
      },
    );
  },
)
```

**Visual Feedback Sequence**:
1. User types text and presses submit
2. TextField becomes disabled (grey text cursor disappears)
3. Send icon replaced with small CircularProgressIndicator
4. Intent classification completes (<500ms)
5. Either:
   - Navigate to chat (if chat intent)
   - Log as note (if note intent, field clears and re-enables)
   - Show clarification dialog (if ambiguous)

**Timeout Handling**:
- If classification exceeds 2 seconds, show error snackbar
- Default to note-logging mode (fail-safe per spec)
- Re-enable TextField for retry

**Alternatives Considered**:
- Full-screen loading overlay: Rejected as too intrusive for <500ms operation
- Progress bar: Rejected as circular indicator is simpler and matches existing patterns
- Skeleton loader: Rejected as TextField state is already clear indicator

---

## Summary of Key Decisions

| Area | Decision | Justification |
|------|----------|---------------|
| Intent Model | GPT-5-nano via OpenAI API | Fast (<500ms), accurate, JSON output, existing auth |
| Chat Backend | Reuse ChatCubit + AiService | Already implements full chat lifecycle, no changes needed |
| Chat UI | MaterialPageRoute fullscreenDialog | Native iOS modal, automatic back button, simple routing |
| Ambiguity UX | AlertDialog with 2 buttons | Accessible, blocks interaction, familiar pattern |
| Loading State | Existing FloatingInputBar pattern | Consistent with voice input UX, no new components |

## Open Questions (Resolved in Spec)
- ✅ Character limit: 2000 characters maximum
- ✅ Empty input handling: Submit button disabled for whitespace
- ✅ Empty log history: Chat still works, AI responds without log context
- ✅ Vector store timeout: AI shows error message in chat
- ✅ Visual feedback: Reuse existing loading indicator + disabled field
- ✅ Keyword triggers: None - AI-only classification
- ✅ Log attribution: No - AI responses without explicit log references

## Next Phase
Phase 1: Design & Contracts (data-model.md, contracts/, quickstart.md, CLAUDE.md update)

# OpenAI Responses API Streaming Implementation Plan

## Overview
This document outlines the phased implementation plan for migrating from the synchronous OpenAI Responses API to streaming responses using server-sent events (SSE).

## Implementation Phases

### Phase 1: Create streaming event models and update AI service interface ✅
**Status:** Completed

**Changes made:**
- Created `ChatStreamEvent` sealed class with three variants:
  - `ChatStreamDelta(String text)` - for incremental text updates
  - `ChatStreamCompleted(String fullText, String? responseId)` - for completion
  - `ChatStreamError(String message)` - for error handling
- Added `streamChatResponse()` method to `AiService` interface
- Added stub implementation in `OpenAiService`

**Testing:**
- Run `flutter analyze` to ensure code compiles ✅
- Verify that existing functionality still works

### Phase 2: Implement SSE parser utility ✅
**Status:** Completed

**Changes made:**
- Created `lib/utils/sse_parser.dart` with full SSE parsing logic
- Handles partial chunks and buffering correctly
- Parses all SSE event types including OpenAI-specific events
- Supports JSON data parsing
- Created comprehensive unit tests (12 test cases)

**Testing:**
- Unit tests cover various SSE formats ✅
- Handles partial chunks correctly ✅
- Processes OpenAI response format ✅

### Phase 3: Implement streamChatResponse in OpenAiService ✅
**Status:** Completed

**Changes made:**
- Implemented full streaming support with `stream: true`
- Uses `http.Request` for streaming response
- Integrates SSE parser for event processing
- Handles all OpenAI event types
- Accumulates text deltas and emits appropriate events
- Error handling for HTTP and streaming errors

**Testing:**
- Code compiles without errors ✅
- Ready for integration testing

### Phase 4: Add basic streaming support to ChatCubit ✅
**Status:** Completed

**Changes made:**
- Added `addUserMessageStreaming()` method
- Creates AI message placeholder that updates in real-time
- Updates `ChatState` with `streamingMessageId` field
- Accumulates text deltas with console logging
- Handles completion, errors, and partial responses
- Updates `lastResponseId` on completion

**Testing:**
- Code compiles without errors ✅
- Console logging added for debugging
- State management properly handles streaming updates

### Phase 5: Integrate streaming into chat UI ✅
**Status:** Completed

**Changes made:**
- Updated `InputArea` to use `addUserMessageStreaming()` for chat messages
- Modified "Thinking..." indicator to only show before first delta arrives
- Added streaming cursor animation for active streaming messages
- Updated scroll behavior to continuously scroll during streaming
- Added `_shouldShowThinkingIndicator()` helper method
- Added `_buildStreamingCursor()` with blinking animation

**Testing:**
- Created `test_streaming.dart` for manual testing
- UI updates in real-time as deltas arrive
- Blinking cursor shows for streaming messages
- Auto-scroll works during streaming

### Phase 6: Add comprehensive error handling
**Status:** Pending

**Tasks:**
- Handle network disconnections
- Implement retry logic for failed streams
- Preserve partial responses on error
- Add timeout handling
- Implement stream cancellation

**Testing:**
- Test with network interruptions
- Verify partial responses are preserved
- Test timeout scenarios
- Verify proper cleanup on cancellation

### Phase 7: Add UI polish
**Status:** Pending

**Tasks:**
- Add typing indicator or cursor animation
- Implement smooth text reveal animations
- Add visual feedback for streaming state
- Optimize performance for long responses
- Add haptic feedback on stream events (mobile)

**Testing:**
- Visual smoothness and performance
- User experience testing
- Performance profiling for long responses

## Technical Details

### SSE Event Format
The OpenAI Responses API emits events in the following format:
```
event: response.output_text.delta
data: {"type": "response.output_text.delta", "delta": "Hello", ...}

event: response.completed
data: {"type": "response.completed", "response": {...}, ...}
```

### Key Events to Handle
1. `response.created` - Stream initialized
2. `response.output_text.delta` - Text chunk received
3. `response.completed` - Stream finished successfully
4. `response.failed` - Stream encountered an error
5. `error` - General error event

### API Request Changes
```dart
// Current (non-streaming)
final requestBody = {
  'model': _chatModelId,
  'input': [...],
  'stream': false, // or omitted
};

// New (streaming)
final requestBody = {
  'model': _chatModelId,
  'input': [...],
  'stream': true,
};
```

## Benefits
- **Improved UX:** Users see responses as they're generated
- **Reduced perceived latency:** First text appears quickly
- **Better feedback:** Users know the system is working
- **Graceful degradation:** Can show partial responses on error

## Risks and Mitigations
- **Risk:** SSE parsing complexity
  - **Mitigation:** Comprehensive unit tests and error handling
- **Risk:** UI performance with rapid updates
  - **Mitigation:** Debounce UI updates if needed
- **Risk:** Network reliability issues
  - **Mitigation:** Implement retry logic and error recovery

## Success Criteria
- All existing tests pass
- Streaming responses appear character-by-character or in small chunks
- Error handling is robust and user-friendly
- Performance is acceptable even for long responses
- User experience is smooth and responsive
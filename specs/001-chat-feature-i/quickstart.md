# Quickstart: Unified Text Field with Chat Intent Detection

**Feature**: 001-chat-feature-i
**Date**: 2025-10-05
**Status**: Ready for Implementation

## Purpose
This document provides manual test scenarios for validating the dual-mode text field feature. All testing is user-led per the constitution (no automated tests).

---

## Prerequisites

1. **Environment Setup**:
   - `.env` file in repository root with valid `OPENAI_API_KEY`
   - Flutter app running on iOS simulator or device
   - OpenAI account with GPT-5-nano access and API credits

2. **Build & Run**:
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

3. **Navigate to Dashboard**:
   - App should open to Dashboard V2 page
   - Floating input bar visible at bottom of screen

---

## Scenario 1: Log a Note (Intent: Note)

**Objective**: Verify that note-like input is classified correctly and logged as an entry.

### Steps:
1. Type in text field: `"Had lunch at Thai restaurant with Sarah"`
2. Press submit (send icon or enter key)
3. Observe loading indicator appears in text field suffix
4. Wait for classification (<500ms expected)

### Expected Results:
- ✅ Text field disables during classification
- ✅ Send icon replaced with CircularProgressIndicator
- ✅ Classification completes in <500ms
- ✅ Entry is logged in dashboard (no chat opens)
- ✅ Text field clears and re-enables
- ✅ New entry appears in recent entries carousel with "Thai restaurant" in text

### Variations to Test:
- `"Feeling great today"` → should log
- `"Worked out for 30 minutes"` → should log
- `"Coffee with John at 3pm"` → should log

---

## Scenario 2: Start a Chat (Intent: Chat)

**Objective**: Verify that question-like input triggers full-screen chat with AI response.

### Steps:
1. Type in text field: `"When was the last time I went to a Thai restaurant?"`
2. Press submit
3. Observe loading indicator

### Expected Results:
- ✅ Text field disables during classification
- ✅ Classification completes in <500ms
- ✅ Full-screen chat page opens (modal transition from bottom)
- ✅ AppBar shows "Close" button (iOS style)
- ✅ Initial query appears as first message: `"When was the last time I went to a Thai restaurant?"`
- ✅ AI response streams in below query (typewriter effect)
- ✅ AI searches user logs and provides relevant answer
- ✅ If no Thai restaurant logs exist, AI says it couldn't find relevant entries

### Variations to Test:
- `"What restaurants have I been to this month?"` → should open chat
- `"Show me my workouts"` → should open chat
- `"When did I last have coffee?"` → should open chat

---

## Scenario 3: Ambiguous Input (Low Confidence)

**Objective**: Verify that ambiguous input triggers clarification dialog.

### Steps:
1. Type in text field: `"Coffee"`
2. Press submit
3. Wait for classification

### Expected Results:
- ✅ Classification completes (may take up to 2s)
- ✅ AlertDialog appears with title "What would you like to do?"
- ✅ Dialog shows user's input: `"Coffee"`
- ✅ Two action buttons visible:
  - "Log as Note" (with edit icon)
  - "Start Chat" (with chat icon)
- ✅ Dialog cannot be dismissed by tapping outside (barrierDismissible: false)

#### If User Selects "Log as Note":
- ✅ Dialog closes
- ✅ Entry logged with text "Coffee"
- ✅ Text field clears

#### If User Selects "Start Chat":
- ✅ Dialog closes
- ✅ Full-screen chat opens
- ✅ First message is "Coffee"
- ✅ AI responds (may indicate query is unclear)

### Variations to Test:
- `"Meeting"` → likely ambiguous
- `"Tomorrow"` → likely ambiguous
- `"Gym"` → likely ambiguous

---

## Scenario 4: Chat Follow-Up Questions

**Objective**: Verify that conversation context persists within a chat session.

### Steps:
1. Start chat with: `"Show me my workouts this month"`
2. Wait for AI response
3. In chat text field, type: `"Which day did I work out the most?"`
4. Submit follow-up question

### Expected Results:
- ✅ First AI response provides workout summary
- ✅ Follow-up question added to conversation
- ✅ AI response maintains context (knows "workouts this month")
- ✅ No need to repeat "workouts" - context understood

---

## Scenario 5: Chat Session Persistence Across Restarts

**Objective**: Verify chat history is retrieved from OpenAI after app restart.

### Steps:
1. Start chat with: `"What restaurants have I been to?"`
2. Wait for AI response
3. Ask follow-up: `"Which was my favorite?"`
4. Wait for response
5. Close chat page (tap Close button)
6. **Force quit app** (swipe up from app switcher)
7. Reopen app
8. Start new chat with any query

### Expected Results:
- ✅ Previous chat session data is NOT visible in new session (fresh state per spec)
- ✅ Each chat session is independent
- ✅ Conversation context persists **within a session** but not **across sessions**

**Note**: Per spec clarification, chat history persistence refers to OpenAI's server-side storage for maintaining context during a session, not user-visible history across sessions.

---

## Scenario 6: Intent Detection Failure Fallback

**Objective**: Verify graceful degradation when intent detection service is unavailable.

### Steps:
1. **Simulate failure**: Temporarily disable network OR modify API key in `.env` to invalid value
2. Type in text field: `"Test entry during API failure"`
3. Press submit
4. Observe behavior

### Expected Results:
- ✅ Loading indicator appears
- ✅ Classification attempt times out after 2 seconds (or fails immediately)
- ✅ **Entry is logged as a note** (fail-safe default)
- ✅ Text field clears
- ✅ Optional: SnackBar shows error message ("Intent detection unavailable, logged as note")
- ✅ User can continue using app in note-logging mode

### Restore After Test:
- Re-enable network or restore valid API key in `.env`

---

## Scenario 7: Empty/Whitespace Input Handling

**Objective**: Verify that empty or whitespace-only input is rejected.

### Steps:
1. Focus text field (tap to activate)
2. **Do not type anything** - leave empty
3. Observe submit button state
4. Try typing only spaces: `"     "`
5. Observe submit button state

### Expected Results:
- ✅ Submit button (send icon) is disabled when field is empty
- ✅ Submit button remains disabled for whitespace-only input
- ✅ User cannot submit empty or whitespace input
- ✅ No classification attempt made

---

## Scenario 8: Character Limit Enforcement

**Objective**: Verify 2000 character maximum is enforced.

### Steps:
1. Paste or type a very long text (>2000 characters) into text field
2. Observe behavior

### Expected Results:
- ✅ TextField stops accepting input at 2000 characters
- ✅ Optional: Character counter shows "2000/2000"
- ✅ User cannot exceed limit
- ✅ Classification works normally for 2000-character input

---

## Scenario 9: Chat with Empty Log History

**Objective**: Verify chat works when user has no logged entries.

### Steps:
1. **Test with new user** OR **clear all entries** (if possible)
2. Start chat with: `"What did I log yesterday?"`
3. Wait for AI response

### Expected Results:
- ✅ Chat opens normally
- ✅ AI responds dynamically (not a predefined error)
- ✅ AI indicates no logs were found (e.g., "I couldn't find any entries from yesterday")
- ✅ User can ask follow-up questions

---

## Scenario 10: Vector Store Search Timeout

**Objective**: Verify graceful handling of slow/failed vector store search.

### Steps:
1. Start chat with complex query requiring log search
2. **Simulate slow network** or **vector store timeout** (if possible in dev environment)
3. Observe AI response

### Expected Results:
- ✅ Chat loads normally
- ✅ If vector store times out, AI shows message in chat: "I couldn't access your logs at this time. Please try again."
- ✅ User can retry by asking question again
- ✅ No app crash or frozen state

---

## Scenario 11: Rapid Successive Submissions

**Objective**: Verify UI handles rapid input submissions gracefully.

### Steps:
1. Type: `"First entry"`
2. Submit immediately
3. **Before classification completes**, type: `"Second entry"`
4. Submit again
5. Repeat for `"Third entry"`

### Expected Results:
- ✅ Text field remains disabled during classification
- ✅ User cannot submit second entry until first classification completes
- ✅ Submissions are processed sequentially (no race conditions)
- ✅ All entries are logged or chats opened correctly

---

## Performance Benchmarks

| Metric | Target | Measurement Method |
|--------|--------|-------------------|
| Intent classification latency | < 500ms (p95) | Stopwatch from submit to result |
| Chat response time | < 2s (first token) | Time to first AI message character |
| UI remains responsive during classification | Always | No frozen UI, animations continue |

### How to Measure:
1. **Classification latency**:
   - Start timer when pressing submit
   - Stop when loading indicator disappears
   - Average over 10 attempts
   - 95th percentile should be <500ms

2. **Chat response time**:
   - Start timer when chat page opens
   - Stop when first character of AI response appears
   - Should be <2s for most queries

---

## Accessibility Testing

### VoiceOver (iOS)

**Objective**: Verify screen reader compatibility.

### Steps:
1. Enable VoiceOver: Settings → Accessibility → VoiceOver
2. Navigate to app's text field
3. Type input using VoiceOver keyboard
4. Submit entry
5. If clarification dialog appears, navigate with VoiceOver

### Expected Results:
- ✅ Text field is announced: "Text input field"
- ✅ Submit button is announced: "Send" or "Submit"
- ✅ Loading state is announced: "Loading" or "Processing"
- ✅ Clarification dialog title and buttons are announced clearly
- ✅ Chat messages are readable in order with VoiceOver

---

## Edge Cases Checklist

- [ ] Special characters in input: `"Test @#$% entry"` → logs or classifies correctly
- [ ] Emoji in input: `"Great day 😊"` → logs or classifies correctly
- [ ] Very short input: `"A"` → likely ambiguous, shows dialog
- [ ] Very long input: 2000 characters → classifies and processes correctly
- [ ] Input with newlines: Multi-line text → preserved in logs/chat
- [ ] Network interruption mid-classification → defaults to note mode
- [ ] App backgrounded during classification → resumes correctly on foreground

---

## Success Criteria

**Feature is ready for user acceptance when:**
1. All 11 scenarios pass expected results
2. Performance benchmarks met (<500ms classification, <2s chat response)
3. VoiceOver accessibility works
4. No crashes or frozen states in edge cases
5. User experience feels seamless (minimal waiting, clear feedback)

---

## Known Limitations

Per spec clarifications:
- Chat history does NOT persist across app restarts (fresh session each time)
- Users cannot manually override AI classification (must use clarification dialog if ambiguous)
- Log attribution not shown in chat responses (AI answers without citing specific logs)

---

## Next Phase
After successful quickstart validation:
- Phase 2 (via /tasks): Generate implementation tasks
- Phase 3: Execute tasks per generated plan
- Phase 4: User validates all scenarios above

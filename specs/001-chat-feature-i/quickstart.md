# Quickstart: Manual Testing Guide

**Feature**: Unified Text Field with Chat Intent Detection
**Branch**: `001-chat-feature-i`
**Tester**: User (per constitution - user-led testing)

## Prerequisites

- [ ] Flutter app running on iOS device/simulator
- [ ] `.env` file configured with valid OpenAI API key
- [ ] Vector store ID present in SharedPreferences (for chat functionality)
- [ ] Existing log entries in the app (for meaningful chat queries)

## Test Scenarios

### Scenario 1: Log a Note (Note Intent Detection)

**Objective**: Verify that note-like input is correctly classified and logged.

**Steps**:
1. Open the app to the main dashboard
2. Tap the unified text field at the bottom
3. Type: `"Had lunch at Thai restaurant with Sarah"`
4. Tap submit/send button

**Expected Results**:
- [ ] Loading indicator appears in text field suffix (< 500ms)
- [ ] Text field is disabled during classification
- [ ] Intent detected as "note" (no dialog shown)
- [ ] Entry is added to the log with appropriate category
- [ ] Entry appears in the dashboard entries list
- [ ] Text field clears and re-enables for next input

**Edge Cases to Test**:
- Empty input → Should prevent submission
- Very long text (500+ characters) → Should handle gracefully
- Special characters/emojis → Should log correctly

---

### Scenario 2: Start a Chat (Chat Intent Detection)

**Objective**: Verify that question-like input opens the full-screen chat interface.

**Steps**:
1. From main dashboard, tap the unified text field
2. Type: `"When was the last time I went to a Thai restaurant?"`
3. Tap submit/send button

**Expected Results**:
- [ ] Loading indicator appears during classification
- [ ] Intent detected as "chat"
- [ ] Full-screen chat page opens with modal transition
- [ ] Original query appears as the first message (sender: user)
- [ ] AI response streams in with typewriter effect
- [ ] Response addresses the query by searching logs
- [ ] Chat history includes the conversation

**Navigation**:
- [ ] Back button in AppBar returns to dashboard
- [ ] Dashboard unified text field is ready for new input

---

### Scenario 3: Ambiguous Input (Clarification Dialog)

**Objective**: Verify that ambiguous input triggers the clarification dialog.

**Steps**:
1. From main dashboard, tap the unified text field
2. Type: `"Coffee"` (single word, could be note or query)
3. Tap submit/send button

**Expected Results**:
- [ ] Loading indicator appears
- [ ] Intent detected as "ambiguous" (confidence < 0.7)
- [ ] Clarification dialog appears with two options:
  - "Log as Note" button with icon
  - "Start Chat" button with icon
- [ ] User's input is displayed in dialog: `"Coffee"`

**User Selects "Log as Note"**:
- [ ] Dialog dismisses
- [ ] Entry is logged as a note
- [ ] Entry appears in dashboard

**User Selects "Start Chat"** (restart scenario):
- [ ] Dialog dismisses
- [ ] Full-screen chat opens
- [ ] "Coffee" appears as first message
- [ ] AI responds based on log search

---

### Scenario 4: Chat Follow-Up Questions

**Objective**: Verify conversation chaining and context preservation.

**Steps**:
1. Start a chat with query: `"Show me my workouts this month"`
2. Wait for AI response
3. Type follow-up: `"Which day did I work out the most?"`
4. Wait for response
5. Type another: `"What exercises did I do?"`

**Expected Results**:
- [ ] First query: AI searches logs and responds
- [ ] Second query: AI maintains context (doesn't repeat initial search)
- [ ] Third query: AI continues conversation thread
- [ ] All messages appear in chronological order
- [ ] Streaming typewriter effect for each AI response
- [ ] Response IDs are chained (check logs: `previous_response_id` field)

---

### Scenario 5: Chat Session Persistence Across Restarts

**Objective**: Verify chat history persists via OpenAI API.

**Steps**:
1. Start a chat with query: `"What did I eat yesterday?"`
2. Get AI response
3. Ask follow-up: `"Was it healthy?"`
4. Get response
5. **Close the app completely** (swipe away, not just background)
6. Reopen the app
7. Navigate to chat (if chat history UI exists) OR start new chat

**Expected Results**:
- [ ] Previous conversation is retrievable from OpenAI
- [ ] Can continue the conversation with context preserved
- [ ] `previous_response_id` properly chains sessions

**Note**: This test may require chat history UI (future enhancement) to fully verify. For now, verify via logs that `store: true` and response IDs are saved.

---

### Scenario 6: Intent Detection Service Failure (Fallback to Note)

**Objective**: Verify graceful degradation when intent detection fails.

**Steps**:
1. **Simulate API failure**: Temporarily disable network OR set invalid API key
2. From dashboard, type: `"Test entry during API failure"`
3. Tap submit

**Expected Results**:
- [ ] Loading indicator appears
- [ ] API call times out or fails after 2 seconds
- [ ] System defaults to note-logging mode (per clarification)
- [ ] Entry is logged as a note
- [ ] No error dialog shown to user
- [ ] Text field re-enables for next input

**Re-enable Network/API**:
- [ ] Subsequent inputs work normally

---

### Scenario 7: Loading State UI Feedback

**Objective**: Verify visual feedback during intent classification.

**Steps**:
1. Type: `"What restaurants have I been to?"`
2. Observe UI immediately after tapping submit

**Expected Results**:
- [ ] Text field disabled (no editing possible)
- [ ] Suffix icon changes to `CircularProgressIndicator`
- [ ] Hint text changes to "Analyzing..." (optional, check implementation)
- [ ] Spinner animates smoothly
- [ ] Loading state lasts < 500ms on good network
- [ ] After classification, spinner disappears

---

### Scenario 8: Empty Log History (Chat with No Data)

**Objective**: Verify chat behavior when user has no log entries.

**Steps**:
1. **Clear all log entries** (or use fresh app install)
2. Type chat query: `"Show me my workouts"`
3. Submit

**Expected Results**:
- [ ] Intent detected as "chat"
- [ ] Full-screen chat opens
- [ ] AI responds with dynamic message (e.g., "You don't have any workout logs yet. Start logging to get insights!")
- [ ] Response is conversational, not a predefined error template

---

## Performance Benchmarks

| Metric | Target | How to Verify |
|--------|--------|---------------|
| Intent classification latency | < 500ms | Observe loading indicator duration |
| Chat response time | < 2s | Time from submit to first streamed character |
| UI responsiveness during classification | No jank | Text field disables smoothly, spinner animates at 60fps |
| Full-screen navigation | Instant | Chat page appears immediately after intent detection |

---

## Accessibility Checks

- [ ] **VoiceOver (iOS)**:
  - Text field has proper label: "Log a note or ask a question"
  - Loading state announced: "Analyzing"
  - Clarification dialog buttons have semantic labels

- [ ] **Keyboard Navigation**:
  - Tab through clarification dialog options
  - Enter key activates selected button

- [ ] **Text Scaling**:
  - Increase iOS text size to maximum
  - Verify all UI remains readable and functional

---

## Error Recovery Scenarios

### 1. Network Interruption During Chat
- Start chat → Disconnect WiFi mid-response
- **Expected**: Error message in chat, ability to retry

### 2. API Rate Limit Exceeded
- Make rapid successive requests to trigger rate limit
- **Expected**: Graceful error, default to note-logging

### 3. Malformed API Response
- (Cannot easily simulate - check error handling in code)
- **Expected**: Catch JSON parsing errors, show user-friendly message

---

## Success Criteria

**Feature is ready for production when**:
- [ ] All 8 test scenarios pass
- [ ] Performance benchmarks met
- [ ] Accessibility checks pass
- [ ] No crashes during error scenarios
- [ ] User can seamlessly switch between note logging and chat
- [ ] Chat history persists across app restarts (verified via logs or future UI)

---

## Known Limitations

1. **Chat History UI**: This feature does not include a chat history browser. Users can only access the most recent chat session.
2. **Offline Mode**: Intent detection requires network. Offline inputs automatically become notes.
3. **Multi-language**: Intent detection tested with English only. Other languages may have lower accuracy.

---

## Regression Testing

After implementing this feature, verify these existing features still work:

- [ ] Voice input → Note logging (existing flow)
- [ ] Manual category selection (existing flow)
- [ ] Entry editing and deletion (existing flow)
- [ ] Dashboard V2 insights display (existing flow)
- [ ] Vector store synchronization (existing background task)

---

## Feedback Template

Use this template to report issues found during testing:

```
**Scenario**: [Which scenario number]
**Steps to Reproduce**:
1.
2.
3.

**Expected**: [What should happen]
**Actual**: [What actually happened]
**Screenshots**: [If applicable]
**Device**: [iPhone model, iOS version]
**Severity**: [Critical / Major / Minor]
```

---

## Next Steps After Testing

1. If issues found → Create tasks for fixes in `tasks.md`
2. If all tests pass → Mark feature as complete in `plan.md`
3. Consider future enhancements:
   - Chat history browser UI
   - Multi-language intent detection
   - Offline intent caching

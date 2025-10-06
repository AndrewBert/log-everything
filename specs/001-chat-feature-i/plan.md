# Implementation Plan: Unified Text Field with Chat Intent Detection

**Branch**: `001-chat-feature-i` | **Date**: 2025-10-05 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/Users/andrewbertino/log-everything-insights/specs/001-chat-feature-i/spec.md`

## Execution Flow (/plan command scope)
```
1. Load feature spec from Input path
   → If not found: ERROR "No feature spec at {path}"
2. Fill Technical Context (scan for NEEDS CLARIFICATION)
   → Detect Project Type from file system structure or context (web=frontend+backend, mobile=app+api)
   → Set Structure Decision based on project type
3. Fill the Constitution Check section based on the content of the constitution document.
4. Evaluate Constitution Check section below
   → If violations exist: Document in Complexity Tracking
   → If no justification possible: ERROR "Simplify approach first"
   → Update Progress Tracking: Initial Constitution Check
5. Execute Phase 0 → research.md
   → If NEEDS CLARIFICATION remain: ERROR "Resolve unknowns"
6. Execute Phase 1 → contracts, data-model.md, quickstart.md, agent-specific template file (e.g., `CLAUDE.md` for Claude Code, `.github/copilot-instructions.md` for GitHub Copilot, `GEMINI.md` for Gemini CLI, `QWEN.md` for Qwen Code, or `AGENTS.md` for all other agents).
7. Re-evaluate Constitution Check section
   → If new violations: Refactor design, return to Phase 1
   → Update Progress Tracking: Post-Design Constitution Check
8. Plan Phase 2 → Describe task generation approach (DO NOT create tasks.md)
9. STOP - Ready for /tasks command
```

**IMPORTANT**: The /plan command STOPS at step 9. Phases 2-4 are executed by other commands:
- Phase 2: /tasks command creates tasks.md
- Phase 3-4: Implementation execution (manual or via tools)

## Summary
Extend the existing unified text field to support dual-mode operation: note logging (existing) and chat initiation (new). Use OpenAI's GPT-5-nano model for real-time intent classification to determine whether user input is a note to be logged or a question to start a chat. When chat intent is detected, transition to a full-screen chat interface that leverages the existing chat backend infrastructure to search user logs and provide AI-generated responses. Each chat session is fresh and independent with no persistence across app restarts.

## Technical Context
**Language/Version**: Dart 3.x with Flutter SDK
**Primary Dependencies**: flutter_bloc, get_it, equatable, openai_dart (for GPT-5-nano), existing AiService infrastructure
**Storage**: SharedPreferences for local data, no chat session persistence (fresh sessions only)
**Testing**: User-led testing (no automated tests per constitution)
**Target Platform**: iOS 15+ (mobile)
**Project Type**: Mobile (Flutter app)
**Performance Goals**: Intent classification < 500ms, chat response < 2s
**Constraints**: Block UI during intent classification, graceful fallback to note-logging on service failure, 2000 character input limit
**Scale/Scope**: Single user, existing chat backend reuse, new full-screen chat UI

## Constitution Check
*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### I. BLoC-First Architecture
- [x] All state management uses BLoC/Cubit pattern (no StatefulWidgets)
- [x] State classes extend Equatable
- [x] Cubit and state files use `part`/`part of` directives

### II. Service Layer Separation
- [x] Services registered in GetIt (`lib/locator.dart`)
- [x] Cubits provided via BlocProvider (NOT in GetIt)
- [x] Clear boundaries between UI state and business logic

### III. Stateless UI Only
- [x] All widgets are StatelessWidget
- [x] Private methods organized below `build()` method
- [x] Widget keys defined in `lib/utils/*_keys.dart` files

### IV. Clean Code Standards
- [x] Comments prefixed with "CP" when needed
- [x] Using `Color.withValues()` (not withOpacity)
- [x] 120 char line width with trailing commas
- [x] No unnecessary comments

### V. User-Led Testing
- [x] Implementation focus only (user handles testing)
- [x] No test files created unless explicitly requested

### VI. AI-First Development
- [x] AI integration via `AiService` where intelligence needed
- [x] Vector store sync is debounced and non-blocking
- [x] Graceful degradation with user feedback on errors

**Initial Check Result**: PASS - All constitutional requirements align with planned approach

## Project Structure

### Documentation (this feature)
```
specs/001-chat-feature-i/
├── plan.md              # This file (/plan command output)
├── research.md          # Phase 0 output (/plan command)
├── data-model.md        # Phase 1 output (/plan command)
├── quickstart.md        # Phase 1 output (/plan command)
├── contracts/           # Phase 1 output (/plan command)
└── tasks.md             # Phase 2 output (/tasks command - NOT created by /plan)
```

### Source Code (repository root)
```
lib/
├── intent_detection/
│   ├── models/
│   │   ├── intent_classification.dart
│   │   └── intent_type.dart
│   ├── services/
│   │   └── intent_detection_service.dart
│   └── cubit/
│       ├── intent_detection_cubit.dart
│       └── intent_detection_state.dart
├── chat/
│   ├── models/
│   │   ├── chat_session.dart (existing, may need updates)
│   │   ├── chat_message.dart (existing)
│   │   └── chat_query.dart (new)
│   ├── pages/
│   │   └── fullscreen_chat_page.dart (new)
│   ├── cubit/
│   │   └── chat_cubit.dart (existing, may need updates)
│   └── widgets/
│       ├── chat_message_bubble.dart (existing)
│       └── intent_clarification_dialog.dart (new)
├── dashboard_v2/
│   ├── widgets/
│   │   └── unified_text_field.dart (existing, needs extension)
│   └── cubit/
│       └── dashboard_v2_cubit.dart (existing, needs updates)
├── utils/
│   └── chat_keys.dart (new)
└── locator.dart (register IntentDetectionService)
```

**Structure Decision**: Mobile Flutter app using feature-based organization. Intent detection is a new feature module. Chat is an existing module that needs frontend updates. Dashboard V2 contains the unified text field that orchestrates the flow.

## Phase 0: Outline & Research
*Status: Complete*

### Research Tasks

1. **GPT-5-nano Integration for Intent Classification**
   - Research: How to use GPT-5-nano via OpenAI API for binary classification (note vs chat)
   - Key questions: Prompt design, response format, latency expectations, error handling
   - Output: Intent detection prompt template and API integration pattern

2. **Existing Chat Backend Analysis**
   - Research: Review existing `AiService` and `ChatCubit` implementation
   - Key questions: What chat API methods exist? How is chat history managed? What's the vector store integration?
   - Output: Reusable backend components list and required modifications

3. **Full-Screen Chat UI Patterns in Flutter**
   - Research: Flutter navigation patterns for modal full-screen transitions
   - Key questions: MaterialPageRoute vs custom transitions, how to pass initial query, how to handle back navigation
   - Output: Navigation pattern and page structure design

4. **Intent Ambiguity UX Patterns**
   - Research: UI patterns for binary choice dialogs in Flutter
   - Key questions: AlertDialog vs BottomSheet, blocking vs non-blocking, accessibility considerations
   - Output: Clarification dialog design

5. **Loading State Management During Intent Detection**
   - Research: Flutter patterns for blocking UI during async operations
   - Key questions: How to disable text field, show loading indicator, handle timeout
   - Output: Loading state pattern for unified text field

**Output**: `research.md` documenting all findings and decisions

## Phase 1: Design & Contracts
*Status: Complete*

### Design Artifacts to Generate

1. **data-model.md**: Document all entities
   - IntentClassification (type: IntentType, confidence: double, timestamp: DateTime)
   - IntentType enum (note, chat, ambiguous)
   - ChatQuery (extends existing chat models)
   - ChatSession (fresh sessions only, no persistence needed)

2. **contracts/**: API contracts
   - `intent_detection_contract.yaml`: GPT-5-nano request/response schema
   - `chat_session_contract.yaml`: Updated chat session management (if needed)

3. **quickstart.md**: Manual test scenarios
   - Scenario 1: Type note, verify it logs
   - Scenario 2: Type question, verify chat opens
   - Scenario 3: Trigger ambiguous input, verify dialog appears
   - Scenario 4: Chat context preserved within session (not across restarts)

4. **CLAUDE.md update**: Incremental context addition
   - Add intent detection service to architecture overview
   - Document GPT-5-nano integration pattern
   - Update unified text field behavior
   - Preserve existing content between markers

**Output**: Complete design documentation suite

## Phase 2: Task Planning Approach
*This section describes what the /tasks command will do - DO NOT execute during /plan*

**Task Generation Strategy**:
- Load `.specify/templates/tasks-template.md` as base
- Generate tasks following Flutter/BLoC workflow: models → services → cubits → UI
- Group by feature module (intent detection, chat frontend, dashboard integration)
- Each model gets a creation task [P]
- Each service gets implementation + DI registration task
- Each cubit gets state + cubit implementation task [P for independent cubits]
- Each UI component gets widget creation task
- Integration tasks for wiring everything together

**Ordering Strategy**:
- **Phase 1**: Models first (IntentType, IntentClassification, ChatQuery) [P]
- **Phase 2**: Intent Detection Service (depends on models)
- **Phase 3**: Intent Detection Cubit + State [P]
- **Phase 4**: Chat updates (ChatCubit updates for fresh session handling)
- **Phase 5**: UI Components (IntentClarificationDialog, FullscreenChatPage) [P]
- **Phase 6**: Dashboard V2 integration (UnifiedTextField extension, DashboardV2Cubit updates)
- **Phase 7**: Service registration in locator.dart
- **Phase 8**: Widget keys addition to chat_keys.dart

**Estimated Output**: 18-22 numbered, ordered tasks in tasks.md

**IMPORTANT**: This phase is executed by the /tasks command, NOT by /plan

## Phase 3+: Future Implementation
*These phases are beyond the scope of the /plan command*

**Phase 3**: Task execution (/tasks command creates tasks.md)
**Phase 4**: Implementation (execute tasks.md following constitutional principles)
**Phase 5**: Validation (user tests in running app per constitution)

## Complexity Tracking
*No constitutional violations identified*

## Progress Tracking
*This checklist is updated during execution flow*

**Phase Status**:
- [x] Phase 0: Research complete (/plan command)
- [x] Phase 1: Design complete (/plan command)
- [x] Phase 2: Task planning complete (/plan command - describe approach only)
- [ ] Phase 3: Tasks generated (/tasks command)
- [ ] Phase 4: Implementation complete
- [ ] Phase 5: Validation passed

**Gate Status**:
- [x] Initial Constitution Check: PASS
- [x] Post-Design Constitution Check: PASS (no violations introduced)
- [x] All NEEDS CLARIFICATION resolved (addressed in spec.md clarifications section)
- [x] Complexity deviations documented (none - no violations)

---
*Based on Constitution v1.0.0 - See `.specify/memory/constitution.md`*

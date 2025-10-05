# Tasks: [FEATURE NAME]

**Input**: Design documents from `/specs/[###-feature-name]/`
**Prerequisites**: plan.md (required), research.md, data-model.md, contracts/

## Execution Flow (main)
```
1. Load plan.md from feature directory
   → If not found: ERROR "No implementation plan found"
   → Extract: tech stack, libraries, structure
2. Load optional design documents:
   → data-model.md: Extract entities → model tasks
   → contracts/: Each file → contract test task
   → research.md: Extract decisions → setup tasks
3. Generate tasks by category:
   → Setup: project init, dependencies, linting
   → Tests: contract tests, integration tests
   → Core: models, services, CLI commands
   → Integration: DB, middleware, logging
   → Polish: unit tests, performance, docs
4. Apply task rules:
   → Different files = mark [P] for parallel
   → Same file = sequential (no [P])
   → Tests before implementation (TDD)
5. Number tasks sequentially (T001, T002...)
6. Generate dependency graph
7. Create parallel execution examples
8. Validate task completeness:
   → All contracts have tests?
   → All entities have models?
   → All endpoints implemented?
9. Return: SUCCESS (tasks ready for execution)
```

## Format: `[ID] [P?] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- Include exact file paths in descriptions

## Path Conventions
- **Single project**: `src/`, `tests/` at repository root
- **Web app**: `backend/src/`, `frontend/src/`
- **Mobile**: `api/src/`, `ios/src/` or `android/src/`
- Paths shown below assume single project - adjust based on plan.md structure

## Phase 3.1: Setup
- [ ] T001 Create feature structure in lib/[domain]/ per implementation plan
- [ ] T002 Add required dependencies to pubspec.yaml if needed
- [ ] T003 [P] Update barrel files for exports/imports

## Phase 3.2: Models & Data
- [ ] T004 [P] Define model classes in lib/[domain]/models/
- [ ] T005 [P] Add JSON serialization methods (toJson/fromJson)
- [ ] T006 [P] Ensure models extend Equatable for value equality

## Phase 3.3: Services (if external integration needed)
- [ ] T007 [P] Create service class in lib/services/
- [ ] T008 Register service in lib/locator.dart (GetIt)
- [ ] T009 Implement service methods with error handling
- [ ] T010 Add graceful degradation for AI/API failures

## Phase 3.4: State Management (BLoC/Cubit)
- [ ] T011 Create cubit class in lib/[domain]/cubit/
- [ ] T012 Create state class using `part`/`part of` pattern
- [ ] T013 State class extends Equatable with proper equality
- [ ] T014 Implement business logic methods in cubit
- [ ] T015 Add copyWith with null-handling bool parameters

## Phase 3.5: UI Implementation
- [ ] T016 [P] Create StatelessWidget in lib/[domain]/widgets/ or lib/pages/
- [ ] T017 [P] Define widget keys in lib/utils/[feature]_keys.dart
- [ ] T018 Add BlocProvider for cubit (NOT in GetIt)
- [ ] T019 Implement UI with BlocBuilder/BlocListener
- [ ] T020 Private methods below build() method
- [ ] T021 Use Color.withValues() (not withOpacity)
- [ ] T022 Apply 120 char width with trailing commas

## Phase 3.6: Polish & User Validation
- [ ] T023 [P] Remove unnecessary comments (keep only CP-prefixed)
- [ ] T024 Run flutter analyze to verify code quality
- [ ] T025 User tests feature in running Flutter app
- [ ] T026 Address user feedback and iterate

## Dependencies
- Models (T004-T006) before Services (T007-T010)
- Services (T007-T010) before State Management (T011-T015)
- State Management (T011-T015) before UI (T016-T022)
- Implementation complete before Polish (T023-T026)

## Parallel Example
```
# Launch model tasks together:
Task: "Define Entry model in lib/entry/models/entry.dart"
Task: "Define Category model in lib/entry/models/category.dart"
Task: "Add JSON serialization to models"
```

## Notes
- [P] tasks = different files, no dependencies
- Follow Flutter/BLoC architecture patterns
- User validates in running app (no test generation)
- Commit after logical task groups
- Avoid: vague tasks, same file conflicts

## Task Generation Rules
*Applied during main() execution*

1. **From Data Model**:
   - Each entity → model creation task [P]
   - Relationships → captured in model design

2. **From Services**:
   - External integrations → service class tasks
   - Service registration → locator.dart task

3. **From User Stories**:
   - User interactions → cubit methods
   - UI flows → StatelessWidget tasks
   - Each screen/widget → BlocProvider setup

4. **Ordering**:
   - Setup → Models → Services → State (Cubit) → UI → Polish
   - Dependencies block parallel execution

## Validation Checklist
*GATE: Checked by main() before returning*

- [ ] All entities have model tasks
- [ ] Services registered in locator.dart (NOT cubits)
- [ ] Cubits provided via BlocProvider
- [ ] All widgets are StatelessWidget
- [ ] Widget keys defined in utils files
- [ ] Parallel tasks truly independent
- [ ] Each task specifies exact file path
- [ ] No task modifies same file as another [P] task
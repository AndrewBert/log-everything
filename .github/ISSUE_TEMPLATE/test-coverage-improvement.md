# Improve Test Coverage Across Codebase

## Summary

Current test coverage is approximately **11.4%** (14 test files covering 123 source files / ~6,785 lines of code). Several major features and critical services lack any test coverage.

## Current State

### Tested Areas ✓
| Domain | Coverage | Notes |
|--------|----------|-------|
| Entry | 50% | JSON serialization, image handling |
| Services | 29% | VectorStore, DeviceId, ImageSync, Snapshot |
| Settings | 37% | Settings page, account section, recovery dialog |
| Dashboard V2 | 8% | Insight models, basic navigation |
| Onboarding | 9% | Only welcome step sign-in |

### Untested Areas ⚠️
| Domain | Files | Impact |
|--------|-------|--------|
| Chat | 7 files | Core AI feature |
| Search | 4 files | Key functionality |
| Snackbar | 7 files | Notification system |
| Intent Detection | 5 files | Classification service |
| Voice Input | 3 files | Input widget |
| Dialogs | 4 files | User-facing dialogs |
| Dashboard V2 UI | 36 files | Main interface |

## Priority Coverage Gaps

### Critical (Core Features)
1. **Services Layer** - `ai_service.dart`, `entry_persistence_service.dart`, `firestore_sync_service.dart`
2. **Dashboard V2** - 36 untested files including cubits, pages, and widgets
3. **Chat** - Complete feature untested (cubit, message model, UI pages)
4. **Dialogs** - All 4 dialog components untested

### High (Important Features)
5. **Search** - Search cubit, overlay, and carousel
6. **Onboarding** - 10/11 files untested (first user experience)
7. **Voice Input** - Widget and cubit
8. **Auth Service** - Authentication flows

### Medium (Supporting Features)
9. **Snackbar** - Notification cubit and service
10. **Intent Detection** - Classification service and models

## Test Infrastructure

The project has solid testing infrastructure ready to use:
- ✓ Mockito with generated mocks (`mocks.mocks.dart`)
- ✓ Test DI system (`test_di_registrar.dart`)
- ✓ `WidgetTestScope` helper for widget test setup
- ✓ Test data fixtures (`test_data.dart`, `auth_test_data.dart`)
- ✓ Domain-specific helpers (`dashboard_v2_test_helpers.dart`)
- ✓ BDD-style naming convention (Given/When/Then)

## Suggested Approach

### Phase 1: Quick Wins
- [ ] Dialogs (4 files) - simple UI components
- [ ] Voice Input (3 files) - isolated widget
- [ ] Snackbar (7 files) - notification system

### Phase 2: Core Services
- [ ] `ai_service.dart` - mock OpenAI calls
- [ ] `entry_persistence_service.dart` - storage layer
- [ ] `firestore_sync_service.dart` - cloud sync
- [ ] `auth_service.dart` - authentication

### Phase 3: Major Features
- [ ] Chat domain (7 files)
- [ ] Search domain (4 files)
- [ ] Onboarding flow (10 files)

### Phase 4: Dashboard V2 UI
- [ ] Cubits (6 files)
- [ ] Pages (9 files)
- [ ] Widgets (14 files)

## Coverage Goals

| Milestone | Target | Focus |
|-----------|--------|-------|
| Short-term | 30% | Services + quick wins |
| Medium-term | 50% | Core features (Chat, Search) |
| Long-term | 75% | Full UI coverage |

## Notes

- Following project convention: test behavior through widget tests, not cubits directly
- Use `WidgetTestScope` for consistent test setup
- Generate new mocks via `dart run build_runner build` as needed

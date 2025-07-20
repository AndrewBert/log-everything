# Dashboard V2 Implementation Plan

## Overview
Redesign the home screen as a modern dashboard inspired by Nothing's Space app, featuring a carousel of recent entries with AI insights and a grid view of all entries.

## Core Features
1. **Recent Entries Carousel** - Manual swipe, shows 2+ square entries
2. **AI Insights** - Generated on-demand above selected carousel entry
3. **Full Entries Grid** - Infinite scroll, 2 columns of square cards
4. **Entry Details** - Full page view with edit capabilities

## Implementation Phases

### Phase 1: Foundation Setup
- [ ] Create `/lib/dashboard_v2/` folder structure
- [ ] Create `DashboardV2Page` widget
- [ ] Create `DashboardV2Cubit` and state
- [ ] Add `/dashboard_v2` route to router
- [ ] Add temporary navigation button to access v2

### Phase 2: Square Entry Card Design
- [x] Created `NewspaperEntryCard` widget (replaced SquareEntryCard)
- [ ] Design compact layout for square format
- [ ] Implement tap handler for navigation
- [ ] Add to widget keys for testing

### Phase 3: Recent Entries Carousel
- [ ] Implement carousel widget with PageView
- [ ] Configure viewport to show 2+ cards
- [ ] Add selection state tracking
- [ ] Style selected vs unselected states

### Phase 4: AI Insights Integration
- [ ] Add insight container above carousel
- [ ] Create `generateInsight` method in AiService
- [ ] Implement on-demand generation on selection
- [ ] Add loading and error states
- [ ] Cache insights in cubit state

### Phase 5: Full Entries Grid
- [ ] Create scrollable grid view below carousel
- [ ] Implement infinite scroll pagination
- [x] Using `NewspaperEntryCard` component
- [ ] Add proper spacing and padding

### Phase 6: Entry Details Page
- [ ] Create `EntryDetailsPage` 
- [ ] Display full entry content
- [ ] Add edit functionality
- [ ] Add recategorization option
- [ ] Implement navigation from cards

### Phase 7: Polish & Swap
- [ ] Add animations and transitions
- [ ] Implement feature flag for v1/v2 toggle
- [ ] Performance optimization
- [ ] Update app navigation to use v2

## Technical Details

### File Structure
```
lib/dashboard_v2/
├── pages/
│   ├── dashboard_v2_page.dart
│   └── entry_details_page.dart
├── widgets/
│   ├── recent_entries_carousel.dart
│   ├── square_entry_card.dart
│   ├── ai_insight_container.dart
│   └── entries_grid.dart
├── cubit/
│   ├── dashboard_v2_cubit.dart
│   └── dashboard_v2_state.dart
└── dashboard_v2_barrel.dart
```

### State Management
- `DashboardV2Cubit` will manage:
  - Selected carousel index
  - Generated insights cache
  - Entries list with pagination
  - Loading states

### AI Service Enhancement
```dart
// New method for insight generation
Future<String> generateInsight(Entry entry, List<Entry> recentEntries)
```

### Key Design Decisions
- **Square cards**: Better visual hierarchy, modern look
- **On-demand insights**: Cost-effective, faster initial load
- **Separate route**: Clean development without breaking v1
- **Grid layout**: Space-efficient, shows more entries

## Next Steps
1. Start with Phase 1 - Foundation Setup
2. Focus on one phase at a time
3. Test each component in isolation
4. Get user feedback after Phase 3 (carousel + insights)

## Future Enhancements (Post-MVP)
- Upcoming todos section
- Categories carousel
- RAG-powered insights
- Customizable dashboard sections
- Time period filters
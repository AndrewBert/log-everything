# Simplified Insights System - Specification

## Overview
Simplify the entry insights system from a complex multi-dimensional analysis (5+ fields, vector store searches, priority logic) to a single playful, helpful insight with minimal AI instructions.

## Goals
- **Reduce complexity**: Eliminate forced generation of 5 different insight types
- **Save tokens**: Shorter prompts, no vector store searches, less response data
- **Add personality**: Make insights feel like a witty, caring friend vs. clinical analysis
- **Improve flexibility**: Let AI decide tone/content vs. rigid structure
- **Maintain value**: Still provide actionable recommendations when relevant

## Current System (To Be Replaced)

### Data Structure
```dart
enum InsightType { summary, emotion, pattern, theme, recommendation }

class Insight {
  final InsightType type;
  final String title;
  final String content;
  // + metadata, emotion details, etc.
}

class ComprehensiveInsight {
  final List<Insight> insights;  // Always 5 insights
  final String? priority;         // Which one to show
}
```

### AI Prompt
- ~200+ lines of instructions
- Complex rules for summary/emotion/pattern/theme/recommendation
- Vector store search for pattern detection
- Priority selection logic
- Heavy focus on "actionable" but clinical tone

### Problems
- Generates 5 insights per entry, uses only 1 (wasteful)
- Empty strings when insights don't apply ("pattern": "")
- Complex priority-picking logic
- Long prompts = high token usage
- Clinical tone lacks personality

## New System (Proposed)

### Data Structure (TBD - discussing with user)
Options under consideration:
- Single string (simplest)
- String + optional type enum for UI labeling
- Keep some metadata for extensibility

### AI Prompt
```
Analyze this log entry and provide a brief, helpful insight.

Default tone: Playful and warm, like a witty friend who cares.
Be helpful when there's something actionable. Be encouraging for wins.
Avoid sarcasm on sensitive topics (health issues, sadness, anxiety, relationships).

Keep it to 1-2 sentences max.
```

### Examples of Expected Output
- "had coffee" → "Caffeine: humanity's favorite performance enhancer ☕"
- "went for a run" → "Nice! Your future self will thank you"
- "should I apply for this job?" → "Sleep on it, then make a pros/cons list tomorrow"
- "feeling anxious about presentation" → "Presentations are tough. Practice once out loud, then trust yourself"
- "finished big project" → "Crushing it! Take the win 🎉"

### Key Changes
1. **Single insight** instead of 5 required fields
2. **Playful default tone** with AI judgment on when to be serious
3. **No vector store search** (for now - may revisit later)
4. **Minimal instructions** - trust the AI vs. over-specifying
5. **1-2 sentences max** for UI card display

## Migration Strategy

### Backwards Compatibility
- Existing entries have `ComprehensiveInsight` objects in storage
- Need to handle reading old format gracefully
- Options:
  - Parse old format and extract priority insight
  - Keep old insights as-is, only new entries use new system
  - Provide migration helper to convert old → new on read

### Storage Format
- Reduce JSON payload size significantly
- Old: ~5 insight objects with metadata
- New: Single insight string (or string + type)

## Questions to Resolve

1. **Data structure**: String only, or string + type enum?
2. **Type field purpose**: If kept, what types? (recommendation, pattern, observation, celebration, etc.)
3. **Backwards compatibility approach**: Convert on read, or dual format support?
4. **Vector store**: Truly skip forever, or leave door open for future "pattern mode"?
5. **Response format**: Plain text or JSON with structured fields?

## Success Metrics

- [ ] Reduced token usage per insight generation (target: 50%+ reduction)
- [ ] Faster insight generation (no vector store calls)
- [ ] Simpler codebase (fewer models, less prompt engineering)
- [ ] User feedback: Insights feel more engaging/less robotic
- [ ] No loss of actionable value for complex entries

## Out of Scope (For Now)

- Vector store pattern detection
- Multi-insight display (emotion + recommendation together)
- Historical trend analysis
- User customization of tone/style

---

**Status**: Specification draft - pending data structure finalization

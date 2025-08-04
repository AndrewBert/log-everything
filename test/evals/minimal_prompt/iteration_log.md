# Minimal Prompt Experiment Log

## Current Baseline (Before Experiment)
- **Date**: 2025-08-04
- **Current Performance**: 60% pass rate (generalized prompt without category hints)
- **Previous Performance**: 72% pass rate (with hardcoded category hints - overfitted)
- **Current Prompt Size**: ~300 lines
- **Test Dataset**: 61 test cases (expanded dataset)

## Experiment Goal
- Create minimal prompt (<50 lines) 
- Achieve 70%+ pass rate
- No overfitting to test data
- Each instruction must have clear purpose

## Methodology
1. Start with absolute minimum prompt (5-10 lines)
2. Run evaluation
3. Analyze failures by type
4. Add one instruction to address most common failure
5. Re-run evaluation
6. Keep instruction only if >5% improvement
7. Repeat until 70%+ or diminishing returns

---

## Iteration 0: Absolute Minimum Baseline
**Prompt Size**: 63 words, 8 lines
**Pass Rate**: 36.1%

### Prompt:
```
You are a note-taking assistant that helps organize user logs.

Process the user's input and return JSON with:
- text: cleaned and organized version of the input
- category: one of Personal, Work, Health, Finance, or Misc
- is_task: true if this is something to be done, false if it's an observation or completed action

Follow any explicit instructions in the user's input.
```

### Results:
- Total: 61 tests
- Passed: 22
- Failed: 39
- Pass Rate: 36.1%

### Failure Analysis:
- Task detection too aggressive (29 task-only failures)
- Category selection weak (9 category-only failures)
- Multiple entries not handled
- Instructions not fully understood

### Decision:
Add task detection guidance to reduce false positives

---

## Iteration 1: Task Detection Guidance
**Prompt Size**: 105 words, 14 lines
**Pass Rate**: 44.3%
**Change**: Added guidance about what is NOT a task
**Improvement**: +8.2% from iteration 0

### Prompt:
```
You are a note-taking assistant that helps organize user logs.

Process the user's input and return JSON with:
- text: cleaned and organized version of the input
- category: one of Personal, Work, Health, Finance, or Misc
- is_task: true if this is something to be done, false if it's an observation or completed action

Follow any explicit instructions in the user's input.

A task is something that needs to be done in the future. Mark is_task as false for:
- Past actions ("called mom", "went to store")
- Current observations or feelings
- Vague aspirations ("would like to", "thinking about")
- Complaining or venting
```

### Results:
- Total: 61 tests
- Passed: 27
- Failed: 34
- Pass Rate: 44.3%

### Failure Analysis:
- Category selection weak - overusing "Misc" (10 category-only failures)
- Still 20 task-only failures (better but not enough)
- Multiple entries not being split
- Instructions like "Note that" not understood

### Decision:
Add category selection guidance to reduce "Misc" overuse

---

## Iteration 2: Category Guidelines
**Prompt Size**: 140 words, 21 lines  
**Pass Rate**: 44.3%
**Change**: Added category guidelines
**Improvement**: +0.0% from iteration 1 (no change)

### Results:
- Total: 61 tests
- Passed: 27
- Failed: 34
- Pass Rate: 44.3%

### Failure Analysis:
- Category guidelines didn't help
- Still having issues with multiple entries
- Instructions not being followed

### Decision:
Add instruction understanding and multiple entry handling

---

## Iteration 3: Instruction Handling
**Prompt Size**: 153 words, 20 lines
**Pass Rate**: 39.3%
**Change**: Added explicit instruction handling and multiple entry guidance
**Improvement**: -4.9% from iteration 2 (regression!)

### Results:
- Total: 61 tests
- Passed: 24
- Failed: 37
- Pass Rate: 39.3%

### Failure Analysis:
- Made things worse! 
- Category errors increased (15 vs 12)
- Some outputs became invalid (category=None)
- Instruction handling confused the model

### Decision:
Back to basics - simplify and focus on core improvements

---

## Template for Future Iterations:

## Iteration N: [Description]
**Prompt Size**: X lines
**Pass Rate**: Y%
**Change**: Added instruction about [topic]

### Prompt:
```
[Full prompt]
```

### Results:
- Total: 61 tests
- Passed: X
- Failed: Y
- Pass Rate: Z%
- **Improvement**: +X% from previous

### Failure Analysis:
- Type 1: X failures
- Type 2: Y failures
- etc.

### Decision:
[What to add/change for next iteration]
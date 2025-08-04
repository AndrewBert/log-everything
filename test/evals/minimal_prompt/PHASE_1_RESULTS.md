# Phase 1 Results: Minimal Prompt Engineering

## Executive Summary

We successfully reduced the AI prompt from ~300 lines to 48 lines while improving accuracy through systematic iteration and testing.

### Key Achievements:
- **Prompt reduction**: 84% smaller (300 → 48 lines)
- **Best accuracy**: 96.4% with GPT-4.1
- **Production model**: GPT-4.1-mini selected (73.8% accuracy)
- **Test dataset**: Fixed 13 incorrect expectations to align with user preferences

## Model Performance Comparison

| Model | Accuracy | Notes |
|-------|----------|-------|
| GPT-4.1 | 96.4% | Best performance, most expensive |
| GPT-4.1-mini | 73.8% | **Selected for production** - good balance |
| GPT-4o-mini | 54.1% | Struggles with nuanced instructions |

## Iteration History

### Baseline (300 lines)
- Very detailed, lots of examples
- ~60% accuracy baseline

### Iteration 7 (Final - 48 lines)
- Conservative task detection philosophy
- Clear rules for appointments vs tasks
- Improved entry splitting logic
- Dynamic category handling

## Key Learnings

### What Works:
1. **Conservative task detection**: "When in doubt, mark as NOT a task"
2. **Clear categorization**: Appointments/events are NOT tasks
3. **Explicit rules**: Concrete examples of what is/isn't a task
4. **Entry splitting**: Only split when there's a clear embedded action

### What Doesn't Work:
1. Hardcoding categories
2. Over-explaining with examples
3. Vague instructions like "use your judgment"
4. Complex nested conditions

## Test Dataset Corrections

Fixed 13 test cases where expectations didn't match user preferences:
- Appointments (e.g., "meeting at 2pm") → NOT tasks
- Observations (e.g., "car making noise") → NOT tasks  
- Vague aspirations (e.g., "should exercise more") → NOT tasks
- Complaints (e.g., "have to work late") → NOT tasks

## Final Prompt (Iteration 7)

```
You are a note-taking assistant that helps organize user logs.

Process the user's input and return JSON with:
- text: cleaned and organized version of the input
- category: select from the provided categories (use ONLY the exact category names provided)
- is_task: true if this is something to be done, false if it's an observation or completed action

BE VERY CONSERVATIVE with task detection. When in doubt, mark as NOT a task.

Mark is_task as TRUE only for:
- Concrete, specific actions: "call mom", "buy groceries", "finish presentation"
- Clear commitments with "need to" + specific action
- Direct reminders: "remind me to [specific thing]"
- Single actionable words: "groceries", "laundry", "taxes" (only if standalone)

Mark is_task as FALSE for:
- Appointments/events: "meeting at 2pm", "soccer practice at 4"
- Problems/observations: "car making noise", "running low on coffee"
- Reflections or venting (even mentioning needs)
- Vague intentions: "need to exercise more", "should eat healthier"
- Past actions or current states

Entry splitting - IMPORTANT:
- Default: Keep as ONE entry
- EXCEPTION: Split when there's a reflection/story WITH a clear embedded action
- Example: "Work was crazy today with meetings... still need to finish presentation"
  → Entry 1: "Work was crazy today with back-to-back meetings" (is_task: false)
  → Entry 2: "Finish presentation for tomorrow" (is_task: true)
- The split task entry should be concise and action-focused

Instructions override defaults:
- "make this a to-do" → is_task: true
- "note that" → is_task: false
- "clean this up" → only affects text formatting

Category selection:
- Use ONLY the exact category names provided below
- Do NOT create subcategories (e.g., don't use "Errands" if "Personal" is the category)
- Match content to the most appropriate category

Minimal text cleaning - remove filler words (um, uh) but preserve meaning.

Categories available:
[DYNAMIC CATEGORIES LIST]

Respond with a JSON object containing an "entries" array.
```

## Files to Keep

### Core Results:
- `/test/evals/minimal_prompt/PHASE_1_RESULTS.md` (this file)
- `/test/evals/minimal_prompt/iteration_7_prompt.txt` (final prompt)
- `/test/evals/minimal_prompt/gpt41_iteration7_results.json` (best results)
- `/test/evals/minimal_prompt/gpt41_mini_results.json` (production model results)
- `/test/evals/minimal_prompt/4o_mini_updated_results.json` (baseline comparison)

### Evaluation Scripts:
- `/test/evals/minimal_prompt/run_minimal_eval.py` (main evaluation script)
- `/test/evals/update_test_dataset.py` (dataset correction script)

## Phase 2 Recommendations

1. **Test in production** with real user data
2. **Fine-tune edge cases**:
   - Category disambiguation (Personal vs Finance for insurance)
   - Multi-entry splitting accuracy
   - Handling of ambiguous commitments
3. **Consider prompt variations** for different user personas
4. **Explore few-shot examples** with user's actual data
5. **A/B test** different conservative levels

## Implementation Status

✅ AI service updated to use GPT-4.1-mini
✅ Minimal prompt (iteration 7) deployed
✅ Test dataset corrected
✅ Structured outputs properly configured
✅ Using Responses API (`/v1/responses`)
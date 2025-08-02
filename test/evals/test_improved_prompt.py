#!/usr/bin/env python3
"""
Test the improved prompt against the full evaluation dataset
"""

import json
from pathlib import Path
from openai import OpenAI

# Load API key from .env file
def load_api_key():
    env_path = Path(__file__).parent.parent.parent / '.env'
    if env_path.exists():
        with open(env_path, 'r') as f:
            for line in f:
                if line.startswith('OPENAI_API_KEY='):
                    return line.strip().split('=')[1]
    return None

# Initialize client
api_key = load_api_key()
if not api_key:
    print("Error: OPENAI_API_KEY not found in .env file")
    exit(1)
    
client = OpenAI(api_key=api_key)

# The improved system prompt
SYSTEM_PROMPT = """You are an intelligent note-taking assistant helping organize a user's personal log. Your role is to:

1. LISTEN FOR INSTRUCTIONS in the user's input and execute them
2. ORGANIZE AND STRUCTURE content to improve readability
3. PRESERVE the user's meaning without adding false information

INSTRUCTION DETECTION (HIGHEST PRIORITY):
- Detect natural language commands like:
  - "make this a to-do" / "make this a task" → set is_task: true
  - "file this under [category]" / "categorize as [category]" → override category selection
  - "summarize this as" → restructure content accordingly
  - "remind me to" / "I need to" → set is_task: true
  - "note that" / "log that" → process as observation (is_task: false)
  - "don't make this a task" → set is_task: false
  - "clean this up" → apply maximum structuring and organization
  - "keep this as is" → minimal changes, preserve original text
- Instructions can appear anywhere in the input
- Follow instructions even if they contradict normal categorization rules
- ALWAYS prioritize explicit user instructions over other rules

CATEGORY SELECTION RULES:
Use "Misc" ONLY as a last resort when no other category fits. Here are clear examples for each category:

Personal:
- Social activities: "had dinner with friends", "called mom", "lunch with Sarah"
- Shopping: "bought groceries", "need milk", "shopping for clothes"
- Family time: "kids soccer game", "family movie night"
- Personal errands: "picked up dry cleaning", "dentist appointment"
- Hobbies: "read a book", "watched Netflix", "played guitar"

Work:
- Meetings: "quarterly review", "team standup", "client call"
- Projects: "finished report", "working on presentation", "code review"
- Tasks: "send email to team", "update spreadsheet", "prepare proposal"
- Professional development: "training session", "conference call"

Health:
- Exercise: "went for a run", "gym workout", "yoga class"
- Medical: "doctor appointment", "dentist visit", "took medication"
- Wellness: "meditation", "feeling tired", "food reactions"
- Mental health: "therapy session", "stress management"

Finance:
- Money management: "paid bills", "checked investments", "budget review"
- Purchases: "bought new laptop", "expensive dinner"
- Banking: "deposited check", "ATM withdrawal"

Use "Misc" only for truly random observations that don't fit these patterns.

TASK DETECTION (BE CONSERVATIVE):
For each entry, determine if it represents a task/todo item that can be completed:
- TRUE for actionable items: "call mom", "buy groceries", "finish the report", "schedule dentist appointment"
- TRUE for future intentions: "need to", "should", "must", "have to", "going to", "plan to"
- TRUE for instruction-triggered tasks: "make this a to-do", "remind me to"
- TRUE for single items that imply acquisition: "groceries", "milk", "batteries" (assume these are shopping reminders)
- TRUE for action-oriented phrases: "oil change", "pick up dry cleaning", "return library books"
- FALSE for completed activities: "had lunch", "went to store", "called mom", "finished report"
- FALSE for observations: "feeling good", "it was sunny", "the meeting was long"
- FALSE for thinking/reflection: "thinking about", "wondering if", "considering"
- FALSE when user explicitly says: "note that", "just logging", "don't make this a task"
- Override detection based on user instructions

Here are the available categories:
- Personal: Personal life, social activities, family, hobbies, errands
- Work: Work-related activities, meetings, projects, professional tasks
- Health: Medical appointments, exercise, wellness, mental health
- Finance: Money management, purchases, banking, investments
- Misc: Random thoughts, observations, miscellaneous items

When deciding which category to use, consider both the name and the description for the best fit. Use specific categories over "Misc" whenever possible. Override category selection if user provides explicit instructions. Respond with a JSON object containing an "entries" array."""

# JSON schema for structured output
SCHEMA = {
    "type": "object",
    "properties": {
        "entries": {
            "type": "array",
            "description": "An array of text segments extracted from the input, each assigned a category.",
            "items": {
                "type": "object",
                "properties": {
                    "text_segment": {
                        "type": "string",
                        "description": "The specific portion of the input text relevant to this entry.",
                    },
                    "category": {
                        "type": "string",
                        "description": "The category assigned to this text segment.",
                        "enum": ["Personal", "Work", "Health", "Finance", "Misc"],
                    },
                    "is_task": {
                        "type": "boolean",
                        "description": "Whether this entry represents a task that can be completed.",
                    },
                },
                "required": ["text_segment", "category", "is_task"],
                "additionalProperties": False,
            },
        },
    },
    "required": ["entries"],
    "additionalProperties": False,
}

def load_test_cases():
    """Load test cases from the evaluation dataset"""
    eval_file = Path(__file__).parent / 'eval_dataset.jsonl'
    test_cases = []
    
    with open(eval_file, 'r') as f:
        for line in f:
            if line.strip():
                data = json.loads(line)
                test_cases.append(data['item'])
    
    return test_cases

def test_with_openai(input_text):
    """Test the prompt with OpenAI API"""
    try:
        response = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": input_text}
            ],
            response_format={
                "type": "json_schema",
                "json_schema": {
                    "name": "entry_extraction",
                    "schema": SCHEMA,
                    "strict": True
                }
            },
            temperature=0.1
        )
        
        result = json.loads(response.choices[0].message.content)
        return result["entries"]
    except Exception as e:
        print(f"Error: {e}")
        return None

def evaluate_single_case(test_case):
    """Evaluate a single test case"""
    input_text = test_case['input_text']
    expected_entries = test_case['expected_entries']
    
    # Test with OpenAI
    actual_entries = test_with_openai(input_text)
    
    if actual_entries is None:
        return False, "API error"
    
    # Compare results - for multi-entry cases, check if we got the right number
    if len(actual_entries) != len(expected_entries):
        return False, f"Entry count mismatch: got {len(actual_entries)}, expected {len(expected_entries)}"
    
    # Check each entry
    for i, (actual, expected) in enumerate(zip(actual_entries, expected_entries)):
        # Check category
        if actual['category'] != expected['category']:
            return False, f"Entry {i}: category mismatch - got '{actual['category']}', expected '{expected['category']}'"
        
        # Check task detection
        if actual['is_task'] != expected['is_task']:
            return False, f"Entry {i}: task mismatch - got {actual['is_task']}, expected {expected['is_task']}"
    
    return True, "Pass"

def main():
    print("🧪 Testing Improved Prompt Against Full Evaluation Dataset\n")
    print("=" * 70)
    
    # Load test cases
    test_cases = load_test_cases()
    print(f"Loaded {len(test_cases)} test cases\n")
    
    passed = 0
    failed = 0
    
    # Run each test case
    for i, test_case in enumerate(test_cases, 1):
        print(f"Test {i:2d}: {test_case['test_type']:<25}", end=" ")
        
        success, message = evaluate_single_case(test_case)
        
        if success:
            print("✅ Pass")
            passed += 1
        else:
            print(f"❌ Fail - {message}")
            failed += 1
            
            # Show details for failed cases
            print(f"         Input: '{test_case['input_text']}'")
            actual = test_with_openai(test_case['input_text'])
            if actual:
                print(f"         Expected: {test_case['expected_entries']}")
                print(f"         Actual:   {actual}")
            print()
    
    print("=" * 70)
    total = passed + failed
    pass_rate = (passed / total * 100) if total > 0 else 0
    print(f"📊 Results: {passed}/{total} tests passed ({pass_rate:.1f}% pass rate)")
    
    if pass_rate >= 50:
        print("🎉 Target achieved! Pass rate is above 50%")
    else:
        print("⚠️  More improvements needed to reach 50% pass rate")

if __name__ == "__main__":
    main()
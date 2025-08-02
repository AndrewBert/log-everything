#!/usr/bin/env python3
"""
Quick validation script for the improved AI prompt.
Tests specific failing cases from the evaluation to see if improvements work.
"""

import json
import os
from openai import OpenAI
from pathlib import Path

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

# The improved system prompt (copied from ai_service.dart)
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

CONTENT TRANSFORMATION:
- Clean up rambling thoughts into coherent, structured entries
- Fix grammar, spelling, and punctuation errors
- Remove filler words (um, uh, like, you know) while preserving meaning
- Convert run-on sentences into clear, concise statements
- Structure lists with proper formatting when multiple items are mentioned
- Group related thoughts into logical paragraphs
- Make content scannable and easy to read

ORGANIZATION RULES:
- STRONGLY PREFER keeping related content together as ONE entry
- Multiple sentences about the same topic should stay together
- Only split into separate entries for clearly unrelated activities
- When user gives an instruction about structure, follow it exactly

CRITICAL RULES:
- NEVER invent facts or add information not present in the input
- PRESERVE the user's core message, intent, and emotional tone
- When instructions conflict with content, follow the instructions
- Default to better organization even without explicit instructions
- Transform verbose rambling into clear, readable text

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
                        "description": "The category assigned to this text segment. Use only the category name from the provided list, not the description.",
                        "enum": ["Personal", "Work", "Health", "Finance", "Misc"],
                    },
                    "is_task": {
                        "type": "boolean",
                        "description": "Whether this entry represents a task, todo item, or action item that can be completed. True for actionable items like 'call mom', 'buy groceries', 'finish report'. False for observations, thoughts, or completed activities like 'had lunch', 'feeling good', 'it was sunny'.",
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

# Test cases targeting specific failing scenarios
TEST_CASES = [
    # Case 1: Health categorization instead of defaulting to Misc
    {
        "input": "Make this a to-do: call the dentist about my appointment",
        "expected": [{"text_segment": "Call the dentist about my appointment", "category": "Health", "is_task": True}],
        "focus": "Health categorization + instruction following"
    },
    # Case 2: Personal shopping instead of Misc  
    {
        "input": "Remind me to pick up groceries after work",
        "expected": [{"text_segment": "Pick up groceries after work", "category": "Personal", "is_task": True}],
        "focus": "Personal categorization for shopping"
    },
    # Case 3: Work categorization for meetings
    {
        "input": "File this under work: had a great lunch with friends at the new cafe",
        "expected": [{"text_segment": "Had a great lunch with friends at the new cafe", "category": "Work", "is_task": False}],
        "focus": "Category override instruction"
    },
    # Case 4: Don't make observations into tasks
    {
        "input": "I've been thinking about starting to exercise more because I've been feeling tired lately",
        "expected": [{"text_segment": "I've been thinking about starting to exercise more because I've been feeling tired lately", "category": "Health", "is_task": False}],
        "focus": "Thinking/reflection should not be task"
    },
    # Case 5: Single word shopping task
    {
        "input": "Groceries", 
        "expected": [{"text_segment": "Groceries", "category": "Personal", "is_task": True}],
        "focus": "Single word should be Personal shopping task"
    }
]

def test_prompt_with_openai(input_text):
    """Test the prompt with OpenAI API using structured output"""
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
            temperature=0.2
        )
        
        result = json.loads(response.choices[0].message.content)
        return result["entries"]
    except Exception as e:
        print(f"Error: {e}")
        return None

def compare_results(actual, expected):
    """Compare actual vs expected results"""
    if len(actual) != len(expected):
        return False, f"Entry count mismatch: got {len(actual)}, expected {len(expected)}"
    
    for i, (act, exp) in enumerate(zip(actual, expected)):
        if act["category"] != exp["category"]:
            return False, f"Entry {i}: category mismatch - got '{act['category']}', expected '{exp['category']}'"
        if act["is_task"] != exp["is_task"]:
            return False, f"Entry {i}: task mismatch - got {act['is_task']}, expected {exp['is_task']}"
    
    return True, "Match"

def main():
    print("🧪 Testing Improved AI Prompt\n")
    print("=" * 60)
    
    passed = 0
    total = len(TEST_CASES)
    
    for i, test_case in enumerate(TEST_CASES, 1):
        print(f"\nTest {i}: {test_case['focus']}")
        print(f"Input: '{test_case['input']}'")
        
        # Test with OpenAI
        actual = test_prompt_with_openai(test_case['input'])
        
        if actual is None:
            print("❌ Failed (API error)")
            continue
            
        # Compare results
        is_match, message = compare_results(actual, test_case['expected'])
        
        if is_match:
            print("✅ Passed")
            passed += 1
        else:
            print(f"❌ Failed: {message}")
            print(f"   Expected: {test_case['expected']}")
            print(f"   Actual:   {actual}")
    
    print("\n" + "=" * 60)
    print(f"📊 Results: {passed}/{total} tests passed ({passed/total*100:.1f}%)")
    
    if passed == total:
        print("🎉 All tests passed! The prompt improvements look good.")
    else:
        print("⚠️  Some tests failed. Consider further prompt refinements.")

if __name__ == "__main__":
    main()
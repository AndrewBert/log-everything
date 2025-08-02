#!/usr/bin/env python3
"""
OpenAI Evaluations with best practices applied for log entry extraction.
Based on OpenAI's eval design best practices guide.
"""

import json
import requests
import time
from pathlib import Path
from typing import Dict, Any, List

# Load API key from .env file
def load_api_key():
    env_path = Path(__file__).parent.parent.parent / '.env'
    if env_path.exists():
        with open(env_path, 'r') as f:
            for line in f:
                if line.startswith('OPENAI_API_KEY='):
                    return line.strip().split('=')[1]
    return None

API_KEY = load_api_key()
if not API_KEY:
    print("Error: OPENAI_API_KEY not found in .env file")
    exit(1)

BASE_URL = "https://api.openai.com/v1"
HEADERS = {
    "Authorization": f"Bearer {API_KEY}",
    "Content-Type": "application/json"
}

def create_evaluation() -> str:
    """Create an evaluation following best practices"""
    
    eval_config = {
        "name": "Log Entry AI - Best Practices v2",
        "data_source_config": {
            "type": "custom",
            "item_schema": {
                "type": "object",
                "properties": {
                    "input_text": {"type": "string"},
                    "expected_category": {"type": "string"},
                    "expected_is_task": {"type": "boolean"},
                    "expected_text": {"type": "string"},
                    "test_type": {"type": "string"},
                    "edge_case_type": {"type": "string"}
                },
                "required": ["input_text", "expected_category", "expected_is_task", "test_type"]
            },
            "include_sample_schema": True
        },
        "testing_criteria": [
            {
                "type": "label_model",
                "name": "Comprehensive Entry Evaluation",
                "model": "o3-mini",  # OpenAI recommends o3-mini for grading
                "input": [
                    {
                        "role": "developer",
                        "content": """You are evaluating an AI note-taking assistant. The assistant should output JSON with:
- "text": processed content
- "category": one of Personal, Work, Health, Finance, Misc
- "is_task": true if actionable, false if observation

GRADING RUBRIC:

Step 1 - Parse the output and check if it's valid JSON
Step 2 - Evaluate each criterion:

A. INSTRUCTION FOLLOWING (Critical)
- Did the AI follow explicit instructions like "make this a to-do", "file this under X"?
- If user said "make this a to-do", is_task MUST be true
- If user said "file this under [category]", category MUST match

B. CONTENT TRANSFORMATION (Important)
- Is the text appropriately cleaned and structured?
- Are filler words (um, uh, like) removed?
- Is rambling text made concise?
- Are lists properly formatted?

C. TASK DETECTION (Important)
- Actionable items (need to, should, must) → is_task: true
- Single words implying action (groceries, laundry) → is_task: true
- Completed activities (had lunch, went to store) → is_task: false
- Observations (weather was nice) → is_task: false

D. CATEGORY ASSIGNMENT (Important)
- Does the category match the content appropriately?
- Personal: daily life, family, shopping
- Work: meetings, projects, colleagues
- Health: medical, exercise, wellness
- Finance: money, bills, investments

Step 3 - Provide reasoning for your decision
Step 4 - Grade as "correct" if ALL critical criteria pass and at least 2/3 important criteria pass

Expected values:
- Category: {{ item.expected_category }}
- Is Task: {{ item.expected_is_task }}
- Test Type: {{ item.test_type }}"""
                    },
                    {
                        "role": "user", 
                        "content": """Original input: {{ item.input_text }}
Assistant output: {{ sample.output_text }}

Evaluate this output step by step."""
                    }
                ],
                "passing_labels": ["correct"],
                "labels": ["correct", "incorrect"]
            }
        ]
    }
    
    response = requests.post(
        f"{BASE_URL}/evals",
        headers=HEADERS,
        json=eval_config
    )
    
    if response.status_code in [200, 201]:
        result = response.json()
        print(f"✓ Created evaluation with ID: {result['id']}")
        return result['id']
    else:
        print(f"✗ Failed to create evaluation: {response.status_code}")
        print(response.text)
        exit(1)

def create_comprehensive_test_data() -> str:
    """Create test dataset following best practices with edge cases"""
    
    test_cases = [
        # HAPPY PATH CASES
        {
            "item": {
                "input_text": "Make this a to-do: call the dentist about my appointment",
                "expected_category": "Health",
                "expected_is_task": True,
                "expected_text": "Call the dentist about my appointment",
                "test_type": "instruction_following",
                "edge_case_type": "none"
            }
        },
        {
            "item": {
                "input_text": "Had a productive meeting with the team today",
                "expected_category": "Work",
                "expected_is_task": False,
                "expected_text": "Had a productive meeting with the team today",
                "test_type": "basic_logging",
                "edge_case_type": "none"
            }
        },
        
        # EDGE CASES - Input Variability
        {
            "item": {
                "input_text": "meting with clinet tommorow about bugdet",  # Typos
                "expected_category": "Work",
                "expected_is_task": False,
                "expected_text": "Meeting with client tomorrow about budget",
                "test_type": "typo_correction",
                "edge_case_type": "typos"
            }
        },
        {
            "item": {
                "input_text": "meeting",  # Minimal context
                "expected_category": "Work",
                "expected_is_task": False,
                "expected_text": "Meeting",
                "test_type": "minimal_context",
                "edge_case_type": "short_input"
            }
        },
        
        # EDGE CASES - Contextual Complexity
        {
            "item": {
                "input_text": "Need to call mom about dinner and also file this under personal but wait actually make it work related because it's a business dinner",
                "expected_category": "Work",  # Last instruction wins
                "expected_is_task": True,
                "expected_text": "Call mom about business dinner",
                "test_type": "multiple_conflicting_instructions",
                "edge_case_type": "conflicting_instructions"
            }
        },
        {
            "item": {
                "input_text": "Went to the store bought milk eggs bread oh and remind me to get batteries next time",
                "expected_category": "Personal",
                "expected_is_task": False,  # Mixed content, past tense dominates
                "expected_text": "Went to the store and bought milk, eggs, and bread. Reminder: get batteries next time",
                "test_type": "multiple_intents",
                "edge_case_type": "multiple_intents"
            }
        },
        
        # EDGE CASES - Instruction Conflicts
        {
            "item": {
                "input_text": "Don't make this a task but I need to call the doctor",
                "expected_category": "Health",
                "expected_is_task": False,  # Explicit instruction overrides "need to"
                "expected_text": "Need to call the doctor",
                "test_type": "conflicting_task_instruction",
                "edge_case_type": "instruction_conflict"
            }
        },
        {
            "item": {
                "input_text": "log this as health but it's about my work stress affecting sleep",
                "expected_category": "Health",  # Explicit category instruction
                "expected_is_task": False,
                "expected_text": "Work stress affecting sleep",
                "test_type": "category_override_complex",
                "edge_case_type": "category_conflict"
            }
        },
        
        # FORMATTING REQUESTS
        {
            "item": {
                "input_text": "Format as a list: buy milk eggs bread cheese",
                "expected_category": "Personal",
                "expected_is_task": True,
                "expected_text": "Shopping list:\n- Milk\n- Eggs\n- Bread\n- Cheese",
                "test_type": "formatting_request",
                "edge_case_type": "format_instruction"
            }
        },
        
        # EXTREME RAMBLING
        {
            "item": {
                "input_text": "So like I was thinking you know um maybe we should probably I mean if it's okay with everyone obviously but like consider possibly reviewing the quarterly report I mean the Q3 one specifically if that makes sense",
                "expected_category": "Work",
                "expected_is_task": False,
                "expected_text": "Consider reviewing the Q3 quarterly report",
                "test_type": "extreme_rambling",
                "edge_case_type": "verbose_input"
            }
        },
        
        # MULTILINGUAL (if supported)
        {
            "item": {
                "input_text": "Reminder: comprar leche y pan",  # Spanish
                "expected_category": "Personal",
                "expected_is_task": True,
                "expected_text": "Buy milk and bread",
                "test_type": "multilingual",
                "edge_case_type": "non_english"
            }
        },
        
        # PRODUCTION-LIKE SCENARIOS
        {
            "item": {
                "input_text": "ugh today was rough... meetings back to back, barely had time for lunch, and now I have to finish that report by tomorrow morning fml",
                "expected_category": "Work",
                "expected_is_task": False,  # Venting, not actionable
                "expected_text": "Rough day with back-to-back meetings, barely had time for lunch. Need to finish report by tomorrow morning.",
                "test_type": "real_world_venting",
                "edge_case_type": "emotional_content"
            }
        }
    ]
    
    # Write to temporary file
    temp_file = Path("best_practices_test_data.jsonl")
    with open(temp_file, "w") as f:
        for case in test_cases:
            f.write(json.dumps(case) + "\n")
    
    # Upload file
    with open(temp_file, "rb") as f:
        files = {"file": ("best_practices_test_data.jsonl", f, "application/jsonl")}
        data = {"purpose": "evals"}
        
        response = requests.post(
            f"{BASE_URL}/files",
            headers={"Authorization": f"Bearer {API_KEY}"},
            files=files,
            data=data
        )
    
    # Clean up temp file
    temp_file.unlink()
    
    if response.status_code in [200, 201]:
        result = response.json()
        print(f"✓ Uploaded file with ID: {result['id']} ({len(test_cases)} test cases)")
        return result['id']
    else:
        print(f"✗ Failed to upload file: {response.status_code}")
        print(response.text)
        exit(1)

def run_evaluation(eval_id: str, file_id: str) -> str:
    """Run evaluation with the actual system prompt"""
    
    # Get the actual system prompt from our AI service
    categories = ["Personal", "Work", "Health", "Finance", "Misc"]
    categories_list = "\n".join([f"- {cat}" for cat in categories])
    
    system_prompt = f"""You are an intelligent note-taking assistant helping organize a user's personal log. Your role is to:

1. LISTEN FOR INSTRUCTIONS in the user's input and execute them
2. ORGANIZE AND STRUCTURE content to improve readability
3. PRESERVE the user's meaning without adding false information

INSTRUCTION DETECTION:
- Detect natural language commands like:
  - "make this a to-do" / "make this a task" → set is_task: true
  - "file this under [category]" / "categorize as [category]" → override category selection
  - "summarize this as" → restructure content accordingly
  - "remind me to" / "I need to" → set is_task: true
  - "note that" / "log that" → process as observation (is_task: false)
  - "clean this up" → apply maximum structuring and organization
  - "keep this as is" → minimal changes, preserve original text
- Instructions can appear anywhere in the input
- Follow instructions even if they contradict normal categorization rules

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

TASK DETECTION:
For each entry, determine if it represents a task/todo item that can be completed:
- TRUE for actionable items: "call mom", "buy groceries", "finish the report", "schedule dentist appointment"
- TRUE for future intentions: "need to", "should", "must", "have to", "going to", "plan to"
- TRUE for instruction-triggered tasks: "make this a to-do", "remind me to"
- TRUE for single items that imply acquisition: "boots", "milk", "batteries" (assume these are shopping reminders)
- TRUE for action-oriented phrases: "oil change", "pick up dry cleaning", "return library books"
- FALSE for completed activities: "had lunch", "went to store", "called mom", "finished report"
- FALSE for observations: "feeling good", "it was sunny", "the meeting was long"
- FALSE when user explicitly says: "note that", "just logging", "not a task"
- Override detection based on user instructions

Here are the available categories:
{categories_list}

When deciding which category to use, consider both the name and the description for the best fit. Override category selection if user provides explicit instructions. Respond with a JSON object containing an "entries" array."""

    # For the evaluation, we'll simplify to single entry output
    simplified_prompt = system_prompt + """

For this evaluation, output a single JSON object (not an array) with:
{
  "text": "the processed content",
  "category": "the selected category",
  "is_task": true or false
}"""

    run_config = {
        "name": "Best Practices Eval Run",
        "data_source": {
            "type": "completions",
            "model": "gpt-4o-mini",
            "input_messages": {
                "type": "template", 
                "template": [
                    {"role": "developer", "content": simplified_prompt},
                    {"role": "user", "content": "{{ item.input_text }}"}
                ]
            },
            "source": {"type": "file_id", "id": file_id}
        },
        "metadata": {
            "eval_version": "2.0",
            "includes_edge_cases": "true",
            "grading_model": "o3-mini"
        }
    }
    
    response = requests.post(
        f"{BASE_URL}/evals/{eval_id}/runs",
        headers=HEADERS,
        json=run_config
    )
    
    if response.status_code in [200, 201]:
        result = response.json()
        print(f"✓ Started evaluation run with ID: {result['id']}")
        print(f"  View results at: {result.get('report_url', 'Check dashboard')}")
        return result['id']
    else:
        print(f"✗ Failed to create run: {response.status_code}")
        print(response.text)
        exit(1)

def check_run_status(eval_id: str, run_id: str):
    """Check the status of an evaluation run with detailed analysis"""
    
    response = requests.get(
        f"{BASE_URL}/evals/{eval_id}/runs/{run_id}",
        headers=HEADERS
    )
    
    if response.status_code == 200:
        result = response.json()
        print(f"\nRun Status: {result['status']}")
        
        if result.get('result_counts'):
            counts = result['result_counts']
            total = counts['total']
            passed = counts['passed'] 
            failed = counts['failed']
            errored = counts.get('errored', 0)
            
            if total > 0:
                pass_rate = (passed / total) * 100
                print(f"Results: {passed}/{total} passed ({pass_rate:.1f}%)")
                if errored > 0:
                    print(f"  ⚠️  {errored} tests errored")
            else:
                print(f"Results: Total={total}, Passed={passed}, Failed={failed}")
        
        # Get test type breakdown if available
        if result.get('metadata'):
            print(f"\nEval Metadata: {result['metadata']}")
            
        return result['status']
    else:
        print(f"✗ Failed to get run status: {response.status_code}")
        return None

def main():
    print("=== OpenAI Evaluation: Best Practices Implementation ===\n")
    print("This evaluation includes:")
    print("- ✓ Chain-of-thought reasoning in grading")
    print("- ✓ Comprehensive edge cases")
    print("- ✓ Production-like test scenarios")
    print("- ✓ Clear grading rubrics")
    print("- ✓ Better grading model (GPT-4.1-mini)\n")
    
    # Step 1: Create evaluation
    print("1. Creating evaluation with best practices...")
    eval_id = create_evaluation()
    
    # Step 2: Upload test data
    print("\n2. Uploading comprehensive test data with edge cases...")
    file_id = create_comprehensive_test_data()
    
    # Step 3: Run evaluation
    print("\n3. Running evaluation...")
    run_id = run_evaluation(eval_id, file_id)
    
    # Step 4: Poll for results
    print("\n4. Waiting for results...")
    max_attempts = 40  # More time for comprehensive eval
    for i in range(max_attempts):
        time.sleep(3)
        status = check_run_status(eval_id, run_id)
        
        if status in ['completed', 'failed', 'canceled']:
            break
        
        if i < max_attempts - 1:
            print(".", end="", flush=True)
    
    print(f"\n\n✨ Evaluation complete!")
    print(f"Eval ID: {eval_id}")
    print(f"Run ID: {run_id}")
    print("\nView detailed results in the OpenAI dashboard")
    print("\nNext steps:")
    print("1. Review which edge cases failed")
    print("2. Update the system prompt based on failures")
    print("3. Re-run evaluation to track improvement")

if __name__ == "__main__":
    main()
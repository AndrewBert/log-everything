#!/usr/bin/env python3
"""
Run OpenAI Evaluations with model-based grading for JSON outputs
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
    """Create an evaluation using model-based grading"""
    
    eval_config = {
        "name": "Log Entry AI - Model Graded",
        "data_source_config": {
            "type": "custom",
            "item_schema": {
                "type": "object",
                "properties": {
                    "input_text": {"type": "string"},
                    "expected_category": {"type": "string"},
                    "expected_is_task": {"type": "boolean"},
                    "expected_text": {"type": "string"},
                    "test_type": {"type": "string"}
                },
                "required": ["input_text", "expected_category", "expected_is_task", "expected_text"]
            },
            "include_sample_schema": True
        },
        "testing_criteria": [
            {
                "type": "label_model",
                "name": "Category and Task Detection",
                "model": "gpt-4o-mini",
                "input": [
                    {
                        "role": "developer",
                        "content": """You are evaluating an AI assistant's output. 
                        
The assistant should output JSON with:
- "text": processed content
- "category": one of Personal, Work, Health, Finance, Misc
- "is_task": true if it's actionable, false if it's an observation

Grade the output as "correct" if:
1. The category matches the expected category
2. The is_task value matches the expected value
3. The text is appropriately cleaned/structured

Otherwise grade as "incorrect".

Expected category: {{ item.expected_category }}
Expected is_task: {{ item.expected_is_task }}"""
                    },
                    {
                        "role": "user", 
                        "content": "Assistant output: {{ sample.output_text }}"
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

def upload_comprehensive_test_data() -> str:
    """Upload comprehensive test dataset"""
    
    # More comprehensive test cases
    test_cases = [
        # Instruction detection
        {
            "item": {
                "input_text": "Make this a to-do: call the dentist about my appointment",
                "expected_category": "Health",
                "expected_is_task": True,
                "expected_text": "Call the dentist about my appointment",
                "test_type": "instruction_detection"
            }
        },
        {
            "item": {
                "input_text": "Remind me to pick up groceries after work",
                "expected_category": "Personal",
                "expected_is_task": True,
                "expected_text": "Pick up groceries after work",
                "test_type": "instruction_detection"
            }
        },
        # Category override
        {
            "item": {
                "input_text": "File this under work: had a great lunch with friends", 
                "expected_category": "Work",
                "expected_is_task": False,
                "expected_text": "Had a great lunch with friends",
                "test_type": "category_override"
            }
        },
        # Content transformation
        {
            "item": {
                "input_text": "So like um I was thinking about maybe possibly starting to exercise more you know",
                "expected_category": "Health",
                "expected_is_task": False,
                "expected_text": "I've been thinking about starting to exercise more",
                "test_type": "content_transformation"
            }
        },
        # Task detection
        {
            "item": {
                "input_text": "Groceries",
                "expected_category": "Personal",
                "expected_is_task": True,
                "expected_text": "Groceries",
                "test_type": "single_word_task"
            }
        },
        {
            "item": {
                "input_text": "Had lunch with Sarah, it was nice",
                "expected_category": "Personal",
                "expected_is_task": False,
                "expected_text": "Had lunch with Sarah. It was nice.",
                "test_type": "observation"
            }
        },
        # Clean up instruction
        {
            "item": {
                "input_text": "Clean this up: so basically what happened was I went to the meeting and um they said we need to revamp the system",
                "expected_category": "Work",
                "expected_is_task": False,
                "expected_text": "Attended the meeting where they announced we need to revamp the system",
                "test_type": "cleanup_instruction"
            }
        },
        # Multiple related items
        {
            "item": {
                "input_text": "Need to call mom and also dad about the family dinner",
                "expected_category": "Personal",
                "expected_is_task": True,
                "expected_text": "Call mom and dad about the family dinner",
                "test_type": "combined_task"
            }
        }
    ]
    
    # Write to temporary file
    temp_file = Path("comprehensive_test_data.jsonl")
    with open(temp_file, "w") as f:
        for case in test_cases:
            f.write(json.dumps(case) + "\n")
    
    # Upload file
    with open(temp_file, "rb") as f:
        files = {"file": ("comprehensive_test_data.jsonl", f, "application/jsonl")}
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
    """Create and run an evaluation using the actual system prompt"""
    
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
        "name": "Comprehensive Test - Instruction Following",
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
    """Check the status of an evaluation run"""
    
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
            
            if total > 0:
                pass_rate = (passed / total) * 100
                print(f"Results: {passed}/{total} passed ({pass_rate:.1f}%)")
            else:
                print(f"Results: Total={total}, Passed={passed}, Failed={failed}")
            
        if result.get('per_testing_criteria_results'):
            print("\nPer-criteria results:")
            for criteria in result['per_testing_criteria_results']:
                print(f"  {criteria['testing_criteria']}: {criteria['passed']} passed, {criteria['failed']} failed")
                
        return result['status']
    else:
        print(f"✗ Failed to get run status: {response.status_code}")
        return None

def main():
    print("=== OpenAI Evaluation: Log Entry AI Assistant ===\n")
    
    # Step 1: Create evaluation
    print("1. Creating model-graded evaluation...")
    eval_id = create_evaluation()
    
    # Step 2: Upload test data
    print("\n2. Uploading comprehensive test data...")
    file_id = upload_comprehensive_test_data()
    
    # Step 3: Run evaluation
    print("\n3. Running evaluation with actual system prompt...")
    run_id = run_evaluation(eval_id, file_id)
    
    # Step 4: Poll for results
    print("\n4. Waiting for results...")
    max_attempts = 30
    for i in range(max_attempts):
        time.sleep(2)
        status = check_run_status(eval_id, run_id)
        
        if status in ['completed', 'failed', 'canceled']:
            break
        
        if i < max_attempts - 1:
            print(".", end="", flush=True)
    
    print(f"\n\n✨ Evaluation complete!")
    print(f"Eval ID: {eval_id}")
    print(f"Run ID: {run_id}")
    print("\nView detailed results in the OpenAI dashboard")

if __name__ == "__main__":
    main()
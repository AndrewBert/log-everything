#!/usr/bin/env python3
"""
Compare different OpenAI models on the evaluation dataset
"""

import json
import time
import requests
from pathlib import Path
from typing import Dict, List, Tuple

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

# Models to test
MODELS = [
    "gpt-4o-mini",
    "gpt-4.1-nano-2025-04-14",
    "gpt-4.1-mini-2025-04-14",
    "gpt-4.1-2025-04-14"
]

def create_evaluation() -> str:
    """Create an evaluation for model comparison"""
    
    eval_config = {
        "name": f"Model Comparison - {time.strftime('%Y-%m-%d %H:%M')}",
        "data_source_config": {
            "type": "custom",
            "item_schema": {
                "type": "object",
                "properties": {
                    "input_text": {"type": "string"},
                    "expected_category": {"type": "string"},
                    "expected_is_task": {"type": "boolean"},
                    "test_type": {"type": "string"}
                },
                "required": ["input_text", "expected_category", "expected_is_task", "test_type"]
            },
            "include_sample_schema": True
        },
        "testing_criteria": [
            {
                "type": "label_model",
                "name": "Model Comparison Evaluation",
                "model": "o3-mini",
                "input": [
                    {
                        "role": "developer",
                        "content": """Evaluate if the AI correctly:
1. Followed instructions (if any)
2. Assigned the correct category
3. Correctly identified if it's a task

Grade as "correct" if category and task detection match expected values."""
                    },
                    {
                        "role": "user", 
                        "content": """Input: {{ item.input_text }}
Expected Category: {{ item.expected_category }}
Expected Is Task: {{ item.expected_is_task }}
Assistant output: {{ sample.output_text }}"""
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
        return result['id']
    else:
        print(f"Failed to create evaluation: {response.status_code}")
        print(response.text)
        exit(1)

def upload_test_data() -> str:
    """Upload focused test dataset"""
    
    # Focus on the problematic test cases
    test_cases = [
        {
            "item": {
                "input_text": "Make this a to-do: call the dentist about my appointment",
                "expected_category": "Health",
                "expected_is_task": True,
                "test_type": "instruction_with_health"
            }
        },
        {
            "item": {
                "input_text": "ugh today was rough... meetings back to back, barely had time for lunch, and now I have to finish that report by tomorrow morning fml",
                "expected_category": "Work",
                "expected_is_task": False,
                "test_type": "venting"
            }
        },
        {
            "item": {
                "input_text": "So like I was thinking you know um maybe we should probably I mean if it's okay with everyone obviously but like consider possibly reviewing the quarterly report I mean the Q3 one specifically if that makes sense",
                "expected_category": "Work",
                "expected_is_task": False,
                "test_type": "non_committal"
            }
        },
        {
            "item": {
                "input_text": "meting with clinet tommorow about bugdet",
                "expected_category": "Work",
                "expected_is_task": True,
                "test_type": "typo_reminder"
            }
        },
        {
            "item": {
                "input_text": "Went to the store bought milk eggs bread oh and remind me to get batteries next time",
                "expected_category": "Personal",
                "expected_is_task": True,
                "test_type": "mixed_with_reminder"
            }
        }
    ]
    
    temp_file = Path("model_comparison_data.jsonl")
    with open(temp_file, "w") as f:
        for case in test_cases:
            f.write(json.dumps(case) + "\n")
    
    with open(temp_file, "rb") as f:
        files = {"file": ("model_comparison_data.jsonl", f, "application/jsonl")}
        data = {"purpose": "evals"}
        
        response = requests.post(
            f"{BASE_URL}/files",
            headers={"Authorization": f"Bearer {API_KEY}"},
            files=files,
            data=data
        )
    
    temp_file.unlink()
    
    if response.status_code == 200:
        result = response.json()
        return result['id']
    else:
        print(f"Failed to upload file: {response.status_code}")
        print(response.text)
        exit(1)

def run_evaluation_for_model(eval_id: str, file_id: str, model: str) -> Tuple[str, Dict]:
    """Run evaluation for a specific model"""
    
    # Get the system prompt (simplified version)
    categories = [
        "Personal: Personal life, social activities, family, hobbies, errands",
        "Work: Work-related activities, meetings, projects, professional tasks", 
        "Health: Medical appointments, exercise, wellness, mental health",
        "Finance: Money management, purchases, banking, investments",
        "Misc: Random thoughts, observations, miscellaneous items"
    ]
    categories_list = "\n".join([f"- {cat}" for cat in categories])
    
    system_prompt = f"""You are an intelligent note-taking assistant helping organize a user's personal log. Your role is to:

1. LISTEN FOR INSTRUCTIONS in the user's input and execute them
2. ORGANIZE AND STRUCTURE content to improve readability
3. PRESERVE the user's meaning without adding false information

INSTRUCTION DETECTION (HIGHEST PRIORITY):
- Detect natural language commands like:
  - "make this a to-do" / "make this a task" → set is_task: true
  - "file this under [category]" / "categorize as [category]" → override category selection
  - For instructions like "make this a to-do: call the dentist", apply BOTH the task instruction AND proper categorization
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
Choose the category that best matches the content's primary purpose, domain, or context. Consider these universal principles:

1. SPECIFICITY OVER GENERALITY: Always prefer more specific categories over broad ones
2. PRIMARY PURPOSE: Categorize based on the main intent or domain of the activity
3. CONTEXT MATCHING: Look for keywords, phrases, or concepts that align with category descriptions
4. LOGICAL GROUPING: Similar activities should consistently use the same category
5. USER PREFERENCE: Follow any explicit categorization instructions from the user


For minimal context (single words like "meeting", "groceries"), use the most likely category based on the word's typical context.
When categorizing, consider domain-specific terms that naturally belong to certain categories.

Use the most general/catch-all category (often "Misc" or similar) ONLY as a last resort when no other category reasonably fits the content.

TASK DETECTION (BE VERY CONSERVATIVE - DEFAULT TO FALSE):
For each entry, determine if it represents a task/todo item that can be completed:

TRUE only for:
- Explicit future actions with clear intent: "I need to call mom", "must buy groceries", "should finish the report"
- Direct imperatives or reminders: "remind me to", "don't forget to", "make sure to"
- Instruction-triggered tasks: "make this a to-do", "add this to my tasks"
- Single shopping items WITHOUT context: "groceries", "milk", "batteries" (assume these are reminders)
- Action phrases with future tense: "will call", "going to schedule", "planning to meet"

FALSE for:
- ANY past tense or completed actions: "went to", "bought", "called", "had", "finished"
- Observations or states: "feeling tired", "work stress affecting sleep", "budget discussion"
- Thinking/considering WITHOUT commitment: "thinking about", "maybe should", "considering"
- Venting about existing work: negative tone + "have to" or "need to" about current obligations
- Just thinking or considering: "maybe we should", "thinking about", "considering"
- ALWAYS FALSE when user says: "don't make this a task", "just logging", "note that"

TRUE for future events/appointments:
- "meeting tomorrow", "appointment at 3pm", "lunch with client" (these are reminders)
- "meeting with client tomorrow about budget" (reminder for scheduled event)

When in doubt, default to FALSE. Only mark as TRUE when there's a clear, uncommitted action to be taken.

Here are the available categories:
{categories_list}

When deciding which category to use, consider both the name and the description for the best fit. Use specific categories over "Misc" whenever possible. Override category selection if user provides explicit instructions.

Respond with a JSON object like:
{{
  "text": "the processed content",
  "category": "Category name",
  "is_task": true/false
}}"""
    
    run_config = {
        "name": f"Model Test - {model}",
        "data_source": {
            "type": "completions",
            "model": model,
            "input_messages": {
                "type": "template", 
                "template": [
                    {"role": "developer", "content": system_prompt},
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
        run_id = result['id']
        
        # Poll for results
        print(f"  Running evaluation for {model}...", end="", flush=True)
        for _ in range(30):
            time.sleep(2)
            
            status_response = requests.get(
                f"{BASE_URL}/evals/{eval_id}/runs/{run_id}",
                headers=HEADERS
            )
            
            if status_response.status_code == 200:
                status_result = status_response.json()
                if status_result['status'] in ['completed', 'failed', 'canceled']:
                    print(f" {status_result['status']}")
                    return run_id, status_result
            print(".", end="", flush=True)
        
        print(" timeout")
        return run_id, {"status": "timeout"}
    else:
        print(f"  Failed to create run for {model}: {response.status_code}")
        return None, {"status": "error"}

def main():
    print("=== Model Comparison Evaluation ===\n")
    
    # Create evaluation
    print("1. Creating evaluation...")
    eval_id = create_evaluation()
    print(f"   Created evaluation: {eval_id}")
    
    # Upload test data
    print("\n2. Uploading test data...")
    file_id = upload_test_data()
    print(f"   Uploaded file: {file_id}")
    
    # Test each model
    print("\n3. Testing models...")
    results = {}
    
    for model in MODELS:
        run_id, result = run_evaluation_for_model(eval_id, file_id, model)
        if run_id:
            results[model] = result
    
    # Display results
    print("\n=== RESULTS ===")
    print(f"{'Model':<30} {'Pass Rate':<15} {'Status'}")
    print("-" * 60)
    
    for model in MODELS:
        if model in results:
            result = results[model]
            if result.get('result_counts'):
                counts = result['result_counts']
                total = counts['total']
                passed = counts['passed']
                pass_rate = f"{passed}/{total} ({passed/total*100:.1f}%)" if total > 0 else "N/A"
            else:
                pass_rate = "N/A"
            status = result.get('status', 'unknown')
            print(f"{model:<30} {pass_rate:<15} {status}")
    
    print("\n✅ Model comparison complete!")
    print(f"View detailed results at: https://platform.openai.com/evaluations/{eval_id}")

if __name__ == "__main__":
    main()
#!/usr/bin/env python3
"""
Run evaluation with the expanded dataset from eval_dataset.jsonl
"""

import json
import time
import requests
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
        "name": "Log Entry AI - Expanded Dataset Evaluation",
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
                    "instruction": {"type": "string"}
                },
                "required": ["input_text", "expected_category", "expected_is_task", "expected_text", "test_type"]
            },
            "include_sample_schema": True
        },
        "testing_criteria": [
            {
                "type": "label_model",
                "name": "Comprehensive Entry Evaluation",
                "model": "o3-mini",
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
- Aspirations without commitment (would like to, hoping to) → is_task: false

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

def load_and_upload_dataset() -> str:
    """Load test dataset from eval_dataset.jsonl and convert to evaluation format"""
    
    # Load test cases from eval_dataset.jsonl
    dataset_path = Path(__file__).parent / "eval_dataset.jsonl"
    test_cases = []
    
    with open(dataset_path, "r") as f:
        for line in f:
            if line.strip():
                data = json.loads(line)
                item = data["item"]
                
                # Convert to evaluation format expected by API
                # For tests with multiple entries, we'll evaluate just the first one for simplicity
                expected_entry = item["expected_entries"][0]
                
                eval_case = {
                    "item": {
                        "input_text": item["input_text"],
                        "expected_category": expected_entry["category"],
                        "expected_is_task": expected_entry["is_task"],
                        "expected_text": expected_entry["text_segment"],
                        "test_type": item["test_type"],
                        "instruction": item.get("instruction", "")
                    }
                }
                test_cases.append(eval_case)
    
    # Write to temporary file
    temp_file = Path("expanded_test_data.jsonl")
    with open(temp_file, "w") as f:
        for case in test_cases:
            f.write(json.dumps(case) + "\n")
    
    # Upload file
    with open(temp_file, "rb") as f:
        files = {"file": ("expanded_test_data.jsonl", f, "application/jsonl")}
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
    """Run evaluation with the actual system prompt from our AI service"""
    
    # Get the actual categories from production
    categories = [
        "Personal: Personal life, social activities, family, hobbies, errands",
        "Work: Work-related activities, meetings, projects, professional tasks", 
        "Health: Medical appointments, exercise, wellness, mental health",
        "Finance: Money management, purchases, banking, investments",
        "Misc: Random thoughts, observations, miscellaneous items"
    ]
    categories_list = "\n".join([f"- {cat}" for cat in categories])
    
    # Load the actual system prompt from ai_service.dart
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
A task must be an actionable commitment that can be checked off a todo list.

TRUE only for:
- Clear commitments to specific actions: "I need to", "must", "will", "going to"
- Direct imperatives: "remind me to", "don't forget to"
- User instructions: "make this a to-do"
- Single items that are clearly reminders: "groceries", "dentist appointment"

FALSE for:
- Past actions (already done)
- Current states or observations
- Aspirations without commitment: "would like to", "hoping to", "want to someday"
- Venting about obligations (complaining tone + "have to")
- Vague considerations: "thinking about", "maybe", "considering"

TRUE for future events/appointments:
- "meeting tomorrow", "appointment at 3pm", "lunch with client" (these are reminders)
- "meeting with client tomorrow about budget" (reminder for scheduled event)

When in doubt, default to FALSE. Only mark as TRUE when there's a clear, uncommitted action to be taken.

Here are the available categories:
{categories_list}

When deciding which category to use, consider both the name and the description for the best fit. Use specific categories over "Misc" whenever possible. Override category selection if user provides explicit instructions."""

    # For the evaluation, we'll simplify to single entry output
    simplified_prompt = system_prompt + """

For this evaluation, output a single JSON object (not an array) with:
{
  "text": "the processed content",
  "category": "the selected category",
  "is_task": true or false
}"""

    run_config = {
        "name": "Expanded Dataset Eval Run",
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
            "eval_version": "3.0",
            "dataset": "expanded_61_cases",
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
    """Check the status of an evaluation run"""
    
    response = requests.get(
        f"{BASE_URL}/evals/{eval_id}/runs/{run_id}",
        headers=HEADERS
    )
    
    if response.status_code == 200:
        result = response.json()
        status = result.get('status', 'unknown')
        print(f"\nRun Status: {status}")
        
        # Show results if available
        if 'results' in result:
            results = result['results']
            total = results.get('total_samples', 0)
            passed = results.get('samples_graded', 0) - results.get('samples_failed', 0)
            if total > 0:
                print(f"Results: {passed}/{total} passed ({passed/total*100:.1f}%)")
            else:
                print(f"Results: Total={total}, Passed={passed}, Failed={results.get('samples_failed', 0)}")
        
        # Show metadata
        if 'metadata' in result:
            print(f"\nEval Metadata: {result['metadata']}")
            
        return status
    else:
        print(f"Failed to check status: {response.status_code}")
        return None

def main():
    print("=== OpenAI Evaluation: Expanded Dataset (61 test cases) ===\n")
    print("This evaluation includes:")
    print("- ✓ Comprehensive task detection patterns")
    print("- ✓ Real-world complexity scenarios")
    print("- ✓ Edge cases and ambiguities")
    print("- ✓ Production-like test data")
    print("- ✓ Better grading model (o3-mini)\n")
    
    # Step 1: Create evaluation
    print("1. Creating evaluation...")
    eval_id = create_evaluation()
    
    # Step 2: Upload test data
    print("\n2. Loading and uploading expanded dataset...")
    file_id = load_and_upload_dataset()
    
    # Step 3: Run evaluation
    print("\n3. Running evaluation...")
    run_id = run_evaluation(eval_id, file_id)
    
    # Step 4: Poll for results
    print("\n4. Waiting for results...")
    max_attempts = 60  # More time for larger dataset
    for i in range(max_attempts):
        time.sleep(5)
        status = check_run_status(eval_id, run_id)
        
        if status in ['completed', 'failed', 'canceled']:
            break
        
        print(".", end="", flush=True)
    
    print(f"\n\n✨ Evaluation complete!")
    print(f"Eval ID: {eval_id}")
    print(f"Run ID: {run_id}")
    print("\nView detailed results in the OpenAI dashboard")
    print("\nNext steps:")
    print("1. Use fetch_eval_results.py to get detailed failure analysis")
    print("2. Update the AI prompt based on failures")
    print("3. Re-run evaluation to track improvement")

if __name__ == "__main__":
    main()
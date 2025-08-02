#!/usr/bin/env python3
"""
Run OpenAI Evaluations using the HTTP API directly for log entry extraction testing.
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
    """Create an evaluation for testing log entry extraction"""
    
    eval_config = {
        "name": "Log Entry Extraction - Instruction & Transform",
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
                "type": "string_check",
                "name": "Output Contains Category",
                "input": "{{ sample.output_text }}",
                "operation": "like",
                "reference": "*{{ item.expected_category }}*"
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

def upload_test_data() -> str:
    """Upload test dataset file"""
    
    # Create test data
    test_cases = [
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
                "input_text": "Had a great meeting with the team today, very productive",
                "expected_category": "Work", 
                "expected_is_task": False,
                "expected_text": "Had a great meeting with the team today. Very productive.",
                "test_type": "content_cleanup"
            }
        },
        {
            "item": {
                "input_text": "Remind me to buy groceries milk eggs bread",
                "expected_category": "Personal",
                "expected_is_task": True,
                "expected_text": "Buy groceries: milk, eggs, bread",
                "test_type": "instruction_and_structure"
            }
        },
        {
            "item": {
                "input_text": "So like um I was thinking we should probably review the quarterly report",
                "expected_category": "Work",
                "expected_is_task": False,
                "expected_text": "We should review the quarterly report",
                "test_type": "filler_removal"
            }
        },
        {
            "item": {
                "input_text": "File this under personal: work was stressful today", 
                "expected_category": "Personal",
                "expected_is_task": False,
                "expected_text": "Work was stressful today",
                "test_type": "category_override"
            }
        }
    ]
    
    # Write to temporary file
    temp_file = Path("eval_test_data.jsonl")
    with open(temp_file, "w") as f:
        for case in test_cases:
            f.write(json.dumps(case) + "\n")
    
    # Upload file
    with open(temp_file, "rb") as f:
        files = {"file": ("eval_test_data.jsonl", f, "application/jsonl")}
        data = {"purpose": "evals"}
        
        response = requests.post(
            f"{BASE_URL}/files",
            headers={"Authorization": f"Bearer {API_KEY}"},
            files=files,
            data=data
        )
    
    # Clean up temp file
    temp_file.unlink()
    
    if response.status_code == 200:
        result = response.json()
        print(f"✓ Uploaded file with ID: {result['id']}")
        return result['id']
    else:
        print(f"✗ Failed to upload file: {response.status_code}")
        print(response.text)
        exit(1)

def run_evaluation(eval_id: str, file_id: str) -> str:
    """Create and run an evaluation"""
    
    # System prompt matching the updated AI service
    system_prompt = """You are an intelligent note-taking assistant. Extract and process user input following these rules:

1. LISTEN FOR INSTRUCTIONS like "make this a to-do", "remind me to", "file this under"
2. CLEAN UP text by removing filler words and improving structure
3. DETECT if it's a task (actionable) or observation

Respond with JSON:
{
  "text": "the processed content",
  "category": "Personal|Work|Health|Finance|Misc",
  "is_task": true/false
}"""

    run_config = {
        "name": "Test Run - Instruction Following",
        "data_source": {
            "type": "completions",
            "model": "gpt-4o-mini",
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
        print(f"✓ Started evaluation run with ID: {result['id']}")
        print(f"  View results at: {result.get('report_url', 'No URL provided')}")
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
            print(f"Results: Total={counts['total']}, Passed={counts['passed']}, Failed={counts['failed']}")
            
        if result.get('per_testing_criteria_results'):
            print("\nPer-criteria results:")
            for criteria in result['per_testing_criteria_results']:
                print(f"  {criteria['testing_criteria']}: {criteria['passed']} passed, {criteria['failed']} failed")
                
        return result['status']
    else:
        print(f"✗ Failed to get run status: {response.status_code}")
        return None

def main():
    print("=== OpenAI Evaluation for Log Entry Extraction ===\n")
    
    # Step 1: Create evaluation
    print("1. Creating evaluation...")
    eval_id = create_evaluation()
    
    # Step 2: Upload test data
    print("\n2. Uploading test data...")
    file_id = upload_test_data()
    
    # Step 3: Run evaluation
    print("\n3. Running evaluation...")
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
    
    print(f"\n\nEvaluation complete!")
    print(f"Eval ID: {eval_id}")
    print(f"Run ID: {run_id}")

if __name__ == "__main__":
    main()
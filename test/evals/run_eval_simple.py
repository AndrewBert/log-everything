#!/usr/bin/env python3
"""
Simplified OpenAI Eval script for testing log entry extraction.
This follows the exact pattern from the OpenAI documentation.
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

# Step 1: Create the evaluation
def create_evaluation():
    eval_response = client.evals.create(
        name="Log Entry Extraction Eval",
        data_source_config={
            "type": "custom",
            "item_schema": {
                "type": "object",
                "properties": {
                    "input_text": {"type": "string"},
                    "expected_category": {"type": "string"},
                    "expected_is_task": {"type": "boolean"},
                    "expected_output": {"type": "string"}
                },
                "required": ["input_text", "expected_category", "expected_is_task", "expected_output"]
            },
            "include_sample_schema": True
        },
        testing_criteria=[
            {
                "type": "string_check",
                "name": "Category Match",
                "input": "{{ sample.category }}",
                "operation": "eq",
                "reference": "{{ item.expected_category }}"
            }
        ]
    )
    
    print(f"Created eval with ID: {eval_response.id}")
    return eval_response.id

# Step 2: Create simple test data
def create_test_data():
    # Create a simple test dataset
    test_data = [
        {
            "item": {
                "input_text": "Make this a to-do: call the dentist",
                "expected_category": "Health",
                "expected_is_task": True,
                "expected_output": "Call the dentist"
            }
        },
        {
            "item": {
                "input_text": "Had a great meeting with the team today",
                "expected_category": "Work",
                "expected_is_task": False,
                "expected_output": "Had a great meeting with the team today"
            }
        },
        {
            "item": {
                "input_text": "Remind me to buy groceries",
                "expected_category": "Personal",
                "expected_is_task": True,
                "expected_output": "Buy groceries"
            }
        }
    ]
    
    # Write to file
    with open("simple_test_data.jsonl", "w") as f:
        for item in test_data:
            f.write(json.dumps(item) + "\n")
    
    print("Created test data file")

# Step 3: Upload the file
def upload_file():
    with open("simple_test_data.jsonl", "rb") as f:
        file_response = client.files.create(
            file=f,
            purpose="evals"
        )
    print(f"Uploaded file with ID: {file_response.id}")
    return file_response.id

# Step 4: Run the evaluation
def run_eval(eval_id, file_id):
    # Simplified system prompt focused on categorization
    system_prompt = """You are a log entry categorizer. Given user input, extract the main content and categorize it.
    
Categories: Personal, Work, Health, Finance, Misc

If the user says "make this a to-do" or "remind me to", extract just the task content.
Respond with a JSON object containing:
{
  "output": "the processed content",
  "category": "the category",
  "is_task": true/false
}"""

    run_response = client.evals.runs.create(
        eval_id,
        name="Simple Categorization Run",
        data_source={
            "type": "responses",
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
    )
    
    print(f"Started eval run with ID: {run_response.id}")
    print(f"View results at: {run_response.report_url}")
    return run_response.id

# Check status
def check_status(eval_id, run_id):
    run = client.evals.runs.retrieve(eval_id, run_id)
    print(f"\nStatus: {run.status}")
    if run.result_counts:
        print(f"Results: Total={run.result_counts.total}, Passed={run.result_counts.passed}, Failed={run.result_counts.failed}")

def main():
    print("OpenAI Eval Setup for Log Entry Extraction\n")
    
    # Create test data
    create_test_data()
    
    # Create evaluation
    eval_id = create_evaluation()
    
    # Upload file
    file_id = upload_file()
    
    # Run evaluation
    run_id = run_eval(eval_id, file_id)
    
    print(f"\nTo check status, run:")
    print(f"python {__file__} --check {eval_id} {run_id}")

if __name__ == "__main__":
    import sys
    
    if len(sys.argv) > 1 and sys.argv[1] == "--check":
        if len(sys.argv) != 4:
            print("Usage: python run_eval_simple.py --check <eval_id> <run_id>")
            sys.exit(1)
        check_status(sys.argv[2], sys.argv[3])
    else:
        main()
#!/usr/bin/env python3
"""
Script to run OpenAI Evaluations for the log entry extraction AI assistant.

Prerequisites:
1. Set OPENAI_API_KEY environment variable
2. Run convert_tests_to_eval_format.dart to generate eval_dataset.jsonl
3. Ensure you have the OpenAI Python SDK installed: pip install openai
"""

import json
import os
from openai import OpenAI
from typing import List, Dict, Any

# Initialize OpenAI client
client = OpenAI()

def create_eval_for_entry_extraction():
    """Create an evaluation for testing the entry extraction system"""
    
    # Define the evaluation configuration
    eval_config = {
        "name": "Log Entry Extraction - Instruction Following & Content Transform",
        "data_source_config": {
            "type": "custom",
            "item_schema": {
                "type": "object",
                "properties": {
                    "input_text": {"type": "string"},
                    "expected_entries": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "text_segment": {"type": "string"},
                                "category": {"type": "string"},
                                "is_task": {"type": "boolean"}
                            },
                            "required": ["text_segment", "category", "is_task"]
                        }
                    },
                    "test_type": {"type": "string"},
                    "instruction": {"type": "string"}
                },
                "required": ["input_text", "expected_entries", "test_type"]
            },
            "include_sample_schema": True
        },
        "testing_criteria": [
            {
                "type": "string_check",
                "name": "Correct number of entries",
                "input": "{{ sample.entries | length }}",
                "operation": "eq",
                "reference": "{{ item.expected_entries | length }}"
            }
        ]
    }
    
    # Create the evaluation
    eval_obj = client.evals.create(**eval_config)
    print(f"Created evaluation with ID: {eval_obj.id}")
    return eval_obj.id

def upload_test_dataset(file_path: str) -> str:
    """Upload the test dataset file"""
    with open(file_path, "rb") as f:
        file_obj = client.files.create(
            file=f,
            purpose="evals"
        )
    print(f"Uploaded file with ID: {file_obj.id}")
    return file_obj.id

def run_evaluation(eval_id: str, file_id: str, categories: List[str]):
    """Run the evaluation with the uploaded dataset"""
    
    # Get the system prompt from the Dart file
    system_prompt = get_system_prompt(categories)
    
    # Create eval run configuration
    # Note: The text/format configuration goes at the model level, not in data_source
    run_config = {
        "name": "Entry Extraction Test Run",
        "data_source": {
            "type": "responses",
            "model": "gpt-4o-mini",  # Using the same model as in the Dart code
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
    
    # Create the run
    run = client.evals.runs.create(eval_id, **run_config)
    print(f"Started evaluation run with ID: {run.id}")
    print(f"View results at: {run.report_url}")
    return run.id

def get_system_prompt(categories: List[str]) -> str:
    """Generate the system prompt (matching the Dart implementation)"""
    categories_list = "\n".join([f"- {cat}" for cat in categories])
    
    return f"""You are an intelligent note-taking assistant helping organize a user's personal log. Your role is to:

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

def get_json_schema(categories: List[str]) -> Dict[str, Any]:
    """Generate the JSON schema for structured output"""
    return {
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
                            "description": "The specific portion of the input text relevant to this entry."
                        },
                        "category": {
                            "type": "string",
                            "description": "The category assigned to this text segment.",
                            "enum": categories
                        },
                        "is_task": {
                            "type": "boolean",
                            "description": "Whether this entry represents a task or action item."
                        }
                    },
                    "required": ["text_segment", "category", "is_task"],
                    "additionalProperties": False
                }
            }
        },
        "required": ["entries"],
        "additionalProperties": False
    }

def check_run_status(eval_id: str, run_id: str):
    """Check the status of an evaluation run"""
    run = client.evals.runs.retrieve(eval_id, run_id)
    print(f"\nRun Status: {run.status}")
    print(f"Results: {run.result_counts}")
    if run.per_testing_criteria_results:
        for criteria in run.per_testing_criteria_results:
            print(f"  {criteria['testing_criteria']}: {criteria['passed']} passed, {criteria['failed']} failed")

def main():
    # Configuration
    categories = ["Personal", "Work", "Health", "Finance", "Misc"]
    dataset_path = "test/evals/eval_dataset.jsonl"
    
    print("Starting OpenAI Evaluation for Log Entry Extraction\n")
    
    # Step 1: Create the evaluation
    eval_id = create_eval_for_entry_extraction()
    
    # Step 2: Upload the test dataset
    if not os.path.exists(dataset_path):
        print(f"Error: Dataset file not found at {dataset_path}")
        print("Please run 'dart run test/evals/convert_tests_to_eval_format.dart' first")
        return
    
    file_id = upload_test_dataset(dataset_path)
    
    # Step 3: Run the evaluation
    run_id = run_evaluation(eval_id, file_id, categories)
    
    print("\nEvaluation started successfully!")
    print(f"Eval ID: {eval_id}")
    print(f"Run ID: {run_id}")
    print("\nYou can check the status by running:")
    print(f"python {__file__} --check {eval_id} {run_id}")

if __name__ == "__main__":
    import sys
    
    if len(sys.argv) > 1 and sys.argv[1] == "--check":
        if len(sys.argv) != 4:
            print("Usage: python run_openai_eval.py --check <eval_id> <run_id>")
            sys.exit(1)
        check_run_status(sys.argv[2], sys.argv[3])
    else:
        main()
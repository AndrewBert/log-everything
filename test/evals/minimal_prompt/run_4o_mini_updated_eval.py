#!/usr/bin/env python3
"""
Run evaluation with gpt-4o-mini on the updated test dataset
"""

import json
import time
from datetime import datetime
from openai import OpenAI
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

client = OpenAI()

# Read the current iteration 7 prompt from ai_service.dart
with open('/Users/andrew/Development/log-everything/lib/services/ai_service.dart', 'r') as f:
    content = f.read()
    
# Extract the system prompt (iteration 7)
start = content.find('// CC: MINIMAL PROMPT EXPERIMENT - Iteration 7')
end = content.find('Respond with a JSON object containing an "entries" array.""";')
if start == -1 or end == -1:
    print("Could not find iteration 7 prompt in ai_service.dart")
    exit(1)

# Get the prompt content
prompt_lines = content[start:end].split('\n')
# Remove comment lines and reconstruct
system_prompt_lines = []
for line in prompt_lines[3:]:  # Skip first 3 lines (comments)
    if 'final systemPrompt =' in line:
        continue
    if '"""' in line:
        line = line.replace('"""', '').strip()
    system_prompt_lines.append(line)

# Clean up the prompt
system_prompt = '\n'.join(system_prompt_lines).strip()

# Add the actual categories that would be provided in production
categories = [
    "- Personal: Personal life, social activities, family, hobbies, errands",
    "- Work: Work-related activities, meetings, projects, professional tasks", 
    "- Health: Medical appointments, exercise, wellness, mental health",
    "- Finance: Money management, purchases, banking, investments",
    "- Misc: Random thoughts, observations, miscellaneous items"
]
categories_string = "\n".join(categories)

# Replace the placeholder with actual categories
system_prompt = system_prompt.replace("$categoriesListString", categories_string)

print("=== GPT-4o-mini Evaluation with Updated Dataset (Iteration 7) ===")
print(f"System prompt length: {len(system_prompt)} chars")
print()

# Read test dataset
with open('../eval_dataset.jsonl', 'r') as f:
    test_cases = [json.loads(line) for line in f if line.strip()]

# Track results
results = {
    "total": len(test_cases),
    "passed": 0,
    "failed": 0,
    "failures": [],
    "start_time": datetime.now().isoformat()
}

start_time = time.time()

# Test each case
for i, test in enumerate(test_cases):
    item = test["item"]
    input_text = item["input_text"]
    expected = item["expected_entries"]
    test_type = item.get("test_type", "unknown")
    
    print(f"Testing case {i+1}/{len(test_cases)}: {input_text[:60]}...")
    
    try:
        # Call Responses API with gpt-4o-mini
        import requests
        
        response = requests.post(
            'https://api.openai.com/v1/responses',
            json={
                'model': 'gpt-4o-mini',
                'input': [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": input_text}
                ],
                'text': {
                    'format': {
                        'type': 'json_schema',
                        'name': 'multiple_entry_extraction',
                        'schema': {
                            "type": "object",
                            "properties": {
                                "entries": {
                                    "type": "array",
                                    "items": {
                                        "type": "object",
                                        "properties": {
                                            "text_segment": {"type": "string"},
                                            "category": {"type": "string"},
                                            "is_task": {"type": "boolean"},
                                        },
                                        "required": ["text_segment", "category", "is_task"],
                                        "additionalProperties": False,
                                    },
                                },
                            },
                            "required": ["entries"],
                            "additionalProperties": False,
                        },
                        'strict': True
                    },
                },
                'temperature': 0,
            },
            headers={
                'Content-Type': 'application/json',
                'Authorization': f'Bearer {client.api_key}',
            }
        )
        
        # Parse Responses API response
        response_json = response.json()
        
        if response_json.get('status') != 'completed':
            raise Exception(f"API request failed: {response_json}")
            
        # Extract the JSON from the response
        entries = []
        if response_json.get('output'):
            for output_item in response_json['output']:
                if output_item['type'] == 'message' and output_item.get('content'):
                    for content_item in output_item['content']:
                        if content_item['type'] == 'output_text':
                            result = json.loads(content_item['text'])
                            entries = result.get("entries", [])
                            break
        
        # Check if response matches expected
        passed = True
        if len(entries) != len(expected):
            passed = False
        else:
            for j, (actual, exp) in enumerate(zip(entries, expected)):
                if (actual.get("text_segment", "").strip() == "" or
                    actual.get("category") != exp["category"] or
                    actual.get("is_task") != exp["is_task"]):
                    passed = False
                    break
        
        if passed:
            print(f"  ✅ Passed")
            results["passed"] += 1
        else:
            actual_cat = entries[0]['category'] if entries else 'None'
            actual_task = entries[0]['is_task'] if entries else 'None'
            print(f"  ❌ Failed - Expected: {expected[0]['category']}/{expected[0]['is_task']}, " +
                  f"Got: {actual_cat}/{actual_task} (entries: {len(entries)})")
            results["failed"] += 1
            results["failures"].append({
                "input": input_text,
                "expected_category": expected[0]["category"],
                "expected_is_task": expected[0]["is_task"],
                "actual_category": entries[0]["category"] if entries else None,
                "actual_is_task": entries[0]["is_task"] if entries else None,
                "test_type": test_type
            })
    
    except Exception as e:
        print(f"  ❌ Error: {str(e)}")
        results["failed"] += 1
        results["failures"].append({
            "input": input_text,
            "error": str(e),
            "test_type": test_type
        })
    
    # Show progress every 10 tests
    if (i + 1) % 10 == 0:
        print(f"\nProgress: {i+1}/{len(test_cases)} ({results['passed']/(i+1)*100:.1f}% pass rate so far)")
        print(f"Elapsed time: {(time.time() - start_time)/60:.1f} minutes\n")

# Final results
results["end_time"] = datetime.now().isoformat()
results["pass_rate"] = (results["passed"] / results["total"]) * 100

print("\n" + "="*60)
print("FINAL RESULTS")
print("="*60)
print(f"Total: {results['total']} tests")
print(f"Passed: {results['passed']}")
print(f"Failed: {results['failed']}")
print(f"Pass Rate: {results['pass_rate']:.1f}%")
print(f"\nTotal time: {(time.time() - start_time)/60:.1f} minutes")

# Save results
with open('4o_mini_updated_results.json', 'w') as f:
    json.dump(results, f, indent=2)

print("\nResults saved to 4o_mini_updated_results.json")

# Show failures
if results["failures"]:
    print("\nFailures:")
    for f in results["failures"][:10]:  # Show first 10
        print(f"- {f['input'][:50]}... (expected {f.get('expected_category')}/{f.get('expected_is_task')})")
    if len(results["failures"]) > 10:
        print(f"... and {len(results['failures']) - 10} more")
#!/usr/bin/env python3
"""
Run COMPLETE evaluation with gpt-5 (full model) on all test cases
With extended timeouts and better error handling
"""

import json
import time
from datetime import datetime
from openai import OpenAI
from dotenv import load_dotenv
import sys

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

# Define the JSON schema for structured outputs
schema = {
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
}

print("="*70)
print("GPT-5 (FULL MODEL) COMPLETE EVALUATION")
print("="*70)
print(f"System prompt length: {len(system_prompt)} chars")
print("Note: This will take a while. Each request has a 30-second timeout.")
print("="*70)
print()

# Read test dataset
with open('../eval_dataset.jsonl', 'r') as f:
    test_cases = [json.loads(line) for line in f if line.strip()]

print(f"Loaded {len(test_cases)} test cases")
print()

# Track results
results = {
    "model": "gpt-5",
    "total": len(test_cases),
    "passed": 0,
    "failed": 0,
    "timeouts": 0,
    "errors": 0,
    "failures": [],
    "response_times": [],
    "start_time": datetime.now().isoformat()
}

start_time = time.time()
test_start_time = time.time()

# Test each case
for i, test in enumerate(test_cases):
    item = test["item"]
    input_text = item["input_text"]
    expected = item["expected_entries"]
    test_type = item.get("test_type", "unknown")
    
    # Progress indicator
    print(f"[{i+1:3}/{len(test_cases)}] Testing: {input_text[:50]:50}... ", end="")
    sys.stdout.flush()
    
    request_start = time.time()
    
    try:
        # Call Responses API with gpt-5 with extended timeout
        import requests
        
        response = requests.post(
            'https://api.openai.com/v1/responses',
            json={
                'model': 'gpt-5',
                'input': [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": input_text}
                ],
                'text': {
                    'format': {
                        'type': 'json_schema',
                        'name': 'multiple_entry_extraction',
                        'schema': schema,
                        'strict': True
                    },
                },
            },
            headers={
                'Content-Type': 'application/json',
                'Authorization': f'Bearer {client.api_key}',
            },
            timeout=30  # 30 second timeout per request
        )
        
        request_time = time.time() - request_start
        results["response_times"].append(request_time)
        
        # Parse Responses API response
        response_json = response.json()
        
        if response_json.get('status') != 'completed':
            print(f"❌ API Error ({request_time:.1f}s)")
            results["errors"] += 1
            results["failures"].append({
                "input": input_text,
                "error": str(response_json.get('error', 'Unknown error')),
                "test_type": test_type
            })
            continue
            
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
            print(f"✅ Pass ({request_time:.1f}s)")
            results["passed"] += 1
        else:
            actual_cat = entries[0]['category'] if entries else 'None'
            actual_task = entries[0]['is_task'] if entries else 'None'
            print(f"❌ Fail: {actual_cat}/{actual_task} ({request_time:.1f}s)")
            results["failed"] += 1
            results["failures"].append({
                "input": input_text,
                "expected_category": expected[0]["category"],
                "expected_is_task": expected[0]["is_task"],
                "actual_category": entries[0]["category"] if entries else None,
                "actual_is_task": entries[0]["is_task"] if entries else None,
                "test_type": test_type,
                "entries_count": len(entries),
                "expected_count": len(expected)
            })
    
    except requests.Timeout:
        print(f"⏱️ TIMEOUT (30s)")
        results["timeouts"] += 1
        results["failures"].append({
            "input": input_text,
            "error": "Request timeout (30s)",
            "test_type": test_type
        })
        
    except Exception as e:
        print(f"❌ Exception: {str(e)[:30]}")
        results["errors"] += 1
        results["failures"].append({
            "input": input_text,
            "error": str(e),
            "test_type": test_type
        })
    
    # Progress update every 5 tests
    if (i + 1) % 5 == 0:
        elapsed = time.time() - start_time
        tests_completed = i + 1
        avg_time = elapsed / tests_completed
        remaining = (len(test_cases) - tests_completed) * avg_time
        
        print(f"\n  Progress: {tests_completed}/{len(test_cases)} completed")
        print(f"  Pass rate so far: {results['passed']}/{tests_completed} = {results['passed']/tests_completed*100:.1f}%")
        print(f"  Elapsed: {elapsed/60:.1f} min | Est. remaining: {remaining/60:.1f} min")
        print()

# Calculate final statistics
results["end_time"] = datetime.now().isoformat()
results["total_time_seconds"] = time.time() - start_time
results["total_time_minutes"] = results["total_time_seconds"] / 60

if results["response_times"]:
    results["avg_response_time"] = sum(results["response_times"]) / len(results["response_times"])
    results["min_response_time"] = min(results["response_times"])
    results["max_response_time"] = max(results["response_times"])
else:
    results["avg_response_time"] = None

results["pass_rate"] = (results["passed"] / results["total"]) * 100 if results["total"] > 0 else 0

# Print final results
print("\n" + "="*70)
print("FINAL RESULTS - GPT-5 (FULL MODEL)")
print("="*70)
print(f"Total tests:     {results['total']}")
print(f"Passed:          {results['passed']} ({results['passed']/results['total']*100:.1f}%)")
print(f"Failed:          {results['failed']} ({results['failed']/results['total']*100:.1f}%)")
print(f"Timeouts:        {results['timeouts']} ({results['timeouts']/results['total']*100:.1f}%)")
print(f"Errors:          {results['errors']} ({results['errors']/results['total']*100:.1f}%)")
print()
print(f"Pass Rate:       {results['pass_rate']:.1f}%")
print()
print("Timing Statistics:")
print(f"Total time:      {results['total_time_minutes']:.1f} minutes")
if results["avg_response_time"]:
    print(f"Avg per test:    {results['avg_response_time']:.1f} seconds")
    print(f"Min time:        {results['min_response_time']:.1f} seconds")
    print(f"Max time:        {results['max_response_time']:.1f} seconds")
print("="*70)

# Save results
with open('gpt5_full_complete_results.json', 'w') as f:
    json.dump(results, f, indent=2)

print(f"\nDetailed results saved to gpt5_full_complete_results.json")

# Show some failure examples
if results["failures"]:
    print("\nExample failures (first 5):")
    for i, f in enumerate(results["failures"][:5]):
        if 'error' in f:
            print(f"  {i+1}. '{f['input'][:40]}...' - Error: {f['error'][:50]}")
        else:
            print(f"  {i+1}. '{f['input'][:40]}...' - Expected: {f.get('expected_category')}/{f.get('expected_is_task')}, Got: {f.get('actual_category')}/{f.get('actual_is_task')}")
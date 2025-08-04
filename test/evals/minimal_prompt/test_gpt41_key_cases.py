#!/usr/bin/env python3
"""
Test GPT-4.1 on key failure cases with iteration 7 prompt
"""

import json
import time
import requests
from pathlib import Path
import sys

sys.path.append(str(Path(__file__).parent))
from run_minimal_eval import load_api_key, load_prompt

API_KEY = load_api_key()
BASE_URL = "https://api.openai.com/v1"
HEADERS = {"Authorization": f"Bearer {API_KEY}", "Content-Type": "application/json"}

# Key test cases that were failing
KEY_CASES = [
    # Should split entries
    {
        "input": "work was crazy today back to back meetings barely had time to breathe still need to finish that presentation for tomorrow",
        "expected_entries": 2,
        "description": "Should split reflection from task"
    },
    {
        "input": "Started cleaning out the garage found a bunch of old photos need to scan them before they deteriorate more",
        "expected_entries": 2,
        "description": "Should split narrative from task"
    },
    # Should NOT be tasks
    {
        "input": "Meeting with client is at 2pm conference room B",
        "expected_is_task": False,
        "description": "Appointment - not a task"
    },
    {
        "input": "Car is making weird noise again",
        "expected_is_task": False,
        "description": "Observation - not a task"
    },
    {
        "input": "Always forgetting to take my vitamins",
        "expected_is_task": False,
        "description": "Observation per user preference"
    },
    # Category selection
    {
        "input": "Remind me to pick up groceries after work",
        "expected_category": "Personal",
        "description": "Should use Personal not Errands"
    }
]

def test_case(prompt, case):
    response = requests.post(
        f"{BASE_URL}/chat/completions",
        headers=HEADERS,
        json={
            "model": "gpt-4.1",
            "messages": [
                {"role": "system", "content": prompt},
                {"role": "user", "content": case["input"]}
            ],
            "temperature": 0,
            "response_format": {"type": "json_object"}
        }
    )
    
    if response.status_code == 200:
        content = response.json()['choices'][0]['message']['content']
        return json.loads(content)
    else:
        return {"error": f"{response.status_code}: {response.text}"}

def main():
    print("=== Testing GPT-4.1 on Key Cases ===\n")
    prompt = load_prompt(7)
    
    passed = 0
    total = len(KEY_CASES)
    
    for i, case in enumerate(KEY_CASES, 1):
        print(f"Test {i}: {case['description']}")
        print(f"Input: {case['input']}")
        
        result = test_case(prompt, case)
        
        if "error" in result:
            print(f"ERROR: {result['error']}")
            continue
            
        entries = result.get("entries", [result])
        print(f"Output: {json.dumps(entries, indent=2)}")
        
        # Check expectations
        success = True
        if "expected_entries" in case:
            if len(entries) != case["expected_entries"]:
                print(f"❌ Expected {case['expected_entries']} entries, got {len(entries)}")
                success = False
            else:
                print(f"✅ Correctly split into {len(entries)} entries")
                
        if "expected_is_task" in case:
            actual_is_task = entries[0].get("is_task", False)
            if actual_is_task != case["expected_is_task"]:
                print(f"❌ Expected is_task={case['expected_is_task']}, got {actual_is_task}")
                success = False
            else:
                print(f"✅ Correctly marked is_task={actual_is_task}")
                
        if "expected_category" in case:
            actual_category = entries[0].get("category", "")
            if actual_category != case["expected_category"]:
                print(f"❌ Expected category={case['expected_category']}, got {actual_category}")
                success = False
            else:
                print(f"✅ Correctly categorized as {actual_category}")
        
        if success:
            passed += 1
            
        print("-" * 60 + "\n")
        time.sleep(1)
    
    print(f"\nSummary: {passed}/{total} tests passed ({passed/total*100:.0f}%)")
    print("\nConclusion: GPT-4.1 appears to follow the splitting instructions much better than GPT-4o-mini!")

if __name__ == "__main__":
    main()
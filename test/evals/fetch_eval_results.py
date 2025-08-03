#!/usr/bin/env python3
"""
Fetch detailed results from an evaluation run
"""

import json
import requests
from pathlib import Path
from typing import Dict, Any

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

def fetch_output_items(eval_id: str, run_id: str):
    """Fetch all output items from an eval run"""
    
    print(f"Fetching results for eval run: {run_id}\n")
    
    # Get output items
    response = requests.get(
        f"{BASE_URL}/evals/{eval_id}/runs/{run_id}/output_items",
        headers=HEADERS,
        params={"limit": 50}  # Get all items
    )
    
    if response.status_code != 200:
        print(f"Error fetching output items: {response.status_code}")
        print(response.text)
        return
    
    result = response.json()
    items = result.get('data', [])
    
    print(f"Found {len(items)} test results\n")
    
    # Analyze results
    passed = []
    failed = []
    
    for item in items:
        status = item.get('status')
        test_input = item.get('datasource_item', {})
        sample = item.get('sample', {})
        
        if status == 'pass':
            passed.append(item)
        else:
            failed.append(item)
            
            # Print failure details
            print(f"❌ FAILED Test #{item.get('datasource_item_id', 'unknown')}")
            print(f"   Input: {test_input.get('input_text', 'N/A')}")
            print(f"   Expected Category: {test_input.get('expected_category', 'N/A')}")
            print(f"   Expected Is Task: {test_input.get('expected_is_task', 'N/A')}")
            print(f"   Test Type: {test_input.get('test_type', 'N/A')}")
            
            # Get actual output
            if sample and 'output' in sample:
                output_messages = sample.get('output', [])
                if output_messages and len(output_messages) > 0:
                    actual_output = output_messages[0].get('content', 'No output')
                    print(f"   Actual Output: {actual_output}")
                    
                    # Try to parse JSON to show what the model actually produced
                    try:
                        parsed = json.loads(actual_output)
                        print(f"   → Category: {parsed.get('category', 'N/A')}")
                        print(f"   → Is Task: {parsed.get('is_task', 'N/A')}")
                        print(f"   → Text: {parsed.get('text', 'N/A')}")
                    except:
                        pass
            
            # Get grader results
            results = item.get('results', [])
            if results:
                for r in results:
                    print(f"   Grader: {r.get('name', 'Unknown')} - Score: {r.get('score', 'N/A')}")
            
            print()
    
    # Summary
    print(f"\n📊 SUMMARY:")
    print(f"   Passed: {len(passed)} tests")
    print(f"   Failed: {len(failed)} tests")
    print(f"   Total: {len(items)} tests")
    if len(items) > 0:
        print(f"   Pass Rate: {(len(passed) / len(items)) * 100:.1f}%")
    
    # Show which test types failed
    print(f"\n📋 FAILED TEST TYPES:")
    failed_types = {}
    for item in failed:
        test_type = item.get('datasource_item', {}).get('test_type', 'unknown')
        failed_types[test_type] = failed_types.get(test_type, 0) + 1
    
    for test_type, count in sorted(failed_types.items()):
        print(f"   {test_type}: {count} failures")

def main():
    import sys
    
    if len(sys.argv) != 3:
        print("Usage: python fetch_eval_results.py <eval_id> <run_id>")
        print("Example: python fetch_eval_results.py eval_688f48f275f88191b11acac9f23ac730 evalrun_688f48f3840c819196fb3865e941a768")
        sys.exit(1)
    
    eval_id = sys.argv[1]
    run_id = sys.argv[2]
    
    fetch_output_items(eval_id, run_id)

if __name__ == "__main__":
    main()
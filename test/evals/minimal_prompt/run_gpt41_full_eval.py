#!/usr/bin/env python3
"""
Run full evaluation with GPT-4.1 - handles timeouts and saves progress
"""

import json
import time
import requests
from pathlib import Path
import sys
from datetime import datetime

sys.path.append(str(Path(__file__).parent))
from run_minimal_eval import load_api_key, load_prompt

API_KEY = load_api_key()
BASE_URL = "https://api.openai.com/v1"
HEADERS = {"Authorization": f"Bearer {API_KEY}", "Content-Type": "application/json"}

def test_single_case(prompt, test_case, timeout=30):
    """Test a single case with timeout handling"""
    try:
        response = requests.post(
            f"{BASE_URL}/chat/completions",
            headers=HEADERS,
            json={
                "model": "gpt-4.1",
                "messages": [
                    {"role": "system", "content": prompt},
                    {"role": "user", "content": test_case["input_text"]}
                ],
                "temperature": 0,
                "response_format": {"type": "json_object"}
            },
            timeout=timeout
        )
        
        if response.status_code == 200:
            content = response.json()['choices'][0]['message']['content']
            return json.loads(content), None
        else:
            return None, f"API Error {response.status_code}: {response.text[:100]}"
    except requests.Timeout:
        return None, "Timeout"
    except Exception as e:
        return None, str(e)

def save_progress(results, filename="gpt41_progress.json"):
    """Save progress to file"""
    with open(filename, "w") as f:
        json.dump(results, f, indent=2)

def load_progress(filename="gpt41_progress.json"):
    """Load previous progress if exists"""
    if Path(filename).exists():
        with open(filename, "r") as f:
            return json.load(f)
    return {}

def main():
    print("=== GPT-4.1 Full Evaluation (Iteration 7) ===")
    print("This will take a while. Progress is saved automatically.\n")
    
    # Load prompt and test cases
    prompt = load_prompt(7)
    dataset_path = Path(__file__).parent.parent / "eval_dataset.jsonl"
    
    test_cases = []
    with open(dataset_path, "r") as f:
        for line in f:
            if line.strip():
                data = json.loads(line)
                test_cases.append(data["item"])
    
    # Load previous progress
    progress = load_progress()
    if progress:
        print(f"Resuming from previous run. {len(progress)} cases already completed.\n")
    
    results = {
        "total": len(test_cases),
        "completed": len(progress),
        "passed": 0,
        "failed": 0,
        "errors": 0,
        "failures": [],
        "start_time": progress.get("start_time", datetime.now().isoformat())
    }
    
    # Test each case
    for i, test_case in enumerate(test_cases):
        case_id = f"case_{i}"
        
        # Skip if already completed
        if case_id in progress:
            result_data = progress[case_id]
            if result_data["passed"]:
                results["passed"] += 1
            else:
                results["failed"] += 1
                if "failure" in result_data:
                    results["failures"].append(result_data["failure"])
            continue
        
        print(f"\nTesting case {i+1}/{len(test_cases)}: {test_case['input_text'][:50]}...")
        start_time = time.time()
        
        output, error = test_single_case(prompt, test_case)
        
        if error:
            print(f"  Error: {error}")
            results["errors"] += 1
            progress[case_id] = {"passed": False, "error": error}
        else:
            # Check against expected values
            expected_entry = test_case["expected_entries"][0]
            
            # Handle both single entry and array formats
            if isinstance(output, dict) and "entries" in output:
                actual_entries = output["entries"]
            elif isinstance(output, list):
                actual_entries = output
            else:
                actual_entries = [output]
            
            # For now, check the first entry
            actual_entry = actual_entries[0] if actual_entries else {}
            
            category_match = actual_entry.get("category") == expected_entry["category"]
            task_match = actual_entry.get("is_task") == expected_entry["is_task"]
            
            passed = category_match and task_match
            
            if passed:
                results["passed"] += 1
                print(f"  ✅ Passed (took {time.time()-start_time:.1f}s)")
            else:
                results["failed"] += 1
                failure = {
                    "input": test_case["input_text"],
                    "expected_category": expected_entry["category"],
                    "expected_is_task": expected_entry["is_task"],
                    "actual_category": actual_entry.get("category"),
                    "actual_is_task": actual_entry.get("is_task"),
                    "test_type": test_case.get("test_type", "unknown")
                }
                results["failures"].append(failure)
                print(f"  ❌ Failed - Expected: {expected_entry['category']}/{expected_entry['is_task']}, Got: {actual_entry.get('category')}/{actual_entry.get('is_task')} (took {time.time()-start_time:.1f}s)")
            
            progress[case_id] = {
                "passed": passed,
                "output": output,
                "failure": failure if not passed else None
            }
        
        # Save progress after each case
        results["completed"] = len(progress)
        save_progress(progress)
        
        # Show overall progress
        if (i + 1) % 5 == 0:
            pass_rate = (results["passed"] / results["completed"] * 100) if results["completed"] > 0 else 0
            print(f"\nProgress: {results['completed']}/{results['total']} ({pass_rate:.1f}% pass rate so far)")
            elapsed = (datetime.now() - datetime.fromisoformat(results["start_time"])).total_seconds() / 60
            print(f"Elapsed time: {elapsed:.1f} minutes")
        
        # Small delay to avoid rate limits
        time.sleep(0.5)
    
    # Final results
    results["end_time"] = datetime.now().isoformat()
    results["pass_rate"] = (results["passed"] / results["total"] * 100) if results["total"] > 0 else 0
    
    print("\n" + "="*60)
    print("FINAL RESULTS")
    print("="*60)
    print(f"Total: {results['total']} tests")
    print(f"Passed: {results['passed']}")
    print(f"Failed: {results['failed']}")
    print(f"Errors: {results['errors']}")
    print(f"Pass Rate: {results['pass_rate']:.1f}%")
    
    # Save final results
    with open("gpt41_iteration7_results.json", "w") as f:
        json.dump(results, f, indent=2)
    
    print(f"\nResults saved to gpt41_iteration7_results.json")
    print("Progress saved to gpt41_progress.json")

if __name__ == "__main__":
    main()
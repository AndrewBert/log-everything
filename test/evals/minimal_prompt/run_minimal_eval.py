#!/usr/bin/env python3
"""
Run evaluation with minimal prompt iterations
"""

import json
import time
import requests
from pathlib import Path
from typing import Dict, List, Tuple
import sys

# Add parent directory to path to import from test/evals
sys.path.append(str(Path(__file__).parent.parent))

# Load API key from .env file
def load_api_key():
    env_path = Path(__file__).parent.parent.parent.parent / '.env'
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

def load_prompt(iteration: int = 0) -> str:
    """Load the prompt for a specific iteration"""
    if iteration == 0:
        prompt_file = Path(__file__).parent / "baseline_prompt.txt"
    else:
        prompt_file = Path(__file__).parent / f"iteration_{iteration}_prompt.txt"
    
    if prompt_file.exists():
        prompt_text = prompt_file.read_text()
        
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
        if "$categoriesListString" in prompt_text:
            prompt_text = prompt_text.replace("$categoriesListString", categories_string)
        elif "Categories available:" in prompt_text and not any(cat in prompt_text for cat in ["Personal", "Work", "Health"]):
            # Add categories after "Categories available:" if not already present
            prompt_text = prompt_text.replace("Categories available:", f"Categories available:\n{categories_string}")
        
        return prompt_text
    else:
        print(f"Error: Prompt file not found: {prompt_file}")
        exit(1)

def test_prompt_on_dataset(prompt: str, save_results: bool = True, iteration: int = 0) -> Dict:
    """Test a prompt against the full dataset"""
    
    # Load test cases
    dataset_path = Path(__file__).parent.parent / "eval_dataset.jsonl"
    test_cases = []
    
    with open(dataset_path, "r") as f:
        for line in f:
            if line.strip():
                data = json.loads(line)
                test_cases.append(data["item"])
    
    # Test each case
    results = {
        "total": len(test_cases),
        "passed": 0,
        "failed": 0,
        "errors": 0,
        "failures": [],
        "failure_types": {}
    }
    
    print(f"\nTesting {len(test_cases)} cases...")
    
    for i, test_case in enumerate(test_cases):
        try:
            # Make API call
            response = requests.post(
                f"{BASE_URL}/chat/completions",
                headers=HEADERS,
                json={
                    "model": "gpt-4.1",  # Testing with GPT-4.1
                    "messages": [
                        {"role": "system", "content": prompt},
                        {"role": "user", "content": test_case["input_text"]}
                    ],
                    "temperature": 0,
                    "response_format": {"type": "json_object"}
                }
            )
            
            if response.status_code == 200:
                result = response.json()
                content = result['choices'][0]['message']['content']
                
                try:
                    output = json.loads(content)
                    
                    # Check against expected values
                    expected_entry = test_case["expected_entries"][0]
                    category_match = output.get("category") == expected_entry["category"]
                    task_match = output.get("is_task") == expected_entry["is_task"]
                    
                    if category_match and task_match:
                        results["passed"] += 1
                    else:
                        results["failed"] += 1
                        
                        # Track failure details
                        failure = {
                            "input": test_case["input_text"],
                            "expected_category": expected_entry["category"],
                            "expected_is_task": expected_entry["is_task"],
                            "actual_category": output.get("category"),
                            "actual_is_task": output.get("is_task"),
                            "test_type": test_case.get("test_type", "unknown")
                        }
                        results["failures"].append(failure)
                        
                        # Count failure types
                        test_type = test_case.get("test_type", "unknown")
                        if test_type not in results["failure_types"]:
                            results["failure_types"][test_type] = 0
                        results["failure_types"][test_type] += 1
                        
                except json.JSONDecodeError:
                    results["errors"] += 1
                    print(f"JSON decode error for case {i+1}")
            else:
                results["errors"] += 1
                print(f"API error for case {i+1}: {response.status_code}")
                
        except Exception as e:
            results["errors"] += 1
            print(f"Error testing case {i+1}: {str(e)}")
        
        # Progress indicator
        if (i + 1) % 10 == 0:
            print(f"Progress: {i+1}/{len(test_cases)}")
        
        # Rate limiting
        time.sleep(0.5)
    
    # Calculate pass rate
    results["pass_rate"] = (results["passed"] / results["total"] * 100) if results["total"] > 0 else 0
    
    # Save results if requested
    if save_results:
        results_file = Path(__file__).parent / "results" / f"iteration_{iteration}_results.json"
        with open(results_file, "w") as f:
            json.dump(results, f, indent=2)
    
    return results

def analyze_failures(results: Dict) -> None:
    """Analyze and print failure patterns"""
    print("\n=== FAILURE ANALYSIS ===")
    print(f"Total failures: {results['failed']}")
    
    # Sort failure types by count
    failure_types = sorted(results["failure_types"].items(), key=lambda x: x[1], reverse=True)
    
    print("\nFailures by test type:")
    for test_type, count in failure_types[:10]:  # Top 10
        print(f"  {test_type}: {count} failures")
    
    # Analyze category vs task failures
    category_failures = 0
    task_failures = 0
    both_failures = 0
    
    for failure in results["failures"]:
        cat_wrong = failure["expected_category"] != failure["actual_category"]
        task_wrong = failure["expected_is_task"] != failure["actual_is_task"]
        
        if cat_wrong and task_wrong:
            both_failures += 1
        elif cat_wrong:
            category_failures += 1
        elif task_wrong:
            task_failures += 1
    
    print(f"\nFailure breakdown:")
    print(f"  Category only: {category_failures}")
    print(f"  Task only: {task_failures}")
    print(f"  Both wrong: {both_failures}")
    
    # Show sample failures
    print("\nSample failures (first 5):")
    for i, failure in enumerate(results["failures"][:5]):
        print(f"\n{i+1}. Input: {failure['input']}")
        print(f"   Expected: category={failure['expected_category']}, is_task={failure['expected_is_task']}")
        print(f"   Actual: category={failure['actual_category']}, is_task={failure['actual_is_task']}")

def main():
    """Run evaluation with minimal prompt"""
    import sys
    
    # Check if specific iteration requested
    if len(sys.argv) > 1:
        iteration = int(sys.argv[1])
        run_single_iteration(iteration)
    else:
        # Run iteration 0 by default
        run_single_iteration(0)

def run_single_iteration(iteration: int):
    """Run a single iteration of the evaluation"""
    print("=== Minimal Prompt Evaluation ===")
    
    if iteration == 0:
        print(f"\n--- Iteration {iteration}: Baseline ---")
    else:
        print(f"\n--- Iteration {iteration} ---")
    
    prompt = load_prompt(iteration)
    print(f"Prompt size: {len(prompt.split())} words, {len(prompt.splitlines())} lines")
    
    results = test_prompt_on_dataset(prompt, save_results=True, iteration=iteration)
    
    print(f"\nResults:")
    print(f"  Passed: {results['passed']}/{results['total']}")
    print(f"  Failed: {results['failed']}")
    print(f"  Errors: {results['errors']}")
    print(f"  Pass Rate: {results['pass_rate']:.1f}%")
    
    # Compare to previous iteration if not baseline
    if iteration > 0:
        prev_results_file = Path(__file__).parent / "results" / f"iteration_{iteration-1}_results.json"
        if prev_results_file.exists():
            with open(prev_results_file) as f:
                prev_results = json.load(f)
            improvement = results['pass_rate'] - prev_results['pass_rate']
            print(f"  Improvement: {improvement:+.1f}% from iteration {iteration-1}")
    
    analyze_failures(results)
    
    print(f"\n✓ Results saved to iteration_{iteration}_results.json")
    print("\nNext step: Analyze failures and create next iteration prompt")

if __name__ == "__main__":
    main()
#!/usr/bin/env python3
"""
Check progress of GPT-4.1 evaluation
"""

import json
from pathlib import Path
from datetime import datetime

def main():
    progress_file = Path("gpt41_progress.json")
    log_file = Path("gpt41_eval.log")
    
    print("=== GPT-4.1 Evaluation Progress ===\n")
    
    if progress_file.exists():
        with open(progress_file) as f:
            progress = json.load(f)
        
        # Count results
        total = 61  # Total test cases
        completed = len(progress)
        passed = sum(1 for case in progress.values() if case.get("passed", False))
        failed = completed - passed
        
        print(f"Progress: {completed}/{total} ({completed/total*100:.1f}%)")
        print(f"Passed: {passed}")
        print(f"Failed: {failed}")
        if completed > 0:
            print(f"Pass Rate: {passed/completed*100:.1f}%")
        
        # Estimate time remaining
        if completed > 5:
            # Assume ~2-3 seconds per case for GPT-4.1
            avg_time_per_case = 2.5
            remaining = total - completed
            eta_minutes = (remaining * avg_time_per_case) / 60
            print(f"\nEstimated time remaining: {eta_minutes:.0f} minutes")
        
        # Show recent failures
        print("\nRecent failures:")
        failures = []
        for case_id, result in progress.items():
            if not result.get("passed") and result.get("failure"):
                failures.append(result["failure"])
        
        for failure in failures[-5:]:  # Last 5 failures
            print(f"- {failure['input'][:60]}...")
            print(f"  Expected: {failure['expected_category']}, is_task={failure['expected_is_task']}")
            print(f"  Got: {failure['actual_category']}, is_task={failure['actual_is_task']}")
    else:
        print("No progress file found. Evaluation may not have started yet.")
    
    # Check log file
    if log_file.exists():
        print(f"\nLog file: {log_file}")
        print("Last few lines:")
        with open(log_file) as f:
            lines = f.readlines()
            for line in lines[-10:]:
                print(f"  {line.rstrip()}")

if __name__ == "__main__":
    main()
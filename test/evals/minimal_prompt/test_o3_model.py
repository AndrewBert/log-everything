#!/usr/bin/env python3
"""
Test iteration 6 prompt with o3 model
"""

import json
import time
import requests
from pathlib import Path
import sys

# Add parent directory to path
sys.path.append(str(Path(__file__).parent))
from run_minimal_eval import load_api_key, load_prompt

API_KEY = load_api_key()
if not API_KEY:
    print("Error: OPENAI_API_KEY not found in .env file")
    exit(1)

BASE_URL = "https://api.openai.com/v1"
HEADERS = {
    "Authorization": f"Bearer {API_KEY}",
    "Content-Type": "application/json"
}

def test_single_case_with_o3(prompt: str, input_text: str):
    """Test a single case with o3 model"""
    
    # o3 might not support system messages, so combine into user message
    combined_prompt = f"{prompt}\n\nUser input: {input_text}"
    
    try:
        response = requests.post(
            f"{BASE_URL}/chat/completions",
            headers=HEADERS,
            json={
                "model": "gpt-4.1",  # Use GPT-4.1 instead of o3
                "messages": [
                    {"role": "user", "content": combined_prompt}
                ],
                "temperature": 0  # GPT-4.1 supports temperature
            },
            timeout=60
        )
        
        if response.status_code == 200:
            result = response.json()
            return result['choices'][0]['message']['content']
        else:
            return f"Error: {response.status_code} - {response.text}"
            
    except Exception as e:
        return f"Exception: {str(e)}"

def main():
    print("=== Testing GPT-4.1 Model with Iteration 7 Prompt ===\n")
    
    # Load iteration 7 prompt (better splitting instructions)
    prompt = load_prompt(7)
    
    # Test cases that were problematic
    test_cases = [
        {
            "input": "work was crazy today back to back meetings barely had time to breathe still need to finish that presentation for tomorrow",
            "description": "Should split: reflection + task"
        },
        {
            "input": "Meeting with client is at 2pm conference room B",
            "description": "Should NOT be a task (appointment)"
        },
        {
            "input": "Car is making weird noise again",
            "description": "Should NOT be a task (observation)"
        },
        {
            "input": "need to call mom",
            "description": "Should be a task (concrete action)"
        }
    ]
    
    print(f"Testing with GPT-4.1 model...\n")
    
    for i, case in enumerate(test_cases, 1):
        print(f"Test {i}: {case['description']}")
        print(f"Input: {case['input']}")
        
        result = test_single_case_with_o3(prompt, case["input"])
        
        try:
            # Try to parse as JSON
            if "```json" in result:
                json_start = result.find("```json") + 7
                json_end = result.find("```", json_start)
                result = result[json_start:json_end].strip()
            
            parsed = json.loads(result)
            print(f"Output: {json.dumps(parsed, indent=2)}")
        except:
            print(f"Raw output: {result}")
        
        print("-" * 50 + "\n")
        
        # Rate limit
        time.sleep(2)

if __name__ == "__main__":
    main()
#!/usr/bin/env python3
"""
Compare different OpenAI models on the task detection evaluation dataset
"""

import json
import time
import requests
from pathlib import Path
from typing import Dict, List, Tuple
import concurrent.futures

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

# Models to compare
MODELS = {
    "gpt-4o-mini": "Current production model (baseline)",
    "gpt-4o": "Full GPT-4o multimodal model",
    "gpt-4.1": "Latest GPT-4.1 with improved instruction following",
    "o3": "Latest O3 reasoning model (most intelligent)"
}

def load_test_cases() -> List[Dict]:
    """Load test cases from eval_dataset.jsonl"""
    dataset_path = Path(__file__).parent / "eval_dataset.jsonl"
    test_cases = []
    
    with open(dataset_path, "r") as f:
        for line in f:
            if line.strip():
                data = json.loads(line)
                test_cases.append(data["item"])
    
    return test_cases

def get_system_prompt() -> str:
    """Get the production system prompt"""
    categories = [
        "Personal: Personal life, social activities, family, hobbies, errands",
        "Work: Work-related activities, meetings, projects, professional tasks", 
        "Health: Medical appointments, exercise, wellness, mental health",
        "Finance: Money management, purchases, banking, investments",
        "Misc: Random thoughts, observations, miscellaneous items"
    ]
    categories_list = "\n".join([f"- {cat}" for cat in categories])
    
    return f"""You are an intelligent note-taking assistant helping organize a user's personal log. Your role is to:

1. LISTEN FOR INSTRUCTIONS in the user's input and execute them
2. ORGANIZE AND STRUCTURE content to improve readability
3. PRESERVE the user's meaning without adding false information

INSTRUCTION DETECTION (HIGHEST PRIORITY):
- Detect natural language commands like:
  - "make this a to-do" / "make this a task" → set is_task: true
  - "file this under [category]" / "categorize as [category]" → override category selection
  - For instructions like "make this a to-do: call the dentist", apply BOTH the task instruction AND proper categorization
  - "summarize this as" → restructure content accordingly
  - "remind me to" / "I need to" → set is_task: true
  - "note that" / "log that" → process as observation (is_task: false)
  - "don't make this a task" → set is_task: false
  - "clean this up" → apply maximum structuring and organization
  - "keep this as is" → minimal changes, preserve original text
- Instructions can appear anywhere in the input
- Follow instructions even if they contradict normal categorization rules
- ALWAYS prioritize explicit user instructions over other rules

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

CATEGORY SELECTION RULES:
Choose the category that best matches the content's primary purpose, domain, or context. Consider these universal principles:

1. SPECIFICITY OVER GENERALITY: Always prefer more specific categories over broad ones
2. PRIMARY PURPOSE: Categorize based on the main intent or domain of the activity
3. CONTEXT MATCHING: Look for keywords, phrases, or concepts that align with category descriptions
4. LOGICAL GROUPING: Similar activities should consistently use the same category
5. USER PREFERENCE: Follow any explicit categorization instructions from the user

// CC: Enhanced categorization hints to reduce "Misc" overuse
CATEGORY HINTS:
- Personal: daily routines, home tasks, car issues, shopping, family, friends, hobbies, personal reminders
- Work: meetings, projects, colleagues, deadlines, professional tasks, job-related items
- Health: exercise, medical, wellness, vitamins, sleep, physical/mental health
- Finance: money, bills, taxes, budget, purchases, banking, investments
- Misc: ONLY for truly uncategorizable items (aim for <10% of entries)

For minimal context (single words like "meeting", "groceries"), use the most likely category based on the word's typical context.
When categorizing, consider domain-specific terms that naturally belong to certain categories.

Use the most general/catch-all category (often "Misc" or similar) ONLY as a last resort when no other category reasonably fits the content.

TASK DETECTION (BE VERY CONSERVATIVE - DEFAULT TO FALSE):
A task must be an actionable commitment that can be checked off a todo list.

// CC: Refined based on evaluation results - balance specificity with general principles
TRUE only for:
- Clear commitments to specific actions: "I need to", "must", "will", "going to", "should"
- Direct imperatives: "remind me to", "don't forget to", "remember to"
- User instructions: "make this a to-do"
- Single action words implying reminders: "groceries", "dentist", "taxes", "laundry"
- Problems requiring action: "car making noise", "running low on X", "forgot to buy X"
- Incomplete work: "still need to finish X", "need to add Y to Z"
- Recurring forgetfulness: "always forgetting to X", "keep forgetting my keys"
- Planning questions: "when should I schedule X?" (implies scheduling action)

FALSE for:
- Past actions (already done)
- Current states or observations
- Aspirations without commitment: "would like to", "hoping to", "want to someday"
- Venting with negative tone: "ugh have to X", "great, another X" (sarcasm)
- Possibilities not commitments: "could", "might", "maybe", "possibly"
- Conditional actions: "if X happens, then Y"
- Ongoing processes: "working on improving X", "practicing Y daily"
- Vague self-improvement: "need to stop procrastinating", "need to get life together"
- Wondering/pondering: "wonder if I should X", "should I do Y?" (unless planning)

TRUE for future events/appointments:
- "meeting tomorrow", "appointment at 3pm", "lunch with client" (these are reminders)
- "meeting with client tomorrow about budget" (reminder for scheduled event)

When in doubt, default to FALSE. Only mark as TRUE when there's a clear, actionable item.

Here are the available categories:
{categories_list}

When deciding which category to use, consider both the name and the description for the best fit. Use specific categories over "Misc" whenever possible. Override category selection if user provides explicit instructions.

Output a single JSON object (not an array) with:
{{
  "text": "the processed content",
  "category": "the selected category",
  "is_task": true or false
}}"""

def test_model(model_id: str, test_case: Dict) -> Tuple[bool, Dict]:
    """Test a single model on a single test case"""
    try:
        # Special handling for o3 which might not support system messages
        if model_id == "o3":
            messages = [{
                "role": "user", 
                "content": f"{get_system_prompt()}\n\nUser input: {test_case['input_text']}"
            }]
            response_format = None  # o3 might not support response_format
        else:
            messages = [
                {"role": "system", "content": get_system_prompt()},
                {"role": "user", "content": test_case["input_text"]}
            ]
            response_format = {"type": "json_object"}
        
        request_body = {
            "model": model_id,
            "messages": messages,
            "temperature": 0
        }
        
        if response_format:
            request_body["response_format"] = response_format
            
        response = requests.post(
            f"{BASE_URL}/chat/completions",
            headers=HEADERS,
            json=request_body,
            timeout=60  # Longer timeout for o1-mini
        )
        
        if response.status_code == 200:
            result = response.json()
            content = result['choices'][0]['message']['content']
            
            # Try to parse JSON from the response
            try:
                # For o3, extract JSON from the response
                if model_id == "o3" and "```json" in content:
                    json_start = content.find("```json") + 7
                    json_end = content.find("```", json_start)
                    content = content[json_start:json_end].strip()
                elif model_id == "o3" and "{" in content:
                    # Try to extract JSON object
                    json_start = content.find("{")
                    json_end = content.rfind("}") + 1
                    content = content[json_start:json_end]
                    
                output = json.loads(content)
            except json.JSONDecodeError:
                print(f"\nJSON decode error for {model_id}: {content[:100]}...")
                return False, {"error": "JSON decode error", "raw": content}
            
            # Check if the output matches expected values
            expected_entry = test_case["expected_entries"][0]
            category_match = output.get("category") == expected_entry["category"]
            task_match = output.get("is_task") == expected_entry["is_task"]
            
            return (category_match and task_match), {
                "output": output,
                "category_match": category_match,
                "task_match": task_match,
                "test_type": test_case.get("test_type", "unknown")
            }
        else:
            error_detail = f"{response.status_code}: {response.text[:200]}"
            return False, {"error": error_detail}
            
    except Exception as e:
        return False, {"error": str(e)}

def run_model_comparison():
    """Run all test cases against all models"""
    print("=== OpenAI Model Comparison for Task Detection ===\n")
    
    # Load test cases
    test_cases = load_test_cases()
    print(f"Loaded {len(test_cases)} test cases\n")
    
    # Results storage
    results = {model: {"passed": 0, "failed": 0, "errors": 0, "failures_by_type": {}} 
               for model in MODELS}
    
    # Test each model
    for model_id, description in MODELS.items():
        print(f"\nTesting {model_id}: {description}")
        print("-" * 60)
        
        # Test availability first
        test_messages = [{"role": "user", "content": "test"}]
        if model_id == "o3":
            test_body = {"model": model_id, "messages": test_messages, "max_tokens": 10}
        else:
            test_body = {"model": model_id, "messages": test_messages, "max_tokens": 1}
            
        test_response = requests.post(
            f"{BASE_URL}/chat/completions",
            headers=HEADERS,
            json=test_body
        )
        
        if test_response.status_code != 200:
            print(f"⚠️  Model {model_id} not available. Error: {test_response.text[:100]}")
            continue
        
        # Test in smaller batches for o3 due to rate limits
        batch_size = 5 if model_id == "o3" else 10
        
        for i in range(0, len(test_cases), batch_size):
            batch = test_cases[i:i+batch_size]
            
            # Test batch sequentially for o3
            if model_id == "o3":
                for j, case in enumerate(batch):
                    passed, details = test_model(model_id, case)
                    
                    if "error" in details:
                        results[model_id]["errors"] += 1
                    elif passed:
                        results[model_id]["passed"] += 1
                    else:
                        results[model_id]["failed"] += 1
                        test_type = details.get("test_type", "unknown")
                        results[model_id]["failures_by_type"][test_type] = \
                            results[model_id]["failures_by_type"].get(test_type, 0) + 1
                    
                    # Rate limit for o3
                    if j < len(batch) - 1:
                        time.sleep(2)
            else:
                # Test batch concurrently for other models
                with concurrent.futures.ThreadPoolExecutor(max_workers=3) as executor:
                    futures = {
                        executor.submit(test_model, model_id, case): case 
                        for case in batch
                    }
                    
                    for future in concurrent.futures.as_completed(futures):
                        test_case = futures[future]
                        passed, details = future.result()
                        
                        if "error" in details:
                            results[model_id]["errors"] += 1
                        elif passed:
                            results[model_id]["passed"] += 1
                        else:
                            results[model_id]["failed"] += 1
                            test_type = details.get("test_type", "unknown")
                            results[model_id]["failures_by_type"][test_type] = \
                                results[model_id]["failures_by_type"].get(test_type, 0) + 1
            
            # Show progress
            completed = min(i + batch_size, len(test_cases))
            print(f"  Progress: {completed}/{len(test_cases)} tests completed", end="\r")
            
            # Rate limit handling
            time.sleep(1)
        
        print()  # New line after progress
    
    # Display results
    print("\n\n" + "=" * 80)
    print("RESULTS SUMMARY")
    print("=" * 80)
    
    # Create comparison table
    print("\n%-20s | %-10s | %-10s | %-10s | %-15s" % 
          ("Model", "Passed", "Failed", "Errors", "Pass Rate"))
    print("-" * 75)
    
    model_performance = []
    for model_id in MODELS:
        if model_id in results and results[model_id]["passed"] + results[model_id]["failed"] > 0:
            total = results[model_id]["passed"] + results[model_id]["failed"]
            pass_rate = (results[model_id]["passed"] / total * 100) if total > 0 else 0
            
            model_performance.append((model_id, pass_rate, results[model_id]))
            
            print("%-20s | %-10d | %-10d | %-10d | %-14.1f%%" % 
                  (model_id, results[model_id]["passed"], results[model_id]["failed"], 
                   results[model_id]["errors"], pass_rate))
    
    # Sort by performance
    model_performance.sort(key=lambda x: x[1], reverse=True)
    
    # Show improvement over baseline
    if len(model_performance) > 0:
        print("\n\nPERFORMANCE COMPARISON")
        print("-" * 40)
        
        baseline_rate = next((perf[1] for perf in model_performance if perf[0] == "gpt-4o-mini"), 0)
        
        for model_id, pass_rate, _ in model_performance:
            if model_id != "gpt-4o-mini" and baseline_rate > 0:
                improvement = ((pass_rate - baseline_rate) / baseline_rate) * 100
                sign = "+" if improvement > 0 else ""
                print(f"{model_id}: {pass_rate:.1f}% ({sign}{improvement:.1f}% vs baseline)")
    
    # Show failure analysis for each model
    print("\n\nFAILURE ANALYSIS BY MODEL")
    print("-" * 40)
    
    for model_id, _, model_results in model_performance[:3]:  # Top 3 models
        if model_results["failures_by_type"]:
            print(f"\n{model_id} - Top failure types:")
            failures = sorted(model_results["failures_by_type"].items(), 
                             key=lambda x: x[1], reverse=True)
            for test_type, count in failures[:5]:
                print(f"  - {test_type}: {count} failures")
    
    # Save detailed results
    output_file = Path(__file__).parent / "model_comparison_results.json"
    with open(output_file, "w") as f:
        json.dump({
            "summary": {
                model_id: {
                    "pass_rate": pass_rate,
                    "passed": model_results["passed"],
                    "failed": model_results["failed"],
                    "errors": model_results["errors"]
                }
                for model_id, pass_rate, model_results in model_performance
            },
            "detailed_results": results,
            "test_count": len(test_cases)
        }, f, indent=2)
    
    print(f"\n\nDetailed results saved to: {output_file}")

if __name__ == "__main__":
    run_model_comparison()
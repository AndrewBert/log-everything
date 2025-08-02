#!/usr/bin/env python3
"""Test a single prompt to see what the model actually outputs"""

import json
from openai import OpenAI
from pathlib import Path

# Load API key
def load_api_key():
    env_path = Path(__file__).parent.parent.parent / '.env'
    if env_path.exists():
        with open(env_path, 'r') as f:
            for line in f:
                if line.startswith('OPENAI_API_KEY='):
                    return line.strip().split('=')[1]
    return None

api_key = load_api_key()
client = OpenAI(api_key=api_key)

# Test with the same system prompt from our evaluation
system_prompt = """You are an intelligent note-taking assistant. Extract and process user input following these rules:

1. LISTEN FOR INSTRUCTIONS like "make this a to-do", "remind me to", "file this under"
2. CLEAN UP text by removing filler words and improving structure
3. DETECT if it's a task (actionable) or observation

Respond with JSON:
{
  "text": "the processed content",
  "category": "Personal|Work|Health|Finance|Misc",
  "is_task": true/false
}"""

# Test inputs
test_inputs = [
    "Make this a to-do: call the dentist about my appointment",
    "Had a great meeting with the team today, very productive",
    "So like um I was thinking we should probably review the quarterly report"
]

print("Testing prompts to see actual model output:\n")

for i, user_input in enumerate(test_inputs, 1):
    print(f"Test {i}: {user_input}")
    
    response = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_input}
        ]
    )
    
    output = response.choices[0].message.content
    print(f"Output: {output}")
    
    # Try to parse as JSON
    try:
        parsed = json.loads(output)
        print(f"Parsed JSON: {json.dumps(parsed, indent=2)}")
    except json.JSONDecodeError:
        print("Failed to parse as JSON")
    
    print("-" * 50)
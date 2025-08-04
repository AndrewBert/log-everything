#!/usr/bin/env python3
"""
Debug gpt-4o-mini response to see what's happening
"""

import json
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

print("=== Debug GPT-4o-mini Response ===")
print(f"System prompt length: {len(system_prompt)} chars")
print("\nTesting with: 'Call dentist at 3pm today'")
print()

try:
    # Call OpenAI API
    response = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": "Call dentist at 3pm today"}
        ],
        response_format={"type": "json_object"},
        temperature=0,
        max_tokens=1000
    )
    
    raw_content = response.choices[0].message.content
    print("Raw response:")
    print(raw_content)
    print()
    
    # Try to parse
    result = json.loads(raw_content)
    print("Parsed JSON:")
    print(json.dumps(result, indent=2))
    
except Exception as e:
    print(f"Error: {e}")
    print(f"Error type: {type(e)}")
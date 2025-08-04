#!/usr/bin/env python3
"""
Test the Responses API with structured outputs
"""

import json
from openai import OpenAI
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

client = OpenAI()

# Simple test case
test_input = "Call dentist at 3pm today"

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
                    "text_segment": {
                        "type": "string",
                        "description": "The cleaned and organized text segment"
                    },
                    "category": {
                        "type": "string",
                        "description": "The category name from the provided list"
                    },
                    "is_task": {
                        "type": "boolean",
                        "description": "Whether this entry represents a task, todo item, or action item that can be completed"
                    },
                },
                "required": ["text_segment", "category", "is_task"],
                "additionalProperties": False,
            },
        },
    },
    "required": ["entries"],
    "additionalProperties": False,
}

print("=== Testing Responses API with Structured Outputs ===")
print(f"Model: gpt-4o-mini")
print(f"Input: '{test_input}'")
print()

try:
    import requests
    
    # Call the Responses API
    response = requests.post(
        'https://api.openai.com/v1/responses',
        json={
            'model': 'gpt-4o-mini',
            'input': [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": test_input}
            ],
            'text': {
                'format': {
                    'type': 'json_schema',
                    'name': 'multiple_entry_extraction',
                    'schema': schema,
                    'strict': True
                },
            },
            'temperature': 0,
        },
        headers={
            'Content-Type': 'application/json',
            'Authorization': f'Bearer {client.api_key}',
        }
    )
    
    result = response.json()
    print("Response:")
    print(json.dumps(result, indent=2))
    
    # Extract the actual output
    if result.get('status') == 'completed' and result.get('output'):
        for output_item in result['output']:
            if output_item['type'] == 'message' and output_item.get('content'):
                for content_item in output_item['content']:
                    if content_item['type'] == 'output_text':
                        parsed = json.loads(content_item['text'])
                        print("\nParsed entries:")
                        print(json.dumps(parsed, indent=2))
                        break
    
except Exception as e:
    print(f"Error: {e}")
    print(f"Error type: {type(e)}")
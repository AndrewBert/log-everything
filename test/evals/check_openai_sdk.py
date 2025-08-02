#!/usr/bin/env python3
"""Check OpenAI SDK capabilities"""

import openai
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
if not api_key:
    print("Error: OPENAI_API_KEY not found in .env file")
    exit(1)

# Check SDK version
print(f"OpenAI SDK version: {openai.__version__}")

# Initialize client
client = openai.OpenAI(api_key=api_key)

# Check available attributes
print("\nAvailable client attributes:")
attrs = [attr for attr in dir(client) if not attr.startswith('_')]
for attr in sorted(attrs):
    print(f"  - {attr}")

# Check if evals is available
if hasattr(client, 'evals'):
    print("\n✓ Evals API is available")
else:
    print("\n✗ Evals API is NOT available in this SDK version")
    print("\nNote: The Evals API might require:")
    print("  1. A beta version of the SDK")
    print("  2. Special access or waitlist approval")
    print("  3. A different endpoint or setup")
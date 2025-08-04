#!/usr/bin/env python3
"""
Update test dataset to fix incorrect task expectations based on user feedback
"""

import json

# Test cases that should have is_task=false (not true)
updates = {
    "Went to grocery store but forgot to buy milk": False,
    "When should I schedule the team meeting?": False,
    "Been putting off calling the dentist for weeks really should do it but hate making appointments maybe I'll do it tomorrow or next week": False,
    "Remember to use the todo app more consistently": False,
    # Also update other test cases that were confirmed wrong
    "I should probably check my blood pressure more often": False,
    "Always forgetting to take my vitamins": False,
    "Meeting with client is at 2pm conference room B": False,
    "Car is making weird noise again": False,
    "Running low on coffee": False,
    "kids have soccer practice at 4 then piano at 6 husband picking up dinner thank god": False,
    "budget meeting @ 10am, lunch w/ jen 12:30, gym after work if time": False,
    "Oh great, another meeting to attend tomorrow 🙄 just what I needed": False,
}

# Read the dataset
with open('eval_dataset.jsonl', 'r') as f:
    lines = f.readlines()

# Update the lines
updated_lines = []
update_count = 0

for line in lines:
    if line.strip():
        data = json.loads(line)
        input_text = data["item"]["input_text"]
        
        # Check if this test case needs updating
        if input_text in updates:
            # Update is_task to false
            for entry in data["item"]["expected_entries"]:
                if entry["is_task"] == True:
                    entry["is_task"] = False
                    update_count += 1
                    print(f"Updated: {input_text[:60]}... to is_task=False")
        
        updated_lines.append(json.dumps(data) + '\n')
    else:
        updated_lines.append(line)

# Write back to file
with open('eval_dataset.jsonl', 'w') as f:
    f.writelines(updated_lines)

print(f"\nTotal updates: {update_count}")
print("Test dataset updated successfully!")
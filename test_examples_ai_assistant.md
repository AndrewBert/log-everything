# AI Assistant Test Examples

## 1. Simple Instruction Following

### Test 1.1: Basic To-Do Instruction
**Input:** "Make this a to-do: call the dentist about my appointment"
**Expected Output:** 
- text_segment: "Call the dentist about my appointment"
- is_task: true
- category: "Health"

### Test 1.2: Remind Me Pattern
**Input:** "Remind me to pick up groceries after work"
**Expected Output:**
- text_segment: "Pick up groceries after work"
- is_task: true
- category: "Personal"

### Test 1.3: Category Override
**Input:** "File this under work: had a great lunch with friends at the new cafe"
**Expected Output:**
- text_segment: "Had a great lunch with friends at the new cafe"
- is_task: false
- category: "Work" (overridden from what would normally be "Personal")

### Test 1.4: Note/Log Instruction
**Input:** "Just noting that the weather was beautiful today"
**Expected Output:**
- text_segment: "The weather was beautiful today"
- is_task: false
- category: "Personal"

## 2. Content Structuring Without Instructions

### Test 2.1: Rambling Thoughts
**Input:** "So like um I was thinking about maybe possibly starting to exercise more you know because I've been feeling kind of tired lately and uh yeah I think it would be good for me"
**Expected Output:**
- text_segment: "I've been thinking about starting to exercise more because I've been feeling tired lately. I think it would be good for me."
- is_task: false
- category: "Health"

### Test 2.2: Run-on Sentence
**Input:** "Went to the store and bought milk and eggs and bread and then I ran into Sarah and we talked for like 20 minutes about her new job and then I came home and made dinner"
**Expected Output:**
- text_segment: "Went to the store and bought milk, eggs, and bread. Ran into Sarah and talked for 20 minutes about her new job. Came home and made dinner."
- is_task: false
- category: "Personal"

### Test 2.3: Multiple Related Points
**Input:** "The project deadline is next Friday. We still need to finish the API integration. John is handling the frontend. I should review the documentation tomorrow."
**Expected Output:**
- text_segment: "Project deadline is next Friday. We still need to finish the API integration. John is handling the frontend. I should review the documentation tomorrow."
- is_task: false (mixed content, not purely a task)
- category: "Work"

## 3. Complex Multi-Instruction Scenarios

### Test 3.1: Multiple Instructions
**Input:** "Make this a task and file it under health: schedule annual physical exam"
**Expected Output:**
- text_segment: "Schedule annual physical exam"
- is_task: true
- category: "Health"

### Test 3.2: Clean Up Instruction
**Input:** "Clean this up: so basically what happened was I went to the meeting and um they said we need to like totally revamp the whole system which is gonna be a lot of work but I think it's necessary"
**Expected Output:**
- text_segment: "Attended the meeting where they announced we need to completely revamp the system. This will be substantial work, but I believe it's necessary."
- is_task: false
- category: "Work"

### Test 3.3: Keep As Is Instruction
**Input:** "Keep this as is: Um, like, I totally think we should, you know, maybe consider the proposal?"
**Expected Output:**
- text_segment: "Um, like, I totally think we should, you know, maybe consider the proposal?"
- is_task: false
- category: "Work"

## 4. Task Detection Edge Cases

### Test 4.1: Ambiguous Single Words
**Input:** "Groceries"
**Expected Output:**
- text_segment: "Groceries"
- is_task: true (implies need to buy)
- category: "Personal"

### Test 4.2: Past vs Future
**Input:** "Called mom about dinner plans need to call dad too"
**Expected Output:** Should create TWO entries:
1. text_segment: "Called mom about dinner plans"
   - is_task: false
   - category: "Personal"
2. text_segment: "Need to call dad too"
   - is_task: true
   - category: "Personal"

### Test 4.3: Mixed Instructions
**Input:** "Note that I finished the report but make this a to-do: send it to the team"
**Expected Output:** Should create TWO entries:
1. text_segment: "Finished the report"
   - is_task: false
   - category: "Work"
2. text_segment: "Send report to the team"
   - is_task: true
   - category: "Work"

## 5. Category-Specific Scenarios

### Test 5.1: Finance with Structure
**Input:** "So I paid the credit card bill today it was like 500 dollars and then I also need to remember to transfer money to savings account maybe like 200 bucks"
**Expected Output:**
- text_segment: "Paid the credit card bill today ($500). Need to transfer $200 to savings account."
- is_task: false (mixed - one completed, one pending)
- category: "Finance"

### Test 5.2: Health with Instructions
**Input:** "Make this a task: refill prescription. Also just logging that my headache is better today"
**Expected Output:** Should create TWO entries:
1. text_segment: "Refill prescription"
   - is_task: true
   - category: "Health"
2. text_segment: "Headache is better today"
   - is_task: false
   - category: "Health"

### Test 5.3: Work Project Update
**Input:** "The client loved the presentation!! They want us to move forward with option B. I need to update the timeline and schedule a kickoff meeting for next week"
**Expected Output:**
- text_segment: "The client loved the presentation! They want us to move forward with option B. Need to update the timeline and schedule a kickoff meeting for next week."
- is_task: false (mixed content)
- category: "Work"

## 6. Extreme Structuring Cases

### Test 6.1: Stream of Consciousness
**Input:** "okay so like today was crazy first i woke up late then spilled coffee on my shirt had to change then traffic was horrible but made it to the presentation on time thank god and it went really well the boss seemed impressed"
**Expected Output:**
- text_segment: "Today was hectic. Woke up late and spilled coffee on my shirt, requiring a change of clothes. Traffic was terrible but managed to arrive at the presentation on time. The presentation went very well and the boss seemed impressed."
- is_task: false
- category: "Work"

### Test 6.2: List Detection
**Input:** "Things to buy at store milk eggs bread cheese yogurt apples bananas oh and paper towels"
**Expected Output:**
- text_segment: "Shopping list:\n- Milk\n- Eggs\n- Bread\n- Cheese\n- Yogurt\n- Apples\n- Bananas\n- Paper towels"
- is_task: true
- category: "Personal"

## 7. Conflict Resolution

### Test 7.1: Conflicting Instructions
**Input:** "Make this a task but note that it's already done: submitted the tax forms"
**Expected Output:**
- text_segment: "Submitted the tax forms"
- is_task: true (first instruction takes precedence)
- category: "Finance"

### Test 7.2: Natural Task Language vs Note Instruction
**Input:** "Note that I need to call the insurance company tomorrow"
**Expected Output:**
- text_segment: "Need to call the insurance company tomorrow"
- is_task: false (explicit "note that" overrides the "need to")
- category: "Finance"

## 8. Multiple Entry Scenarios

### Test 8.1: Clearly Separate Topics
**Input:** "Went for a 5 mile run this morning felt great. Also the quarterly report is due next Friday and I should start working on it."
**Expected Output:** Should create TWO entries:
1. text_segment: "Went for a 5-mile run this morning. Felt great."
   - is_task: false
   - category: "Health"
2. text_segment: "Quarterly report is due next Friday. Should start working on it."
   - is_task: false
   - category: "Work"

### Test 8.2: Related Observations
**Input:** "The new coffee machine at work is amazing. It makes such good espresso. Everyone's been using it all day. Productivity might actually go up!"
**Expected Output:** Should create ONE entry:
- text_segment: "The new coffee machine at work is amazing - makes excellent espresso. Everyone's been using it all day. Productivity might actually increase!"
- is_task: false
- category: "Work"

## 9. Special Formatting Cases

### Test 9.1: Quotes and Special Characters
**Input:** "Remember to tell Sarah "the meeting is at 3pm not 2pm" and don't forget!!!"
**Expected Output:**
- text_segment: "Tell Sarah "the meeting is at 3pm not 2pm""
- is_task: true
- category: "Work"

### Test 9.2: Numbers and Amounts
**Input:** "spent $45.50 on gas and like maybe around 20 or 25 dollars on lunch with the team"
**Expected Output:**
- text_segment: "Spent $45.50 on gas and approximately $20-25 on lunch with the team"
- is_task: false
- category: "Finance"

## 10. Instruction Variations

### Test 10.1: Alternative Phrasing
**Input:** "Categorize as personal: work was stressful today"
**Expected Output:**
- text_segment: "Work was stressful today"
- is_task: false
- category: "Personal" (overridden)

### Test 10.2: Summarize Instruction
**Input:** "Summarize this as: productive team meeting about Q2 goals. So we had this really long meeting today where we talked about all sorts of things like the revenue targets and the new product features and who's responsible for what"
**Expected Output:**
- text_segment: "Productive team meeting about Q2 goals"
- is_task: false
- category: "Work"

### Test 10.3: Implicit Structure Request
**Input:** "List of things discussed in therapy: anxiety about work, sleep issues, need to practice meditation more, feeling better overall though"
**Expected Output:**
- text_segment: "Therapy discussion topics:\n- Anxiety about work\n- Sleep issues\n- Need to practice meditation more\n- Feeling better overall"
- is_task: false
- category: "Health"
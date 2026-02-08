# Quickstart: AI Rephrase Toggle

## Validation Steps

### 1. Toggle appears in Settings
1. Open the app
2. Navigate to Settings page
3. Verify "AI Text Cleanup" toggle appears in the General section
4. Verify toggle is ON by default

### 2. Toggle persists across restarts
1. Open Settings
2. Toggle "AI Text Cleanup" OFF
3. Close the app completely
4. Reopen the app
5. Navigate to Settings
6. Verify toggle is still OFF

### 3. Rephrase ON (default behavior)
1. Ensure toggle is ON in Settings
2. Log an entry with filler words: "um went to the store and uh bought some groceries"
3. Verify the saved entry has filler words removed (e.g., "Went to the store and bought some groceries")
4. Verify categorization still works correctly

### 4. Rephrase OFF (verbatim mode)
1. Toggle "AI Text Cleanup" OFF in Settings
2. Log an entry with filler words: "um had lunch with uh sarah at the new place"
3. Verify the saved entry preserves the exact text: "um had lunch with uh sarah at the new place"
4. Verify categorization and task detection still work correctly

### 5. Multi-entry split with rephrase OFF
1. Toggle "AI Text Cleanup" OFF
2. Log a combined entry: "went to gym this morning, need to call dentist tomorrow"
3. Verify the entry splits into two entries
4. Verify each segment preserves original text (not cleaned up)
5. Verify each segment has correct category and task detection

### 6. Mid-processing toggle has no effect on queued entries
1. Log an entry (it will show "Processing...")
2. Quickly toggle the rephrase setting
3. Verify the entry processes with the setting that was active when it was submitted

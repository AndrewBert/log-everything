# OpenAI Evaluations for Log Entry Extraction

This directory contains the setup for automated testing of the AI log entry extraction system using OpenAI's Evaluations API.

## Prerequisites

1. Set your OpenAI API key:
   ```bash
   export OPENAI_API_KEY="your-api-key"
   ```

2. Install the OpenAI Python SDK:
   ```bash
   pip install openai
   ```

## Files

- `eval_config.json` - Evaluation configuration
- `convert_tests_to_eval_format.dart` - Converts test examples to JSONL format
- `eval_dataset.jsonl` - Generated test dataset (10 test cases)
- `run_eval_simple.py` - Simplified evaluation runner
- `run_openai_eval.py` - Full evaluation runner with all test cases
- `test_examples_ai_assistant.md` - Manual test examples (30+ cases)

## Running Evaluations

### Quick Start (Simple Version)

The simple version tests basic categorization with 3 test cases:

```bash
python test/evals/run_eval_simple.py
```

This will:
1. Create a simple test dataset
2. Create an evaluation configuration
3. Upload the test data
4. Run the evaluation
5. Provide a link to view results

### Full Test Suite

To run all 10 test cases from the converted dataset:

```bash
# First, generate the dataset
dart run test/evals/convert_tests_to_eval_format.dart

# Then run the full evaluation
python test/evals/run_openai_eval.py
```

### Checking Status

After running an evaluation, check its status:

```bash
python test/evals/run_eval_simple.py --check <eval_id> <run_id>
```

## What Gets Tested

The evaluations test:

1. **Instruction Detection** - Does the AI follow commands like "make this a to-do"?
2. **Content Transformation** - Does it clean up rambling text properly?
3. **Category Assignment** - Does it assign the correct category?
4. **Task Detection** - Does it correctly identify tasks vs. observations?
5. **Multiple Entry Splitting** - Does it split unrelated content appropriately?

## Understanding Results

The evaluation will show:
- **Total** - Number of test cases
- **Passed** - Tests that matched expected output
- **Failed** - Tests that didn't match
- **Per-criteria results** - How each testing criteria performed

View detailed results in the OpenAI dashboard via the provided URL.

## Cost Considerations

Each evaluation run costs money because it:
1. Calls the API for each test case
2. May use additional API calls for model-graded criteria

Start with the simple version to test your setup before running the full suite.

## Troubleshooting

1. **"API Key not found"** - Make sure `OPENAI_API_KEY` is set
2. **"Module not found"** - Install the OpenAI SDK: `pip install openai`
3. **Rate limits** - The API has rate limits; space out large test runs
4. **Evaluation failures** - Check the dashboard for detailed error messages

## Next Steps

1. Run the simple evaluation first to verify setup
2. Review results in the OpenAI dashboard
3. Iterate on the system prompt based on failures
4. Add more test cases as needed
5. Consider using model-graded criteria for subjective qualities like "text readability"
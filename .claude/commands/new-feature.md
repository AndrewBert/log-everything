Start new feature development workflow: create branch, worktree, open VS Code Insiders, and copy environment file.

## Interactive Usage

You can use this command in multiple ways:

### 1. Natural Language Description
Just describe what you want to build:
- "/new feature add dark mode toggle to settings"
- "/new feature voice input for quick logging" 
- "/new feature improve chat UI with better formatting"

Claude will generate an appropriate branch name like `add-dark-mode-toggle`, `voice-input-quick-logging`, etc.

### 2. Simple Prompt
Just say "/new feature" and Claude will ask you to describe the feature.

### 3. Direct Branch Name
Provide the exact branch name: "/new feature my-specific-branch-name"

## Implementation

When triggered, Claude should:

1. **Parse the input** - extract feature description or ask for it
2. **Generate branch name** - convert description to kebab-case branch name (e.g., "Add dark mode" → "add-dark-mode")
3. **Confirm with user** - show the proposed branch name and ask for approval
4. **Execute workflow**:

```bash
FEATURE_NAME="generated-or-provided-name" && \
git checkout main && \
git pull origin main && \
git branch "$FEATURE_NAME" && \
git worktree add "../$FEATURE_NAME" "$FEATURE_NAME" && \
cp .env "../$FEATURE_NAME/.env" 2>/dev/null || echo "No .env file found" && \
code-insiders "../$FEATURE_NAME"
```

## Branch Naming Conventions
- Use kebab-case (lowercase with hyphens)
- Keep it descriptive but concise
- Examples: `add-voice-input`, `fix-chat-ui`, `improve-onboarding`, `refactor-entry-service`

The new feature environment will be ready for development with all dependencies and environment variables in place.
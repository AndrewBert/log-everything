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
3. **Check for existing branches** - verify the branch doesn't already exist
4. **Execute workflow**:

```bash
# Stay on main branch to avoid checkout conflicts
git checkout main && \
git pull origin main && \
FEATURE_NAME="generated-or-provided-name" && \
# Create branch without checking it out
git branch "$FEATURE_NAME" && \
# Create worktree (this will checkout the branch in the worktree)
git worktree add "../log-everything.worktrees/$FEATURE_NAME" "$FEATURE_NAME" && \
# Symlink the .env file
ln -s ../../log-everything/.env "../log-everything.worktrees/$FEATURE_NAME/.env" && \
echo "✅ .env symlinked to main repository" && \
# Set up FVM for the worktree and run pub get
(cd "../log-everything.worktrees/$FEATURE_NAME" && fvm use stable && fvm flutter pub get) && \
echo "✅ FVM configured (stable) and dependencies installed" && \
echo "✅ Feature branch '$FEATURE_NAME' created with worktree" && \
# Try VS Code Insiders first, fall back to regular VS Code
(code-insiders "../log-everything.worktrees/$FEATURE_NAME" 2>/dev/null || \
 code "../log-everything.worktrees/$FEATURE_NAME" 2>/dev/null || \
 echo "⚠️  Please open '../log-everything.worktrees/$FEATURE_NAME' in your editor")
```

## Important Notes

- **Branch Creation**: Use `git branch` instead of `git checkout -b` to avoid conflicts when creating worktrees
- **Stay on Main**: The main repository should remain on the main branch while worktrees handle feature branches
- **VS Code Fallback**: Try VS Code Insiders first, then regular VS Code, then provide manual instructions
- **Clean Up**: If a branch already exists, ask user if they want to delete and recreate it

## Branch Naming Conventions
- Use kebab-case (lowercase with hyphens)
- Keep it descriptive but concise
- Examples: `add-voice-input`, `fix-chat-ui`, `improve-onboarding`, `refactor-entry-service`

The new feature environment will be ready for development with all dependencies and environment variables in place.
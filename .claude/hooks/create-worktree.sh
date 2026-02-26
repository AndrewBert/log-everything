#!/bin/bash
# Creates worktrees in ../log-everything.worktrees/<name> (GitLens convention)
set -e

INPUT=$(cat)
NAME=$(echo "$INPUT" | jq -r '.name')
CWD=$(echo "$INPUT" | jq -r '.cwd')

WORKTREE_DIR="$CWD/../log-everything.worktrees/$NAME"
mkdir -p "$(dirname "$WORKTREE_DIR")"

# Create git worktree with a new branch
git -C "$CWD" worktree add "$WORKTREE_DIR" -b "worktree-$NAME" >&2

# Copy .env if it exists
cp "$CWD/.env" "$WORKTREE_DIR/.env" 2>/dev/null || true

# Install dependencies
cd "$WORKTREE_DIR"
flutter pub get >&2

# Print absolute path to stdout (required by Claude Code)
echo "$WORKTREE_DIR"

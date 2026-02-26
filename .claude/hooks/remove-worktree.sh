#!/bin/bash
# Removes worktrees from ../log-everything.worktrees/<name>
set -e

INPUT=$(cat)
WORKTREE_PATH=$(echo "$INPUT" | jq -r '.worktree_path')
CWD=$(echo "$INPUT" | jq -r '.cwd')

# Remove git worktree reference first, then delete directory
git -C "$CWD" worktree remove "$WORKTREE_PATH" --force 2>/dev/null || rm -rf "$WORKTREE_PATH"

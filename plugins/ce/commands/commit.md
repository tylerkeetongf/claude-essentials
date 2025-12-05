---
description: Create a well-formatted git commit for current changes
allowed-tools: Task
---

Create a git commit by delegating to the commit agent.

## Process

1. Parse `$ARGUMENTS` to determine:
   - Context type: "staged" (default) or "unstaged"
   - Any specific commit instructions from the user
2. Invoke the `ce:commit` agent via Task tool, passing only:
   - The context type
   - Any user-provided instructions from `$ARGUMENTS`

The agent handles all git operations (file list, diff, commit history, commit) in its own context.

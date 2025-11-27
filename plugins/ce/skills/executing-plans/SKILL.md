---
name: executing-plans
description: Execute implementation plans via batch execution with human review or subagent dispatch with automated code review gates
---

# Executing Plans

Load plan, review critically, execute tasks with review checkpoints.

**Core principle:** Never execute blindly. Review plans first, verify as you go, stop when blocked.

## Two Execution Modes

### Batch Mode (Human Review)
- Execute 3 tasks, pause for human feedback
- Best when: Human wants oversight, tasks may need adjustment
- Review: Human reviews between batches

### Subagent Mode (Automated Review)
- Dispatch fresh subagent per task, code-reviewer between tasks
- Best when: Tasks are independent, want continuous progress
- Review: Automated code review after each task

**Choose batch mode by default.** Use subagent mode when explicitly requested or when tasks are clearly independent and well-specified.

## The Process

### Step 1: Load and Review Plan

1. Read plan file
2. Review critically - identify questions or concerns
3. If concerns: Raise them before starting
4. Create TodoWrite with all tasks
5. Proceed with chosen execution mode

### Step 2: Execute Tasks

#### Batch Mode

For each task in batch (default: 3 tasks):
1. Mark as in_progress
2. Follow each step exactly
3. Run verifications as specified
4. Mark as completed

When batch complete:
- Show what was implemented
- Show verification output
- Say: "Ready for feedback."

Based on feedback:
- Apply changes if needed
- Execute next batch
- Repeat until complete

#### Subagent Mode

For each task:

**Dispatch implementation subagent:**
```
Task tool (general-purpose):
  description: "Implement Task N: [task name]"
  prompt: |
    You are implementing Task N from [plan-file].

    Read that task carefully. Your job is to:
    1. Implement exactly what the task specifies
    2. Write tests (following TDD if task says to)
    3. Verify implementation works
    4. Commit your work
    5. Report back

    Work from: [directory]

    Report: What you implemented, what you tested, test results, files changed, any issues
```

**Dispatch code-reviewer subagent:**
```
Task tool (code-reviewer):
  Review the changes made by the previous subagent

  WHAT_WAS_IMPLEMENTED: [from subagent's report]
  PLAN_OR_REQUIREMENTS: Task N from [plan-file]
  BASE_SHA: [commit before task]
  HEAD_SHA: [current commit]
  DESCRIPTION: [task summary]
```

**Apply review feedback:**
- Fix Critical issues immediately
- Fix Important issues before next task
- Note Minor issues
- Dispatch follow-up subagent if fixes needed

Mark task complete, move to next task.

### Step 3: Final Review

**Batch mode:** Human reviews final state

**Subagent mode:** Dispatch final code-reviewer:
- Reviews entire implementation
- Checks all plan requirements met
- Validates overall architecture

### Step 4: Complete Development

After all tasks complete and verified:
- Verify all tests pass
- Present options for creating PR or committing
- Execute the chosen option

## When to Stop and Ask

**STOP executing immediately when:**
- Hit a blocker (missing dependency, test fails, instruction unclear)
- Plan has critical gaps
- You don't understand an instruction
- Verification fails repeatedly

**Ask for clarification rather than guessing.**

## Red Flags

**Never:**
- Execute without reviewing plan first
- Skip verifications
- Proceed with unfixed Critical issues
- Guess when blocked

**Subagent mode specific:**
- Never dispatch multiple implementation subagents in parallel (conflicts)
- Never skip code review between tasks
- If subagent fails, dispatch fix subagent with specific instructions (don't fix manually)

## Quick Reference

| Mode | Review By | Best For | Overhead |
|------|-----------|----------|----------|
| Batch | Human | Needs oversight, uncertain plan | Lower |
| Subagent | Automated | Independent tasks, well-specified | Higher |

## Integration

**Required:** `writing-plans` creates plans this skill executes

**Complementary:** `writing-tests` for TDD during task execution

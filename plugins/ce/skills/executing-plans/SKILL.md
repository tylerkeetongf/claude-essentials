---
name: executing-plans
description: Executes implementation plans autonomously with wave-based parallel subagents. Uses complexity tiers to right-size agent dispatch, auto-recovers from errors, and verifies at completion.
---

# Executing Plans

Load plan, analyze dependencies, execute in parallel waves, verify at completion.

**Core principle:** Autonomous execution. Run to completion, only stop for true blockers.

**Efficiency principle:** Dispatch based on task complexity. Simple tasks bundle items for one agent. Standard tasks get dedicated agents with TDD.

## Plan Loading

Identify and parse the plan:

**Single-file plans** (explicit path):

- User provides path like `./plans/YYYY-MM-DD-feature.md`
- Parse `### Task N:` sections
- Extract `**Complexity:**` to determine dispatch strategy (Simple vs Standard)
- Extract `**Context:**` blocks for file dependencies
- Extract `**Verify:**` commands for verification

**Multi-file plans** (folder structure):

- User provides folder path like `./plans/YYYY-MM-DD-feature/`
- Start with `README.md` - this is the master tracking document
- Parse the phase table in Section 4 to identify phase files and their status
- Load each phase file (`phase-N-*.md`) for task details
- Execute phases in order based on prerequisites

**Native plan-mode** (current session):

- Plan is already in the conversation context from plan mode
- No need to search `~/.claude/plans/` - that would risk loading stale plans from other sessions
- Parse the plan content directly from context
- Parse numbered lists, checklists, or markdown sections as tasks
- Infer file targets from task descriptions

Create TodoWrite with all parsed tasks before execution.

## Dependency Analysis

Analyze file overlap to group tasks into execution waves. Items within a task execute sequentially by one agent.

**Tasks are independent (same wave) when:**

- No overlapping file paths in their Context blocks
- Different subsystems (different top-level directories)
- No explicit ordering in plan

**Tasks depend on each other (sequential waves) when:**

- Task A modifies a file Task B creates
- Task A imports from Task B's output
- Task A tests functionality Task B implements
- Plan explicitly states ordering

**Example wave computation:**

```
Task 1 (Simple): API Types Setup - 3 items bundled
Task 2 (Simple): Config Constants - 2 items bundled
Task 3 (Standard): Retry Logic - TDD cycle
Task 4 (Standard): Handler Tests - TDD cycle

Wave 1: [Task 1, Task 2]  <- parallel, independent Simple tasks
Wave 2: [Task 3]          <- depends on types from Task 1
Wave 3: [Task 4]          <- depends on implementation from Task 3
```

If dependency analysis is unclear, ask before proceeding.

## Wave Execution

For each wave, dispatch all tasks in parallel using multiple Task tool calls in a single message. Use the appropriate agent based on complexity tier.

```
# Wave 1 - dispatch based on complexity

# Simple task: ce:haiku handles all bundled items
Task tool (ce:haiku):
  description: "Task 1: API Types Setup"
  prompt: |
    Execute Task 1 from [plan-file].

    Complexity: Simple (bundled items)

    Context (read first):
    - src/types/index.ts
    - src/api/client.ts

    Complete ALL items in order:
    1. Create src/types/api-responses.ts with ApiResponse<T> interface
    2. Export ApiResponse from src/types/index.ts
    3. Add ResponseStatus enum to api-responses.ts

    Verify: npm run typecheck
    Commit when complete: /ce:commit

    Report: Files changed, verification output

# Standard task: general-purpose handles TDD cycle
Task tool (general-purpose):
  description: "Task 3: Retry Logic"
  prompt: |
    Execute Task 3 from [plan-file].

    Complexity: Standard (TDD required)

    Context (read first):
    - src/api/client.ts
    - tests/api/client.test.ts

    Follow TDD cycle:
    1. Red: Write failing test for retry behavior
    2. Green: Implement minimal retry logic
    3. Refactor: Clean up, run lint

    Verify: npm test -- tests/api/client.test.ts
    Commit when complete: /ce:commit

    Report: Test results, implementation summary, files changed
```

Wait for all parallel tasks to complete. Mark completed in TodoWrite. Proceed to next wave.

## Multi-File Plan Execution

For plans split across multiple files, execute at the phase level with progress tracking.

**Execution flow:**

1. Read `README.md` to understand overall structure and current progress
2. Load context from Section 3 (Context Loading)
3. Check phase table for first incomplete phase
4. Load that phase file and execute its tasks using wave-based execution
5. Update README.md phase status when complete
6. Repeat until all phases complete

**Phase status tracking:**

After completing each phase, update the README.md phase table:

```markdown
| Phase | Document                                           | Status      | Description               |
| ----- | -------------------------------------------------- | ----------- | ------------------------- |
| 1     | [phase-1-foundation.md](./phase-1-foundation.md)   | COMPLETED   | Core infrastructure setup |
| 2     | [phase-2-features.md](./phase-2-features.md)       | IN_PROGRESS | Feature implementation    |
| 3     | [phase-3-integration.md](./phase-3-integration.md) | NOT_STARTED | Integration and polish    |
```

Also update the phase file's own status header:

```markdown
> **Status:** COMPLETED
```

**Resuming interrupted multi-file plans:**

When resuming execution of a multi-file plan:

1. Read README.md phase table to find current state
2. Find first phase with status `IN_PROGRESS` or `NOT_STARTED`
3. If a phase is `IN_PROGRESS`, read its task checkboxes to find incomplete tasks
4. Resume from the first incomplete task

**Phase-level parallelization:**

Phases typically execute sequentially (Phase 2 depends on Phase 1). However, if the README.md explicitly marks phases as independent:

```markdown
## 5. Execution Order

Phases 2 and 3 can run in parallel after Phase 1 completes.
```

Then dispatch those phases as parallel subagents:

```
Task tool (general-purpose):
  description: "Execute Phase 2: Features"
  prompt: |
    Execute all tasks in ./plans/2024-01-15-feature/phase-2-features.md
    [standard execution instructions]

Task tool (general-purpose):
  description: "Execute Phase 3: Integration"
  prompt: |
    Execute all tasks in ./plans/2024-01-15-feature/phase-3-integration.md
    [standard execution instructions]
```

**Subagent prompt requirements:**

- Specific scope (which files)
- Clear constraints (stay in scope)
- Expected report format
- Plan file reference for context

### Common Mistakes

**Too broad:** "Fix all the tests" - agent gets lost trying to tackle everything at once.
Better: "Fix agent-tool-abort.test.ts" - focused scope the agent can actually handle.

**No context:** "Fix the race condition" - agent doesn't know where to look.
Better: Paste the error messages and test names so the agent has something concrete to work with.

**No constraints:** Agent might refactor your entire codebase when you just wanted a small fix.
Better: "Do NOT change production code" or "Fix tests only" - explicit boundaries.

**Vague output:** "Fix it" - you have no idea what actually changed.
Better: "Return summary of root cause and changes" - structured report you can verify.

### When NOT to Parallelize

Not every multi-task situation benefits from parallel agents:

- **Related failures:** If fixing one problem might fix others, investigate together first
- **Exploratory debugging:** You don't know what's broken yet - need to understand the system
- **Shared state:** Agents would interfere (editing same files, using same resources)
- **Need full context:** Understanding requires seeing the entire system, not isolated pieces

### Agent Selection

Agent selection is driven by the task's complexity tier from the plan:

| Complexity | Agent | Dispatch Pattern |
|------------|-------|------------------|
| Simple | ce:haiku | All bundled items in one call |
| Standard | general-purpose | Full TDD cycle in one call |

**Simple tasks (ce:haiku):**
- Multiple bundled items executed sequentially
- No judgment needed - just follow the checklist
- Single verification at end of all items
- One commit for the whole task

**Standard tasks (general-purpose):**
- Full TDD cycle: Red → Green → Refactor
- May need to make implementation decisions
- Verification at each TDD step
- One commit after refactor

**The heuristic:** Look at `**Complexity:**` in the task. If it says Simple, use haiku. If it says Standard, use general-purpose. If it's missing, infer from structure: checklist of items = Simple, TDD steps = Standard.

## Auto-Recovery

When a subagent reports failure, classify and respond:

**Recoverable errors** - dispatch fix subagent:

- Test failures
- Type errors
- Lint issues
- Build errors with clear cause

```
Task tool (general-purpose):
  description: "Fix Task N errors"
  prompt: |
    Task N from [plan-file] failed with:

    [error output]

    Files involved: [list]

    Fix the errors and verify the fix works.
    Commit when resolved.

    Report: What caused it, what you fixed, verification result
```

**True blockers** - stop and ask:

- Missing dependencies that can't be inferred
- Ambiguous instructions
- Security concerns (secrets, unsafe operations)
- Circular dependencies
- Same error failing 2+ times after fix attempts

When stopped, report what was completed and ask for guidance.

## Final Verification

After all waves complete (or all phases for multi-file plans):

1. **Run full test suite** (not just individual task tests)
2. **Run build/compile** to verify everything integrates
3. **Run linter** to catch remaining issues

4. **Dispatch code-reviewer for comprehensive review:**

```
Task tool (ce:code-reviewer):
  description: "Review complete implementation"
  prompt: |
    Review the entire implementation from [plan-file or plan-folder/README.md].

    Compare current state against main branch (or pre-plan state).

    Assess:
    - All plan requirements met (check success criteria in spec)
    - Architecture alignment
    - Cross-cutting concerns (error handling, logging, security)
    - Test coverage adequate
    - Merge readiness

    Provide: Summary, any critical issues, recommendations. Only highlight issues, do not output complements. We only care about what needs to be fixed/refactored.
```

Fix all issues that are identified

5. **Update plan status:**

   - Single-file: Update `> **Status:** COMPLETED` header
   - Multi-file: Update README.md header status AND mark all phase statuses as `COMPLETED`

6. **Archive completed plan:**
   Move the plan from `plans/` to a sibling `done/` folder to keep the plans directory clean:

   ```bash
   # Create done folder if it doesn't exist (sibling to plans/)
   mkdir -p <parent-of-plans>/done

   # Move the completed plan
   # Single-file: plans/2024-01-15-feature.md → done/2024-01-15-feature.md
   # Multi-file:  plans/2024-01-15-feature/  → done/2024-01-15-feature/
   mv <plan-path> <parent-of-plans>/done/
   ```

7. **Present summary and options:**
   - Implementation complete: [summary]
   - Tests: [pass/fail count]
   - Review findings: [summary]
   - Options: Create PR / Commit to branch / Address findings first

## When to Stop

**Stop and ask for:**

- Ambiguous plan instructions that can't be inferred
- Security concerns (secrets in code, unsafe operations)
- Circular dependencies that can't be resolved
- Repeated auto-recovery failures (same error 2+ times)
- Missing critical information (no test command, no build command)

**Do NOT stop for:**

- Fixable test failures (auto-recover)
- Type errors (auto-recover)
- Style/lint issues (auto-recover)
- Minor review suggestions (note and continue)
- Warnings that don't block execution

## Quick Reference

| Aspect | Approach |
|--------|----------|
| Simple tasks | ce:haiku - all bundled items in one dispatch |
| Standard tasks | general-purpose - full TDD cycle in one dispatch |
| Parallelization | Independent tasks in same wave, items within task are sequential |
| Review timing | Single final review at completion |
| Human checkpoints | None until final verification |
| Plan formats | Single-file, multi-file (folder), or current session plan-mode |
| Multi-file plans | Execute phases sequentially, update README.md status after each |
| Error handling | Auto-recover, stop only for blockers |

**Token efficiency:** Each subagent costs ~800-1000 tokens overhead. Bundling 5 items into one Simple task saves ~4000 tokens vs separate dispatch.

## Integration

**Prerequisite:** `Skill(ce:writing-plans)` creates plans this skill executes

**Complementary:**

- `Skill(ce:writing-tests)` for test writing tasks - use when plan includes test creation
- `Skill(ce:documenting-systems)` for documentation tasks - use when plan includes README, API docs, or technical documentation
- `Skill(ce:verification-before-completion)` for final verification patterns

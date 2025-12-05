---
name: writing-plans
description: Create comprehensive, context-aware implementation plans using TDD and Spec-Driven patterns
---

# Writing Plans

Write detailed, step-by-step implementation plans designed for an agentic coding workflow. Assume the executor has zero context. The plan must act as a single source of truth, containing the spec, context, and execution steps.

**Save plans to:** `./plans/YYYY-MM-DD-<feature-name>.md`

## Plan Document Structure

````

# [Feature Name] Implementation Plan

> **Status:** DRAFT | APPROVED | IN_PROGRESS | COMPLETED

## 1. Specification

**User Story:** [As a... I want to... So that...]
**Success Criteria:**

- [ ] Criterion 1
- [ ] Criterion 2

## 2. Architecture & Strategy

**Approach:** [High-level technical approach]
**Key Components:**

- `ComponentA`: Responsibilities...
- `ComponentB`: Responsibilities...

## 3. Context Loading

_Instructions for the agent: Run these commands to load necessary context before starting._

```bash
glob src/relevant/path/*.ts
read src/specific/interface.ts
load Skill(command=<a relevant skill related to the task>)
````

---

## 4. Implementation Tasks

### Task [N]: [Component/Feature Name]

**Goal:** [Brief description of what this specific task achieves]

**Relevant Files:**

- `src/path/to/file.ts`
- `tests/path/to/file.test.ts`

**Step 1: TDD - Red (Failing Test)**

- [ ] Create/Modify test file: `tests/path/to/file.test.ts`
- [ ] Add test case: `it('should [expected behavior]...')`
- [ ] **VERIFY:** Run `npm test -- tests/path/to/file.test.ts`
  - _Expected Output:_ `FAIL` (ReferenceError or expectation mismatch)

**Step 2: TDD - Green (Minimal Implementation)**

- [ ] Create/Modify source file: `src/path/to/file.ts`
- [ ] Implement minimal code to satisfy the test.
- [ ] **VERIFY:** @example Run `yarn test -- tests/path/to/file.test.ts`
  - _Expected Output:_ `PASS`

**Step 3: Refactor & Integration**

- [ ] Optimize code if necessary (clean up types, remove hardcoding).
- [ ] Run linter: @example `yarn lint`
- [ ] **COMMIT:** use the `/ce:commit` command

---

### Task [N+1]: [Next Component]

...

````

## Best Practices for Plan Generation

1.  **Explicit file paths:** Never say "create a utility." Say "create `src/utils/string-helpers.ts`."
2.  **One-shot context:** The "Context Loading" section is vital. It tells the implementing agent *exactly* what to read so it doesn't waste tokens searching the file tree.
3.  **Verification is mandatory:** Every code change must have a corresponding CLI command to verify it (test, lint, etc).
4.  **Atomic Commits:** Each task ends with a commit. This creates save points.

## Post-Generation Prompt

**"Plan saved to `./plans/YYYY-MM-DD-<feature-name>.md`.**

To execute this plan, I recommend:
1.  **Load Context:** Run the commands in Section 3.
2.  **Execute Task 1:** Use the `@ce:executing-plans` skill.

**Shall I initialize the plan file now?"**
```

### Explanation of Changes
1.  **Folder Convention (`./plans/`)**: Moving plans to a dedicated directory prevents clutter in the root and makes it easier to `.gitignore` or organize planning documents.
2.  **Context Loading Section**: This is the single biggest quality-of-life improvement for Claude Code. By explicitly listing `glob` and `read` commands, you allow the executing agent to hydrate its context immediately without hallucinating file structures.
3.  **Status & Metadata**: Added a header block for status. This is useful when you pause and resume sessions; the agent can read the status line to know where it left off.
4.  **Split Verification**: The original "Step 1" combined writing and running. Splitting them forces the agent to *stop* and actually run the command, which catches environment issues (like missing dependencies) before code is written.
````

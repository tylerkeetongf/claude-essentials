---
name: writing-plans
description: Create comprehensive, context-aware implementation plans with right-sized tasks. Uses complexity tiers to balance efficiency with parallelization.
---

# Writing Plans

Write detailed, step-by-step implementation plans designed for an agentic coding workflow. Assume the executor has zero context. The plan must act as a single source of truth, containing the spec, context, and execution steps.

**Save plans to:** `./plans/YYYY-MM-DD-<feature-name>.md`

**For large plans (1000+ lines):** Split into multiple files within a folder at `./plans/YYYY-MM-DD-<feature-name>/` (see "Multi-File Plan Structure" section below)

## Task Sizing Guidelines

Tasks fall into complexity tiers that determine their structure and how they're executed:

| Tier | Effort | Examples | Structure | Agent |
|------|--------|----------|-----------|-------|
| Simple | 1-5 min | Config changes, type definitions, exports, renames | Checklist of items | ce:haiku |
| Standard | 15-60 min | Feature with tests, bug fix, component | Full TDD cycle | general-purpose |
| Complex | 1+ hours | Multi-component feature, large refactor | Break into Standard tasks | - |

**Decision tree:**
- Is it a single-line or purely mechanical change? → **Simple** (bundle with related items)
- Does it need new tests written? → **Standard** (use TDD structure)
- Will it take more than an hour? → **Break it down** into Standard tasks

**Bundling simple tasks:**
Group 3-7 related simple items into one task. They should share context (same subsystem, same purpose). Don't bundle unrelated items just because they're small.

**Good bundle:** "Add API response types" - create interface, add enum, export from index
**Bad bundle:** "Misc cleanup" - add type, fix README typo, update version - these share no context

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

Tasks are structured based on their complexity tier. Use the right format for each.

---

### Simple Task Format

Use for mechanical changes that don't need TDD. Bundle related items together.

```markdown
### Task [N]: [Descriptive Name]
**Complexity:** Simple

**Context:** `src/types/`, `src/api/client.ts`

**Items:**
1. [ ] Create `src/types/api-responses.ts` with `ApiResponse<T>` interface
2. [ ] Export `ApiResponse` from `src/types/index.ts`
3. [ ] Add `ResponseStatus` enum to `src/types/api-responses.ts`

**Verify:** `npm run typecheck`
**Commit:** `/ce:commit`
```

---

### Standard Task Format

Use for features requiring implementation decisions and tests.

```markdown
### Task [N]: [Feature Name]
**Complexity:** Standard

**Context:** `src/api/client.ts`, `tests/api/client.test.ts`

**Red (Failing Test):**
- [ ] Add test: `it('should retry failed requests up to 3 times')`
- [ ] **Verify:** `npm test -- tests/api/client.test.ts` → FAIL

**Green (Implementation):**
- [ ] Implement retry logic in `fetchWithRetry()` function
- [ ] **Verify:** `npm test -- tests/api/client.test.ts` → PASS

**Refactor:**
- [ ] Extract retry config to constants
- [ ] Run linter: `npm run lint`
- [ ] **Commit:** `/ce:commit`
```

---

### Task [N+1]: [Next Task]

...

````

## Best Practices for Plan Generation

1.  **Right-size tasks:** Match structure to complexity. Don't force TDD on config changes; don't bundle unrelated items.
2.  **Explicit file paths:** Never say "create a utility." Say "create `src/utils/string-helpers.ts`."
3.  **One-shot context:** The "Context" field per task tells the agent exactly what to read. Don't make agents search.
4.  **Verification is mandatory:** Every task ends with a verify command (test, typecheck, lint).
5.  **Commits per task:** Each task ends with a commit, not each item within a task. This creates meaningful save points.
6.  **Bundle by context:** Group simple items that share understanding (same subsystem, same purpose). 3-7 items is the sweet spot.

## Multi-File Plan Structure

When a plan exceeds ~1000 lines, break it into multiple files to keep each document focused and manageable. Create a folder instead of a single file.

**Folder structure:**
```
./plans/YYYY-MM-DD-<feature-name>/
├── README.md              # Main overview and tracking (always start here)
├── phase-1-<name>.md      # First major phase
├── phase-2-<name>.md      # Second major phase
└── phase-N-<name>.md      # Additional phases as needed
```

**README.md (Main Overview):**
```markdown
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
```

## 4. Phase Overview & Progress

| Phase | Document | Status | Description |
|-------|----------|--------|-------------|
| 1 | [phase-1-foundation.md](./phase-1-foundation.md) | NOT_STARTED | Core infrastructure setup |
| 2 | [phase-2-features.md](./phase-2-features.md) | NOT_STARTED | Feature implementation |
| 3 | [phase-3-integration.md](./phase-3-integration.md) | NOT_STARTED | Integration and polish |

## 5. Execution Order

1. Load context (Section 3)
2. Complete Phase 1 before starting Phase 2
3. Phases may have internal parallelization noted in their docs
```

**Phase document structure:**
Each phase document follows the same task format as single-file plans but focuses on one logical grouping of work.

```markdown
# Phase N: [Phase Name]

> **Status:** NOT_STARTED | IN_PROGRESS | COMPLETED
> **Prerequisites:** [List any phases that must complete first]

## Context Loading (Phase-Specific)

_Additional context needed for this phase:_

```bash
read src/specific/to/this/phase.ts
```

## Tasks

### Task N.1: [Component Name]
**Complexity:** Simple | Standard
[Use appropriate format based on complexity tier...]

### Task N.2: [Next Component]
**Complexity:** Simple | Standard
[Use appropriate format...]
```

**When to split:**
- Plan is approaching or exceeding 1000 lines
- Natural phase boundaries exist (setup, core features, integration, etc.)
- Multiple developers might work on different phases
- You want to track progress at a phase level

## Post-Generation Prompt

**For single-file plans:**

> Plan saved to `./plans/YYYY-MM-DD-<feature-name>.md`.
>
> To execute this plan:
> 1. **Load Context:** Run the commands in Section 3.
> 2. **Execute Task 1:** Use the `Skill(ce:executing-plans)` skill.
>
> Shall I initialize the plan file now?

**For multi-file plans:**

> Plan saved to `./plans/YYYY-MM-DD-<feature-name>/`.
>
> Files created:
> - `README.md` - Main overview and progress tracking
> - `phase-1-<name>.md` - [Description]
> - `phase-2-<name>.md` - [Description]
> - ...
>
> To execute this plan:
> 1. **Load Context:** Run the commands in README.md Section 3.
> 2. **Execute Phase 1:** Open `phase-1-<name>.md` and use `Skill(ce:executing-plans)`.
> 3. **Update Progress:** Mark phases complete in README.md as you finish them.
>
> Shall I initialize the plan folder now?
```

### Explanation of Design Decisions
1.  **Complexity Tiers**: Not all tasks need TDD. Simple mechanical changes (add a type, export something) waste tokens when forced through Red/Green/Refactor. Tiers let you match structure to the work.
2.  **Task Bundling**: Each subagent costs ~800-1000 tokens overhead. Bundling 5 simple items into one task saves ~4000 tokens vs dispatching them separately.
3.  **Folder Convention (`./plans/`)**: Moving plans to a dedicated directory prevents clutter in the root and makes it easier to `.gitignore` or organize planning documents.
4.  **Context Loading Section**: This is the single biggest quality-of-life improvement for Claude Code. By explicitly listing `glob` and `read` commands, you allow the executing agent to hydrate its context immediately without hallucinating file structures.
5.  **Status & Metadata**: Added a header block for status. This is useful when you pause and resume sessions; the agent can read the status line to know where it left off.
6.  **Multi-File Plans**: Large plans (1000+ lines) get unwieldy in a single file. Breaking them into phases with a central README provides: clear progress tracking at the phase level, ability to work on phases independently, reduced cognitive load when reading any single document, and natural parallelization boundaries for team work.

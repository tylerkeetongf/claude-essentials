---
name: writing-tests
description: Write behavior-focused tests following Testing Trophy model with real dependencies, avoiding common anti-patterns like testing mocks and polluting production code
---

# Writing Tests

**Core Philosophy:** Test user-observable behavior with real dependencies. Tests should survive refactoring when behavior is unchanged.

**Iron Laws:**
1. Test real behavior, not mock behavior
2. Never add test-only methods to production code
3. Never mock without understanding dependencies

## Testing Trophy Model

Write tests in this priority order:

1. **Integration Tests (PRIMARY)** - Multiple units with real dependencies
2. **E2E Tests (SECONDARY)** - Complete workflows across the stack
3. **Unit Tests (RARE)** - Pure functions only (no dependencies)

**Default to integration tests.** Only drop to unit tests for pure utility functions.

## Pre-Test Workflow

BEFORE writing any tests:

1. **Review project standards** - Check `.cursor/rules/*`, testing docs, or `*test*.md` files
2. **Understand behavior** - What should this do? What can go wrong?
3. **Choose test type** - Integration (default), E2E (critical workflows), or Unit (pure functions)
4. **Identify dependencies** - What needs to be real vs mocked?

## Test Type Decision

```
Is this a complete user workflow?
  → YES: E2E test (Playwright/Cypress)

Is this a pure function (no side effects/dependencies)?
  → YES: Unit test

Everything else:
  → Integration test (with real dependencies)
```

## Mocking Guidelines

**Default: Don't mock. Use real dependencies.**

### Only Mock These

- External APIs (fetch, HTTP requests)
- Timers (setTimeout, setInterval, Date.now)
- Randomness (Math.random, crypto)
- File I/O
- Browser APIs (window.location, localStorage)
- Third-party services (payments, analytics)

### Never Mock These

- State management (Redux, Zustand, Context)
- Providers/Context
- Child components
- Internal modules
- Hooks/composables
- Routing (use memory router instead)

**Why:** Mocking internal dependencies creates brittle tests that break during refactoring.

### Before Mocking, Ask:

1. "What side effects does this method have?"
2. "Does my test depend on those side effects?"
3. If yes → Mock at lower level (the slow/external operation, not the method test needs)
4. Unsure? → Run with real implementation first, observe what's needed, THEN add minimal mocking

### Mock Red Flags

- "I'll mock this to be safe"
- "This might be slow, better mock it"
- Can't explain why mock is needed
- Mock setup longer than test logic
- Test fails when removing mock

## Integration Test Pattern

```javascript
describe("Feature Name", () => {
  // Real state/providers, not mocks
  const setup = (initialState = {}) => {
    return render(<Component />, {
      wrapper: ({ children }) => (
        <StateProvider initialState={initialState}>{children}</StateProvider>
      ),
    });
  };

  it("should show result when user performs action", async () => {
    setup({ items: [] });

    // Semantic query (role/label/text)
    const button = screen.getByRole("button", { name: /add item/i });
    await userEvent.click(button);

    // Assert on UI output
    await waitFor(() => expect(screen.getByText(/item added/i)).toBeVisible());
  });
});
```

## E2E Test Pattern

```javascript
test("should complete workflow when user takes action", async ({ page }) => {
  await page.goto("/dashboard");

  // Given: precondition
  await expect(page.getByRole("heading", { name: "Dashboard" })).toBeVisible();

  // When: user action
  await page.getByRole("button", { name: "Add Item" }).click();

  // Then: expected outcome
  await expect(page.getByText("Item added successfully")).toBeVisible();
});
```

## Query Strategy

**Use semantic queries (order of preference):**

1. `getByRole('button', { name: /submit/i })` - Accessibility-based
2. `getByLabelText(/email/i)` - Form labels
3. `getByText(/welcome/i)` - Visible text
4. `getByPlaceholderText(/search/i)` - Input placeholders

**Avoid:**

- `getByTestId` - Implementation detail
- CSS selectors - Brittle, breaks during refactoring
- Internal state queries - Not user-observable

## String Management

**Use source constants, not hard-coded strings:**

```javascript
// Good - References actual constant
import { MESSAGES } from "@/constants/messages";
expect(screen.getByText(MESSAGES.SUCCESS)).toBeVisible();

// Bad - Hard-coded, breaks when copy changes
expect(screen.getByText("Action completed successfully!")).toBeVisible();
```

## Anti-Patterns to Avoid

### Testing Mock Behavior

```typescript
// BAD: Testing mock existence, not real behavior
test('renders sidebar', () => {
  render(<Page />);
  expect(screen.getByTestId('sidebar-mock')).toBeInTheDocument();
});

// GOOD: Test real component with semantic query
test('renders sidebar', () => {
  render(<Page />);  // Don't mock sidebar
  expect(screen.getByRole('navigation')).toBeInTheDocument();
});
```

**Gate:** Before asserting on mock elements, ask "Am I testing real behavior or mock existence?" If testing mocks → Stop, delete assertion or unmock.

### Test-Only Methods in Production

```typescript
// BAD: destroy() only used in tests - pollutes production class
class Session {
  async destroy() {
    await this._workspaceManager?.destroyWorkspace(this.id);
  }
}

afterEach(() => session.destroy());

// GOOD: Test utilities handle cleanup
// In test-utils/cleanupSession.ts
export async function cleanupSession(session: Session) {
  const workspace = session.getWorkspaceInfo();
  if (workspace) await workspaceManager.destroyWorkspace(workspace.id);
}

afterEach(() => cleanupSession(session));
```

**Gate:** Before adding methods to production classes, ask "Is this only for tests?" Yes → Put in test utilities.

### Mocking Without Understanding

```typescript
// BAD: Mock prevents side effect test depends on
test('detects duplicate server', () => {
  vi.mock('ToolCatalog', () => ({
    discoverAndCacheTools: vi.fn().mockResolvedValue(undefined)
  }));

  await addServer(config);
  await addServer(config);  // Should detect duplicate, won't!
});

// GOOD: Mock at correct level, preserve needed behavior
test('detects duplicate server', () => {
  vi.mock('MCPServerManager'); // Mock slow startup only

  await addServer(config);  // Config written
  await addServer(config);  // Duplicate detected
});
```

### Incomplete Mocks

```typescript
// BAD: Partial mock - missing fields downstream code needs
const mockResponse = {
  status: 'success',
  data: { userId: '123', name: 'Alice' }
  // Missing: metadata.requestId that downstream code uses
};

// GOOD: Mirror real API completely
const mockResponse = {
  status: 'success',
  data: { userId: '123', name: 'Alice' },
  metadata: { requestId: 'req-789', timestamp: 1234567890 }
};
```

**Gate:** Before creating mocks, check "What fields does real API return?" Include ALL fields, not just what your test uses.

## TDD Prevents Anti-Patterns

1. **Write test first** → Think about what you're testing (not mocks)
2. **Watch it fail** → Confirms test tests real behavior
3. **Minimal implementation** → No test-only methods creep in
4. **Real dependencies first** → See what test needs before mocking

**If testing mock behavior, you violated TDD** - you added mocks without watching test fail against real code.

## Quality Checklist

Before completing tests, verify:

- [ ] Happy path covered
- [ ] Error conditions handled
- [ ] Loading states tested
- [ ] User interactions simulated realistically
- [ ] Accessibility queries used (role, label, text)
- [ ] Real dependencies used (minimal mocking)
- [ ] Condition-based waiting used (see `condition-based-waiting` skill)
- [ ] Tests survive refactoring (no implementation details)
- [ ] No test-only methods added to production code
- [ ] No assertions on mock existence

## What NOT to Test

- Internal state
- Component props
- Function call counts
- CSS classes
- Test IDs
- Implementation details
- Mock existence

**Test behavior users see, not code structure.**

## Quick Reference

| Test Type   | When                | Dependencies | Tools      |
| ----------- | ------------------- | ------------ | ---------- |
| Integration | Default             | Real         | Jest + RTL |
| E2E         | Critical workflows  | Real         | Playwright |
| Unit        | Pure functions only | None         | Jest       |

| Anti-Pattern | Fix |
|--------------|-----|
| Testing mock existence | Test real component or unmock |
| Test-only methods in production | Move to test utilities |
| Mocking without understanding | Understand dependencies, mock minimally |
| Incomplete mocks | Mirror real API completely with all fields |
| Tests as afterthought | TDD - write tests first |

**Remember:** Behavior over implementation. Real over mocked. Semantic over structural.

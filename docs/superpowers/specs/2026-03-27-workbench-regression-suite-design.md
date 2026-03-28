# Workbench Regression Suite — Design Document

**Date**: 2026-03-27
**Feature**: 037-workbench-regression-suite
**Status**: Design approved

## Goal

Provide a comprehensive, AI-agent-executable regression test suite for the MHG Workbench application that can be invoked via a single skill command, integrated into the shipping pipeline, and maintained alongside feature development.

## Problem

The existing regression coverage (`regression-targets.md`) has only 5 manual flows. The workbench has grown to 6+ major modules with 31+ permissions, 7 user roles, 3 locales, and responsive layouts. Post-deploy verification is shallow and ad-hoc, leading to regressions that surface late.

## Scope

### In scope

1. **Test definition layer** (DONE): 124 YAML test cases across 16 modules in `regression-suite/`
2. **Runner skill**: `/mhg.regression` command that executes tests via Playwright MCP tools
3. **Ship pipeline integration**: Update `/mhg.ship` Phase 4 to use the new suite
4. **CI automation**: GitHub Actions workflow for scheduled/dispatch regression runs
5. **Maintenance workflow**: Conventions for adding/updating/removing tests as features evolve

### Out of scope

- Unit tests or component tests (covered by `chat-ui` Playwright specs and `workbench-frontend` Vitest)
- Backend API regression (this suite tests the UI surface only)
- Production environment testing (dev environment only; prod uses post-deploy smoke via different mechanism)
- Test data seeding automation (relies on existing `global-setup.ts` seed in `chat-ui`)

## Architecture

### Component 1: Test Definition Layer (exists)

```
regression-suite/
  _config.yaml              # Environment URLs, accounts, timeouts, known errors
  _runner-guide.md          # Agent execution protocol documentation
  01-auth.yaml ... 16-cross-cutting.yaml   # 16 module files, 124 tests
  results/                  # Run output directory
```

Each test case is a YAML object with:
- `id`, `title`, `priority` (P0-P3), `tags`, `role`, `viewport`
- `prerequisites`, `depends_on` (test ID references)
- `steps[]` — ordered MCP tool actions with params and assertions
- `pass_criteria[]`, `error_signatures[]`

Tests are grouped by module. Modules are executed in dependency order defined in `_config.yaml.execution_order`. AUTH-001 is the gate test — if it fails, the entire run aborts.

### Component 2: Runner Skill — `/mhg.regression`

**Location**: `.claude/skills/mhg.regression/SKILL.md`

**Invocation**:
```
/mhg.regression smoke          # P0 only, ~10 min
/mhg.regression standard       # P0+P1, ~30 min
/mhg.regression full           # All priorities, ~60 min
/mhg.regression module:03-review-queue   # Single module
```

**Execution flow**:

```
Parse mode argument
       |
Read _config.yaml → resolve environment, accounts, timeouts
       |
Load module YAML files → filter by priority
       |
Execute AUTH-001 (gate) ──FAIL──> Abort, write failure report
       |PASS
       |
For each module in execution_order:
  For each test (filtered):
    Check depends_on → skip if dependency failed
    Check role → re-auth if different
    Check viewport → resize if different
    Execute steps sequentially:
      Call Playwright MCP tool
      Evaluate assertions
      On failure: screenshot, record, continue
    Evidence capture (console + network)
    Record result
       |
Write results/{timestamp}.yaml
Write results/{timestamp}.md
Print summary to user
```

**Key behaviors**:
- Session reuse: authenticate once, reuse for all owner-role tests
- Role switching: logout + re-auth when test requires different role, then switch back
- Failure isolation: one test failure does not abort the module — continues to next test
- Evidence capture: mandatory `browser_console_messages` + `browser_network_requests` after every test
- Known error filtering: console/network errors matched against `_config.yaml.known_acceptable_*` are not flagged

**Result format**:

Structured YAML (`results/{timestamp}.yaml`):
```yaml
run:
  id: "{timestamp}"
  mode: "{smoke|standard|full|module:XX}"
  environment: dev
  started: "{ISO}"
  completed: "{ISO}"
  duration_seconds: N
summary:
  total: N
  passed: N
  failed: N
  skipped: N
  pass_rate: "N%"
  by_priority: { P0: {...}, P1: {...}, ... }
  by_module: { auth: {...}, navigation: {...}, ... }
failures:
  - id: "XX-NNN"
    step: N
    expected: "..."
    actual: "..."
    screenshot: "results/XX-NNN-failure.png"
skipped:
  - id: "XX-NNN"
    reason: "..."
global_health:
  console_errors_unexpected: N
  network_errors_unexpected: N
  i18n_literal_keys_found: [...]
```

Human-readable markdown (`results/{timestamp}.md`):
- Summary table by priority and module
- Failure details with screenshots
- Known issues encountered
- Recommendations

### Component 3: Ship Pipeline Integration

Update `.claude/skills/mhg.ship/SKILL.md` Phase 4:

**Current**: Phase 4 reads `references/regression-targets.md` and manually walks through 5 flows using Playwright MCP tools.

**New**: Phase 4 invokes `/mhg.regression smoke` (or `standard` based on user preference). The skill handles execution, result writing, and pass/fail determination.

**Changes required**:
1. Replace Phase 4's inline flow instructions with a skill invocation
2. Update `references/regression-targets.md` to note it's superseded by `regression-suite/` and kept for reference only
3. Phase 4 pass/fail is determined by the runner skill's exit: P0 100% pass = phase passes; any P0 failure = phase fails and enters fix loop

### Component 4: CI Automation

A GitHub Actions workflow in `chat-ui` (where Playwright is already configured):

**File**: `.github/workflows/regression-suite.yml`

**Triggers**:
- `workflow_dispatch` with mode input (smoke/standard/full)
- `repository_dispatch` event from chat-backend/chat-frontend/workbench-frontend deploy workflows
- Optional: daily schedule for `standard` runs

**Implementation approach**:
- The workflow checks out `client-spec` to access `regression-suite/` YAML definitions
- Runs a Node.js script that translates YAML test definitions into Playwright test calls
- Uses the existing `chat-ui` Playwright infrastructure (fixtures, auth helpers, global setup)
- Outputs results as GitHub Actions artifacts

**YAML-to-Playwright translator requirements**:
- Must support these YAML step actions mapped to Playwright API: `browser_navigate` → `page.goto()`, `browser_snapshot` → `page.accessibility.snapshot()`, `browser_click` → `page.click()` / `page.getByRole().click()`, `browser_fill_form` → `page.fill()`, `browser_wait_for` → `page.waitForSelector()` / `expect().toBeVisible()`, `browser_console_messages` → `page.on('console')` listener, `browser_network_requests` → `page.on('response')` listener
- `evidence_capture` maps to collecting accumulated console + network events
- `browser_select_option` → `page.selectOption()`, `browser_resize` → `page.setViewportSize()`, `browser_press_key` → `page.keyboard.press()`
- Variable interpolation (`${workbench_url}`, `${account.email}`, `${otp_code}`) resolved from `_config.yaml` at load time
- `extract` directives capture regex matches from console output into named variables for subsequent steps
- Unsupported or unrecognized step actions must log a warning and skip (not crash the run)
- The translator must output results in the same YAML + markdown format as the agent runner

### Component 5: Maintenance Workflow

Documented conventions in `regression-suite/CONTRIBUTING.md`:

1. **When to add tests**: After any feature ships that adds or changes workbench UI behavior
2. **How to add tests**:
   - Identify the module YAML file (or create a new one if it's a new area)
   - Follow the test case schema from `_runner-guide.md`
   - Assign ID following module prefix + next number (e.g., `RQ-015`)
   - Set priority: P0 for critical path, P1 for standard workflows, P2 for edge cases, P3 for exploratory
   - Include `depends_on` if the test requires prior state
   - Add `error_signatures` for expected failure patterns
3. **When to update tests**: When a feature changes behavior that existing tests assert against
4. **When to remove tests**: When a feature is deprecated and the UI is removed
5. **Staleness detection** (future enhancement, out of scope for this spec): Extend `/speckit.analyze` to warn when a completed spec's feature area has no corresponding regression tests
6. **Changelog**: `regression-suite/CHANGELOG.md` tracks additions/removals per release cycle

## Data Flow

```
User invokes /mhg.regression <mode>
  → Skill reads _config.yaml
  → Skill loads + filters module YAML files
  → Skill calls Playwright MCP tools per step
  → Playwright MCP controls browser against dev environment
  → Browser hits workbench.dev.mentalhelp.chat → api.dev.mentalhelp.chat
  → Skill captures console/network evidence
  → Skill writes results/ YAML + MD
  → Skill prints summary to user
```

For CI:
```
Deploy workflow completes
  → repository_dispatch to chat-ui
  → GHA workflow runs regression-suite.yml
  → Node.js translator reads YAML, executes Playwright tests
  → Results uploaded as artifacts
  → Slack notification on failure (optional)
```

## Error Handling

- **AUTH-001 gate failure**: Entire run aborts with clear diagnostic (account blocked? OTP extraction failed? API down?)
- **Individual test failure**: Recorded with screenshot, continue to next test
- **Dependency chain failure**: Downstream tests auto-skipped with reason
- **Role switch failure**: Re-auth failed — skip remaining tests for that role, continue with primary role
- **Known error filtering**: Console/network errors matched against `_config.yaml` patterns are suppressed, not flagged
- **Timeout handling**: Per-step timeouts from `_config.yaml.timeouts`; step timeout = test failure, not run abort

## Pass/Fail Thresholds

| Mode | Context | Pass condition | Fail condition |
|---|---|---|---|
| `smoke` | Stand-alone or `/mhg.ship` Phase 4 | 100% P0 pass | Any P0 failure |
| `standard` | Stand-alone | 100% P0 pass AND P1 pass rate >= 90% | Any P0 failure OR P1 pass rate < 90% |
| `full` | Stand-alone | 100% P0 pass AND P1 pass rate >= 90% | Any P0 failure OR P1 pass rate < 90% |
| `module:XX` | Stand-alone | All filtered tests pass | Any test failure |

P2 and P3 failures are reported but do not affect the overall pass/fail verdict. They are informational — regressions to investigate but not blockers.

## Testing Strategy

- **Smoke validation**: Run `/mhg.regression smoke` against dev — should complete in ~10 min with AUTH-001 passing
- **Module validation**: Run `/mhg.regression module:01-auth` — verify auth tests execute correctly
- **Result validation**: Check `results/` output files parse as valid YAML and contain expected structure
- **YAML syntax**: `python -c "import yaml; yaml.safe_load(open(f))"` for each module file
- **ID uniqueness**: Script to verify all 124 test IDs are unique across all modules

## Priority Order

1. Runner skill (`/mhg.regression`) — highest value, makes suite usable
2. Ship integration (update `/mhg.ship` Phase 4) — connects suite to deployment pipeline
3. Maintenance workflow (`CONTRIBUTING.md`, changelog) — prevents staleness
4. CI automation (GHA workflow) — most infrastructure, lowest urgency

## Acceptance Criteria

### Runner skill
1. `/mhg.regression smoke` executes all P0 tests against dev and produces a pass/fail report
2. `/mhg.regression standard` executes all P0 + P1 tests with correct priority filtering
3. `/mhg.regression full` executes all tests across all priorities in dependency order
4. `/mhg.regression module:03-review-queue` executes only the tests in that module file
5. Results are written to `regression-suite/results/` in both YAML and markdown formats
6. Pass/fail thresholds are applied per the table in "Pass/Fail Thresholds" section

### Error handling behaviors
7. If AUTH-001 fails, the entire run aborts immediately with a diagnostic report (no other tests execute)
8. If a test fails, all tests listing it in `depends_on` are auto-skipped with reason "Dependency {ID} failed"
9. If role switch re-authentication fails, remaining tests for that role are skipped; run continues with primary role
10. Console/network errors matching `_config.yaml.known_acceptable_*` patterns are suppressed, not flagged

### Ship integration
11. `/mhg.ship` Phase 4 invokes the runner skill instead of manual regression flows
12. `references/regression-targets.md` is updated to reference the new suite as the canonical source

### CI automation
13. `chat-ui/.github/workflows/regression-suite.yml` accepts `workflow_dispatch` with mode input
14. The YAML-to-Playwright translator maps all documented step actions to Playwright API calls
15. Unsupported step actions log a warning and skip (do not crash the run)
16. CI results are uploaded as GitHub Actions artifacts in the same YAML + markdown format

### Maintenance
17. `regression-suite/CONTRIBUTING.md` documents when/how to add, update, and remove tests
18. `regression-suite/CHANGELOG.md` exists for tracking test additions/removals per release

### Invariants
19. All YAML test case files parse without errors (`yaml.safe_load`)
20. No duplicate test IDs exist across any module files

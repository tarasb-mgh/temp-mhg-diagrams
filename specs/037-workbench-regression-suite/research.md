# Research: Workbench Regression Test Suite

**Feature**: 037-workbench-regression-suite
**Date**: 2026-03-27

## Research Topics

### 1. Claude Code Skill Architecture for Test Execution

**Decision**: The runner skill is a single `SKILL.md` file that contains the full execution protocol as structured instructions for the AI agent. It is NOT a programmatic script — it's a prompt-based skill that the agent follows step-by-step.

**Rationale**: Claude Code skills are prompt files, not executable code. The agent reads the SKILL.md and follows the instructions, calling Playwright MCP tools as directed. This matches the existing skill pattern used by `/mhg.ship`, `/mhg.specify`, and other MHG skills.

**Alternatives considered**:
- Executable TypeScript runner in `client-spec` — rejected because `client-spec` is a meta-framework, not an application. Adding npm/TypeScript infrastructure would violate the project's purpose.
- Python runner script — rejected for same reason. The skill system is the right abstraction layer.

### 2. YAML Test Parsing Within a Skill

**Decision**: The skill instructs the agent to read `_config.yaml` and module YAML files using the `Read` tool, then interpret the YAML structure in-context to determine which tests to run and what steps to execute. No external YAML parser is needed at the skill layer.

**Rationale**: The AI agent can natively understand YAML structure when reading file contents. The `Read` tool provides the file content, and the agent parses it as part of its reasoning. This is how existing skills work — they read files and act on content.

**Alternatives considered**:
- Pre-process YAML into a simpler format (e.g., markdown checklist) — rejected because it would require a build step and lose the structured assertion data.
- Use a Python script to parse YAML and output a test plan — rejected because it adds a runtime dependency.

### 3. Playwright MCP Tool Mapping for CI

**Decision**: The CI YAML-to-Playwright translator maps each YAML step `action` to the corresponding Playwright API call:

| YAML Action | Playwright API |
|---|---|
| `browser_navigate` | `page.goto(url)` |
| `browser_snapshot` | `page.accessibility.snapshot()` (for assertions) |
| `browser_click` | `page.getByRole(...).click()` or `page.click(selector)` |
| `browser_fill_form` | `page.getByLabel(...).fill(value)` or `page.fill(selector, value)` |
| `browser_wait_for` | `page.waitForSelector(selector)` or `expect(locator).toBeVisible()` |
| `browser_console_messages` | `page.on('console', cb)` listener accumulated during test |
| `browser_network_requests` | `page.on('response', cb)` listener accumulated during test |
| `browser_select_option` | `page.selectOption(selector, value)` |
| `browser_resize` | `page.setViewportSize({ width, height })` |
| `browser_press_key` | `page.keyboard.press(key)` |
| `browser_take_screenshot` | `page.screenshot({ path, fullPage: true })` |
| `evidence_capture` | Flush console + network listeners, evaluate against known errors |

**Rationale**: This mapping aligns with Playwright's API surface and matches how the existing `chat-ui` E2E tests use Playwright. The translator is a thin adapter, not a test framework.

**Alternatives considered**:
- Generate Playwright spec files from YAML (static code generation) — rejected because it would duplicate test definitions and require regeneration on every YAML change.
- Use Playwright's test runner directly with custom fixtures that read YAML — this is actually what the translator does, just described differently.

### 4. Authentication in CI Context

**Decision**: The CI workflow reuses the existing `chat-ui` auth infrastructure: `global-setup.ts` seeds test users, and `authTest.ts` fixtures handle OTP-based storage state caching. The YAML translator maps AUTH-001's OTP flow to the existing `ensureOtpStorageState()` helper.

**Rationale**: The `chat-ui` repo already solves the OTP auth problem for CI. Building a separate auth mechanism would duplicate work and diverge from the tested pattern.

**Alternatives considered**:
- Implement OTP extraction in the translator — rejected because `chat-ui` already handles this via console listener + storage state caching.

### 5. Result Storage and Comparison

**Decision**: Results are written as timestamped YAML + markdown files in `regression-suite/results/`. No database or external service. Results are gitignored to avoid polluting the repository with run artifacts.

**Rationale**: File-based results are the simplest approach. The AI agent writes them, the user reads them. For trend analysis, results can be compared by reading multiple YAML files.

**Alternatives considered**:
- Store results in Jira — rejected because Jira is for tracking work items, not test results. Test results are ephemeral run data.
- Store results in a GCS bucket — overengineered for the current need. Can be added later if CI runs need persistent storage.

### 6. Pass/Fail Threshold Implementation

**Decision**: The runner skill computes pass/fail per the threshold table in the design doc:
- `smoke`: 100% P0 pass required
- `standard`/`full`: 100% P0 AND P1 >= 90% pass rate
- `module:XX`: All filtered tests must pass
- P2/P3 failures are informational only

The skill reads the final result counts and applies these rules to determine the overall verdict.

**Rationale**: P0 tests are critical path — any failure is a blocker. P1 tests allow a 10% margin for transient issues or known flaky tests. P2/P3 are exploratory and should never block a deploy.

**Alternatives considered**:
- All-or-nothing pass/fail — rejected because it would make the suite too brittle for standard/full modes.
- Configurable thresholds in `_config.yaml` — considered but deferred. Hardcoded thresholds are simpler and sufficient for now.

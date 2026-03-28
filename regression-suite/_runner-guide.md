# MHG Workbench Regression Suite — Agent Runner Guide

This document instructs the AI agent on how to execute the regression test suite.
The suite consists of YAML test definition files processed via Playwright MCP tools.

---

## Quick Start

```
1. Read _config.yaml → resolve environment URLs, accounts, timeouts
2. Determine execution mode (smoke | standard | full | module:XX)
3. Filter tests by priority/module
4. Execute AUTH-001 first — if it fails, ABORT the entire run
5. Process remaining modules in execution_order from _config.yaml
6. Write results to regression-suite/results/
```

---

## Execution Protocol

### Phase 1: Initialize

1. **Read `_config.yaml`** to load:
   - Environment URLs (use `default_environment` unless overridden)
   - Account credentials for the requested role
   - Timeouts, known acceptable errors, error signatures
2. **Determine execution mode** from the user's invocation:
   - `smoke` → filter to P0 tests only
   - `standard` → filter to P0 + P1
   - `full` → include all priorities
   - `module:XX` → load only the specified module file (e.g., `module:03-review-queue`)
3. **Initialize result accumulator**:
   ```yaml
   passed: []
   failed: []
   skipped: []
   global_console_errors: []
   global_network_errors: []
   ```

### Phase 2: Authentication Bootstrap

1. Load `01-auth.yaml` and execute **AUTH-001** (OTP login flow).
2. If AUTH-001 **fails**, record the failure and **abort the entire run** — no other test can proceed without authentication.
3. If AUTH-001 **passes**, the browser session is now authenticated. All subsequent tests reuse this session.
4. **Role switching**: If a test requires a different `role` than the current session:
   - Execute logout (navigate to login page or click Logout)
   - Re-authenticate with the new role's account
   - After the role-specific tests complete, re-authenticate as the primary role (owner)
   - **Optimization**: Group tests by role to minimize re-authentication

### Phase 3: Module Execution

Process modules in the order specified by `execution_order` in `_config.yaml`.

For each module YAML file:

1. **Load and parse** the YAML file
2. **Filter** tests by the active execution mode's priority filter
3. **Sort** tests by their order in the file (tests are already dependency-ordered)
4. For each test:

   **a. Pre-flight checks:**
   - If `depends_on` lists any test ID that failed or was skipped → mark this test as `skipped` with reason "Dependency {ID} did not pass"
   - If `prerequisites` list conditions that cannot be met → mark as `skipped`
   - If `role` differs from current session → re-authenticate (see Phase 2 step 4)
   - If `viewport` differs from current → call `browser_resize` to adjust

   **b. Execute steps sequentially:**
   For each step in the test's `steps` array:

   | Step `action` | MCP Tool to Call | Notes |
   |---|---|---|
   | `browser_navigate` | `browser_navigate` | Resolve `${workbench_url}` from config |
   | `browser_snapshot` | `browser_snapshot` | Evaluate `assert` conditions against accessibility tree |
   | `browser_click` | `browser_click` | Use `ref` from snapshot or text content |
   | `browser_fill_form` | `browser_fill_form` | Use field label or placeholder |
   | `browser_wait_for` | `browser_wait_for` | Wait for text/element with timeout |
   | `browser_console_messages` | `browser_console_messages` | Check for errors or extract values |
   | `browser_network_requests` | `browser_network_requests` | Check for 4xx/5xx responses |
   | `browser_select_option` | `browser_select_option` | For dropdown/combobox selections |
   | `browser_press_key` | `browser_press_key` | For keyboard interactions |
   | `browser_resize` | `browser_resize` | For viewport changes (responsive tests) |
   | `browser_take_screenshot` | `browser_take_screenshot` | Capture visual evidence |
   | `evidence_capture` | (composite) | Run both `browser_console_messages` + `browser_network_requests` |

   **c. Variable interpolation:**
   - `${workbench_url}` → resolved from `_config.yaml` environment
   - `${chat_url}` → resolved from `_config.yaml` environment
   - `${api_url}` → resolved from `_config.yaml` environment
   - `${account.email}` → resolved from `_config.yaml` accounts for current role
   - `${otp_code}` → extracted from `browser_console_messages` via `extract` directive
   - Any `extract` directive stores a named variable for use in subsequent steps

   **d. Assertion evaluation:**

   | Assertion Type | How to Evaluate |
   |---|---|
   | `element_visible: "..."` | Check accessibility tree from `browser_snapshot` contains the described element |
   | `element_not_visible: "..."` | Confirm element is NOT in the accessibility tree |
   | `text_content: "..."` | Verify text appears in the snapshot output |
   | `url_contains: "..."` | Check current page URL contains the substring |
   | `url_not_contains: "..."` | Confirm URL does not contain the substring |
   | `no_literal_i18n_keys: true` | Scan snapshot for dot-notation strings matching `[a-z]+\.[a-z]+(\.[a-z]+)+` |
   | `no_unexpected_console_errors: true` | Filter console errors against `known_acceptable_console` from config |
   | `no_unexpected_network_failures: true` | Filter network 4xx/5xx against `known_acceptable_network` from config |
   | `element_count_gte: { selector, count }` | Verify at least N matching elements |
   | `element_count_eq: { selector, count }` | Verify exactly N matching elements |

   **e. On step failure:**
   - Record: test ID, step index, step description, expected vs actual
   - Take a screenshot via `browser_take_screenshot`
   - **Do NOT abort the module** — continue to the next test
   - Mark the test as `failed`

   **f. Evidence capture (mandatory final step):**
   Every test MUST end with evidence capture, even if the test already failed:
   - Call `browser_console_messages` → check against error signatures
   - Call `browser_network_requests` → check for unexpected 4xx/5xx
   - Record any unexpected findings in the test result

### Phase 4: Result Reporting

After all modules complete, generate two output files:

#### 4a. Structured Result (YAML)

Write to `regression-suite/results/{YYYY-MM-DD-HH-MM}.yaml`:

```yaml
run:
  id: "{YYYY-MM-DD-HH-MM}"
  mode: "{smoke|standard|full|module:XX}"
  environment: "{dev|prod}"
  account: "{email used}"
  started: "{ISO timestamp}"
  completed: "{ISO timestamp}"
  duration_seconds: {N}

summary:
  total: {N}
  passed: {N}
  failed: {N}
  skipped: {N}
  pass_rate: "{N}%"
  by_priority:
    P0: { total: N, passed: N, failed: N, skipped: N }
    P1: { total: N, passed: N, failed: N, skipped: N }
    P2: { total: N, passed: N, failed: N, skipped: N }
    P3: { total: N, passed: N, failed: N, skipped: N }
  by_module:
    auth: { total: N, passed: N, failed: N, skipped: N }
    navigation: { total: N, passed: N, failed: N, skipped: N }
    # ... one entry per module executed

failures:
  - id: "{test ID}"
    title: "{test title}"
    module: "{module name}"
    priority: "{P0-P3}"
    step: {step index}
    step_description: "{what the step does}"
    expected: "{assertion description}"
    actual: "{what was observed}"
    console_errors: ["{any relevant errors}"]
    network_errors: ["{any relevant errors}"]
    screenshot: "results/{test-ID}-failure.png"

skipped:
  - id: "{test ID}"
    reason: "{why it was skipped}"

known_issues_encountered:
  - id: "{KI-NNN from config}"
    description: "{from config}"
    tests_affected: ["{test IDs}"]

global_health:
  console_errors_total: {N}
  console_errors_unexpected: {N}
  network_errors_total: {N}
  network_errors_unexpected: {N}
  i18n_literal_keys_found: ["{any literal keys}"]
```

#### 4b. Human-Readable Summary (Markdown)

Write to `regression-suite/results/{YYYY-MM-DD-HH-MM}.md`:

```markdown
# MHG Workbench Regression Report

**Date**: {date} | **Mode**: {mode} | **Environment**: {env}
**Duration**: {N} minutes | **Pass Rate**: {N}% ({passed}/{total})

## Results by Priority
| Priority | Total | Passed | Failed | Skipped |
|----------|-------|--------|--------|---------|
| P0       | ...   | ...    | ...    | ...     |
| P1       | ...   | ...    | ...    | ...     |
| P2       | ...   | ...    | ...    | ...     |
| P3       | ...   | ...    | ...    | ...     |

## Results by Module
| Module | Total | Passed | Failed | Skipped |
|--------|-------|--------|--------|---------|
| ...    | ...   | ...    | ...    | ...     |

## Failures
### {test ID}: {title} [{priority}]
- **Module**: {module}
- **Step {N}**: {step description}
- **Expected**: {assertion}
- **Actual**: {observation}
- **Screenshot**: [link]

## Known Issues Encountered
- KI-001: gradeDescription.buttonAriaLabel literal key in review session
- KI-002: Security section labels English-only in UK/RU locale

## i18n Issues
- {any literal keys found}

## Recommendations
1. {actionable fix suggestions based on failures}
```

---

## Assertion Helpers

### Checking for Literal i18n Keys

Scan the `browser_snapshot` accessibility tree output for any text matching:
```regex
[a-z]+\.[a-z]+(\.[a-z]+)+
```
Exclude known false positives:
- URLs (containing `://`)
- Email addresses (containing `@`)
- File paths (containing `/` or `\`)
- Version numbers (e.g., `v1.2.3`)
- Known acceptable keys from `known_issues` in config

### Filtering Console Errors

When `browser_console_messages` returns messages:
1. Filter to messages with level `error` or `warning`
2. For each error, check against `known_acceptable_console` patterns in config
3. If the error matches a known pattern → ignore
4. If the error does NOT match any known pattern → flag as unexpected

### Filtering Network Failures

When `browser_network_requests` returns requests:
1. Filter to requests with status >= 400
2. Exclude OPTIONS (preflight) requests
3. For each failure, check against `known_acceptable_network` in config
4. If the failure matches a known pattern → ignore
5. If it does NOT match → flag as unexpected

---

## Tips for the Executing Agent

1. **Use `browser_snapshot` liberally** — it's the primary way to verify UI state. The accessibility tree is more reliable than screenshots for assertion checking.

2. **Locator strategy** — When clicking elements, prefer:
   - `ref` values from the most recent `browser_snapshot`
   - Button/link text content
   - ARIA roles + names
   - Avoid CSS selectors (fragile to styling changes)

3. **Wait before asserting** — After navigation or form submission, use `browser_wait_for` before `browser_snapshot` to allow the page to settle.

4. **Don't clean up test data** — These are read-mostly tests. Avoid creating/deleting real data unless the test explicitly requires it (e.g., SS-004 save draft). When a test does create data, note it for manual cleanup.

5. **Screenshot on failure** — Always capture `browser_take_screenshot` when a test fails. Include the screenshot path in the failure record.

6. **Track cumulative state** — Some tests build on prior state (e.g., RS-005 depends on RS-003/RS-004 having rated messages). The `depends_on` field makes this explicit.

7. **Language reset** — After i18n tests (module 14), switch back to English before continuing to other modules. English is the baseline for all non-i18n assertions.

8. **Viewport reset** — After responsive tests (module 15), resize back to `default_viewport` from config before running cross-cutting checks.

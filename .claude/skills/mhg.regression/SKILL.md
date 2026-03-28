---
name: mhg.regression
description: >
  This skill should be used when the user asks to "run the regression suite", "run regression tests",
  "run smoke tests", "run the workbench regression", "execute regression", "test the workbench",
  "run P0 tests", "run full regression", "check for regressions", or "regression check".
  Executes the MHG Workbench regression test suite via Playwright MCP tools against the dev environment.
version: 1.0.0
---

# mhg.regression — Workbench Regression Test Suite Runner

Execute the comprehensive regression test suite for the MHG Workbench application.
The suite is defined in YAML files under `regression-suite/` and executed via Playwright MCP tools.

## Arguments

The skill accepts a single argument: the **execution mode**.

| Mode | Argument | Tests | Est. Duration |
|------|----------|-------|---------------|
| Smoke | `smoke` (default) | P0 only | ~10 min |
| Standard | `standard` | P0 + P1 | ~30 min |
| Full | `full` | All priorities | ~60 min |
| Module | `module:<name>` | Single module | varies |

Examples:
- `/mhg.regression` → runs smoke (default)
- `/mhg.regression smoke` → runs smoke
- `/mhg.regression standard` → runs P0 + P1
- `/mhg.regression full` → runs all 124 tests
- `/mhg.regression module:03-review-queue` → runs only review queue tests

---

## Section 1: Parse Arguments

1. Extract the execution mode from the skill arguments:
   - If no argument or `smoke` → mode = `smoke`, priority filter = `[P0]`
   - If `standard` → mode = `standard`, priority filter = `[P0, P1]`
   - If `full` → mode = `full`, priority filter = `[P0, P1, P2, P3]`
   - If `module:<name>` → mode = `module`, target module = `<name>`, no priority filter (run all tests in that module)
   - If unrecognized → print error: `"Unknown mode '<arg>'. Use: smoke, standard, full, or module:<name>"` and stop
2. Record the mode for use in result reporting.

---

## Section 2: Load Configuration

1. **Read** `regression-suite/_config.yaml` using the Read tool.
2. Extract from the YAML content:
   - `environments.dev` → `workbench_url`, `chat_url`, `api_url`
   - `accounts.owner` → `email`, `otp_pattern`
   - `timeouts` → `page_load`, `api_response`, `otp_extraction`
   - `known_acceptable_console` → list of `{ pattern, reason }` to suppress
   - `known_acceptable_network` → list of `{ endpoint, status, reason }` to suppress
   - `execution_order` → module sequence
   - `error_signatures` → patterns to hunt
3. Store these values as variables for use in subsequent sections.

---

## Section 3: Load and Filter Modules

1. **Determine which module files to load**:
   - If mode = `module:<name>` → load only `regression-suite/<name>.yaml`
   - Otherwise → load all module files listed in `execution_order` from config
2. For each module file, **Read** it using the Read tool.
3. Parse the YAML content to extract the `tests` array.
4. **Filter by priority**:
   - For each test, check if `test.priority` is in the priority filter for the current mode
   - Remove tests that don't match the filter
5. Track the total count of tests to execute.
6. Print: `"Mode: {mode} | Tests: {count} | Modules: {module_count}"`

---

## Section 4: AUTH-001 Gate

**AUTH-001 is the gate test. If it fails, abort the entire run.**

Execute these steps using Playwright MCP tools:

1. `browser_navigate` → `{workbench_url}`
2. `browser_wait_for` → wait for page to load (text "Sign In" or "Email")
3. `browser_snapshot` → verify login page rendered (look for sign-in button or email field)
4. `browser_click` → click "Sign In to Start" button (if present)
5. `browser_snapshot` → verify email field visible
6. `browser_fill_form` → fill the email field with `{account.owner.email}`
7. `browser_click` → click "Send Code" button
8. `browser_wait_for` → wait for OTP input to appear
9. `browser_console_messages` → scan output for OTP code matching pattern `Code:\s+(\d{6})`
   - Extract the 6-digit code. If not found, wait 2 seconds and try again (max 3 attempts)
   - If OTP not found after 3 attempts: **ABORT** — print `"GATE FAILURE: AUTH-001 — Could not extract OTP from console. Is the dev environment running?"` and stop
10. `browser_fill_form` → fill OTP field with extracted code
11. `browser_click` → click "Verify" button
12. `browser_wait_for` → wait for dashboard to load (text "Dashboard" or navigation sidebar)
13. `browser_snapshot` → verify authenticated state (sidebar visible, user info present)

**If any step fails**: Record the failure, take a `browser_take_screenshot`, print the diagnostic, and **ABORT the entire run**. Do not continue to other tests.

**If AUTH-001 passes**: Print `"GATE PASSED: AUTH-001 — Authenticated as {email}"` and continue.

---

## Section 5: Test Execution Loop

For each module in execution order, for each test (filtered by priority):

### 5a. Pre-flight Checks

1. **Dependency check**: If `test.depends_on` lists any test ID that is in the `failed` or `skipped` results → mark this test as `skipped` with reason `"Dependency {id} did not pass"` → continue to next test
2. **Role check**: If `test.role` differs from current authenticated role:
   - Navigate to workbench login page or click Logout
   - Re-authenticate with the new role's account (same OTP flow as AUTH-001 but with different email from `accounts.{role}`)
   - After the role-specific tests complete, re-authenticate as owner
3. **Viewport check**: If `test.viewport` is not `"default"` and differs from current viewport → call `browser_resize` with the specified `{ width, height }`

### 5b. Execute Steps

For each step in `test.steps`:

1. **Resolve variables**: Replace `${workbench_url}`, `${chat_url}`, `${api_url}`, `${account.email}`, `${otp_code}` with values from config and previously extracted variables
2. **Call the MCP tool** matching `step.action`:
   - `browser_navigate` → call with `url` from params
   - `browser_snapshot` → call and capture the accessibility tree output
   - `browser_click` → call with `ref` from params (element reference from most recent snapshot)
   - `browser_fill_form` → call with `field` and `value` from params
   - `browser_wait_for` → call with `text` and `timeout` from params
   - `browser_console_messages` → call and capture output
   - `browser_network_requests` → call and capture output
   - `browser_select_option` → call with selector and value from params
   - `browser_resize` → call with width and height from params
   - `browser_press_key` → call with key from params
   - `browser_take_screenshot` → call to capture visual state
   - `evidence_capture` → call both `browser_console_messages` AND `browser_network_requests`
3. **Handle `extract` directives**: If the step has an `extract` field, apply the regex pattern to the tool output and store the named variable for use in subsequent steps

### 5c. Evaluate Assertions

After each step that has an `assert` field, evaluate each assertion:

| Assertion | How to evaluate |
|-----------|----------------|
| `element_visible: "..."` | Check the `browser_snapshot` accessibility tree contains an element matching the description |
| `element_not_visible: "..."` | Confirm the element is NOT in the accessibility tree |
| `text_content: "..."` | Verify the text appears somewhere in the snapshot output |
| `url_contains: "..."` | Check the current page URL contains the substring |
| `no_literal_i18n_keys: true` | Scan the snapshot for patterns matching `[a-z]+\.[a-z]+(\.[a-z]+)+` in visible text. Exclude URLs (containing `://`), emails (containing `@`), file paths. Known issue: `gradeDescription.buttonAriaLabel` is expected (ignore it) |
| `no_unexpected_console_errors: true` | Get `browser_console_messages`, filter against `known_acceptable_console` patterns from config. If any unmatched errors remain → assertion fails |
| `no_unexpected_network_failures: true` | Get `browser_network_requests`, find any with status >= 400, filter against `known_acceptable_network` from config. If any unmatched failures remain → assertion fails |

**On assertion failure**:
- Call `browser_take_screenshot` to capture the visual state
- Record: `{ test_id, step_index, assertion_type, expected, actual }`
- Mark the test as `failed`
- **Do NOT abort the module** — continue to the next test

### 5d. Evidence Capture (mandatory)

After the last step of every test (whether it passed or failed):
1. Call `browser_console_messages` — check for error-level messages against `known_acceptable_console`
2. Call `browser_network_requests` — check for status >= 400 against `known_acceptable_network`
3. Record any unexpected findings in the test result

---

## Section 6: Write Results

After all tests complete, generate two output files.

### 6a. Generate timestamp

Use the current date/time formatted as `YYYY-MM-DD-HH-MM` for the result file names.

### 6b. Write YAML result

Write to `regression-suite/results/{timestamp}.yaml`:

```yaml
run:
  id: "{timestamp}"
  mode: "{mode}"
  environment: dev
  account: "{email}"
  started: "{ISO start time}"
  completed: "{ISO end time}"
  duration_seconds: {calculated}

summary:
  total: {total tests executed}
  passed: {count}
  failed: {count}
  skipped: {count}
  pass_rate: "{percentage}%"
  by_priority:
    P0: { total: N, passed: N, failed: N, skipped: N }
    P1: { total: N, passed: N, failed: N, skipped: N }
    P2: { total: N, passed: N, failed: N, skipped: N }
    P3: { total: N, passed: N, failed: N, skipped: N }
  by_module:
    # one entry per module executed
    auth: { total: N, passed: N, failed: N, skipped: N }

failures:
  # one entry per failed test
  - id: "{test ID}"
    title: "{test title}"
    module: "{module name}"
    priority: "{P0-P3}"
    step: {step index where failure occurred}
    step_description: "{what the step does}"
    expected: "{assertion that failed}"
    actual: "{what was observed}"

skipped:
  - id: "{test ID}"
    reason: "{why skipped}"

global_health:
  console_errors_unexpected: {count of unfiltered errors}
  network_errors_unexpected: {count of unfiltered failures}
  i18n_literal_keys_found: ["{any literal keys detected}"]
```

### 6c. Write Markdown summary

Write to `regression-suite/results/{timestamp}.md`:

```markdown
# MHG Workbench Regression Report

**Date**: {date} | **Mode**: {mode} | **Environment**: Dev
**Duration**: {minutes} minutes | **Pass Rate**: {rate}% ({passed}/{total})
**Verdict**: {PASS or FAIL}

## Results by Priority
| Priority | Total | Passed | Failed | Skipped |
|----------|-------|--------|--------|---------|
| P0       | ...   | ...    | ...    | ...     |
| P1       | ...   | ...    | ...    | ...     |

## Results by Module
| Module | Total | Passed | Failed | Skipped |
|--------|-------|--------|--------|---------|
| ...    | ...   | ...    | ...    | ...     |

## Failures
### {test ID}: {title} [{priority}]
- **Step {N}**: {step description}
- **Expected**: {assertion}
- **Actual**: {observation}

## Recommendations
{actionable suggestions based on failures}
```

---

## Section 7: Apply Pass/Fail Thresholds

After writing results, determine the overall **verdict**:

| Mode | Pass condition | Fail condition |
|------|---------------|----------------|
| `smoke` | 100% P0 pass | Any P0 failure |
| `standard` | 100% P0 AND P1 pass rate >= 90% | Any P0 failure OR P1 < 90% |
| `full` | 100% P0 AND P1 pass rate >= 90% | Any P0 failure OR P1 < 90% |
| `module:XX` | All filtered tests pass | Any test failure |

P2 and P3 failures are **informational** — they do not affect the verdict.

Print the final summary:

```
═══════════════════════════════════════════════
  REGRESSION SUITE: {PASS ✓ or FAIL ✗}
  Mode: {mode} | Tests: {passed}/{total} | Duration: {N}m
  Results: regression-suite/results/{timestamp}.md
═══════════════════════════════════════════════
```

If the verdict is **FAIL**, additionally print the failing test IDs and their step descriptions.

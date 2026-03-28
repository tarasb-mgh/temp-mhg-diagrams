# Data Model: Workbench Regression Test Suite

**Feature**: 037-workbench-regression-suite
**Date**: 2026-03-27

## Entities

### Test Case

A single regression test with structured execution steps.

| Field | Type | Description |
|-------|------|-------------|
| id | string | Unique identifier across all modules (e.g., `AUTH-001`, `RQ-003`) |
| title | string | Human-readable test name |
| priority | enum | `P0` (smoke), `P1` (standard), `P2` (full), `P3` (optional) |
| tags | string[] | Ad-hoc labels for filtering (e.g., `[auth, otp, login]`) |
| role | string | Account role to use (references `_config.yaml.accounts`) |
| viewport | object or string | `{ width, height }` or `"default"` (uses config default) |
| prerequisites | string[] | Human-readable conditions (informational) |
| depends_on | string[] | Test IDs that must pass before this test runs |
| steps | Step[] | Ordered list of execution steps |
| pass_criteria | string[] | Human-readable success conditions |
| error_signatures | ErrorSignature[] | Patterns to watch for in this test's context |

### Step

A single action within a test case.

| Field | Type | Description |
|-------|------|-------------|
| action | enum | MCP tool or composite action (see Action Types below) |
| params | object | Tool-specific parameters (url, ref, field, value, timeout, etc.) |
| expect | string | Human-readable description of expected outcome (informational) |
| assert | Assertion[] | Machine-evaluatable assertions against step output |
| extract | object | Named variable extraction from step output (key → regex pattern) |

### Action Types

| Action | Description | MCP Tool |
|--------|-------------|----------|
| `browser_navigate` | Navigate to URL | `playwright__browser_navigate` |
| `browser_snapshot` | Capture accessibility tree | `playwright__browser_snapshot` |
| `browser_click` | Click element by ref or text | `playwright__browser_click` |
| `browser_fill_form` | Fill input field | `playwright__browser_fill_form` |
| `browser_wait_for` | Wait for text/element | `playwright__browser_wait_for` |
| `browser_console_messages` | Read console output | `playwright__browser_console_messages` |
| `browser_network_requests` | Read network log | `playwright__browser_network_requests` |
| `browser_select_option` | Select dropdown value | `playwright__browser_select_option` |
| `browser_resize` | Change viewport | `playwright__browser_resize` |
| `browser_press_key` | Press keyboard key | `playwright__browser_press_key` |
| `browser_take_screenshot` | Capture screenshot | `playwright__browser_take_screenshot` |
| `evidence_capture` | Composite: console + network check | (agent executes both tools) |

### Assertion

| Field | Type | Description |
|-------|------|-------------|
| element_visible | string | Element description that must appear in snapshot |
| element_not_visible | string | Element description that must NOT appear |
| text_content | string | Text that must appear in snapshot |
| url_contains | string | Substring required in current URL |
| url_not_contains | string | Substring that must NOT be in URL |
| no_literal_i18n_keys | boolean | If true, scan for dot-notation literal keys |
| no_unexpected_console_errors | boolean | If true, filter console against known acceptable |
| no_unexpected_network_failures | boolean | If true, filter network against known acceptable |
| element_count_gte | object | `{ selector, count }` — at least N elements |
| element_count_eq | object | `{ selector, count }` — exactly N elements |

### ErrorSignature

| Field | Type | Description |
|-------|------|-------------|
| pattern | string | Regex or substring to match in console/network output |
| severity | enum | `critical`, `high`, `medium`, `low` |
| meaning | string | Human-readable explanation of what the error indicates |

### Module

A YAML file grouping related test cases.

| Field | Type | Description |
|-------|------|-------------|
| module.id | string | Module identifier (e.g., `01-auth`) |
| module.title | string | Human-readable module name |
| module.description | string | What this module covers |
| module.gate | boolean | If true, first test failure aborts the entire run |
| tests | TestCase[] | Ordered list of test cases |

### Configuration (`_config.yaml`)

| Section | Description |
|---------|-------------|
| environments | URL maps for dev and prod (chat_url, workbench_url, api_url) |
| accounts | Role-keyed account definitions (email, otp_source, otp_pattern) |
| default_environment | Which environment to target (default: dev) |
| default_viewport | Default browser size `{ width, height }` |
| locales | Supported locales with selector labels |
| timeouts | Named timeout values in milliseconds |
| execution_modes | Mode definitions with priority filters |
| execution_order | Module execution sequence |
| known_acceptable_console | Console error patterns to suppress |
| known_acceptable_network | Network error patterns to suppress |
| known_issues | Documented known failures with affected test IDs |
| error_signatures | Global error patterns to hunt (console, network, ui) |

### Run Result

| Field | Type | Description |
|-------|------|-------------|
| run.id | string | Timestamp identifier |
| run.mode | string | Execution mode used |
| run.environment | string | Target environment |
| run.started | ISO datetime | Run start time |
| run.completed | ISO datetime | Run end time |
| run.duration_seconds | number | Total duration |
| summary.total | number | Total tests executed |
| summary.passed | number | Tests that passed |
| summary.failed | number | Tests that failed |
| summary.skipped | number | Tests skipped (dependencies, prerequisites) |
| summary.pass_rate | string | Percentage passed |
| summary.by_priority | object | Breakdown per priority level |
| summary.by_module | object | Breakdown per module |
| failures[] | object | Failed test details (id, step, expected, actual, screenshot) |
| skipped[] | object | Skipped test details (id, reason) |
| global_health | object | Aggregate console/network error counts |

## Relationships

```
Configuration (1) ←── references ──→ (N) Module
Module (1) ←── contains ──→ (N) TestCase
TestCase (1) ←── contains ──→ (N) Step
Step (1) ←── contains ──→ (N) Assertion
TestCase (N) ←── depends_on ──→ (N) TestCase
Run Result (1) ←── produced by ──→ (1) Execution Run
Run Result (1) ←── references ──→ (N) TestCase (failures, skipped)
```

## State Transitions

### Test Case Status (during execution)

```
pending → executing → passed
                    → failed (assertion failure or step error)
                    → skipped (dependency failed or prerequisite unmet)
```

### Run Status

```
initializing → gate_check (AUTH-001)
gate_check → aborted (AUTH-001 failed)
gate_check → executing (AUTH-001 passed)
executing → complete
complete → verdict: PASS (thresholds met)
complete → verdict: FAIL (thresholds not met)
```

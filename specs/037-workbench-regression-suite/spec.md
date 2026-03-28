# Feature Specification: Workbench Regression Test Suite

**Feature Branch**: `037-workbench-regression-suite`
**Created**: 2026-03-27
**Status**: Draft
**Input**: User description: "Comprehensive AI-agent-executable regression test suite for the MHG Workbench application with runner skill, ship pipeline integration, CI automation, and maintenance workflow"

## Summary

Establish a complete regression testing capability for the MHG Workbench that can be triggered by a single command, integrated into the deployment pipeline, and run automatically in CI. The suite covers all 16 workbench feature modules (authentication, review system, surveys, user management, groups, privacy, security, settings, internationalization, and responsive layout) with 124 structured test cases executable by an AI agent using browser automation tools.

## User Scenarios & Testing

### User Story 1 - Run Regression After Deploy (Priority: P1)

An operator deploys new code to the dev environment and needs to verify that existing workbench functionality hasn't regressed. They invoke `/mhg.regression smoke` and receive a pass/fail report within 10 minutes covering the critical path (authentication, navigation, review queue, survey list, user list, groups list, i18n, and error monitoring).

**Why this priority**: This is the primary use case. Without a quick regression check after deploy, regressions go undetected until manual QA or user reports surface them days later.

**Independent Test**: Can be fully tested by invoking `/mhg.regression smoke` against the dev environment after any deploy and verifying the result report is generated with correct pass/fail verdicts.

**Acceptance Scenarios**:

1. **Given** the dev environment is deployed and accessible, **When** the operator invokes `/mhg.regression smoke`, **Then** all P0 tests execute against dev and a structured result report is written to `regression-suite/results/`
2. **Given** AUTH-001 (OTP login) fails, **When** the smoke run encounters this failure, **Then** the entire run aborts immediately with a diagnostic message explaining the failure cause
3. **Given** one P0 test fails, **When** the smoke run completes, **Then** the overall verdict is FAIL and the report lists the failing test with step details and screenshot

---

### User Story 2 - Ship Pipeline Regression (Priority: P1)

The deployment operator uses `/mhg.ship` to push changes through the full pipeline. Phase 4 (UI regression) now automatically invokes the regression suite instead of requiring manual walkthroughs of 5 flows. If P0 tests pass, Phase 4 passes. If any P0 test fails, Phase 4 enters its fix loop.

**Why this priority**: The ship pipeline is the primary deployment mechanism. Integrating the regression suite here ensures every deploy is verified automatically, replacing the fragile manual process.

**Independent Test**: Can be tested by running `/mhg.ship` through to Phase 4 and verifying it invokes the regression runner and correctly gates on P0 pass/fail.

**Acceptance Scenarios**:

1. **Given** the operator runs `/mhg.ship` and reaches Phase 4, **When** the regression suite executes, **Then** it runs smoke-level tests and reports results within the ship pipeline context
2. **Given** all P0 tests pass during Phase 4, **When** the suite completes, **Then** Phase 4 is marked as passed and the pipeline proceeds
3. **Given** a P0 test fails during Phase 4, **When** the suite completes, **Then** Phase 4 is marked as failed and the pipeline enters the fix-and-retry loop

---

### User Story 3 - Comprehensive Pre-Release Regression (Priority: P2)

Before cutting a release branch, the operator runs `/mhg.regression full` to execute all 124 tests including edge cases, responsive layout checks, and exploratory tests. The full report gives confidence that no subtle regressions exist beyond the critical path.

**Why this priority**: Full regression is valuable but time-intensive (~60 minutes). It's used less frequently than smoke (every deploy) but is critical before release promotion.

**Independent Test**: Can be tested by invoking `/mhg.regression full` and verifying all 124 tests execute with correct priority filtering and dependency ordering.

**Acceptance Scenarios**:

1. **Given** the dev environment is stable, **When** the operator invokes `/mhg.regression full`, **Then** all tests across all priorities execute in dependency order and a comprehensive report is generated
2. **Given** a P2 test fails, **When** the full run completes, **Then** the overall verdict is still PASS (P2 failures are informational) but the failure is documented in the report
3. **Given** the operator invokes `/mhg.regression standard`, **When** tests execute, **Then** only P0 and P1 tests run, and the pass threshold requires 100% P0 and at least 90% P1 pass rate

---

### User Story 4 - CI-Triggered Regression (Priority: P3)

After a deploy workflow completes in any app repository, a GitHub Actions workflow in `chat-ui` is triggered via `repository_dispatch`. The workflow runs the smoke regression tests headlessly using a Playwright-based translator that maps YAML test definitions to programmatic browser automation calls. Results are uploaded as workflow artifacts.

**Why this priority**: CI automation removes the human-in-the-loop requirement for post-deploy regression. It provides continuous quality assurance but requires the most engineering effort (YAML-to-Playwright translator).

**Independent Test**: Can be tested by triggering the workflow via `workflow_dispatch` with a mode input and verifying the results artifact is produced.

**Acceptance Scenarios**:

1. **Given** the CI workflow is configured, **When** triggered via `workflow_dispatch` with mode `smoke`, **Then** the workflow executes smoke tests and uploads results as artifacts
2. **Given** a YAML test step uses an unsupported action, **When** the translator encounters it, **Then** it logs a warning and skips the step without crashing the run
3. **Given** the deploy workflow completes for `workbench-frontend`, **When** it dispatches to `chat-ui`, **Then** the regression workflow triggers automatically

---

### User Story 5 - Add Tests for New Feature (Priority: P2)

A developer ships a new workbench feature (e.g., a review reports page) and needs to add regression coverage. They follow the conventions in `CONTRIBUTING.md` to add test cases to the appropriate module YAML file with correct IDs, priorities, and assertions.

**Why this priority**: Without a maintenance workflow, the test suite goes stale as features are added or changed. This story ensures the suite evolves with the product.

**Independent Test**: Can be tested by adding a new test to a module YAML, running that module via `/mhg.regression module:XX`, and verifying the new test executes.

**Acceptance Scenarios**:

1. **Given** a new feature has shipped, **When** the developer adds tests to the module YAML following CONTRIBUTING.md conventions, **Then** the new tests are picked up on the next regression run
2. **Given** a test ID already exists, **When** the suite validates YAML files, **Then** it reports the duplicate and the run does not proceed with ambiguous IDs

---

### Edge Cases

- What happens when the dev environment is down? AUTH-001 fails at the navigation step, the run aborts with a diagnostic pointing to the network failure.
- What happens when a test's dependency failed? The test is auto-skipped with reason "Dependency {ID} failed" and does not count as a failure.
- What happens when role-switch re-authentication fails? Remaining tests for that role are skipped; the run continues with the primary role.
- What happens when all tests pass but there are unexpected console errors? CC-004 (console monitoring) catches them and may fail, impacting the overall verdict.
- What happens when new i18n keys are added but not translated? I18N-005 detects literal dot-notation keys in the UI and flags them.
- What happens when a YAML file has a syntax error? The runner reports the parse error for that module and skips it, continuing with remaining modules.

## Requirements

### Functional Requirements

- **FR-001**: System MUST provide a `/mhg.regression` skill that accepts execution mode (smoke, standard, full, or module:XX) as an argument
- **FR-002**: System MUST read test configuration from `regression-suite/_config.yaml` including environment URLs, account credentials, timeouts, and known acceptable errors
- **FR-003**: System MUST load and parse YAML module files, filtering tests by priority based on the selected execution mode
- **FR-004**: System MUST execute AUTH-001 as a gate test; if it fails, the entire run MUST abort with a diagnostic report
- **FR-005**: System MUST execute test steps sequentially using Playwright MCP tools (browser_navigate, browser_snapshot, browser_click, browser_fill_form, browser_wait_for, browser_console_messages, browser_network_requests)
- **FR-006**: System MUST evaluate assertions after each step and record failures with step details and screenshots
- **FR-007**: System MUST auto-skip tests whose `depends_on` references include any failed or skipped test
- **FR-008**: System MUST capture browser console messages and network requests after every test (evidence capture)
- **FR-009**: System MUST filter console and network errors against known acceptable patterns from `_config.yaml` before flagging them
- **FR-010**: System MUST write structured results to `regression-suite/results/{timestamp}.yaml` and human-readable summary to `regression-suite/results/{timestamp}.md`
- **FR-011**: System MUST apply pass/fail thresholds: 100% P0 pass required; for standard/full modes, P1 pass rate must be at least 90%
- **FR-012**: The `/mhg.ship` skill Phase 4 MUST invoke the regression runner instead of manual regression flows
- **FR-013**: A GitHub Actions workflow MUST accept `workflow_dispatch` with mode input and `repository_dispatch` from app repo deploy workflows
- **FR-014**: The CI YAML-to-Playwright translator MUST map YAML step actions to Playwright API calls and skip unsupported actions with a warning
- **FR-015**: The `regression-suite/CONTRIBUTING.md` file MUST document conventions for adding, updating, and removing tests
- **FR-016**: The `regression-suite/CHANGELOG.md` file MUST exist for tracking test additions and removals per release cycle
- **FR-017**: All YAML test files MUST parse without errors and all test IDs MUST be unique across modules

### Key Entities

- **Test Case**: A structured YAML object with id, title, priority, role, steps, assertions, and error signatures. Belongs to exactly one module.
- **Module**: A YAML file containing related test cases (e.g., `03-review-queue.yaml`). Modules are executed in a defined order.
- **Configuration**: The `_config.yaml` file containing environment URLs, account credentials, timeouts, known errors, execution order, and error signatures.
- **Run Result**: A timestamped YAML + markdown output summarizing pass/fail counts, failure details, and global health metrics.
- **Execution Mode**: One of smoke (P0), standard (P0+P1), full (all), or module-scoped. Determines which tests are loaded and what thresholds apply.

## Success Criteria

### Measurable Outcomes

- **SC-001**: Smoke regression completes in under 15 minutes and correctly reports pass/fail for all P0 tests
- **SC-002**: Full regression covers 100% of workbench feature modules (16 modules) with at least one test per module
- **SC-003**: The runner correctly auto-skips dependent tests when a prerequisite fails, preventing false failures
- **SC-004**: Post-deploy regression time is reduced from ~30 minutes of manual walkthroughs to ~10 minutes of automated smoke
- **SC-005**: Every regression run produces machine-readable results (YAML) that can be compared across runs to identify trends
- **SC-006**: Ship pipeline Phase 4 requires zero manual intervention when P0 tests pass
- **SC-007**: New test cases can be added by editing a single YAML file following documented conventions, without modifying runner code
- **SC-008**: CI regression workflow triggers automatically after deploy and produces results within 20 minutes

## Assumptions

- The dev environment is accessible at the canonical URLs defined in CLAUDE.md
- The OTP login mechanism logs the verification code to the browser console in dev (standard dev behavior)
- The Playwright MCP tools are available in the AI agent's execution context
- The `chat-ui` repository has Playwright already configured with the required browser dependencies
- Test data (users, sessions, groups) exists in the dev database from the existing `global-setup.ts` seed or prior manual setup
- The existing 124 YAML test cases in `regression-suite/` are the baseline; test count will grow as features are added

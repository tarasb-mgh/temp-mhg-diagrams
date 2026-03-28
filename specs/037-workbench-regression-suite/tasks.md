# Tasks: Workbench Regression Test Suite

**Input**: Design documents from `specs/037-workbench-regression-suite/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1-US5)
- Exact file paths included in descriptions

---

## Phase 1: Runner Skill (US1 — Run Regression After Deploy) — MTB-997

**Purpose**: Create the `/mhg.regression` skill that executes YAML test definitions via Playwright MCP tools

- [X] T001 [US1] Create skill directory and SKILL.md frontmatter with name, version, description, and trigger patterns in `client-spec/.claude/skills/mhg.regression/SKILL.md`
- [X] T002 [US1] Write SKILL.md Section 1 — argument parsing: extract execution mode (smoke/standard/full/module:XX) from skill arguments, validate input, set default to `smoke`
- [X] T003 [US1] Write SKILL.md Section 2 — configuration loading: instruct agent to read `regression-suite/_config.yaml`, resolve environment URLs, account credentials, timeouts, known acceptable errors
- [X] T004 [US1] Write SKILL.md Section 3 — module loading and filtering: instruct agent to load YAML module files in execution_order, filter tests by priority based on mode (smoke=P0, standard=P0+P1, full=all, module=single file)
- [X] T005 [US1] Write SKILL.md Section 4 — AUTH-001 gate: instruct agent to execute AUTH-001 first via Playwright MCP tools (navigate, fill email, extract OTP from console, verify), abort entire run if gate fails
- [X] T006 [US1] Write SKILL.md Section 5 — test execution loop: for each test, check depends_on (skip if dependency failed), check role (re-auth if different), check viewport (resize if different), execute steps sequentially via MCP tools, evaluate assertions, capture evidence
- [X] T007 [US1] Write SKILL.md Section 6 — assertion evaluation: define how agent evaluates element_visible, element_not_visible, no_literal_i18n_keys, no_unexpected_console_errors, no_unexpected_network_failures against snapshot/console/network output
- [X] T008 [US1] Write SKILL.md Section 7 — result writing: instruct agent to write structured YAML results to `regression-suite/results/{timestamp}.yaml` and human-readable markdown to `regression-suite/results/{timestamp}.md`
- [X] T009 [US1] Write SKILL.md Section 8 — pass/fail thresholds: apply thresholds (smoke: 100% P0; standard/full: 100% P0 + >=90% P1; module: all pass), print summary with verdict

---

## Phase 2: Ship Pipeline Integration (US2 — Ship Pipeline Regression) — MTB-998

**Purpose**: Update `/mhg.ship` Phase 4 to use the new regression runner

- [X] T010 [US2] Update Phase 4 in `client-spec/.claude/skills/mhg.ship/SKILL.md` — replace inline 5-flow regression instructions with invocation of `/mhg.regression smoke`
- [X] T011 [US2] Update Phase 4 pass/fail logic — Phase 4 passes when runner reports 100% P0 pass; Phase 4 fails and enters fix loop when any P0 test fails
- [X] T012 [P] [US2] Add superseded notice to `client-spec/.claude/skills/mhg.ship/references/regression-targets.md` — header stating this file is superseded by `regression-suite/` and kept for reference only

---

## Phase 3: Maintenance Workflow (US5 — Add Tests for New Feature) — MTB-999

**Purpose**: Document conventions for keeping the test suite current as features evolve

- [X] T013 [P] [US5] Create `client-spec/regression-suite/CONTRIBUTING.md` — document when to add tests (after feature ships), how to add (module YAML, ID conventions, priority assignment, YAML schema), how to update (when behavior changes), how to remove (when feature deprecated)
- [X] T014 [P] [US5] Create `client-spec/regression-suite/CHANGELOG.md` — initial entry documenting the 124-test baseline across 16 modules created on 2026-03-27

---

## Phase 4: CI Automation (US4 — CI-Triggered Regression) — MTB-1000

**Purpose**: Build GitHub Actions workflow and YAML-to-Playwright translator for headless CI execution

- [ ] T015 [US4] Create `chat-ui/.github/workflows/regression-suite.yml` — workflow_dispatch with mode input (smoke/standard/full), repository_dispatch trigger from app repo deploys, checkout client-spec for YAML definitions, run translator
- [ ] T016 [US4] Create `chat-ui/tests/regression/yaml-translator.ts` — TypeScript module that reads YAML test definitions and maps step actions to Playwright API calls per research.md mapping table (browser_navigate→page.goto, browser_snapshot→page.accessibility.snapshot, etc.)
- [ ] T017 [US4] Create `chat-ui/tests/regression/runner.ts` — TypeScript entry point that loads _config.yaml, filters modules by mode, executes tests via translator, handles AUTH-001 gate, dependency chains, role switching, writes results as YAML+MD artifacts
- [ ] T018 [US4] Integrate auth with existing chat-ui fixtures — reuse `ensureOtpStorageState()` from `chat-ui/tests/e2e/fixtures/authTest.ts` for OTP authentication in CI context

---

## Phase 5: Verification — MTB-1001

**Purpose**: Validate the complete implementation end-to-end

- [ ] T019 [US1] Run `/mhg.regression smoke` against dev environment — verify AUTH-001 passes, P0 tests execute, results written to `regression-suite/results/`, summary printed with pass/fail verdict
- [ ] T020 [P] [US1] Run `/mhg.regression module:01-auth` — verify single-module execution filters correctly and only auth tests run
- [ ] T021 [US3] Run `/mhg.regression standard` — verify P0+P1 filtering, pass/fail threshold (100% P0 + >=90% P1), results written correctly
- [X] T022 [P] Validate all YAML test files parse without errors and all 124 test IDs are unique across modules (run validation script)

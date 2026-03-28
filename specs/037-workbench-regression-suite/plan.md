# Implementation Plan: Workbench Regression Test Suite

**Branch**: `037-workbench-regression-suite` | **Date**: 2026-03-27 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/037-workbench-regression-suite/spec.md`

## Summary

Build the execution and integration layer for the existing 124-test YAML regression suite: a `/mhg.regression` runner skill that executes tests via Playwright MCP tools, integration into `/mhg.ship` Phase 4, a CI GitHub Actions workflow with YAML-to-Playwright translator, and maintenance documentation (CONTRIBUTING.md, CHANGELOG.md).

## Technical Context

**Language/Version**: YAML (test definitions), Markdown (skill prompts), TypeScript (CI translator), Bash (validation scripts)
**Primary Dependencies**: Playwright MCP (`plugin-playwright-playwright`), Claude Code skill system, GitHub Actions, `chat-ui` Playwright infrastructure
**Storage**: File-based (YAML test definitions, YAML+MD results in `regression-suite/results/`)
**Testing**: Self-validating — the suite tests itself by executing against the dev environment; YAML syntax validated via Python `yaml.safe_load`
**Target Platform**: Claude Code AI agent (skills), GitHub Actions CI (headless Chromium)
**Project Type**: Skill + CI workflow (meta-tooling, not application code)
**Performance Goals**: Smoke run completes in under 15 minutes; full run in under 90 minutes
**Constraints**: Must work with existing Playwright MCP tool interface; must not require new npm packages in `client-spec`
**Scale/Scope**: 124 test cases across 16 modules; 4 execution modes; 7 user roles; 3 locales

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Applicable? | Status | Notes |
|-----------|-------------|--------|-------|
| I. Spec-First | Yes | PASS | Spec created via `/speckit.specify`, plan follows |
| II. Multi-Repo Orchestration | Yes | PASS | Changes span `client-spec` (skill, YAML), `chat-ui` (CI workflow), and `.claude/skills/mhg.ship/` (Phase 4 update) |
| III. Test-Aligned | Yes | PASS | Suite uses Playwright (existing in `chat-ui`); CI translator uses existing Playwright infrastructure |
| IV. Branch Discipline | Yes | PASS | Feature branch `037-workbench-regression-suite` created from current state |
| V. Privacy/Security | Partial | PASS | Suite tests PII masking; no new PII handling introduced. Test accounts use dev-only email addresses |
| VI. Accessibility/i18n | Yes | PASS | Suite includes i18n verification tests (module 14) for all 3 locales |
| VII. Split-Repo First | Yes | PASS | All changes in split repos (client-spec, chat-ui) |
| VIII. GCP CLI | No | N/A | No infrastructure changes |
| IX. Responsive/PWA | Yes | PASS | Suite includes responsive layout tests (module 15) and PWA test (CC-001) |
| X. Jira Traceability | Yes | PASS | Epic MTB-996 created |
| XI. Documentation | Partial | DEFERRED | CONTRIBUTING.md serves as internal documentation; Confluence updates deferred until production release |
| XII. Release Engineering | No | N/A | This is tooling, not a user-facing release |

No constitution violations. No complexity tracking needed.

## Project Structure

### Documentation (this feature)

```text
specs/037-workbench-regression-suite/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
└── checklists/
    └── requirements.md  # Spec quality checklist
```

### Source Code (repository root)

```text
client-spec/
├── regression-suite/                    # EXISTING — test definitions
│   ├── _config.yaml                     # Environment config
│   ├── _runner-guide.md                 # Execution protocol docs
│   ├── 01-auth.yaml ... 16-cross-cutting.yaml  # 16 module files
│   ├── results/                         # Run output directory
│   ├── CONTRIBUTING.md                  # NEW — maintenance conventions
│   └── CHANGELOG.md                     # NEW — test change log
├── .claude/skills/mhg.regression/       # NEW — runner skill
│   └── SKILL.md                         # Skill definition
└── .claude/skills/mhg.ship/            # EXISTING — ship pipeline
    └── SKILL.md                         # MODIFIED — Phase 4 update
    └── references/
        └── regression-targets.md        # MODIFIED — superseded notice

chat-ui/
└── .github/workflows/
    └── regression-suite.yml             # NEW — CI workflow
└── tests/regression/
    └── yaml-translator.ts               # NEW — YAML-to-Playwright translator
    └── runner.ts                        # NEW — CI regression runner
```

**Structure Decision**: The skill lives in `client-spec/.claude/skills/` (standard skill location). The CI translator lives in `chat-ui` alongside existing Playwright infrastructure. Test definitions remain in `client-spec/regression-suite/`.

## Implementation Phases

### Phase 1: Runner Skill (US1 — P1)

Create `.claude/skills/mhg.regression/SKILL.md` that:
1. Parses execution mode from arguments (smoke/standard/full/module:XX)
2. Reads `regression-suite/_config.yaml`
3. Loads and filters module YAML files by priority
4. Executes AUTH-001 as gate (abort on fail)
5. Iterates tests: step execution via Playwright MCP tools, assertion evaluation, evidence capture
6. Handles dependency chains (auto-skip on upstream failure)
7. Handles role switching (logout + re-auth when role changes)
8. Writes structured results to `regression-suite/results/{timestamp}.yaml` + `.md`
9. Applies pass/fail thresholds and prints summary

**Files**:
- `client-spec/.claude/skills/mhg.regression/SKILL.md`

### Phase 2: Ship Pipeline Integration (US2 — P1)

Update `/mhg.ship` Phase 4 to invoke the runner skill:
1. Replace inline 5-flow regression instructions with `/mhg.regression smoke` invocation
2. Update `references/regression-targets.md` with superseded notice pointing to `regression-suite/`
3. Phase 4 pass = 100% P0 pass from runner output; fail = any P0 failure triggers fix loop

**Files**:
- `client-spec/.claude/skills/mhg.ship/SKILL.md` (Phase 4 section)
- `client-spec/.claude/skills/mhg.ship/references/regression-targets.md` (superseded header)

### Phase 3: Maintenance Workflow (US5 — P2)

Create documentation for test lifecycle:
1. `regression-suite/CONTRIBUTING.md` — when/how to add, update, remove tests; ID conventions, priority assignment, YAML schema reference
2. `regression-suite/CHANGELOG.md` — initial entry documenting the 124-test baseline

**Files**:
- `client-spec/regression-suite/CONTRIBUTING.md`
- `client-spec/regression-suite/CHANGELOG.md`

### Phase 4: CI Automation (US4 — P3)

Build the CI workflow and YAML-to-Playwright translator:
1. `chat-ui/.github/workflows/regression-suite.yml` — workflow_dispatch + repository_dispatch triggers
2. `chat-ui/tests/regression/yaml-translator.ts` — maps YAML step actions to Playwright API calls
3. `chat-ui/tests/regression/runner.ts` — loads config, filters, executes, reports

**Files**:
- `chat-ui/.github/workflows/regression-suite.yml`
- `chat-ui/tests/regression/yaml-translator.ts`
- `chat-ui/tests/regression/runner.ts`

### Cross-Repository Dependencies

| Order | Repository | Changes | Depends on |
|-------|-----------|---------|------------|
| 1 | client-spec | Runner skill, ship integration, maintenance docs | None |
| 2 | chat-ui | CI workflow, YAML translator | client-spec regression-suite/ must exist |

# Implementation Plan: Workbench UX Wayfinding and Information Architecture Overhaul

**Branch**: `029-workbench-ux-wayfinding` | **Date**: 2026-03-12 | **Spec**: [spec.md](spec.md)  
**Input**: Feature specification from `specs/029-workbench-ux-wayfinding/spec.md`

## Summary

Establish a role-based UX baseline for Workbench, remove authentication blockers that prevent reliable audits, and deliver an implementation-ready IA and wayfinding package focused on intuitive navigation without manuals. The output of this feature is a validated remediation backlog and acceptance checklist for follow-up changes in target repositories (`workbench-frontend`, optionally `chat-backend` and `chat-frontend-common` for API or shared UX behavior support).

## Technical Context

**Language/Version**: Markdown documentation in this repository; TypeScript 5.x expected in downstream implementation repos  
**Primary Dependencies**: Playwright-based browser validation, MHG dev environments, role-based test accounts  
**Storage**: N/A (specification artifacts only in this repo)  
**Testing**: Task-based UX validation via Playwright evidence + role checklist execution  
**Target Platform**: `https://workbench.dev.mentalhelp.chat` with API at `https://api.dev.mentalhelp.chat`  
**Project Type**: Specification and orchestration (no application code changes in this repo)  
**Performance Goals**: UX quality goals from spec success criteria (discoverability and wayfinding outcomes)  
**Constraints**: No production deployment actions; do not use direct `*.run.app` URLs  
**Scale/Scope**: One global UX initiative with role matrix, baseline findings, IA redesign artifacts, and rerun checklist

## Constitution Check

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Spec-First | Pass | Work starts from `spec.md` and execution is task-driven. |
| II. Multi-Repo Orchestration | Pass | Outputs explicitly map to downstream repos for implementation. |
| III. Test-Aligned | Pass | Baseline plus rerun checklist enforce measurable UX validation. |
| IV. Branch & Integration | Pass | Feature docs live under `specs/029-workbench-ux-wayfinding/`. |
| V. Privacy & Security | Pass | No production data changes; auth blockers documented as prerequisites. |
| VI. Accessibility & i18n | Pass | Includes language consistency and first-use clarity requirements. |
| VII. Split-Repo First | Pass | This repo defines work; implementation is delegated to target repos. |
| VIII. GCP CLI Infra | Pass | No infra mutations in this feature scope. |
| IX. Responsive/PWA | Pass | UX tasks cover role flows and wayfinding behavior, including deep navigation states. |
| X. Jira Traceability | Pass | Backlog conversion is part of task output. |
| XI. Documentation | Pass | Deliverables include plan, research, quickstart, and checklist artifacts. |
| XII. Release Engineering | Pass | Dev-only validation; no release branch or main merge actions in scope. |

## Project Structure

### Documentation (this feature)

```text
specs/029-workbench-ux-wayfinding/
|-- spec.md                      # Feature specification
|-- plan.md                      # This file
|-- research.md                  # Baseline findings and decisions
|-- quickstart.md                # Execution guide for baseline and rerun
|-- tasks.md                     # Work breakdown
`-- checklists/
    `-- requirements.md          # Ready checklist for post-auth role rerun
```

### Source Code (downstream implementation targets)

```text
workbench-frontend/
`-- src/
    `-- features/workbench/
        |-- navigation/          # menu IA and labels
        |-- shared/              # breadcrumbs, back context, next-step hints
        |-- review/              # deep-flow wayfinding
        |-- survey/              # flow guidance and status cues
        `-- group/               # discoverability and return paths

chat-backend/ (conditional)
`-- src/
    `-- routes/ and services/    # endpoints or metadata needed for UX context/state

chat-frontend-common/ (conditional)
`-- src/
    `-- shared UX primitives     # reusable copy/components if adopted cross-app
```

**Structure Decision**: This repository remains documentation-only; implementation tasks produced here are executed in split target repositories.

## Implementation Strategy

1. **Unblock and normalize baseline**
   - Resolve dev auth path for role matrix and align frontend/backend deploy cycle.
2. **Capture role-based evidence**
   - Record sign-in outcomes, menu visibility, deep-flow navigation, and blockers.
3. **Design target IA and wayfinding**
   - Build a role-aware navigation model with explicit back paths and next-step prompts.
4. **Convert findings into delivery backlog**
   - Create implementation-ready tasks by severity and owner team.
5. **Run post-fix rerun gate**
   - Execute checklist and compare baseline vs rerun outcomes.

## Dependencies and Assumptions

- Approved role accounts are available for dev validation.
- Auth unblock method is agreed and documented before rerun.
- Baseline evidence in `artifacts/workbench-ux-audit-20260312-232652/` remains the reference package.
- Implementation teams in downstream repos will consume task outputs from this feature.

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Auth remains blocked for key roles | Medium | Treat auth unblock as Phase 1 gate; do not start deep UX conclusions before gate is green. |
| Incomplete test data for deep flows | Medium | Add explicit data prerequisites and ownership in quickstart/checklist. |
| Functional passes hide UX confusion | High | Use task-based usability criteria instead of page-load checks only. |
| Role-specific menu divergence creates inconsistency | Medium | Maintain role matrix and shared label dictionary in the backlog. |

## Complexity Tracking

No constitution violations. Scope is orchestration-heavy but implementation-light in this repository.

## Post-Design Constitution Re-check

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Spec-First | Pass | Clarifications integrated into `spec.md`; plan artifacts generated from approved spec. |
| III. Test-Aligned | Pass | Added explicit audit contract and measurable rerun gate definitions. |
| V. Privacy & Security | Pass | Evidence retention and audit handling are documented as explicit rules. |
| X. Jira Traceability | Pass | Feature Epic/Stories/Subtasks created and linked for `029`. |
| XI. Documentation | Pass | Planning artifacts now include `data-model.md`, `contracts/`, and `quickstart.md`. |
| XII. Release Engineering | Pass | Scope remains dev-only validation with no production actions. |

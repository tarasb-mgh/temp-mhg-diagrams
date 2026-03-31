# Implementation Plan: Unified Workbench Tag Center

**Branch**: `042-workbench-tag-center` | **Date**: 2026-03-31 | **Spec**: [spec.md](./spec.md)  
**Jira Epic**: [MTB-1049](https://mentalhelpglobal.atlassian.net/browse/MTB-1049)  
**Input**: Feature specification from `/specs/042-workbench-tag-center/spec.md`

## Summary

Deliver a single Workbench Tag Center with two explicit modes (`User Tags`, `Review Tags`), unify backend tagging contracts, and migrate tester-tag behavior into standard user-tag behavior. The implementation must keep domain separation in UI, expose all user tags on user profile pages, enforce review-tag deletion guardrails for any historical usage, and preserve the clarified access model where rights-management and tag-definition actions are gated while user-tag assignment is not capability-gated.

## Technical Context

**Language/Version**: TypeScript 5.x (React 18 frontend, Node.js/Express backend)  
**Primary Dependencies**: React, Zustand, react-router, react-i18next, Express, PostgreSQL, shared `chat-types`, shared `chat-frontend-common`  
**Storage**: PostgreSQL tagging tables (`tag_definitions`, `user_tags`, review-tag linkage tables)  
**Testing**: Vitest + React Testing Library (frontend), backend unit/integration tests, Playwright E2E (`chat-ui`)  
**Target Platform**: Workbench web frontend + backend API on existing dev/prod environments  
**Project Type**: Split web application (multi-repository frontend/backend/shared packages)  
**Performance Goals**:
- Primary tag flows complete without blocking failure in automated dev E2E runs
- SC-003 gate: each happy flow run 10 consecutive times with <=2 blocking-failure runs
**Constraints**:
- One unified Tag Center entry point only
- No legacy URL compatibility requirement
- Review-tag deletion blocked if any active or historical review reference exists
- User-tag assignment allowed for all users without capability gating
- Rights-management and tag-definition actions remain gated
- Localization delivery order: `en` -> `uk` -> `ru`
**Scale/Scope**:
- Multi-repo change touching workbench UI, backend APIs, shared models, and E2E
- Internal operational usage (moderation/review/admin workflows)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| # | Principle | Status | Notes |
|---|-----------|--------|-------|
| I | Spec-First Development | PASS | Approved spec exists in `specs/042-workbench-tag-center/spec.md` |
| II | Multi-Repository Orchestration | PASS | Planned work spans split repos only (`workbench-frontend`, `chat-backend`, `chat-frontend-common`, `chat-types`, `chat-ui`) |
| III | Test-Aligned Development | PASS | Uses existing Vitest/RTL/Playwright standards with explicit E2E flow coverage |
| IV | Branch and Integration Discipline | PASS | Feature branch workflow and PR-to-`develop` policy unaffected |
| V | Privacy and Security First | PASS | Authorization model and destructive-operation guardrails are explicit |
| VI | Accessibility and Internationalization | PASS | New UI content requires translatable copy (`en`, `uk`, `ru`) and workbench accessibility defaults |
| VI-B | Design System Compliance | PASS | Tag Center is implemented in workbench design-system patterns |
| VII | Split-Repository First | PASS | No legacy monorepo changes planned |
| VIII | GCP CLI Infrastructure Management | PASS (N/A) | No infrastructure changes required |
| IX | Responsive UX and PWA Compatibility | PASS | Workbench user-facing pages remain responsive and testable |
| X | Jira Traceability and Project Tracking | PASS | Epic exists (`MTB-1049`) and plan outputs will be linked |
| XI | Documentation Standards | PASS | User-facing flow changes are suitable for documentation updates |
| XII | Release Engineering and Production Readiness | PASS | No release-topology change; standard dev validation path applies |

**Gate result: PASS** - No principle violations identified.

## Project Structure

### Documentation (this feature)

```text
specs/042-workbench-tag-center/
├── plan.md                     # This file
├── research.md                 # Phase 0 output
├── data-model.md               # Phase 1 output
├── quickstart.md               # Phase 1 output
├── contracts/
│   └── tag-center-api.yaml     # Unified tagging API contract
└── tasks.md                    # Phase 2 output (/speckit.tasks)
```

### Source Code (target repositories)

```text
chat-types/src/
└── tags.ts                              # Shared DTO/types for unified tag center

chat-frontend-common/src/
├── api/tagCenter.ts                     # Unified tag-center client methods
└── permissions/workbenchPermissions.ts  # Rights-management capability helpers

chat-backend/src/
├── routes/admin.tagCenter.ts            # Unified definitions/assignments/rights API
├── services/tagCenter.service.ts        # Domain orchestration for tag center operations
├── services/tagDefinition.service.ts    # Existing definition lifecycle updates
├── services/userTag.service.ts          # Assignment/unassignment behavior
└── routes/review.queue.ts               # Review-tag dependency checks if needed

workbench-frontend/src/
├── features/tags/TagCenterPage.tsx      # Unified entry point with User/Review modes
├── features/tags/components/            # Mode-specific definition and assignment UIs
├── features/users/UserProfileView.tsx   # Show all assigned user tags
├── router/routes.tsx                    # Route consolidation to Tag Center
└── locales/{en,uk,ru}/                  # Tag Center and profile tag copy

chat-ui/tests/e2e/workbench/
└── tag-center.spec.ts                   # Mandatory E2E flows and screenshot evidence
```

**Structure Decision**: Keep split-repository implementation and introduce one unified feature vertical (`tag center`) across backend, frontend, shared API/types, and E2E.

## Cross-Repository Dependencies

### Execution Order

```text
1. chat-types                 -> finalize shared DTO contracts and enums
2. chat-backend               -> implement unified API surface and migration-safe behavior
3. chat-frontend-common       -> expose unified client and permission helpers
4. workbench-frontend         -> implement unified Tag Center UI and profile tag visibility
5. chat-ui                    -> implement and run mandatory E2E coverage set
```

### Inter-repo Dependencies

| From | To | Dependency |
|------|----|------------|
| `chat-types` | `chat-backend`, `chat-frontend-common`, `workbench-frontend` | Shared request/response shape consistency |
| `chat-backend` | `workbench-frontend` | Unified endpoints must exist before UI integration validation |
| `chat-frontend-common` | `workbench-frontend` | Shared API calls and permission helpers for route/action gating |
| `workbench-frontend` | `chat-ui` | UI route and selectors must be stable for E2E |

## Phase 0 Research Summary

Research decisions are captured in `research.md` and resolve all planning uncertainties:

1. One Tag Center entry with dual-mode UX is the selected IA
2. Tester-tag dedicated API is deprecated in favor of unified contracts
3. Review-tag delete is blocked on any active/historical reference
4. Assignment behavior is intentionally non-capability-gated for all users
5. Rights-management and definition actions remain gated and auditable
6. SC-003 execution protocol is fully specified (automated dev E2E, 10 runs)

## Phase 1 Design Summary

Phase 1 outputs define:

- Unified domain entities and state transitions in `data-model.md`
- A single API contract in `contracts/tag-center-api.yaml`
- A practical end-to-end validation flow in `quickstart.md`
- Updated agent context through the standard context refresh script

## Post-Design Constitution Check

| # | Principle | Status | Notes |
|---|-----------|--------|-------|
| II | Multi-Repository Orchestration | PASS | Cross-repo boundaries and order documented |
| III | Test-Aligned Development | PASS | Dedicated mandatory E2E matrix included |
| V | Privacy and Security First | PASS | Delete guardrails and authorization split explicitly documented |
| VI | Accessibility and Internationalization | PASS | Localization order and user-facing text coverage retained |
| VII | Split-Repository First | PASS | No legacy monorepo targets introduced |
| X | Jira Traceability and Project Tracking | PASS | Artifacts tied to `MTB-1049` |

**Post-design gate result: PASS** - Phase 1 remains constitution-compliant.

## Key Implementation Decisions

### Single Entry, Dual Domain UX

Expose one Tag Center route with explicit domain mode switch. This reduces navigation fragmentation while preserving cognitive separation between `User Tags` and `Review Tags`.

### Unified Backend Surface

Replace dedicated tester-only API flows with unified definition/assignment contracts that still preserve domain-specific guardrails (for example, review-tag delete blocking rules).

### Explicit Authorization Split

Keep rights-management and definition lifecycle actions gated; keep user-tag assignment ungated by capability per clarified business rule.

### Contextual Secondary Controls for Rights Management

Keep high-frequency definition and assignment flows visually primary, and place rights-management actions as compact secondary controls in the assignments header (icon refresh + save action) to reduce layout noise on desktop and mobile.

### Profile Completeness

User profile shows all assigned user tags from the same source of truth used by Tag Center assignment flows.

### E2E-First Validation Discipline

Mandatory operations and error/permission paths must be covered in automated Playwright flows, including SC-003 reliability gate runs.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| None | N/A | N/A |

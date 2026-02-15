# Implementation Plan: Split Chat and Workbench Experiences

**Branch**: `001-split-workbench-app` | **Date**: 2026-02-14 | **Spec**: `specs/001-split-workbench-app/spec.md`  
**Input**: Feature specification from `/specs/001-split-workbench-app/spec.md`

## Summary

Deliver a full frontend + backend split between chat and workbench, including
independently deployable backend services for independent scaling, plus
environment-specific dedicated workbench domains:
`workbench.mentalhelp.chat` and `api.workbench.mentalhelp.chat` in production,
with the same pattern for development while preserving existing chat domains.

## Technical Context

**Language/Version**: TypeScript (frontend/UI tests), Node.js 20 (backend/services)  
**Primary Dependencies**: React, React Router, Vite, Express/Nest-style backend routing conventions, Playwright, Vitest  
**Storage**: Existing DB/session stores and backend APIs (no new business data domain required; service boundary and routing updates required)  
**Testing**: Vitest (`chat-frontend`, `chat-backend`), React Testing Library (`chat-frontend`), Playwright (`chat-ui`)  
**Target Platform**: Modern web browsers, GCP-hosted backend services, environment-specific DNS/LB routing  
**Project Type**: Split-repository multi-service web platform (`chat-frontend`, `chat-backend`, `chat-ui`, `chat-infra`, `chat-ci`)  
**Performance Goals**: Independent horizontal scaling for chat and workbench backends without cross-surface degradation  
**Constraints**: Preserve auth/role boundaries, keep chat domains stable, enforce workbench domain/API isolation, preserve responsive + PWA compatibility  
**Scale/Scope**: User entry points, backend service boundaries, domain topology (prod/dev), smoke coverage for critical routes/deep links/APIs

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] Spec-first workflow is preserved (`spec.md` → `plan.md` → `tasks.md` → implementation)
- [x] Affected split repositories are explicitly listed with per-repo file paths
- [x] Test strategy aligns with each target repository conventions
- [x] Integration strategy enforces PR-only merges into `develop` from feature/bugfix branches
- [x] Required approvals and required CI checks are identified for each target repo
- [x] Post-merge hygiene is defined: delete merged remote/local feature branches and sync local `develop` to `origin/develop`
- [x] For user-facing changes, responsive and PWA compatibility checks are defined (breakpoints, installability, and mobile-browser coverage)
- [x] Post-deploy smoke checks are defined for critical routes, deep links, and API endpoints

## Project Structure

### Documentation (this feature)

```text
specs/001-split-workbench-app/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── experience-split-validation.yaml
└── tasks.md
```

### Source Code (repository root)

```text
chat-frontend/
├── src/
│   ├── app/
│   ├── features/chat/
│   ├── features/workbench/
│   ├── routes/
│   └── services/

chat-backend/
├── src/
│   ├── routes/chat/
│   ├── routes/workbench/
│   ├── middleware/
│   └── services/

chat-infra/
├── gcp/
│   ├── dns/
│   ├── lb/
│   └── services/

chat-ui/
└── tests/
    ├── chat/
    ├── workbench/
    ├── routing/
    └── api/
```

**Structure Decision**: Implement split boundaries in both frontend and backend,
deploy backend surfaces independently, and codify domain topology in infra and
release validation artifacts.

## Phase 0: Research Plan

1. Determine backend service split pattern that maximizes independent scaling while minimizing auth/session drift.
2. Define canonical prod/dev domain mapping for chat/workbench frontend and API hosts.
3. Define routing and CORS boundary patterns to prevent cross-surface API leakage.
4. Define smoke and regression evidence requirements for new domain/service topology.

## Phase 1: Design Plan

1. Extend data model with backend surface and domain topology entities.
2. Define validation contract for frontend route split, backend boundary isolation, and domain correctness.
3. Create quickstart checks for prod/dev domain parity, CORS integrity, and deep-link/API smoke.
4. Update agent context after design completion.

## Post-Design Constitution Re-check

- [x] Cross-repo scope is explicit and includes backend/infra/CI dependencies
- [x] Responsive and PWA requirements remain preserved after split
- [x] API/domain smoke checks are explicit for both dev and prod
- [x] No unresolved clarifications remain

## Merge and Gate Checklist

### Pre-merge gates (per repository)

- [ ] All unit tests pass (`vitest run`)
- [ ] TypeScript compiles without errors (`tsc -b`)
- [ ] Linter passes (if configured)
- [ ] PR has required approvals
- [ ] CI checks are green

### Integration order

1. **chat-backend**: Merge first; backend surface filtering must be deployed before frontend or infra changes take effect.
2. **chat-infra**: Provision DNS/SSL/LB/Cloud Run after backend is deployed.
3. **chat-frontend**: Frontend split requires backend + infra to be in place for correct API routing.
4. **chat-ui**: E2E tests run last after all services are deployed and accessible.

### Post-merge verification

- [ ] `develop` branch CI passes in all repos after merge
- [ ] Dev deployment succeeds for both chat and workbench services
- [ ] Domain topology validation passes (DNS, SSL, LB)
- [ ] E2E test suite passes against deployed surfaces
- [ ] Feature branches deleted (remote + local) per branch hygiene policy

### Release promotion

- Cut `release/*` branch from `develop` after dev validation passes
- Follow standard release-promotion-main-prod flow

## Complexity Tracking

No constitution violations identified; no exceptions required.

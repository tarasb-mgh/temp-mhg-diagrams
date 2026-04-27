# Implementation Plan: Review MVP Defect Bundle

**Branch**: `060-review-mvp-fixes` | **Date**: 2026-04-27 | **Spec**: [`spec.md`](./spec.md)
**Input**: Feature specification from `/specs/060-review-mvp-fixes/spec.md`
**Jira Epic**: MTB-1546 | **Child bugs**: MC-64, MC-65, MC-66, MC-67 | **Blocks**: MC-63

## Summary

Fix four user-facing defects (MC-64/65/66/67) discovered in the 2026-04-27 dev regression so the MC-63 chat-backend release can ship the 058 Reviewer Queue + 059 Reports work to production without regressing the existing Reviewer Queue / Dashboard / Team Dashboard surfaces. Coordinated multi-repo work across **chat-backend** (queue API broken-filter, dashboard counter unification, broken-reason enum + DB migration, Team Dashboard membership reconciliation), **workbench-frontend** (defensive filter, dynamic broken-badge tooltip, Team Dashboard empty-state, Dashboard tile scope label), and **client-spec/regression-suite** (RQ-002a, RQ-014, RD-005 YAML test additions). Total estimated effort: ~2 engineer-days.

## Technical Context

**Language/Version**:
- chat-backend: TypeScript 5.x, Node.js 20 LTS, Express 5.x
- workbench-frontend: TypeScript 5.x, React 18, Vite 5.x, react-router 6.x
- client-spec/regression-suite: YAML 1.2 (no code; AI-agent-driven)

**Primary Dependencies**:
- chat-backend: `pg` (PostgreSQL driver), existing `db/migrations/` SQL migration system, Vitest
- workbench-frontend: `@mentalhelpglobal/chat-types` (DTO types), `@mentalhelpglobal/chat-frontend-common` (auth, API helpers), Vitest + React Testing Library
- regression-suite: Playwright MCP (`browser_navigate`, `browser_snapshot`, `browser_click`, etc.) — no in-suite dependency

**Storage**: PostgreSQL on Cloud SQL `chat-db-dev` / `chat-db-prod` (europe-west1). Existing `sessions` and `reviews` tables are touched. New typed-reason migration adds a non-breaking column.

**Testing**:
- Backend: Vitest unit tests next to source; integration tests against test DB
- Frontend: Vitest + React Testing Library component tests
- E2E: regression-suite YAML tests interpreted by AI agent via Playwright MCP against `https://workbench.dev.mentalhelp.chat`

**Target Platform**:
- chat-backend: Cloud Run (`europe-west1`) — `chat-backend-dev` and `chat-backend` (prod)
- workbench-frontend: GCS bucket fronted by GCLB at `workbench.dev.mentalhelp.chat` / `workbench.mentalhelp.chat`

**Project Type**: Multi-repo defect-fix bundle. Three repos affected; one coordinated release window.

**Performance Goals**:
- Queue API broken filter MUST add no measurable latency (`<5ms` overhead vs current p95).
- Dashboard counter call MUST resolve in `<300ms` (matches existing tile load expectation).
- Team Dashboard membership endpoint MUST resolve in `<200ms`.

**Constraints**:
- Backwards-compatible DB migration: legacy rows with NULL `is_broken` MUST be treated as not-broken (default false).
- No incidental refactors to unrelated review code paths.
- All user-visible strings (broken-reason tooltips, Team Dashboard empty-state copy) MUST exist in en/uk/ru per Principle VI.
- Design system compliance per Principle VI-B (no ad-hoc styling for the new empty-state copy or scope-label additions).

**Scale/Scope**:
- Affects 4 surfaces (Review Queue list, Dashboard tile, Team Dashboard page, Broken-badge tooltip).
- ~2 engineer-days total (~1d backend + ~0.5d frontend + ~0.5d regression-suite + ~0.5d verify).
- 3 new regression tests (RQ-002a, RQ-014, RD-005); 0 existing tests deleted; 12 existing passing tests must continue passing.
- 4 Jira bugs closed; 1 Jira Epic completed.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Spec-First | ✅ | spec.md authored at `specs/060-review-mvp-fixes/spec.md`, reviewed APPROVED, 0 [NEEDS CLARIFICATION] markers; this plan follows. |
| II. Multi-Repo Orchestration | ✅ | Plan explicitly enumerates the 3 affected repos (chat-backend, workbench-frontend, client-spec) with target paths per change. |
| III. Test-Aligned (Mandatory Coverage) | ✅ | Each bug fix gets a regression test that reproduces the original defect and verifies fix. RQ-014 reproduces MC-65, RQ-002a reproduces MC-64, RD-005 reproduces MC-67, MC-66 covered by an integration test on the typed-reason mapping. |
| IV. Branch & Integration Discipline | ✅ | Feature branch `060-review-mvp-fixes` exists in client-spec; matching `bugfix/060-review-mvp-fixes` branches to be created in chat-backend and workbench-frontend. PRs to develop only; no `--admin`. |
| V. Privacy/Security | ✅ | No PII handling change. Admin-only `?include_broken=true` opt-in is gated server-side; no new auth surfaces. Audit log for filtered counts (FR-020) is non-PII observability. |
| VI. Accessibility/i18n | ✅ | New broken-reason tooltip strings + Team Dashboard empty-state copy added in en/uk/ru. Keyboard accessibility preserved (no new modals; tooltip uses existing badge component). |
| VI-B. Design System Compliance | ✅ | Dashboard tile scope label uses existing `.text-xs text-neutral-500` typography token; Team Dashboard empty-state uses existing card pattern; no ad-hoc styling. |
| VII. Split-Repo First | ✅ | All work in split repos (chat-backend, workbench-frontend, client-spec); no chat-client touch. |
| VIII. GCP CLI Infra | N/A | No infra changes. DB migration uses existing migrations system invoked via the standard backend deploy. |
| IX. Responsive/PWA | ✅ | No layout changes that affect mobile/tablet/desktop. The added scope label and empty-state copy reflow naturally within existing components. |
| X. Jira Traceability | ✅ | Epic MTB-1546 created, 4 child bugs (MC-64..67) linked. Plan summary will be added as a comment on MTB-1546 after this plan lands. Per-task Jira creation will happen during `/speckit.tasks`. |
| XI. Documentation | ⚠️ | No User Manual or Non-Technical Onboarding update needed (no new user-facing workflow). Release Notes entry required when MTB-1546 ships to prod with MC-63 — flagged in Phase 4 verify checklist. |
| XII. Release Engineering | ✅ | This work lands on `develop` ahead of MC-63's release branch cut. The release of these fixes follows the standard `develop → release/* → main` flow under owner approval — no autonomous merging. |
| XIII. CX Agent | N/A | No Dialogflow CX changes. |

**Gate**: Passes. No constitutional violations require justification.

## Project Structure

### Documentation (this feature)

```text
specs/060-review-mvp-fixes/
├── plan.md                    # This file
├── research.md                # Phase 0 output: research log + decisions
├── data-model.md              # Phase 1 output: Session, BrokenReason, TeamMembership entities
├── contracts/                 # Phase 1 output: API contracts for the 4 affected endpoints
│   ├── review-queue.md        # GET /api/review/queue (broken-filter behavior)
│   ├── dashboard-summary.md   # GET /api/dashboard/summary (Pending Review tile)
│   ├── team-dashboard-membership.md  # GET /api/team-dashboard/membership (new shape)
│   └── session-dto.md         # Session DTO additions (brokenReason field)
├── quickstart.md              # Phase 1 output: how to run the fixes locally + verify
├── checklists/
│   └── requirements.md        # From /speckit.specify
└── tasks.md                   # Phase 2 output (/speckit.tasks)
```

### Source Code (repository roots)

```text
chat-backend/                                                 (~1 day)
├── src/
│   ├── routes/
│   │   ├── review.queue.ts                  # FR-001/002 broken-filter + opt-in
│   │   ├── dashboard.ts                     # FR-004/005 unify counter source
│   │   └── team-dashboard.ts                # FR-013..016 membership reconciliation
│   ├── services/
│   │   ├── review-queue.service.ts          # NEW: shared count helper used by both routes
│   │   ├── broken-detection.service.ts      # FR-009..012 typed reason refactor
│   │   └── team-membership.service.ts       # FR-013 single-source membership getter
│   ├── types/
│   │   └── review.ts                        # FR-010 add brokenReason to Session DTO
│   ├── db/migrations/
│   │   └── 060_broken_reason_column.sql     # FR-009 add broken_reason column
│   └── observability/
│       └── queue-filter-log.ts              # FR-020 broken-filtered count log
└── tests/
    ├── unit/services/review-queue.test.ts   # parity helper coverage
    ├── unit/services/broken-detection.test.ts  # reason mapping per criterion
    └── integration/api/review-queue.test.ts # broken-filter behavior; admin opt-in gating

workbench-frontend/                                           (~0.5 day)
├── src/
│   ├── features/
│   │   ├── review/
│   │   │   ├── Queue.tsx                    # FR-003 defensive filter
│   │   │   ├── BrokenBadge.tsx              # FR-012 dynamic tooltip via i18n
│   │   │   └── TeamDashboard.tsx            # FR-014/015 empty-state branching
│   │   └── dashboard/
│   │       └── PendingReviewTile.tsx        # FR-006/007 scope label + click-through
│   └── i18n/
│       ├── en/review.json                   # brokenReason.* + teamDashboard.* keys
│       ├── uk/review.json
│       └── ru/review.json
└── src/__tests__/
    ├── BrokenBadge.test.tsx                 # tooltip-from-reason mapping
    ├── TeamDashboard.test.tsx               # empty-state branches
    └── PendingReviewTile.test.tsx           # scope label + Space-aware click-through

client-spec/                                                  (~0.5 day)
└── regression-suite/
    ├── 03-review-queue.yaml                 # add RQ-002a, RQ-014
    └── 05-review-dashboards.yaml            # add RD-005
```

**Structure Decision**: Multi-repo split as enumerated above. Each repo owns its layer of the fix; the regression-suite ties them together at the integration level.

## Phasing

| Phase | Repo | Deliverable | Effort | Owner-approval gate |
|-------|------|-------------|--------|---------------------|
| 1 | chat-backend | DB migration + 4 backend changes + tests | ~1 day | PR to develop, dev deploy via `workflow_dispatch` from feature branch |
| 2 | workbench-frontend | 4 component fixes + i18n + component tests | ~0.5 day | PR to develop, dev deploy via `workflow_dispatch` |
| 3 | client-spec/regression-suite | 3 new YAML tests, _config.yaml unchanged | ~0.5 day | PR to develop |
| 4 | Verify | Re-run regression on dev; confirm 15/15 pass; close child bugs | ~0.5 day | Owner reviews evidence in `evidence/060/`, closes MC-64..67 + MTB-1546 |

**Coordination with MC-63**: This Epic must close before the MC-63 release branch is cut. Phases 1-3 land in develop; Phase 4 verifies on dev. When all 4 child bugs are closed and Phase 4 evidence is in, MC-63 is unblocked for its release-branch cut (which itself requires owner approval per Principle XII).

## Cross-Repository Dependencies

| Dep | From | To | Notes |
|-----|------|----|-------|
| Session DTO with `brokenReason` field | chat-backend | workbench-frontend | If `chat-types` is updated, bump version + publish before frontend `npm install`. If the type lives in chat-backend's local `types/`, no version bump needed. Per design doc: lives in chat-backend's local types and is re-exported through `chat-types` per the existing pattern. |
| `TeamMembership` response shape | chat-backend | workbench-frontend | New `missingRole` field; frontend MUST handle absence gracefully if backend rolls out before frontend. |
| Queue broken-filter behavior | chat-backend | regression-suite | RQ-014 asserts the backend filter works end-to-end; runs against dev after Phase 1 deploy. |
| Dashboard counter unification | chat-backend + workbench-frontend | regression-suite | RQ-002a needs both backend (single source) and frontend (scope label) to land before it can pass. |

**Order constraint**: Phase 1 (backend) MUST land before Phase 3 regression tests can pass. Phase 2 (frontend) and Phase 3 may proceed in parallel after Phase 1 lands on dev.

## Complexity Tracking

> **No constitutional violations require justification.** All gates pass.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| (none) | | |

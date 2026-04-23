# Implementation Plan: Reviewer MVP Gap Closure

**Branch**: `059-reviewer-mvp-gaps` | **Date**: 2026-04-22 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/059-reviewer-mvp-gaps/spec.md`

## Summary

Close the remaining MVP implementation gaps for the Reviewer/Researcher
flow documented in feature 058. This is a polish / hardening pass — no
new backend tables, no new API endpoints. Changes span admin settings
additions, notification wiring, frontend state components, multi-tab
reconciliation gating, a canonical Toggle adoption, an in-app unsaved
changes modal, a browser capability guard, axe-core E2E integration, and
an audit log purge job. All 11 user stories map to extensions of existing
058 infrastructure.

## Technical Context

**Language/Version**:
- `chat-types`: TypeScript 5.x (consumed by client + server).
- `chat-backend`: Node.js 20 LTS, Express 4.x, Knex/Postgres.
- `workbench-frontend`: React 18, Vite 5, TypeScript 5.x, Tailwind.
- `chat-frontend-common`: TypeScript shared component library.
- `chat-ui`: Playwright 1.x, TypeScript.

**Primary Dependencies**:
- Backend: Express, Knex, Postgres 15, Pino, existing audit-log
  middleware, existing notification service, existing session timeout
  middleware.
- Frontend: React 18, react-i18next, IndexedDB (raw, no idb wrapper),
  axios, Zustand, React Router v6, existing `useFocusRefresh` hook,
  existing offline queue, `Toggle` from `chat-frontend-common`.
- Test infra: Vitest (chat-backend, workbench-frontend),
  `@axe-core/playwright` (chat-ui, NEW), Playwright MCP
  (regression-suite YAML).

**Storage**:
- Postgres: 2 new admin setting keys (column or KV insert), no new
  tables.
- Browser IndexedDB: no schema change (existing offline queue).

**Testing**:
- Vitest unit + integration in `chat-backend` and `workbench-frontend`
  (Constitution III: positive + negative per scenario).
- Playwright in `chat-ui` with axe-core (NEW).
- Regression-suite YAML updates for new test cases.

**Target Platform**:
- Browsers: latest 2 versions of Chrome, Edge, Firefox, Safari.
- Viewports: same as 058 (≥768 px full fidelity, 360–767 px mobile).

**Project Type**: Web application across multiple split repositories.

**Performance Goals**:
- Skeleton within 200ms of fetch start (FR-007).
- Notification propagation ≤ 60s (SC-007).
- Inactivity timeout round-trip ≤ 1 min (SC-006).

**Constraints**:
- No new backend tables or endpoints.
- Toggle scope: Settings pages only (clarification Q2).
- Cold-tier audit log deferred to infra (clarification Q3).
- All Markdown English-only (Constitution XI).
- Design system tokens only (Constitution VI-B).

**Scale/Scope**:
- 11 user stories, 31 functional requirements, 6 edge cases, 12
  success criteria from `spec.md`.

## Constitution Check

| Principle | Status | Note |
|-----------|--------|------|
| I. Spec-First Development | PASS | Spec exists with 2 rounds of clarification resolved. |
| II. Multi-Repository Orchestration | PASS | Targets `chat-types`, `chat-backend`, `workbench-frontend`, `chat-frontend-common`, `chat-ui`. Cross-repo deps documented below. |
| III. Test-Aligned Development | PASS | Vitest positive + negative per scenario; axe-core gate in chat-ui; regression-suite updates. |
| IV. Branch and Integration Discipline | PASS | Branch `059-reviewer-mvp-gaps`; per-PR dev deploy + green CI; merge requires owner approval. |
| V. Privacy and Security First | PASS | Inactivity timeout hardening (FR-015..017); audit log retention (FR-026..028); no new PII exposure. |
| VI. Accessibility and Internationalization | PASS | axe-core CI gate (FR-025); `aria-live` on states (FR-003, FR-010); all new strings in uk/ru/en. |
| VI-B. Design System Compliance | PASS | Canonical Toggle adoption (FR-019); shared state components use design-system tokens. |
| VII. Split-Repository First | PASS | All work in split repos; chat-client untouched. |
| VIII. GCP CLI Infrastructure Management | N/A | No infra changes (purge job is in-process, not Cloud Run). |
| IX. Responsive UX and PWA Compatibility | PASS | Shared state components responsive; no new PWA manifest changes. |
| X. Jira Traceability | PLANNED | Epic + Stories created after `/speckit.tasks`. |
| XI. Documentation Standards | PASS | All artifacts in English. |
| XII. Release Engineering | PASS | Dev-only validation; no release branch without owner approval. |
| XIII. CX Agent Management | N/A | No Dialogflow CX changes. |

No constitution gate fails. No deviations require Complexity Tracking.

## Project Structure

### Documentation (this feature)

```
specs/059-reviewer-mvp-gaps/
├── spec.md                  # Feature specification (2 rounds of clarification)
├── research.md              # Phase 0 (this iteration)
├── data-model.md            # Phase 1 (this iteration)
├── quickstart.md            # Phase 1 validation guide
├── plan.md                  # This file
├── tasks.md                 # Phase 2 (/speckit.tasks output)
└── checklists/
    └── requirements.md      # /speckit.specify quality checklist
```

### Source Code (across repositories)

```
chat-types/                                      # Shared TS types
└── src/
    ├── adminSettings.ts                         # +verbose_autosave_failures, +inactivity_timeout_minutes
    └── notification.ts                          # +'space.membership_change' category

chat-backend/                                    # Express API
├── src/
│   ├── routes/admin.settings.ts                 # PATCH handler: +2 new keys, +audit emission
│   ├── services/settings.service.ts             # +getInactivityTimeout(), +getVerboseAutosaveFailures()
│   ├── middleware/sessionTimeout.middleware.ts   # read DB setting instead of env var
│   ├── services/reviewNotification.service.ts   # +emitSpaceMembershipChange()
│   ├── routes/group.members.ts                  # wire membership change → notification emit
│   ├── services/reviewQueue.service.ts          # +recomputeCompletion on settings change
│   ├── services/auditPurge.service.ts           # NEW: daily purge job
│   ├── services/redFlagEmail.service.ts         # +per-message deep link in email
│   └── db/migrations/067_059-reviewer-mvp-gaps.sql  # admin setting columns
├── tests/unit/
│   ├── adminSettings.059.test.ts                # +inactivity_timeout, +verbose toggle
│   ├── notificationMembership.test.ts           # space.membership_change emission
│   ├── auditPurge.test.ts                       # purge job: age filter, legal_hold, batch row
│   └── recomputeCompletion.059.test.ts          # auto-complete on count decrease
└── tests/integration/                           # if applicable

workbench-frontend/                              # React app
├── src/
│   ├── components/states/
│   │   ├── LoadingSkeleton.tsx                  # FR-007
│   │   ├── EmptyState.tsx                       # FR-008
│   │   └── ErrorState.tsx                       # FR-009
│   ├── components/
│   │   ├── UnsavedChangesModal.tsx              # FR-013/014
│   │   └── BrowserCapabilityGuard.tsx           # FR-023/024
│   ├── features/workbench/review/
│   │   ├── ReviewSessionView.tsx                # Submit countdown (FR-001..003), reconciliation gate (FR-011)
│   │   ├── ReviewQueueView.tsx                  # Focus refresh on tab return (FR-029), adopt shared states
│   │   ├── ReportView.tsx                       # Adopt shared states
│   │   ├── ReviewDashboard.tsx                  # Adopt shared states
│   │   ├── ClinicalTagPicker.tsx                # Retired tag rendering (FR-004..006)
│   │   ├── components/TagChip.tsx               # Retired prefix + tooltip (FR-004/005)
│   │   └── offline/
│   │       ├── useFocusRefresh.ts               # Gate-snapshot-reconcile loop (FR-011)
│   │       ├── useBeforeUnloadGuard.ts          # Keep native handler
│   │       └── OfflineBanner.tsx                # Existing, minor label tweak
│   ├── features/workbench/settings/
│   │   └── SettingsView.tsx                     # Canonical Toggle adoption (FR-019), +2 admin inputs
│   ├── assets/illustrations/                    # SVG empty/error illustrations
│   └── locales/{en,uk,ru}.json                  # +new i18n keys for all 059 components
├── tests/unit/
│   ├── SubmitCountdown.test.tsx                 # FR-001..003
│   ├── RetiredTagChip.test.tsx                  # FR-004..006
│   ├── SharedStates.test.tsx                    # FR-007..010
│   ├── MultiTabReconciliation.test.tsx          # FR-011..012
│   ├── UnsavedChangesModal.test.tsx             # FR-013..014
│   ├── InactivityTimeout.test.tsx               # FR-015..017
│   ├── VerboseAutosaveToggle.test.tsx           # FR-018..019
│   ├── SpaceMembershipNotification.test.tsx     # FR-020..022
│   ├── BrowserCapabilityGuard.test.tsx          # FR-023..024
│   └── PendingTabFocusRefresh.test.tsx          # FR-029
└── tests/integration/

chat-frontend-common/                            # Design-system library
└── src/components/Toggle.tsx                    # Already exists — no changes needed

chat-ui/                                         # Playwright E2E
├── package.json                                 # +@axe-core/playwright
├── tests/helpers/accessibility.ts               # checkAccessibility(page) helper
└── tests/reviewer/
    └── a11y.spec.ts                             # axe-core on every Reviewer route (FR-025)

regression-suite/                                # AI-runnable YAML harness
└── 19-reviewer-review-queue.yaml                # +new test cases for 059 gaps
```

**Structure Decision**: Pure extension of the existing 058 multi-repo
layout per Constitution VII. No new repositories, no new modules. All
changes are additions to existing files or new files in existing
directories.

## Cross-Repository Coordination

Phase order — strict dependency chain:

1. **chat-types**: Add `verbose_autosave_failures` and
   `inactivity_timeout_minutes` to admin settings types; add
   `space.membership_change` to notification category type. Tagged
   minor release.
2. **chat-backend**: Add migration for admin setting columns; extend
   settings service + PATCH handler; wire notification emission on
   membership change; add purge job; extend session timeout middleware
   to read DB; extend recompute-completion on settings change; add
   per-message deep link to Red Flag email. Consume new `chat-types`.
3. **workbench-frontend**: Create shared state components; adopt across
   all Reviewer surfaces; implement Submit countdown; extend
   `useFocusRefresh` for gate-reconcile; create `UnsavedChangesModal`;
   create `BrowserCapabilityGuard`; adopt canonical `Toggle` on
   Settings; render retired tags; add inactivity timeout + verbose
   toggle admin inputs; render space membership notifications.
   Consume new `chat-types`.
4. **chat-ui**: Add `@axe-core/playwright`; create accessibility helper;
   add `a11y.spec.ts` for every Reviewer route.
5. **regression-suite**: Update `19-reviewer-review-queue.yaml` with
   new test cases for each 059 gap.
6. **Polish**: Run full regression; capture evidence; await owner
   approval for merge.

Each repo gets its own branch named `059-reviewer-mvp-gaps`.

## Risk and Mitigation Summary

| Risk | Mitigation |
|------|------------|
| `useFocusRefresh` gate introduces perceived latency on tab switch | Skeleton overlay is brief (<500ms for local dev); timeout fallback lifts overlay after 3s with a warning |
| React Router `useBlocker` API not stable in project's RR version | Check version at implementation; fall back to `unstable_useBlocker` or `window.onpopstate` shim |
| Purge job races with concurrent reads | Purge runs at 03:00 UTC (off-peak); batch size limited to 1000 rows per iteration |
| axe-core introduces flaky false positives in CI | Pin axe-core version; maintain a known-issues ignore list reviewed quarterly |
| Admin settings read on every request (inactivity timeout) adds latency | Cache the DB setting with 60s TTL in-process; invalidate on PATCH |
| Toggle component from `chat-frontend-common` has API incompatibility with current Settings | Verify props/API at start of implementation; adapt wrapper if needed |

## Complexity Tracking

No constitution-check violations. No entries required.

---

**Phase 0 status**: COMPLETE — see `research.md`.
**Phase 1 status**: COMPLETE — see `data-model.md`, `quickstart.md`.
**Next command**: `/speckit.tasks` to generate the dependency-ordered `tasks.md`.

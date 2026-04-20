# Implementation Plan: Reviewer Review Queue — Full Implementation and E2E Validation

**Branch**: `058-reviewer-review-queue` | **Date**: 2026-04-16 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/058-reviewer-review-queue/spec.md`

## Summary

Deliver the full MVP-grade Reviewer / Researcher experience inside MHG Workbench: a Space-driven Review Queue, a structured rating editor with 8 fixed criteria, per-message clinical tags + Red Flag, autosave with offline mode and multi-tab reconciliation, change-request workflow, Space-scoped Reports, full WCAG 2.1 AA compliance, server-side PII masking with no Reviewer-side reveal, and an end-to-end Playwright MCP regression module exercising every acceptance criterion plus 22 edge cases. Implementation is split across the existing `chat-types`, `chat-backend`, `workbench-frontend`, and `chat-frontend-common` repositories, with E2E coverage in `regression-suite/19-reviewer-review-queue.yaml` plus a Playwright spec mirror in `chat-ui`.

## Technical Context

**Language/Version**:
- `chat-types`: TypeScript 5.x (consumed by both client and server).
- `chat-backend`: Node.js 20 LTS, Express 4.x, Knex/Postgres.
- `workbench-frontend`: React 18, Vite 5, TypeScript 5.x, Tailwind via `chat-frontend-common/tailwind-preset.js`.
- `chat-frontend-common`: TypeScript shared component library.
- `regression-suite`: YAML harness driven by Playwright MCP; `chat-ui` Playwright spec mirror in TypeScript.

**Primary Dependencies**:
- Backend: Express, Knex, Postgres 15, `presidio-analyzer` (Python out-of-process worker for PII NER), `i18next` (server-side error messages), Pino logger, existing audit-log middleware.
- Frontend: React 18, react-i18next, `idb` (IndexedDB wrapper), `axios` for the autosave / ping channel, `web-vitals`, `@axe-core/playwright` (in E2E), `react-hook-form` for editor state, design-system tokens from `chat-frontend-common`.
- Test infra: Vitest (chat-backend, workbench-frontend), Playwright (chat-ui), Playwright MCP (regression-suite YAML).

**Storage**:
- Postgres in `chat-backend`: existing schema extended with new tables and attributes per `data-model.md`.
- Browser IndexedDB (per Reviewer namespace) in `workbench-frontend` for the offline queue (FR-031b).
- GCS (Parquet) for cold-archive Audit Log partitions (FR-050a, Decision 14 in research.md).

**Testing**:
- Vitest unit + integration in `chat-backend` and `workbench-frontend` (Constitution III mandatory positive + negative test for every user-facing scenario).
- Playwright MCP YAML in `regression-suite/19-reviewer-review-queue.yaml`.
- Playwright spec mirror in `chat-ui` for human-runnable / CI-driven E2E.
- `@axe-core/playwright` for accessibility gates.
- Lighthouse CI for performance budget gates (SC-013o).

**Target Platform**:
- Browsers: latest 2 versions of Chrome, Edge, Firefox, Safari (incl. iPadOS) per FR-046h.
- Viewports: ≥ 768 px full fidelity, 360–767 px read-only triage (FR-046f).
- Workbench shell: PWA-installable (FR-046g) — reuses existing `workbench-pwa`.

**Project Type**: Web application across multiple split repositories (Constitution VII).

**Performance Goals**:
- Queue list page TTI ≤ 1.5 s desktop / ≤ 3.0 s tablet (SC-012, SC-013o).
- Session detail TTI ≤ 2.0 s desktop / ≤ 3.0 s tablet for 16-message session (SC-013o).
- Autosave round-trip P95 ≤ 500 ms; focus-fetch reconciliation P95 ≤ 800 ms (SC-013o).
- Transcript scroll ≥ 60 FPS sustained (SC-013o).
- Initial bundle ≤ 350 KB gzipped on the Reviewer route (SC-013o).
- Core Web Vitals: LCP ≤ 2.5 s, CLS ≤ 0.1, FID ≤ 100 ms (SC-013o).

**Constraints**:
- Server-side PII masking before payload reaches Reviewer (FR-047c..f).
- Audit Log append-only, 5-year tiered retention (FR-050a..b).
- WCAG 2.1 Level AA mandatory; axe-core critical/serious blocks merge (FR-047a/b, SC-013g).
- All Markdown English-only (Constitution XI).
- Design system tokens only — no ad-hoc styling (Constitution VI-B).

**Scale/Scope**:
- ~250 Pending sessions per Reviewer at peak; pagination at page size 25 (FR-009b).
- Up to ~50 clinical tags + ~20 review tags in Tag Center.
- 3 supported locales today (uk / ru / en), dynamically extensible (FR-009c).
- 8 user stories, 93 functional requirements, 22 edge cases, 31 success criteria from `spec.md`.

## Constitution Check

Performed before Phase 0 research and re-evaluated after Phase 1 design.

| Principle | Status | Note |
|---|---|---|
| I. Spec-First Development | PASS | Spec exists and was clarified across 5 rounds; this plan extends it. No code change yet. |
| II. Multi-Repository Orchestration | PASS | Targets `chat-types`, `chat-backend`, `workbench-frontend`, `chat-frontend-common`, `chat-ui`, plus the in-repo `regression-suite/`. Cross-repo dependencies documented below. |
| III. Test-Aligned Development | PASS | Vitest in chat-backend + workbench-frontend (positive + negative for every user-facing scenario), Playwright in chat-ui, YAML regression-suite for AI runs, axe-core gating. |
| IV. Branch and Integration Discipline | PASS | Branch `058-reviewer-review-queue` cut from `main`; per-PR dev deploy + green CI gating planned; merging to `develop` requires owner approval; no AI-driven merge. |
| V. Privacy and Security First | PASS | PII detector mandatory + no Reviewer-side reveal (FR-047c..f); GDPR retention via 5-year tiered Audit Log (FR-050a/b); 2FA per environment (FR-004). |
| VI. Accessibility and Internationalization | PASS | WCAG 2.1 AA gate via axe-core (FR-047a/b); i18n across uk/ru/en with dynamic extension; chat-language-aware tag selectors (FR-021a, FR-024c). |
| VI-B. Design System Compliance | PASS | Mandatory canonical Toggle reuse (FR-031d); design-system tokens consumed via existing `chat-frontend-common`; no ad-hoc styling. |
| VII. Split-Repository First | PASS | All work targets the split repos; chat-client untouched. |
| VIII. GCP CLI Infrastructure Management | PASS | Cloud Run Job for Audit Log retention added via Terraform in `chat-infra`; `gcloud` commands documented at deploy time. |
| IX. Responsive UX and PWA Compatibility | PASS | Three-tier responsive plan (FR-046f); PWA shell reuse (FR-046g); Lighthouse PWA score ≥ 90 (SC-013m). |
| X. Jira Traceability and Project Tracking | PLANNED | Epic and Stories will be created via `/speckit.taskstoissues` after `tasks.md` exists; the spec will record the MTB key. |
| XI. Documentation Standards | PASS | All artefacts in English only; user-manual / release-notes updates scheduled in the polish phase. |
| XIII. CX Agent Management | N/A | This feature does not touch the Dialogflow CX agent. |

No constitution gate fails. No deviations require entry in Complexity Tracking.

## Project Structure

### Documentation (this feature)

```
specs/058-reviewer-review-queue/
├── spec.md                  # Feature specification (Phase /speckit.specify + /speckit.clarify x5)
├── research.md              # Phase 0 (this iteration)
├── data-model.md            # Phase 1 (this iteration)
├── contracts/
│   └── openapi.yaml         # Phase 1 HTTP contract
├── quickstart.md            # Phase 1 manual + automated validation guide
├── plan.md                  # This file
├── tasks.md                 # Phase 2 (/speckit.tasks output)
└── checklists/
    ├── requirements.md      # /speckit.specify quality checklist
    ├── security.md          # /speckit.checklist security
    ├── accessibility.md     # /speckit.checklist accessibility
    ├── privacy.md           # /speckit.checklist privacy
    ├── performance.md       # /speckit.checklist performance
    └── i18n.md              # /speckit.checklist i18n
```

### Source Code (across repositories)

```
chat-types/                                  # Shared TS types (consumed by client + server)
└── src/reviewer-review-queue/
    ├── session.ts                           # ChatSession, SessionCard, SessionDetail
    ├── review.ts                            # Review, Rating, MessageTagComment
    ├── tags.ts                              # ClinicalTagDef, ClinicalTagAttachment, ReviewTagDef, ReviewTagAttachment
    ├── red-flag.ts
    ├── change-request.ts
    ├── notification.ts
    ├── reports.ts
    ├── audit.ts                             # extension fields legalHold + tier
    ├── admin-settings.ts                    # verbose_autosave_failures key
    └── index.ts

chat-backend/                                # Express API
├── src/
│   ├── modules/reviewer-queue/
│   │   ├── routes/                          # endpoint handlers (matches contracts/openapi.yaml)
│   │   ├── services/                        # queue service, review service, autosave service, etc.
│   │   ├── middleware/
│   │   │   ├── pii-detector.ts              # PII middleware over Reviewer transcript reads (FR-047c)
│   │   │   ├── space-scope.ts               # FR-010 RBAC narrowing
│   │   │   └── audit-emitter.ts             # FR-049 emissions
│   │   ├── repos/                           # Knex query layer
│   │   └── recompute-completion.ts          # FR-008b on settings change
│   ├── workers/
│   │   ├── pii-presidio.py                  # out-of-process Python worker
│   │   └── audit-archive-job.ts             # FR-050a/b retention job (Cloud Run Job)
│   └── migrations/2026_NN_reviewer_review_queue.ts
└── tests/
    ├── unit/
    └── integration/

workbench-frontend/                          # React app (Reviewer surface lives here)
├── src/
│   └── modules/reviewer-queue/
│       ├── pages/
│       │   ├── ReviewQueuePage.tsx          # /workbench/review
│       │   ├── ReviewSessionPage.tsx        # /workbench/review/session/:id
│       │   └── ReviewerReportsPage.tsx      # /workbench/review/reports (Reviewer-scoped)
│       ├── components/
│       │   ├── QueueTabs.tsx
│       │   ├── ChipFilterBar.tsx            # FR-009a
│       │   ├── LanguageFilter.tsx           # FR-009c
│       │   ├── Paginator.tsx                # FR-009b
│       │   ├── SessionCard.tsx              # FR-008
│       │   ├── ScoreSelector.tsx            # FR-011, FR-012
│       │   ├── CriterionSelector.tsx        # FR-014
│       │   ├── ValidatedAnswerField.tsx     # FR-015
│       │   ├── ClinicalTagSelector.tsx      # FR-020, FR-021a
│       │   ├── ReviewTagSelector.tsx        # FR-024a, FR-024c
│       │   ├── TagChip.tsx                  # FR-024d, FR-021b
│       │   ├── RedFlagButton.tsx            # FR-025
│       │   ├── RedFlagModal.tsx             # FR-026
│       │   ├── MessageTagComment.tsx        # FR-022
│       │   ├── SubmitButton.tsx             # FR-018, FR-018a (countdown UX)
│       │   ├── OfflineBanner.tsx            # FR-031b
│       │   ├── NotificationBanner.tsx       # FR-039a
│       │   ├── NotificationBellList.tsx     # FR-039a
│       │   ├── EmptyState.tsx               # FR-046c
│       │   ├── LoadingSkeleton.tsx          # FR-046b
│       │   ├── ErrorState.tsx               # FR-046d
│       │   ├── BrowserNotSupportedNotice.tsx # FR-046i
│       │   └── MobileSwitchPrompt.tsx       # FR-046f
│       ├── hooks/
│       │   ├── useReviewerQueue.ts          # paged + filtered queue fetch
│       │   ├── useReviewerSession.ts        # session detail fetch + state
│       │   ├── useReviewQueueRefresh.ts     # FR-008a refresh-on-action + 60s polling
│       │   ├── useAutosave.ts               # FR-031, FR-031a (blur + beforeunload)
│       │   ├── useOfflineMode.ts            # FR-031b
│       │   ├── useFocusFetch.ts             # FR-034a multi-tab reconciliation
│       │   ├── useSubmitGate.ts             # FR-018 enablement
│       │   └── useReviewerNotifications.ts  # FR-039a
│       ├── services/
│       │   ├── reviewerApi.ts               # axios client wired to chat-backend
│       │   ├── piiSafeRender.ts             # render helper for [REDACTED:type]
│       │   └── offlineQueue.ts              # IndexedDB wrapper around `idb`
│       ├── i18n/
│       │   ├── en.json
│       │   ├── uk.json
│       │   └── ru.json
│       └── index.ts
└── tests/
    ├── unit/
    └── integration/

chat-frontend-common/                        # Design-system component library
└── src/
    └── components/
        └── Toggle.tsx                       # canonical Toggle (FR-031d) — verify or introduce

chat-ui/                                     # Playwright spec mirror (human/CI-runnable)
└── tests/reviewer-review-queue/
    ├── happy-path.spec.ts
    ├── isolation.spec.ts
    ├── multi-tab.spec.ts
    ├── pii.spec.ts
    ├── a11y.spec.ts
    ├── responsive.spec.ts
    └── perf.spec.ts

regression-suite/                            # AI-runnable Playwright MCP YAML harness
├── 19-reviewer-review-queue.yaml            # NEW module — RQ-001..RQ-NNN test cases
└── _config.yaml                             # add module to execution_order after 04-review-session

chat-infra/                                  # Cloud infra
└── terraform/
    └── modules/audit-log-archive/           # Cloud Run Job for FR-050a/b
```

**Structure Decision**: Multi-repo split per Constitution VII. Frontend lives in `workbench-frontend`; backend in `chat-backend`; shared types in `chat-types`; design-system components in `chat-frontend-common`; AI-runnable E2E YAML in this repo's `regression-suite/`; CI-runnable Playwright spec mirror in `chat-ui`. Cloud infra changes (Audit Log archive job) in `chat-infra`.

## Cross-Repository Coordination

Phase order — strict dependency chain:

1. **chat-types**: Phase 1 lands the new entity types and merges to `develop`; tagged minor release.
2. **chat-frontend-common**: if the canonical `Toggle` is missing, introduce it; tagged minor release.
3. **chat-backend**: implement migration + endpoints + middleware + audit emissions + retention job; consume new `chat-types`; merge to `develop` behind feature flag (default OFF in dev).
4. **workbench-frontend**: implement Reviewer modules; consume new `chat-types` + new common Toggle; merge to `develop` behind feature flag (default OFF in dev).
5. **regression-suite**: add `19-reviewer-review-queue.yaml`; update `_config.yaml`. Run smoke green ≥ 3 times consecutively.
6. **chat-ui**: add Playwright spec mirror; CI runs in `chat-ui` pipeline.
7. **chat-infra**: provision the Audit Log archive Cloud Run Job (post-MVP — can ship immediately after backend lands).
8. **Polish phase**: flip the feature flag ON in dev; run `mhg.regression module:19-reviewer-review-queue level:full`; capture Lighthouse + axe artefacts; open dev validation report; await owner approval to merge feature branches in each repo to their `develop`.

Each repo gets its own branch named `058-reviewer-review-queue` per Constitution VII.

## Risk and Mitigation Summary

| Risk | Mitigation |
|---|---|
| PII detector misses a known pattern | Server-side audit-only sentinel scans + tracked-bug channel (FR-047f). Unit tests with the canonical PII corpus. |
| Audit Log API outage continues blocking NF-03 | Treated as a tracked dependency in `research.md`; fix scoped as a separate bugfix feature; the Reviewer NF-03 tests check that emissions are dispatched, not necessarily that they are queryable on day one. |
| Multi-tab reconciliation race causes data loss | Conflict indicator + last-blur-wins is verifiable end-to-end (SC-013k); rejected hard-block UX explicitly. |
| Bundle budget regression (350 KB) | `web-vitals` reporting in production (sampled at 10%) + Lighthouse CI gate per branch deploy (SC-013o). |
| 5-year audit retention storage cost | Cold-tier GCS Parquet keeps cost flat; partition pruning reduces hot-tier index size. |
| Tag soft-delete propagation lag | 60-second refresh (FR-008a) caps user-visible staleness. |
| Cross-Reviewer leak via direct API call | Dedicated SC-013a + SC-004 tests with two accounts; backend RBAC enforced at the route layer. |

## Complexity Tracking

No constitution-check violations. No entries required.

---

**Phase 0 status**: COMPLETE — see `research.md`.
**Phase 1 status**: COMPLETE — see `data-model.md`, `contracts/openapi.yaml`, `quickstart.md`.
**Next command**: `/speckit.tasks` to generate the dependency-ordered `tasks.md`.

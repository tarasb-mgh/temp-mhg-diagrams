# Implementation Plan: Non-Therapy Technical Backlog

**Branch**: `030-non-therapy-backlog` | **Date**: 2026-03-15 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/030-non-therapy-backlog/spec.md`

---

## Summary

Implement 38 technical, security, and compliance requirements across 7 engineering domains that are unblocked by therapy team sign-off. These requirements form the infrastructure foundations for Phases 2–4 of the MHG roadmap: a GDPR-compliant pseudonymous identity layer, cohort onboarding mechanics, clinical assessment data schema, AI safety filters, analytics RBAC, annotation tooling, and DevOps scale validation. All work targets the split repositories (`chat-backend`, `workbench-frontend`, `chat-infra`, `chat-types`, `chat-ui`). The `chat-client` monorepo is not touched.

---

## Technical Context

**Language/Version**: TypeScript / Node.js (chat-backend, workbench-frontend); PostgreSQL 15 (Cloud SQL); Go (chat-infra scripts where applicable)
**Primary Dependencies**: Express.js (chat-backend API); React + Vite (workbench-frontend); Cloud Tasks (assessment scheduler); GCP Pub/Sub (notification pipeline); Redis (session cache); Vitest (unit tests); Playwright (E2E tests in chat-ui)
**Storage**: Cloud SQL PostgreSQL (primary); Redis (session-level cache); Cloud Logging (audit log retention)
**Testing**: Vitest (unit/integration in chat-backend); Vitest + React Testing Library (workbench-frontend); Playwright (E2E in chat-ui)
**Target Platform**: GCP Cloud Run (backend services); GCS + GCLB (frontend); Cloud SQL (data)
**Project Type**: Multi-service web application (backend API + workbench SPA + infra scripts)
**Performance Goals**: p95 score_aggregation_api < 200ms; p95 chat API < 500ms; p95 workbench < 1,000ms; error rate < 0.1% at 1,000 concurrent users; autoscale to 100 instances in < 30s
**Constraints**: All tables storing health data must be PII-free; append-only enforcement via DB triggers; GDPR erasure cascade must complete within 24h in prod; AI context injection must fail-open within 200ms; annotation blinding enforced at data layer
**Scale/Scope**: 1,000 concurrent users; 12-month data growth projection for DB sizing; 38 requirements across 7 domains; ~7 Jira Epics; spans 5 target repositories

---

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Spec-First Development | ✅ PASS | spec.md complete and checklist passed |
| II. Multi-Repository Orchestration | ✅ PASS | Cross-repo dependency table documented below |
| III. Test-Aligned Development | ✅ PASS | Vitest (backend/frontend), Playwright (E2E) — existing patterns maintained |
| IV. Branch and Integration Discipline | ✅ PASS | Feature branch `030-non-therapy-backlog` created; PRs to `develop` only |
| V. Privacy and Security First | ✅ PASS | Core concern of this spec — FR-001–007 address GDPR/pseudonymisation |
| VI. Accessibility and Internationalization | ⚠️ PARTIAL | Annotation interface (US-6) and audit log dashboard (US-5) must maintain WCAG AA and i18n for any new workbench UI components |
| VII. Split-Repository First | ✅ PASS | All changes target split repos only; chat-client not touched |
| VIII. GCP CLI Infrastructure Management | ✅ PASS | Cloud SQL instance creation, IAM binding, Cloud Tasks queue, autoscaling config — all scripted via gcloud in chat-infra |
| IX. Responsive UX and PWA Compatibility | ⚠️ PARTIAL | Applies to workbench UI additions (annotation interface, audit log dashboard, RBAC enforcement UI) — responsive behaviour required |
| X. Jira Traceability | ✅ PASS | `/speckit.taskstoissues` will create 7 Epics + Stories post-tasks |
| XI. Documentation Standards | ✅ PASS | quickstart.md + contracts/ generated in Phase 1 |
| XII. Release Engineering | ✅ PASS | No release branch or main merge — all work targets develop |

**Violations requiring justification**: None.

---

## Cross-Repository Dependency Map

| Domain | Primary Repo | Secondary Repos | Execution Order |
|--------|-------------|-----------------|-----------------|
| Security & Identity (FR-001–007) | `chat-backend` | `chat-infra` (Cloud SQL instance, IAM, Secret Manager) | `chat-infra` first (infra provisioning), then `chat-backend` (schema migration, middleware) |
| Consent & Cohort Onboarding (FR-008–014) | `chat-backend` | `workbench-frontend` (cohort admin UI); `chat-types` (ConsentRecord, Cohort types) | `chat-types` first, then `chat-backend`, then `workbench-frontend` |
| Clinical Assessment Data Schema (FR-015–021) | `chat-backend` | `workbench-frontend` (trajectory views); `chat-types` (Assessment types) | `chat-types` → `chat-backend` → `workbench-frontend` |
| AI Safety & Filtering (FR-022–024) | `chat-backend` | `chat-types` (FilterEvent type) | `chat-types` → `chat-backend` |
| Analytics & RBAC (FR-025–029) | `chat-backend` | `workbench-frontend` (audit log dashboard, CSV export); `chat-types` (AnalyticsEvent types) | `chat-types` → `chat-backend` → `workbench-frontend` |
| Annotation & ML (FR-030–035) | `chat-backend` | `workbench-frontend` (annotation interface, kappa display); `chat-types` (Annotation types) | `chat-types` → `chat-backend` → `workbench-frontend` |
| DevOps & Scale (FR-036–038) | `chat-infra` | `chat-ui` (load test scripts) | `chat-infra` (autoscaling, DB config), `chat-ui` (load tests) — parallel |

---

## Project Structure

### Documentation (this feature)

```text
specs/030-non-therapy-backlog/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   ├── identity-api.yaml
│   ├── assessment-api.yaml
│   ├── analytics-api.yaml
│   └── annotation-api.yaml
└── tasks.md             # Phase 2 output (/speckit.tasks — NOT created here)
```

### Source Code (multi-repository layout)

```text
chat-backend/
├── src/
│   ├── auth/
│   │   ├── identity-map.service.ts          # FR-002: separate identity store access
│   │   ├── pii-rejection.middleware.ts       # FR-004: PII-rejection on all inputs
│   │   ├── consent.service.ts               # FR-008–010: consent versioning
│   │   └── guest-otp-upgrade.service.ts     # FR-014: guest→OTP merge
│   ├── cohort/
│   │   ├── invite-code.service.ts           # FR-011–013: code generation, expiry
│   │   └── cohort-guard.middleware.ts       # FR-012: k>=25 analytics guard
│   ├── assessment/
│   │   ├── assessment-sessions.model.ts     # FR-015: append-only tables
│   │   ├── assessment-scheduler.service.ts  # FR-019: Cloud Tasks adaptive scheduler
│   │   ├── score-trajectories.service.ts    # FR-016: materialised view queries
│   │   └── risk-threshold.service.ts        # FR-020: configurable thresholds
│   ├── ai-filter/
│   │   ├── post-generation-filter.ts        # FR-022: response filter
│   │   └── score-context-injector.ts        # FR-023–024: band injection + cache
│   ├── analytics/
│   │   ├── event-instrumentation.service.ts # FR-025: 8-event logging
│   │   ├── anonymity-guard.middleware.ts    # FR-026: k=10 suppression
│   │   ├── rbac.middleware.ts               # FR-027: API-layer 403 enforcement
│   │   └── gdpr-audit.service.ts            # FR-028–029: audit log + CSV export
│   ├── annotation/
│   │   ├── annotation-blinding.service.ts   # FR-030: blinding enforcement
│   │   ├── transcript-sampling.service.ts   # FR-032: stratified sampling
│   │   ├── kappa.service.ts                 # FR-033: Cohen's/Fleiss' kappa
│   │   └── model-metrics.service.ts         # FR-034: sensitivity/specificity/F-beta
│   └── erasure/
│       └── erasure-cascade.service.ts       # FR-003: GDPR right-to-erasure
│
├── migrations/
│   ├── 030-001-pseudonymous-users.sql       # FR-001: users table redesign
│   ├── 030-002-consent-records.sql          # FR-008: consent_records table
│   ├── 030-003-cohorts.sql                  # FR-011: cohorts + cohort_memberships
│   ├── 030-004-assessment-schema.sql        # FR-015: assessment_sessions/items/scores
│   ├── 030-005-score-trajectories.sql       # FR-016: materialised view + refresh
│   ├── 030-006-assessment-schedule.sql      # FR-019: assessment_schedule table
│   ├── 030-007-risk-thresholds.sql          # FR-020: risk_thresholds config table
│   ├── 030-008-supervisor-cohorts.sql       # FR-027: supervisor_cohort_assignments
│   └── 030-009-annotations.sql             # FR-031: annotations table
│
└── tests/
    ├── integration/
    │   ├── erasure-cascade.test.ts
    │   ├── pii-rejection.test.ts
    │   ├── consent-enforcement.test.ts
    │   ├── cohort-guard.test.ts
    │   └── assessment-append-only.test.ts
    └── unit/
        ├── kappa.test.ts
        ├── model-metrics.test.ts
        ├── ai-filter.test.ts
        └── score-trajectories.test.ts

chat-types/
└── src/
    ├── identity.types.ts          # ConsentRecord, IdentityMapping
    ├── cohort.types.ts            # Cohort, CohortMembership, InviteCode
    ├── assessment.types.ts        # AssessmentSession, AssessmentItem, AssessmentScore, ScoreTrajectory
    ├── analytics.types.ts         # AnalyticsEvent (8 types), GDPRAuditEntry
    ├── annotation.types.ts        # Annotation, SamplingRun, KappaResult, ModelMetrics
    └── ai-filter.types.ts         # FilterEvent, ScoreContextCache

workbench-frontend/
└── src/
    ├── features/
    │   ├── cohort-management/
    │   │   ├── InviteCodeManager.tsx        # FR-011–013: code creation/deactivation UI
    │   │   └── CohortAnalyticsGuard.tsx     # FR-012: cohort size warning UI
    │   ├── assessment-trajectories/
    │   │   └── ScoreTrajectoryView.tsx      # FR-016: longitudinal trajectory display
    │   ├── gdpr-audit/
    │   │   ├── AuditLogDashboard.tsx        # FR-028: GDPR audit log view
    │   │   └── AuditCsvExport.tsx           # FR-029: CSV export button
    │   └── annotation/
    │       ├── AnnotationInterface.tsx      # FR-030: blinded annotation UI
    │       ├── AdjudicationView.tsx         # FR-030: post-submission side-by-side
    │       └── KappaResultPanel.tsx         # FR-033: kappa display + alert indicator

chat-infra/
└── scripts/
    ├── 030-create-identity-map-instance.sh  # FR-002: separate Cloud SQL instance
    ├── 030-iam-identity-map-bindings.sh     # FR-002, FR-005: SA bindings
    ├── 030-cloud-tasks-assessment-queue.sh  # FR-019: Cloud Tasks queue setup
    ├── 030-audit-log-retention.sh           # FR-006: 3-year retention policy
    ├── 030-autoscaling-review.sh            # FR-036: Cloud Run min/max config
    └── 030-cloudsql-pooling-review.sh       # FR-037: DB connection config

chat-ui/
└── tests/
    └── load/
        ├── chat-load-1000.spec.ts           # FR-035: 1000-user load test
        └── workbench-load-1000.spec.ts      # FR-035: workbench load test
```

---

## Phase 0: Research

*All research consolidated in [research.md](./research.md)*

### Research Tasks Dispatched

| # | Question | Outcome |
|---|----------|---------|
| R-01 | Jacobson-Truax RCI formula and PostgreSQL materialised view implementation pattern | Resolved — see research.md |
| R-02 | Cloud Tasks vs Cloud Scheduler for adaptive assessment intervals | Resolved — Cloud Tasks (per-task delay) preferred over Cloud Scheduler (fixed cron) |
| R-03 | PostgreSQL trigger-enforced append-only pattern (prevent UPDATE/DELETE at DB level) | Resolved — see research.md |
| R-04 | F-beta metric with β=4.47 computation (20:1 FN:FP cost asymmetry) | Resolved — F-beta formula confirmed |
| R-05 | Bootstrap confidence interval for Cohen's kappa (1,000-iteration pattern) | Resolved — see research.md |
| R-06 | GCP Cloud SQL separate instance setup with VPC-level service account isolation | Resolved — see research.md |
| R-07 | Server-side regex post-generation filter pattern (TypeScript/Express) | Resolved — see research.md |
| R-08 | FHIR QuestionnaireResponse + Observation schema design for PostgreSQL | Resolved — FHIR-compatible columns, not FHIR server |
| R-09 | k-anonymity suppression pattern for SQL analytics queries | Resolved — HAVING clause guard on all cohort aggregates |
| R-10 | QR code generation at 300 DPI (Node.js library selection) | Resolved — `qrcode` npm package (MIT license) |

---

## Phase 1: Design Artifacts

*See [data-model.md](./data-model.md) and [contracts/](./contracts/)*

### Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Identity map storage | Separate Cloud SQL instance (same VPC, distinct SA) | Stronger isolation than schema-level; auth service SA only; mirrors Wysa/industry gold standard |
| Append-only enforcement | PostgreSQL `BEFORE UPDATE OR DELETE` trigger raising exception | Application-level enforcement alone is insufficient; DB trigger survives code changes |
| Materialised view refresh | pg_cron 15-minute schedule | Simpler than Cloud Tasks for scheduled DB jobs; on-demand refresh available via stored procedure |
| Assessment scheduler | Cloud Tasks (deferred tasks, per-user delay) | Adaptive per-user intervals not possible with cron-based Cloud Scheduler |
| AI filter | Server-side synchronous filter before response delivery | Client-side filtering bypassable; async post-delivery logging insufficient for safety |
| Score context cache | Redis session-level cache (existing Redis instance) | Minimise latency; invalidate on assessment completion event; existing infra reused |
| Kappa computation | Server-side TypeScript (no external ML service) | κ computation is deterministic arithmetic; no ML framework needed; keeps backend self-contained |
| FHIR design | Schema-compatible columns (not FHIR server) | FHIR export is future phase; schema design enables it without requiring a FHIR server now |
| QR code generation | `qrcode` npm package | MIT license; 300 DPI via `scale` option; no external service dependency |
| k=10 anonymity guard | SQL `HAVING COUNT(DISTINCT pseudonymous_user_id) >= 10` on all aggregate queries | Enforced at data layer; reusable as a shared query helper function |

---

## Inter-Repo Execution Sequence

```
Phase A — Types First (chat-types)
  └─ Add: identity.types.ts, cohort.types.ts, assessment.types.ts,
          analytics.types.ts, annotation.types.ts, ai-filter.types.ts
  └─ Publish new chat-types version; consumers update dependency

Phase B — Infrastructure (chat-infra) [parallel with Phase A]
  └─ 030-create-identity-map-instance.sh
  └─ 030-iam-identity-map-bindings.sh
  └─ 030-cloud-tasks-assessment-queue.sh
  └─ 030-audit-log-retention.sh
  └─ 030-autoscaling-review.sh
  └─ 030-cloudsql-pooling-review.sh

Phase C — Backend Core (chat-backend) [requires Phase A + B]
  └─ Run migrations 030-001 through 030-009 (in order)
  └─ Implement services: auth, cohort, assessment, ai-filter, analytics, annotation, erasure
  └─ Integration tests: erasure, PII-rejection, consent, cohort-guard, append-only

Phase D — Workbench Frontend (workbench-frontend) [requires Phase C API contracts]
  └─ CohortManagement UI, ScoreTrajectoryView, GDPRAuditDashboard, AnnotationInterface

Phase E — Load Tests (chat-ui) [requires Phase C deployed to dev]
  └─ 1,000-user load tests: chat + workbench

Phase F — Validation (chat-ui E2E) [requires Phases D + E green]
  └─ Playwright E2E: cohort join flow, consent enforcement, annotation blinding
```

---

## Critical Dependencies

- **Cloud SQL `user_identity_map` instance** must be provisioned (chat-infra Phase B) before any backend migration runs that references the identity map.
- **chat-types version** must be published and consumers updated before any backend service compilation.
- **Redis** (existing) — used for score context cache (FR-024). Existing instance sufficient; no new provisioning required.
- **GCP Pub/Sub topic** for flag notifications (FR-021 resolution workflow) — verify existing topic from MTB-554 (Production Resilience) or create in chat-infra.
- **Cloud Tasks queue** for assessment scheduler (FR-019) — new queue in existing GCP project; scripted in chat-infra.

---

## Security Review Checklist

Required per Constitution Principle V before any Phase C task ships to develop:

- [ ] `user_identity_map` instance SA has only `cloudsql.instances.connect` + `cloudsql.client` roles — no broader DB access
- [ ] PII-rejection middleware regex tested for false positive rate < 1% on representative non-PII inputs
- [ ] Consent enforcement integration test covers all three API endpoints (session, intake, assessment)
- [ ] Erasure cascade integration test covers orphaned in-progress assessment sessions
- [ ] AI response filter regression test suite covers ≥50 test cases per prohibited pattern category
- [ ] k=10 suppression unit test covers all analytics query paths (not just the dashboard endpoint)
- [ ] Annotation blinding test confirms data-layer enforcement (direct DB query, not UI test)

---

## Accessibility & i18n Requirements

Per Constitution Principle VI — applies to all workbench UI additions:

- All new workbench components must support `uk`, `en`, `ru` translations via existing i18n infrastructure
- Annotation interface must be keyboard-navigable (tab order, focus indicators)
- Audit log dashboard must maintain WCAG AA colour contrast
- Cohort management UI must show accessible error states for "cohort too small" and "expired code" messages

---

## Phase 2 Planning

*Phase 2 (tasks.md) is produced by `/speckit.tasks` — not generated by this command.*

Estimated task count: ~85–100 tasks across 7 user stories. Recommended sprint grouping:
- **Sprint 1**: US-1 (Privacy & Identity) + US-2 Phase A–B (infra + types) — P1 gate
- **Sprint 2**: US-2 backend + US-3 (Assessment Schema) — P1 completion
- **Sprint 3**: US-4 (AI Safety) + US-5 (Analytics & RBAC) — P2
- **Sprint 4**: US-6 (Annotation & ML) + US-7 (DevOps & Scale) — P3

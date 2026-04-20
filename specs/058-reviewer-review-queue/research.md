# Research: Reviewer Review Queue — Full Implementation and E2E Validation

**Feature**: `058-reviewer-review-queue`
**Date**: 2026-04-16
**Phase**: Phase 0 — Outline & Research

This document records the technical decisions taken during Phase 0, with rationale and rejected alternatives. Inputs: `spec.md`, `checklists/*.md`, MHG constitution v3.15.0, current dev environment audit (2026-04-16), prior MHG features 035 / 036 / 042 / 050 / 054 / 055.

---

## Decision 1 — Frontend stack and split-repo target

- **Decision**: Implement the entire Reviewer surface in the existing `workbench-frontend` React + Vite + TypeScript codebase. Reuse the existing routing, shell, sidebar, header, locale switcher, Space dropdown, and Tag Center pages; extend them rather than fork.
- **Rationale**:
  - The dev audit (2026-04-16) confirmed the full Workbench shell, sidebar, header, Space dropdown, locale switcher, Settings page, Tag Center (with Clinical Tags and Review Tags tabs), Review Queue, Review Settings, Reports, and Audit Log routes already exist in `workbench-frontend`.
  - Constitution Principle VII (Split-Repository First) prohibits new feature work in the legacy `chat-client` monorepo.
  - Constitution Principle II (Multi-Repository Orchestration) lists `workbench-frontend` as a primary target repo.
  - Constitution Principle VI-B (Design System Compliance) requires reuse of `chat-frontend-common/tailwind-preset.js` and `workbench-frontend/src/index.css` tokens.
- **Alternatives considered**:
  - Standalone micro-frontend — rejected (introduces new bundle, breaks single-shell UX).
  - Implementation in `chat-client` monorepo — explicitly forbidden by Constitution VII.

## Decision 2 — Backend stack and split-repo target

- **Decision**: Extend `chat-backend` (Express.js) for every Reviewer-facing API endpoint introduced by this feature: queue listing with filters and pagination, session detail, autosave, submit, change-request, notifications, language-source endpoint, ping, and the soft-delete-aware tag list.
- **Rationale**:
  - `chat-backend` already serves the `/api/*` surface for the Workbench (CLAUDE.md).
  - Constitution Principle VIII (GCP CLI Infrastructure Management) directs API subdomain routing under `/api/*` canonical paths.
  - Audit Log endpoint already exists at `chat-backend` (currently broken — tracked separately) and the new audit emissions need to call into the same write path.
- **Alternatives considered**:
  - Spinning up a new microservice for review operations — rejected (premature decomposition; dev velocity loss).
  - Implementing in `delivery-workbench-backend` — wrong scope (delivery workbench is a separate single-environment subsystem).

## Decision 3 — Shared types

- **Decision**: All wire types for the Reviewer surface (`Session`, `Rating`, `ClinicalTag`, `ReviewTag`, `RedFlag`, `MessageTagComment`, `Review`, `ChangeRequest`, `Notification`, `AuditLogEntry`, `Space`, etc.) MUST be defined in `chat-types` and consumed by both `chat-backend` and `workbench-frontend`.
- **Rationale**:
  - Constitution Principle VII: "Shared type changes MUST go through `chat-types` first".
  - Same constitutional clause requires consumers to update their dependency.
  - Eliminates drift between client and server payload shape.
- **Alternatives considered**:
  - Inline types in each repo — rejected (drift risk).

## Decision 4 — E2E test home

- **Decision**: New regression module `regression-suite/19-reviewer-review-queue.yaml` in `client-spec` (this repo) drives the entire Reviewer happy path, isolation tests, edge cases, accessibility, and PII checks against `https://workbench.dev.mentalhelp.chat`. Inserted into `_config.yaml` `execution_order` after `04-review-session`. Uses `e2e-researcher@test.local` as the canonical Reviewer fixture (already declared in `_config.yaml`).
- **Rationale**:
  - The regression-suite is the AI-agent-executable Playwright MCP harness; constitution Principle III names `chat-ui` Playwright as the canonical E2E system but the YAML regression-suite is the harness used in this repo for AI-driven runs.
  - `_config.yaml` already lists `researcher` with `otp_source: browser_console`, matching FR-004's dev-side OTP flow.
- **Alternatives considered**:
  - Place E2E in `chat-ui` Playwright project — possible but loses the AI-runnable YAML harness; will additionally add Playwright-spec equivalents in `chat-ui` for human/CI-driven runs (mirrored, not duplicated assertions).

## Decision 5 — Client storage for autosave (offline mode + multi-tab)

- **Decision**: Use the browser-native `IndexedDB` API with the `idb` (`jakearchibald/idb`) wrapper for offline-queue persistence (FR-031b). Use `BroadcastChannel` API for cross-tab signal exchange of focus events when feasible; fall back to `storage` event polling on browsers without `BroadcastChannel`.
- **Rationale**:
  - `IndexedDB` is the only durable client store with sufficient quota for a queue of unsynced writes; `localStorage` quota is too small and is synchronous.
  - `BroadcastChannel` covers all officially-supported browsers per FR-046h (evergreen Chromium, latest Firefox, latest Safari ≥ 15.4 supports it).
  - `idb` is widely audited and 7 KB gzipped — fits the 350 KB bundle budget (SC-013o).
- **Alternatives considered**:
  - Service worker as the sync owner — rejected (over-engineered for a 2-tab editor; the sync logic stays in the page so it can update DOM directly; the SW remains the cache shell only per FR-046g).
  - SharedWorker — rejected (limited Safari support, no clear gain).

## Decision 6 — Server-side PII detection

- **Decision**: Implement the PII detector in `chat-backend` as a middleware over `GET /api/sessions/:id` and `GET /api/sessions/:id/messages` responses. Combine deterministic regexes (emails, phones, dates, IDs) with a lightweight NER pipeline using `presidio-analyzer` (Python) executed as an out-of-process worker, communicated via gRPC or a local HTTP call. Replacements use the canonical `[REDACTED:type]` placeholder per FR-047c.
- **Rationale**:
  - FR-047c mandates server-side detection BEFORE payload reaches client; FR-047d prohibits any reveal path on the Reviewer surface.
  - Presidio is Apache-2.0, supports custom recogniser definition, and covers PII types listed in FR-047c.
  - Out-of-process Python worker isolates the NER memory footprint from the Express event loop (Node ↔ Python via gRPC is a documented workbench pattern).
- **Alternatives considered**:
  - Pure-regex masking — rejected (NER is needed for names embedded in arbitrary text — see clinical-context risk in `privacy.md` CHK001).
  - Client-side masking — rejected (violates FR-047c; PII would briefly traverse the wire).
  - Microsoft Azure / AWS Comprehend Medical — rejected for cost and data-residency reasons.

## Decision 7 — Review Tags + Clinical Tags constructor reuse

- **Decision**: Extend the existing Tag Center component (per the parallel feature dependency) so that the language-group control and the description editor are a single canonical component reused between Clinical Tag and Review Tag administration. The Reviewer-facing tag chip + tooltip rendering is a single React component used in three contexts (selector, transcript, session card).
- **Rationale**: FR-024e and the Q2-Round-3 clarification mandate component reuse; design-system constitution VI-B rejects parallel implementations.
- **Alternatives considered**: Two parallel constructors — rejected.

## Decision 8 — Pagination model

- **Decision**: Server-side pagination, page size 25, cursor-or-offset based — choose offset-based for the MVP because the list is small (≤ 250 typical) and offset is simpler to test (FR-009b, SC-012).
- **Rationale**: Offset matches the explicit "Prev / Next + numbered pages" requirement; cursor semantics would force an opaque token model and mismatch the numbered-pages UI.
- **Alternatives considered**:
  - Cursor-based — rejected as premature for the expected scale.
  - Infinite scroll — explicitly rejected in clarification Round 2 Q1.

## Decision 9 — X / Y counter freshness

- **Decision**: Refresh-on-action triggers + 60-second `setInterval` polling (FR-008a) implemented inside a single React hook `useReviewQueueRefresh` that owns visibility / focus event listeners and the timer. No WebSocket / SSE.
- **Rationale**: Avoids new push infrastructure; matches Round-3 Q5 clarification; backend can simply expose the same query endpoint.
- **Alternatives considered**: WebSocket / SSE — out of scope.

## Decision 10 — Notification surface

- **Decision**: Single `useReviewerNotifications` hook backed by `GET /api/notifications/unread` poll on focus + 60 s; renders the persistent banner (top of page) + bell-icon list. Three category event-types (`change_request.decision`, `red_flag.supervisor_followup`, `space.membership_change`) per FR-039b.
- **Rationale**: Single store, two surfaces (banner + bell list), explicit dismiss → POST `/api/notifications/:id/read` → emits `notification.read` audit entry.
- **Alternatives considered**: WebSocket push — out of scope; same rationale as Decision 9.

## Decision 11 — Required reviewer count change propagation

- **Decision**: Backend computes session completion threshold at query time using the CURRENT Review Settings `required_count`. No cohort snapshot. Auto-completion on decrease handled by a backend `recomputeCompletion` hook fired on settings change (FR-008b, EC-17, EC-18).
- **Rationale**: Matches Round-4 Q4 clarification "forward-only for non-completed sessions"; avoids per-session frozen state.
- **Alternatives considered**: Cohort snapshot — rejected in clarification.

## Decision 12 — Multi-tab reconciliation

- **Decision**: On `visibilitychange` → `visible` and `focus` events, the focused tab fires `GET /api/sessions/:id/state`, captures a local snapshot at the moment of focus return, and runs per-field reconciliation per FR-034a. No backend lock.
- **Rationale**: Matches Round-4 Q5 clarification; backend stays stateless.
- **Alternatives considered**: WebSocket conflict resolution — out of scope; backend pessimistic lock — rejected (poor UX).

## Decision 13 — Toggle component reuse

- **Decision**: Use the existing `<Toggle>` from `chat-frontend-common` if it exists; otherwise introduce one in `chat-frontend-common` and use it for `verbose_autosave_failures` (FR-031c, FR-031d) plus all future toggles. Constitution VI-B compliance.
- **Rationale**: Mandated by FR-031d.
- **Action item**: First check whether `chat-frontend-common` exposes a Toggle — verified at start of implementation; if missing, build it in `chat-frontend-common`, ship in a tagged minor release, and then use it from `workbench-frontend`.

## Decision 14 — Audit Log retention tiers

- **Decision**: Hot tier — primary Postgres table partitioned by month for the most recent 12 months. Warm tier — same table for months 12–36 with a `warm` partition; queries from the Audit Log UI receive a `Cache-Control: no-store` warning header. Cold tier — monthly partition migrated to GCS as compressed Parquet via a Cloud Run Job; restore-on-request endpoint stages a restored partition back into a temporary Postgres table for 24h.
- **Rationale**: FR-050a / FR-050b / SC-013q. Aligns with constitution VIII (gcloud / Terraform-driven infrastructure).
- **Alternatives considered**:
  - Single tier with no archive — violates SC-013q (cold tier requirement).
  - BigQuery for warm/cold — viable but adds an extra storage system; will be revisited if data volume grows beyond Postgres comfort.

## Decision 15 — Browser support

- **Decision**: Playwright projects: `chromium`, `webkit` for E2E; manual smoke + Lighthouse in Firefox latest stable. Browserslist config in `workbench-frontend`: `["last 2 chrome versions", "last 2 edge versions", "last 2 firefox versions", "last 2 safari versions"]`.
- **Rationale**: Matches FR-046h Round-5 Q2 clarification.

## Decision 16 — Performance instrumentation

- **Decision**: Web Vitals collected via `web-vitals` npm package in `workbench-frontend`, posted to a backend `/api/telemetry/web-vitals` endpoint, sampled at 10% in production. Lighthouse CI configured in `chat-ci` to run against `workbench.dev.mentalhelp.chat` per branch deploy and fail when budget regresses (SC-013o).
- **Rationale**: Standard pattern; explicit FR-budget enforcement by CI matches constitution Principle IV's CI gate.

## Decision 17 — i18n strategy

- **Decision**: Reuse the existing `react-i18next` configuration in `workbench-frontend` (verified in dev audit — three locales `uk` / `ru` / `en` already present). Add namespaces:
  - `reviewer.queue` (Pending/Completed labels, chip filters, paginator, X/Y, language filter)
  - `reviewer.session` (criteria labels, score tooltips, validated-answer placeholder, tag/Red Flag UI, multi-tab reconciliation indicators, Submit countdown)
  - `reviewer.reports` (titles, axis labels, empty state)
  - `reviewer.notifications` (banner + bell list strings, dismiss CTA)
  - `reviewer.empty` (illustration alt-text policy + headlines)
  - `reviewer.errors` (browser-not-supported, ping-down banner, network errors)
- **Rationale**: Matches FR-002a + Round-3 Q2 clarification + i18n checklist coverage.

## Decision 18 — Accessibility automation

- **Decision**: Use `@axe-core/playwright` integrated into the Playwright MCP harness step set so each E2E test ends with `await injectAxe(page); await checkA11y(page, null, { axeOptions: { runOnly: ['wcag21a', 'wcag21aa'] }, includedImpacts: ['critical', 'serious'] });`. Critical / serious failures fail the test (FR-047b, SC-013g).
- **Rationale**: Industry standard; integrates cleanly with existing harness.

## Decision 19 — PWA reuse

- **Decision**: Reuse the existing `workbench-pwa` shell (manifest, service worker) — no new manifest. Confirm the shell already declares the Reviewer routes inside `start_url` scope; if it doesn't, raise a one-line fix in `workbench-frontend` as part of this feature (Decision is non-blocking for spec gating).
- **Rationale**: FR-046g + constitution Principle IX.

## Decision 20 — Tests required (per Constitution III)

- **Decision**: Generate at least one positive + one negative unit/integration test per spec acceptance scenario (8 user stories × 4–8 scenarios each) plus E2E coverage in `19-reviewer-review-queue.yaml`. Vitest in `chat-backend` and `workbench-frontend`.
- **Rationale**: Constitution Principle III "Mandatory Test Coverage" subsection: every user-facing scenario in `spec.md` MUST have at least one positive and one negative test.

---

## Open items deferred to plan / implementation

- Anonymisation algorithm for `session_id` and `user_id` (UUID v4 vs ksuid vs hashed-pseudonym) — backend implementation detail, picked during plan validation.
- Telemetry stack choice (OpenTelemetry vs custom POST) — defaulted to custom POST in Decision 16 to avoid new infra; revisit if we have an OTel collector by the time this ships.
- Specific E2E seed strategy for two-Reviewer cross-isolation tests — pre-seed via a backend test endpoint scoped to dev only; concrete pattern documented in `quickstart.md`.

## Feature flag strategy

- **Decision**: Behind `feature.reviewer_review_queue_v2` env-var flag in both `chat-backend` and `workbench-frontend`, default OFF in dev until end-to-end smoke passes, then ON. Final flip-and-cleanup ticket scheduled in the Polish phase.
- **Rationale**: Lets us deploy backend changes ahead of frontend if needed; standard MHG release practice.

---

All `[NEEDS CLARIFICATION]` markers from the original spec template have been resolved through the 5 prior `/speckit.clarify` rounds and Phase-0 decisions above. No outstanding clarifications block Phase 1.

# Research: Review MVP Defect Bundle

**Phase 0 output for `060-review-mvp-fixes`** | **Date**: 2026-04-27

## Purpose

Resolve technical unknowns before Phase 1 design. Most decisions for this defect-fix bundle were resolved during brainstorming (see `docs/superpowers/specs/2026-04-27-review-mvp-defect-bundle-design.md`). This document captures the remaining research items and codifies the decisions.

---

## R-001 — Current state of the queue API broken-session filter

**Decision**: The Review Queue API (`GET /api/review/queue`) currently does NOT filter broken sessions; the DTO returns `is_broken: true` and the frontend renders the badge. Confirmed via the 2026-04-27 dev regression: the In Progress tab on Dev team Space surfaces 2 broken sessions (`CHAT-8611`, `CHAT-EC17`).

**Rationale**: Empirical observation from the regression run. Network capture showed `GET /api/review/queue?...&groupId=ba1ced2d-...&tab=in_progress → 200, 2 results` with broken sessions in the response.

**Implementation implication**: A `WHERE is_broken = false` clause goes into the queue service's count helper and the list helper (single source), with admin-only opt-in via `?include_broken=true` query param. The opt-in is gated by a server-side permission check, not by a UI hide.

**Alternatives considered**:
- Filter only at the frontend (rejected — leaves backend exposing the data, breaks the "single source of truth" principle).
- Soft-delete broken sessions (rejected — they're not deletes; they're operationally valid, just non-actionable for reviewers).

---

## R-002 — Dashboard counter source query divergence

**Decision**: The Dashboard tile's "Pending Review" counter uses a bespoke aggregate query that differs from the queue API's filter. They MUST share a single helper (`reviewQueueService.countBy({ groupId, statuses })`) so they can never drift.

**Rationale**: The 2026-04-27 regression observed Dashboard saying 91, queue Pending tab saying 0 (with a Space filter mismatch — Layer A) AND Dashboard 91 ≠ All-Spaces visible total of 55 (Layer B). Layer A is fixed by propagating the active Space; Layer B is fixed by having both surfaces call the same count helper.

**Implementation implication**: Create `chat-backend/src/services/review-queue.service.ts` exposing `listBy()` and `countBy()` taking the same `WhereParams`. Both `routes/review.queue.ts` and `routes/dashboard.ts` call `countBy()` with consistent params. The Dashboard tile passes `{ groupId: activeSpace, statuses: ['pending'] }` matching the user's active Space and the Pending semantics.

**"Pending Review" semantics**: Pending status only (not Pending + Flagged + In Progress). This matches the Pending tab in the queue, gives users a 1:1 mental model, and avoids changing how the existing Pending tab counts work. (Decision baked in during brainstorming, ratified by user.)

**Alternatives considered**:
- Sum of Pending + Flagged + In Progress (rejected — would change tile semantics from current expected; also not matching any single tab's count).
- Server-computed materialized view (rejected — overkill for this counter; perf is fine with the shared query).

---

## R-003 — Existing broken-session detection logic

**Decision**: The current broken-detection logic exists as a single boolean (`is_broken`) with a hardcoded UI tooltip. Refactor to a typed enum: `BrokenReason: NO_ASSISTANT_REPLIES | EMPTY_TRANSCRIPT | MALFORMED | UNKNOWN`. Each detection criterion writes its matching reason to a new `broken_reason` column.

**Rationale**: The MC-66 bug report shows the tooltip claims "no assistant replies" for sessions that do have assistant replies. Either the detection is buggy or the tooltip is wrong. Audit (Phase 1) will discover which; the typed-reason refactor makes the result data-driven so the UI matches the logic by construction.

**Implementation implication**:
- DB migration `060_broken_reason_column.sql` adds nullable `broken_reason TEXT` (with CHECK constraint enumerating allowed values + NULL).
- `services/broken-detection.service.ts` consolidates the existing detection rules. Each rule writes a unique reason on match.
- Backfill: a one-time UPDATE attempts to infer the reason from existing data. Rows where the reason is ambiguous get `'UNKNOWN'`.
- Session DTO gains `brokenReason?: BrokenReason | null`.

**Alternatives considered**:
- Free-text reason field (rejected — rules out typed UI strings, defeats the purpose).
- Multiple boolean columns (rejected — explosion when more reasons added; harder to query).

---

## R-004 — Team Dashboard membership endpoint divergence

**Decision**: The Team Dashboard membership endpoint currently uses a different data source from the Space combobox (`/api/admin/groups`). Reconcile by having `/api/team-dashboard/membership` call the same `getSpacesForUser(userId)` source.

**Rationale**: The 2026-04-27 regression observed the Space combobox showing 9 Spaces while Team Dashboard says "No active team membership". Two sources, two answers. Single source eliminates the contradiction.

**Implementation implication**:
- New `chat-backend/src/services/team-membership.service.ts` wraps `getSpacesForUser()` and adds the role-gate logic returning `{ spaces: Space[], hasTeamMembership: boolean, missingRole: string | null }`.
- Frontend `TeamDashboard.tsx` consumes the new shape; renders content when `hasTeamMembership && spaces.length > 0`; renders specific empty-state copy referencing `missingRole` when present; renders generic empty-state when `spaces.length === 0`.

**Decision on Owner role gating**: Owner sees Team Dashboard content when the user is a member of ≥1 Space. If a stricter requirement (e.g., a "team-member" role) was originally intended, that's a separate spec story; for this fix, Owner has the broadest visibility role and should see the page.

**Alternatives considered**:
- Make Team Dashboard role-gated to a non-Owner role (rejected — no spec story exists for that; would need product decision).
- Inline the membership check (rejected — replicates the divergence problem in a new place).

---

## R-005 — Backwards-compatibility for legacy session rows

**Decision**: The new `broken_reason` column is nullable. Legacy rows with `is_broken = true` and `broken_reason = NULL` render the fallback `UNKNOWN` tooltip. Rows with `is_broken = NULL` (no flag set at all) treat as not-broken (default false).

**Rationale**: Constraint per spec: "legacy session rows with NULL `is_broken` or NULL `broken_reason` must continue to work". Avoiding a forced backfill keeps the migration fast and risk-free.

**Implementation implication**:
- Migration: `ALTER TABLE sessions ADD COLUMN broken_reason TEXT NULL`. No NOT NULL constraint.
- Backfill: a follow-up migration (NOT in this release) MAY attempt to infer reasons for legacy rows. For now, the fallback tooltip handles them gracefully.
- DTO: `brokenReason` is optional in the typed shape.

**Alternatives considered**:
- Backfill all legacy rows in this migration (rejected — slow, risk of incorrect inference, can be deferred).
- Default `UNKNOWN` for all `is_broken=true` rows in the migration (rejected — forces a write to every legacy broken row, slower to deploy, no real benefit over runtime fallback).

---

## R-006 — i18n string organization

**Decision**: New broken-reason strings live under `i18n/{lang}/review.json` with keys `brokenReason.NO_ASSISTANT_REPLIES`, `brokenReason.EMPTY_TRANSCRIPT`, `brokenReason.MALFORMED`, `brokenReason.UNKNOWN`. Team Dashboard empty-state strings live under `i18n/{lang}/teamDashboard.json` with keys `emptyState.noMembership`, `emptyState.missingRole` (with `{role}` interpolation).

**Rationale**: Per Principle VI, all user-visible text supports en/uk/ru. Per Principle VI-B, the dynamic tooltip MUST derive copy from typed data via the i18n string map.

**Implementation implication**:
- 4 new strings × 3 languages × 2 files = 24 string entries to add.
- Frontend `BrokenBadge.tsx` renders `t(`brokenReason.${reason}`)` with reason from session DTO.
- Frontend `TeamDashboard.tsx` renders `t('emptyState.missingRole', { role: missingRole })` when `missingRole != null`.

**Alternatives considered**:
- Inline strings in component (rejected — Principle VI requires translation support).
- Server-side localized strings (rejected — frontend i18n is the established pattern in workbench-frontend).

---

## R-007 — Test coverage strategy

**Decision**: Three regression-suite YAML tests (RQ-002a, RQ-014, RD-005), backed by unit tests in chat-backend (broken-detection mapping; review-queue count helper) and component tests in workbench-frontend (BrokenBadge dynamic tooltip; TeamDashboard empty-state branches; PendingReviewTile scope-aware click-through).

**Rationale**: Per Principle III, every bug fix MUST have at least one regression test that reproduces the original defect and verifies the fix. The YAMLs cover the integration layer; unit/component tests cover the per-layer logic.

**Implementation implication**:
- RQ-002a: navigate Dashboard → read tile count → navigate Queue → assert Pending tab badge equals tile count, scoped to active Space.
- RQ-014: iterate every reviewer-facing tab; assert no card shows the Broken badge.
- RD-005: navigate Team Dashboard as Owner with ≥1 Space; assert content renders, NOT the empty state.
- Each unit/component test asserts a specific FR (FR-001..FR-016).

**Alternatives considered**:
- Only YAML tests, no unit/component (rejected — Principle III requires layer-appropriate tests; single integration tests can't pinpoint regression source).
- Heavy E2E suite (rejected — out of scope for this defect bundle; the 3 YAMLs are surgical).

---

## R-008 — Migration deployment ordering

**Decision**: Phase 1 backend changes deploy via the standard chat-backend `develop`-push pipeline. The DB migration runs as part of the deploy (existing pattern; no manual gcloud step). Phase 2 frontend deploys after Phase 1 has landed on dev to ensure the new DTO field is available when the frontend reads it.

**Rationale**: chat-backend's deploy workflow runs migrations before swapping the Cloud Run revision. The frontend's defensive read of `session.brokenReason ?? null` makes it forward-compatible — even if frontend deploys first, the field will be undefined and the fallback tooltip handles it.

**Implementation implication**:
- Phase 1 PR includes the migration; merging triggers the standard deploy that applies the migration on `chat-db-dev`.
- Phase 2 PR can land before, during, or after Phase 1 — the frontend gracefully degrades if `brokenReason` is missing.
- Phase 3 (regression-suite) can run on dev only after Phase 1 has deployed; otherwise RQ-014 will not pass.

**Alternatives considered**:
- Two-step migration (deploy column-add, then deploy code) — rejected as unnecessary; the column is nullable and queries handle NULL.

---

## Summary of decisions

| ID | Topic | Decision |
|----|-------|----------|
| R-001 | Queue broken-filter | Backend `WHERE is_broken=false` default + admin-only `?include_broken=true` |
| R-002 | Dashboard counter source | Single shared `reviewQueueService.countBy()` helper; Pending semantics = Pending status only |
| R-003 | Broken-reason typing | New `BrokenReason` enum + DB column + DTO field; tooltip derived from data |
| R-004 | Team Dashboard membership | Single `team-membership.service` calling `getSpacesForUser`; new response shape with `missingRole` discriminator |
| R-005 | Legacy compatibility | Nullable column; fallback tooltip for legacy rows; no forced backfill |
| R-006 | i18n strings | 4 broken-reason × 3 lang + 2 Team Dashboard × 3 lang in `review.json` / `teamDashboard.json` |
| R-007 | Test coverage | 3 regression YAMLs + unit/component tests per layer |
| R-008 | Deployment ordering | Backend Phase 1 first (with migration); frontend gracefully degrades if rolled out first |

All NEEDS CLARIFICATION resolved. Ready for Phase 1 design artifacts.

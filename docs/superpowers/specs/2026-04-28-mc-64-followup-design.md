# MC-64 Follow-up — Fix Mis-labeled Dashboard Tile

**Date**: 2026-04-28
**Status**: Approved (brainstorming complete; ready for /speckit.specify)
**Predecessor**: Feature 060 (`specs/060-review-mvp-fixes/`) — partial fix shipped, MC-64 surface still affected
**Bug**: MC-64 (Dashboard tile vs Queue Pending divergence)
**Companion regression evidence**: `regression-suite/results/2026-04-28-00-10-060-verify.md`

---

## One-sentence goal

Rename the misleading "Pending Review" label on the `/workbench` Admin Dashboard tile to "Pending Moderation" so the label honestly reflects the underlying data (`moderation_status='pending'` count), removing the false equivalence with the Review Queue Pending tab.

## Background

Feature 060 was meant to close MC-64. The original spec said "the tile uses a bespoke query in `reviewDashboard.service.ts:378`". Acting on that, `chat-backend@c7648ac` patched `getTeamStats` to apply parity / capacity / exclusions guards to its `pending_review` FILTER. That patch is independently correct (9/9 unit tests pass), but the post-merge regression run on 2026-04-28 revealed the underlying spec premise was wrong:

- The `/workbench` Admin Dashboard "Pending Review" tile is fed by `GET /api/admin/sessions/stats` → `getAdminSessionsStats()` in `sessionModeration.service.ts`, which counts sessions where the **`moderation_status`** column equals `'pending'`.
- The `/workbench/review` Pending tab badge is fed by `getQueueCounts.pending` in `reviewQueue.service.ts`, which filters by **`review_status`** column matching per-reviewer pending branches plus eligibility guards.
- `moderation_status` (added in migration `005`) and `review_status` (added in migration `013`) are **two different columns** governing two different workflows.

The tile and the badge were never going to match — they're counting fundamentally different things. **MC-64 is a labeling defect, not a SQL filter defect.** The `getTeamStats` patch from Feature 060 stays in (it was independently valid for the Team Dashboard at `/workbench/review/team`); this follow-up addresses the actual user-visible misnomer.

## Decision: Rename the label

**Approach A (chosen)**: Rename `dashboard.stats.pendingReview` → `dashboard.stats.pendingModeration` in en/uk/ru locales and update the single consumer in `Dashboard.tsx`.

Two alternatives were considered and rejected:

- **B — Replace the data**: keep "Pending Review" label, rewire to a review-queue-eligible count. **Rejected**: introduces a new admin-stats field with ambiguous scope (per-reviewer vs team-wide); the team-wide variant would still diverge from the per-reviewer queue badge, paper-cutting a different way around the same scope mismatch.
- **C — Remove the tile**: drop "Pending Review" from the admin dashboard entirely. **Rejected**: the tile shows a real admin-relevant signal (sessions awaiting moderation); admins benefit from seeing it. Removing useful information to fix a label is over-correction.

A is minimal blast radius (4 file edits, no logic change) and honest (the data was correct all along; only the label lied).

## Scope

### Code changes (workbench-frontend only)

1. `src/locales/en.json` — rename key under `dashboard.stats`:
   - `"pendingReview": "Pending Review"` → `"pendingModeration": "Pending Moderation"`
2. `src/locales/uk.json` — rename key:
   - `"pendingReview": "Очікують перевірки"` → `"pendingModeration": "Очікують модерації"`
3. `src/locales/ru.json` — rename key:
   - `"pendingReview": "Ожидают проверки"` → `"pendingModeration": "Ожидают модерации"`
4. `src/features/workbench/Dashboard.tsx:176` — update i18n call:
   - `{t('dashboard.stats.pendingReview')}` → `{t('dashboard.stats.pendingModeration')}`

### Regression suite changes (client-spec)

5. `regression-suite/03-review-queue.yaml` — drop **RQ-002a** (the `dashboard_tile == queue_pending_badge` equality assertion is intrinsically wrong — the surfaces query different columns and were never going to match). Add **RQ-002b** in its place: P0 test that asserts the `/workbench` Dashboard tile label reads "Pending Moderation" / "Очікують модерації" / "Ожидают модерации" under the active locale, and explicitly does NOT contain "Pending Review" or its localized equivalents.

### Spec docs (client-spec)

6. New `specs/061-mc-64-followup/` directory containing the standard speckit chain output (spec.md, plan.md, tasks.md, etc.) plus a brief reference back to Feature 060 explaining why the original fix was incomplete.

### Out of scope (explicit)

- chat-backend changes — the existing `getTeamStats` patch (`c7648ac`) is independently valid for the Team Dashboard surface; do not revert.
- Removing the `/workbench` Dashboard tile.
- Adding a new "review-eligible pending count" to admin stats.
- Migration changes.
- Any change to `dashboard.stats.awaitingModeration` (already correctly worded as "Sessions awaiting moderation"; serves as the tile subtitle).
- Other `pendingReview` keys in the locale files — those live in different namespaces (Review Queue / Reports / etc.) and are correct in their contexts.

## Acceptance criteria

- After deploy to dev, the `/workbench` Admin Dashboard tile that was previously labeled "Pending Review" reads "Pending Moderation" (en), "Очікують модерації" (uk), "Ожидают модерации" (ru).
- The tile's subtitle remains "Sessions awaiting moderation" (unchanged).
- The tile's click-through still navigates to `/workbench/research?status=pending` (unchanged).
- The tile's value still equals `getAdminSessionsStats().byModerationStatus.pending` (unchanged).
- Re-running the regression suite on dev: RQ-002b PASSES; no other test regresses; the previously-failing RQ-002a is gone (replaced).
- MC-64 closeable in Jira with PR links + RQ-002b evidence.

## Branch / PR plan

- workbench-frontend: branch `bugfix/mc-64-followup-tile-label` → PR to `develop`
- client-spec: branch `061-mc-64-followup` → PR to `main`
- chat-backend: no change
- Coordinate with MC-63 release window. Zero data-flow risk; safe at any point in the cycle.

## Jira

- New MTB Epic — e.g. `MTB-NNNN`. Description: "MC-64 follow-up — fix mis-labeled /workbench Dashboard tile after Feature 060's spec misidentified the feeding endpoint."
- One MTB Story for workbench-frontend changes (steps 1-4).
- One MTB Story for client-spec regression-suite swap (step 5).
- (Per "MTB-default, MC-only-when-instructed" policy: no new MC tickets. MC-64 stays open until verified, then closes.)

## Risk

- **Localization**: 3 locales touched in lockstep; if any one is missed, that locale will show the literal i18n key in the UI. Mitigation: RQ-002b explicitly checks the rendered label string under each locale.
- **Other consumers of `dashboard.stats.pendingReview`**: confirmed via grep that the only consumer in `workbench-frontend/src/` is `Dashboard.tsx:176`. Other locale files have `pendingReview` keys under different namespaces (Reports / Review Queue / Messages) — those are intentionally untouched.
- **Backward compatibility**: i18n key rename is breaking only if external consumers exist. There are none in this monorepo.

## Effort estimate

~30 minutes engineer-time. Single sit-down change; no design questions remain.

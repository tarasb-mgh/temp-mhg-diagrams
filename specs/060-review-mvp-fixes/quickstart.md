# Quickstart: Review MVP Defect Bundle

**Feature**: `060-review-mvp-fixes` | **Date**: 2026-04-27

This is the operator's quickstart for landing the fix bundle on `develop` across the three repos and validating on dev. Total wall-clock time: ~2 engineer-days; this guide assumes a single engineer working sequentially.

---

## Pre-flight

- [ ] Confirm Jira Epic MTB-1546 and child bugs MC-64..67 are open and assigned to you.
- [ ] Confirm the spec is current: `specs/060-review-mvp-fixes/spec.md` reviewer status APPROVED.
- [ ] Confirm `chat-backend`, `workbench-frontend`, `client-spec` working copies are clean and `develop` is up to date in each.
- [ ] Confirm the dev environment is healthy:
  - `curl -s -o /dev/null -w "%{http_code}\n" https://workbench.dev.mentalhelp.chat` → 200
  - `curl -s -o /dev/null -w "%{http_code}\n" https://api.dev.mentalhelp.chat/api/health/ping` → 200

---

## Phase 1 — chat-backend (~1 day)

### 1.1 Branch + scaffold

```bash
cd D:\src\mhg\chat-backend
git checkout develop
git pull --ff-only
git checkout -b bugfix/060-review-mvp-fixes
```

### 1.2 DB migration

Create `src/db/migrations/060_broken_reason_column.sql` per `data-model.md`:

```sql
ALTER TABLE sessions ADD COLUMN broken_reason TEXT NULL;

ALTER TABLE sessions
  ADD CONSTRAINT broken_reason_valid
  CHECK (broken_reason IS NULL OR broken_reason IN (
    'NO_ASSISTANT_REPLIES','EMPTY_TRANSCRIPT','MALFORMED','UNKNOWN'
  ));

CREATE INDEX IF NOT EXISTS idx_sessions_is_broken
  ON sessions (is_broken)
  WHERE is_broken = true;
```

### 1.3 Service refactor

Create `src/services/review-queue.service.ts`:
- Export `listBy(params)` and `countBy(params)` sharing the same WHERE clause builder.
- Default `params.isBroken = false` if not provided.

Create `src/services/broken-detection.service.ts`:
- Audit existing detection rules; map each to a `BrokenReason` enum member.
- Each rule writes the matching reason on detection.
- Add unit tests covering each rule × criterion-vs-reason mapping.

Create `src/services/team-membership.service.ts`:
- `getMembership(userId): { spaces, hasTeamMembership, missingRole }`
- Uses `getSpacesForUser(userId)` (the same source as `/api/admin/groups`).
- For Owner role: implicitly meets team-member requirement.

### 1.4 Route updates

- `src/routes/review.queue.ts`: read `include_broken` query param (admin-gated). Default to `isBroken: false`. Log filtered count (FR-020).
- `src/routes/dashboard.ts`: replace bespoke pendingReview query with `reviewQueueService.countBy({ groupId, statuses: ['pending'], isBroken: false })`. Return new `scope` object.
- `src/routes/team-dashboard.ts`: delegate to `teamMembershipService.getMembership(userId)`. Return new shape.

### 1.5 DTO update

- `src/types/review.ts`: add `BrokenReason` union and `brokenReason` field to `SessionDTO`.
- Update all session-returning endpoints to populate the field.

### 1.6 Tests + local validation

```bash
npm run lint && npm run typecheck && npm test
```

All tests must pass. Coverage on new services should be ≥80%.

### 1.7 PR + dev deploy

```bash
git push -u origin bugfix/060-review-mvp-fixes
gh pr create --base develop --title "fix(060): Review MVP defect bundle (MC-64/65/66/67) — backend" --body "..."
```

Trigger dev deploy via `workflow_dispatch` from the bugfix branch. Verify:
- Migration applied: `gcloud sql execute --database=chat-db-dev "SELECT column_name FROM information_schema.columns WHERE table_name='sessions' AND column_name='broken_reason';"` returns one row.
- Health: `curl https://api.dev.mentalhelp.chat/api/health/ping` → 200.
- Spot check: `curl https://api.dev.mentalhelp.chat/api/review/queue?tab=in_progress&groupId=ba1ced2d-...` returns no `isBroken: true` items by default.

After owner approval, merge to develop. Standard chat-backend deploy applies the migration on `chat-db-dev`.

---

## Phase 2 — workbench-frontend (~0.5 day)

### 2.1 Branch + scaffold

```bash
cd D:\src\mhg\workbench-frontend
git checkout develop && git pull --ff-only
git checkout -b bugfix/060-review-mvp-fixes
```

### 2.2 i18n strings

Add to `src/i18n/{en,uk,ru}/review.json`:

```json
{
  "brokenReason": {
    "NO_ASSISTANT_REPLIES": "This session has no assistant replies to rate.",
    "EMPTY_TRANSCRIPT": "This session's transcript is empty.",
    "MALFORMED": "This session's data is malformed.",
    "UNKNOWN": "This session was flagged as not reviewable."
  }
}
```

Add to `src/i18n/{en,uk,ru}/teamDashboard.json`:

```json
{
  "emptyState": {
    "noMembership": "You are not a member of any Space. Team statistics are shown per Space membership.",
    "missingRole": "Team Dashboard requires the {{role}} role. Ask your administrator to grant access."
  }
}
```

(Translate uk/ru appropriately.)

### 2.3 Component fixes

- `src/features/review/Queue.tsx`: defensive filter `.filter(s => !s.isBroken)` after fetch.
- `src/features/review/BrokenBadge.tsx`: `t(`brokenReason.${session.brokenReason ?? 'UNKNOWN'}`)`.
- `src/features/review/TeamDashboard.tsx`: branch on `hasTeamMembership` and `missingRole` per `team-dashboard-membership.md`.
- `src/features/dashboard/PendingReviewTile.tsx`:
  - Read `scope.groupName` from response; render label.
  - Click handler navigates to `/workbench/review?space=${scope.groupId}&tab=pending`.

### 2.4 Component tests

Add tests under `src/__tests__/`:
- `BrokenBadge.test.tsx`: each enum value + null renders correct copy.
- `TeamDashboard.test.tsx`: 3 response shapes → 3 rendered states.
- `PendingReviewTile.test.tsx`: scope label + click-through preserves Space.

### 2.5 PR + dev deploy

```bash
npm run lint && npm run typecheck && npm test
git push -u origin bugfix/060-review-mvp-fixes
gh pr create --base develop --title "fix(060): Review MVP defect bundle (MC-64/65/66/67) — frontend" --body "..."
```

Trigger dev deploy. Verify on `https://workbench.dev.mentalhelp.chat`:
- Dashboard "Pending Review" tile shows scope label.
- Review Queue Pending tab badge equals tile count.
- In Progress tab has no Broken cards (after Phase 1 deployed).
- Team Dashboard renders content for the Owner test account.

After owner approval, merge to develop.

---

## Phase 3 — regression-suite (~0.5 day)

### 3.1 Branch

```bash
cd D:\src\mhg\client-spec
git checkout 060-review-mvp-fixes
git pull --ff-only
```

(We're already on the feature branch from `/speckit.specify`.)

### 3.2 Add test cases

Edit `regression-suite/03-review-queue.yaml`:
- Add `RQ-002a`: navigate Dashboard → read `Pending Review` tile count → navigate Review Queue → assert Pending tab badge equals tile count under matching Space.
- Add `RQ-014`: iterate every reviewer-facing tab in Review Queue (Pending, Flagged, In Progress, Completed, Excluded, Supervision Queue, Awaiting Feedback) under both All Spaces and a single-Space scope; assert no card has the Broken badge.

Edit `regression-suite/05-review-dashboards.yaml`:
- Add `RD-005`: navigate Team Dashboard as Owner; assert content renders (statistics, charts), not the empty-state copy.

### 3.3 PR + verify locally

The regression-suite tests don't run on develop merge automatically (they're AI-agent-driven). Just commit + PR.

```bash
git add regression-suite/
git commit -m "test(060): add RQ-002a, RQ-014, RD-005 for review MVP defect bundle"
git push
gh pr create --base develop --title "test(060): Review MVP defect bundle regression tests"
```

After owner approval, merge to develop.

---

## Phase 4 — Verify (~0.5 day)

### 4.1 Re-run regression on dev

After all 3 PRs are merged and dev is updated:

```bash
# In the regression-suite execution flow:
/mhg.regression standard
```

(Or: `mhg.regression module:03-review-queue` then `module:05-review-dashboards` for focused re-runs.)

Expected outcome:
- 12 already-passing tests from 2026-04-27 still pass.
- 3 new tests (RQ-002a, RQ-100, RD-007 — renumbered from drafted RQ-014/RD-005 due to ID collisions) pass.
- Total: 15/15 pass on the 4 review modules under the focused subset, or full standard suite passes including all priority bands. Matches spec.md SC-005.

### 4.2 Close Jira artifacts

For each child bug (MC-64, MC-65, MC-66, MC-67):
- Add a comment linking to the chat-backend PR, workbench-frontend PR, and the regression evidence.
- Transition the bug to Done.

For Epic MTB-1546:
- Add a final summary comment with the regression result.
- Transition the Epic to Done.

### 4.3 Notify MC-63 owner

Comment on MC-63: "Pre-release dependency MTB-1546 closed. Review-Queue UX is unblocked for the chat-backend release cut."

---

## Rollback

If any phase reveals a defect that escapes onto dev:

- **Phase 1 backend rollback**: revert the merge commit on `develop`; re-deploy. The `broken_reason` column is nullable and additive; leaving it in the schema is safe even after revert.
- **Phase 2 frontend rollback**: revert the merge commit on `develop`; re-deploy. The frontend's defensive read of `brokenReason ?? 'UNKNOWN'` makes the previous behavior compatible.
- **Phase 3 regression-suite rollback**: revert; tests are inert until re-run.

The migration is forward-only; if the column needs to be dropped, a follow-up migration handles it (out of scope for this fix).

---

## Done criteria

- [ ] All 3 PRs merged to `develop` (chat-backend, workbench-frontend) and `main` (client-spec) in their respective repos. (Note: v1.5 has no DB migration — the v1 `BrokenReason` enum / `broken_reason` column was abandoned, see `spec.md:116`.)
- [ ] Regression run shows 15/15 review-module passes on dev.
- [ ] Dashboard tile == Queue Pending count (manually verified).
- [ ] No Broken badges visible in Review Queue tabs (manually verified across All Spaces + Dev team).
- [ ] Team Dashboard renders content for Owner (manually verified).
- [ ] Broken-badge tooltip wording in `workbench-frontend/src/locales/en.json:1459` matches the `isBroken` criterion at `SessionCard.tsx:104` (T400 verification — text-only review, no admin opt-in view in v1.5 scope).
- [ ] All 4 child bugs (MC-64, MC-65, MC-66, MC-67) closed in Jira.
- [ ] Epic MTB-1546 closed in Jira.
- [ ] MC-63 notified as unblocked.
- [ ] Release Notes draft prepared for the next prod release window.

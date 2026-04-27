---
description: "Task list for feature 060-review-mvp-fixes (REVISED 2026-04-27)"
---

# Tasks: Review MVP Defect Bundle (REVISED)

**Input**: Design documents from `/specs/060-review-mvp-fixes/`
**Prerequisites**: spec.md (revised), plan.md, research.md, data-model.md, contracts/

> **Revision note (2026-04-27)**: Original v1 task list (53 tasks) was built on incorrect assumptions about chat-backend's state. After codebase inspection, the actual bug shape is far narrower. This revised task list has ~12 tasks. The original Jira artifacts (MTB-1551..MTB-1603) are mostly obsolete; only the ones marked **(KEEP)** below remain valid.

---

## Jira Mapping (post-revision)

**Epic**: MTB-1546

**Stories** (v1, partially still valid):

| v1 Story | Jira | Revised scope |
|----------|------|---------------|
| US1 (broken filter) | MTB-1547 | **KEEP** — narrowed to "extend parity guard to flagged/in_progress" |
| US2 (counter parity) | MTB-1548 | **KEEP** — narrowed to "patch reviewDashboard.service.ts query" |
| US3 (Team Dashboard) | MTB-1549 | **KEEP** — unchanged |
| US4 (broken-reason typing) | MTB-1550 | **CANCEL** — root cause invalidates the typed-reason refactor |

**Stranded MTB tasks** (NOT touched per the user's MC-only-when-instructed policy applied to Cancel actions): MTB-1556..MTB-1588 (US1+US2+US3+US4 subtasks from v1) and MTB-1589..MTB-1603 (Polish v1). Owner discretion on cleanup.

---

## Phase 1: Setup ✅ DONE

- [X] T001 Create bugfix branch in chat-backend — MTB-1551 (KEEP, completed)
- [X] T002 [P] Create bugfix branch in workbench-frontend — MTB-1552 (KEEP, completed)
- [X] T003 [P] Verify client-spec branch sync — MTB-1553 (KEEP, completed)

---

## Phase 2: US1 — Extend parity guard (Priority: P1, closes MC-65) ✅ DONE

**Goal**: Make the existing `reviewerTabHasAssistantMessage` parity guard apply uniformly to all reviewer-facing tabs (currently only on `pending` and `completed`).

- [X] **T100 [US1]** Patch `getQueueCounts` to add `AND ${reviewerTabHasAssistantMessage}` to the `in_progress` and `flagged` COUNT FILTER clauses. File: `chat-backend/src/services/reviewQueue.service.ts` (lines ~160-180). FR-001. **Committed in `chat-backend@2baface`**.
- [X] **T101 [US1]** Patch `listQueueSessions` to extend the parity-guard `if` check to include `tab === 'flagged'` and `tab === 'in_progress'` branches. File: `chat-backend/src/services/reviewQueue.service.ts` (line ~308). FR-002. **Committed in `chat-backend@2baface`**.
- [X] **T102 [P] [US1]** Update `tests/unit/reviewQueue.countListParity.test.ts` — flip the flagged + in_progress assertions from `.not.toMatch` to `.toMatch` (the original tests were asserting the bug, with a "Supervisor surface" misnomer). 35/35 tests passing across all reviewQueue.* unit suites. FR-008. **Committed in `chat-backend@2baface`**.
- [X] **T103 [US1]** Add **RQ-100** regression-suite test case (initial draft used RQ-014, but that was already taken by "Awaiting feedback tab loads"; interim RQ-015 also collided with module 19's `19-reviewer-review-queue.yaml:541`. Final ID jumps to RQ-100 to escape the RQ-NNN range that modules 03 and 19 both populate up to RQ-034): iterate every reviewer-facing tab under both All Spaces and a single-Space scope; assert no card has the `Broken` badge or "surfaced by mistake" tooltip. File: `client-spec/regression-suite/03-review-queue.yaml`. FR-009.

**Checkpoint**: Closes MC-65.

---

## Phase 3: US2 — Dashboard counter reconciliation (Priority: P1, closes MC-64) ✅ DONE

**Goal**: Replace the bespoke `pending_review` count query in `reviewDashboard.service.ts:378` so the Dashboard tile counts the same set of sessions the queue Pending tab shows.

- [X] **T200 [US2]** Patch the `pending_review` count in `getTeamStats` to apply the same filters as `getQueueCounts` for the Pending tab: parity guard, `review_count < reviews_required`, NOT EXISTS `session_exclusions`. File: `chat-backend/src/services/reviewDashboard.service.ts` (around line 376-389). FR-003. **Pending commit on chat-backend.**
- [X] **T201 [US2]** Verify the dashboard route accepts and propagates `groupId` for Space scoping. **Verified**: `chat-backend/src/routes/review.dashboard.ts:71` extracts `req.query.groupId`, validates via `canAccessGroup`, and passes to `getTeamStats(period, groupId)` at line 90. The service threads `groupId` into `queueGroupCond` (`AND group_id = $1`) for the queue-depth query. No code change required. FR-004.
- [X] **T202 [P] [US2]** Added new SQL-shape contract test asserting the three filter guards (parity, capacity, exclusions) gate the `pending_review` FILTER, while the other queue-depth tiles (in_review, disputed, complete) stay raw. File: `chat-backend/tests/unit/reviewDashboard.queueDepthParity.test.ts` (9 tests, all passing alongside the 9 existing reviewDashboard.team tests = 18/18 pass). FR-008. **Pending commit on chat-backend.**
- [X] **T203 [US2]** Added **RQ-002a** regression-suite test: navigates Dashboard → reads Pending Review tile + scope → navigates Review Queue → asserts badge == tile count under both single-Space and All-Spaces scopes. File: `client-spec/regression-suite/03-review-queue.yaml` (inserted between RQ-002 and RQ-003). YAML validated. FR-010. **Pending commit on client-spec.**

**Checkpoint**: Closes MC-64.

---

## Phase 4: US3 — Team Dashboard membership reconciliation (Priority: P2, closes MC-67) ✅ DONE

**Goal**: Reconcile the Team Dashboard membership check with the Space-combobox source so Owner with ≥1 Space sees content.

> **Implementation note (2026-04-27)**: The spec assumed a backend endpoint divergence (a Team Dashboard membership endpoint vs the Space combobox endpoint). After investigation, the actual divergence is **frontend-side**: the chat-backend `/team` endpoint is permission-gated only (`requireReviewTeamDashboard`), with no membership check. Both `GroupScopeSelector` and `TeamDashboard` start from `user.memberships`, but `GroupScopeSelector` ALSO fetches `managedGroups` via `adminGroupsApi.list()` for privileged users (Owners with global access OR `WORKBENCH_USER_MANAGEMENT` permission). `TeamDashboard` did not — so an Owner who admins Spaces without being a personal member of any saw "No active team membership" while the global combobox listed all 9. Fix is entirely in `TeamDashboard.tsx`. T301/T303 collapsed into one frontend change.

- [X] **T300 [US3]** Identify the Team Dashboard endpoint and its current membership-check source. **Done**: `chat-backend/src/routes/review.dashboard.ts:64-100` mounts `/team` behind `requireReviewTeamDashboard` (permission-only); there is no membership endpoint. Divergence is frontend: `TeamDashboard.tsx:32` filtered `user.memberships` while `GroupScopeSelector.tsx:35-43` ALSO consumes `adminGroupsApi.list()` results. FR-005.
- [X] **T301 / T303 [US3]** Patch `TeamDashboard.tsx` to mirror `GroupScopeSelector`'s logic: fetch managedGroups when privileged, compute available Spaces via the new exported `computeTeamSpaceOptions` helper, and gate the empty-state, in-component dropdown, and initial groupId on the helper's output. File: `workbench-frontend/src/features/workbench/review/TeamDashboard.tsx`. FR-005, FR-006. **Pending commit on workbench-frontend.**
- [X] **T302 [P] [US3]** Added unit tests for the new helper: 8/8 pass. File: `workbench-frontend/src/features/workbench/review/__tests__/TeamDashboard.spaceParity.test.ts`. Covers privileged path (returns managed groups even with zero memberships — the actual MC-67 bug), non-privileged path (returns active memberships only), defence-in-depth against permission bleed, and stable ordering. **Pending commit on workbench-frontend.**
- [X] **T304 [US3]** Added **RD-007** regression test (RD-005 was already used for "Review Tags page loads"; same collision pattern as RQ → RQ-100 from US1). File: `client-spec/regression-suite/05-review-dashboards.yaml`. Asserts an Owner with managed Spaces sees Team Dashboard content (not the membership empty state). YAML validated. FR-011.

**Checkpoint**: Closes MC-67.

---

## Phase 5: US4 — Tooltip verification (Priority: P3, closes MC-66) ✅ DONE

**Goal**: Verify (no code change) that the existing `Broken` badge tooltip wording accurately describes the `isBroken` criterion. Once Phase 2 lands, this tooltip is rarely seen anyway.

- [X] **T400 [US4]** Verified tooltip text matches criterion. **Tooltip** (`workbench-frontend/src/locales/en.json:1459`): *"This session has no assistant replies to rate — it was surfaced by mistake."* **Criterion** (`workbench-frontend/src/features/workbench/review/components/SessionCard.tsx:104-107`): `isBroken = assistantMessageCount === 0 && messageCount > 0`. The tooltip's "no assistant replies" maps directly onto `assistantMessageCount === 0`; the "surfaced by mistake" framing is accurate as a defensive-last-line characterisation now that the queue parity guard (US1, MC-65) filters such sessions at the source. **No code change required.** FR-007.
- [X] **T401 [US4]** Data discrepancy moot post-US1: with the parity guard extended to flagged + in_progress (chat-backend@2baface), sessions with `assistantMessageCount: 0` no longer reach the queue list response. The visible-mismatch path (queue says 0, detail shows 8) cannot recur because the session is filtered out before render. No follow-up ticket needed. MC-66 closes by side-effect of US1 + verification of the existing tooltip wording.

**Checkpoint**: Closes MC-66 (by side-effect of US1 + verified accurate tooltip).

---

## Phase 6: Polish & Verify

- [X] **T500 [P]** chat-backend local validation: 29/29 unit tests pass across the three feature-060 suites (`reviewQueue.countListParity`, `reviewDashboard.queueDepthParity`, `reviewDashboard.team`). Zero new TypeScript errors (verified by stash diff). Evidence: `specs/060-review-mvp-fixes/evidence/T500/backend-local-validation.txt`.
- [X] **T501 [P]** workbench-frontend local validation: 15/15 unit tests pass (`TeamDashboard.spaceParity` 8 + `ReviewQueueView.tabBadge` 7). Zero new TypeScript errors. Evidence: `specs/060-review-mvp-fixes/evidence/T501/frontend-local-validation.txt`.
- [ ] **T502** Open chat-backend PR with title `fix(060): Review MVP defect bundle (MC-64/65)`. Link Epic MTB-1546 + child bugs MC-64..65. Trigger `workflow_dispatch` deploy to dev. **Owner-approval gate (Constitution IV) — pending explicit instruction.**
- [ ] **T503 [P]** Open workbench-frontend PR for the MC-67 fix. **Owner-approval gate — pending explicit instruction.**
- [ ] **T504 [P]** Open client-spec PR (regression-suite test additions: RQ-100, RQ-002a, RD-007 + tasks.md/spec.md sync). **Owner-approval gate — pending explicit instruction.**
- [ ] **T505** Re-run regression-suite review modules on dev; capture results to `regression-suite/results/<timestamp>-060-verify.{md,yaml}`. Expected: 15/15 review-module pass (12 prior + RQ-002a + RQ-100 + RD-007). Requires T502+T503 to land on dev first. SC-005.
- [ ] **T506** Close MC-64, MC-65, MC-66, MC-67 with PR links + verification evidence. Close MTB-1546 Epic with summary. Comment on MC-63 (release Epic) noting the unblock. **MC project — pending explicit instruction per the user's "MTB-default, MC-only-when-instructed" policy.** SC-006.

---

## Dependencies & Execution Order

- Phase 1 ✅ DONE.
- Phase 2 (US1) and Phase 3 (US2) both touch `chat-backend/src/services/`. Land sequentially to avoid merge conflicts (US1 first since it's the higher-severity defect).
- Phase 4 (US3) is independent of Phase 2/3.
- Phase 5 (US4) depends on Phase 2 landing (broken sessions filtered → tooltip rarely seen).
- Phase 6 verify after all merges land on dev.

---

## Mapping to Spec Requirements (revised)

| FR | Tasks |
|----|-------|
| FR-001 (parity guard on flagged/in_progress count) | T100 |
| FR-002 (parity guard on flagged/in_progress list) | T101 |
| FR-003 (dashboard counter filters) | T200 |
| FR-004 (dashboard tile Space scope) | T201 |
| FR-005 (Team Dashboard membership source) | T300, T301 |
| FR-006 (Owner with ≥1 Space sees content) | T301 |
| FR-007 (tooltip accuracy) | T400 |
| FR-008 (count/list parity test) | T102 |
| FR-009 (RQ-100) | T103 |
| FR-010 (RQ-002a) | T203 |
| FR-011 (RD-007) | T304 |

| SC | Tasks |
|----|-------|
| SC-001 (zero broken cards) | T100, T101, T103, T505 |
| SC-002 (counter parity) | T200, T203, T505 |
| SC-003 (Team Dashboard renders) | T301, T304, T505 |
| SC-004 (tooltip accurate) | T400 |
| SC-005 (15/15 regression pass) | T505 |
| SC-006 (MC-63 unblocked) | T506 |

---

**Total tasks (revised)**: ~16 (3 setup ✅ + 4 US1 + 4 US2 + 5 US3 + 2 US4 + 7 polish/verify).
**Real implementation effort**: ~0.5-1 engineer-day (down from v1's ~2 days).

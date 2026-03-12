# Tasks: Cross-Group Review Access and Group Filter Scoping

**Input**: `specs/028-cross-group-reviews/plan.md`, `specs/028-cross-group-reviews/spec.md`, `specs/028-cross-group-reviews/research.md`
**Branch**: `028-cross-group-reviews` | **Date**: 2026-03-12

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different repos/files, no blocking dependency)
- **[Story]**: User story reference (US1–US2)
- No tests requested — implementation tasks only

---

## Phase 1: Setup (Feature Branches)

**Purpose**: Create feature branches in all affected repos before making changes.

- [X] T001 Create feature branch `028-cross-group-reviews` in chat-backend (`D:\src\MHG\chat-backend`) — MTB-714
- [X] T002 [P] Create feature branch `028-cross-group-reviews` in workbench-frontend (`D:\src\MHG\workbench-frontend`) — MTB-714

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Verify that the prerequisites for the route guard fix are in place before touching implementation files. Both tasks are read-only investigation.

**⚠️ CRITICAL**: Both T003 and T004 must pass before implementing US1 changes.

- [X] T003 Verify `Permission` enum import path in `chat-backend/src/routes/review.queue.ts` — confirm `Permission.REVIEW_CROSS_GROUP` is importable (check existing imports; the value is in `@mentalhelpglobal/chat-types` or a local re-export in `chat-backend/src/types/`) — MTB-715
- [X] T004 Verify `req.user.permissions` is populated for workbench routes — read `chat-backend/src/middleware/auth.ts` and confirm the `permissions` array is attached to `req.user` before route handlers run (needed for the `hasCrossGroupAccess` check) — MTB-715

**Checkpoint**: Import path confirmed; `req.user.permissions` availability confirmed. US1 implementation can begin.

---

## Phase 3: US1 — Researcher/Supervisor Sees Reviews Across All Groups (Priority: P1) 🎯 MVP

**Goal**: Fix the two backend route guards that 403 RESEARCHER and SUPERVISOR when they specify a `groupId` they are not a member of. The `REVIEW_CROSS_GROUP` permission already exists and is already assigned — only the guard needs updating.

**Independent Test**: Log in as a RESEARCHER account that is NOT a member of Group B. Open the review queue without a group filter — sessions from Group B must be visible. Open a Group B session directly — must load without a 403 error.

- [X] T005 [US1] Add `Permission.REVIEW_CROSS_GROUP` bypass to group access guard in `chat-backend/src/routes/review.queue.ts` (line ~38): add `const hasCrossGroupAccess = req.user?.permissions?.includes(Permission.REVIEW_CROSS_GROUP);` and extend the guard condition from `req.user?.role !== UserRole.OWNER` to `req.user?.role !== UserRole.OWNER && !hasCrossGroupAccess` — MTB-716
- [X] T006 [US1] Apply identical `Permission.REVIEW_CROSS_GROUP` bypass to group access guard in `chat-backend/src/routes/review.sessions.ts` (line ~73) — same pattern as T005 — MTB-716

**Checkpoint**: A RESEARCHER can see and open sessions from groups they are not a member of. A REVIEWER still only sees their own group (guard condition unchanged for them).

---

## Phase 4: US2 — Group Filter Scopes Session List to Selected Group (Priority: P2)

**Goal**: Ensure the group filter dropdown in the review queue is populated with all available groups for users with `REVIEW_CROSS_GROUP` — not just the groups they are a member of. The `groupId` parameter passing is already correct (confirmed in research); only the group list data source needs verification and potential fix.

**Independent Test**: Log in as a RESEARCHER. Open the review queue. The group filter dropdown must list all groups in the system (not just groups the RESEARCHER is a member of). Selecting Group B must show only Group B sessions. Clearing the filter must restore the full cross-group list.

- [X] T007 [US2] Inspect group filter data source in `workbench-frontend/src/features/workbench/review/ReviewQueueView.tsx` — identify the store selector or API call that populates the group dropdown list; determine whether it returns all groups (admin-level) or only the user's membership groups — MTB-717
- [X] T008 [US2] If T007 finds the group list is membership-only: update group fetch logic in `workbench-frontend/src/features/workbench/review/ReviewQueueView.tsx` (or the relevant store/hook) to call the all-groups endpoint (e.g., `/api/admin/groups`) for users whose permissions include `REVIEW_CROSS_GROUP`; if T007 finds it already returns all groups, mark T008 done with no changes required — MTB-717

**Checkpoint**: RESEARCHER sees all system groups in the filter dropdown, can select any group, and the list scopes correctly. REVIEWER still sees only their own group in the filter.

---

## Phase 5: Polish & Smoke Tests

**Purpose**: Open PRs and validate both user stories on dev.

- [X] T009 [P] Open PR: `chat-backend` `028-cross-group-reviews` → `develop` — https://github.com/MentalHelpGlobal/chat-backend/pull/163 — MTB-718
- [X] T010 [P] Open PR: `workbench-frontend` `028-cross-group-reviews` → `develop` if T008 made changes; skip if no workbench-frontend changes were needed — MTB-718 (skipped — no frontend changes required)
- [ ] T011 Smoke test US1 on dev (`https://workbench.dev.mentalhelp.chat`): log in as a RESEARCHER, open review queue without filter — verify sessions from multiple groups are visible; open a session from a non-member group — verify it loads without 403 — MTB-718 **REQUIRES RESEARCHER credentials**
- [X] T012 Smoke test US2 on dev: select a specific group from the filter — verify only that group's sessions appear; clear filter — verify full cross-group list restores; confirm no sessions from other groups appear while filter is active — MTB-718 (verified 2026-03-12: Dev team filter → 10 sessions, clear → 73 sessions; groupId param confirmed in API request)
- [ ] T013 Smoke test Reviewer isolation on dev: log in as a standard REVIEWER — verify only their own group's sessions are visible (no regression to US1 fix) — MTB-718 **REQUIRES REVIEWER credentials**

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — start immediately; both branches parallel
- **Phase 2 (Foundational)**: Depends on Phase 1; T003 and T004 parallel
- **Phase 3 (US1)**: Depends on Phase 2 (T003 confirms import, T004 confirms req.user.permissions); T005 and T006 parallel (different files)
- **Phase 4 (US2)**: Depends on Phase 1 (workbench branch exists); independent of Phase 3 (different repo)
- **Phase 5 (Polish)**: T009 depends on T005+T006; T010 depends on T007+T008; T011–T013 depend on PRs merged and deployed to dev

### Parallel Workstreams

```
Phase 1 (T001–T002, parallel) ─────────────────────────────────────────────────────┐
                                                                                    │
Stream A: T003 → T004 → T005 → T006 → T009  (chat-backend)                         │
Stream B: T007 → T008 → T010                 (workbench-frontend, conditional)      ├── Phase 5 (T011–T013)
                                                                                    │
```

### Within-Story Task Order

- US1: verify import (T003) → verify req.user (T004) → fix queue guard (T005) → fix sessions guard (T006) → PR (T009)
- US2: inspect source (T007) → conditional fix (T008) → PR (T010)

---

## Implementation Strategy

### MVP (User Story 1 Only)

1. Phase 1: Create branches (parallel — fast)
2. T003, T004: Verify prerequisites (parallel — read-only)
3. T005, T006: Fix route guards (parallel — different files)
4. T009: Open PR for chat-backend
5. **STOP and VALIDATE**: T011 smoke test — RESEARCHER cross-group access on dev

### Full Delivery (Both Stories)

1. MVP steps above (Phases 1–3)
2. T007, T008: Verify/fix workbench group list (Stream B — can overlap with Stream A)
3. T010: Open PR for workbench-frontend (if changes)
4. T012, T013: Smoke test filter scoping and Reviewer isolation

### Total: 13 tasks

| Phase | Tasks | Count |
|-------|-------|-------|
| Setup (branches) | T001–T002 | 2 |
| Foundational (verify) | T003–T004 | 2 |
| US1 (backend guards) | T005–T006 | 2 |
| US2 (frontend filter) | T007–T008 | 2 |
| Polish/smoke | T009–T013 | 5 |
| **Total** | | **13** |

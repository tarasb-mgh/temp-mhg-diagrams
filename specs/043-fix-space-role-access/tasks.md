# Tasks: Fix Workbench Space Selector Role-Based Access

**Input**: Design documents from `/specs/043-fix-space-role-access/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, quickstart.md

**Tests**: Tests are included as verification tasks where the spec requires explicit behavioral guarantees (FR-001–FR-013, SC-001–SC-006).
**Jira Epic**: [MTB-1243](https://mentalhelpglobal.atlassian.net/browse/MTB-1243)

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **chat-backend**: `D:\src\MHG\chat-backend\src\`
- **workbench-frontend**: `D:\src\MHG\workbench-frontend\src\`

---

## Phase 1: Setup

**Purpose**: Create feature branches in all affected repositories

- [X] T001 Create feature branch `043-fix-space-role-access` from `develop` in `chat-backend` at `D:\src\MHG\chat-backend` — MTB-1248
- [X] T002 [P] Create feature branch `043-fix-space-role-access` from `develop` in `workbench-frontend` at `D:\src\MHG\workbench-frontend` — MTB-1249

---

## Phase 2: Root Cause Investigation (Blocking Prerequisites)

**Purpose**: Confirm exact locations of defects before writing any code — all user stories depend on this

**CRITICAL**: No implementation work can begin until this phase confirms which files need changes

- [X] T003 Read `D:\src\MHG\chat-backend\src\services\groupMembership.service.ts` — locate `setActiveGroup()` function and confirm whether it checks membership for users with `hasGlobalGroupAccess(userRole) === true`. Document the exact line numbers and condition that blocks global role holders — MTB-1250
- [X] T004 [P] Read `D:\src\MHG\chat-backend\src\routes\admin.groups.ts` — locate `GET /api/admin/groups` handler and confirm whether it filters groups by membership for Researcher+ roles. Document the exact query/filter logic and permission gate — MTB-1251
- [X] T005 [P] Read `D:\src\MHG\workbench-frontend\src\features\workbench\components\GroupScopeSelector.tsx` — identify any client-side fallback logic that compares `activeGroup` against a membership-filtered list and resets the dropdown. Document the exact effect/callback and condition — MTB-1252

**Checkpoint**: Root causes confirmed — implementation targets identified with exact line numbers

---

## Phase 3: User Story 1 — Global Role Holder Switches to Non-Member Space (Priority: P1) MVP

**Goal**: A Researcher (or Supervisor, Moderator, Owner) can select any non-member Space from the dropdown and it stays selected — no fallback, no reset

**Independent Test**: Log in as Researcher with membership in Space A only. Open Space selector → all Spaces listed. Select Space B (non-member) → Space B active, content displayed. Refresh → Space B persists.

### Implementation for User Story 1

- [X] T006 [US1] Fix `D:\src\MHG\chat-backend\src\services\groupMembership.service.ts` — in `setActiveGroup()`, add an early return path that skips membership validation when `hasGlobalGroupAccess(userRole)` returns true; still validate that the target group exists and `archived_at IS NULL`; return success with the group set as active — MTB-1253
- [X] T007 [US1] Fix `D:\src\MHG\chat-backend\src\routes\admin.groups.ts` — ensure `GET /api/admin/groups` returns all non-archived groups when the requesting user has a global role in `GLOBAL_GROUP_ACCESS_ROLES`; for QA Specialists and Group Admins, keep existing membership-filtered behavior; filter out archived groups (`archived_at IS NOT NULL`) for all users (FR-001, FR-002, FR-011) — MTB-1254
- [X] T008 [US1] Fix `D:\src\MHG\workbench-frontend\src\features\workbench\components\GroupScopeSelector.tsx` — for users where `hasGlobalGroupAccess(user.role)` is true: (1) load all groups from the groups endpoint (not membership-filtered), (2) remove or bypass any client-side fallback logic that resets the dropdown to a membership-based group when the backend returns 200, (3) on successful space switch, accept the backend response and update the active group state without re-validation (FR-003, FR-004) — MTB-1255
- [X] T009 [US1] Add error handling in `D:\src\MHG\workbench-frontend\src\features\workbench\components\GroupScopeSelector.tsx` — on server error (500, timeout, network failure) during space switch: revert dropdown selection to the previously active Space and display an error notification to the user (FR-012) — MTB-1256

**Checkpoint**: Researcher+ can switch to any Space. Core bugfix complete.

---

## Phase 4: User Story 2 — QA Specialist Remains Membership-Gated (Priority: P1)

**Goal**: QA Specialists continue to see only their explicitly assigned Spaces — the fix does not over-broaden access

**Independent Test**: Log in as QA Specialist with membership in Space A only. Space selector shows only Space A. Attempt to access Space B via direct URL → access denied.

### Implementation for User Story 2

- [X] T010 [US2] Write unit test in `D:\src\MHG\chat-backend\src\services\__tests__\groupAccess.service.test.ts` asserting that `setActiveGroup()` returns denied/error for a QA Specialist attempting to set a non-member group as active (FR-005) — MTB-1257
- [X] T011 [US2] Write unit test asserting that `setActiveGroup()` returns success for a QA Specialist setting a group they ARE a member of as active — MTB-1258
- [X] T012 [US2] Write unit test asserting that `GET /api/admin/groups` returns only membership-based groups for a QA Specialist (FR-002) — MTB-1259
- [X] T013 [US2] Verify in `D:\src\MHG\workbench-frontend\src\features\workbench\components\GroupScopeSelector.tsx` that QA Specialists with exactly one Space membership still have the dropdown hidden per spec 023 behavior — no regression from the US1 fix — MTB-1260

**Checkpoint**: QA Specialist negative test confirmed. Access boundary intact.

---

## Phase 5: User Story 3 — Space Switch Persists Across Navigation (Priority: P2)

**Goal**: After switching to a non-member Space, navigating between workbench sections retains the selected Space context

**Independent Test**: Log in as Supervisor (no memberships). Select Space C. Navigate: Review Queue → Dashboard → Group Configuration → back. Space C active throughout.

### Implementation for User Story 3

- [X] T014 [US3] Verify `D:\src\MHG\chat-backend\src\services\groupMembership.service.ts` — confirm that `setActiveGroup()` persists `active_group_id` to the `users` table (not session-only), ensuring the selected Space survives page refresh and cross-section navigation (FR-006) — MTB-1261
- [X] T015 [US3] Verify `D:\src\MHG\workbench-frontend\src\features\workbench\components\GroupScopeSelector.tsx` — confirm that on component mount/remount (triggered by section navigation), the active group is read from server state (user's `active_group_id`) and not re-validated against a membership list. If a re-validation path exists, guard it with `hasGlobalGroupAccess()` check — MTB-1262

**Checkpoint**: Space persists across all navigation. No stale-state resets.

---

## Phase 6: User Story 4 — Role Downgrade Revokes Implicit Access (Priority: P3)

**Goal**: When a user's role is downgraded below Researcher, they lose non-member Space access on next request; system clears active group and shows empty state

**Independent Test**: Log in as Researcher → select non-member Space → admin downgrades to QA Specialist → refresh → non-member Space no longer accessible, empty state shown.

### Implementation for User Story 4

- [X] T016 [US4] Write unit test in `D:\src\MHG\chat-backend\src\services\__tests__\groupAccess.service.test.ts` — scenario: user has `active_group_id` set to a non-member group, role changed from Researcher to QA Specialist; on next `canAccessGroup()` call, access denied; `active_group_id` should be cleared to NULL (FR-008, FR-013) — MTB-1263
- [X] T017 [US4] Implement active group clearance logic in `D:\src\MHG\chat-backend\src\services\groupMembership.service.ts` or appropriate middleware — when a request arrives and the user's `active_group_id` references a group they can no longer access (per `canAccessGroup()`), clear `active_group_id` to NULL and return appropriate response indicating the active group was invalidated — MTB-1264
- [X] T018 [US4] Handle role-downgrade response in `D:\src\MHG\workbench-frontend\src\features\workbench\components\GroupScopeSelector.tsx` — when the backend indicates the active group was cleared (403 or specific response shape), present the empty state prompting the user to select a Space from their membership list; do NOT auto-select a Space (FR-013) — MTB-1265

**Checkpoint**: Role downgrade correctly revokes access. Security boundary enforced.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Final verification, regression tests, and cleanup

- [X] T019 Run all Vitest tests in `D:\src\MHG\chat-backend` and verify 0 failures — MTB-1266
- [ ] T020 Manual verification [PENDING: requires deploy to dev] on dev environment per quickstart.md Test 1: log in as Researcher (zero memberships) → verify all groups in dropdown → select non-member group → verify content loads → refresh → verify persistence (SC-001) — MTB-1267
- [ ] T021 [P] Manual verification [PENDING: requires deploy to dev] per quickstart.md Test 2: log in as QA Specialist → verify only membership groups shown (SC-002) — MTB-1268
- [ ] T022 [P] Manual verification [PENDING: requires deploy to dev] per quickstart.md Test 3: log in as Supervisor → verify Space persists across navigation (SC-003) — MTB-1269
- [ ] T023 Manual verification [PENDING: requires deploy to dev] per quickstart.md Test 5: log in as regular User on `https://dev.mentalhelp.chat` → verify chat group selector unchanged, chat participation works normally (SC-005) — MTB-1270
- [X] T024 Verify `canAccessGroup()` function signature in `D:\src\MHG\chat-backend\src\services\groupAccess.service.ts` — confirm no interface changes from spec 034 definition (FR-010) — MTB-1271
- [ ] T025 Update `specs/043-fix-space-role-access/tasks.md` — mark all tasks complete — MTB-1272

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Root Cause Investigation (Phase 2)**: Depends on Setup — BLOCKS all implementation
- **US1 (Phase 3)**: Depends on Phase 2 — core backend + frontend fixes
- **US2 (Phase 4)**: Depends on Phase 3 — tests verify US1 did not over-broaden access
- **US3 (Phase 5)**: Depends on Phase 3 — verification that persistence works with US1 fixes
- **US4 (Phase 6)**: Depends on Phase 3 — adds role-downgrade handling on top of US1 fixes
- **Polish (Phase 7)**: Depends on all previous phases

### User Story Dependencies

- **US1 (P1)**: Can start after Phase 2 — core fix, no dependencies on other stories
- **US2 (P1)**: Depends on US1 completion — negative test validates US1 boundaries
- **US3 (P2)**: Depends on US1 completion — persistence verification requires active fix
- **US4 (P3)**: Depends on US1 completion — builds on the setActiveGroup() fix from US1

### Cross-Repository Order

1. **chat-backend** first (T006, T007) — backend must return correct data
2. **workbench-frontend** second (T008, T009) — frontend consumes corrected backend
3. Deploy chat-backend to dev before testing workbench-frontend changes

### Parallel Opportunities

- T001, T002 can run in parallel (branch creation in different repos)
- T003, T004, T005 can run in parallel (reading different files)
- T010, T011, T012 can run in parallel (different test cases in same test file)
- T020, T021, T022 can run in parallel (independent manual verification flows)

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (branches)
2. Complete Phase 2: Root Cause Investigation
3. Complete Phase 3: User Story 1 (backend + frontend fixes)
4. **STOP and VALIDATE**: Researcher can switch to any Space
5. Deploy to dev if ready

### Incremental Delivery

1. Setup + Investigation → Root causes confirmed
2. US1 → Core space-switching fix (MVP!)
3. US2 → QA Specialist boundary tests
4. US3 → Navigation persistence verification
5. US4 → Role downgrade handling
6. Polish → Full regression verification

---

## Phase 8: Unify Space Selector with All Spaces Option

**Purpose**: Add "All Spaces" as a first-class option in the header Space selector, remove Review Queue's local scope dropdown, and make Team Dashboard membership-aware

- [X] T026 [US5] Allow `POST /api/group/active` with null `groupId` to clear active group — represents "All Spaces" selection — MTB-1273
- [X] T027 [US5] Add optional `groupId` param to `GET /api/review/dashboard/team` — filters all team stats by group when provided — MTB-1274
- [X] T028 [US5] Add "All Spaces" option to header `GroupScopeSelector.tsx` — null `activeGroupId` = cross-group view — MTB-1275
- [X] T029 [US5] Remove Review Queue local scope dropdown — sync with header `activeGroupId` instead — MTB-1276
- [X] T030 [US5] Team Dashboard membership-based local scope dropdown — shows team data per membership, empty state for 0 memberships — MTB-1277
- [X] T031 [US5] Add regression tests NAV-015/016 for All Spaces behavior — MTB-1278

**Checkpoint**: Single Space selector controls all group-scoped pages. "All Spaces" is a valid cross-group view.

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- No database migrations needed — all changes are application-level logic
- `chat-types` does NOT need changes — `GLOBAL_GROUP_ACCESS_ROLES` and `hasGlobalGroupAccess()` already exist
- The `canAccessGroup()` function interface must NOT be modified (FR-010)
- Chat frontend (`chat-frontend`) is explicitly unaffected — no tasks needed there

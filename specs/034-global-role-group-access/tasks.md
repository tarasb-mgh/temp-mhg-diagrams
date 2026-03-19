# Tasks: Global Role Group Access

**Input**: Design documents from `/specs/034-global-role-group-access/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, quickstart.md

**Tests**: Tests are included as verification tasks where the spec requires explicit behavioral guarantees (FR-005, SC-001–SC-006).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **chat-types**: `D:\src\MHG\chat-types\src\`
- **chat-backend**: `D:\src\MHG\chat-backend\src\`
- **workbench-frontend**: `D:\src\MHG\workbench-frontend\src\`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create feature branches in all affected repositories and publish shared types

- [x] T001 Create feature branch `034-global-role-group-access` from `develop` in `chat-types` at `D:\src\MHG\chat-types`
- [x] T002 [P] Create feature branch `034-global-role-group-access` from `develop` in `chat-backend` at `D:\src\MHG\chat-backend`
- [x] T003 [P] Create feature branch `034-global-role-group-access` from `develop` in `workbench-frontend` at `D:\src\MHG\workbench-frontend`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Shared types constant and centralized access resolution function that ALL user stories depend on

**CRITICAL**: No user story work can begin until this phase is complete

- [x] T004 Add `GLOBAL_GROUP_ACCESS_ROLES` constant (array of `UserRole.RESEARCHER`, `UserRole.SUPERVISOR`, `UserRole.MODERATOR`, `UserRole.OWNER`) and `hasGlobalGroupAccess(role: UserRole): boolean` helper to `D:\src\MHG\chat-types\src\rbac.ts`
- [x] T005 Bump `chat-types` package version in `D:\src\MHG\chat-types\package.json`, build, and publish to GitHub Packages
- [x] T006 Update `@mentalhelpglobal/chat-types` dependency to latest version in `D:\src\MHG\chat-backend\package.json` and run `npm install`
- [x] T007 Create `D:\src\MHG\chat-backend\src\services\groupAccess.service.ts` with `canAccessGroup(userId, groupId, userRole)` function returning `{ granted: boolean, accessType: 'membership' | 'global_role' | null }`. Resolution logic: (1) check group not archived (`archived_at IS NOT NULL` → deny), (2) if role in `GLOBAL_GROUP_ACCESS_ROLES` → grant with `global_role`, (3) query `group_memberships` for active membership → grant with `membership`, (4) deny
- [x] T008 Write unit tests for `canAccessGroup()` in `D:\src\MHG\chat-backend\src\services\__tests__\groupAccess.service.test.ts` covering: global role grants access, membership grants access, QA Specialist denied without membership, archived group denied for all roles, dual-path user (role + membership) returns `membership` access type, role downgrade scenario (user was Researcher → changed to QA Specialist → canAccessGroup returns denied for non-member group) (FR-008), role removal preserves membership (user has Researcher role + membership → role downgraded to QA Specialist → canAccessGroup still grants via membership path) (FR-010)

**Checkpoint**: Foundation ready — `canAccessGroup()` is available for all route updates

---

## Phase 3: User Story 1 — Researcher Reviews Sessions Across All Groups (Priority: P1) MVP

**Goal**: A Researcher with zero group memberships can select any group in the workbench and review sessions from that group

**Independent Test**: Log in as a Researcher with no group memberships. Verify the group selector lists all groups. Select a group, view review queue, submit a review.

### Implementation for User Story 1

- [x] T009 [US1] Update `D:\src\MHG\chat-backend\src\services\reviewQueue.service.ts` — remove `canAccessGroupScopedQueue()` function; replace all internal references with import of `canAccessGroup()` from `groupAccess.service.ts`
- [x] T010 [US1] Update `D:\src\MHG\chat-backend\src\routes\review.queue.ts` — replace the inline `REVIEW_CROSS_GROUP` / `OWNER` check + `canAccessGroupScopedQueue()` call (lines 38-50) with a single `canAccessGroup(req.user.id, groupId, req.user.role)` call; return 403 if denied
- [x] T011 [US1] Update `D:\src\MHG\chat-backend\src\routes\review.sessions.ts` — replace the group access check (lines 74-83) with `canAccessGroup()` call; return 403 if denied
- [x] T012 [US1] Update `D:\src\MHG\chat-backend\src\services\groupMembership.service.ts` — modify `setActiveGroup()` (lines 95-130) to skip membership validation when `hasGlobalGroupAccess(userRole)` returns true; still validate group exists and is not archived
- [x] T013 [US1] Update `D:\src\MHG\chat-backend\src\routes\admin.groups.ts` — widen permission gate on `GET /api/admin/groups` (line 26-28) to also allow users with `WORKBENCH_GROUP_DASHBOARD` permission, enabling Researchers to list all groups

**Checkpoint**: Researcher can select any group and review sessions. Core access resolution is working.

---

## Phase 4: User Story 2 — Supervisor Configures Any Group's Review Policy (Priority: P1)

**Goal**: A Supervisor with zero group memberships can access any group's configuration panel and modify supervision policy, reviewer count, and survey ordering

**Independent Test**: Log in as a Supervisor with no group memberships. Navigate to a group's config panel. Change supervision policy from "none" to "sampled" at 20%. Verify it persists.

### Implementation for User Story 2

- [x] T014 [US2] Update `D:\src\MHG\chat-backend\src\routes\group.ts` — in the `requireGroupAdmin(req)` function (lines 44-59), add a check: if `hasGlobalGroupAccess(req.user.role)` return the groupId without requiring group admin membership. This grants Supervisors+ access to group dashboard, users, and configuration endpoints
- [x] T015 [US2] Update `D:\src\MHG\chat-backend\src\routes\group.ts` — verify that `GET /api/group/dashboard` and `GET /api/group/me` endpoints work for Researcher+ roles accessing non-member groups by confirming `resolveGroupId(req)` uses the user's `active_group_id` which was set via the updated `setActiveGroup()` in T012

**Checkpoint**: Supervisor can configure any group's review policy without membership.

---

## Phase 5: User Story 3 — Owner Has Full Access to All Groups (Priority: P1)

**Goal**: Owner has unrestricted access to every group's workbench features and does NOT appear in group member lists

**Independent Test**: Log in as Owner with no group memberships. Access all group features. Verify member list for any group does not include the Owner.

### Implementation for User Story 3

- [x] T016 [US3] Verify `D:\src\MHG\chat-backend\src\routes\admin.groups.ts` — confirm that `GET /api/admin/groups/:groupId/members` endpoint queries only `group_memberships` table and never includes users without explicit membership records. No code change expected — add assertion comment documenting FR-005 invariant
- [x] T017 [US3] Verify `D:\src\MHG\chat-backend\src\routes\group.ts` — confirm that `GET /api/group/users` endpoint returns only explicit group members. No code change expected — add assertion comment documenting FR-005 invariant
- [x] T018 [US3] Write unit test in `D:\src\MHG\chat-backend\src\services\__tests__\groupAccess.service.test.ts` asserting that a user with Owner role and no `group_memberships` record does NOT appear in the result set of member list queries (FR-005)

**Checkpoint**: Owner access verified end-to-end. Member list exclusion confirmed by test.

---

## Phase 6: User Story 4 — Moderator Manages Escalations Across Groups (Priority: P2)

**Goal**: A Moderator can access escalation queues and approve deanonymization requests for groups they are not a member of

**Independent Test**: Log in as Moderator with no group memberships. Filter escalation queue to a specific group. Process an escalation. Approve a deanonymization request.

### Implementation for User Story 4

- [x] T019 [US4] Update `D:\src\MHG\chat-backend\src\routes\review.deanonymize.ts` (or equivalent deanonymization route) — add `canAccessGroup()` check so that Moderators can approve deanonymization requests for sessions in groups they are not members of; return 403 if denied

**Checkpoint**: Moderator can manage escalations and deanonymization across all groups.

---

## Phase 7: User Story 5 — QA Specialist Remains Group-Gated (Priority: P2)

**Goal**: QA Specialists continue to see only their explicitly assigned groups; they do NOT receive implicit cross-group access

**Independent Test**: Log in as QA Specialist with membership in Group A only. Verify group selector shows only Group A. Log in with zero memberships — verify empty selector.

### Implementation for User Story 5

- [x] T020 [US5] Write unit test in `D:\src\MHG\chat-backend\src\services\__tests__\groupAccess.service.test.ts` asserting that `canAccessGroup()` returns `{ granted: false }` for a QA Specialist accessing a group they are not a member of
- [x] T021 [US5] Write unit test asserting that `canAccessGroup()` returns `{ granted: true, accessType: 'membership' }` for a QA Specialist accessing a group they ARE a member of

**Checkpoint**: Negative test confirmed — QA Specialists are correctly excluded from implicit access.

---

## Phase 8: User Story 6 — Audit Trail Distinguishes Access Type (Priority: P3)

**Goal**: Audit log entries for group-scoped workbench actions include an `access_type` field distinguishing role-based from membership-based access

**Independent Test**: As Supervisor (non-member of Group X), modify Group X's config. Check audit log entry has `access_type: "global_role"`. As Researcher (member of Group Y), submit review in Group Y. Check audit log entry has `access_type: "membership"`.

### Implementation for User Story 6

- [x] T022 [US6] Update `D:\src\MHG\chat-backend\src\routes\group.ts` — after `canAccessGroup()` resolves, pass `access_type` from the result into the `details` parameter of all `logAuditEvent()` calls for group-scoped actions (group.active_set, group config changes)
- [x] T023 [P] [US6] Update `D:\src\MHG\chat-backend\src\routes\review.queue.ts` — pass `access_type` into `details` of audit log calls for review-scoped actions
- [x] T024 [P] [US6] Update `D:\src\MHG\chat-backend\src\routes\review.sessions.ts` — pass `access_type` into `details` of audit log calls
- [x] T025 [P] [US6] Update `D:\src\MHG\chat-backend\src\routes\review.deanonymize.ts` — pass `access_type` into `details` of audit log calls for deanonymization actions

**Checkpoint**: All group-scoped audit entries include access_type field.

---

## Phase 9: Frontend (Workbench Group Selector)

**Purpose**: Update the workbench group selector to show all groups for Researcher+ roles

- [x] T026 Update `@mentalhelpglobal/chat-types` dependency to latest version in `D:\src\MHG\workbench-frontend\package.json` and run `npm install`
- [x] T027 Update `D:\src\MHG\workbench-frontend\src\features\workbench\components\GroupScopeSelector.tsx` — import `hasGlobalGroupAccess` from `@mentalhelpglobal/chat-types`; for users where `hasGlobalGroupAccess(user.role)` is true, always call `adminGroupsApi.list()` to load all groups regardless of membership count; for QA Specialists, keep existing behavior (show only membership-based groups)

**Checkpoint**: Researcher+ users see all groups in the selector. QA Specialists see only their assigned groups.

---

## Phase 10: Polish & Cross-Cutting Concerns

**Purpose**: Final verification, documentation updates, and cleanup

- [x] T028 Run all Vitest tests in `D:\src\MHG\chat-backend` and verify 0 failures
- [ ] T029 [PENDING: manual verification post-deploy] Manual verification on dev environment per quickstart.md test flow: log in as Researcher (zero memberships) → verify group selector → select group → review session → check audit log
- [ ] T030 [PENDING: manual verification post-deploy] Manual negative test: log in as QA Specialist (zero memberships) → verify empty selector → verify no group access
- [ ] T031 [PENDING: manual verification post-deploy] Verify chat frontend regression (SC-006): log in as a regular user on `https://dev.mentalhelp.chat`, confirm group selector shows only member groups and chat participation works normally — no behavioral change from this feature
- [x] T032 Update `specs/034-global-role-group-access/tasks.md` — mark all tasks complete

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion — BLOCKS all user stories
- **US1 (Phase 3)**: Depends on Foundational — core route updates
- **US2 (Phase 4)**: Depends on Foundational — can run in parallel with US1
- **US3 (Phase 5)**: Depends on Foundational — verification tasks, can run in parallel with US1/US2
- **US4 (Phase 6)**: Depends on Foundational — can run in parallel with US1/US2/US3
- **US5 (Phase 7)**: Depends on Foundational — negative test, can run in parallel
- **US6 (Phase 8)**: Depends on US1/US2/US4 completion (needs routes updated first for audit integration)
- **Frontend (Phase 9)**: Depends on Foundational (types published) — can run in parallel with backend phases
- **Polish (Phase 10)**: Depends on all previous phases

### User Story Dependencies

- **US1 (P1)**: Can start after Foundational — no dependencies on other stories
- **US2 (P1)**: Can start after Foundational — shares `requireGroupAdmin()` update but independent of US1
- **US3 (P1)**: Can start after Foundational — verification only, no cross-story dependencies
- **US4 (P2)**: Can start after Foundational — independent deanonymization route
- **US5 (P2)**: Can start after Foundational — test-only, no implementation dependencies
- **US6 (P3)**: Depends on US1, US2, US4 routes being updated (audit calls need `access_type` from `canAccessGroup()`)

### Parallel Opportunities

- T001, T002, T003 can run in parallel (branch creation in different repos)
- T009, T010, T011 can run in parallel (different route files)
- US1, US2, US3, US4, US5 can all run in parallel after Foundational
- US6 tasks T023, T024, T025 can run in parallel (different route files)
- Phase 9 (frontend) can run in parallel with all backend phases after T005

---

## Parallel Example: User Story 1

```bash
# After Foundational complete, launch review route updates together:
Task: "T010 [US1] Update review.queue.ts — replace access check with canAccessGroup()"
Task: "T011 [US1] Update review.sessions.ts — replace access check with canAccessGroup()"
```

## Parallel Example: User Story 6 (Audit)

```bash
# After US1/US2/US4 routes updated, launch audit updates together:
Task: "T023 [US6] Update review.queue.ts — pass access_type to audit log"
Task: "T024 [US6] Update review.sessions.ts — pass access_type to audit log"
Task: "T025 [US6] Update review.deanonymize.ts — pass access_type to audit log"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (branches)
2. Complete Phase 2: Foundational (types + canAccessGroup)
3. Complete Phase 3: User Story 1 (review access)
4. Complete Phase 9: Frontend (group selector)
5. **STOP and VALIDATE**: Researcher can select any group and review sessions
6. Deploy to dev if ready

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. US1 + Frontend → Researcher cross-group review (MVP!)
3. US2 → Supervisor cross-group configuration
4. US3 → Owner verification + FR-005 member list test
5. US4 → Moderator deanonymization access
6. US5 → QA Specialist negative test
7. US6 → Audit trail access_type
8. Polish → Final verification

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- No database migrations needed — all changes are application-level logic
- The `canAccessGroup()` function in T007 is the single point of change for the access rule
- Tests in T008, T018, T020, T021 verify the core behavioral guarantees
- Chat frontend (`chat-frontend`) is explicitly unaffected — no tasks needed there

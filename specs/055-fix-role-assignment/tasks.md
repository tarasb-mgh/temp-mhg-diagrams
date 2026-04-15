# Tasks: 055-fix-role-assignment

**Input**: Design documents from `/specs/055-fix-role-assignment/`  
**Prerequisites**: plan.md, spec.md, research.md, data-model.md  
**Jira Epic**: [MTB-1351](https://mentalhelpglobal.atlassian.net/browse/MTB-1351)

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3, US4)
- All file paths relative to `chat-backend/`

---

## Phase 1: Database Fix

**Purpose**: Extend the PostgreSQL CHECK constraint on `users.role` to include all roles from the `UserRole` enum

- [x] T001 [P] Create migration `src/db/migrations/063_055-extend-user-role-constraint.sql` — drop existing `users_role_check` constraint and recreate with all 10 roles (user, qa_specialist, researcher, supervisor, moderator, group_admin, owner, expert, admin, master)
- [x] T002 [P] Update reference schema `src/db/schema.sql` — change `valid_role` CHECK constraint to include supervisor, expert, admin, master

**Checkpoint**: Database layer now accepts all 10 roles defined in the `UserRole` enum

---

## Phase 2: US1 — Owner Assigns Expert Role (Priority: P1) + US2 — Owner Assigns Admin/Master Roles (Priority: P1) + US4 — Existing Roles Continue to Work (Priority: P1) — MTB-1358

**Goal**: Verify that role assignment works for all 10 roles — both new (expert, admin, master) and existing (7 legacy roles)

**Independent Test**: Log in as Owner, navigate to a user's profile, change their role to Expert/Admin/Master, confirm 200 response and role persists on reload. Repeat with legacy roles to confirm no regression.

> Note: US1, US2, and US4 share the same fix (T001) and are validated together because the migration is the single fix point for all three stories.

### Regression Tests

- [x] T003 [P] [US1] Write regression test for `changeUserRole` returning the updated user with Expert role in `tests/unit/changeUserRole.test.ts`
- [x] T004 [P] [US2] Write regression test for `changeUserRole` returning the updated user with Admin and Master roles in `tests/unit/changeUserRole.test.ts`
- [x] T005 [P] [US4] Write parameterized regression tests for `changeUserRole` covering all 7 legacy roles in `tests/unit/changeUserRole.test.ts`
- [x] T006 [P] [US1] Write test for `changeUserRole` returning null when target user does not exist in `tests/unit/changeUserRole.test.ts`
- [x] T007 [P] [US1] Write test for `changeUserRole` logging audit event with previous and new role in `tests/unit/changeUserRole.test.ts`
- [x] T008 [P] [US1] Write test for `changeUserRole` returning null when UPDATE returns no rows in `tests/unit/changeUserRole.test.ts`

### Validation

- [x] T009 Run full test suite (`npm test`) and confirm all 512 tests pass with 0 failures

**Checkpoint**: All P1 user stories validated — Expert, Admin, Master role assignment works; legacy roles unaffected

---

## Phase 3: US3 — Owner Creates User with New Role (Priority: P2) — MTB-1359

**Goal**: Confirm that user creation with new roles also works (same migration fixes this path)

**Independent Test**: Open Create User modal, select Expert as role, submit form, verify user is created with Expert role.

- [x] T010 [US3] Deploy `chat-backend` to dev environment via workflow_dispatch from feature branch and verify user creation with Expert role via the Create User modal at `https://workbench.dev.mentalhelp.chat/workbench/users`

**Checkpoint**: User creation with new roles works end-to-end on dev

---

## Phase 4: Polish & Cross-Cutting Concerns

**Purpose**: Final validation, PR, and deployment

- [x] T011 Open PR from `055-fix-role-assignment` to `develop` in `chat-backend` with scope, test evidence, and migration details
- [x] T012 Add YAML regression test case to `regression-suite/` covering role assignment for new roles (expert, admin, master) via Workbench UI

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Database Fix)**: No dependencies — can start immediately
- **Phase 2 (Tests + Validation)**: Depends on Phase 1 (T001, T002)
- **Phase 3 (Dev Validation)**: Depends on Phase 1 deployment to dev
- **Phase 4 (Polish)**: Depends on Phase 2 and Phase 3 completion

### User Story Dependencies

- **US1 (Expert role)**: Fixed by T001, tested by T003/T006/T007/T008
- **US2 (Admin/Master roles)**: Fixed by T001, tested by T004
- **US3 (Create user with new role)**: Fixed by T001, validated by T010
- **US4 (Legacy roles)**: Unaffected by T001, regression-tested by T005

### Parallel Opportunities

- T001 and T002 can run in parallel (different files)
- T003–T008 can all run in parallel (same file but independent test cases)
- T011 and T012 can run in parallel

---

## Implementation Strategy

### MVP (Phase 1 + Phase 2)

1. Apply migration T001 + schema update T002
2. Run regression tests T003–T009
3. **STOP and VALIDATE**: All role assignments work at the service layer

### Full Delivery

1. MVP above
2. Deploy to dev (T010) and validate via UI
3. Open PR (T011) and add regression suite coverage (T012)

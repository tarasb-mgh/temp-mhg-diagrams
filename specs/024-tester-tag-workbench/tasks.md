# Tasks: Workbench Tester Tag Assignment UI

**Jira Epic**: [MTB-692](https://mentalhelpglobal.atlassian.net/browse/MTB-692)
**Input**: Design documents from `/specs/024-tester-tag-workbench/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

## Jira Ticket Mapping

- `MTB-693` - Shared tester-tag contracts, permissions, and client helpers
- `MTB-694` - Backend tester-tag route, service, persistence, and authorization foundation
- `MTB-695` - Dedicated workbench page for assigning the tester tag
- `MTB-696` - Read-only tester status on the user profile
- `MTB-697` - Tester-tag removal flow on the management page
- `MTB-698` - Access gating and blocked assignment for ineligible end-user accounts
- `MTB-699` - Accessibility and responsive refinements for tester-tag management surfaces
- `MTB-700` - Playwright coverage and screenshot evidence
- `MTB-701` - Quickstart, validation, audit, and security-review evidence

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g. `[US1]`, `[US2]`, `[US3]`)
- Include exact file paths in descriptions

## Path Conventions

- `chat-types/src/` — shared TypeScript types and permission constants
- `chat-backend/src/` — Express backend routes, services, and middleware
- `chat-frontend-common/src/` — shared frontend API and permission helpers
- `workbench-frontend/src/` — workbench React UI
- `chat-ui/tests/e2e/` — Playwright end-to-end coverage

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Prepare the affected split repositories and shared surfaces for the feature

- [X] T001 Create feature branch `024-tester-tag-workbench` in `chat-types/`, `chat-backend/`, `chat-frontend-common/`, `workbench-frontend/`, and `chat-ui/` — local setup only
- [X] T002 [P] Add or confirm tester-tag request/response DTOs in `chat-types/src/tags.ts` for dedicated tester-tag management and profile visibility — MTB-693
- [X] T003 [P] Add or confirm `Admin`, `Supervisor`, and `Owner` tester-tag management permission constants in `chat-types/src/rbac.ts` — MTB-693
- [X] T004 [P] Scaffold shared tester-tag client helpers in `chat-frontend-common/src/api/testerTag.ts` and `chat-frontend-common/src/permissions/workbenchPermissions.ts` — MTB-693

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core backend and routing prerequisites that block all user stories

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T005 Create dedicated tester-tag route surface in `chat-backend/src/routes/admin.testerTags.ts` — MTB-694
- [X] T006 Create tester-tag domain service in `chat-backend/src/services/testerTag.service.ts` — MTB-694
- [X] T007 Update tester-tag persistence behavior in `chat-backend/src/services/userTag.service.ts` to support idempotent assign/remove operations without duplicate tag records — MTB-694
- [X] T008 Modify authorization enforcement in `chat-backend/src/middleware/reviewAuth.ts` — MTB-694
- [X] T009 Add the dedicated tester-tag management route entry in `workbench-frontend/src/router/routes.tsx` — MTB-695

**Checkpoint**: Shared types, backend route/service base, permissions, and frontend route shell are ready

---

## Phase 3: User Story 1 - Assign Tester Tag From Dedicated Management Page (Priority: P1) 🎯 MVP

**Goal**: Authorized users can assign the `tester` tag from a dedicated workbench page, and the assigned state becomes visible on the user profile

**Independent Test**: Open the dedicated tester-tag management page as `Admin`, `Supervisor`, or `Owner`, assign the `tester` tag to an eligible internal user, save, reload, and verify the user profile shows the assigned tester status.

### Implementation for User Story 1

- [X] T010 [US1] Implement list and detail read handlers for tester-tag management in `chat-backend/src/routes/admin.testerTags.ts` and `chat-backend/src/services/testerTag.service.ts` — MTB-695
- [X] T011 [US1] Implement assign tester-tag handler with eligibility validation in `chat-backend/src/routes/admin.testerTags.ts` and `chat-backend/src/services/testerTag.service.ts` — MTB-695
- [X] T012 [P] [US1] Create the dedicated management page container in `workbench-frontend/src/features/users/TesterTagManagementPage.tsx` — MTB-695
- [X] T013 [P] [US1] Create assignment controls in `workbench-frontend/src/features/users/components/TesterTagAssignmentCard.tsx` — MTB-695
- [X] T014 [P] [US1] Create eligibility and internal-use guidance messaging in `workbench-frontend/src/features/users/components/TesterEligibilityNotice.tsx` — MTB-695
- [X] T015 [US1] Implement page-level API integration in `workbench-frontend/src/features/users/services/testerTagApi.ts` — MTB-695
- [X] T016 [US1] Wire assignment flow, authorized-page loading, and save refresh behavior in `workbench-frontend/src/features/users/TesterTagManagementPage.tsx` — MTB-695
- [X] T017 [US1] Add read-only tester status visibility to `workbench-frontend/src/features/userProfile/UserProfileView.tsx` — MTB-696
- [X] T018 [US1] Add dedicated page and profile-status translations in `workbench-frontend/src/locales/en/users.json`, `workbench-frontend/src/locales/uk/users.json`, and `workbench-frontend/src/locales/ru/users.json` — MTB-695
- [X] T019 [US1] Expose tester-tag status for user profile rendering in `chat-backend/src/routes/admin.testerTags.ts` or the existing user-profile route used by `workbench-frontend/src/features/userProfile/UserProfileView.tsx` — MTB-696
- [X] T020 [US1] Wire user profile tester-status data loading in `workbench-frontend/src/features/userProfile/UserProfileView.tsx` — MTB-696

**Checkpoint**: Authorized users can assign the tester tag from the dedicated page, and profiles show the assigned state

---

## Phase 4: User Story 2 - Remove Tester Tag From Dedicated Management Page (Priority: P1)

**Goal**: Authorized users can remove the `tester` tag from the same dedicated page, and future chat access no longer behaves as tester-tagged

**Independent Test**: Open the dedicated tester-tag management page for a tester-tagged eligible user, remove the `tester` tag, save, reload, and verify the user profile no longer shows tester status.

### Implementation for User Story 2

- [X] T021 [US2] Implement remove tester-tag handler with idempotent behavior in `chat-backend/src/routes/admin.testerTags.ts` and `chat-backend/src/services/testerTag.service.ts` — MTB-697
- [X] T022 [US2] Add remove-state controls and status transitions in `workbench-frontend/src/features/users/components/TesterTagAssignmentCard.tsx` — MTB-697
- [X] T023 [US2] Update page refresh and cleared-status rendering in `workbench-frontend/src/features/users/TesterTagManagementPage.tsx` and `workbench-frontend/src/features/userProfile/UserProfileView.tsx` — MTB-697

**Checkpoint**: Authorized users can remove the tester tag and the profile reflects the cleared state

---

## Phase 5: User Story 3 - Safe And Understandable Tester Tag Management (Priority: P2)

**Goal**: The dedicated page is access-restricted, blocks assignment for regular end-user accounts, and clearly communicates internal-only tester usage while remaining future-expandable

**Independent Test**: Verify unauthorized roles cannot access the dedicated page, regular end-user accounts cannot receive the tester tag, and the page/profile clearly communicate current tester status and internal-use rules.

### Implementation for User Story 3

- [X] T024 [P] [US3] Create a reusable visible status badge in `workbench-frontend/src/features/users/components/TesterStatusBadge.tsx` — MTB-699
- [X] T025 [US3] Enforce dedicated-page access gating in `chat-frontend-common/src/permissions/workbenchPermissions.ts` and `workbench-frontend/src/router/routes.tsx` — MTB-698
- [X] T026 [US3] Implement blocked-assignment states for regular end-user accounts in `chat-backend/src/services/testerTag.service.ts` and `workbench-frontend/src/features/users/components/TesterEligibilityNotice.tsx` — MTB-698
- [X] T027 [US3] Refine future-expandable page structure and tester-only page language in `workbench-frontend/src/features/users/TesterTagManagementPage.tsx` — MTB-698
- [X] T028 [US3] Integrate visible tester-status badge presentation in `workbench-frontend/src/features/userProfile/UserProfileView.tsx` and `workbench-frontend/src/features/users/components/TesterStatusBadge.tsx` — MTB-696
- [X] T029 [US3] Add keyboard navigation, focus handling, and screen-reader labels to `workbench-frontend/src/features/users/TesterTagManagementPage.tsx`, `workbench-frontend/src/features/users/components/TesterTagAssignmentCard.tsx`, and `workbench-frontend/src/features/users/components/TesterStatusBadge.tsx` — MTB-699
- [X] T030 [US3] Validate accessible text, status announcements, and read-only tester visibility semantics in `workbench-frontend/src/features/userProfile/UserProfileView.tsx` and `workbench-frontend/src/features/users/components/TesterStatusBadge.tsx` — MTB-699

**Checkpoint**: The management flow is safe, access-restricted, and understandable, while remaining scoped to `tester` in this release

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Cross-story verification and regression coverage

- [X] T031 [P] Validate responsive behavior of `workbench-frontend/src/features/users/TesterTagManagementPage.tsx` and `workbench-frontend/src/features/userProfile/UserProfileView.tsx` across common workbench breakpoints — MTB-699
- [X] T032 [P] Add dedicated Playwright coverage for page access, assign, remove, blocked assignment, and profile visibility in `chat-ui/tests/e2e/workbench/tester-tag-management.spec.ts` — MTB-700
- [X] T033 [P] Capture Playwright screenshots for the dedicated tester-tag management page and user profile tester-status view in `chat-ui/tests/e2e/workbench/tester-tag-management.spec.ts` — MTB-700
- [X] T034 Update user-facing documentation for tester-tag management workflow and visible profile status using `specs/024-tester-tag-workbench/quickstart.md` — MTB-701
- [X] T035 Run quickstart validation from `specs/024-tester-tag-workbench/quickstart.md` against `chat-backend/`, `workbench-frontend/`, and `chat-ui/` — MTB-701

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational completion
- **User Story 2 (Phase 4)**: Depends on User Story 1 backend/page flow being available
- **User Story 3 (Phase 5)**: Depends on Foundational completion and integrates with User Story 1 page/profile surfaces
- **Polish (Phase 6)**: Depends on all desired user stories being complete

### User Story Dependencies

- **US1 (P1)**: Can start after Foundational - MVP for dedicated page assignment flow
- **US2 (P1)**: Depends on US1 because removal reuses the same dedicated page and tester-state projection
- **US3 (P2)**: Depends on US1 page/profile surfaces and can proceed after US1 core flow exists

### Within Each User Story

- Backend handlers before frontend integration
- Shared/reusable UI components before parent page integration
- Page flow before profile visibility refinement
- Story checkpoint validation before moving to the next dependent story

### Parallel Opportunities

- `T002`, `T003`, and `T004` can run in parallel during Setup
- `T012`, `T013`, and `T014` can run in parallel within US1
- `T024` can run in parallel with backend blocking logic in `T026`
- Final Playwright coverage `T032` can be prepared while final integration is stabilizing

---

## Parallel Example: User Story 1

```bash
# Parallel UI component work for US1:
T012: Create the dedicated management page container in workbench-frontend/src/features/users/TesterTagManagementPage.tsx
T013: Create assignment controls in workbench-frontend/src/features/users/components/TesterTagAssignmentCard.tsx
T014: Create eligibility and internal-use guidance messaging in workbench-frontend/src/features/users/components/TesterEligibilityNotice.tsx
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Verify assignment works end-to-end and profile status is visible
5. Demo the dedicated page MVP before adding removal and safety refinements

### Incremental Delivery

1. Setup + Foundational → route, service, permissions, and route shell ready
2. Add US1 → dedicated page assignment flow and visible profile status
3. Add US2 → removal behavior on the same page
4. Add US3 → access restriction, blocked-assignment safety, accessibility, and future-expandable page structure
5. Finish with responsive verification, Playwright evidence, documentation updates, and quickstart validation

### Parallel Team Strategy

1. Developer A: backend route/service work in `chat-backend/src/routes/admin.testerTags.ts` and `chat-backend/src/services/testerTag.service.ts`
2. Developer B: workbench dedicated page and components in `workbench-frontend/src/features/users/`
3. Developer C: profile visibility and routing/permission updates in `workbench-frontend/src/features/userProfile/`, `workbench-frontend/src/router/`, and `chat-frontend-common/src/permissions/`
4. Developer D: final E2E coverage and screenshot capture in `chat-ui/tests/e2e/workbench/tester-tag-management.spec.ts`

---

## Notes

- [P] tasks = different files, no blocking dependency on incomplete tasks
- `[US1]`, `[US2]`, `[US3]` labels map tasks directly to the specification user stories
- User Story 1 is the recommended MVP scope
- This release manages only the `tester` tag; do not expand tasks into generic tag management
- User profile visibility is read-only; all tester-tag changes must stay on the dedicated management page

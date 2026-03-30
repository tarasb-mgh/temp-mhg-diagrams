# Tasks: Unified Workbench Tag Center

**Input**: Design documents from `/specs/042-workbench-tag-center/`  
**Prerequisites**: `plan.md` (required), `spec.md` (required), `research.md`, `data-model.md`, `contracts/tag-center-api.yaml`, `quickstart.md`

**Tests**: Test tasks are included because the specification explicitly requires repeatable validation coverage and mandatory Playwright E2E flows.

**Organization**: Tasks are grouped by user story so each story can be implemented and validated independently.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no blocking dependency)
- **[Story]**: User story label (`US1`, `US2`, `US3`, `US4`)
- All task descriptions include concrete file paths

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Prepare shared contracts, feature scaffolding, and baseline files across split repositories.

- [X] T001 Sync shared tag-center DTO contracts in `chat-types/src/tags.ts` — MTB-1054
- [X] T002 [P] Add unified tag-center API client surface in `chat-frontend-common/src/api/tagCenter.ts` — MTB-1055
- [X] T003 [P] Add rights-management helper exports in `chat-frontend-common/src/permissions/workbenchPermissions.ts` — MTB-1056
- [X] T004 Create feature route scaffold for Tag Center in `workbench-frontend/src/router/routes.tsx` — MTB-1057
- [X] T005 [P] Add base localization key scaffolding in `workbench-frontend/src/locales/en/tags.json`, `workbench-frontend/src/locales/uk/tags.json`, and `workbench-frontend/src/locales/ru/tags.json` — MTB-1058

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core backend/frontend foundations that must be complete before user-story implementation.

**⚠️ CRITICAL**: No user-story phase should start until these tasks are complete.

- [X] T006 Implement unified backend route registration for Tag Center in `chat-backend/src/routes/admin.tagCenter.ts` and route wiring in `chat-backend/src/index.ts` — MTB-1059
- [X] T007 [P] Implement shared failure-meaning mapping (`invalid input`, `insufficient permission`, `missing target`, `conflicting state`) in `chat-backend/src/services/tagCenter.service.ts` — MTB-1060
- [X] T008 [P] Implement shared delete-block response shape with `message` + `nextAction` in `chat-backend/src/services/tagCenter.service.ts` — MTB-1061
- [X] T009 Implement Tag Center page shell with mode switch (`User Tags`, `Review Tags`) in `workbench-frontend/src/features/tags/TagCenterPage.tsx` — MTB-1062
- [X] T010 [P] Add Tag Center navigation entry and remove legacy links in `workbench-frontend/src/features/workbench/WorkbenchLayout.tsx` — MTB-1063
- [X] T011 [P] Deprecate tester-specific backend route/service wiring in `chat-backend/src/routes/admin.testerTags.ts` and `chat-backend/src/services/testerTag.service.ts` by redirecting usage to unified tag-center flow — MTB-1064
- [X] T012 [P] Deprecate tester-specific frontend API usage by migrating references from `chat-frontend-common/src/api/testerTag.ts` to `chat-frontend-common/src/api/tagCenter.ts` — MTB-1065
- [X] T013 [P] Create Playwright spec scaffold for tag-center flows in `chat-ui/tests/e2e/workbench/tag-center.spec.ts` — MTB-1066

**Checkpoint**: Foundation complete - story phases can proceed.

---

## Phase 3: User Story 1 - Manage User Tags and Assignments in One Place (Priority: P1) 🎯 MVP

**Goal**: Deliver user-tag definition lifecycle and assignment workflows in `User Tags` mode.

**Independent Test**: Operator can create/edit/archive/unarchive a user tag, assign/unassign it to any user, and use case-insensitive AND-based search/filter in User Tags mode.

### Tests for User Story 1

- [X] T014 [P] [US1] Add backend integration tests for user-tag definition lifecycle and assignment behavior in `chat-backend/tests/integration/tag-center.user-tags.test.ts` — MTB-1067
- [X] T015 [P] [US1] Add frontend unit tests for User Tags mode interactions in `workbench-frontend/src/features/tags/__tests__/UserTagsMode.test.tsx` — MTB-1068
- [X] T016 [P] [US1] Add Playwright E2E flow for create/edit/archive/unarchive + assign/unassign in `chat-ui/tests/e2e/workbench/tag-center.spec.ts` — MTB-1069

### Implementation for User Story 1

- [X] T017 [US1] Implement user-scope definition endpoints (`GET/POST/PATCH/DELETE/archive/unarchive`) in `chat-backend/src/routes/admin.tagCenter.ts` — MTB-1070
- [X] T018 [US1] Implement user-scope definition lifecycle logic and active-assignment delete preconditions in `chat-backend/src/services/tagDefinition.service.ts` — MTB-1071
- [X] T019 [US1] Implement assignment/unassignment endpoint behavior (non-capability-gated, all users) in `chat-backend/src/services/userTag.service.ts` — MTB-1072
- [X] T020 [US1] Implement user search/filter semantics (case-insensitive partial + AND logic) in `chat-backend/src/services/tagCenter.service.ts` — MTB-1073
- [X] T021 [P] [US1] Implement User Tags mode definition list/editor components in `workbench-frontend/src/features/tags/components/UserTagDefinitionsPanel.tsx` — MTB-1074
- [X] T022 [P] [US1] Implement User Tags assignment panel and assignment mutations in `workbench-frontend/src/features/tags/components/UserTagAssignmentsPanel.tsx` — MTB-1075
- [X] T023 [US1] Wire User Tags mode client calls and state management in `workbench-frontend/src/features/tags/TagCenterPage.tsx` — MTB-1076
- [X] T024 [US1] Add localized User Tags copy and validation/error strings in `workbench-frontend/src/locales/en/tags.json`, `workbench-frontend/src/locales/uk/tags.json`, and `workbench-frontend/src/locales/ru/tags.json` — MTB-1077

**Checkpoint**: User Tags mode is independently functional and testable.

---

## Phase 4: User Story 2 - Manage Review Tags Separately from Same Entry Point (Priority: P1)

**Goal**: Deliver review-tag lifecycle in `Review Tags` mode with delete blocked for any active/historical reference.

**Independent Test**: Operator can create/edit/archive/unarchive review tags, and delete is blocked with actionable guidance when references exist.

### Tests for User Story 2

- [X] T025 [P] [US2] Add backend integration tests for review-tag lifecycle and delete guardrail in `chat-backend/tests/integration/tag-center.review-tags.test.ts` — MTB-1078
- [X] T026 [P] [US2] Add frontend unit tests for Review Tags mode separation and blocked-delete UX in `workbench-frontend/src/features/tags/__tests__/ReviewTagsMode.test.tsx` — MTB-1079
- [X] T027 [P] [US2] Add Playwright E2E flow for review-tag lifecycle and blocked-delete guidance in `chat-ui/tests/e2e/workbench/tag-center.spec.ts` — MTB-1080

### Implementation for User Story 2

- [X] T028 [US2] Implement review-scope definition endpoints in `chat-backend/src/routes/admin.tagCenter.ts` — MTB-1081
- [X] T029 [US2] Implement review-tag reference existence checks (active + historical) for delete preconditions in `chat-backend/src/services/tagCenter.service.ts` — MTB-1082
- [X] T030 [US2] Implement Review Tags mode definition list/editor components in `workbench-frontend/src/features/tags/components/ReviewTagDefinitionsPanel.tsx` — MTB-1083
- [X] T031 [US2] Wire Review Tags mode data loading and mutations in `workbench-frontend/src/features/tags/TagCenterPage.tsx` — MTB-1084
- [X] T032 [US2] Add localized Review Tags copy and delete-block guidance in `workbench-frontend/src/locales/en/tags.json`, `workbench-frontend/src/locales/uk/tags.json`, and `workbench-frontend/src/locales/ru/tags.json` — MTB-1085

**Checkpoint**: Review Tags mode is independently functional and testable.

---

## Phase 5: User Story 4 - Capability-Driven Access for Rights/Definitions (Priority: P1)

**Goal**: Enforce capability-based gating for rights-management and tag-definition actions, with consistent denial semantics.

**Independent Test**: Read-only users can view but not mutate gated actions; denied actions return consistent failure meaning and UI feedback.

### Tests for User Story 4

- [X] T033 [P] [US4] Add backend authorization tests for rights/definition actions in `chat-backend/tests/integration/tag-center.authz.test.ts` — MTB-1086
- [X] T034 [P] [US4] Add frontend gating tests for control visibility/disabled states in `workbench-frontend/src/features/tags/__tests__/TagCenterPermissions.test.tsx` — MTB-1087
- [X] T035 [P] [US4] Add Playwright E2E denied-action flows (read-only, denied write, cross-domain attempt) in `chat-ui/tests/e2e/workbench/tag-center.spec.ts` — MTB-1088

### Implementation for User Story 4

- [X] T036 [US4] Implement rights-management endpoints (`GET/PUT /rights`) in `chat-backend/src/routes/admin.tagCenter.ts` — MTB-1089
- [X] T037 [US4] Implement rights-management service rules (moderator-or-higher constraint) in `chat-backend/src/services/tagCenter.service.ts` — MTB-1090
- [X] T038 [US4] Apply capability checks to rights-management and definition lifecycle actions in `chat-backend/src/routes/admin.tagCenter.ts` — MTB-1091
- [X] T039 [US4] Implement frontend gated control behavior for definition and rights actions in `workbench-frontend/src/features/tags/TagCenterPage.tsx` — MTB-1092
- [X] T040 [US4] Implement localized denied-action messaging mapped to failure meanings in `workbench-frontend/src/locales/en/tags.json`, `workbench-frontend/src/locales/uk/tags.json`, and `workbench-frontend/src/locales/ru/tags.json` — MTB-1093

**Checkpoint**: Capability-gated action model is independently functional and testable.

---

## Phase 6: User Story 3 - Show All Assigned User Tags in User Profile (Priority: P2)

**Goal**: Display all assigned user tags in user profile using Tag Center source of truth.

**Independent Test**: After assigning multiple user tags, profile view shows complete assigned tag list and stays consistent after refresh.

### Tests for User Story 3

- [X] T041 [P] [US3] Add backend tests for profile tag projection endpoint in `chat-backend/tests/integration/user-profile-tags.test.ts` — MTB-1094
- [X] T042 [P] [US3] Add frontend tests for profile assigned-tag rendering in `workbench-frontend/src/features/users/__tests__/UserProfileTags.test.tsx` — MTB-1095
- [X] T043 [P] [US3] Add Playwright E2E profile visibility flow in `chat-ui/tests/e2e/workbench/tag-center.spec.ts` — MTB-1096

### Implementation for User Story 3

- [X] T044 [US3] Implement profile assigned-tags projection endpoint in `chat-backend/src/routes/user.profile.ts` — MTB-1097
- [X] T045 [US3] Implement profile tag projection query/service in `chat-backend/src/services/tagCenter.service.ts` — MTB-1098
- [X] T046 [US3] Render all assigned user tags in profile UI in `workbench-frontend/src/features/users/UserProfileView.tsx` — MTB-1099
- [X] T047 [US3] Add localized profile tag labels in `workbench-frontend/src/locales/en/users.json`, `workbench-frontend/src/locales/uk/users.json`, and `workbench-frontend/src/locales/ru/users.json` — MTB-1100

**Checkpoint**: User profile tag visibility is independently functional and testable.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Final consistency, reliability gate execution, and documentation alignment.

- [ ] T048 Run SC-003 reliability gate (10 consecutive runs per happy flow) and capture results in `chat-ui/tests/e2e/workbench/tag-center.spec.ts` artifacts — MTB-1105
- [ ] T049 [P] Verify quickstart end-to-end checklist and update evidence references in `specs/042-workbench-tag-center/quickstart.md` — MTB-1101
- [ ] T050 [P] Run accessibility audit (keyboard navigation, focus visibility, semantic labels, screen-reader behavior, WCAG AA contrast) for Tag Center and profile tags in `workbench-frontend/src/features/tags/TagCenterPage.tsx` and `workbench-frontend/src/features/users/UserProfileView.tsx` — MTB-1102
- [ ] T051 [P] Run responsive validation at 375px, 768px, and 1280px for Tag Center and profile tags in `chat-ui/tests/e2e/workbench/tag-center.spec.ts` — MTB-1103
- [ ] T052 [P] Verify workbench PWA installability and no regression in manifest/service worker behavior after Tag Center rollout using `workbench-frontend/public/manifest.json` and `chat-ui/tests/e2e/workbench/tag-center.spec.ts` — MTB-1104
- [ ] T053 [P] Update user-facing documentation scope notes in `specs/042-workbench-tag-center/plan.md` and `specs/042-workbench-tag-center/spec.md` if wording drift appears during implementation; if no wording drift is detected, record explicit \"no change required\" evidence in `specs/042-workbench-tag-center/quickstart.md` — MTB-1106
- [ ] T054 Final regression pass for Tag Center route/navigation consolidation in `workbench-frontend/src/router/routes.tsx` and `workbench-frontend/src/features/workbench/WorkbenchLayout.tsx` — MTB-1107

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: Starts immediately
- **Phase 2 (Foundational)**: Depends on Phase 1 and blocks all user stories
- **Phase 3 (US1)**: Depends on Phase 2
- **Phase 4 (US2)**: Depends on Phase 2; can run in parallel with US1
- **Phase 5 (US4)**: Depends on Phase 2; can run in parallel with US1/US2
- **Phase 6 (US3)**: Depends on Phase 3 completion (needs assignment flows), but can overlap late US2/US4 work
- **Phase 7 (Polish)**: Depends on all implemented story phases

### User Story Dependencies

- **US1 (P1)**: Primary MVP; no dependency on other stories after foundation
- **US2 (P1)**: Independent from US1 except shared foundation
- **US4 (P1)**: Cross-cutting gating; depends only on foundation and touches US1/US2 surfaces
- **US3 (P2)**: Depends on US1 assignment source of truth

### Parallel Opportunities

- Setup tasks marked `[P]` (T002, T003, T005) can run concurrently
- Foundational tasks marked `[P]` (T007, T008, T010, T011, T012, T013) can run concurrently
- Within US1: T014/T015/T016 and T021/T022 can run concurrently
- Within US2: T025/T026/T027 and T030/T032 can run concurrently
- Within US4: T033/T034/T035 and T039/T040 can run concurrently
- Within US3: T041/T042/T043 can run concurrently

---

## Parallel Example: User Story 1

```bash
# Run in parallel after T013:
Task: "T014 [US1] backend integration tests in chat-backend/tests/integration/tag-center.user-tags.test.ts"
Task: "T015 [US1] frontend unit tests in workbench-frontend/src/features/tags/__tests__/UserTagsMode.test.tsx"
Task: "T016 [US1] Playwright flow in chat-ui/tests/e2e/workbench/tag-center.spec.ts"

# Run in parallel after T020:
Task: "T021 [US1] UserTagDefinitionsPanel in workbench-frontend/src/features/tags/components/UserTagDefinitionsPanel.tsx"
Task: "T022 [US1] UserTagAssignmentsPanel in workbench-frontend/src/features/tags/components/UserTagAssignmentsPanel.tsx"
```

## Parallel Example: User Story 2

```bash
# Run in parallel after T029:
Task: "T026 [US2] frontend unit tests in workbench-frontend/src/features/tags/__tests__/ReviewTagsMode.test.tsx"
Task: "T027 [US2] Playwright review-tag guardrail flow in chat-ui/tests/e2e/workbench/tag-center.spec.ts"
Task: "T030 [US2] ReviewTagDefinitionsPanel in workbench-frontend/src/features/tags/components/ReviewTagDefinitionsPanel.tsx"
```

## Parallel Example: User Story 4

```bash
# Run in parallel after T038:
Task: "T034 [US4] UI gating tests in workbench-frontend/src/features/tags/__tests__/TagCenterPermissions.test.tsx"
Task: "T035 [US4] denied-action E2E flows in chat-ui/tests/e2e/workbench/tag-center.spec.ts"
Task: "T040 [US4] denied-action localization in workbench-frontend/src/locales/{en,uk,ru}/tags.json"
```

## Parallel Example: User Story 3

```bash
# Run in parallel after T045:
Task: "T042 [US3] profile tag rendering tests in workbench-frontend/src/features/users/__tests__/UserProfileTags.test.tsx"
Task: "T043 [US3] profile visibility E2E flow in chat-ui/tests/e2e/workbench/tag-center.spec.ts"
Task: "T046 [US3] profile rendering in workbench-frontend/src/features/users/UserProfileView.tsx"
```

---

## Implementation Strategy

### MVP First (US1)

1. Complete Phase 1 and Phase 2  
2. Deliver Phase 3 (US1) and validate independently  
3. Use US1 as first deployable increment

### Incremental Delivery

1. Add US2 review-domain lifecycle in parallel  
2. Add US4 capability-gated rights/definition controls  
3. Add US3 profile completeness  
4. Execute final polish and SC-003 reliability gate

### Suggested MVP Scope

- **Recommended MVP**: User Story 1 only (Tasks T001-T024)

---

## Notes

- All tasks follow the required checklist format (`- [ ] T### [P?] [US?] Description with file path`)
- Tests are included because validation coverage is explicitly required in the specification
- Keep implementation language in English for all artifacts and updates

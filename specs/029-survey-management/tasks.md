# Tasks: Survey Instance Management

**Input**: Design documents from `/specs/029-survey-management/`
**Branch**: `029-survey-management`
**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to ([US1], [US2], [US3])
- Include exact file paths in descriptions

---

## Phase 1: Setup (Feature Branches)

**Purpose**: Create the `029-survey-management` branch in all affected split repositories. Per constitution Principle IV, feature branches must use the same name across all repos.

- [X] T001 [P] Create branch `029-survey-management` from `develop` in `D:\src\MHG\chat-types`
- [X] T002 [P] Create branch `029-survey-management` from `develop` in `D:\src\MHG\chat-backend`
- [X] T003 [P] Create branch `029-survey-management` from `develop` in `D:\src\MHG\workbench-frontend`
- [X] T004 [P] Create branch `029-survey-management` from `develop` in `D:\src\MHG\chat-ui`

---

## Phase 2: Foundational (Shared Types — chat-types)

**Purpose**: Publish the four new shared TypeScript types before any backend or frontend code can reference them. This phase MUST be complete before Phase 3 begins.

**⚠️ CRITICAL**: chat-backend and workbench-frontend cannot import the new types until chat-types is published.

- [X] T005 Add `SurveyInstanceUpdateInput`, `SurveyMemberCompletion`, `SurveyGroupStatistics`, and `SurveyInstanceStatistics` interfaces to `D:\src\MHG\chat-types\src\survey.ts` (see data-model.md for exact field signatures)
- [X] T006 Export all four new types from `D:\src\MHG\chat-types\src\index.ts`
- [X] T007 Bump the patch version in `D:\src\MHG\chat-types\package.json`, commit, tag, and publish to GitHub Packages so downstream repos can consume the new types

**Checkpoint**: `@mentalhelpglobal/chat-types` published with new types — user story implementation can now begin.

---

## Phase 3: User Story 1 — Edit Survey Expiration Date (Priority: P1) 🎯 MVP

**Goal**: Workbench admins can change the expiration date on an active (or expired) survey instance. Past dates are rejected. Setting a future date on an expired instance revives it to `active` status. All existing responses are preserved.

**Independent Test**: Navigate to an active survey instance in the workbench, click Edit, change the expiration date to a future value, save — verify the new date is shown and the status badge is unchanged. Then attempt to set a past date — verify a validation error appears.

### Backend (chat-backend)

- [X] T008 [US1] Add `updateInstance(id, input: SurveyInstanceUpdateInput): Promise<SurveyInstance>` to `D:\src\MHG\chat-backend\src\services\surveyInstance.service.ts`: fetch instance, throw 404 if missing, throw 409 if `status='closed'`, validate `expirationDate` is a future ISO datetime, reset `status='active'` when currently `expired` and new date is future, execute `UPDATE survey_instances SET expiration_date=$1, status=$2, updated_at=now() WHERE id=$3` and return updated instance with `completedCount`
- [X] T009 [US1] Add `PATCH /:id` route handler to `D:\src\MHG\chat-backend\src\routes\survey.instances.ts` with `authenticate`, `requireActiveAccount`, `workbenchGuard`, `requirePermission(Permission.SURVEY_INSTANCE_MANAGE)` guards; parse and forward body to `updateInstance()`; return `{ success: true, data: SurveyInstance }` on success or structured error on validation/conflict failure

### Frontend (workbench-frontend)

- [X] T010 [P] [US1] Add `patchInstance(id: string, input: SurveyInstanceUpdateInput): Promise<ApiResponse<SurveyInstance>>` to `D:\src\MHG\workbench-frontend\src\services\surveyApi.ts` calling `PATCH /api/workbench/survey-instances/:id`
- [X] T011 [US1] Add `updateInstance(id: string, input: SurveyInstanceUpdateInput) => Promise<boolean>` action to `D:\src\MHG\workbench-frontend\src\stores\surveyStore.ts`: call `surveyApi.patchInstance()`, on success update `currentInstance` in store and refresh the matching entry in `instances[]`; return true on success, false on error
- [X] T012 [US1] Create `D:\src\MHG\workbench-frontend\src\features\workbench\surveys\components\InstanceEditModal.tsx`: modal with a `datetime-local` Expiration Date field pre-filled from `instance.expirationDate`, future-date client-side validation, submit calls `surveyStore.updateInstance()`, success closes modal and shows toast, error renders API message; disable all inputs and show read-only notice when `instance.status === 'closed'`; focus trap, ESC closes, ARIA labelled
- [X] T013 [US1] Update `D:\src\MHG\workbench-frontend\src\features\workbench\surveys\SurveyInstanceDetailView.tsx`: import and render `InstanceEditModal`; add Edit (pencil) button in the instance header gated by `hasPermission(Permission.SURVEY_INSTANCE_MANAGE)`; button is disabled with tooltip when `status === 'closed'`; manage `isEditModalOpen` boolean state
- [X] T014 [P] [US1] Add `survey.instanceEdit.*` i18n keys to `D:\src\MHG\workbench-frontend\src\i18n\en.json`, `uk.json`, and `ru.json` (keys: `title`, `expirationDate`, `groups`, `save`, `cancel`, `successMessage`, `errorPastDate`, `errorClosed`, `errorNoFields`)

### E2E Tests (chat-ui)

- [X] T015 [US1] Create `D:\src\MHG\chat-ui\tests\survey-management.spec.ts` with US1 test cases: (a) log in as workbench admin → open active instance → open Edit modal → update expiration to future date → verify new date rendered and status unchanged; (b) attempt to set past date → verify validation error visible; (c) verify existing responses still listed after edit

**Checkpoint**: US1 complete — expiration date editing is fully functional and independently testable.

---

## Phase 4: User Story 2 — Change Group Assignment Mid-Flight (Priority: P2)

**Goal**: Admins can replace the group assignment on an active survey while it's running. Completed responses from the previous group are preserved. The new group's users see the survey in their pending list.

**Independent Test**: Open an active survey instance with at least one complete response → edit groups to a new group → verify responses tab still shows the previously completed response → log in as a new group user and verify the survey appears in their gate-check.

### Backend (chat-backend)

- [X] T016 [US2] Extend `updateInstance()` in `D:\src\MHG\chat-backend\src\services\surveyInstance.service.ts` to handle `groupIds`: validate array is non-empty, compute added/removed groups vs current `group_ids`, run a transaction that (a) `UPDATE survey_instances SET group_ids=$1::uuid[], updated_at=now() WHERE id=$2`, (b) `INSERT INTO group_survey_order(group_id, instance_id, display_order)` for each added group with `display_order = COALESCE(MAX(display_order),0)+1` for that group, (c) `DELETE FROM group_survey_order WHERE group_id=ANY($removed) AND instance_id=$id`; existing `survey_responses` rows are never deleted

### Frontend (workbench-frontend)

- [X] T017 [US2] Add Groups multi-select checkbox field to `D:\src\MHG\workbench-frontend\src\features\workbench\surveys\components\InstanceEditModal.tsx`: load available groups via `adminGroupsApi.list()` on modal open, pre-check the groups currently in `instance.groupIds`, include selected groups in the `updateInstance` call alongside any expiration date change; show warning (non-blocking) if all groups are deselected
- [X] T018 [P] [US2] Add `survey.instanceEdit.groups`, `survey.instanceEdit.emptyGroupsWarning` i18n keys to `D:\src\MHG\workbench-frontend\src\i18n\en.json`, `uk.json`, and `ru.json`

### E2E Tests (chat-ui)

- [X] T019 [US2] Append US2 test cases to `D:\src\MHG\chat-ui\tests\survey-management.spec.ts`: (a) open active instance with a recorded response → change group assignment → verify the response is still visible in the responses tab; (b) log in as a user from the new group → verify survey appears in gate-check; (c) verify empty-groups warning renders when all groups are deselected

**Checkpoint**: US2 complete — group reassignment works mid-flight with response preservation.

---

## Phase 5: User Story 3 — Completion Statistics with Non-Completers (Priority: P3)

**Goal**: Admins can view per-group completion statistics for a survey instance: total members, completed, pending, completion rate, and a list of individual users who have not yet submitted.

**Independent Test**: Open a survey instance where some group members have completed and some have not → click the Statistics tab → verify the counts are correct → verify the non-completers list names match users who haven't submitted.

### Backend (chat-backend)

- [X] T020 [US3] Add `getInstanceStatistics(instanceId: string, groupIdFilter?: string): Promise<SurveyInstanceStatistics>` to `D:\src\MHG\chat-backend\src\services\surveyInstance.service.ts`: (1) fetch instance, 404 if missing; (2) if `groupIdFilter` present, validate it exists in `instance.group_ids`, 400 if not; (3) query active members: `SELECT u.id, u.display_name, u.email, gm.group_id FROM group_memberships gm JOIN users u ON u.id=gm.user_id WHERE gm.group_id=ANY($targetGroups) AND gm.status='active' AND u.status='active'`; (4) query completions: `SELECT pseudonymous_id, group_id, completed_at FROM survey_responses WHERE instance_id=$id AND is_complete=true AND invalidated_at IS NULL`; (5) join by `user_id = pseudonymous_id`, aggregate per group into `SurveyInstanceStatistics`; set `completionRate=0` when `totalMembers=0`
- [X] T021 [US3] Add `GET /:id/statistics` route to `D:\src\MHG\chat-backend\src\routes\survey.instances.ts` with `authenticate`, `requireActiveAccount`, `workbenchGuard`, `requireAnyPermission(Permission.SURVEY_INSTANCE_MANAGE, Permission.SURVEY_INSTANCE_VIEW)` guards; forward optional `?groupId` query param to `getInstanceStatistics()`; return `{ success: true, data: SurveyInstanceStatistics }`

### Frontend (workbench-frontend)

- [X] T022 [P] [US3] Add `getInstanceStatistics(id: string, groupId?: string): Promise<ApiResponse<SurveyInstanceStatistics>>` to `D:\src\MHG\workbench-frontend\src\services\surveyApi.ts` calling `GET /api/workbench/survey-instances/:id/statistics?groupId=...`
- [X] T023 [US3] Add `fetchInstanceStatistics(id: string, groupId?: string) => Promise<void>` action and `instanceStatistics`, `instanceStatisticsLoading`, `instanceStatisticsError` state to `D:\src\MHG\workbench-frontend\src\stores\surveyStore.ts`
- [X] T024 [US3] Create `D:\src\MHG\workbench-frontend\src\features\workbench\surveys\components\SurveyStatisticsView.tsx`: on mount calls `surveyStore.fetchInstanceStatistics(instanceId)`; renders summary row (total/completed/pending/rate as %) with a completion progress bar (`role="progressbar"`, `aria-valuenow`, `aria-valuemax`); if instance has multiple groups renders a group tab selector; renders a Members table with columns Name, Email, Status (Completed / Pending badge); table has a "Show: All / Pending only" filter toggle; loading skeleton while fetching; empty state "All members have completed this survey" when `pendingCount === 0`; table scrolls horizontally on narrow screens
- [X] T025 [US3] Add Statistics tab to `D:\src\MHG\workbench-frontend\src\features\workbench\surveys\SurveyInstanceDetailView.tsx` visible to `SURVEY_INSTANCE_MANAGE | SURVEY_INSTANCE_VIEW`; renders `<SurveyStatisticsView instanceId={instance.id} />`
- [X] T026 [P] [US3] Add `survey.statistics.*` i18n keys to `D:\src\MHG\workbench-frontend\src\i18n\en.json`, `uk.json`, and `ru.json` (keys: `title`, `totalMembers`, `completed`, `pending`, `completionRate`, `nonCompleters`, `allCompleted`, `filterAll`, `filterPending`, `statusCompleted`, `statusPending`)

### E2E Tests (chat-ui)

- [X] T027 [US3] Append US3 test cases to `D:\src\MHG\chat-ui\tests\survey-management.spec.ts`: (a) open instance with mixed completions → click Statistics tab → verify total/completed/pending counts match expected values → verify non-completers list contains correct user names; (b) all-completed state → verify 100% rate and empty non-completers list; (c) filter to "Pending only" → verify only pending members shown

**Checkpoint**: US3 complete — all three user stories are independently functional.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Unit tests, accessibility validation, and documentation.

- [X] T028 [P] Write Vitest unit tests for `updateInstance()` covering: valid future `expirationDate` update, past date rejection (400), closed instance rejection (409), `expired` status reset to `active` when date extended, no-field-provided rejection — in `D:\src\MHG\chat-backend\src\services\surveyInstance.service.test.ts`
- [X] T029 [P] Write Vitest unit tests for `getInstanceStatistics()` covering: correct completer/non-completer split, `completionRate=0` when no members, `groupIdFilter` validation (400 when not assigned), 404 on missing instance — in `D:\src\MHG\chat-backend\src\services\surveyInstance.service.test.ts`
- [X] T030 [P] Write Vitest unit tests for `updateInstance()` groupIds handling: non-empty validation, `group_survey_order` insert for added groups, delete for removed groups, responses not deleted — in `D:\src\MHG\chat-backend\src\services\surveyInstance.service.test.ts`
- [X] T031 Validate accessibility on `InstanceEditModal` (focus trap, ESC, label associations) and `SurveyStatisticsView` (table `<caption>`, progress bar ARIA) in `D:\src\MHG\workbench-frontend\src\features\workbench\surveys\components\`
- [X] T032 Run quickstart.md validation scenarios against `https://workbench.dev.mentalhelp.chat` and capture screenshots as evidence in `D:\src\MHG\client-spec\specs\029-survey-management\evidence\`
- [X] T033 Update Confluence User Manual page for Survey Instance Management with screenshots captured via Playwright MCP against `https://workbench.dev.mentalhelp.chat` (add sections: Edit Expiration Date, Change Group Assignment, View Completion Statistics)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — all T001–T004 run in parallel immediately
- **Phase 2 (Foundational)**: Depends on Phase 1 — **BLOCKS Phases 3, 4, 5**
- **Phase 3 (US1)**: Depends on Phase 2 — backend tasks (T008, T009) run first; frontend tasks (T010–T014) can start in parallel once T009 is deployed to dev; T015 requires T013 + dev deployment
- **Phase 4 (US2)**: Depends on Phase 3 — T016 extends T008's function; T017 extends T012's modal
- **Phase 5 (US3)**: Depends on Phase 2 — independent of US1/US2 backend logic; T024/T025 depend on T022/T023
- **Phase 6 (Polish)**: Depends on Phases 3, 4, 5 all complete

### User Story Dependencies

- **US1 (P1)**: Depends on Phase 2 only — no dependency on US2 or US3
- **US2 (P2)**: Depends on Phase 3 backend (extends `updateInstance()`) and Phase 3 frontend (extends `InstanceEditModal`)
- **US3 (P3)**: Depends on Phase 2 only — `getInstanceStatistics()` is a new independent service method

### Cross-Repository Dependencies

| Consumer | Depends On | Gate |
|----------|-----------|------|
| chat-backend (T008+) | chat-types T007 (published) | Import `SurveyInstanceUpdateInput` |
| workbench-frontend (T010+) | chat-types T007 (published) | Import `SurveyInstanceStatistics` |
| workbench-frontend (T013) | chat-backend T009 (deployed to dev) | PATCH endpoint live |
| workbench-frontend (T025) | chat-backend T021 (deployed to dev) | Statistics endpoint live |
| chat-ui (T015, T019, T027) | workbench-frontend deployed to dev | UI available at workbench.dev.mentalhelp.chat |

---

## Parallel Opportunities

### Phase 1 — all in parallel
```
T001, T002, T003, T004 (create branches in each repo simultaneously)
```

### Phase 3 — US1
```
# After T008 merges, frontend API + i18n in parallel:
T010 (surveyApi.ts patchInstance)    — parallel
T014 (i18n keys)                     — parallel

# After T010: T011 → T012 → T013 (sequential, each depends on prior)
# After T013 deployed to dev: T015 (E2E)
```

### Phase 5 — US3
```
# After Phase 2:
T020 (backend service)               — parallel with T022
T022 (frontend API)                  — parallel with T020 and T026
T026 (i18n keys)                     — parallel

# After T020: T021 (route)
# After T022: T023 (store) → T024 (component) → T025 (wire into detail view)
# After T025 deployed: T027 (E2E)
```

### Phase 6 — all unit test tasks in parallel
```
T028, T029, T030 (backend unit tests — same test file, parallel writing)
T031 (accessibility), T032 (quickstart validation) — parallel with tests
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup branches
2. Complete Phase 2: Publish chat-types (CRITICAL gate)
3. Complete Phase 3: US1 — expiration date editing
4. **STOP and VALIDATE**: Smoke-test edit flow on `https://workbench.dev.mentalhelp.chat`
5. Run T015 E2E tests

### Incremental Delivery

1. Setup + Foundational → types published
2. US1 (P1) → expiration date editing → deployable MVP
3. US2 (P2) → adds group reassignment to existing modal → extend MVP
4. US3 (P3) → adds statistics tab → full feature complete
5. Polish → unit tests + docs

### Parallel Team Strategy

With two developers:
- **Developer A** (backend focus): T008, T009 (US1 backend) → T016 (US2 backend) → T020, T021 (US3 backend)
- **Developer B** (frontend focus): T010–T014 (US1 frontend) → T017–T018 (US2 frontend) → T022–T026 (US3 frontend)
- Both run E2E tests (T015, T019, T027) after respective story completes
- Both tackle Polish (T028–T033) together

---

## Notes

- [P] tasks = different files, no shared-state dependencies — safe to run in parallel
- chat-types publish (T007) is the single hardest gate — do not skip it
- `updateInstance()` accumulates functionality across US1 (T008) and US2 (T016) — keep the function signature unchanged between stories
- `InstanceEditModal` accumulates fields across US1 (T012) and US2 (T017) — design the component for extensibility from T012
- All i18n keys must be added to all three locales (en, uk, ru) in the same task — never add en-only keys
- Evidence screenshots for T032 must be stored in `specs/029-survey-management/evidence/`
- Commit after each task or logical group; do not batch unrelated tasks in one commit

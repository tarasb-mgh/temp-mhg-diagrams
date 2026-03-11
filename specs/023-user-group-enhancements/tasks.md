# Tasks: User Group and Management Interface Enhancements

**Input**: Design documents from `specs/023-user-group-enhancements/`
**Prerequisites**: plan.md ✅ | spec.md ✅ | research.md ✅ | data-model.md ✅ | contracts/ ✅ | quickstart.md ✅

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no shared dependencies)
- **[Story]**: User story from spec.md (US1–US8)
- Exact file paths included in every description

---

## Phase 1: Setup

**Purpose**: Feature branch initialization in both affected repositories

- [x] T001 Create branch `023-user-group-enhancements` from `develop` in `workbench-frontend` at `D:/src/MHG/workbench-frontend`
- [x] T002 [P] Create branch `023-user-group-enhancements` from `develop` in `chat-backend` at `D:/src/MHG/chat-backend`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Shared utilities required by multiple user story phases; complete before Phase 3+

**⚠️ CRITICAL**: T003 unblocks US1 (badge), US3 (dropdown logic). T004 unblocks US2 (refresh signal).

- [x] T003 [P] Add `isPrivilegedRole(role: UserRole): boolean` utility (returns true for OWNER, MODERATOR, SUPERVISOR) in `workbench-frontend/src/types/helpers.ts` (create file)
- [x] T004 [P] Add `groupListVersion: number` field (initial `0`) and `bumpGroupListVersion()` action to the Zustand store in `workbench-frontend/src/stores/workbenchStore.ts`

**Checkpoint**: Foundation complete — all user story phases can now proceed

---

## Phase 3: User Story 1 — Privileged Account Group Participation (Priority: P1) 🎯 MVP

**Goal**: Privileged accounts (OWNER, MODERATOR, SUPERVISOR) can be added as group members; they appear in the member list with a role indicator.

**Independent Test**: Add a user with OWNER or SUPERVISOR role to a group via the Groups admin interface → user appears in the member list without a 403 error; a badge distinguishes their privileged role.

- [x] T005 [US1] Remove `OWNER`, `MODERATOR`, `SUPERVISOR` from the `FORBIDDEN_TARGET_ROLE` blocklist in `addUserToGroup`; retain block for `RESEARCHER` and `GROUP_ADMIN`; verify that `logAuditEvent` is called for the new membership insertion in `chat-backend/src/services/group.service.ts`
- [x] T006 [P] [US1] Add privileged role badge (using `isPrivilegedRole` helper from T003) to member list rows so privileged accounts are visually distinguishable in `workbench-frontend/src/features/workbench/groups/GroupsView.tsx`

---

## Phase 4: User Story 2 — Spaces List Refresh After Group Creation (Priority: P1)

**Goal**: The spaces/groups dropdown updates within 2 s of successful group creation without a page reload.

**Independent Test**: Create a new group → the GroupScopeSelector dropdown list updates immediately without reloading the page; wait 30 s with no action → the list still reflects current state (polling verification).

- [x] T007 [US2] Call `bumpGroupListVersion()` (from T004) inside `handleCreateGroup` immediately after `adminGroupsApi.create()` succeeds in `workbench-frontend/src/features/workbench/groups/GroupsView.tsx`
- [x] T008 [US2] In the `canManageUsers` managed-groups `useEffect`, add `groupListVersion` to the dependency array (reactive re-fetch on bump) and add a separate `setInterval(loadManagedGroups, 30000)` with cleanup in `workbench-frontend/src/features/workbench/components/GroupScopeSelector.tsx`

---

## Phase 5: User Story 3 — Hide Spaces Dropdown for Single-Space Non-Privileged Users (Priority: P2)

**Goal**: Non-privileged users with exactly one space never see the dropdown; privileged accounts always see it.

**Independent Test**: Log in as a non-privileged user belonging to exactly one group → no spaces dropdown visible; log in as OWNER or SUPERVISOR belonging to one group → dropdown is visible.

- [x] T009 [US3] Replace the `shouldShowGroupSelector` boolean with logic: `isPrivilegedRole(user.role) || adminMemberships.length > 1 || activeMemberships.length > 1`; this preserves all three existing conditions while adding the explicit privileged-account override in `workbench-frontend/src/features/workbench/components/GroupScopeSelector.tsx`

---

## Phase 6: User Story 4 — Group Surveys Section with Reordering (Priority: P2)

**Goal**: Group Surveys section is accessible, lists surveys, supports reordering that persists, and shows a helpful empty state.

**Independent Test**: Open a group with assigned surveys → Group Surveys section lists all surveys; drag to reorder → reload page → order is preserved; open a group with no surveys → empty state with guidance message is shown.

- [x] T010 [US4] Update `survey.groupSurveys.empty` translation key to include actionable guidance text (e.g., "No surveys assigned to this group. Assign surveys via Survey Instances.") in `workbench-frontend/src/locales/en/translation.json` only — uk/ru translations are handled in T022
- [x] T011 [P] [US4] Read `GroupSurveyList.tsx` and confirm drag-end handler calls `onReorder` with the full reordered `instanceId[]` array; add a `// verified YYYY-MM-DD` comment confirming the call exists; if the call is absent, implement it — do not add a no-op comment in `workbench-frontend/src/features/workbench/groups/components/GroupSurveyList.tsx`

---

## Phase 7: User Story 5 — Deduplicated Survey Completion Across Groups (Priority: P2)

**Goal**: A user in two groups sharing the same survey instance is not prompted to complete it twice.

**Independent Test**: Assign the same survey instance to Group A and Group B (both in `group_ids`); complete the survey as a user in both groups; verify the gate-check endpoint does not return the survey as pending for the second group.

- [x] T012 [US5] Verify `getGateCheck` in `chat-backend/src/services/surveyResponse.service.ts` lines 40–55 correctly excludes instances where `pseudonymous_id + instance_id` is already complete; add a `// verified` comment with the date and confirm no code change is needed per research.md; if a gap is found, fix the query predicate

---

## Phase 8: User Story 6 — Consolidated Invalidation Menu with Confirmation (Priority: P3)

**Goal**: All invalidation controls for survey responses are grouped in a single "Invalidation" dropdown; every action requires a confirmation modal before executing; higher-risk actions are restricted to OWNER/MODERATOR.

**Independent Test**: Open any survey response view → no invalidation buttons visible outside the Invalidation menu; click an invalidation action → confirmation modal appears; cancel → no data changed; confirm → invalidation applied and UI reflects updated state; log in as standard admin → higher-risk actions (invalidate all, invalidate group) are disabled/hidden.

- [x] T013 [US6] Create `InvalidationMenu` component: dropdown trigger button labelled "Invalidation", three action items (invalidate response [low-risk, all admins], invalidate group [isPrivilegedRole only], invalidate all [isPrivilegedRole only]), React confirmation modal with action description and Cancel/Confirm buttons, calls parent `onInvalidated` callback on success — use `isPrivilegedRole(user.role)` from T003 to gate higher-risk actions (covers OWNER, MODERATOR, SUPERVISOR per FR-008a) in `workbench-frontend/src/features/workbench/surveys/components/InvalidationMenu.tsx`
- [x] T014 [US6] Replace the inline invalidation group-selector, invalidate-group button, and invalidate-all button with `<InvalidationMenu instanceId={id} groupOptions={groupOptions} onInvalidated={...} />` in `workbench-frontend/src/features/workbench/surveys/SurveyInstanceDetailView.tsx`
- [x] T015 [P] [US6] Replace the inline invalidation group-selector, invalidate-group button, invalidate-all button, and per-response inline invalidate button with `<InvalidationMenu instanceId={id} groupOptions={groupOptions} responseId={resp.id} onInvalidated={...} />` in `workbench-frontend/src/features/workbench/surveys/SurveyResponseListView.tsx`

---

## Phase 9: User Story 7 — Privileged Account Lookup in User Group Interface (Priority: P3)

**Goal**: Administrators can filter the user lookup in group management to show only privileged accounts.

**Independent Test**: Open a group; toggle "Privileged accounts only" in the member lookup; search results contain only OWNER/MODERATOR/SUPERVISOR accounts; select one → added to group without error.

- [x] T016 [US7] Add `privileged` query param handling to `GET /api/admin/users`: when `privileged=true`, add `AND role = ANY(ARRAY['owner','moderator','supervisor'])` to the WHERE clause in `chat-backend/src/routes/users.ts`
- [x] T017 [US7] Add "Privileged accounts only" checkbox filter to the Add Member section of the group detail panel; when checked, call `apiFetch('/api/admin/users?privileged=true')` (or add `adminUsersApi.listPrivileged()` to `workbench-frontend/src/services/adminApi.ts`) and display results in a searchable dropdown for selection; the selected user is then added via the existing `adminGroupsApi.addMember()` call in `workbench-frontend/src/features/workbench/groups/GroupsView.tsx`

---

## Phase 10: User Story 8 — User Management Navigation and Copy Improvements (Priority: P3)

**Goal**: Row clicks do not navigate; only [View] navigates; copy icon appears next to email in list and on card; search filter survives navigate-to-card-and-back.

**Independent Test**: Click a user row outside [View] → no navigation; click [View] → navigates to card; click copy icon on email → email in clipboard, icon briefly shows ✓; apply search filter → navigate to card via [View] → press back → filter still applied.

- [x] T018 [US8] Remove `onClick={() => navigate(...)}` and `cursor-pointer` from the `<tr>` element; confirm `<button onClick={e => { e.stopPropagation(); navigate(...) }}>` on [View] button is retained in `workbench-frontend/src/features/workbench/users/UserListView.tsx`
- [x] T019 [P] [US8] Add copy-to-clipboard icon (Lucide `Copy` → `Check` for 2 s on success) next to the email field on the user profile card in `workbench-frontend/src/features/workbench/users/UserProfileCard.tsx`
- [x] T020 [US8] Add copy-to-clipboard icon (Lucide `Copy` → `Check` for 2 s) next to email in each user list row in `workbench-frontend/src/features/workbench/users/UserListView.tsx`
- [x] T021 [US8] Migrate `search`, `roleFilter`, `statusFilter`, `sort`, `testUsersOnly`, `page`, `pageSize` from `useState` to `useSearchParams` URL params (keys: `q`, `role`, `status`, `sort`, `testOnly`, `page`, `pageSize`) so filter state is preserved on browser back navigation in `workbench-frontend/src/features/workbench/users/UserListView.tsx`

---

## Final Phase: Polish & Cross-Cutting Concerns

**Purpose**: i18n completeness, accessibility, responsive verification, and PR preparation for both repos

- [x] T022 [P] Add all new i18n translation keys (US1: privilegedBadge; US4: survey.groupSurveys.empty uk/ru only; US6: invalidation menu labels, confirmation modal text; US7: lookupPrivileged; US8: copyEmail, emailCopied) to `workbench-frontend/src/locales/uk/translation.json` and `workbench-frontend/src/locales/ru/translation.json`; also add US1/US6/US7/US8 English keys to `workbench-frontend/src/locales/en/translation.json` (US4 English key handled by T010)
- [x] T023 [P] Add `aria-label` to InvalidationMenu dropdown trigger and each menu item; add `aria-label` to copy-to-clipboard buttons in list and card; verify all new interactive elements are keyboard-navigable in `workbench-frontend/src/features/workbench/surveys/components/InvalidationMenu.tsx` and `workbench-frontend/src/features/workbench/users/UserListView.tsx`
- [x] T024 Verify responsive layout at 375 px: InvalidationMenu dropdown does not overflow viewport; copy icon is tappable (min 44 × 44 px); user list row [View] button and copy icon visible on mobile in `workbench-frontend/src/features/workbench/surveys/components/InvalidationMenu.tsx` and `workbench-frontend/src/features/workbench/users/UserListView.tsx`

---

## Phase 4: Release

- [x] T025 [P] Capture screenshots via Playwright MCP against `https://workbench.dev.mentalhelp.chat` for: user group list with privileged badge, Group Surveys drag-and-drop section, invalidation consolidated menu, user management [View] button and copy icon — captured 2026-03-10: 023-group-members-privileged.png (Privileged badge + Show privileged accounts only checkbox), 023-group-surveys-empty.png (empty state guidance), 023-invalidation-menu.png (dropdown with group selector + action items), 023-user-list-copy-view.png (copy icon + View button)
- [x] T026 [P] Update Confluence User Manual with user group management section covering new features: privileged group participation, Group Surveys, consolidated invalidation menu, user management improvements — with Playwright-captured screenshots — Confluence page 8749070 updated to v6 2026-03-10T15:03 with "User Group Management" section (Group Member List, Adding Members, Group Surveys, Spaces Dropdown Visibility, Spaces List Refresh, User Management: Navigation/Copy Email/Filter State)
- [x] T027 [P] Update Confluence Release Notes — production deployment complete (v2026.03.11-backend.1, v2026.03.11-workbench.4, v2026.03.11-frontend.3 tagged on `main` 2026-03-11); Confluence Release Notes updated — see page 8749070 and activity-report pages for full details
- [x] T028 Open PRs from `023-user-group-enhancements` branch to `develop` in all affected repositories (`workbench-frontend`, `chat-backend`), obtain required reviews, and merge only after all required checks pass — workbench-frontend#47 merged 2026-03-10, chat-backend#127 merged 2026-03-10
- [x] T029 Verify unit and E2E test gates passed for merged PRs — workbench-frontend CI ✅ 2026-03-10T13:34, Deploy ✅ 13:46; chat-backend CI ✅ 13:18, Deploy ✅ 13:22
- [x] T030 Capture post-deploy smoke evidence: workbench user group list loads, Group Surveys section visible, invalidation menu renders, user list copy icon present — confirmed 2026-03-10 via Playwright: group list loads with 6 groups, Privileged badge visible, Group Surveys section renders empty state, Invalidation dropdown opens with group selector + 2 actions, User list shows copy icon next to each email with View button
- [x] T031 Delete merged remote `023-user-group-enhancements` branches and purge local feature branches — remote branches already auto-deleted on merge; no local branches existed
- [x] T032 Sync local `develop` to `origin/develop` in all affected repositories — workbench-frontend ✅, chat-backend ✅
- [x] T033 Transition Jira Stories MTB-658–MTB-665 to Done and add completion summary comment to Epic MTB-657 — all transitioned 2026-03-10T14:50; completion comment added to MTB-657

---

## Dependencies

```
T001, T002 (branch setup — run in parallel)
  └─ T003, T004 (foundation — run in parallel)
       ├─ T005, T006 (US1 — parallel; T006 uses T003)
       ├─ T007, T008 (US2 — parallel; both use T004)
       │    └─ T009 (US3 — uses T003; runs after T008 same file)
       ├─ T010, T011 (US4 — parallel, minimal deps)
       ├─ T012 (US5 — verification only)
       ├─ T013 → T014, T015 (US6 — T014/T015 parallel after T013)
       ├─ T016, T017 (US7 — parallel; T017 uses T016 endpoint)
       └─ T018 → T019 [P], T020, T021 (US8 — T019 parallel; T020/T021 after T018 same file)
            └─ T022, T023, T024 (polish — T022/T023 parallel)
```

## Parallel Execution Opportunities

| Parallel Group | Tasks | Note |
|----------------|-------|------|
| Branch setup | T001, T002 | Different repos |
| Foundation | T003, T004 | Different files |
| US1 backend + frontend | T005, T006 | Different repos |
| US2 store + selector | T007, T008 | Different files |
| US4 empty state + reorder | T010, T011 | Different files |
| US6 detail + response views | T014, T015 | Different files (after T013) |
| US7 backend + frontend | T016, T017 | Different repos |
| US8 card copy + row cleanup | T018, T019 | Different files |
| Polish | T022, T023 | Different concerns |

## Implementation Strategy

**MVP** (deliver first — P1 stories): T001–T004 → T005–T008 (US1 + US2)
**Increment 2** (P2 stories): T009–T012 (US3, US4, US5)
**Increment 3** (P3 stories): T013–T021 (US6, US7, US8)
**Final**: T022–T024 (polish — do last, covers all stories)

## Summary

| | Count |
|---|---|
| **Total tasks** | 24 |
| US1 (Privileged group participation) | 2 tasks (T005–T006) |
| US2 (Spaces list refresh) | 2 tasks (T007–T008) |
| US3 (Hide single-space dropdown) | 1 task (T009) |
| US4 (Group Surveys reordering) | 2 tasks (T010–T011) |
| US5 (Survey deduplication) | 1 task (T012) |
| US6 (Invalidation menu) | 3 tasks (T013–T015) |
| US7 (Privileged lookup) | 2 tasks (T016–T017) |
| US8 (User management UX) | 4 tasks (T018–T021) |
| Setup + Foundation + Polish | 7 tasks (T001–T004, T022–T024) |
| **Parallel opportunities** | 9 parallel groups |
| **Suggested MVP scope** | T001–T008 (US1 + US2; both P1 stories) |

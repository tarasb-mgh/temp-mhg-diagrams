# Tasks: Clinical Tags Tab in Tag Center

**Input**: Design documents from `specs/054-clinical-tags-tab/`  
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, quickstart.md

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup

**Purpose**: Create feature branches in affected repositories

- [x] T001 Create feature branch `054-clinical-tags-tab` from `develop` in chat-backend
- [x] T002 [P] Create feature branch `054-clinical-tags-tab` from `develop` in workbench-frontend

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Breadcrumb enhancement and routing restructure that ALL user stories depend on

**CRITICAL**: No user story work can begin until this phase is complete

- [x] T003 Extend `BreadcrumbSegment` type with optional `menuItems` property in workbench-frontend/src/features/workbench/components/Breadcrumb.tsx
- [x] T004 Implement dropdown rendering for breadcrumb segments with `menuItems` (positioned menu, chevron indicator, navigate on click) in workbench-frontend/src/features/workbench/components/Breadcrumb.tsx
- [x] T005 Add keyboard accessibility for breadcrumb dropdown (arrow keys, escape to close, outside click dismiss) in workbench-frontend/src/features/workbench/components/Breadcrumb.tsx
- [x] T006 Create TagCenterLayout component with breadcrumb dropdown segment and Outlet in workbench-frontend/src/features/workbench/tags/TagCenterLayout.tsx
- [x] T007 Extract User Tags mode logic from TagCenterPage into standalone UserTagsSection component in workbench-frontend/src/features/workbench/tags/UserTagsSection.tsx
- [x] T008 [P] Extract Review Tags mode logic from TagCenterPage into standalone ReviewTagsSection component in workbench-frontend/src/features/workbench/tags/ReviewTagsSection.tsx
- [x] T009 Restructure tags route in WorkbenchShell from flat to nested routes (index + user + review + clinical) in workbench-frontend/src/features/workbench/WorkbenchShell.tsx
- [x] T010 Update `isTagCenterRoute` check in WorkbenchLayout to match all `/workbench/tags/*` sub-routes in workbench-frontend/src/features/workbench/WorkbenchLayout.tsx

**Checkpoint**: Tag Center routing works with sub-routes; User Tags at `/tags/user` and Review Tags at `/tags/review` function identically to pre-restructure behavior

---

## Phase 3: User Story 5 — Fix MVP Draft Comment Persistence Bug (Priority: P1)

**Goal**: Fix the draft persistence layer so clinical tag comments write to the correct database table

**Independent Test**: Save a draft clinical tag comment during review → reload → verify comment is restored

- [x] T011 [US5] Fix table name from `clinical_tag_comments` to `review_clinical_tag_comments` in chat-backend/src/routes/review.draft.ts line 143
- [x] T012 [US5] Add regression test: draft save persists clinical_tag_comment to review_clinical_tag_comments table in chat-backend/tests/unit/review.draft.test.ts
- [x] T013 [US5] Add negative test: empty clinical_tag_comment is handled gracefully without error in chat-backend/tests/unit/review.draft.test.ts

**Checkpoint**: Draft clinical tag comments persist correctly and survive page reload

---

## Phase 4: User Story 3 — Tag Center Landing Page (Priority: P1)

**Goal**: Landing page at `/workbench/tags` with 3 summary cards for navigation and discoverability

**Independent Test**: Navigate to Tag Center → see 3 cards with stats → click card → navigate to section → breadcrumb "Tags" → return to landing

- [x] T014 [P] [US3] Add `searchExperts` and `getExpertCount` helper functions in workbench-frontend/src/services/tagApi.ts
- [x] T015 [P] [US3] Create TagCenterCard reusable component (icon, title, description, stats, loading skeleton, error fallback) in workbench-frontend/src/features/workbench/tags/TagCenterLanding.tsx
- [x] T016 [US3] Create TagCenterLanding component with 3 cards fetching stats from existing endpoints in workbench-frontend/src/features/workbench/tags/TagCenterLanding.tsx
- [x] T017 [US3] Add English localization keys for landing page (tagCenter.landing.*) in workbench-frontend/src/locales/en.json
- [x] T018 [US3] Add responsive layout for landing page cards (grid on desktop, stack on mobile) in workbench-frontend/src/features/workbench/tags/TagCenterLanding.tsx

**Checkpoint**: Landing page displays 3 cards with stats; clicking any card navigates to the correct section; breadcrumb returns to landing

---

## Phase 5: User Story 1 — Clinical Tag Definitions (Priority: P1) MVP

**Goal**: Administrators can create, edit (name + description), and delete clinical tags from the Clinical Tags section

**Independent Test**: Create tag "ANXIETY" → add description → verify session count → rename → delete unused tag — all from `/workbench/tags/clinical`

- [x] T019 [US1] Create ClinicalTagsSection orchestrator component with two-column layout (desktop) and stacked layout (mobile) in workbench-frontend/src/features/workbench/tags/ClinicalTagsSection.tsx
- [x] T020 [US1] Implement ClinicalTagDefinitionsPanel with single-line create input and Create button in workbench-frontend/src/features/workbench/tags/components/ClinicalTagDefinitionsPanel.tsx
- [x] T021 [US1] Implement tag list rendering with active dot, name badge (violet), description (grey text), session count (amber badge), and action icons in workbench-frontend/src/features/workbench/tags/components/ClinicalTagDefinitionsPanel.tsx
- [x] T022 [US1] Implement inline rename action (pencil icon → input replacement → save/cancel) in workbench-frontend/src/features/workbench/tags/components/ClinicalTagDefinitionsPanel.tsx
- [x] T023 [US1] Implement expandable description editor (description icon → expandable row with pre-populated input + confirm button) in workbench-frontend/src/features/workbench/tags/components/ClinicalTagDefinitionsPanel.tsx
- [x] T024 [US1] Implement delete action with confirmation dialog and sessionCount > 0 blocking with explanation message in workbench-frontend/src/features/workbench/tags/components/ClinicalTagDefinitionsPanel.tsx
- [x] T025 [US1] Implement case-insensitive duplicate name validation on create and rename with error message in workbench-frontend/src/features/workbench/tags/components/ClinicalTagDefinitionsPanel.tsx
- [x] T026 [US1] Add English localization keys for clinical tag section (tagCenter.clinical.*) in workbench-frontend/src/locales/en.json

**Checkpoint**: Full CRUD lifecycle for clinical tags works from `/workbench/tags/clinical`; duplicate names blocked; delete blocked when in use

---

## Phase 6: User Story 2 — Expert Tag Assignments (Priority: P1)

**Goal**: Administrators can assign and unassign clinical tags to expert users with auto-save per toggle

**Independent Test**: Select expert → toggle "PTSD" checkbox → verify auto-save → reload → verify assignment persists

- [x] T027 [US2] Add expert tag list/assign/remove API helpers (getExpertTags, assignExpertTag, removeExpertTag) in workbench-frontend/src/services/tagApi.ts
- [x] T028 [US2] Implement ClinicalTagAssignmentsPanel with expert search input and expert user list (expert role only) in workbench-frontend/src/features/workbench/tags/components/ClinicalTagAssignmentsPanel.tsx
- [x] T029 [US2] Implement selected expert view with clinical tag checkboxes and auto-save per toggle in workbench-frontend/src/features/workbench/tags/components/ClinicalTagAssignmentsPanel.tsx
- [x] T030 [US2] Implement empty state for no experts and loading states for expert list and assignments in workbench-frontend/src/features/workbench/tags/components/ClinicalTagAssignmentsPanel.tsx
- [x] T031 [US2] Wire ClinicalTagAssignmentsPanel into ClinicalTagsSection as right column panel in workbench-frontend/src/features/workbench/tags/ClinicalTagsSection.tsx

**Checkpoint**: Expert assignment panel shows only expert-role users; toggling checkboxes auto-saves; assignments persist on reload

---

## Phase 7: User Story 4 — Deprecate Standalone Clinical Tag Admin (Priority: P2)

**Goal**: Remove old clinical tag admin page from navigation and redirect to Tag Center

**Independent Test**: Navigate to `/workbench/review/clinical-tags` → verify redirect to `/workbench/tags/clinical`; verify no sidebar link to old page

- [x] T032 [US4] Add redirect route from `/review/clinical-tags` to `/workbench/tags/clinical` in workbench-frontend/src/features/workbench/WorkbenchShell.tsx
- [x] T033 [US4] Remove or hide sidebar navigation link to standalone clinical tag admin page (if present) in workbench-frontend/src/features/workbench/WorkbenchLayout.tsx

**Checkpoint**: Old URL redirects correctly; no navigation path leads to standalone page

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Localization completion, testing, and regression suite

- [x] T034 [P] Add Ukrainian localization keys for all new UI text (landing, clinical, breadcrumb) in workbench-frontend/src/locales/uk.json
- [x] T035 [P] Add Russian localization keys for all new UI text (landing, clinical, breadcrumb) in workbench-frontend/src/locales/ru.json
- [x] T036 [P] Add unit tests for Breadcrumb dropdown rendering and keyboard interaction in workbench-frontend/src/features/workbench/components/__tests__/Breadcrumb.test.tsx
- [x] T037 [P] Add unit tests for ClinicalTagDefinitionsPanel CRUD operations and validation in workbench-frontend/src/features/workbench/tags/components/__tests__/ClinicalTagDefinitionsPanel.test.tsx
- [x] T038 [P] Add unit tests for ClinicalTagAssignmentsPanel expert search and auto-save toggle in workbench-frontend/src/features/workbench/tags/components/__tests__/ClinicalTagAssignmentsPanel.test.tsx
- [x] T039 [P] Add unit tests for TagCenterLanding stats loading and error handling in workbench-frontend/src/features/workbench/tags/__tests__/TagCenterLanding.test.tsx
- [x] T040 Add regression test cases for clinical tag management to regression-suite/19-clinical-tags.yaml
- [x] T041 Run quickstart.md validation against dev environment

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Setup — BLOCKS all user stories
- **US5 Bugfix (Phase 3)**: Independent of Phase 2 — can run in parallel with Foundational
- **US3 Landing (Phase 4)**: Depends on Phase 2 (routing must be in place)
- **US1 Definitions (Phase 5)**: Depends on Phase 2 (clinical route must exist)
- **US2 Assignments (Phase 6)**: Depends on Phase 5 (definitions panel provides tag data)
- **US4 Deprecation (Phase 7)**: Depends on Phase 5 + 6 (clinical section must be complete)
- **Polish (Phase 8)**: Depends on all user story phases being complete

### User Story Dependencies

- **US5 (Bugfix)**: Independent — backend only, no frontend dependency
- **US3 (Landing)**: Depends on Phase 2 routing restructure — no dependency on other user stories
- **US1 (Definitions)**: Depends on Phase 2 routing — no dependency on other user stories
- **US2 (Assignments)**: Depends on US1 (needs definitions loaded in ClinicalTagsSection)
- **US4 (Deprecation)**: Depends on US1 + US2 (clinical section must be fully functional)

### Cross-Repository Dependencies

```
chat-backend (Phase 1 setup + Phase 3 bugfix)
  └── Deploy to dev after merge
       ↓
workbench-frontend (Phase 1 setup → Phase 2-7)
  └── Develop in parallel, validate against fixed backend
       ↓
Both deployed to dev → Phase 8 validation
```

### Parallel Opportunities

- T001 + T002: branch creation in both repos
- T007 + T008: extract UserTagsSection and ReviewTagsSection simultaneously
- T014 + T015: API helpers and card component (different files)
- T034 + T035 + T036 + T037 + T038 + T039: all polish tasks are independent
- Phase 3 (bugfix) runs in parallel with Phase 2 (foundational)

---

## Parallel Example: Phase 2 (Foundational)

```bash
# Breadcrumb changes (T003-T005) must be sequential (same file)
# Section extraction can be parallel:
Task T007: "Extract UserTagsSection from TagCenterPage"
Task T008: "Extract ReviewTagsSection from TagCenterPage"  # [P] different file
```

## Parallel Example: Phase 8 (Polish)

```bash
# All localization and test tasks run in parallel:
Task T034: "Ukrainian localization"
Task T035: "Russian localization"
Task T036: "Breadcrumb tests"
Task T037: "ClinicalTagDefinitionsPanel tests"
Task T038: "ClinicalTagAssignmentsPanel tests"
Task T039: "TagCenterLanding tests"
```

---

## Implementation Strategy

### MVP First (US1 Only)

1. Complete Phase 1: Setup (branches)
2. Complete Phase 2: Foundational (routing + breadcrumb)
3. Complete Phase 5: US1 — Clinical Tag Definitions
4. **STOP and VALIDATE**: Clinical tag CRUD works at `/workbench/tags/clinical`
5. Deploy to dev for validation

### Incremental Delivery

1. Setup + Foundational → routing infrastructure ready
2. Add US5 (bugfix) → backend fix deployed
3. Add US3 (landing) → Tag Center has entry page
4. Add US1 (definitions) → clinical tag CRUD works (MVP!)
5. Add US2 (assignments) → expert assignments work
6. Add US4 (deprecation) → old page retired
7. Polish → localization + tests

### Recommended Execution (Single Developer)

Phase 1 → Phase 2 → Phase 3 (parallel) → Phase 4 → Phase 5 → Phase 6 → Phase 7 → Phase 8

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story is independently completable and testable after Phase 2
- Existing panels (UserTagDefinitionsPanel, UserTagAssignmentsPanel, ReviewTagDefinitionsPanel) remain UNCHANGED
- All API endpoints already exist — no backend changes beyond the bugfix
- Design system compliance: use design system tokens only, no ad-hoc colors or sizing

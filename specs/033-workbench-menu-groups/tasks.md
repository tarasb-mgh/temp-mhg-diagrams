# Tasks: Workbench Sidebar Menu Reorganization

**Input**: Design documents from `specs/033-workbench-menu-groups/`  
**Prerequisites**: `plan.md` (required), `spec.md` (required), `research.md`, `data-model.md`, `contracts/sidebar-nav-config.md`, `quickstart.md`  
**Branch**: `033-workbench-menu-groups` | **Date**: 2026-03-17  
**Epic**: MTB-783 | **Stories**: MTB-784 (US1), MTB-785 (US2), MTB-786 (US3), MTB-787 (US4)

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no blocking dependency)
- **[Story]**: User story reference (`[US1]`, `[US2]`, `[US3]`, `[US4]`)
- Every task includes an explicit file path

---

## Phase 1: Setup (Localization Foundation)

**Purpose**: Add all new and renamed i18n keys to all 3 locale files before any component changes. This unblocks all subsequent phases.

- [X] T001 [P] [US2] Add group heading keys (`workbench.nav.group.reviews`, `workbench.nav.group.surveys`, `workbench.nav.group.peopleAccess`) and new item keys (`reviewQueue`, `reviewDashboard`, `teamDashboard`, `escalations`, `reviewTags`, `reviewSettings`, `surveyTemplates`, `testerTags`) to `workbench-frontend/src/locales/en.json`. — MTB-788
- [X] T002 [P] [US2] Add group heading keys and new item keys with Ukrainian translations to `workbench-frontend/src/locales/uk.json` per research.md Decision 4 translation table. — MTB-789
- [X] T003 [P] [US2] Add group heading keys and new item keys with Russian translations to `workbench-frontend/src/locales/ru.json` per research.md Decision 4 translation table. — MTB-790
- [X] T004 [P] [US2] Update shortened label values for existing keys in all 3 locale files: `workbench.nav.users` ("User Management" → "Users"), `workbench.nav.groups` ("Group management" → "Groups"), `workbench.nav.privacy` ("Privacy Controls" → "Privacy"), `workbench.nav.reviewReports` ("Reports & Analytics" → "Reports") in `workbench-frontend/src/locales/en.json`, `uk.json`, `ru.json`. — MTB-791

**Checkpoint**: All i18n keys exist in all 3 locales. Components can reference new keys immediately.

---

## Phase 2: Foundational (State Management)

**Purpose**: Add collapse state infrastructure to Zustand store. Blocks US3 (collapsible groups) but US1/US2 can proceed without it.

- [X] T005 [US3] Add `navGroupCollapsed: Record<string, boolean>` state field and `toggleNavGroup(groupId: string)` action to `workbench-frontend/src/stores/workbenchStore.ts`. Extend `partialize` to include `navGroupCollapsed` for localStorage persistence. — MTB-792

**Checkpoint**: Store supports collapse state read/write with persistence. No UI changes yet.

---

## Phase 3: User Story 1 — Grouped Sidebar Navigation (Priority: P1)

**Goal**: Replace the flat nav item list with a grouped, data-driven menu structure with 3 collapsible groups (Reviews, Surveys, People & Access).

**Independent Test**: Sidebar displays items in named groups with visible headings; empty groups are hidden for roles with limited permissions.

### Implementation for User Story 1

- [X] T006 [US1] Define `NavGroupConfig` interface and replace flat `navItems` array with `dashboardItem`, `navGroups` (reviews, surveys, peopleAccess), and `settingsItem` in `workbench-frontend/src/features/workbench/WorkbenchLayout.tsx`. — MTB-793
- [X] T007 [US1] Replace `mainNavItems` / `researchNavItems` rendering split with group-based rendering: for each group, render heading + permission-filtered child items. Hide entire group when zero items are visible. Render Dashboard above groups, Settings below, in `workbench-frontend/src/features/workbench/WorkbenchLayout.tsx`. — MTB-794
- [X] T008 [US1] Move Group Resources contextual block to render after the last static group (People & Access) and before Settings in `workbench-frontend/src/features/workbench/WorkbenchLayout.tsx`. — MTB-795
- [X] T009 [US1] Update `allNavItems` derivation to include all items from all groups (for breadcrumb active-state calculation) in `workbench-frontend/src/features/workbench/WorkbenchLayout.tsx`. — MTB-796

**Checkpoint**: Sidebar renders grouped items with headings. Dashboard at top, Settings at bottom, Group Resources between groups and Settings. Empty groups hidden. Breadcrumbs work for all items.

---

## Phase 4: User Story 2 — Consistent Naming and Iconography (Priority: P1)

**Goal**: Assign unique icons and consistent Title Case labels to every sidebar item.

**Independent Test**: No two visible sidebar items share the same icon; all labels are Title Case and 3 words or fewer.

### Implementation for User Story 2

- [X] T010 [US2] Update icon imports in `workbench-frontend/src/features/workbench/WorkbenchLayout.tsx`: add `ClipboardCheck`, `BarChart3`, `UsersRound`, `AlertTriangle`, `Tags`, `Wrench`, `FileText`, `ListChecks`, `UserCog`, `Building2`, `UserCheck`, `ShieldCheck`, `MessageSquare`, `ClipboardList`; remove unused icon imports. — MTB-797
- [X] T011 [US2] Update icon assignments for all nav items in `workbench-frontend/src/features/workbench/WorkbenchLayout.tsx` per research.md Decision 3 icon mapping table: Review Queue → ClipboardCheck, Survey Templates → FileText, Survey Instances → ListChecks, Users → UserCog, Groups → Building2, Approvals → UserCheck, Privacy → ShieldCheck, Review Tags → Tags, Group Chats → MessageSquare, Group Surveys → ClipboardList. — MTB-798
- [X] T012 [US2] Update all `labelKey` references in nav item definitions to use new key names per contracts/sidebar-nav-config.md renamed keys list (`research` → `reviewQueue`, `surveySchemas` → `surveyTemplates`, `testerTagManagement` → `testerTags`, `tagManagement` → `reviewTags`) in `workbench-frontend/src/features/workbench/WorkbenchLayout.tsx`. — MTB-799

**Checkpoint**: All sidebar items have unique icons and consistent short labels. Visual inspection confirms no duplicates.

---

## Phase 5: User Story 3 — Collapsible Groups with Persistent State (Priority: P2)

**Goal**: Each menu group can be collapsed/expanded with state persisting across navigation and page refresh.

**Independent Test**: Collapse the Surveys group, navigate to another page, return — Surveys remains collapsed. Navigate to a page within a collapsed group — group auto-expands.

### Implementation for User Story 3

- [X] T013 [US3] Add collapse toggle handler to group headings: read `navGroupCollapsed[group.id]` from `workbenchStore`, call `toggleNavGroup(group.id)` on heading click, conditionally render child items based on collapsed state, in `workbench-frontend/src/features/workbench/WorkbenchLayout.tsx`. — MTB-800
- [X] T014 [US3] Add chevron indicator (ChevronDown when expanded, ChevronRight when collapsed) to group heading elements in `workbench-frontend/src/features/workbench/WorkbenchLayout.tsx`. — MTB-801
- [X] T015 [US3] Add auto-expand override: if `location.pathname` starts with any item's `path` in a collapsed group, treat that group as expanded for the current render, in `workbench-frontend/src/features/workbench/WorkbenchLayout.tsx`. — MTB-802

**Checkpoint**: Groups collapse/expand on click. Chevron indicator reflects state. State persists across navigation and refresh. Active-route group auto-expands.

---

## Phase 6: User Story 4 — Surfacing Hidden Review Sub-Routes (Priority: P3)

**Goal**: Add 4 existing but previously hidden review routes to the Reviews group sidebar.

**Independent Test**: Users with appropriate permissions see Review Dashboard, Team Dashboard, Escalations, and Review Settings in the sidebar and can navigate to them.

### Implementation for User Story 4

- [X] T016 [US4] Add nav items for Review Dashboard (`/workbench/review/dashboard`, BarChart3, `REVIEW_ACCESS`), Team Dashboard (`/workbench/review/team`, UsersRound, `REVIEW_TEAM_DASHBOARD`), Escalations (`/workbench/review/escalations`, AlertTriangle, `REVIEW_ESCALATION`), and Review Settings (`/workbench/review/config`, Wrench, `REVIEW_CONFIGURE`) to the Reviews group items array in `workbench-frontend/src/features/workbench/WorkbenchLayout.tsx`. — MTB-803

**Checkpoint**: All 4 review sub-routes are visible in the sidebar for users with matching permissions. Navigation to each route works correctly.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Final verification and cleanup across all stories.

- [X] T017 [P] Verify that `researchPaths` set and the old `researchExpanded` state are removed (replaced by group-based collapse logic) in `workbench-frontend/src/features/workbench/WorkbenchLayout.tsx`. — MTB-804
- [X] T018 [P] Verify all 3 locale files have consistent key coverage: every key referenced in nav config exists in `en.json`, `uk.json`, and `ru.json` under `workbench-frontend/src/locales/`. — MTB-805
- [X] T019 Run `npm run build` in `workbench-frontend` to confirm no TypeScript or build errors. — MTB-806

---

## Dependencies & Execution Order

### Phase Dependencies

- Phase 1 (i18n) → No dependencies, start immediately
- Phase 2 (Store) → No dependencies, can run in parallel with Phase 1
- Phase 3 (US1 Grouping) → Depends on Phase 1 completion (needs new label keys)
- Phase 4 (US2 Icons/Labels) → Depends on Phase 1 completion (needs new label keys); can run in parallel with Phase 3
- Phase 5 (US3 Collapse) → Depends on Phase 2 (store) and Phase 3 (group structure)
- Phase 6 (US4 Hidden Routes) → Depends on Phase 3 (group structure exists)
- Phase 7 (Polish) → Depends on all previous phases

### User Story Dependencies

- **US1 (P1)**: Depends on Phase 1 (i18n). Core grouping structure.
- **US2 (P1)**: Depends on Phase 1 (i18n). Icon and label changes. Can run in parallel with US1.
- **US3 (P2)**: Depends on Phase 2 (store) + US1 (group structure must exist to collapse).
- **US4 (P3)**: Depends on US1 (Reviews group must exist to add items to it).

### Parallel Opportunities

- Phase 1: T001, T002, T003, T004 (all different locale files)
- Phase 3 + Phase 4: T006-T009 and T010-T012 can be interleaved (same file but different sections)
- Phase 7: T017, T018 (different concerns)

---

## Implementation Strategy

### MVP First (US1 + US2 only)

1. Complete Phase 1 (i18n keys)
2. Complete Phase 3 (US1: grouping) + Phase 4 (US2: icons/labels) in parallel
3. **STOP and VALIDATE**: Sidebar shows grouped items with unique icons and consistent labels
4. Deploy to dev for visual verification

### Incremental Delivery

1. Phase 1 + Phase 3 + Phase 4 → Grouped sidebar with correct icons and labels (MVP)
2. Phase 2 + Phase 5 → Collapsible groups with persistent state
3. Phase 6 → Hidden review routes surfaced
4. Phase 7 → Cleanup and build verification

### Suggested MVP Scope

- Phases 1, 3, 4 only (through T012) for the first executable increment

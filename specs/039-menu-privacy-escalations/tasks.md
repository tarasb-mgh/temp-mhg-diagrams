# Tasks: Move Privacy to Security & Hide Escalations

**Input**: Design documents from `/specs/039-menu-privacy-escalations/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, quickstart.md

**Tests**: Not explicitly requested — test tasks are omitted.

**Organization**: Tasks are grouped by user story. Both stories are P1 and independent of each other, so they can be implemented in parallel.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2)
- Include exact file paths in descriptions

---

## Phase 1: Setup

**Purpose**: Create feature branch

- [x] T001 Create feature branch `039-menu-privacy-escalations` from `develop` in `workbench-frontend` — MTB-987

---

## Phase 2: User Story 1 — Privacy Controls Appears Under Security (Priority: P1)

**Goal**: Move the Privacy nav item from the `peopleAccess` group to the `security` group as the last entry, and update the security group's permission filtering to support per-item permissions.

**Independent Test**: Log in as Owner. Verify "Privacy" appears as the last item in the Security sidebar group. Verify it no longer appears under People & Access. Click it — `/workbench/privacy` loads. Collapse Security, navigate to `/workbench/privacy` via URL — Security auto-expands.

- [x] T002 [US1] Remove the Privacy `NavItemConfig` object (path `/workbench/privacy`, icon `ShieldCheck`, permission `WORKBENCH_PRIVACY`) from the `peopleAccess` group items array in `workbench-frontend/src/features/workbench/WorkbenchLayout.tsx` — MTB-991
- [x] T003 [US1] Add the Privacy `NavItemConfig` object as the last item in the `securityNavGroup` items array in `workbench-frontend/src/features/workbench/WorkbenchLayout.tsx`, preserving path `/workbench/privacy`, labelKey `workbench.nav.privacy`, icon `ShieldCheck`, and permission `Permission.WORKBENCH_PRIVACY` — MTB-992
- [x] T004 [US1] Remove the `group.id === 'security'` special case in the `visibleGroups` useMemo so all groups (including security) pass through `filterByPermission` in `workbench-frontend/src/features/workbench/WorkbenchLayout.tsx` — MTB-993

**Checkpoint**: Privacy appears under Security group. Auto-expand works for `/workbench/privacy`. People & Access no longer shows Privacy.

---

## Phase 3: User Story 2 — Escalations Hidden from Sidebar (Priority: P1)

**Goal**: Remove the Escalations nav item from the Reviews sidebar group. The route, component, and permission guard remain untouched.

**Independent Test**: Log in as user with `REVIEW_ESCALATION` permission. Verify "Escalations" does NOT appear in the Reviews group. Navigate to `/workbench/review/escalations` via direct URL — page loads and functions normally.

- [x] T005 [P] [US2] Remove the Escalations `NavItemConfig` object (path `/workbench/review/escalations`, icon `AlertTriangle`, permission `REVIEW_ESCALATION`) from the `reviews` group items array in `workbench-frontend/src/features/workbench/WorkbenchLayout.tsx` — MTB-994
- [x] T006 [P] [US2] Remove the `AlertTriangle` icon import from `workbench-frontend/src/features/workbench/WorkbenchLayout.tsx` if it is no longer referenced anywhere in the file — MTB-995

**Checkpoint**: Escalations no longer appears in sidebar. Route `/workbench/review/escalations` still works via direct URL.

---

## Phase 4: Verification

**Purpose**: Confirm both changes work together and no regressions

- [x] T007 Verify locally that sidebar renders correctly: Privacy under Security (last item), no Escalations in Reviews, People & Access has 4 items, Reviews has 6 items, Security has 6 items — MTB-988
- [x] T008 Verify routes `/workbench/privacy` and `/workbench/review/escalations` load correctly via direct URL navigation — MTB-989
- [x] T009 Open PR from `039-menu-privacy-escalations` to `develop` in `workbench-frontend` with scope, test evidence, and screenshots of the updated sidebar — MTB-990

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **User Story 1 (Phase 2)**: Depends on Phase 1 — T002 → T003 → T004 (sequential, same file region)
- **User Story 2 (Phase 3)**: Depends on Phase 1 — can run in parallel with Phase 2 (different array sections of same file)
- **Verification (Phase 4)**: Depends on Phases 2 and 3 completion

### User Story Dependencies

- **User Story 1 (P1)**: Independent of User Story 2
- **User Story 2 (P1)**: Independent of User Story 1
- Both modify `WorkbenchLayout.tsx` but in different sections (different nav group arrays), so they can be implemented sequentially within a single editing session

### Parallel Opportunities

- T005 and T006 are parallelizable (different sections of the file, independent changes)
- US1 and US2 are logically independent — in practice they'll be done in one commit since it's a single-file change

---

## Implementation Strategy

### Single-Pass Delivery (Recommended)

This feature is small enough to implement in a single editing session:

1. Open `WorkbenchLayout.tsx`
2. Remove Privacy from `peopleAccess` (T002)
3. Add Privacy to `securityNavGroup` (T003)
4. Remove security special case in filtering (T004)
5. Remove Escalations from `reviews` (T005)
6. Clean up `AlertTriangle` import (T006)
7. Local verification (T007, T008)
8. PR (T009)

Total: 9 tasks across 1 file in 1 repository.

---

## Notes

- All code changes are in a single file: `workbench-frontend/src/features/workbench/WorkbenchLayout.tsx`
- No routes, components, permissions, or localization keys are modified
- The `workbench.nav.escalations` locale key becomes unused but is harmless to leave in place
- This spec depends on 033 and 035 sidebar changes being deployed first

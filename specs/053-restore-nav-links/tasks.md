# Tasks: Restore Missing Workbench Navigation Links

**Input**: Design documents from `/specs/053-restore-nav-links/`
**Prerequisites**: `plan.md` (required), `spec.md` (required), `research.md`, `quickstart.md`

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Implementation

**Purpose**: Both US1 and US2 are P1 priority and modify the same file (`WorkbenchLayout.tsx`). They are implemented together in a single phase since they cannot be parallelized (same file) and share the same import change.

### US1 — Tag Center sidebar link

- [X] T001 [US1] Re-add `Tags` icon import from `lucide-react` and add Tag Center nav item as first entry in `peopleAccess` group (`path: '/workbench/tags'`, `labelKey: 'workbench.nav.tagCenter'`, `icon: <Tags>`, `permission: Permission.TAG_MANAGE`) in `workbench-frontend/src/features/workbench/WorkbenchLayout.tsx` — MTB-1346

### US2 — Settings standalone sidebar button

- [X] T002 [US2] Restore Settings standalone button in sidebar nav section, after group-scoped items and before "Back to Chat" link, using existing `settingsItem` config with `isActive` highlight and design system styling in `workbench-frontend/src/features/workbench/WorkbenchLayout.tsx` — MTB-1347

**Checkpoint**: Both nav links visible in sidebar. Tag Center in "People & Access" group, Settings at bottom before "Back to Chat".

---

## Phase 2: Validation

**Purpose**: Verify all acceptance scenarios from spec, design system compliance (US3), and no regressions.

- [X] T003 [P] [US1] Verify Tag Center appears for `TAG_MANAGE` user, hidden for others, active highlight works, and group collapse/expand includes Tag Center on `https://workbench.dev.mentalhelp.chat` — MTB-1348
- [X] T004 [P] [US2] Verify Settings visible and functional on mobile (375px), tablet (768px), and desktop (1280px) viewports; confirm avatar dropdown Settings path still works on desktop on `https://workbench.dev.mentalhelp.chat` — MTB-1349
- [X] T005 [US3] Visual consistency check: compare Tag Center and Settings items against existing sidebar items (Users, Groups, Review Queue) for identical icon size, spacing, hover/active states, and touch target height on `https://workbench.dev.mentalhelp.chat` — MTB-1350
- [X] T006 Regression check: confirm all previously visible sidebar items unchanged, breadcrumbs correct for Tag Center and Settings, no navigation regressions on `https://workbench.dev.mentalhelp.chat` — MTB-1345

**Checkpoint**: All acceptance scenarios pass. Feature complete.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Implementation)**: No dependencies — can start immediately
- **Phase 2 (Validation)**: Depends on Phase 1 + deployment to dev environment

### User Story Dependencies

- **US1 (Tag Center)** and **US2 (Settings)**: Both modify the same file — must be sequential (T001 → T002)
- **US3 (Design system)**: Validated during Phase 2 (T005) — depends on T001 and T002

### Within Phase 1

- T001 before T002 (same file, sequential edits)

### Parallel Opportunities

- T003 and T004 can run in parallel (independent validation checks)
- T005 and T006 depend on T003/T004 completing (visual check after functional confirmation)

---

## Implementation Strategy

### Single-pass delivery

This feature is small enough for single-pass delivery:

1. Implement T001 + T002 in one commit
2. Deploy to dev via `workflow_dispatch`
3. Run validation (T003–T006) on dev
4. Open PR to `develop`

---

## Notes

- No Setup or Foundational phases needed — this is a config-level change in an existing file
- No new files, routes, APIs, or translations required
- The `settingsItem` config object already exists in `WorkbenchLayout.tsx` (line 189–193) but is not rendered in the sidebar
- The `Tags` icon import was removed during 048 and needs to be re-added

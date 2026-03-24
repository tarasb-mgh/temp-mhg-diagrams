# Implementation Plan: Move Privacy to Security & Hide Escalations

**Branch**: `039-menu-privacy-escalations` | **Date**: 2026-03-24 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/039-menu-privacy-escalations/spec.md`

## Summary

Two sidebar navigation changes in `workbench-frontend`: (1) move the Privacy nav item from the `peopleAccess` group to the `security` group as its last entry, and (2) remove the Escalations nav item from the `reviews` group. No routes, components, permissions, or localization keys are modified. The only file requiring changes is `WorkbenchLayout.tsx` (nav configuration arrays).

## Technical Context

**Language/Version**: TypeScript 5.x, React 18  
**Primary Dependencies**: React, react-router-dom, Lucide React (icons), Zustand (workbench store), react-i18next  
**Storage**: N/A (no data changes)  
**Testing**: Vitest (unit), Playwright in chat-ui (E2E)  
**Target Platform**: Web (desktop + mobile responsive)  
**Project Type**: Web application (SPA)  
**Performance Goals**: N/A (pure config change, no runtime impact)  
**Constraints**: None beyond existing sidebar rendering  
**Scale/Scope**: Single file change in one repository

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Spec-First Development | ✅ Pass | Spec exists at `specs/039-menu-privacy-escalations/spec.md` |
| II. Multi-Repository Orchestration | ✅ Pass | Single repo (`workbench-frontend`) affected |
| III. Test-Aligned Development | ✅ Pass | Playwright sidebar tests should verify new menu structure |
| IV. Branch and Integration Discipline | ✅ Pass | Feature branch → PR → `develop` |
| V. Privacy and Security First | ✅ Pass | No user data changes; moving a nav item does not affect privacy/security logic |
| VI. Accessibility and Internationalization | ✅ Pass | No new user-visible text; existing i18n keys reused |
| VI-B. Design System Compliance | ✅ Pass | No UI component changes; sidebar rendering logic unchanged |
| VII. Split-Repository First | ✅ Pass | Change targets `workbench-frontend` (split repo) |
| VIII. GCP CLI Infrastructure | ✅ N/A | No infrastructure changes |
| IX. Responsive UX and PWA | ✅ Pass | Sidebar mobile behavior unchanged |
| X. Jira Traceability | ✅ Pass | Jira Epic to be created |
| XI. Documentation Standards | ✅ Pass | User Manual may need minor update to reflect menu reorganization |
| XII. Release Engineering | ✅ Pass | Standard feature deployment cycle |

No violations. No Complexity Tracking needed.

## Project Structure

### Documentation (this feature)

```text
specs/039-menu-privacy-escalations/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
└── tasks.md             # Phase 2 output (created by /speckit.tasks)
```

### Source Code (affected files)

```text
workbench-frontend/
└── src/features/workbench/WorkbenchLayout.tsx   # Nav group configuration
```

**Structure Decision**: This is a minimal config-level change within a single existing file. No new files, modules, or directories are needed.

## Implementation Approach

### Change 1: Move Privacy from peopleAccess to security

**Current code** (`WorkbenchLayout.tsx`):
- Privacy item is the last entry in the `peopleAccess` group's `items` array (~line 167-171)
- Security group is a separate `securityNavGroup` constant (~line 176-187) with its own items array
- Security group items currently bypass per-item permission filtering (line 292-293: `group.id === 'security' ? group.items`)

**Required changes**:
1. Remove the Privacy `NavItemConfig` object from `navGroups[2].items` (the `peopleAccess` group)
2. Add it as the last entry in `securityNavGroup.items`
3. Update the `visibleGroups` filtering logic: the security group currently returns `group.items` unfiltered because all security items share the group-level gate. With Privacy added (which has its own `permission: Permission.WORKBENCH_PRIVACY`), the security group must still work correctly. Since all security admins who can see the group will also have `WORKBENCH_PRIVACY` (Owners have all permissions; Security Admins have `SECURITY_VIEW`/`SECURITY_MANAGE`/`SECURITY_FEATURE_FLAG` only — they may NOT have `WORKBENCH_PRIVACY`), Privacy should be filtered by its `permission` within the security group. The simplest fix: remove the special-case `group.id === 'security'` branch and let all groups use the standard `filterByPermission` path, OR keep the special case but apply `filterByPermission` to Privacy specifically.

**Decision**: Remove the `group.id === 'security'` special case. Let all groups (including security) pass through `filterByPermission`. This is correct because:
- Existing security items have no `permission` field → `filterByPermission` passes items without `permission` through (they rely on the group-level `isSecurityAdmin` gate)
- Privacy has `permission: Permission.WORKBENCH_PRIVACY` → it will be filtered correctly within the group
- This simplifies the code and makes future security group items with permissions work automatically

**Auto-expand**: The existing `isActive` → `groupHasActiveRoute` → `isGroupCollapsed` logic already handles this correctly. When a user is on `/workbench/privacy`, the Security group will have an active route and auto-expand. The People & Access group will no longer match this path since the item is removed.

### Change 2: Remove Escalations from reviews

**Current code** (`WorkbenchLayout.tsx`):
- Escalations item is in the `reviews` group's `items` array (~line 100-105)

**Required change**:
1. Remove the Escalations `NavItemConfig` object from `navGroups[0].items` (the `reviews` group)
2. The route definition in `WorkbenchShell.tsx` remains untouched
3. The `AlertTriangle` icon import can be removed if no other component uses it (verify first)

### What NOT to change

- **Routes**: `/workbench/privacy` and `/workbench/review/escalations` routes in `WorkbenchShell.tsx` stay intact
- **Components**: Privacy page component and Escalations page component are untouched
- **Permissions**: `WORKBENCH_PRIVACY` and `REVIEW_ESCALATION` enum values remain
- **Localization**: `workbench.nav.privacy` and `workbench.nav.escalations` keys remain in locale files (unused keys are harmless)
- **Icon imports**: `ShieldCheck` is still used (by Privacy in its new location). `AlertTriangle` may become unused — check and clean up if so

## Cross-Repository Dependencies

None. This is a single-repository change in `workbench-frontend`.

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Security Admin without `WORKBENCH_PRIVACY` can't see Privacy | Expected | Low | Intentional per spec — Privacy inherits Security group visibility |
| Removing `group.id === 'security'` special case breaks security items | Low | Medium | Security items have no `permission` field → `filterByPermission` passes them through unchanged |
| Stale collapsed state for peopleAccess after Privacy removal | None | None | Collapse state is per-group, not per-item; removing an item doesn't invalidate the group's state |
| Escalations unreachable after sidebar removal | Low | Low | Route remains functional; in-flow links preserved; direct URL works |

## Execution Order

1. Create feature branch `039-menu-privacy-escalations` from `develop` in `workbench-frontend`
2. Modify `WorkbenchLayout.tsx`:
   a. Remove Privacy from `peopleAccess` group
   b. Add Privacy to `securityNavGroup` as last item
   c. Remove Escalations from `reviews` group
   d. Remove `group.id === 'security'` special case in `visibleGroups` filtering
   e. Clean up unused `AlertTriangle` import (if applicable)
3. Verify locally: sidebar renders correctly for Owner role, Privacy under Security, no Escalations
4. Open PR to `develop`, run CI
5. After merge + deploy to dev: Playwright verification (SC-001 through SC-006)

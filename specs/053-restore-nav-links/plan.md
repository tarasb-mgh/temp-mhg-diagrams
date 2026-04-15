# Implementation Plan: Restore Missing Workbench Navigation Links

**Branch**: `053-restore-nav-links` | **Date**: 2026-04-15 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/053-restore-nav-links/spec.md`

## Summary

Restore two sidebar navigation links that were unintentionally removed during the Workbench MVP refactor (048, 2026-04-09): Tag Center in the "People & Access" group and Settings as a standalone button before "Back to Chat". The implementation is a single-file edit in `workbench-frontend/src/features/workbench/WorkbenchLayout.tsx` — no new routes, pages, APIs, or translation keys are required.

## Technical Context

**Language/Version**: TypeScript 5.x, React 18  
**Primary Dependencies**: react-router-dom, lucide-react, react-i18next  
**Storage**: N/A  
**Testing**: Vitest + React Testing Library (unit), Playwright in `chat-ui` (E2E)  
**Target Platform**: Web (mobile, tablet, desktop)  
**Project Type**: Web application (workbench SPA)  
**Performance Goals**: N/A (static navigation, no runtime cost)  
**Constraints**: Must match existing design system tokens (Principle VI-B)  
**Scale/Scope**: 1 file changed, ~15 lines added

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Applies | Status | Notes |
|-----------|---------|--------|-------|
| I | Spec-First Development | PASS | Approved spec exists in `specs/053-restore-nav-links/spec.md` |
| II | Multi-Repository Orchestration | PASS | Single repo affected (`workbench-frontend`) |
| III | Test-Aligned Development | PASS | E2E validation via Playwright; unit test for nav item presence |
| IV | Branch and Integration Discipline | PASS | Feature branch `053-restore-nav-links` in workbench-frontend; PR to `develop` |
| V | Privacy and Security First | N/A | No user data changes |
| VI | Accessibility and i18n | PASS | i18n keys already exist (en, uk, ru); touch targets match existing 44px/40px pattern |
| VI-B | Design System Compliance | PASS | Uses existing Lucide icons, design system color tokens, and established nav item patterns |
| VII | Split-Repository First | PASS | Only `workbench-frontend` affected |
| VIII | GCP CLI Infrastructure | N/A | No infrastructure changes |
| IX | Responsive UX and PWA | PASS | Settings link restores mobile access; Tag Center uses existing responsive sidebar |
| X | Jira Traceability | PASS | Jira Epic will be created with spec content |
| XI | Documentation Standards | DEFERRED | User Manual update if nav screenshots exist (post-implementation) |
| XII | Release Engineering | N/A | Not a release; PR to `develop` only |

## Project Structure

### Documentation (this feature)

```text
specs/053-restore-nav-links/
├── spec.md
├── plan.md              # This file
├── research.md          # Phase 0 output
├── quickstart.md        # Phase 1 output
└── checklists/
    └── requirements.md  # Spec quality validation
```

### Source Code (affected files)

```text
workbench-frontend/
└── src/features/workbench/WorkbenchLayout.tsx   # Sidebar navigation config

chat-ui/
└── tests/e2e/workbench/navigation.spec.ts       # E2E nav validation (if exists)
```

**Structure Decision**: Single-file implementation in `workbench-frontend`. The change is entirely within the `WorkbenchLayout.tsx` navigation configuration arrays — no new files, components, or modules are created.

### Affected repositories

| # | Repository | Changes | Execution order |
|---|------------|---------|-----------------|
| 1 | workbench-frontend | Add Tag Center nav item to `peopleAccess` group; restore Settings standalone button | First (and only) |

## Implementation Details

### Change 1: Tag Center nav item in "People & Access" group

Add a `NavItemConfig` entry to the `peopleAccess` group in the `navGroups` array, positioned as the **first item** (before Users):

- `path`: `/workbench/tags`
- `labelKey`: `workbench.nav.tagCenter`
- `icon`: `<Tags className="w-5 h-5" />`
- `permission`: `Permission.TAG_MANAGE`

This requires re-adding the `Tags` import from `lucide-react`.

### Change 2: Settings standalone button restored

Restore the Settings button as a standalone navigation item rendered **after** the nav groups and group-scoped section, but **before** the "Back to Chat" link. This matches the pre-048 layout.

The button uses the existing `settingsItem` config object (already defined but not rendered in the sidebar since 048). The rendering pattern follows the same `isActive`/hover/click pattern as the dashboard button.

### Change 3: Breadcrumb registration

The `allNavItems` memo already includes `settingsItem`. The Tag Center item will be included automatically via `visibleGroups.flatMap(g => g.visibleItems)` since it will be part of the `peopleAccess` group. No additional breadcrumb changes needed.

## Complexity Tracking

No constitution violations. No complexity justifications needed.

# Phase 0 Research: Restore Missing Workbench Navigation Links

## R1: Root cause of removed links

**Decision**: The links were removed during the Workbench MVP refactor (feature 048, commit `44fb0f7`, 2026-04-09). The `WorkbenchLayout.tsx` navigation arrays were restructured to add new groups (expertise, agents) and the Tag Center entry was dropped from the `peopleAccess` group. The Settings standalone button was removed from the sidebar rendering (though the `settingsItem` config object was preserved).

**Evidence**:
- `git diff b14ef33..44fb0f7 -- src/features/workbench/WorkbenchLayout.tsx` shows the `Tags` icon import removed, the Tag Center nav item deleted from `peopleAccess`, and the Settings button JSX block removed from the sidebar.
- The route in `WorkbenchShell.tsx` at `/workbench/tags` was never removed — only the nav entry.
- The `settingsItem` config object still exists in current code (line 189-193) but is not rendered as a button.

**Alternatives considered**: None — this is a restoration, not a design decision.

## R2: Existing translation keys

**Decision**: All required i18n keys already exist in all three locale files. No translation work needed.

**Evidence**:
- `en.json` line 187: `"tagCenter": "Tag Center"` (under `workbench.nav`)
- `uk.json` line 187: `"tagCenter": "Центр тегів"`
- `ru.json` line 187: `"tagCenter": "Центр тегов"`
- `en.json` line 196: `"settings": "Settings"` (under `workbench.nav`)

## R3: Permission gating pattern

**Decision**: Use the existing `permission` field in `NavItemConfig` with `Permission.TAG_MANAGE` for Tag Center. Settings has no permission gate (accessible to all authenticated Workbench users). This matches the pre-048 behavior and the route guards in `WorkbenchShell.tsx`.

**Evidence**: The route guard at `WorkbenchShell.tsx` line 140 uses `<SubRouteGuard requiredPermission={Permission.TAG_MANAGE}>`.

## R4: Design system compliance

**Decision**: Use existing patterns from the sidebar — no new styles, tokens, or components needed. The `Tags` icon from Lucide was the original choice and remains appropriate.

**Evidence**: Pre-048 diff shows `Tags` from `lucide-react` was used with `className="w-5 h-5"`, matching all other sidebar icons. The nav item styling uses `isActive()` for highlight state, standard Tailwind classes from the design system (`bg-primary-50`, `text-primary-700`, `font-medium` for active; `text-neutral-600`, `hover:bg-neutral-50` for default).

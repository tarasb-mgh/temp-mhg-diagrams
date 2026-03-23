# Quickstart: Workbench Sidebar Menu Reorganization (033)

## Prerequisites

- Node.js 18+
- Access to `workbench-frontend` repository on branch `033-workbench-menu-groups`
- Local dev environment with `npm install` completed

## Target Repository

All changes are in `workbench-frontend`. No other repositories are affected.

## Files to Modify

| File | Change Type | Purpose |
| ---- | ----------- | ------- |
| `src/features/workbench/WorkbenchLayout.tsx` | Major refactor | Replace flat `navItems` array with `navGroups` config; add group rendering logic; update icon imports |
| `src/stores/workbenchStore.ts` | Add state | Add `navGroupCollapsed` map and `toggleNavGroup` action; extend `partialize` |
| `src/locales/en.json` | Add/rename keys | Add group heading keys, new item keys, rename shortened labels |
| `src/locales/uk.json` | Add/rename keys | Ukrainian translations for all new/renamed keys |
| `src/locales/ru.json` | Add/rename keys | Russian translations for all new/renamed keys |

## Implementation Order

1. **Localization first**: Add all new i18n keys to all 3 locale files.
2. **Store**: Add collapse state and toggle action to `workbenchStore`.
3. **NavGroup config**: Define `NavGroupConfig` interface and `navGroups` array in `WorkbenchLayout.tsx`.
4. **Sidebar rendering**: Replace the flat item loop with group-based rendering (headings, collapse/expand, permission filtering at group level).
5. **Icon deduplication**: Update all icon imports and assignments per research.md icon mapping.
6. **Group Resources**: Reposition contextual block between last static group and Settings.
7. **Testing**: Verify all 5 roles see correct items, collapse state persists, no empty groups render.

## Local Verification

```bash
cd workbench-frontend
npm run dev
```

1. Open `http://localhost:5173/workbench`
2. Verify sidebar shows grouped items with headings
3. Click a group heading to collapse/expand
4. Navigate to a different page — verify collapse state persists
5. Switch to a role with limited permissions — verify empty groups are hidden
6. Check mobile viewport (< 768px) — verify off-canvas drawer works with groups

## Key Technical Notes

- `lucide-react@0.460.0` is already installed — all proposed icons are available
- Zustand persist uses `workbench-storage` localStorage key — existing users will get the new collapse state added seamlessly
- No route changes are needed — all routes already exist in `WorkbenchShell.tsx`
- The breadcrumb bar works automatically since it derives from path matching, not group structure

# Contract: Sidebar Navigation Configuration

## Purpose

Define the declarative configuration interface for the workbench sidebar so that menu structure changes require only data modifications, not structural code changes (FR-012).

## NavItemConfig Interface

```typescript
interface NavItemConfig {
  path: string;
  labelKey: string;
  icon: React.ReactNode;
  permission?: Permission;
  anyPermissions?: Permission[];
}
```

No changes from the existing interface.

## NavGroupConfig Interface (new)

```typescript
interface NavGroupConfig {
  id: string;
  labelKey: string;
  items: NavItemConfig[];
  collapsible?: boolean; // default: true
}
```

## Sidebar Configuration Shape

```typescript
const dashboardItem: NavItemConfig = { ... };
const settingsItem: NavItemConfig = { ... };
const navGroups: NavGroupConfig[] = [
  { id: 'reviews', labelKey: 'workbench.nav.group.reviews', items: [...] },
  { id: 'surveys', labelKey: 'workbench.nav.group.surveys', items: [...] },
  { id: 'peopleAccess', labelKey: 'workbench.nav.group.peopleAccess', items: [...] },
];
```

Rendering order:
1. `dashboardItem` (ungrouped, top)
2. `navGroups` in array order (each with heading + filtered items)
3. Group Resources contextual block (existing pattern, unchanged)
4. `settingsItem` (ungrouped, bottom-pinned)

## Permission Filtering Contract

For each group in `navGroups`:
1. Filter `group.items` by user permissions (same logic as current `visibleNavItems`).
2. If filtered items count is 0, skip the entire group (heading + items).
3. If filtered items count > 0, render the group heading and visible items.

## Collapse State Contract

```typescript
// In workbenchStore
interface WorkbenchState {
  // ... existing fields ...
  navGroupCollapsed: Record<string, boolean>;
  toggleNavGroup: (groupId: string) => void;
}
```

- Key: `NavGroupConfig.id`
- Value: `true` = collapsed, `false` or absent = expanded
- Default: all groups expanded (empty map)
- Auto-expand: if `location.pathname` starts with any item's `path` in a collapsed group, treat as expanded for that render

## Localization Contract

New keys required in `en.json`, `uk.json`, `ru.json`:

```json
{
  "workbench": {
    "nav": {
      "group": {
        "reviews": "Reviews",
        "surveys": "Surveys",
        "peopleAccess": "People & Access"
      },
      "reviewQueue": "Review Queue",
      "reviewDashboard": "Review Dashboard",
      "teamDashboard": "Team Dashboard",
      "escalations": "Escalations",
      "reviewTags": "Review Tags",
      "reviewSettings": "Review Settings",
      "surveyTemplates": "Survey Templates",
      "testerTags": "Tester Tags"
    }
  }
}
```

Renamed keys (old key → new key):
- `workbench.nav.research` → `workbench.nav.reviewQueue`
- `workbench.nav.surveySchemas` → `workbench.nav.surveyTemplates`
- `workbench.nav.testerTagManagement` → `workbench.nav.testerTags`
- `workbench.nav.users` label change: "User Management" → "Users"
- `workbench.nav.groups` label change: "Group management" → "Groups"
- `workbench.nav.privacy` label change: "Privacy Controls" → "Privacy"
- `workbench.nav.reviewReports` label change: "Reports & Analytics" → "Reports"
- `workbench.nav.tagManagement` → `workbench.nav.reviewTags`

Old keys may be retained temporarily for backward compatibility but are not referenced by sidebar code after migration.

## Validation Rules

1. Every `NavGroupConfig.id` must be unique.
2. Every `NavItemConfig.icon` must be a unique Lucide component (no two items share the same icon).
3. Every `NavItemConfig.labelKey` must resolve to a non-empty string in all 3 locales.
4. Every `NavGroupConfig.labelKey` must resolve to a non-empty string in all 3 locales.
5. No `NavItemConfig` appears in more than one group.

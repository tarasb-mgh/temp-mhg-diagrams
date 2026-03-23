# Data Model: Workbench Sidebar Menu Reorganization (033)

## Overview

This feature modifies the sidebar navigation data structure in `workbench-frontend`. No backend data model changes are required. All entities below are frontend-only TypeScript interfaces.

## Entities

### 1) NavItemConfig (modified)

Extends the existing interface with no breaking changes.

- Purpose: Defines a single sidebar navigation entry.
- Fields:
  - `path`: string — route path (e.g., `/workbench/review`)
  - `labelKey`: string — i18n translation key (e.g., `workbench.nav.reviewQueue`)
  - `icon`: ReactNode — Lucide icon component instance
  - `permission?`: Permission — single required permission (optional)
  - `anyPermissions?`: Permission[] — any-of permission set (optional)
- Validation rules:
  - At least `path`, `labelKey`, and `icon` are required.
  - `permission` and `anyPermissions` are mutually exclusive.
- Changes from current: No structural changes. Label keys and icons will be updated per research.md decisions.

### 2) NavGroupConfig (new)

- Purpose: Defines a named, collapsible group of navigation items.
- Fields:
  - `id`: string — stable identifier for collapse state tracking (e.g., `reviews`, `surveys`, `peopleAccess`)
  - `labelKey`: string — i18n translation key for the group heading (e.g., `workbench.nav.group.reviews`)
  - `items`: NavItemConfig[] — ordered list of child navigation items
  - `collapsible`: boolean — whether the group supports expand/collapse (default: `true`)
- Validation rules:
  - `id` must be unique across all groups.
  - `items` must contain at least one item in the static definition (permission filtering may result in zero visible items at runtime, in which case the group is hidden per FR-005).
  - `labelKey` must have translations in all 3 locales (en, uk, ru).

### 3) NavGroupCollapseState (new)

- Purpose: Tracks which groups are collapsed/expanded per user session.
- Fields:
  - Map structure: `Record<string, boolean>` where key is `NavGroupConfig.id` and value is `true` for collapsed, `false` or absent for expanded.
- Storage: Zustand `workbenchStore` with `persist` middleware (localStorage key: `workbench-storage`).
- Validation rules:
  - Unknown group IDs in stored state are silently ignored (forward compatibility).
  - Missing group IDs default to expanded (FR-015: all groups expanded on first visit).

## Relationships

- `NavGroupConfig (1) -> (N) NavItemConfig` via `items` array
- `NavGroupCollapseState` references `NavGroupConfig.id` as keys
- Permission filtering operates on `NavItemConfig` level, then `NavGroupConfig` visibility is derived (group visible if at least one child visible)

## State Transitions

### NavGroupCollapseState per group

```
expanded (default) -> collapsed (user clicks heading)
collapsed -> expanded (user clicks heading)
collapsed -> expanded (auto-expand when active route is within group, per FR-004)
```

## Sidebar Rendering Data Flow

1. Static `navGroups: NavGroupConfig[]` defines all groups and items.
2. Permission filter: for each group, filter `items` by user permissions → `visibleItems`.
3. Group filter: hide groups where `visibleItems.length === 0`.
4. Collapse state: read from `workbenchStore.navGroupCollapsed[group.id]`.
5. Auto-expand override: if current route matches any item in a collapsed group, treat as expanded.
6. Render: Dashboard (ungrouped) → visible groups in order → Group Resources block (if active group) → Settings (ungrouped, bottom).

## Full Navigation Item Inventory

### Static Groups

| Group ID | Group Label (en) | Item Label (en) | Path | Icon | Permission |
| -------- | ---------------- | --------------- | ---- | ---- | ---------- |
| (ungrouped) | — | Dashboard | `/workbench` | LayoutDashboard | none |
| reviews | Reviews | Review Queue | `/workbench/review` | ClipboardCheck | REVIEW_ACCESS |
| reviews | Reviews | Review Dashboard | `/workbench/review/dashboard` | BarChart3 | REVIEW_ACCESS |
| reviews | Reviews | Reports | `/workbench/review/reports` | FileBarChart | REVIEW_REPORTS |
| reviews | Reviews | Team Dashboard | `/workbench/review/team` | UsersRound | REVIEW_TEAM_DASHBOARD |
| reviews | Reviews | Escalations | `/workbench/review/escalations` | AlertTriangle | REVIEW_ESCALATION |
| reviews | Reviews | Review Tags | `/workbench/review/tags` | Tags | TAG_MANAGE |
| reviews | Reviews | Review Settings | `/workbench/review/config` | Wrench | REVIEW_CONFIGURE |
| surveys | Surveys | Survey Templates | `/workbench/surveys/schemas` | FileText | SURVEY_SCHEMA_MANAGE |
| surveys | Surveys | Survey Instances | `/workbench/surveys/instances` | ListChecks | SURVEY_INSTANCE_MANAGE or SURVEY_INSTANCE_VIEW |
| peopleAccess | People & Access | Users | `/workbench/users` | UserCog | WORKBENCH_USER_MANAGEMENT |
| peopleAccess | People & Access | Groups | `/workbench/groups` | Building2 | WORKBENCH_USER_MANAGEMENT or SURVEY_INSTANCE_MANAGE or SURVEY_INSTANCE_VIEW |
| peopleAccess | People & Access | Approvals | `/workbench/approvals` | UserCheck | WORKBENCH_USER_MANAGEMENT |
| peopleAccess | People & Access | Tester Tags | `/workbench/users/tester-tags` | Tag | TESTER_TAG_MANAGE |
| peopleAccess | People & Access | Privacy | `/workbench/privacy` | ShieldCheck | WORKBENCH_PRIVACY |
| (ungrouped) | — | Settings | `/workbench/settings` | Settings | none |

### Contextual Group Resources Block

| Item Label (en) | Path | Icon | Permission |
| --------------- | ---- | ---- | ---------- |
| Group Dashboard | `/workbench/group` | LayoutDashboard | WORKBENCH_GROUP_DASHBOARD |
| Group Users | `/workbench/group/users` | Users | WORKBENCH_GROUP_USERS |
| Group Chats | `/workbench/group/sessions` | MessageSquare | WORKBENCH_GROUP_RESEARCH or WORKBENCH_USER_MANAGEMENT |
| Group Surveys | `/workbench/groups/:groupId/surveys` | ClipboardList | SURVEY_INSTANCE_MANAGE or SURVEY_INSTANCE_VIEW |

### Excluded Routes (not in sidebar)

| Route | Reason |
| ----- | ------ |
| `/workbench/review/session/:sessionId` | Detail view (requires session ID parameter) |
| `/workbench/review/supervision/:sessionReviewId` | Detail view (requires session review ID parameter) |
| `/workbench/review/deanonymization` | Sensitive operation; accessible only via in-flow navigation |
| `/workbench/research` | Redirect to `/workbench/review` |
| `/workbench/research/session/:sessionId` | Redirect to review session |
| `/workbench/research-legacy` | Legacy route, out of scope |
| `/workbench/research-legacy/session/:sessionId` | Legacy route, out of scope |
| `/workbench/users/:userId` | Detail view (requires user ID parameter) |
| `/workbench/surveys/schemas/:id/edit` | Detail view (requires schema ID parameter) |
| `/workbench/surveys/instances/:id` | Detail view (requires instance ID parameter) |
| `/workbench/surveys/instances/:id/responses` | Detail view (requires instance ID parameter) |
| `/workbench/group/sessions/:sessionId` | Detail view (requires session ID parameter) |

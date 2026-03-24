# Data Model: Move Privacy to Security & Hide Escalations

**Feature**: 039-menu-privacy-escalations  
**Date**: 2026-03-24

## Entity Changes

No new entities are introduced. No existing entities are modified. This feature changes only the **configuration data** that populates existing interfaces.

### NavGroupConfig (unchanged interface)

```typescript
interface NavGroupConfig {
  id: string;
  labelKey: string;
  items: NavItemConfig[];
}
```

**Data changes**:

| Group ID | Change | Items After |
|----------|--------|-------------|
| `reviews` | Remove Escalations entry | Review Queue, Review Dashboard, Reports, Team Dashboard, Review Tags, Review Settings (6 items, was 7) |
| `peopleAccess` | Remove Privacy entry | Users, Groups, Approvals, Tester Tags (4 items, was 5) |
| `security` | Add Privacy entry at end | Dashboard, Principal Groups, Permissions, Assignments, Effective Permissions, **Privacy** (6 items, was 5) |

### NavItemConfig (unchanged interface)

```typescript
interface NavItemConfig {
  path: string;
  labelKey: string;
  icon: React.ReactNode;
  permission?: Permission;
  anyPermissions?: Permission[];
}
```

**Moved item** (Privacy — no property changes):

| Property | Value |
|----------|-------|
| `path` | `/workbench/privacy` |
| `labelKey` | `workbench.nav.privacy` |
| `icon` | `<ShieldCheck className="w-5 h-5" />` |
| `permission` | `Permission.WORKBENCH_PRIVACY` |

**Removed item** (Escalations — deleted from config, route preserved):

| Property | Value |
|----------|-------|
| `path` | `/workbench/review/escalations` |
| `labelKey` | `workbench.nav.escalations` |
| `icon` | `<AlertTriangle className="w-5 h-5" />` |
| `permission` | `Permission.REVIEW_ESCALATION` |

## Visibility Logic Change

### Current (security group special case)

```typescript
visibleItems: group.id === 'security'
  ? group.items
  : filterByPermission(group.items, user?.permissions)
```

### Target (uniform filtering)

```typescript
visibleItems: filterByPermission(group.items, user?.permissions)
```

All groups pass through `filterByPermission`. Security items without `permission` field pass through unchanged (existing behavior). Privacy's `permission: Permission.WORKBENCH_PRIVACY` is evaluated within the security group.

## Routes (no changes)

| Route | Permission Guard | Status |
|-------|-----------------|--------|
| `/workbench/privacy` | `Permission.WORKBENCH_PRIVACY` | Unchanged |
| `/workbench/review/escalations` | `Permission.REVIEW_ESCALATION` | Unchanged |

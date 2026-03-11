# Data Model: User Group and Management Interface Enhancements

**Date**: 2026-03-10
**Branch**: `023-user-group-enhancements`

---

## No Database Migrations Required

All changes are service-logic and UI-layer only. No new tables or columns are added.

---

## Existing Entities (Referenced)

### `users`

| Column | Type | Relevant to |
|--------|------|-------------|
| `id` | uuid | primary key |
| `role` | `UserRole` enum | US1 (privileged check), US3, US7 |
| `active_group_id` | uuid nullable | FK → `user_groups.id` |
| `display_name` | text | US8 display |
| `email` | text | US8 copy icon |

**Privileged roles** (used in `isPrivilegedRole` helper): `OWNER`, `MODERATOR`, `SUPERVISOR`

### `group_memberships`

| Column | Type | Relevant to |
|--------|------|-------------|
| `user_id` | uuid FK → `users` | US1 |
| `group_id` | uuid FK → `user_groups` | US1 |
| `role` | `'member' \| 'admin'` | US1 (privileged accounts join as `member`) |
| `status` | `'active' \| 'pending'` | US1 |

**Change**: `addUserToGroup` in `group.service.ts` removes `OWNER`, `MODERATOR`, `SUPERVISOR` from the `FORBIDDEN_TARGET_ROLE` blocklist. They are inserted as `role = 'member', status = 'active'`.

### `survey_instances`

| Column | Type | Relevant to |
|--------|------|-------------|
| `id` | uuid | primary key |
| `schema_id` | uuid FK → `survey_schemas` | US5 deduplication key |
| `group_ids` | uuid[] | groups this instance is assigned to; shared across groups |
| `status` | enum | US4 display |
| `title` | text | US4 |

**Deduplication model** (US5): A single `survey_instances` row is assigned to multiple groups via `group_ids[]`. One completion record (by `pseudonymous_id + instance_id`) marks the survey complete in all groups that share the instance. This is verified in `getGateCheck`: a completed `instance_id` is excluded from all groups' pending lists.

### `survey_responses`

| Column | Type | Relevant to |
|--------|------|-------------|
| `id` | uuid | primary key |
| `instance_id` | uuid FK → `survey_instances` | US5 deduplication |
| `pseudonymous_id` | text | user identifier |
| `group_id` | uuid | which group context the response was submitted in |
| `is_complete` | boolean | completion gate |
| `invalidated_at` | timestamp nullable | US6 invalidation state |

### `group_survey_order`

| Column | Type | Relevant to |
|--------|------|-------------|
| `group_id` | uuid FK → `user_groups` | US4 ordering |
| `instance_id` | uuid FK → `survey_instances` | US4 ordering |
| `display_order` | integer | sort key for group members' survey list |

---

## Frontend State Model Changes

### `workbenchStore` (Zustand)

**New field**: `groupListVersion: number` (initial value `0`)
**New action**: `bumpGroupListVersion(): void` — increments `groupListVersion` by 1

**Usage**: `GroupsView.handleCreateGroup` calls `bumpGroupListVersion()` after a successful group creation API response. `GroupScopeSelector` includes `groupListVersion` in its managed-group re-fetch `useEffect` dependency array, triggering an immediate re-fetch.

### `UserListView` URL Search Params Schema

Filter state moves from component `useState` to `useSearchParams`. URL encodes:

| Param | Type | Default |
|-------|------|---------|
| `q` | string | `''` (search query) |
| `role` | `UserRole \| 'all'` | `'all'` |
| `status` | string | `'all'` |
| `sort` | `SortOption` | `'created_at_desc'` |
| `testOnly` | `'1' \| '0'` | `'0'` |
| `page` | number string | `'1'` |
| `pageSize` | number string | `'10'` |

Navigation to `/workbench/users/:userId` preserves the full URL. Browser back navigation restores the URL including all params.

---

## New Component Interface

### `InvalidationMenu` Props

```typescript
interface InvalidationMenuProps {
  instanceId: string;
  groupOptions: Array<{ id: string; name: string }>;
  // Called after a successful invalidation action; parent re-fetches data
  onInvalidated: () => void;
  // Whether to show response-level invalidation (only in SurveyResponseListView)
  responseId?: string;
}
```

**Actions exposed**:

| Action | Risk Level | Role Gate |
|--------|------------|-----------|
| Invalidate single response (`responseId` only) | Low | `SURVEY_INSTANCE_MANAGE` |
| Invalidate group responses | Medium | `OWNER` or `MODERATOR` |
| Invalidate all responses for instance | High | `OWNER` or `MODERATOR` |

**Confirmation modal**: Renders a React modal (no third-party library) with action description, consequences text, Cancel button, and Confirm button. No data is modified until Confirm is clicked.

---

## API Contract Changes (Backend)

See `contracts/` directory for full OpenAPI fragments.

### `POST /api/admin/groups/:groupId/members` (US1)

**Change**: Remove `FORBIDDEN_TARGET_ROLE` error for `OWNER`, `MODERATOR`, `SUPERVISOR` roles. These users can now be added as group members with `role = 'member'`.

**Retained restriction**: `RESEARCHER`, `GROUP_ADMIN` roles still return `403 FORBIDDEN` with `FORBIDDEN_TARGET_ROLE`.

### `GET /api/admin/users` (US7)

**Change**: Add `privileged=true` query parameter. When set, filters results to users with roles in `['owner', 'moderator', 'supervisor']`.

**No breaking change**: Existing callers without `privileged` param receive unchanged behavior.

# Data Model: Dynamic Permissions Engine

**Feature Branch**: `035-dynamic-permissions-engine`
**Date**: 2026-03-20

## Overview

Four new tables plus one column added to the existing `settings` table. No changes to existing `users`, `group_memberships`, or `audit_log` tables.

## New Tables

### `permissions` — Registry of all known permissions

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK, DEFAULT gen_random_uuid() | Primary key |
| key | VARCHAR(100) | UNIQUE, NOT NULL | Permission identifier (e.g., `review:submit`) |
| display_name | VARCHAR(255) | NOT NULL | Human-readable label |
| category | VARCHAR(50) | NOT NULL | Grouping: chat, workbench, review, tag, survey, data, security, group |
| scope_types | VARCHAR(20)[] | NOT NULL | Applicable scopes: `{platform}`, `{platform,group}`, or `{group}` |
| is_system | BOOLEAN | NOT NULL, DEFAULT true | True for built-in permissions (prevents deletion) |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | Creation timestamp |
| updated_at | TIMESTAMPTZ | DEFAULT NOW() | Last update (trigger-managed) |

**Indexes**: `idx_permissions_key` (UNIQUE on key), `idx_permissions_category` (for filtering)

**Seed data**: 58 existing permissions + 8 new = 66 total. All seeded with `is_system = true`.

### `principal_groups` — Named collections of users

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK, DEFAULT gen_random_uuid() | Primary key |
| name | VARCHAR(255) | UNIQUE, NOT NULL | Group name (e.g., "Researchers", "Security Admins") |
| description | TEXT | | Optional description |
| is_system | BOOLEAN | NOT NULL, DEFAULT false | True for pre-seeded groups |
| is_immutable | BOOLEAN | NOT NULL, DEFAULT false | True only for Owners and Security Admins |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | Creation timestamp |
| updated_at | TIMESTAMPTZ | DEFAULT NOW() | Last update (trigger-managed) |

**Indexes**: `idx_principal_groups_name` (UNIQUE on name)

**Seed data**: 7 groups total:
- Immutable: Owners (`is_immutable=true, is_system=true`), Security Admins (`is_immutable=true, is_system=true`)
- System: QA Specialists, Researchers, Supervisors, Moderators, Group Admins (all `is_system=true, is_immutable=false`)

### `principal_group_members` — Users in principal groups

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| principal_group_id | UUID | FK → principal_groups ON DELETE CASCADE, NOT NULL | Group reference |
| user_id | UUID | FK → users ON DELETE CASCADE, NOT NULL | User reference |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | When added |

**Primary key**: (principal_group_id, user_id)

**Indexes**: `idx_pgm_user` (on user_id for "which groups is this user in?" queries)

**Seed data**: All existing users with `role = 'owner'` added to Owners group. Users added to their corresponding system group based on `users.role` value.

### `permission_assignments` — The core ACL table

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK, DEFAULT gen_random_uuid() | Primary key |
| permission_id | UUID | FK → permissions ON DELETE CASCADE, NOT NULL | Which permission |
| principal_type | VARCHAR(20) | NOT NULL, CHECK IN ('user', 'group') | Target type |
| principal_id | UUID | NOT NULL | FK to users or principal_groups (app-validated) |
| securable_type | VARCHAR(20) | NOT NULL, CHECK IN ('platform', 'group') | Scope level |
| securable_id | UUID | NULLABLE | NULL for platform scope, group UUID for group scope |
| effect | VARCHAR(10) | NOT NULL, CHECK IN ('allow', 'deny') | Grant or block |
| created_by | UUID | FK → users ON DELETE SET NULL | Who created this assignment |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | When created |

**Unique constraint**: (permission_id, principal_type, principal_id, securable_type, securable_id)

**Indexes**:
- `idx_pa_principal` (principal_type, principal_id) — "what assignments does this principal have?"
- `idx_pa_permission` (permission_id) — "who has this permission?"
- `idx_pa_securable` (securable_type, securable_id) — "what assignments exist at this scope?"

**Seed data**: One `allow` assignment per permission per system principal group, replicating `ROLE_PERMISSIONS`. All at platform scope. Owners group gets `allow` for ALL 66 permissions. Security Admins group gets `allow` for `WORKBENCH_ACCESS`, `SECURITY_VIEW`, `SECURITY_MANAGE`, `SECURITY_FEATURE_FLAG` only.

## Modified Tables

### `settings` — Add feature flag column

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| dynamic_permissions_enabled | BOOLEAN | NOT NULL, DEFAULT false | Feature flag for dynamic permission engine |

Added via `ALTER TABLE settings ADD COLUMN IF NOT EXISTS dynamic_permissions_enabled BOOLEAN NOT NULL DEFAULT false`.

## Unchanged Tables

- **`users`** — `role` column remains; used as fallback when flag is OFF and for initial seed group membership mapping
- **`group_memberships`** — continues to govern data scoping (which sessions you see), not permissions
- **`groups`** — referenced by `permission_assignments.securable_id` when `securable_type = 'group'`
- **`audit_log`** — receives new action types but schema is unchanged

## Resolution Algorithm (Query Pattern)

```sql
-- Step 1: Get all principal group IDs for the user
WITH user_groups AS (
  SELECT principal_group_id AS id FROM principal_group_members WHERE user_id = $1
),
-- Step 2: Get all assignments for this user (direct + via groups)
all_assignments AS (
  SELECT pa.permission_id, p.key AS permission_key,
         pa.securable_type, pa.securable_id, pa.effect
  FROM permission_assignments pa
  JOIN permissions p ON pa.permission_id = p.id
  WHERE (pa.principal_type = 'user' AND pa.principal_id = $1)
     OR (pa.principal_type = 'group' AND pa.principal_id IN (SELECT id FROM user_groups))
)
-- Step 3: For each (permission, scope), check for deny
SELECT permission_key, securable_type, securable_id,
  CASE WHEN bool_or(effect = 'deny') THEN 'deny' ELSE 'allow' END AS resolved_effect
FROM all_assignments
GROUP BY permission_key, securable_type, securable_id;
```

The application layer then builds the `ResolvedPermissions` object from these rows.

## Audit Event Types

| Action | Target Type | Description |
|--------|------------|-------------|
| `security.group_create` | principal_group | New principal group created |
| `security.group_update` | principal_group | Group name/description changed |
| `security.group_delete` | principal_group | Group deleted |
| `security.group_member_add` | principal_group | User added to group |
| `security.group_member_remove` | principal_group | User removed from group |
| `security.assignment_create` | permission_assignment | Permission assigned (allow/deny) |
| `security.assignment_delete` | permission_assignment | Permission assignment removed |
| `security.flag_toggle` | settings | Feature flag toggled |
| `security.cache_invalidate` | system | Manual cache invalidation triggered |

## Relationships

```
User (1) ──── principal_group_members (N) ──── Principal Group (1)
                                                      │
                                                      ├── permission_assignments (N) ──── Permission (1)
                                                      │   (principal_type = 'group')
                                                      │
User (1) ──── permission_assignments (N) ──── Permission (1)
              (principal_type = 'user')

Permission Assignment ──── scope ──── Platform (singleton) OR Group (from groups table)
```

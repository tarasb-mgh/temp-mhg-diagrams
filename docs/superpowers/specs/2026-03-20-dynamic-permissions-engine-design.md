# Dynamic Permissions Engine — Design Spec

**Date:** 2026-03-20
**Status:** Draft
**Feature:** Replace hardcoded RBAC with database-driven hierarchical permission model (core engine + migration layer + Security Configuration UI)

---

## Problem Statement

The MHG platform uses a hardcoded RBAC system defined in `chat-types/src/rbac.ts`: 7 static roles mapped to 58 permissions via a TypeScript constant. Changing who can do what requires a code change, a package publish, and a deployment across all consuming repos. There is no way to grant permissions per-group, no way to create custom roles, and no way for administrators to adjust access without developer intervention.

## Goal

Replace the static `ROLE_PERMISSIONS` mapping with a database-driven, hierarchical permission system that supports:
- Allow/Deny/Inherit permission assignments
- Principal groups (custom roles) and individual principal assignments
- Platform-level and group-level permission scoping
- Full backward compatibility via feature flag and system principal groups that replicate existing role behavior
- A Security Configuration UI for Owners and Security Admins to manage the permission system

## Core Concepts

### Securables

Resources that can have permissions attached. Two levels in a fixed hierarchy:

```
Platform (singleton)
  └── Group (1..N spaces)
```

Permissions set at Platform inherit down to all Groups unless overridden. Sessions inherit their group's permissions — they are not independently securable.

### Principals

Entities that can receive permissions:
- **Individual principals** — a single user
- **Principal groups** — a named collection of users

### Immutable Principal Groups (cannot be deleted or renamed)
- **Owners** — full system access, replicates current OWNER role behavior
- **Security Admins** — can manage the permission system only

### System Principal Groups (pre-seeded, deletable)
- QA Specialists, Researchers, Supervisors, Moderators, Group Admins — each pre-configured with permission assignments that exactly replicate current `ROLE_PERMISSIONS` mappings

### Permission Assignments

Attach a permission to a principal at a securable scope:
- **Allow** — explicitly grants the permission
- **Deny** — explicitly blocks the permission (wins over Allow at same scope)
- **Inherit** (default) — no explicit assignment; resolved from parent scope

### Resolution Rules

**Deny wins.** If any assignment (from any group the user belongs to, or direct user assignment) says Deny for a permission, the permission is denied. Otherwise, if any assignment says Allow, it's granted. No explicit assignment = no access (closed by default).

## Permission Registry

The current 58 permissions become database records. Each permission has:
- **Key** — string identifier (e.g., `review:submit`)
- **Display name** — human-readable label
- **Category** — grouping: Chat, Workbench, Review, Tag, Survey, Data, Security
- **Applicable scope types** — which scopes the permission can be assigned at

### Scope Applicability

**Platform-only** (global capabilities, no group context):
- `WORKBENCH_ACCESS`, `DATA_EXPORT`, `DATA_DELETE`, `SECURITY_VIEW`, `SECURITY_MANAGE`, `SECURITY_FEATURE_FLAG`

**Platform + Group** (can be granted globally or per-group):
- All Review permissions, all Tag permissions, Survey management, User management, Workbench research/moderation/privacy

**Group-only** (only meaningful within a specific group):
- `GROUP_ADMIT_USERS` — approve/reject membership requests, manage invite codes
- `GROUP_VIEW_SURVEYS` — view survey instances and responses for this group
- `GROUP_VIEW_CHATS` — view chat sessions within this group
- `GROUP_VIEW_MEMBERS` — view participant list for this group
- `GROUP_MANAGE_CONFIG` — edit group settings (supervision policy, reviewer count, survey ordering)

### New Security Permissions
- `SECURITY_VIEW` — view security configuration (read-only)
- `SECURITY_MANAGE` — create/edit/delete principal groups, permission assignments
- `SECURITY_FEATURE_FLAG` — toggle the dynamic permissions feature flag

The `Permission` enum in `chat-types` remains for compile-time safety. The database registry must match it (validated on startup).

## Data Model

### `permissions` — Registry of all known permissions
- `id` UUID PK
- `key` VARCHAR UNIQUE — e.g., `review:submit`
- `display_name` VARCHAR
- `category` VARCHAR — e.g., "review", "security", "group"
- `scope_types` VARCHAR[] — e.g., `['platform']`, `['platform','group']`, `['group']`
- `is_system` BOOLEAN — true for built-in permissions, prevents deletion
- `created_at`, `updated_at`

### `principal_groups` — Named collections of users
- `id` UUID PK
- `name` VARCHAR UNIQUE
- `description` TEXT
- `is_system` BOOLEAN — true for pre-seeded groups
- `is_immutable` BOOLEAN — true only for Owners and Security Admins
- `created_at`, `updated_at`

### `principal_group_members` — Users in principal groups
- `principal_group_id` UUID FK → principal_groups
- `user_id` UUID FK → users
- `created_at`
- PK: (principal_group_id, user_id)

### `permission_assignments` — The core ACL table
- `id` UUID PK
- `permission_id` UUID FK → permissions
- `principal_type` VARCHAR — `'user'` or `'group'`
- `principal_id` UUID — references users or principal_groups
- `securable_type` VARCHAR — `'platform'` or `'group'`
- `securable_id` UUID NULLABLE — NULL for platform scope, group UUID for group scope
- `effect` VARCHAR — `'allow'` or `'deny'`
- `created_by` UUID FK → users
- `created_at`
- UNIQUE: (permission_id, principal_type, principal_id, securable_type, securable_id)

### No changes to existing tables
- `users.role` remains for backward compatibility
- `group_memberships` remains unchanged — governs data scoping, not permissions

## Feature Flag & Backward Compatibility

**Feature flag**: `DYNAMIC_PERMISSIONS_ENABLED` in settings. Default: `false`.

### When flag is OFF (default)
- Auth middleware resolves permissions from the static `ROLE_PERMISSIONS` constant, exactly as today
- Permission tables exist and can be configured through Security Configuration UI
- No runtime authorization impact

### When flag is ON
- Auth middleware resolves permissions from the database using the resolution service
- `users.role` is still read but only used to determine immutable group membership
- `ROLE_PERMISSIONS` constant ignored for authorization

### Rollback
Flipping flag to `false` instantly reverts to static permissions. No data loss.

### Seed Migration
On first deployment:
1. Create permission tables
2. Seed `permissions` registry with all 58 existing + 3 new security + 5 new group-only permissions
3. Create immutable principal groups (Owners, Security Admins)
4. Create system principal groups (QA Specialists, Researchers, Supervisors, Moderators, Group Admins)
5. Create `permission_assignments` replicating current `ROLE_PERMISSIONS` mappings
6. Add existing Owner-role users to the Owners principal group

### Startup Validation
Backend compares `Permission` enum against `permissions` table. Mismatches logged as warnings.

## Permission Resolution Service

### Caching
- **Cache key**: `userId`
- **Cache value**: resolved platform + group permissions
- **TTL**: 60 seconds
- **Invalidation**: on any assignment or group membership change for the user or their groups

### Resolution Function
```
resolvePermissions(userId): Promise<ResolvedPermissions>

ResolvedPermissions {
  platform: Map<permissionKey, 'allow' | 'deny'>
  groups: Map<groupId, Map<permissionKey, 'allow' | 'deny'>>
}
```

### Auth Middleware Integration
With flag on, the middleware populates `req.user.permissions` by flattening resolved permissions into a `Permission[]` for the active group context. All 195 existing call sites work unchanged — they still check `permissions.includes(Permission.X)`.

For group-scoped checks beyond the active group:
```
hasPermissionInGroup(resolvedPermissions, permissionKey, groupId): boolean
```

## Security Configuration UI

New top-level workbench section, visible only to Owners and Security Admins regardless of feature flag state.

### Security Dashboard
- Feature flag toggle with confirmation dialog
- Summary cards: total principal groups, total assignments, total permissions
- Preview mode banner when flag is off

### Principal Groups
- List view with member count, system/immutable badges
- CRUD: create, rename, delete (respecting immutability constraints)
- Member management: add/remove users with search-by-email

### Permissions Browser
- Read-only registry grouped by category
- Click-through to see all assignments for a permission

### Permission Assignments
- Scoped view: select Platform or a specific Group to see assignments
- Add/remove assignments: permission + principal + effect + scope
- Effective permissions viewer: select a user to see resolved permissions with source attribution
- Preview mode: shows what WOULD apply if flag were on

### UI Constraints
- Works regardless of feature flag state
- English-only (internal tooling, per constitution Principle VI delivery workbench precedent)
- Desktop-only (workbench is not responsive)

## Edge Cases

### User in zero principal groups with no direct assignments
Access is denied for all permissions. This is correct behavior — the system is closed by default. The user can authenticate but cannot perform any permissioned action until assigned to a principal group or given a direct assignment.

### Conflicting Allow (group) + Deny (direct user assignment)
Deny wins regardless of source. If a user has a direct Allow for `REVIEW_SUBMIT` but their group "Restricted" has a Deny for `REVIEW_SUBMIT` at the same scope — the permission is denied. Conversely, if a group grants Allow but the user has a direct Deny — also denied. Deny from ANY source at ANY level wins unconditionally.

### Group-scoped assignment for a platform-only permission
The API must reject this with a 400 error. The `permission_assignments` write path validates that the `securable_type` matches the permission's `scope_types`. A `DATA_EXPORT` assignment with `securable_type = 'group'` is invalid and never persisted. The DB does not enforce this constraint (it's application-level validation) to keep the schema simple.

### Last Owner removed from Owners group
The system enforces a minimum of 1 member in the Owners principal group. The API rejects removal of the last Owner with a 400 error: "Cannot remove the last member of the Owners group." Same constraint applies to Security Admins group.

### User in multiple groups with conflicting assignments
If a user belongs to groups A, B, and C, and group A has Allow for `REVIEW_SUBMIT` at Platform, group B has Deny for `REVIEW_SUBMIT` at Platform, and group C has Allow for `REVIEW_SUBMIT` in Group X — the Platform-level permission is denied (Deny from B wins). The Group X-level permission is allowed (Allow from C, no Deny at that scope). Each scope level is resolved independently.

### Cache staleness window
When a Deny assignment is created, there is a maximum 60-second window where affected users may still have a stale Allow cached. This is an accepted trade-off for performance. For immediate effect, the admin can use the "Force cache invalidation" action in the Security Dashboard, which clears all permission caches synchronously. Critical security changes (e.g., revoking access for a compromised account) should use this action.

### Seed migration idempotency
The seed migration is idempotent. It uses INSERT ... ON CONFLICT DO NOTHING for all seed records. Running the migration twice produces no duplicates and no errors. This supports rollback-and-reapply scenarios.

### Audit logging interim measure
While full audit logging is out of scope, all permission assignment CRUD operations are logged via the existing `logAuditEvent()` function with action types `security.assignment_create`, `security.assignment_delete`, `security.group_create`, `security.group_delete`, `security.group_member_add`, `security.group_member_remove`, `security.flag_toggle`. This provides basic traceability using existing infrastructure until a dedicated audit feature is built.

## Scope Boundaries

### In Scope
- Database tables, seed migration, startup validation
- Permission resolution service with caching
- Dual-mode auth middleware with feature flag
- `chat-types` updates: new permissions, resolution types
- Backend CRUD API for principal groups, members, assignments
- Security Configuration UI (dashboard, groups, browser, assignments, effective viewer)

### Out of Scope
- Migrating 195 call sites to use `ResolvedPermissions` directly (flattening shim handles it)
- Removing `users.role` column or `ROLE_PERMISSIONS` constant (cleanup after flag permanent)
- Audit logging for permission changes (separate feature)

## Success Criteria

1. Feature flag OFF: zero behavioral change across all existing functionality
2. Feature flag ON: for every user in the system at migration time, and for any new user subsequently assigned to a system principal group, the resolved `Permission[]` from the database matches the `ROLE_PERMISSIONS[role]` array exactly (validated by an automated comparison test covering all 7 system roles)
3. Seed migration produces identical effective permissions for every existing role (verified by a test that resolves permissions for a synthetic user in each system principal group and asserts array equality with `ROLE_PERMISSIONS`)
4. Flag rollback to OFF restores static behavior instantly with no data loss
5. Permission resolution adds less than 50ms p95 latency on warm cache under 100 concurrent users, with up to 5 principal group memberships and 200 assignments per user. Cold cache (first request after TTL expiry) must resolve in under 200ms.
6. Security Configuration UI: functional CRUD on principal groups, members, assignments, effective permissions viewer
7. Security Configuration section visible only to Owners/Security Admins regardless of flag state

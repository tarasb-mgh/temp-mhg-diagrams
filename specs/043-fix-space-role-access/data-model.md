# Data Model: Fix Workbench Space Selector Role-Based Access

**Feature**: 043-fix-space-role-access
**Date**: 2026-04-02

## Schema Changes

**None required.** This feature is a bugfix to application-level logic. All database tables and columns referenced below already exist.

## Existing Entities (Reference)

### users

| Field | Type | Notes |
|-------|------|-------|
| id | UUID | Primary key |
| role | ENUM (UserRole) | Global role: USER, QA_SPECIALIST, RESEARCHER, SUPERVISOR, GROUP_ADMIN, MODERATOR, OWNER |
| active_group_id | UUID (nullable) | FK → groups.id. The currently selected Space for workbench context. This is the field written by `setActiveGroup()`. |

**Relevant behavior**: When `active_group_id` references a group the user cannot access (e.g., after role downgrade), the system must clear it to NULL and present the empty state.

### groups

| Field | Type | Notes |
|-------|------|-------|
| id | UUID | Primary key |
| name | VARCHAR | Display name shown in Space selector |
| archived_at | TIMESTAMP (nullable) | Non-null = archived. Archived groups must not appear in Space selector and must not be settable as active group. |

### group_memberships

| Field | Type | Notes |
|-------|------|-------|
| user_id | UUID | FK → users.id |
| group_id | UUID | FK → groups.id |
| status | ENUM | active, pending, rejected, removed |

**Relevant behavior**: Only `status = 'active'` records grant membership-path access. Global role holders bypass this table for Space selection purposes.

## Access Resolution Logic (No Change)

The `canAccessGroup(userId, groupId, userRole)` function interface and behavior remain unchanged:

1. If group `archived_at IS NOT NULL` → DENY
2. If `userRole` in `GLOBAL_GROUP_ACCESS_ROLES` → GRANT (accessType: 'global_role')
3. If active membership exists in `group_memberships` → GRANT (accessType: 'membership')
4. Otherwise → DENY

## State Transitions

### active_group_id Lifecycle

```
NULL (no active group)
  → setActiveGroup(groupId) succeeds → groupId
  → setActiveGroup(groupId) fails → stays NULL

groupId (active group set)
  → setActiveGroup(newGroupId) succeeds → newGroupId
  → setActiveGroup(newGroupId) fails → stays groupId (FR-012)
  → role downgrade + group no longer accessible → NULL (FR-013)
  → group archived → NULL (edge case: archived space)
```

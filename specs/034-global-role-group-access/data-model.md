# Data Model: Global Role Group Access

**Feature Branch**: `034-global-role-group-access`
**Date**: 2026-03-19

## Overview

This feature introduces no new database tables or columns. The access resolution is a runtime logic change that leverages existing schema. The only data-level change is adding an `access_type` key to the JSONB `details` column in existing `audit_log` entries.

## Existing Entities (Unchanged)

### groups
| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key |
| name | VARCHAR | Group display name |
| archived_at | TIMESTAMP | Soft-delete marker |
| archived_by | UUID | Who archived it |
| created_at | TIMESTAMP | Creation timestamp |
| updated_at | TIMESTAMP | Last update |

### group_memberships
| Column | Type | Description |
|--------|------|-------------|
| user_id | UUID | FK to users |
| group_id | UUID | FK to groups |
| role | VARCHAR | 'member' or 'admin' |
| status | VARCHAR | 'active', 'pending', 'rejected', 'removed' |

**Note**: Global role holders who access groups via their role do NOT create records in this table. This table remains the sole source of truth for group member lists.

### users
| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key |
| role | VARCHAR | Global role (user, qa_specialist, researcher, supervisor, moderator, group_admin, owner) |
| active_group_id | UUID | FK to groups — currently set group context |

**Change**: `active_group_id` may now reference a group where the user has no `group_memberships` record, provided the user holds a global role >= Researcher.

### audit_log
| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key |
| actor_id | UUID | FK to users |
| action | VARCHAR | Event type (e.g., 'group.active_set') |
| target_type | VARCHAR | Entity type (e.g., 'group') |
| target_id | UUID | Entity ID |
| details | JSONB | Event metadata |
| ip_address | VARCHAR | Request IP |
| created_at | TIMESTAMP | Event timestamp |

**Change**: The `details` JSONB object gains a new key `access_type` with values `"membership"` or `"global_role"` for group-scoped actions performed by workbench users.

## New Logical Entity: Access Resolution

This is not a database entity — it is a runtime function.

### canAccessGroup(userId, groupId, userRole)

**Inputs**:
| Parameter | Type | Source |
|-----------|------|--------|
| userId | UUID | From authenticated request |
| groupId | UUID | From request header/query/param |
| userRole | UserRole | From authenticated request |

**Output**:
| Field | Type | Description |
|-------|------|-------------|
| granted | boolean | Whether access is allowed |
| accessType | 'membership' \| 'global_role' | How access was resolved |

**Resolution Logic**:
1. Query `groups` for `groupId` — if `archived_at IS NOT NULL`, return `{ granted: false }` (archived groups are inaccessible to everyone)
2. If `userRole` is in `GLOBAL_GROUP_ACCESS_ROLES` → return `{ granted: true, accessType: 'global_role' }`
3. Query `group_memberships` for `(userId, groupId, status='active')` → if found, return `{ granted: true, accessType: 'membership' }`
4. Return `{ granted: false, accessType: null }`

## New Constant: GLOBAL_GROUP_ACCESS_ROLES

**Location**: `chat-types/src/rbac.ts`

```
GLOBAL_GROUP_ACCESS_ROLES = [UserRole.RESEARCHER, UserRole.SUPERVISOR, UserRole.MODERATOR, UserRole.OWNER]
```

Defines which roles receive implicit group access. QA_SPECIALIST, GROUP_ADMIN, and USER are excluded.

## Relationships

```
User (1) ──── (role) ──→ Global Role
  │                           │
  │                           ├── If >= RESEARCHER: implicit access to ALL groups
  │                           └── If < RESEARCHER: no implicit access
  │
  └──── (group_memberships) ──→ Group (0..N)
                                    │
                                    └── Explicit membership: access to THIS group only

Access Resolution = (Global Role path) OR (Membership path)
```

## Migration Requirements

**None.** No schema changes are required. All changes are application-level logic.

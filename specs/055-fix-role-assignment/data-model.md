# Data Model: 055-fix-role-assignment

**Date**: 2026-04-16

## Affected Entity: users

### Column: role

| Property | Current | After Fix |
|----------|---------|-----------|
| Type | VARCHAR | VARCHAR (unchanged) |
| Constraint Name | `users_role_check` | `users_role_check` (replaced) |
| Allowed Values | `user`, `qa_specialist`, `researcher`, `supervisor`, `moderator`, `group_admin`, `owner` | `user`, `qa_specialist`, `researcher`, `supervisor`, `moderator`, `group_admin`, `owner`, **`expert`**, **`admin`**, **`master`** |
| Default | None | None (unchanged) |
| Nullable | No | No (unchanged) |

### Canonical Role Enum (chat-types)

Source: `chat-types/src/rbac.ts` — `UserRole` enum

| Enum Key | DB Value | Status |
|----------|----------|--------|
| USER | `user` | Existing |
| QA_SPECIALIST | `qa_specialist` | Existing |
| RESEARCHER | `researcher` | Existing |
| SUPERVISOR | `supervisor` | Existing |
| MODERATOR | `moderator` | Existing |
| GROUP_ADMIN | `group_admin` | Existing |
| OWNER | `owner` | Existing |
| EXPERT | `expert` | **New (MVP 048)** |
| ADMIN | `admin` | **New (MVP 048)** |
| MASTER | `master` | **New (MVP 048)** |

### Relationships

No new relationships introduced. The `users.role` column is referenced by:
- Application-layer permission resolution (`ROLE_PERMISSIONS` map in `chat-types`)
- Route guards checking `req.user.role` (e.g., Owner-only checks)
- `expert_tag_assignments.user_id` FK (references `users.id`, not `users.role`)

### Migration Details

| Property | Value |
|----------|-------|
| Migration File | `063_055-extend-user-role-constraint.sql` |
| Operation | DROP existing constraint, ADD new constraint |
| Idempotent | Yes (uses `pg_constraint` introspection) |
| Backward Compatible | Yes (only expands allowed values) |
| Data Migration | None required |

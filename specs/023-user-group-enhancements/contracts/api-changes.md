# API Contract Changes: 023-user-group-enhancements

**Date**: 2026-03-10

These are the two backend API changes required by this feature. All other user story work is purely frontend.

---

## US1 — POST /api/admin/groups/:groupId/members

**File**: `chat-backend/src/services/group.service.ts`

### Before

```typescript
// Blocks owner, moderator, researcher, supervisor, group_admin
if (['owner', 'moderator', 'researcher', 'supervisor', 'group_admin'].includes(String(role))) {
  throw new Error('FORBIDDEN_TARGET_ROLE');
}
```

### After

```typescript
// Only block researcher and group_admin — privileged accounts (owner, moderator, supervisor)
// are permitted to participate in groups as members per FR-001
if (['researcher', 'group_admin'].includes(String(role))) {
  throw new Error('FORBIDDEN_TARGET_ROLE');
}
```

### Response contract (unchanged)

| Condition | HTTP Status | Body |
|-----------|-------------|------|
| Success | 201 | `{ success: true, data: User }` |
| User not found | 404 | `{ success: false, error: { code: 'USER_NOT_FOUND' } }` |
| Target is researcher/group_admin | 403 | `{ success: false, error: { code: 'FORBIDDEN', message: 'Cannot change group membership for privileged roles' } }` |
| Caller lacks WORKBENCH_USER_MANAGEMENT | 403 | existing auth middleware |

---

## US7 — GET /api/admin/users

**File**: `chat-backend/src/routes/users.ts`

### New query parameter

| Param | Type | Description |
|-------|------|-------------|
| `privileged` | `'true'` (optional) | When present and `'true'`, filters to users with role in `['owner', 'moderator', 'supervisor']` |

### Service layer change

In `user.service.ts` (or inline in `users.ts`), add a WHERE clause fragment:

```sql
-- When privileged=true
AND role = ANY(ARRAY['owner', 'moderator', 'supervisor'])
```

Combined with existing `role` filter param: if both `role` and `privileged=true` are supplied, `privileged` takes precedence (returns only privileged roles matching the role param, or all privileged roles if no role param).

### Response contract (unchanged shape)

```json
{
  "success": true,
  "data": [ /* User[] */ ],
  "meta": { "page": 1, "limit": 10, "total": 3, "hasMore": false }
}
```

---

## No Other Backend Changes

| User Story | Backend Change |
|------------|---------------|
| US2 — Spaces refresh | None — frontend polls and re-fetches `GET /api/admin/groups` |
| US3 — Dropdown hide | None — frontend evaluates `user.role` from auth store |
| US4 — Group Surveys | None — endpoint already exists |
| US5 — Deduplication | None — already implemented at DB/service layer |
| US6 — Invalidation menu | None — same backend endpoints, better frontend UX |
| US8 — User list UX | None — clipboard API, URL params, row-click removal |

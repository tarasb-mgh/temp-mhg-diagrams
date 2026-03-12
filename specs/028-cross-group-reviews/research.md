# Research: Cross-Group Review Access and Group Filter Scoping

**Feature**: 028-cross-group-reviews
**Date**: 2026-03-12
**Branch**: `028-cross-group-reviews`

## Decisions

### Decision 1 — No new permission type needed

**Decision**: Use the existing `REVIEW_CROSS_GROUP` permission from `chat-types`.

**Rationale**: `chat-types/src/rbac.ts` already defines `Permission.REVIEW_CROSS_GROUP` (line 52) and already grants it to both `UserRole.RESEARCHER` (line 110) and `UserRole.SUPERVISOR` (line 128). The permission model is complete — the bug is purely in the route-level access guard that does not check for this permission.

**Alternatives considered**:
- Adding a new permission (rejected — redundant; the correct permission exists and is correctly assigned)
- Role-level checks in the guard (rejected — permission-based checks are more flexible and already wired up)

---

### Decision 2 — Fix is in route guards, not service layer

**Decision**: Modify the group access guard in `chat-backend/src/routes/review.queue.ts` (line 38) and `chat-backend/src/routes/review.sessions.ts` (line 73) to bypass the membership check when the requesting user holds `Permission.REVIEW_CROSS_GROUP`.

**Current guard logic** (both files, same pattern):
```typescript
if (groupId && req.user?.role !== UserRole.OWNER) {
  const hasAccess = await canAccessGroupScopedQueue(req.user!.id, groupId);
  if (!hasAccess) { return res.status(403).json({...}); }
}
```

**Bug**: When a RESEARCHER or SUPERVISOR specifies a `groupId` query param that they are not a member of, `canAccessGroupScopedQueue()` returns false and the route 403s. Only OWNER bypasses this check.

**Fix**: Extend the bypass condition to also skip the membership check for users with `REVIEW_CROSS_GROUP`:
```typescript
const hasCrossGroupPermission = req.user?.permissions?.includes(Permission.REVIEW_CROSS_GROUP);
if (groupId && req.user?.role !== UserRole.OWNER && !hasCrossGroupPermission) {
  const hasAccess = await canAccessGroupScopedQueue(req.user!.id, groupId);
  if (!hasAccess) { return res.status(403).json({...}); }
}
```

**Rationale**: The service layer (`reviewQueue.service.ts`) already handles the `groupId` filter correctly — it applies the filter as a WHERE clause when provided and returns all records when absent. No service-layer change is needed.

**Alternatives considered**:
- Moving the check into `canAccessGroupScopedQueue()` itself — rejected because the function is a membership check; augmenting it with permission logic mixes two concerns.
- Adding the bypass at a higher-level middleware — rejected; the existing workbench guard already confirms WORKBENCH_ACCESS; the group access check is route-specific.

---

### Decision 3 — No database schema changes

**Decision**: No migrations, no new tables, no new columns.

**Rationale**: Sessions already have `group_id`. Access control is entirely permission-based. The fix is pure application logic in route guards.

---

### Decision 4 — Frontend group filter source must be verified

**Decision**: Verify whether the workbench group filter dropdown fetches all groups (admin-level) or only the current user's group memberships. If it returns only the user's own groups, RESEARCHER/SUPERVISOR users with no or limited memberships will see an incomplete or empty filter — blocking the US2 filter workflow.

**Finding**: `ReviewQueueView.tsx` passes `groupId` (UUID) to the store correctly, and `reviewStore.ts` passes it to the API correctly. The dropdown's data source (which API call populates the list of groups to choose from) must be inspected.

**Expected outcomes**:
- If the groups API (`/api/admin/groups` or `/api/group`) already returns all groups for workbench users — no frontend change needed beyond the backend fix.
- If the groups API returns only user-membership groups — the frontend needs to call an all-groups endpoint for users with `REVIEW_CROSS_GROUP`, or the backend needs a separate "available filter groups" endpoint.

**Alternatives considered**:
- Always showing all groups in the filter for all roles — rejected; Reviewer role should only see their own group per FR-003.
- Client-side permission check to switch data sources — acceptable if the groups endpoint is readily available.

---

### Decision 5 — chat-backend is the sole repo with required code changes; workbench-frontend pending verification

**Decision**: Primary implementation is in `chat-backend` only (route guard fixes in two files). `workbench-frontend` requires investigation of the group list data source before determining if any change is needed.

**Rationale**: The backend access control fix unblocks both US1 (cross-group visibility) and the backend portion of US2 (filter scoping). The frontend filter already passes the correct `groupId` parameter. The only open question is whether the filter's group list is correctly populated for privileged users with broad cross-group access.

**Repositories affected**:
- `chat-backend` — required (route guard fix)
- `workbench-frontend` — conditional (group list source fix if needed)
- `chat-types` — none (REVIEW_CROSS_GROUP already exists)
- All others — none

---

## Supporting Findings

### Permission model (chat-types/src/rbac.ts)
- `Permission.REVIEW_CROSS_GROUP` — line 52
- `UserRole.RESEARCHER` gets `REVIEW_CROSS_GROUP` — line 110
- `UserRole.SUPERVISOR` gets `REVIEW_CROSS_GROUP` — line 128
- `UserRole.REVIEWER` does NOT get `REVIEW_CROSS_GROUP` — baseline reviewer sees only their group (correct per FR-003)

### Backend route files
- `chat-backend/src/routes/review.queue.ts:38–49` — group guard; bypasses only for OWNER
- `chat-backend/src/routes/review.sessions.ts:73–81` — group guard; bypasses only for OWNER
- `chat-backend/src/services/reviewQueue.service.ts` — `listQueueSessions()` correctly applies `groupId` as filter when provided, returns all when absent; no changes needed

### Frontend store and view
- `workbench-frontend/src/stores/reviewStore.ts` — `queueScopeGroupId` state; `fetchQueue` and `selectSession` both pass `groupId` to API correctly
- `workbench-frontend/src/features/workbench/review/ReviewQueueView.tsx` — group filter dropdown; source of the groups list needs verification

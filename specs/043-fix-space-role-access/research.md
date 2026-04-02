# Research: Fix Workbench Space Selector Role-Based Access

**Feature**: 043-fix-space-role-access
**Date**: 2026-04-02

## Research Questions

### RQ-1: Where does `setActiveGroup()` validate membership?

**Decision**: The `setActiveGroup()` function in `groupMembership.service.ts` is the primary backend entry point when a user switches Space. Spec 034 task T012 claims this was updated to skip membership validation when `hasGlobalGroupAccess(userRole)` returns true. The observed behavior (fallback to membership-based Space) indicates the bypass is either incomplete, conditional on a code path not triggered by the selector, or overridden by a subsequent check.

**Rationale**: The function is the single point where `active_group_id` is written to the `users` table. If membership validation fails here, the backend returns an error, and the frontend falls back.

**Action**: Read `setActiveGroup()` implementation; verify the `hasGlobalGroupAccess()` check exists and is reached on the code path triggered by the Space selector dropdown.

**Alternatives considered**:
- The bug could be purely frontend (backend returns 200 but frontend ignores it) — less likely since the behavior is consistent across page refresh
- The bug could be in a middleware layer — checked: Express middleware does not intercept group-switch requests

### RQ-2: Does `GET /api/admin/groups` return all groups for global role holders?

**Decision**: The `GET /api/admin/groups` endpoint in `admin.groups.ts` is the data source for the Space selector dropdown. Spec 034 task T013 claims this was widened to allow Researcher+ roles. If the endpoint still filters by membership, the dropdown will only show member groups.

**Rationale**: Even if `setActiveGroup()` is correctly bypassing membership checks, the user can't switch to a group that doesn't appear in their dropdown.

**Action**: Read `admin.groups.ts` route handler; verify the permission gate allows Researcher+ roles and that the query returns all non-archived groups (not filtered by membership).

**Alternatives considered**:
- The frontend might call a different endpoint for group list — possible but unlikely since spec 034 T027 references `adminGroupsApi.list()`

### RQ-3: Does the frontend `GroupScopeSelector.tsx` apply client-side fallback?

**Decision**: The `GroupScopeSelector.tsx` component likely contains logic that validates the active group against the user's membership list and falls back to the first matching group if the active group is not in the membership list.

**Rationale**: The consistent behavior (always falls back to first membership-based Space) suggests a deterministic client-side check, not a backend error. The frontend may be running a validation pass after receiving the group list and active group state.

**Action**: Read `GroupScopeSelector.tsx`; identify any post-mount or post-fetch logic that compares `activeGroup` against a membership-filtered list and triggers a `setActiveGroup()` call if mismatch detected.

**Alternatives considered**:
- Zustand store initialization might set active group from cached membership list — possible secondary cause
- React effect dependencies might trigger re-render that resets state — check useEffect dependencies

### RQ-4: What HTTP status does the backend return when membership validation fails in `setActiveGroup()`?

**Decision**: If the backend returns 403 (Forbidden) when a global role holder tries to set a non-member group as active, the frontend would reasonably interpret this as "access denied" and fall back to a safe default.

**Rationale**: The HTTP status code determines the frontend error handling path. A 403 triggers fallback logic; a 200 should be accepted.

**Action**: Identify the error response shape from `setActiveGroup()` route handler. Verify whether the frontend has distinct handling for 403 vs 500 on group switch.

**Alternatives considered**: N/A — this is diagnostic.

### RQ-5: Is chat-types update needed?

**Decision**: No. The `GLOBAL_GROUP_ACCESS_ROLES` constant and `hasGlobalGroupAccess()` helper were added in spec 034 (T004) and are already published. No changes to `chat-types` are required.

**Rationale**: The constants are correct. The bug is in how they are (or aren't) used in the space-switching code path.

**Alternatives considered**: Checked if a new permission constant might be needed — not necessary since `hasGlobalGroupAccess()` already encapsulates the role check.

## Technical Decisions Summary

| Decision | Choice | Confidence |
|----------|--------|-----------|
| Primary fix location (backend) | `setActiveGroup()` in `groupMembership.service.ts` | High |
| Secondary fix location (backend) | `GET /api/admin/groups` in `admin.groups.ts` | Medium |
| Frontend fix location | `GroupScopeSelector.tsx` fallback logic | High |
| Schema changes needed | None | High |
| chat-types changes needed | None | High |
| Error handling on failed switch | Stay on current Space + error notification | Confirmed (clarification) |
| Role downgrade behavior | Clear active group + empty state | Confirmed (clarification) |

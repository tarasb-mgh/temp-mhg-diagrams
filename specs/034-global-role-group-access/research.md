# Research: Global Role Group Access

**Feature Branch**: `034-global-role-group-access`
**Date**: 2026-03-19

## Decision 1: Access Resolution Function Location

**Decision**: Create a shared `canAccessGroup(userId, groupId, userRole)` function in `chat-backend/src/services/groupAccess.service.ts`, replacing the review-queue-specific `canAccessGroupScopedQueue()` in `reviewQueue.service.ts`.

**Rationale**: The existing `canAccessGroupScopedQueue()` at `reviewQueue.service.ts:96-109` already queries `group_memberships` for a single membership check. The new function generalizes this with a role-tier check. Placing it in a dedicated service file makes the access resolution a first-class concept rather than buried in review-queue logic.

**Alternatives considered**:
- Inline the check in middleware: rejected because multiple routes need it with different error handling
- Add to existing `group.service.ts`: rejected because access resolution is orthogonal to group CRUD
- Add to `auth.service.ts`: rejected because it's already large and this is a distinct concern

## Decision 2: Role Threshold Constant

**Decision**: Define a `GLOBAL_GROUP_ACCESS_ROLES` constant in `chat-types/src/rbac.ts` listing `[RESEARCHER, SUPERVISOR, MODERATOR, OWNER]`. The access resolution checks `userRole in GLOBAL_GROUP_ACCESS_ROLES`.

**Rationale**: This aligns with the existing `REVIEW_CROSS_GROUP` permission boundary. Using a named constant rather than a hardcoded role comparison makes the threshold explicit and easy to audit. If a new role is added between QA_SPECIALIST and RESEARCHER in the future, the constant only needs one update.

**Alternatives considered**:
- Check `role >= RESEARCHER` numerically: rejected because roles are string enums, not numeric — would require a role-level mapping that doesn't exist
- Reuse `REVIEW_CROSS_GROUP` permission check: rejected because the feature grants access to ALL group-scoped features, not just reviews — conflating the two would make the permission name misleading

## Decision 3: Group Selector Data Source

**Decision**: The workbench `GroupScopeSelector` calls `adminGroupsApi.list()` for users with global roles >= Researcher, and falls back to membership-based group list for QA Specialists.

**Rationale**: `adminGroupsApi.list()` at `admin.groups.ts:44-59` already returns all groups and is gated by `WORKBENCH_USER_MANAGEMENT` or `SURVEY_INSTANCE_MANAGE/VIEW`. Researchers already have `WORKBENCH_GROUP_DASHBOARD` but not `WORKBENCH_USER_MANAGEMENT`. Two options: (a) add a new permission, or (b) use the existing `adminGroupsApi.list()` and widen its permission gate. Option (b) is simpler — add `WORKBENCH_GROUP_DASHBOARD` to the allowed permissions for listing all groups.

**Alternatives considered**:
- Create a new `/api/groups/all` endpoint: rejected as unnecessary duplication
- Send all groups in the auth response: rejected because it couples group listing to auth and increases payload size

## Decision 4: Audit Log Access Type Field

**Decision**: Add an `access_type` field to the `details` JSON object in audit log entries. Values: `"membership"` or `"global_role"`. No schema migration needed — `details` is a JSONB column.

**Rationale**: The existing `logAuditEvent()` function at `auth.service.ts:495-508` accepts a `details: Record<string, unknown>` parameter. Adding `access_type` as a key in the details object requires zero schema changes and is immediately queryable via JSONB operators.

**Alternatives considered**:
- Add a dedicated `access_type` column to `audit_log`: rejected as over-engineering for a single field that doesn't need indexing
- Skip audit distinction entirely: rejected because the spec requires it (FR-007) for compliance

## Decision 5: Group Context Switching for Global Roles

**Decision**: Modify `setActiveGroup()` in `groupMembership.service.ts:95-130` to allow global role holders to set any group as active without membership validation.

**Rationale**: Currently `setActiveGroup()` validates that the user has an active membership in the target group (line 101-125). For global role holders, this check must be bypassed. The function already has an internal flow — adding a role-tier check at the top is the minimal change.

**Alternatives considered**:
- Create a separate `setActiveGroupForGlobalRole()`: rejected because it duplicates logic and creates two code paths for the same operation
- Pass a `skipMembershipCheck` flag: rejected because callers shouldn't know about access internals — the function should resolve this from the user's role

## Decision 6: Affected Repositories

**Decision**: Changes span three repositories: `chat-types`, `chat-backend`, `workbench-frontend`. No changes to `chat-frontend`, `chat-frontend-common` (beyond what's inherited from `chat-types`), or `chat-ui`.

**Rationale**:
- `chat-types`: New constant (`GLOBAL_GROUP_ACCESS_ROLES`) in `rbac.ts`
- `chat-backend`: New `groupAccess.service.ts`, updates to group routes, review routes, and groupMembership service
- `workbench-frontend`: Update `GroupScopeSelector.tsx` to show all groups for eligible roles
- `chat-frontend-common` does not need changes because the auth store already stores `user.role` and `user.permissions` — the workbench frontend reads these directly
- `chat-frontend` (chat app) is explicitly out of scope
- `chat-ui` E2E tests: would require test accounts with specific role configurations; testing is handled via backend unit/integration tests

**Alternatives considered**:
- Move `canAccessGroup` to `chat-frontend-common`: rejected because it's a backend authorization function, not a frontend utility

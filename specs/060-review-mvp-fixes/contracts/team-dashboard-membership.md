# Contract: GET /api/team-dashboard/membership

> ⚠️ **V1 DESIGN — ABANDONED.** This contract describes a v1 backend endpoint (`GET /api/team-dashboard/membership` returning `{ spaces, hasTeamMembership, missingRole }`) that was never implemented. After investigation on 2026-04-27 the chat-backend `/api/review/dashboard/team` endpoint turned out to be permission-gated only (`requireReviewTeamDashboard`) — there is no membership endpoint. The MC-67 divergence is purely **frontend-side**: `TeamDashboard.tsx` consulted `user.memberships` while `GroupScopeSelector` ALSO uses `adminGroupsApi.list()` for privileged users. The actual fix is the new `computeTeamSpaceOptions` helper in `TeamDashboard.tsx` (workbench-frontend `2899219`). Kept here for speckit chain provenance only — see `../tasks.md` (US3 / T300..T304) for what actually shipped.

---

**Feature**: `060-review-mvp-fixes` | **FR refs**: FR-013, FR-014, FR-015, FR-016 *(v1 numbering — superseded; revised spec.md uses FR-005, FR-006)*

## Purpose

Return the membership status that the Team Dashboard frontend uses to decide whether to render content or one of two empty states.

## Request

```
GET /api/team-dashboard/membership
Headers:
  Authorization: Bearer <session-token>
```

No query params. The user identity is derived from the auth token.

## Behavior changes (this fix)

### Single source for Space membership (FR-013)

Before: the Team Dashboard's membership check used a bespoke query that disagreed with the Space combobox endpoint.

After: this endpoint MUST call `getSpacesForUser(userId)` — the same source that powers `/api/admin/groups` (the Space combobox endpoint). The two endpoints MUST always agree about Space membership.

### Response shape with discriminator (FR-014, FR-015, FR-016)

The response includes a `missingRole` discriminator that the frontend uses to render specific empty-state copy when applicable.

## Response (success)

**HTTP 200**

### Case 1: User has Spaces and meets team-member role requirement (FR-014)

```json
{
  "spaces": [
    { "id": "ba1ced2d-...", "name": "Dev team" },
    { "id": "f3a8c1d7-...", "name": "RegressionTest-023" }
  ],
  "hasTeamMembership": true,
  "missingRole": null
}
```

Frontend renders Team Dashboard content.

### Case 2: User has Spaces but lacks team-member role (FR-015)

```json
{
  "spaces": [
    { "id": "ba1ced2d-...", "name": "Dev team" }
  ],
  "hasTeamMembership": false,
  "missingRole": "reviewer-team-member"
}
```

Frontend renders empty-state copy: "Team Dashboard requires the Reviewer team-member role; ask your administrator to grant access."

### Case 3: User has zero Spaces (FR-016)

```json
{
  "spaces": [],
  "hasTeamMembership": false,
  "missingRole": null
}
```

Frontend renders empty-state copy: "You are not a member of any Space. Team statistics are shown per Space membership."

## Owner role behavior (this fix)

For the Owner role specifically: the team-member role requirement is satisfied implicitly. An Owner with ≥1 Space ALWAYS gets `hasTeamMembership: true, missingRole: null`. This is the expected case for the `playwright@mentalhelp.global` test account.

If product later defines a stricter requirement, the change is internal to `team-membership.service`; the contract surface stays the same.

## Response (errors)

| Status | Condition | Response shape |
|--------|-----------|----------------|
| 401 | Missing/invalid auth token | `{ error: "UNAUTHORIZED" }` |
| 403 | User has no Workbench access at all | `{ error: "FORBIDDEN" }` |
| 500 | Service failure | `{ error: "INTERNAL", traceId: "..." }` |

## Edge cases

- **Space deletion race**: If a Space is deleted between the membership check and the response build, the `spaces` array reflects the post-deletion state. `hasTeamMembership` is computed against the final array.
- **First-time login**: User just signed in; membership cache may be cold. The endpoint MUST NOT return stale data; force a fresh read from the membership source.
- **Role downgrade**: User loses team-member role mid-session. Next call to this endpoint returns `hasTeamMembership: false`; frontend re-renders empty-state. No special revoke flow needed.

## Backwards compatibility

This is effectively a new endpoint shape. The previous endpoint may have returned a different shape (the regression observed only the empty-state behavior, not the wire format). The frontend MUST be deployed alongside or after the backend; if frontend is older it can safely treat the new shape as a strict superset (ignore `missingRole` if absent).

## Test contract

| Test | Verifies |
|------|----------|
| Unit (`tests/unit/services/team-membership.test.ts`) | Each of the 3 response cases produces the correct shape |
| Integration ("membership matches Space combobox") | `team-dashboard/membership.spaces` == `admin/groups` for the same user |
| Integration ("Owner with Spaces gets hasTeamMembership=true") | Owner test account sees Case 1 response |
| Component test (`TeamDashboard.test.tsx`) | Each of the 3 response cases triggers the correct rendered state |
| Regression YAML (RD-005) | Owner with ≥1 Space sees content (not empty state) |

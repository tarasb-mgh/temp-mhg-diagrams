# Contract: GET /api/dashboard/summary

> ⚠️ **V1 DESIGN — ABANDONED.** This contract describes a hypothetical `GET /api/dashboard/summary` endpoint that does not exist. The actual chat-backend endpoint that surfaces the "Pending Review" tile is `/api/review/dashboard/team` (handler: `reviewDashboard.service.ts` `getTeamStats`). The MC-64 fix is to extend the `pending_review` FILTER inside `getTeamStats`'s queue-depth query to apply the same eligibility guards (parity, capacity, exclusions) used by `getQueueCounts.pending` (chat-backend `c7648ac`). No new endpoint, no DTO refactor. Kept here for speckit chain provenance only — see `../tasks.md` (US2 / T200..T203) for what actually shipped.

---

**Feature**: `060-review-mvp-fixes` | **FR refs**: FR-004, FR-005, FR-006, FR-007, FR-008 *(v1 numbering — superseded; revised spec.md uses FR-003, FR-004)*

## Purpose

Aggregate counters for the workbench Dashboard tiles. After this fix, the "Pending Review" counter consolidates onto the same source as the Review Queue API.

## Request

```
GET /api/dashboard/summary
Query params:
  groupId: UUID (optional; null/absent means All Spaces)
Headers:
  Authorization: Bearer <session-token>
```

## Behavior changes (this fix)

### Pending Review counter source (FR-004, FR-008)

Before: bespoke `SELECT COUNT(*) ...` query unique to this endpoint.

After: delegates to `reviewQueueService.countBy({ groupId, statuses: ['pending'], isBroken: false })`. This is the same helper used by the Review Queue list endpoint to populate the Pending tab badge.

The tile's count reflects:
- Sessions in `pending` status (including all sub-statuses: `new`, `unfinished`, `repeat`).
- Scoped to the user's selected Space (or All Spaces when `groupId` absent).
- Excluding broken sessions (`is_broken = false`).

### Space-aware (FR-005)

The endpoint already accepts `groupId`; this fix ensures the tile ALWAYS sends it (not previously the case for the Pending Review counter — it ignored the param). The frontend `PendingReviewTile.tsx` MUST send the active Space's `groupId`.

## Response (success)

**HTTP 200**

```json
{
  "scope": {
    "groupId": "ba1ced2d-e827-4a2e-8d16-94fc3085962e",
    "groupName": "Dev team"
  },
  "counters": {
    "pendingReview": 31,
    "activeUsers": 44,
    "pendingApprovals": 12,
    "blockedUsers": 0,
    "activeSessions": 5
  }
}
```

When `groupId` is absent (All Spaces):

```json
{
  "scope": {
    "groupId": null,
    "groupName": "All Spaces"
  },
  "counters": {
    "pendingReview": 31,
    "...": "..."
  }
}
```

The frontend uses `scope.groupName` to render the scope label on the tile (FR-006).

## Tile click-through behavior (FR-007)

When the user clicks the "Pending Review" tile:

```
Frontend: read counters.pendingReview, scope.groupId
  ↓
Navigate to /workbench/review?space=<scope.groupId>&tab=pending
  ↓
Review Queue page reads space query param, sets Space combobox
  ↓
Queue API call uses same groupId
  ↓
Pending tab badge equals tile's count (FR-007)
```

## Response (errors)

| Status | Condition | Response shape |
|--------|-----------|----------------|
| 401 | Missing/invalid auth token | `{ error: "UNAUTHORIZED" }` |
| 403 | User lacks Workbench access role | `{ error: "FORBIDDEN" }` |
| 500 | Counter query failure | `{ error: "INTERNAL", traceId: "..." }` |

## Edge cases

- **Counter query times out**: Endpoint returns 200 with `pendingReview: null` (or omits the field). Frontend renders "—" not stale "0".
- **Space switch race**: If two requests are in-flight (one for old Space, one for new), the frontend uses the latest request's response only; older response is discarded.
- **All Spaces**: `groupId` absent. The counter reflects all sessions in `pending` status across every Space the user has access to (typical for Owner/Admin roles).

## Backwards compatibility

- The response shape gains a `scope` object. Old clients that read `counters.pendingReview` directly continue to work; the new field provides labeling context.
- Old clients that don't send `groupId` get All-Spaces semantics (existing behavior). New clients send the active Space's `groupId` to scope.

## Test contract

| Test | Verifies |
|------|----------|
| Unit (`tests/unit/services/review-queue.test.ts`) | `countBy()` returns the same number as `listBy().length` for matching params |
| Integration (`tests/integration/api/dashboard.test.ts`, "pending counter scoped to groupId") | Counter reflects only the requested Space's pending sessions |
| Integration ("pending counter excludes broken") | A seeded broken session is NOT counted in `pendingReview` |
| Integration ("counter parity with queue endpoint") | `dashboard/summary.counters.pendingReview === review/queue?tab=pending&groupId=X.total` |
| Regression YAML (RQ-002a) | Dashboard tile count == Queue Pending tab badge under matching Space scope |

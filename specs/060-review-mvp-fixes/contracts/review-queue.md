# Contract: GET /api/review/queue

> ⚠️ **V1 DESIGN — ABANDONED.** This contract describes the v1 fix-bundle design (a new `is_broken` filter, `?include_broken=true` admin opt-in, and `brokenReason` field on the response) that was discarded after codebase inspection on 2026-04-27. The actual MC-65 fix is far narrower: the existing 058 `reviewerTabHasAssistantMessage` parity guard is extended to the **flagged** and **in_progress** tab branches in `getQueueCounts` and `listQueueSessions` (chat-backend `2baface`). No new fields, no new query params, no new admin opt-in. Kept here for speckit chain provenance only — see `../tasks.md` (US1 / T100..T103) for what actually shipped.

---

**Feature**: `060-review-mvp-fixes` | **FR refs**: FR-001, FR-002, FR-003, FR-010 *(v1 numbering — partially superseded)*

## Purpose

List review-queue sessions filtered by tab, sub-status, Space, and (after this fix) broken-flag.

## Request

```
GET /api/review/queue
Query params:
  page: number (1-indexed, default 1)
  groupId: UUID (optional; null/absent means All Spaces)
  tab: 'pending' | 'flagged' | 'in_progress' | 'completed' | 'excluded' | 'supervision_queue' | 'awaiting_feedback'
  status: 'new' | 'unfinished' | 'repeat' (optional sub-status filter for Pending tab)
  include_broken: boolean (default false; admin-only)
Headers:
  Authorization: Bearer <session-token>
```

## Behavior changes (this fix)

### Default behavior (FR-001)

When `include_broken` is absent or `false`:
- The query MUST add `WHERE is_broken = false` (or `WHERE is_broken IS NOT TRUE` to handle NULL).
- Broken sessions MUST NOT appear in any tab's response.
- Counts returned in tab badges MUST exclude broken sessions.

### Admin opt-in (FR-002)

When `include_broken=true`:
- The server MUST verify the caller has admin permission. If not, the parameter is silently ignored (filter still applied).
- If permitted, the response includes broken sessions, each with `isBroken: true` and `brokenReason: <typed>` populated in the DTO.

### Logging (FR-020)

For every queue response that filtered broken sessions, the backend MUST log a structured event:
```
{ "event": "queue_broken_filtered", "tab": "<tab>", "groupId": "<id|null>", "filteredCount": N }
```

## Response (success)

**HTTP 200**

```json
{
  "page": 1,
  "totalPages": 3,
  "total": 31,
  "items": [
    {
      "id": "be2dc550-f382-4094-ae0b-821bed5fe2e5",
      "chatId": "CHAT-8611",
      "userRef": "USER-E65B",
      "status": "pending",
      "subStatus": "unfinished",
      "groupId": "ba1ced2d-e827-4a2e-8d16-94fc3085962e",
      "messageCount": 8,
      "createdAt": "2026-02-01T10:00:00Z",
      "tags": [],
      "isBroken": false,
      "brokenReason": null
    }
    // ...
  ]
}
```

When `include_broken=true` AND admin caller:

```json
{
  "items": [
    {
      "id": "...",
      "chatId": "CHAT-8611",
      "...": "...",
      "isBroken": true,
      "brokenReason": "UNKNOWN"
    }
  ]
}
```

## Response (errors)

| Status | Condition | Response shape |
|--------|-----------|----------------|
| 400 | Invalid `tab` value | `{ error: "INVALID_TAB", message: "..." }` |
| 401 | Missing/invalid auth token | `{ error: "UNAUTHORIZED" }` |
| 403 | User lacks Reviewer/Supervisor/Admin role | `{ error: "FORBIDDEN" }` |
| 500 | DB query failure | `{ error: "INTERNAL", traceId: "..." }` |

## Backwards compatibility

- Existing callers (workbench-frontend Queue.tsx) work unchanged: they don't send `include_broken`, so they get the new default-filtered behavior.
- The new `brokenReason` field is opt-in to read; clients that ignore it are not affected.
- Legacy session rows with `is_broken = NULL` are treated as not-broken (safe default per R-005).

## Test contract

| Test | Verifies |
|------|----------|
| Unit (`tests/unit/services/review-queue.test.ts`) | `listBy()` and `countBy()` return identical row sets for the same `WhereParams` |
| Integration (`tests/integration/api/review-queue.test.ts`, "default filters broken") | A seeded broken session is NOT in the response |
| Integration ("admin opt-in includes broken") | Same broken session appears with `isBroken=true, brokenReason=<typed>` when admin sends `include_broken=true` |
| Integration ("non-admin opt-in is ignored") | Reviewer-role user with `include_broken=true` still gets filtered response |
| Regression YAML (RQ-014) | No card with `Broken` badge in any reviewer-facing tab |

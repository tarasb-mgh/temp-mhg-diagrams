# API Contract: Review Queue Safety Prioritisation

**Branch**: `032-review-queue-safety-priority`
**Date**: 2026-03-15
**Base URL**: `/api/review`

All changes are **additive** to existing endpoints. No breaking changes.

---

## Modified Endpoint 1: GET /api/review/queue

### Change
Response `items` array: each `QueueSession` object gains `safetyPriority` field.
Response `counts` object gains `elevated` field.

### Request (unchanged)
```
GET /api/review/queue
  ?page=1
  &pageSize=20
  &tab=pending|flagged|in_progress|completed
  &sortBy=priority|oldest|newest
  &riskLevel=high|medium|low|none
  &language=en|uk|ru
  &dateFrom=ISO8601
  &dateTo=ISO8601
  &assignedToMe=true|false
  &tags=comma,separated
  &groupId=UUID
```

### Response (additions highlighted)
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "anonymousSessionId": "anon-xxx",
      "anonymousUserId": "anon-yyy",
      "messageCount": 12,
      "assistantMessageCount": 6,
      "reviewStatus": "pending_review",
      "reviewCount": 0,
      "reviewsRequired": 3,
      "riskLevel": "medium",
      "autoFlagged": false,
      "safetyPriority": "elevated",
      "language": "uk",
      "startedAt": "2026-03-15T10:00:00Z",
      "endedAt": "2026-03-15T10:45:00Z",
      "myReviewStatus": "not_started",
      "assignedReviewerId": null,
      "tags": []
    }
  ],
  "counts": {
    "pending": 42,
    "flagged": 8,
    "inProgress": 5,
    "completed": 120,
    "elevated": 3
  },
  "meta": {
    "page": 1,
    "pageSize": 20,
    "total": 42
  }
}
```

### Error: 401 Unauthorized
```json
{
  "success": false,
  "error": "UNAUTHORIZED",
  "message": "Authentication required"
}
```

### Error: 403 Forbidden
```json
{
  "success": false,
  "error": "INSUFFICIENT_PERMISSIONS",
  "message": "Requires REVIEW_ACCESS permission"
}
```

### Sort behaviour when `sortBy=priority` (default)
Elevated sessions (`safetyPriority: 'elevated'`) sort above all `normal` sessions. Within each tier, existing sort logic (risk_level → auto_flagged → oldest) is preserved.

---

## Modified Endpoint 2: POST /api/review/sessions/:sessionId/submit

### Change
Request body gains two optional fields that become **server-side required** when the session has `safetyPriority = 'elevated'`.

### Request
```json
POST /api/review/sessions/uuid/submit
Content-Type: application/json

{
  "overallComment": "optional string",
  "safetyFlagDisposition": "resolve | escalate | false_positive",
  "safetyFlagNotes": "optional string"
}
```

| Field | Type | Required | Validation |
|-------|------|----------|------------|
| `overallComment` | string | No | Max 2000 chars |
| `safetyFlagDisposition` | `'resolve' \| 'escalate' \| 'false_positive'` | **Required if session is elevated** | Must be one of the three values |
| `safetyFlagNotes` | string | No | No hard limit enforced; soft UI hint at 500 chars |

### Error: 401 Unauthorized
```json
{
  "success": false,
  "error": "UNAUTHORIZED",
  "message": "Authentication required"
}
```

### Error: 403 Forbidden
```json
{
  "success": false,
  "error": "INSUFFICIENT_PERMISSIONS",
  "message": "Requires REVIEW_SUBMIT permission"
}
```

### Error: 404 Not Found
```json
{
  "success": false,
  "error": "SESSION_NOT_FOUND",
  "message": "Session not found"
}
```

### Error: 400 Bad Request (missing disposition for elevated session)
```json
{
  "success": false,
  "error": "SAFETY_FLAG_DISPOSITION_REQUIRED",
  "message": "A safety flag disposition is required for elevated sessions"
}
```

### Success: 200 OK
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "sessionId": "uuid",
    "reviewerId": "uuid",
    "status": "submitted",
    "completedAt": "2026-03-15T14:32:00Z"
  }
}
```

### Side effects per disposition

| Disposition | `risk_flags.status` | `sessions.safety_priority` | Supervisor queue |
|-------------|--------------------|-----------------------------|-----------------|
| `resolve` | `'resolved'` | `'normal'` | Not surfaced |
| `escalate` | `'escalated'` | stays `'elevated'` | Surfaced as escalated |
| `false_positive` | `'resolved'` (audit event_type distinguishes as `false_positive`) | `'normal'` | Not surfaced |

---

## New Endpoint 3: PATCH /api/review/sessions/:sessionId/safety-flag/reopen

For supervisors to reopen a previously resolved flag. Accepts flags in `resolved` status regardless of whether the original disposition was `resolve` or `false_positive` (both set `risk_flags.status = 'resolved'`; the original disposition is recorded in `safety_flag_audit_events.event_type`). The supervisor's clinical judgment at reopen time is what determines whether reopening is warranted.

### Authorization
Requires `REVIEW_SUPERVISE` permission.

### Request
```json
PATCH /api/review/sessions/uuid/safety-flag/reopen
Content-Type: application/json

{
  "notes": "optional string — reason for reopening"
}
```

### Response: 200 OK
```json
{
  "success": true,
  "data": {
    "flagId": "uuid",
    "status": "open",
    "reopenedAt": "2026-03-15T16:00:00Z"
  }
}
```

### Error: 404 Not Found
```json
{
  "success": false,
  "error": "NO_SAFETY_FLAG",
  "message": "No safety flag found for this session"
}
```

### Error: 409 Conflict
```json
{
  "success": false,
  "error": "FLAG_NOT_DISMISSED",
  "message": "Flag must be in resolved state to reopen"
}
```

---

## Existing Endpoint: GET /api/review/supervision/queue

Existing supervisor queue endpoint (from spec 011). FR-013 requires escalated sessions to appear above routine second-level review items.

### Authorization
Requires `REVIEW_SUPERVISE` permission.

### Request
```
GET /api/review/supervision/queue
```

### Response: 200 OK
```json
{
  "success": true,
  "data": [
    {
      "sessionReviewId": "uuid",
      "sessionId": "uuid",
      "reviewerName": "Reviewer Name",
      "groupName": "Group Name",
      "messageCount": 12,
      "iteration": 1,
      "submittedAt": "2026-03-15T14:32:00Z",
      "safetyPriority": "elevated",
      "escalationDisposition": "escalate"
    }
  ]
}
```

### Sort behaviour
Escalated sessions (`safetyPriority: 'elevated'` AND `escalationDisposition: 'escalate'`) sort above routine second-level review items. Within each tier, sorted by `submittedAt ASC` (oldest first).

### Error: 401 Unauthorized
```json
{
  "success": false,
  "error": "UNAUTHORIZED",
  "message": "Authentication required"
}
```

### Error: 403 Forbidden
```json
{
  "success": false,
  "error": "INSUFFICIENT_PERMISSIONS",
  "message": "Requires REVIEW_SUPERVISE permission"
}
```

---

## Existing Endpoint: POST /api/review/supervision/:sessionReviewId/decision

This is the existing supervisor decision endpoint (from spec 011). FR-014 requires that escalated sessions use this same endpoint. No new endpoint is needed — the existing contract already supports the required flow.

### Authorization
Requires `REVIEW_SUPERVISE` permission.

### Request
```json
POST /api/review/supervision/uuid/decision
Content-Type: application/json

{
  "decision": "approved | disapproved",
  "comments": "string (optional)",
  "returnToReviewer": false
}
```

| Field | Type | Required | Validation |
|-------|------|----------|------------|
| `decision` | `'approved' \| 'disapproved'` | Yes | Must be one of the two values |
| `comments` | string | No | Optional per FR-014; may be empty |
| `returnToReviewer` | boolean | No | Only valid when `decision = 'disapproved'` and iteration < 3 |

### Response: 200 OK
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "sessionReviewId": "uuid",
    "decision": "approved",
    "comments": "Escalation confirmed — clinical concern valid",
    "iteration": 1,
    "createdAt": "2026-03-15T16:30:00Z"
  }
}
```

### Error: 403 Forbidden
```json
{
  "success": false,
  "error": "INSUFFICIENT_PERMISSIONS",
  "message": "Requires REVIEW_SUPERVISE permission"
}
```

### Error: 404 Not Found
```json
{
  "success": false,
  "error": "REVIEW_NOT_FOUND",
  "message": "Session review not found"
}
```

### Behaviour for escalated sessions
When a supervisor submits a decision on a review that included an `escalate` disposition:
- **approved** (confirm escalation): The supervisor confirms the clinical concern is valid. The session's `safety_priority` is reset to `'normal'` (supervisor-resolved — removed from the escalated tier per spec US3 AC3), and an audit event with `event_type = 'supervisor_resolved'` is recorded.
- **disapproved** (dismiss escalation): The supervisor overrides the reviewer's escalation. The session's `safety_priority` is reset to `'normal'`, and an audit event with `event_type = 'supervisor_dismissed'` is recorded.

---

## Frontend Component Contract: SafetyFlagResolutionStep

```typescript
// workbench-frontend/src/features/workbench/review/components/SafetyFlagResolutionStep.tsx

interface SafetyFlagResolutionStepProps {
  disposition: SafetyFlagDisposition | null;
  notes: string;
  onChange: (disposition: SafetyFlagDisposition | null, notes: string) => void;
  disabled?: boolean;
}
```

**Renders when**: parent `ReviewSessionView` receives a session where `safetyPriority === 'elevated'`.
**Does not render when**: `safetyPriority === 'normal'`.

**Behaviour**:
- Three radio buttons: Resolve / Escalate / False Positive
- Optional textarea for notes (shown below radio group)
- Passes `null` as disposition until user selects an option
- Parent blocks submit if `safetyPriority === 'elevated'` and `disposition === null`

---

## i18n Keys Required

All keys under `review.safetyFlag.*` — to be added to `en.json`, `uk.json`, `ru.json` in `workbench-frontend`:

```jsonc
"review": {
  "safetyFlag": {
    "priorityBadge": "Elevated",              // UK: "Підвищений пріоритет", RU: "Повышенный приоритет"
    "resolutionTitle": "Safety Flag Resolution",
    "resolutionRequired": "A safety flag resolution is required before submitting.",
    "dispositionResolve": "Resolve — no further action needed",
    "dispositionEscalate": "Escalate — requires clinical attention",
    "dispositionFalsePositive": "False Positive — AI filter misfired",
    "notesLabel": "Notes (optional)",
    "notesPlaceholder": "Add context about your decision…",
    "notesHint": "Visible to supervisors",
    "elevatedCount": "{{count}} elevated",    // for queue counts badge
    "queueBadgeAriaLabel": "Elevated priority session"
  }
}
```

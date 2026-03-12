# Data Model: Release Batch — v2026.03.11

**Feature**: 026-release-batch-docs
**Phase**: 1 — Design (Retrospective)
**Date**: 2026-03-11

---

## Entity Changes

### ChatMessage (modified)

Existing entity. The `metadata.client` sub-object gained a new status value.

| Field | Type | Change |
|---|---|---|
| `metadata.client.status` | `'sending' \| 'failed' \| 'pending'` | Added `'pending'` — message queued for retry due to network loss |
| `metadata.client.originalContent` | `string \| undefined` | Existing — stores content for retry |
| `metadata.client.retryable` | `boolean \| undefined` | Existing |

**Status semantics**:
- `sending` — optimistic UI, request in-flight
- `failed` — server returned an error (5xx); manual retry button shown
- `pending` — network unreachable; auto-retried when `online` event fires

**Persistence**: `metadata.client` is a client-only field — never written to the
database. It is stripped before any persistence operation.

---

### SurveySchema (modified)

Existing entity. Added `instructions` field.

| Field | Type | Change |
|---|---|---|
| `id` | `uuid` | Unchanged |
| `groupId` | `uuid` | Unchanged |
| `title` | `string` | Unchanged |
| `questions` | `SurveyQuestion[]` | Unchanged |
| `visibilityConditions` | `VisibilityCondition[]` | Enhanced — now supports multiple conditions per question (AND logic) and `NOT_IN` operator |
| `instructions` | `string \| null` | **New** — markdown-formatted instructions shown above the survey. Moved from `survey_instances`. |
| `createdAt` | `timestamp` | Unchanged |
| `updatedAt` | `timestamp` | Unchanged |

---

### SurveyResponse (new)

Tracks a user's answers to a survey schema instance. Used by the gate-check
endpoint to determine whether a user has completed their required intake survey.

| Field | Type | Notes |
|---|---|---|
| `id` | `uuid` | Primary key |
| `userId` | `uuid` | FK → users |
| `surveySchemaId` | `uuid` | FK → survey_schemas |
| `surveyInstanceId` | `uuid \| null` | FK → survey_instances (if applicable) |
| `answers` | `jsonb` | Map of `questionId → answer value(s)` |
| `completedAt` | `timestamp \| null` | Set when user submits; null while in progress |
| `createdAt` | `timestamp` | |
| `updatedAt` | `timestamp` | |

**State transitions**:
```
[created on first answer PATCH] → completedAt = null (in-progress)
                                 → completedAt = timestamp (submitted)
```

---

### RAGCallDetail (transient, not persisted)

Returned in the `POST /api/chat/message` response payload for tester-tagged users only.
Never written to the database.

| Field | Type | Notes |
|---|---|---|
| `retrievedDocuments` | `RAGDocument[]` | Documents retrieved from the knowledge base |
| `queryText` | `string` | The query sent to the retrieval system |
| `retrievalTimeMs` | `number` | Latency of the retrieval call |

**`RAGDocument`**:

| Field | Type | Notes |
|---|---|---|
| `id` | `string` | Document identifier in the knowledge base |
| `title` | `string \| null` | Document title |
| `excerpt` | `string` | Relevant passage retrieved |
| `score` | `number` | Relevance score (0–1) |

---

## Visibility Condition Schema (enhanced)

Survey question visibility conditions now support multiple simultaneous conditions
and the `NOT_IN` operator.

```typescript
interface VisibilityCondition {
  questionId: string;          // which question's answer to test
  operator: 'IN' | 'NOT_IN';  // NEW: NOT_IN operator added
  values: string[];            // set of values to test against
}

// A question's visibility rule is an array of conditions (AND logic):
interface QuestionVisibility {
  conditions: VisibilityCondition[];  // all must be true for question to show
}
```

**Previous model**: single `VisibilityCondition` per question, `IN` operator only.
**New model**: array of conditions (AND), both `IN` and `NOT_IN` operators.

---

## Session Persistence (client-side)

Not a database entity — documents the client-side state management contract.

| Storage | Key | Value | Cleared when |
|---|---|---|---|
| `localStorage` | `mhg_chat_session_id` | Session UUID string | `endSession()`, `endSessionInBackground()`, user-identity change |

**Resume flow**:
1. On `startSession()`, check `localStorage` for stored session ID (authenticated users only)
2. `GET /api/chat/sessions/:id/conversation` — if `status === 'active'`, restore messages
3. If non-active, 404, or network error → fall through to `POST /api/chat/sessions` (new session)
4. On new session success → write session ID to `localStorage`

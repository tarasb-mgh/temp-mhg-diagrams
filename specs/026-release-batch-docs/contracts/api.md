# API Contracts: Release Batch — v2026.03.11

**Feature**: 026-release-batch-docs
**Phase**: 1 — Design (Retrospective)
**Date**: 2026-03-11
**Base URL**: `https://api.mentalhelp.chat` (prod) / `https://api.dev.mentalhelp.chat` (dev)

---

## New Endpoints

### GET /api/chat/sessions/:id/conversation

Retrieves the full conversation history for an existing session. Used by the frontend
to restore a session on page reload.

**Auth**: Bearer token (authenticated users only)

**Path params**:
| Param | Type | Description |
|---|---|---|
| `id` | `uuid` | Session ID |

**Response 200**:
```json
{
  "data": {
    "sessionId": "uuid",
    "status": "active | ended | expired",
    "messages": [
      {
        "id": "uuid",
        "role": "user | assistant | system",
        "content": "string",
        "timestamp": "ISO8601",
        "metadata": { ... }
      }
    ]
  }
}
```

**Response 404**: Session not found or does not belong to authenticated user.

**Client behaviour**:
- If `status !== 'active'` → treat as if 404; start new session
- `system` role messages are filtered out before display

---

### GET /api/chat/gate-check

Checks whether the authenticated user has completed the required gate survey for
their current group. Called during chat initialisation before session creation.

**Auth**: Bearer token

**Response 200**:
```json
{
  "data": {
    "required": true,
    "completed": false,
    "surveySchemaId": "uuid | null",
    "surveyInstanceId": "uuid | null",
    "existingResponseId": "uuid | null"
  }
}
```

**Client behaviour**:
- If `required && !completed` → show survey UI before chat
- If `!required || completed` → proceed directly to session creation

---

### POST /api/chat/survey-responses

Creates a new survey response record (called when user begins the gate survey).

**Auth**: Bearer token

**Request body**:
```json
{
  "surveySchemaId": "uuid",
  "surveyInstanceId": "uuid | null"
}
```

**Response 201**:
```json
{
  "data": {
    "id": "uuid",
    "surveySchemaId": "uuid",
    "completedAt": null
  }
}
```

---

### PATCH /api/chat/survey-responses/:id

Updates answers and/or marks the survey response as completed.

**Auth**: Bearer token

**Path params**:
| Param | Type | Description |
|---|---|---|
| `id` | `uuid` | Survey response ID |

**Request body**:
```json
{
  "answers": {
    "question-uuid-1": "answer string",
    "question-uuid-2": ["option-a", "option-b"]
  },
  "completed": true
}
```

**Response 200**:
```json
{
  "data": {
    "id": "uuid",
    "completedAt": "ISO8601 | null"
  }
}
```

---

## Modified Endpoints

### POST /api/chat/message (modified)

Existing endpoint for sending a chat message and receiving an assistant response.

**Change**: For tester-tagged users, the response now includes a `ragCallDetail` field.

**Additional response field (tester users only)**:
```json
{
  "data": {
    "message": { ... },
    "ragCallDetail": {
      "queryText": "string",
      "retrievalTimeMs": 120,
      "retrievedDocuments": [
        {
          "id": "string",
          "title": "string | null",
          "excerpt": "string",
          "score": 0.87
        }
      ]
    }
  }
}
```

**For non-tester users**: `ragCallDetail` is omitted entirely (not `null`).

---

## Modified Survey Schema Endpoints

### GET /api/admin/survey-schemas/:id (modified)

**Change**: Response now includes `instructions` field.

```json
{
  "data": {
    "id": "uuid",
    "title": "string",
    "instructions": "markdown string | null",
    "questions": [ ... ],
    ...
  }
}
```

### PUT /api/admin/survey-schemas/:id (modified)

**Change**: Accepts `instructions` in the request body.

```json
{
  "title": "string",
  "instructions": "string | null",
  "questions": [ ... ]
}
```

---

## Unchanged Endpoints (referenced for completeness)

| Endpoint | Purpose |
|---|---|
| `POST /api/chat/sessions` | Create a new chat session |
| `POST /api/chat/sessions/:id/end` | Explicitly end a session |
| `GET /api/auth/me` | Get authenticated user (includes `testerTagAssigned`) |
| `POST /api/auth/refresh` | Refresh access token |
| `GET /api/settings` | Public app settings (no auth) |

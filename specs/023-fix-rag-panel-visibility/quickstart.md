# Quickstart: Fix RAG Panel Visibility (023)

**Branch**: `023-fix-rag-panel-visibility`
**Repos**: `chat-types`, `chat-backend`, `workbench-frontend`, `chat-frontend`

---

## Prerequisites

- PostgreSQL running locally (Docker: `postgres:15-alpine`)
- Migration `032_seed_tester_tag_definition.sql` already applied (part of bugfix `001-fix-tester-tags-users`)
- A test account with the `tester` tag assigned (use admin tester-tag UI from `024-tester-tag-workbench` or direct SQL)

Assign tester tag manually if needed:
```sql
-- Get the tester tag definition ID
SELECT id FROM tag_definitions WHERE LOWER(name) = 'tester';

-- Assign to a user (replace UUIDs)
INSERT INTO user_tags (user_id, tag_definition_id, assigned_by, assigned_at)
VALUES ('<user-uuid>', '<tester-tag-def-uuid>', '<admin-uuid>', NOW())
ON CONFLICT DO NOTHING;
```

---

## Local Development Setup

### 1. Install dependencies (all repos)

```bash
cd /Users/malyarevich/dev/chat-types && npm install && npm run build
cd /Users/malyarevich/dev/chat-backend && npm install
cd /Users/malyarevich/dev/workbench-frontend && npm install
cd /Users/malyarevich/dev/chat-frontend && npm install
```

### 2. Start backend

```bash
cd /Users/malyarevich/dev/chat-backend && npm run dev
```

### 3. Start frontends

```bash
# Terminal 1
cd /Users/malyarevich/dev/workbench-frontend && npm run dev

# Terminal 2
cd /Users/malyarevich/dev/chat-frontend && npm run dev
```

---

## Validation Checklist

### Backend: `GET /api/auth/me`

```bash
TOKEN="<valid-access-token-for-tester-tagged-user>"
curl -s -H "Authorization: Bearer $TOKEN" \
  https://api.workbench.dev.mentalhelp.chat/api/auth/me \
  | jq '.data.testerTagAssigned'
# Expected: true
```

For a non-tester user:
```bash
curl -s -H "Authorization: Bearer $NON_TESTER_TOKEN" \
  https://api.workbench.dev.mentalhelp.chat/api/auth/me \
  | jq '.data.testerTagAssigned'
# Expected: false or null
```

### Backend: `POST /api/chat/message` (tester user)

```bash
curl -s -X POST -H "Authorization: Bearer $TESTER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"message": "tell me about cognitive behavioral therapy"}' \
  https://api.workbench.dev.mentalhelp.chat/api/chat/message \
  | jq '.data.assistantMessage.ragCallDetail'
# Expected: non-null object with retrievalQuery + retrievedDocuments (when RAG triggered)
# Expected: null (when RAG not triggered for this query)
```

### Backend: `GET /api/review/sessions/:id` (reviewer)

```bash
curl -s -H "Authorization: Bearer $REVIEWER_TOKEN" \
  https://api.workbench.dev.mentalhelp.chat/api/review/sessions/<session-id> \
  | jq '[.data.messages[] | select(.role == "assistant") | .ragCallDetail] | first'
# Expected: RAGCallDetail object for sessions where RAG was used
```

### Frontend: Chat interface (tester-tagged user)

1. Log in as a tester-tagged user in chat-frontend
2. Send a message that triggers RAG retrieval
3. Verify the RAG panel appears below the assistant message bubble
4. Log in as a non-tester user — confirm no RAG panel appears

### Frontend: Workbench review interface (any reviewer)

1. Log in as any staff user (Reviewer through Owner)
2. Open a session that had RAG-assisted responses
3. Confirm the RAGDetailPanel renders below the relevant assistant messages
4. Expand the panel — verify retrieval query and document list are shown

---

## Running Tests

```bash
# chat-backend unit tests
cd /Users/malyarevich/dev/chat-backend && npm test

# workbench-frontend unit tests
cd /Users/malyarevich/dev/workbench-frontend && npm test

# chat-frontend unit tests
cd /Users/malyarevich/dev/chat-frontend && npm test
```

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `testerTagAssigned` not in `/api/auth/me` | `dbUserToAuthUser` not updated | Apply changes to `chat-backend/src/types/index.ts` |
| `ragCallDetail` missing from chat message | Chat route not calling `extractRAGDetails` | Apply changes to `chat-backend/src/routes/chat.ts` |
| RAG panel not showing in chat-frontend | `testerTagAssigned` undefined in auth store | Check `/api/auth/me` response; ensure `chat-types` is rebuilt |
| TypeScript errors on `ragCallDetail` access | `chat-types` not rebuilt after type change | `npm run build` in `chat-types`, then reinstall in dependent repos |

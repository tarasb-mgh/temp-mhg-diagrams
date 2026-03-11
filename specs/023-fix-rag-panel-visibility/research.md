# Research: Fix RAG Panel Visibility (023)

**Created**: 2026-03-11
**Branch**: `023-fix-rag-panel-visibility`
**Status**: Complete

---

## 1. RAG Data Flow (current state)

**Decision**: RAG metadata is not stored as a dedicated DB column. It is extracted at read-time from the `metadata`/`diagnosticInfo`/`generativeInfo` JSONB blob on each message row.

**Evidence** — `chat-backend/src/services/rag.service.ts`:
```typescript
export function extractRAGDetails(metadata: any): RAGCallDetail | null {
  if (metadata?.ragCallDetail) return metadata.ragCallDetail;
  const dataStoreSeq = metadata?.diagnostic_info?.data_store_execution_sequence
    ?? metadata?.diagnosticInfo?.dataStoreExecutionSequence
    ?? metadata?.data_store_execution_sequence;
  // parses snippets from dataStoreSeq ...
}
```

**Rationale**: No schema change required. All RAG data is already present in the stored metadata blobs from Dialogflow CX; it just needs to be extracted and forwarded to clients that have permission to see it.

---

## 2. Review Sessions Endpoint (current state — US1)

**Decision**: `GET /api/review/sessions/:sessionId` already calls `extractRAGDetails()` inside `anonymizeMessage()` and spreads `ragCallDetail` onto the returned message object.

**Evidence** — `chat-backend/src/routes/review.sessions.ts`:
```typescript
function anonymizeMessage(msg: any, isReviewable?: boolean): any {
  const ragCallDetail = assistantLike
    ? extractRAGDetails(msg.metadata ?? msg.diagnostic_info ?? msg.diagnosticInfo)
    : undefined;
  return {
    id, role, content, timestamp, metadata, isReviewable,
    ...(ragCallDetail ? { ragCallDetail } : {}),
  };
}
```

**Gap identified**: `AnonymizedMessage` in `chat-types/src/review.ts` does not formally declare `ragCallDetail`. The workbench frontend accesses it via `(message as any).ragCallDetail`. No runtime data loss occurs (TypeScript types don't strip properties), but the cast is a code smell and type-unsafe.

**Fix required**: Add `ragCallDetail?: RAGCallDetail` to `AnonymizedMessage` in `chat-types`.

---

## 3. Owner Permission Check (US1)

**Decision**: Owner has full permissions including `REVIEW_ACCESS`. No changes required to route guards.

**Evidence** — `chat-types/src/rbac.ts`:
```typescript
[UserRole.OWNER]: Object.values(Permission) // Full access
```

**Conclusion**: If an Owner cannot see RAG in the workbench, the issue is not permission-gating. The more likely cause is the type gap described in §2 causing a runtime `undefined` access, or the Owner testing via the *chat* interface rather than the workbench review interface.

---

## 4. `AuthenticatedUser` Missing `testerTagAssigned` (Root Cause for US2)

**Decision**: The `AuthenticatedUser` interface (returned by `GET /api/auth/me`) must be extended with `testerTagAssigned?: boolean`. Both `dbUserToAuthUser()` and the underlying DB query must forward this value.

**Evidence — type gap**:
- `chat-types/src/entities.ts` line 47: `User` interface has `testerTagAssigned?: boolean`
- `chat-types/src/entities.ts` line 63–100: `AuthenticatedUser` — **no `testerTagAssigned` field**
- `chat-backend/src/types/index.ts` `dbUserToAuthUser()` — does **not** map `tester_tag_assigned`

**DB query coverage**:
- `getUserById()` in `user.service.ts` includes the `EXISTS(... tester) AS tester_tag_assigned` subquery
- `dbUserToUser()` maps `tester_tag_assigned` → `testerTagAssigned` on the `User` object
- `getAuthUserById()` calls `getUserById()` then passes the result to `dbUserToAuthUser()`, which discards `testerTagAssigned`

**Fix required**:
1. Add `testerTagAssigned?: boolean` to `AuthenticatedUser` in `chat-types`
2. Update `dbUserToAuthUser()` to include `testerTagAssigned: (dbUser as any).tester_tag_assigned === true`

---

## 5. Chat Message Endpoint Missing RAG (Root Cause for US2)

**Decision**: `POST /api/chat/message` must include `ragCallDetail` in the assistant message payload when the requesting user has `testerTagAssigned === true`. The extraction is done via the existing `extractRAGDetails()` utility.

**Evidence**: `chat.ts` — no calls to `extractRAGDetails()` or `enrichMessagesWithRAG()` anywhere in the chat route. The response assistant message is returned as-is from the Dialogflow CX session handler; `diagnosticInfo`/`metadata` is present but never parsed for RAG.

**Approach**:
- In the `POST /api/chat/message` handler, after building the assistant message response, call `extractRAGDetails(assistantMessage.metadata ?? assistantMessage.diagnosticInfo)` if `req.user?.testerTagAssigned === true`
- Spread `ragCallDetail` onto the outgoing message only for tester-tagged users — never expose raw diagnostic info to regular users

**Alternative considered**: Add a separate `GET /api/chat/sessions/:id/messages` endpoint that enriches all messages for tester-tagged users. Rejected — complex to implement and the chat frontend streams messages in real-time via the existing chat message flow. Enriching at send-time is simpler and covers the primary use case.

---

## 6. Chat Frontend Missing RAG Panel (Root Cause for US2)

**Decision**: Add `RAGDetailPanel` rendering to `chat-frontend/src/features/chat/MessageBubble.tsx`, gated on `user.testerTagAssigned` and `(message as any).ragCallDetail`.

**Evidence**:
- `MessageBubble.tsx` currently shows `TechnicalDetails` and system prompts for `hasExtendedPermissions` roles
- `hasExtendedPermissions` already includes `owner` role but does NOT check `testerTagAssigned`
- `RAGDetailPanel` exists only in `workbench-frontend/src/features/workbench/review/components/RAGDetailPanel.tsx`

**Approach**:
- The `RAGDetailPanel` component should be extracted to `chat-frontend-common` (or duplicated to `chat-frontend`) so both surfaces can use it
- **Preferred**: duplicate the component to `chat-frontend/src/components/RAGDetailPanel.tsx` (avoids cross-repo dependency change for a bugfix; can be extracted later)
- Gate rendering: `isAssistant && user?.testerTagAssigned && (message as any).ragCallDetail`

---

## 7. Cross-Repository Impact

| Repository | Changes Required | Priority |
|---|---|---|
| `chat-types` | Add `ragCallDetail?` to `AnonymizedMessage`; add `testerTagAssigned?` to `AuthenticatedUser` | Must-do first |
| `chat-backend` | Update `dbUserToAuthUser()`; enrich chat message response with `ragCallDetail` for tester users | Blocks frontend |
| `workbench-frontend` | Remove `as any` cast in `ReviewSessionView.tsx`; no functional change needed | Polish |
| `chat-frontend` | Add `RAGDetailPanel` component; render in `MessageBubble.tsx` for tester users | US2 delivery |

---

## 8. Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| `chat-types` version mismatch across repos | Medium | Use `023-fix-rag-panel-visibility` branch in all repos; CI resolves ref dynamically |
| Exposing raw diagnostic info to non-tester users | Low | Gate strictly: `req.user?.testerTagAssigned === true` before spreading `ragCallDetail` |
| Zero-document RAG edge case crashes panel | Low | `RAGDetailPanel` already guards `!ragDetail.retrievedDocuments?.length` with a null render; update to show fallback instead |

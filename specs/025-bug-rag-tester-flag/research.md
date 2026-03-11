# Research: Bug Fix — RAG Panel Never Visible (025)

**Created**: 2026-03-11  
**Branch**: `025-bug-rag-tester-flag`  
**Status**: Complete — all unknowns resolved via Playwright + GitHub source inspection on 2026-03-11  
**Reference**: Extends `specs/023-fix-rag-panel-visibility/research.md` (§4, §5, §6)

---

## Summary

Three root-cause defects were identified through direct source inspection of the `develop` branch across `chat-types`, `chat-backend`, and `chat-frontend`. The defects are independent but cumulative — all three must be fixed for the RAG panel to appear.

---

## Defect 1: `dbUserToAuthUser()` omits `testerTagAssigned`

**Decision**: Add `testerTagAssigned: dbUser.tester_tag_assigned === true` to `dbUserToAuthUser()` return object in `chat-backend/src/types/index.ts`.

**Evidence**:
```typescript
// chat-backend/src/types/index.ts — current dbUserToAuthUser() return (simplified)
return {
  id: dbUser.id,
  email: dbUser.email,
  displayName: dbUser.display_name,
  role: dbUser.role,
  // ... other fields ...
  // testerTagAssigned is MISSING — causes req.user.testerTagAssigned === undefined
};

// chat-backend/src/types/index.ts — dbUserToUser() CORRECTLY maps it:
return {
  ...
  testerTagAssigned: dbUser.tester_tag_assigned === true,
  // ← this line exists in dbUserToUser but NOT in dbUserToAuthUser
};
```

**DB query coverage confirmed**:
- `getUserById()` in `user.service.ts`: includes `EXISTS(SELECT 1 FROM user_tags WHERE user_id = u.id AND tag = 'tester') AS tester_tag_assigned`
- `dbUserToUser()` maps `tester_tag_assigned` → `testerTagAssigned: boolean`  
- `dbUserToAuthUser()` receives the same `dbUser` argument but discards `tester_tag_assigned`

**Fix**: One line added to `dbUserToAuthUser()` return object:
```typescript
testerTagAssigned: (dbUser as any).tester_tag_assigned === true,
```

**Rationale**: `dbUser` is typed as `DbUser` which may not yet declare `tester_tag_assigned` as a formal field. Casting to `any` is acceptable here; alternatively, add `tester_tag_assigned?: boolean` to `DbUser` type to make it explicit.

**Alternatives considered**: Moving the mapping to a shared helper. Rejected — the existing pattern in the codebase is two separate mapping functions; adding one line is the minimal and consistent fix.

---

## Defect 2: `POST /api/chat/message` never attaches `ragCallDetail`

**Decision**: After building the `assistantMessage` response object, check `req.user?.testerTagAssigned === true` and, if true, call `extractRAGDetails()` on the response metadata and attach the result.

**Evidence**:
```typescript
// chat-backend/src/routes/chat.ts — current assistant message construction (simplified):
const assistantMessage: StoredMessage = {
  id: uuidv4(),
  role: 'assistant',
  content: dialogflowResponse.messages.join('\n'),
  timestamp: new Date().toISOString(),
  intent: dialogflowResponse.intentInfo,
  diagnosticInfo: dialogflowResponse.diagnosticInfo,
  // ... other fields ...
  // ragCallDetail is NEVER attached here
};
// response is sent with the raw assistantMessage — no RAG metadata for any user
```

**`extractRAGDetails()` already exists**:
```typescript
// chat-backend/src/services/rag.service.ts
export function extractRAGDetails(metadata: any): RAGCallDetail | null {
  if (metadata?.ragCallDetail) return metadata.ragCallDetail;
  const dataStoreSeq = metadata?.diagnostic_info?.data_store_execution_sequence
    ?? metadata?.diagnosticInfo?.dataStoreExecutionSequence;
  // ... parses snippets from Dialogflow CX dataStoreExecutionSequence ...
}
```

**Fix**: After building `assistantMessage`, before sending the response:
```typescript
const ragCallDetail = req.user?.testerTagAssigned === true
  ? extractRAGDetails(dialogflowResponse.diagnosticInfo ?? dialogflowResponse.metadata)
  : null;

const responseAssistantMessage = ragCallDetail
  ? { ...assistantMessage, ragCallDetail }
  : assistantMessage;
```

**Security note**: `ragCallDetail` MUST only be attached for `testerTagAssigned === true`. The raw `diagnosticInfo` must never be sent to non-tester users.

**Rationale**: Using the spread pattern (`{ ...assistantMessage, ragCallDetail }`) for the response object avoids mutating the `StoredMessage` that is also written to the DB, keeping storage clean.

---

## Defect 3: `chat-frontend` has no RAG panel component

**Decision**: Create `chat-frontend/src/components/RAGDetailPanel.tsx` by adapting the existing `workbench-frontend/src/features/workbench/review/components/RAGDetailPanel.tsx`. Gate rendering in `MessageBubble.tsx` on `user?.testerTagAssigned && message.ragCallDetail`.

**Evidence**:
```typescript
// chat-frontend/src/components/MessageBubble.tsx — current state (simplified):
export const MessageBubble = ({ message }) => {
  return (
    <div>
      <MessageContent message={message} />
      {hasExtendedPermissions && <TechnicalDetails message={message} />}
      {/* ← NO RAGDetailPanel here, no ragCallDetail branch */}
    </div>
  );
};
```

**`RAGDetailPanel` in workbench-frontend**:
- Receives `ragDetail: RAGCallDetail` prop
- Renders expandable "Sources" section with retrieval query and document list
- Handles empty `retrievedDocuments` array with a null return (needs update to show "No documents retrieved" per FR-007)

**Approach**:
- **Duplicate** to `chat-frontend` (not extract to `chat-frontend-common`) — avoids cross-repo dependency change for a bugfix; extraction can be a follow-up improvement
- Import `RAGCallDetail` type from `@mentalhelpglobal/chat-types`
- Gate in `MessageBubble.tsx`: `isAssistant && user?.testerTagAssigned && message.ragCallDetail`

**Alternatives considered**:
- Extract to `chat-frontend-common`: cleaner long-term, but requires a separate PR, version bump, and republish of `chat-frontend-common`. Too much scope for a bugfix.
- Reuse via copy-paste with light adaptation: chosen approach.

---

## auth store cache risk

**Question**: Does `authStore` in `chat-frontend` cache user data in `localStorage` without `testerTagAssigned`? Could old cached auth state prevent the flag from showing?

**Finding**: If the user logged in before Defect 1 is fixed (i.e., `testerTagAssigned` was never in the auth response), the cached auth object in `localStorage` will not have the flag. After Defect 1 is fixed, a re-login will populate it correctly. However, users who stay logged in across the deploy may need to log out and back in.

**Decision**: No code change required for this; acceptable behavior. The E2E test (FR-008) will always do a fresh login, so it will not be affected.

---

## Cross-Repository Impact Summary

| Repository | Files | Change Type | Priority |
|------------|-------|-------------|---------|
| `chat-types` | `src/entities.ts` | Add `testerTagAssigned` to `AuthenticatedUser`; add `ragCallDetail?` to `AnonymizedMessage` | P0 — blocks everything |
| `chat-backend` | `src/types/index.ts` | Add `testerTagAssigned` mapping in `dbUserToAuthUser()` | P1 — blocks chat response |
| `chat-backend` | `src/routes/chat.ts` | Attach `ragCallDetail` for tester users in `POST /api/chat/message` | P1 |
| `chat-frontend` | `src/components/RAGDetailPanel.tsx` | New component | P1 |
| `chat-frontend` | `src/components/MessageBubble.tsx` | Render `RAGDetailPanel` conditionally | P1 |
| `chat-ui` | `tests/rag-panel-visibility.spec.ts` | New Playwright E2E test | P1 (regression gate) |
| `workbench-frontend` | `src/.../ReviewSessionView.tsx` | Remove `as any` cast | P3 — polish |

---

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|-----------|
| Old cached `localStorage` auth state hides the fix | Medium | Users re-login after deploy; E2E test always does fresh login |
| `extractRAGDetails()` returns null when Dialogflow doesn't trigger RAG | Low | Return null → `ragCallDetail` absent → panel hidden — correct behavior |
| `chat-types` version mismatch after bump | Medium | Pin `@mentalhelpglobal/chat-types` version in all consumer repos before merging |
| RAG panel in `chat-frontend` duplicates workbench code | Low | Accepted tech debt; extraction to `chat-frontend-common` tracked as follow-up |
| E2E test flakiness on `dev` (e.g., Dialogflow not triggering RAG) | Medium | Use known RAG-triggering prompt; add retry; document the trigger in test |

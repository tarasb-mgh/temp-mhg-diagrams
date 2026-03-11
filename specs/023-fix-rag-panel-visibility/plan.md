# Implementation Plan: Fix RAG Panel Visibility (023)

**Branch**: `023-fix-rag-panel-visibility`
**Created**: 2026-03-11
**Status**: Ready
**Jira Bug**: [MTB-691](https://mentalhelpglobal.atlassian.net/browse/MTB-691)
**Jira Epic**: [MTB-229](https://mentalhelpglobal.atlassian.net/browse/MTB-229)

---

## Root Cause Summary

Five gaps prevent the RAG Call Details panel from being visible:

| # | Root Cause | Affected Repo |
|---|---|---|
| RC1 | `AuthenticatedUser` type lacks `testerTagAssigned` field | `chat-types` |
| RC2 | `dbUserToAuthUser()` does not forward `tester_tag_assigned` | `chat-backend` |
| RC3 | `AnonymizedMessage` type lacks formal `ragCallDetail` field | `chat-types` |
| RC4 | `POST /api/chat/message` never includes `ragCallDetail` | `chat-backend` |
| RC5 | `chat-frontend/MessageBubble.tsx` has no RAG panel rendering | `chat-frontend` |

---

## Technical Context

### Repository Layout

```
chat-types/          — shared TypeScript types (npm package)
  src/entities.ts    — User, AuthenticatedUser, ChatMessage
  src/review.ts      — AnonymizedMessage, RAGCallDetail, RAGDocument

chat-backend/
  src/services/rag.service.ts          — extractRAGDetails(), enrichMessagesWithRAG()
  src/routes/review.sessions.ts        — anonymizeMessage() already calls extractRAGDetails
  src/routes/chat.ts                   — POST /api/chat/message handler
  src/types/index.ts                   — dbUserToUser(), dbUserToAuthUser()
  src/services/user.service.ts         — getUserById() (includes tester_tag_assigned subquery)
  src/services/auth.service.ts         — getAuthUserById()

workbench-frontend/
  src/features/workbench/review/ReviewSessionView.tsx    — renders RAGDetailPanel
  src/features/workbench/review/components/RAGDetailPanel.tsx

chat-frontend/
  src/features/chat/MessageBubble.tsx  — needs RAGDetailPanel added
  src/components/TechnicalDetails.tsx
```

### Key Existing Behaviours

- `review.sessions.ts` already calls `extractRAGDetails()` → RAG data IS sent for review sessions
- `workbench-frontend` already renders `RAGDetailPanel` via `(message as any).ragCallDetail`
- `Owner` role has all permissions including `REVIEW_ACCESS` — no permission change needed
- `getUserById()` already queries `tester_tag_assigned` from DB; `dbUserToUser()` maps it to `User.testerTagAssigned`
- The gap is `dbUserToAuthUser()` (separate mapper) which does NOT include this field

---

## Constitution Check

| Principle | Assessment |
|---|---|
| **Spec-First** | ✅ Spec and research complete before implementation |
| **Multi-Repo Orchestration** | ✅ Branch `023-fix-rag-panel-visibility` used in all 4 repos |
| **Test-Aligned** | ✅ Unit tests required per phase; existing test suite must stay green |
| **Privacy & Security First** | ✅ `ragCallDetail` gated strictly: review role for workbench, testerTagAssigned for chat |
| **Accessibility** | ✅ RAGDetailPanel uses semantic HTML, expandable with ARIA attributes |
| **Jira Traceability** | ✅ Bug MTB-691 under Epic MTB-229 tracked |
| **Documentation Standards** | ✅ Contracts in OpenAPI, quickstart and data-model updated |

---

## Phase 0 — Research

**Status**: ✅ Complete — see `research.md`

All five root causes confirmed. No ambiguities remain.

---

## Phase 1 — Design

**Status**: ✅ Complete — see `data-model.md`, `contracts/rag-visibility-api.yaml`, `quickstart.md`

---

## Phase 2 — Implementation Plan

### Step 1: `chat-types` — Type Changes (blocks all other steps)

**Branch**: `023-fix-rag-panel-visibility` on `chat-types`

**File**: `src/entities.ts`
- Add `testerTagAssigned?: boolean` to `AuthenticatedUser` interface

**File**: `src/review.ts`
- Add `ragCallDetail?: RAGCallDetail` to `AnonymizedMessage` interface

**Build & publish**: `npm run build` then bump patch version (or use local file reference for branch builds).

**Tests**: No unit tests required — pure type addition. TypeScript compilation is the test.

---

### Step 2: `chat-backend` — Type Mapper & Route Changes

**Branch**: `023-fix-rag-panel-visibility` on `chat-backend`

**2a. `src/types/index.ts` — `dbUserToAuthUser()`**

Add `testerTagAssigned` to the returned object:
```typescript
return {
  // ...existing fields...
  testerTagAssigned: (dbUser as any).tester_tag_assigned === true,
};
```

Note: `dbUser` as received in `getAuthUserById` is actually a `User` object (from `getUserById`). The `User` has `testerTagAssigned` (camelCase). Update to also handle both:
```typescript
testerTagAssigned:
  (dbUser as any).tester_tag_assigned === true ||
  (dbUser as any).testerTagAssigned === true,
```

**2b. `src/routes/chat.ts` — Enrich chat message response**

After the assistant message is built in `POST /api/chat/message`, check if the authenticated user is tester-tagged and include `ragCallDetail`:

```typescript
// After building assistantMessage object
const reqUser = (req as any).user;
if (reqUser?.testerTagAssigned === true && assistantMessage) {
  const ragCallDetail = extractRAGDetails(
    assistantMessage.metadata ?? assistantMessage.diagnosticInfo
  );
  if (ragCallDetail) {
    assistantMessage = { ...assistantMessage, ragCallDetail };
  }
}
```

Import `extractRAGDetails` from `'../services/rag.service'`.

**2c. Unit tests**

- `tests/unit/auth.service.test.ts` (or new file): assert `testerTagAssigned` is present and `true` for a tester-tagged user in `getAuthUserById` output
- `tests/unit/chat.route.test.ts`: assert `ragCallDetail` present in response for tester user when RAG was triggered; absent for non-tester user

**Tests**: `npm test` must pass including existing suite.

---

### Step 3: `workbench-frontend` — Type Cleanup

**Branch**: `023-fix-rag-panel-visibility` on `workbench-frontend`

**File**: `src/features/workbench/review/ReviewSessionView.tsx`

Replace the `as any` cast with the proper typed access now that `AnonymizedMessage` formally has `ragCallDetail`:

```typescript
// Before
{(message as any).ragCallDetail && (
  <RAGDetailPanel ragDetail={(message as any).ragCallDetail as RAGCallDetail} />
)}

// After
{message.ragCallDetail && (
  <RAGDetailPanel ragDetail={message.ragCallDetail} />
)}
```

**File**: `src/features/workbench/review/components/RAGDetailPanel.tsx`

Fix the zero-document edge case: when `ragCallDetail` is present but `retrievedDocuments` is empty, show a "No retrieval data available" fallback instead of returning `null`:

```typescript
if (!ragDetail.retrievedDocuments?.length && !ragDetail.retrievalQuery) {
  return null;  // No data at all — hide
}
// If retrievedDocuments is empty but retrievalQuery exists, render fallback
```

**Tests**: `npm test` must pass.

---

### Step 4: `chat-frontend` — Add RAG Panel

**Branch**: `023-fix-rag-panel-visibility` on `chat-frontend`

**4a. New component**: `src/components/RAGDetailPanel.tsx`

Copy and adapt from `workbench-frontend/src/features/workbench/review/components/RAGDetailPanel.tsx`. The component takes a `ragDetail: RAGCallDetail` prop and renders an expandable card with:
- Retrieval query display
- List of documents with relevance scores and snippets
- "No retrieval data available" fallback for empty document list when query is present

**4b. `src/features/chat/MessageBubble.tsx`**

Add RAG panel rendering after the assistant message content, gated on tester tag:

```typescript
const isTester = user?.testerTagAssigned === true;
const ragCallDetail = isAssistant && isTester
  ? (message as any).ragCallDetail as RAGCallDetail | undefined
  : undefined;

// In JSX, after message bubble content:
{ragCallDetail && <RAGDetailPanel ragDetail={ragCallDetail} />}
```

Import `RAGCallDetail` from `@mentalhelpglobal/chat-types`.

**4c. Auth store**: Verify `useAuthStore` persists the full `AuthenticatedUser` including `testerTagAssigned`. No change expected if the store stores the object as-is from `/api/auth/me`.

**Tests**: Add unit test for `MessageBubble` rendering logic:
- Tester user + `ragCallDetail` present → panel renders
- Non-tester user + `ragCallDetail` present → panel does NOT render
- Tester user + no `ragCallDetail` → panel does NOT render

---

## Cross-Repo Dependency Order

```
chat-types (build first)
    ↓
chat-backend (imports chat-types)
    ↓
workbench-frontend (imports chat-types, calls chat-backend)
chat-frontend    (imports chat-types, calls chat-backend)
```

CI branches: all four repos must have branch `023-fix-rag-panel-visibility` checked out. The CI workflow dynamically resolves the branch ref (same pattern as implemented in `024-tester-tag-workbench` bugfix for `chat-types`).

---

## Risk Assessment

| Risk | Severity | Mitigation |
|---|---|---|
| `chat-types` build not picked up in dependent repos | Medium | Rebuild chat-types first; verify local installs resolve correctly |
| `testerTagAssigned` leaks to non-tester users | High | Code review gate; unit test for non-tester returns undefined/false |
| RAG enrichment slows chat message response | Low | `extractRAGDetails()` is pure CPU parsing (no DB/network); negligible overhead |
| `MessageBubble` type errors on `ragCallDetail` | Low | Use `(message as any).ragCallDetail` with type assertion until chat-types is rebuilt |

---

## Rollback

If a regression is detected post-deploy:
1. Revert the PR on `chat-backend` (undoing `dbUserToAuthUser` and `chat.ts` changes)
2. Revert the PR on `chat-frontend` (removes RAG panel from MessageBubble)
3. `chat-types` and `workbench-frontend` changes are non-breaking (additive type fields + cleanup)
4. Deploy from previous known-good tags

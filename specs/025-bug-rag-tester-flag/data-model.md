# Data Model: Bug Fix — RAG Panel Never Visible (025)

**Branch**: `025-bug-rag-tester-flag`  
**Date**: 2026-03-11  
**Scope**: Minimal — no new entities, no DB migrations. Only type extensions and a new frontend component.

---

## Changed Entities

### 1. `AuthenticatedUser` — `chat-types/src/entities.ts`

**Change**: Add `testerTagAssigned: boolean` field (was missing from `AuthenticatedUser`; exists on `User`).

```typescript
// BEFORE (chat-types/src/entities.ts — AuthenticatedUser)
export interface AuthenticatedUser {
  id: string;
  email: string;
  displayName: string;
  role: UserRole;
  permissions: Permission[];
  status: UserStatus;
  groupId: string | null;
  activeGroupId: string | null;
  groupRole: GroupRole | null;
  memberships: GroupMembershipSummary[];
  approvedBy: string | null;
  approvedAt: string | null;
  disapprovedAt: string | null;
  disapprovalComment: string | null;
  disapprovalCount: number;
  createdAt: string;
  lastLoginAt: string;
  // testerTagAssigned missing
}

// AFTER
export interface AuthenticatedUser {
  // ... all existing fields unchanged ...
  testerTagAssigned: boolean;   // ← ADDED: true when 'tester' tag assigned
}
```

**Notes**:
- Non-optional (`boolean`, not `boolean | undefined`) — the backend always returns `true` or `false`
- Maps to `tester_tag_assigned` column (EXISTS subquery in `getUserById()`)
- All authentication endpoints (`/api/auth/otp/verify`, `/api/auth/me`, OAuth callback) use `dbUserToAuthUser()` — fixing that function propagates the change to all endpoints

---

### 2. `AnonymizedMessage` — `chat-types/src/review.ts`

**Change**: Add formal `ragCallDetail?: RAGCallDetail` field (was previously accessed via `(message as any).ragCallDetail`).

```typescript
// BEFORE
export interface AnonymizedMessage {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  timestamp: string;
  metadata: { confidence?: number | null; intent?: string | null };
  isReviewable: boolean;
  // ragCallDetail not declared — accessed as (message as any).ragCallDetail
}

// AFTER
export interface AnonymizedMessage {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  timestamp: string;
  metadata: { confidence?: number | null; intent?: string | null };
  isReviewable: boolean;
  ragCallDetail?: RAGCallDetail;   // ← ADDED: optional; present on assistant messages with RAG
}
```

---

### 3. `RAGCallDetail` — `chat-types/src/entities.ts` (reference — no change)

Already defined. Reproduced here for reference:

```typescript
export interface RAGDocument {
  title: string;
  relevanceScore: number;        // 0.0 – 1.0
  contentSnippet: string;
}

export interface RAGCallDetail {
  retrievalQuery: string;
  retrievedDocuments: RAGDocument[];
  retrievalTimestamp: string;    // ISO 8601
}
```

---

## New Component

### 4. `RAGDetailPanel` — `chat-frontend/src/components/RAGDetailPanel.tsx`

**Change**: New component. Adapted from `workbench-frontend/src/features/workbench/review/components/RAGDetailPanel.tsx`.

```typescript
// Props
interface RAGDetailPanelProps {
  ragDetail: RAGCallDetail;
}

// Renders:
// - Collapsible "Sources" header
// - Retrieval query string
// - List of RAGDocument items: title, relevance score (%), content snippet
// - Empty state: "No documents retrieved" when retrievedDocuments.length === 0
```

**Differences from workbench version**:
- Adds explicit empty-state message per FR-007 (workbench version returns null for empty array)
- Chat-appropriate styling (lighter, collapsible panel below message bubble)

---

## Updated Component

### 5. `MessageBubble` — `chat-frontend/src/components/MessageBubble.tsx`

**Change**: Add conditional rendering of `RAGDetailPanel`.

```typescript
// New rendering gate in MessageBubble (pseudocode):
{isAssistant && user?.testerTagAssigned && message.ragCallDetail && (
  <RAGDetailPanel ragDetail={message.ragCallDetail} />
)}
```

**Gate logic**:
| Condition | Result |
|-----------|--------|
| `isAssistant === false` | Panel hidden (user messages never have RAG) |
| `user?.testerTagAssigned !== true` | Panel hidden (non-tester users) |
| `message.ragCallDetail == null` | Panel hidden (no RAG retrieval occurred) |
| All conditions met | Panel rendered |

---

## Backend Changes (not entity schema, but runtime data flow)

### 6. `dbUserToAuthUser()` — `chat-backend/src/types/index.ts`

```typescript
// Add to return object:
testerTagAssigned: (dbUser as any).tester_tag_assigned === true,
```

### 7. `POST /api/chat/message` — `chat-backend/src/routes/chat.ts`

```typescript
// After building assistantMessage, before sending response:
import { extractRAGDetails } from '../services/rag.service';

const ragCallDetail = req.user?.testerTagAssigned === true
  ? extractRAGDetails(dialogflowResponse.diagnosticInfo ?? dialogflowResponse.metadata)
  : null;

const responseAssistantMessage = ragCallDetail
  ? { ...assistantMessage, ragCallDetail }
  : assistantMessage;

// Use responseAssistantMessage in the response payload, not assistantMessage directly
```

---

## No DB Migrations Required

The `tester_tag_assigned` value is already computed by `getUserById()` via an EXISTS subquery. No schema changes, no migration files, no downtime.

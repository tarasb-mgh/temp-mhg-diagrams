# Data Model: Fix RAG Panel Visibility (023)

**Created**: 2026-03-11
**Status**: Complete

No new database tables or columns are introduced. RAG metadata is already stored inside the `metadata`/`diagnosticInfo` JSONB blobs on the `session_messages` table and extracted at read-time.

---

## Type Changes (chat-types)

### `AuthenticatedUser` — add field

**File**: `chat-types/src/entities.ts`

```typescript
export interface AuthenticatedUser {
  id: string;
  email: string;
  displayName: string;
  role: UserRole;
  permissions: Permission[];
  status: 'active' | 'blocked' | 'pending' | 'approval' | 'disapproved' | 'anonymized';
  groupId: string | null;
  activeGroupId?: string | null;
  groupRole?: GroupRole | null;
  memberships?: GroupMembershipSummary[];
  approvedBy?: string | null;
  approvedAt?: Date | null;
  disapprovedAt?: Date | null;
  disapprovalComment?: string | null;
  disapprovalCount?: number;
  createdAt: Date;
  lastLoginAt: Date;
  testerTagAssigned?: boolean;   // ← NEW: signals tester-diagnostic access in chat UI
}
```

### `AnonymizedMessage` — add field

**File**: `chat-types/src/review.ts`

```typescript
export interface AnonymizedMessage {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  timestamp: Date;
  metadata: {
    confidence?: number;
    intent?: string;
  };
  isReviewable: boolean;
  ragCallDetail?: RAGCallDetail;   // ← NEW: present when RAG retrieval occurred
}
```

---

## Existing Types (unchanged, referenced for context)

### `RAGCallDetail`

**File**: `chat-types/src/review.ts`

```typescript
export interface RAGCallDetail {
  retrievalQuery: string;
  retrievedDocuments: RAGDocument[];
  retrievalTimestamp: Date;
}
```

### `RAGDocument`

**File**: `chat-types/src/review.ts`

```typescript
export interface RAGDocument {
  title: string;
  relevanceScore: number;
  contentSnippet: string;
}
```

---

## Backend Mapping Changes (chat-backend)

### `dbUserToAuthUser` — forward testerTagAssigned

**File**: `chat-backend/src/types/index.ts`

```typescript
export function dbUserToAuthUser(dbUser: DbUser, context?: ...): AuthenticatedUser {
  return {
    // ...existing fields...
    testerTagAssigned: (dbUser as any).tester_tag_assigned === true,   // ← NEW
  };
}
```

Note: `getUserById()` already runs the `EXISTS(... tester) AS tester_tag_assigned` subquery; the value is available on the `DbUser` row passed through `getAuthUserById → getUserById → dbUserToAuthUser`.

---

## No Schema Migration Required

The `tag_definitions` and `user_tags` tables (created by migration `015_add_tagging_system.sql` and seeded by `032_seed_tester_tag_definition.sql`) already contain the `tester` tag definition. No additional migrations are needed for this bugfix.

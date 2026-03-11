# Quickstart: Bug Fix — RAG Panel Never Visible (025)

**Branch**: `025-bug-rag-tester-flag`  
**Date**: 2026-03-11  
**Environment**: Dev only — `https://dev.mentalhelp.chat` / `https://api.dev.mentalhelp.chat`

---

## Prerequisites

- Access to the MHG GitHub organization (read/write on all split repos)
- Local Node.js 20+ and npm
- An account on `dev.mentalhelp.chat` that has the `tester` tag assigned (use `e2e-owner@test.local` — Owner role with tester tag confirmed assigned via workbench)
- Playwright installed in `chat-ui` repo

---

## Repo Setup

All changes happen on the `025-bug-rag-tester-flag` branch in each repo. Create the branch from `develop` in each affected repo:

```bash
git checkout develop && git pull origin develop
git checkout -b 025-bug-rag-tester-flag
```

Do this in: `chat-types`, `chat-backend`, `chat-frontend`, `chat-ui`.  
For `workbench-frontend` (P3 polish): same pattern, optional.

---

## Step 1 — Fix `chat-types`

**File**: `chat-types/src/entities.ts`

Add `testerTagAssigned: boolean` to `AuthenticatedUser`:

```typescript
export interface AuthenticatedUser {
  // ... existing fields ...
  testerTagAssigned: boolean;   // ← add this
}
```

**File**: `chat-types/src/review.ts`

Add `ragCallDetail?: RAGCallDetail` to `AnonymizedMessage`:

```typescript
export interface AnonymizedMessage {
  // ... existing fields ...
  ragCallDetail?: RAGCallDetail;   // ← add this
}
```

**Bump version and build**:

```bash
cd chat-types
# update package.json version (patch bump, e.g. 1.2.3 → 1.2.4)
npm run build
```

> The consuming repos (`chat-backend`, `chat-frontend`, `workbench-frontend`) reference `chat-types` via the `025-bug-rag-tester-flag` branch in `package.json`, or via a local `npm link` for local development.

---

## Step 2 — Fix `chat-backend`

### 2a. `dbUserToAuthUser()` — `src/types/index.ts`

Find the return statement in `dbUserToAuthUser()` and add:

```typescript
testerTagAssigned: (dbUser as any).tester_tag_assigned === true,
```

### 2b. `POST /api/chat/message` — `src/routes/chat.ts`

Import `extractRAGDetails`:

```typescript
import { extractRAGDetails } from '../services/rag.service';
```

After building `assistantMessage`, before constructing the response:

```typescript
const ragCallDetail = req.user?.testerTagAssigned === true
  ? extractRAGDetails(dialogflowResponse.diagnosticInfo ?? dialogflowResponse.metadata)
  : null;

const responseAssistantMessage = ragCallDetail
  ? { ...assistantMessage, ragCallDetail }
  : assistantMessage;
```

Use `responseAssistantMessage` in the response payload instead of `assistantMessage`.

### Verify locally

```bash
cd chat-backend
npm install
npm run build
npm test   # Vitest unit tests must pass
```

Manual API check (after running dev server):

```bash
# Should return testerTagAssigned: true for tester-tagged user
curl -X GET http://localhost:3000/api/auth/me \
  -H "Authorization: Bearer <token>"

# Should return ragCallDetail on assistantMessage for tester user
curl -X POST http://localhost:3000/api/chat/message \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"message": "розкажи про депресію"}'
```

---

## Step 3 — Fix `chat-frontend`

### 3a. Create `RAGDetailPanel` component

Create `chat-frontend/src/components/RAGDetailPanel.tsx`.  
Adapt from `workbench-frontend/src/features/workbench/review/components/RAGDetailPanel.tsx`:

Key differences:
- Replace workbench-specific styles with chat-appropriate styles
- Handle empty `retrievedDocuments`: show `"No documents retrieved"` instead of returning `null`

```typescript
// Minimum props interface:
interface RAGDetailPanelProps {
  ragDetail: RAGCallDetail;  // from @mentalhelpglobal/chat-types
}
```

### 3b. Update `MessageBubble`

In `chat-frontend/src/components/MessageBubble.tsx`, add inside the assistant message render path:

```typescript
import { RAGDetailPanel } from './RAGDetailPanel';

// Inside MessageBubble render, after existing content:
{isAssistant && user?.testerTagAssigned && message.ragCallDetail && (
  <RAGDetailPanel ragDetail={message.ragCallDetail} />
)}
```

Where `user` comes from `authStore` (already available in `MessageBubble` context).

### Verify locally

```bash
cd chat-frontend
npm install
npm run build
npm test   # Vitest unit tests must pass
```

---

## Step 4 — E2E Test in `chat-ui`

> **Strategy (clarified 2026-03-11)**: Use `page.route()` to mock `POST /api/chat/message` with a deterministic fixture response. This ensures the test is reliable regardless of Dialogflow availability on `dev`. The test validates the frontend rendering gate (`testerTagAssigned` + `ragCallDetail` presence) — not the backend RAG extraction pipeline (covered by unit tests in Phase 4).

Create `chat-ui/tests/rag-panel-visibility.spec.ts`:

```typescript
import { test, expect } from '@playwright/test';

const DEV_URL = 'https://dev.mentalhelp.chat';
const API_CHAT_URL = '**/api/chat/message';

const RAG_FIXTURE = {
  success: true,
  data: {
    userMessage: { id: 'u1', role: 'user', content: 'test', timestamp: new Date().toISOString() },
    assistantMessage: {
      id: 'a1',
      role: 'assistant',
      content: 'Депресія — це серйозний стан...',
      timestamp: new Date().toISOString(),
      ragCallDetail: {
        retrievalQuery: 'депресія',
        retrievalTimestamp: new Date().toISOString(),
        retrievedDocuments: [
          { title: 'Про депресію', relevanceScore: 0.92, contentSnippet: 'Депресія характеризується...' },
        ],
      },
    },
  },
};

const RAG_FIXTURE_NO_RAG = {
  ...RAG_FIXTURE,
  data: {
    ...RAG_FIXTURE.data,
    assistantMessage: { ...RAG_FIXTURE.data.assistantMessage, ragCallDetail: undefined },
  },
};

test('RAG Sources panel visible for tester-tagged user', async ({ page }) => {
  // Mock chat API to return deterministic ragCallDetail
  await page.route(API_CHAT_URL, route =>
    route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(RAG_FIXTURE) })
  );

  await page.goto(DEV_URL);
  // ... OTP login as e2e-owner@test.local (tester-tagged) ...

  await page.getByPlaceholder('Написати повідомлення').fill('test');
  await page.keyboard.press('Enter');

  await expect(page.getByText('Sources')).toBeVisible({ timeout: 10000 });
  await page.getByText('Sources').click();
  await expect(page.locator('[data-testid="rag-retrieved-docs"]')).toBeVisible();
});

test('RAG Sources panel hidden for non-tester user', async ({ page }) => {
  await page.route(API_CHAT_URL, route =>
    route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(RAG_FIXTURE) })
  );

  await page.goto(DEV_URL);
  // ... OTP login as non-tester user ...

  await page.getByPlaceholder('Написати повідомлення').fill('test');
  await page.keyboard.press('Enter');

  // Even with ragCallDetail in the mocked response, non-tester user must NOT see the panel
  await expect(page.getByText('Sources')).not.toBeVisible({ timeout: 5000 });
});
```

Run:

```bash
cd chat-ui
npx playwright test rag-panel-visibility.spec.ts --headed
```

---

## Step 5 — Optional: `workbench-frontend` polish

In `workbench-frontend/src/features/workbench/review/components/ReviewSessionView.tsx` (or wherever `(message as any).ragCallDetail` is used):

Replace:
```typescript
const ragDetail = (message as any).ragCallDetail;
```

With:
```typescript
const ragDetail = message.ragCallDetail;  // now typed via AnonymizedMessage
```

---

## Dev Validation Checklist

After deploying all fixes to `dev` environment:

- [ ] Login as `e2e-owner@test.local` → `GET /api/auth/me` response includes `testerTagAssigned: true`
- [ ] Login as a non-tester user → response includes `testerTagAssigned: false`
- [ ] Send `"розкажи про депресію"` as tester user → `POST /api/chat/message` response includes `assistantMessage.ragCallDetail`
- [ ] Same message as non-tester user → `ragCallDetail` absent from response
- [ ] "Sources" panel appears below assistant message in chat UI for tester user
- [ ] "Sources" panel absent for non-tester user
- [ ] Playwright E2E test passes: `npx playwright test rag-panel-visibility.spec.ts`
- [ ] All CI checks pass on the feature branches before any PR is opened

---

## Deployment Notes

- **Dev deployment**: Open PR to `develop` in each repo → CI merges → `deploy-dev` workflow deploys to dev automatically
- **Production**: NOT until all E2E tests pass on dev AND explicit written approval received from owner (SC-007, Principle XII)
- **No DB migrations**: `tester_tag_assigned` already computed by existing EXISTS subquery
- **No `chat-types` version publish required**: branch-based reference is sufficient for the fix; a proper publish can follow as part of the next regular release

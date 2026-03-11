# Bug Report: RAG Panel Never Visible in Chat for Tester-Tagged Users

**Feature Branch**: `025-bug-rag-tester-flag`
**Created**: 2026-03-11
**Status**: Ready for Planning
**Jira Epic**: [MTB-229](https://mentalhelpglobal.atlassian.net/browse/MTB-229) *(parent — spec 023)*
**Jira Bug**: [MTB-706](https://mentalhelpglobal.atlassian.net/browse/MTB-706)
**Reference**: Spec `023-fix-rag-panel-visibility` — User Story 2 (FR-002, FR-006, SC-002, SC-003)

**Related Specs**:
- `023-fix-rag-panel-visibility` — Parent spec; this bug blocks its User Story 2 (RAG in chat for tester-tagged users) and partially User Story 3 (backend payload)
- `024-tester-tag-workbench` — Tester tag management UI (confirmed working; not the cause of this bug)

---

## Background

Spec `023-fix-rag-panel-visibility` defined a fix for the RAG Call Details Panel not appearing in the chat interface for tester-tagged users. Implementation work was undertaken across `chat-types`, `chat-backend`, and `chat-frontend`. Despite the code being merged and deployed, the RAG panel **still does not appear** in the chat interface for any user, including `Owner`-role accounts confirmed to have the `tester` tag assigned via the workbench.

End-to-end investigation (Playwright + GitHub source inspection on `develop` branch as of 2026-03-11) confirmed **three independent defects** that together fully prevent the feature from working:

### Defect 1 — `dbUserToAuthUser()` omits `testerTagAssigned`

The `dbUserToAuthUser()` utility in `chat-backend/src/types/index.ts` constructs the `AuthenticatedUser` object used by every authenticated API response (`/api/auth/otp/verify`, `/api/auth/me`, middleware `req.user`). This function does **not** include `testerTagAssigned` in its return value, even though:
- `AuthenticatedUser` in `chat-types` already declares `testerTagAssigned?: boolean`
- The sibling `dbUserToUser()` function in the same file correctly maps `tester_tag_assigned` from the database row

As a result, `req.user.testerTagAssigned` is always `undefined` in all request handlers, making any downstream gate on this flag unreachable.

### Defect 2 — Chat message endpoint never returns `ragCallDetail`

`POST /api/chat/message` in `chat-backend/src/routes/chat.ts` builds an `assistantMessage` object and returns it in the response. The current code does **not**:
- Check `req.user?.testerTagAssigned` to determine whether to include RAG metadata
- Extract RAG metadata from `dialogflowResponse.diagnosticInfo`
- Attach a `ragCallDetail` field to the outgoing assistant message payload

This means that even if Defect 1 were fixed and a tester-tagged user were correctly identified, the response payload would still never carry `ragCallDetail`.

### Defect 3 — `chat-frontend` has no RAG panel component in `MessageBubble`

The `chat-frontend/src/components/MessageBubble.tsx` file does not contain any logic or component rendering for a RAG details panel. No `RAGDetailPanel`, `Sources` expandable control, or `ragCallDetail`-conditional branch exists. Without a frontend rendering path, even a correct backend payload would have no visual output.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Auth response correctly exposes tester-tag status (Priority: P1)

When a tester-tagged user authenticates, the system returns a user object that includes `testerTagAssigned: true`. This flag persists in the session and is accessible to the chat interface for conditional rendering decisions. Without this, no tester-specific feature can function.

**Why this priority**: Defect 1 is a prerequisite for Defect 2 and 3. Every downstream fix depends on the flag being available in the authenticated user context.

**Independent Test**: Log in as a user with the tester tag assigned. Inspect the authentication response — `testerTagAssigned: true` must be present. Log in as a user without the tag — `testerTagAssigned: false` must be present (not absent).

**Acceptance Scenarios**:

1. **Given** a user with the `tester` tag assigned in the system, **When** they complete OTP or OAuth login, **Then** the authentication response includes `testerTagAssigned: true` in the user object.
2. **Given** a user without the `tester` tag, **When** they log in, **Then** the authentication response includes `testerTagAssigned: false` (field present, value false).
3. **Given** a logged-in tester-tagged user, **When** `GET /api/auth/me` is called, **Then** the response includes `testerTagAssigned: true`.
4. **Given** a logged-in non-tester user, **When** `GET /api/auth/me` is called, **Then** the response includes `testerTagAssigned: false`.

---

### User Story 2 — Chat message endpoint returns `ragCallDetail` for tester-tagged users (Priority: P1)

When a tester-tagged user sends a message that triggers RAG retrieval, the response from `POST /api/chat/message` includes `ragCallDetail` on the assistant message. For non-tester users, `ragCallDetail` is absent from the response.

**Why this priority**: Without the backend payload change, the frontend panel has no data to render. This is the data-layer fix that enables User Story 3.

**Independent Test**: As a tester-tagged user, send a RAG-triggering message. Intercept the `POST /api/chat/message` response and confirm `assistantMessage.ragCallDetail` is present and populated. Repeat as a non-tester user and confirm the field is absent.

**Acceptance Scenarios**:

1. **Given** a tester-tagged authenticated user, **When** they send a message that triggers RAG retrieval, **Then** the `POST /api/chat/message` response includes `assistantMessage.ragCallDetail` with retrieval details.
2. **Given** a non-tester authenticated user, **When** they send a message that triggers RAG retrieval, **Then** the `POST /api/chat/message` response does **not** include `ragCallDetail`.
3. **Given** a tester-tagged user, **When** their message does not trigger RAG retrieval, **Then** `ragCallDetail` is absent from the response.
4. **Given** a guest (unauthenticated) user, **When** they send a message, **Then** `ragCallDetail` is always absent.

---

### User Story 3 — RAG panel renders in chat UI for tester-tagged users (Priority: P1)

A tester-tagged user sends a message in the chat interface. For AI responses where RAG retrieval occurred, an expandable "Sources" panel appears below the message bubble. For AI responses without RAG, no panel appears. Non-tester users never see the panel.

**Why this priority**: This is the user-facing outcome the original spec 023 US2 describes. Fixing the backend without fixing the frontend still leaves the feature invisible.

**Independent Test**: As a confirmed tester-tagged user (with US1 and US2 fixed), send a RAG-triggering message in the chat interface. Verify that a "Sources" expandable control appears below the assistant response. Click to expand and confirm retrieval details are shown.

**Acceptance Scenarios**:

1. **Given** a tester-tagged user receives an AI response with `ragCallDetail` in the payload, **When** the message is rendered in the chat interface, **Then** a "Sources" expandable control appears below the message bubble.
2. **Given** a tester-tagged user receives an AI response without `ragCallDetail`, **When** the message is rendered, **Then** no "Sources" control appears.
3. **Given** a non-tester user receives any AI response, **When** the message is rendered, **Then** no "Sources" control appears regardless of payload content.
4. **Given** a tester-tagged user, **When** they expand the "Sources" panel, **Then** retrieval query, document titles, relevance scores, and content snippets are visible.
5. **Given** `ragCallDetail` present but with empty `retrievedDocuments`, **When** the panel is expanded, **Then** an explicit "No documents retrieved" message is shown rather than a blank panel.

---

### Edge Cases

- What happens when `testerTagAssigned` is missing from the auth response due to an older cached token? The system must re-fetch user state on session start and not rely solely on cached token claims.
- What happens when `ragCallDetail` is present in the payload but `retrievedDocuments` is an empty array? The Sources panel must remain visible with a clear empty state.
- What happens when the chat-frontend receives a `ragCallDetail` field it doesn't recognize the schema of? The panel should render any known fields and gracefully skip unknown ones.
- What happens when Playwright E2E tests run before these fixes are deployed to dev? Tests must be written against the fixed behavior and should fail deterministically before the fix is applied, acting as a regression guard.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The authentication service MUST include `testerTagAssigned: boolean` in every `AuthenticatedUser` response object, including OTP verify, OAuth callback, and session-me endpoints.
- **FR-002**: The value of `testerTagAssigned` MUST reflect the current state of the `tester` tag in the database at the time of authentication; `true` when the tag is assigned, `false` when not.
- **FR-003**: The chat message endpoint MUST check whether the authenticated user has `testerTagAssigned: true` and, when true, extract available RAG metadata from the AI response and include it as `ragCallDetail` on the assistant message in the API response payload.
- **FR-004**: The chat message endpoint MUST NOT include `ragCallDetail` in the response for users without `testerTagAssigned: true` (non-tester users and unauthenticated users).
- **FR-005**: The chat interface MUST render an expandable "Sources" control below any assistant message bubble that includes `ragCallDetail` in its data, visible only when the current user has `testerTagAssigned: true`.
- **FR-006**: The "Sources" control MUST expand to show: the retrieval query used, a list of retrieved documents each with title/identifier, relevance score, and content snippet.
- **FR-007**: When `ragCallDetail` is present but `retrievedDocuments` is empty, the expanded panel MUST show an explicit "No documents retrieved" message.
- **FR-008**: A Playwright E2E test MUST be written that verifies the end-to-end flow: login as tester-tagged user → send RAG-triggering message → confirm "Sources" panel visible → expand panel → confirm content present.
- **FR-009**: The fix MUST be verified on `dev` environment before any release branch is cut. No production deployment MUST occur without explicit approval.

### Key Entities

- **`AuthenticatedUser`** (chat-types) — already has `testerTagAssigned?: boolean`; must be populated by `dbUserToAuthUser()`
- **`ragCallDetail`** on `StoredMessage` — must be extracted from Dialogflow `diagnosticInfo` and included in the chat message response
- **Playwright E2E test** — new test in `chat-ui` that validates the full tester-tag RAG visibility flow

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: After login as a tester-tagged user, the authenticated user object contains `testerTagAssigned: true` in 100% of authentication responses (OTP verify, OAuth, session-me).
- **SC-002**: After login as a non-tester user, `testerTagAssigned: false` is present (not absent) in 100% of authentication responses.
- **SC-003**: For a tester-tagged user sending a RAG-triggering message, `ragCallDetail` is present in 100% of `POST /api/chat/message` responses where RAG retrieval occurred.
- **SC-004**: For a non-tester user, `ragCallDetail` is absent in 100% of `POST /api/chat/message` responses.
- **SC-005**: The "Sources" expandable control appears on 100% of tester-tagged user assistant message bubbles that have `ragCallDetail` populated.
- **SC-006**: The Playwright E2E test passes on `dev` environment before any release is cut and serves as a regression gate for future deployments.
- **SC-007**: Zero production deployments occur during this bugfix without explicit written approval. All validation occurs on `dev` only.

---

## Out of Scope

- Changes to how the tester tag is assigned or managed (covered by spec 024)
- RAG panel in the workbench/review interface (separate user story in spec 023)
- Changes to the Dialogflow integration or RAG metadata capture pipeline
- Any changes to production environment without explicit approval

# Feature Specification: Fix RAG Call Details Panel Visibility

**Feature Branch**: `023-fix-rag-panel-visibility`
**Created**: 2026-03-09
**Status**: Ready for Planning
**Jira Epic**: [MTB-229](https://mentalhelpglobal.atlassian.net/browse/MTB-229)
**Jira Bug**: [MTB-691](https://mentalhelpglobal.atlassian.net/browse/MTB-691)
**Reference**: Spec 011-chat-review-supervision, User Story 6, FR-015/FR-015a/FR-016

**Related Specs**:
- `011-chat-review-supervision` — Original specification defining RAG Call Details (User Story 6, FR-015/FR-015a/FR-016, tasks T052–T060)
- `002-chat-moderation-review` — Base chat moderation and review system
- `003-chat-moderation-review` — Split-repo implementation of the review system
- `024-tester-tag-workbench` — Dedicated workbench UI for managing the `tester` tag

---

## Background

Spec `011-chat-review-supervision` introduced a RAG Call Details panel (US6) to display retrieved documents, relevance scores, and retrieval queries for AI-generated responses. The panel was intended to be:
- Visible **in the review/workbench interface** for all staff reviewers and above (Reviewer through Owner)
- Visible **in the chat interface** exclusively for users with the `tester` tag assigned

Currently the panel does not render for users with the **Owner** role (or any role), despite the backend already extracting RAG metadata from stored message payloads. The root causes are:
1. `AuthenticatedUser` type does not carry `testerTagAssigned`, so the chat frontend cannot gate RAG visibility on it
2. `dbUserToAuthUser()` does not forward the `tester_tag_assigned` DB flag into the session token/user object
3. `AnonymizedMessage` type formally lacks `ragCallDetail`, causing type-cast workarounds in the workbench frontend
4. The `POST /api/chat/message` response payload never includes `ragCallDetail`, even for tester-tagged users
5. `chat-frontend/MessageBubble.tsx` has no RAG panel rendering at all

---

## Clarifications

**Q1**: Does Owner see RAG in the chat interface or only in the review/workbench interface?
**A1**: Both. In the review/workbench interface all staff roles (Reviewer through Owner) see RAG details on reviewed sessions. In the chat interface, only tester-tagged users (including Owners who have the tester tag) see RAG details on their own live messages.

**Q2**: Is `tester` tag a role-based check or a user-level tag?
**A2**: User-level tag. A user with role `owner` does NOT automatically see RAG in chat unless they have been explicitly assigned the `tester` tag by an Admin/Supervisor/Owner. Role alone is not sufficient.

**Q3**: What does the panel show when RAG retrieval occurred but returned zero documents?
**A3**: Show the `Sources` control and indicate that retrieval ran but returned no documents (not hide the panel entirely).

**Q4**: What does the panel show when the message was not processed by RAG at all?
**A4**: Panel is hidden completely. No fallback, no empty state.

**Q5**: Is the tester-tag management UI in scope for this bugfix?
**A5**: No. The tag management UI is delivered by feature `024-tester-tag-workbench`. This spec covers only RAG panel visibility.

**Q6**: Where is the `AuthenticatedUser` returned by `/api/auth/me` stored/consumed in frontends?
**A6**: Both `chat-frontend` and `workbench-frontend` consume it via `useAuthStore`. The `testerTagAssigned` flag must be present on `AuthenticatedUser` so the store can expose it to components.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 — RAG Details in Review Interface (Priority: P1)

A workbench reviewer, supervisor, or owner opens a past chat session in the review interface. For any assistant message where the AI used RAG retrieval, the RAG Call Details panel is visible and expandable, showing the retrieval query, retrieved documents with relevance scores, and content snippets. The panel is collapsed by default. If the AI response did not use RAG, no "Sources" control appears.

**Why this priority**: The review interface is the primary workspace for quality assurance. Reviewers and supervisors cannot assess whether the AI retrieved appropriate sources without this panel. Clinical safety reviews depend on source transparency. This directly blocks the QA workflow.

**Independent Test**: Log in as an owner (or reviewer/supervisor), open a session containing at least one AI response that used RAG retrieval, and verify the "Sources" control appears on that message and expands to show retrieval details.

**Acceptance Scenarios**:

1. **Given** a session where the AI used RAG retrieval, **When** a user with role ≥ Reviewer opens that session in the workbench review view, **Then** the RAGDetailPanel is visible on the assistant message.
2. **Given** a session where the AI did NOT use RAG, **When** any reviewer opens that session, **Then** no RAGDetailPanel appears (no panel, no placeholder).
3. **Given** RAG retrieval occurred but returned zero documents, **When** a reviewer opens the session, **Then** the RAGDetailPanel shows with an explicit empty-result message inside.
4. **Given** an Owner role user, **When** they open a reviewed session in the workbench, **Then** they see RAG details (Owner has full permissions including `REVIEW_ACCESS`).
5. **Given** an AI response is known to have used RAG but the retrieval metadata was not logged by the AI service, **When** the response is displayed, **Then** the "Sources" control still appears and the expanded panel displays "No retrieval data available."
6. **Given** a RAG response with multiple retrieved documents, **When** the details panel is expanded, **Then** each document shows its title/identifier, a relevance score, and a content snippet.

---

### User Story 2 — RAG Details in Chat Interface for Tester-Tagged Users (Priority: P1)

A tester-tagged user (any role including Owner) is chatting in the chat interface. After each AI response that used RAG, the RAGDetailPanel is visible inline below the message bubble. Regular (non-tester) users never see RAG controls or panels in the chat interface, regardless of their role. Management of the `tester` tag itself is outside the scope of this bugfix.

**Why this priority**: Tester-tagged users (including owners performing QA) rely on in-chat RAG visibility to validate retrieval behavior in real time without switching to the review interface. This is equally critical alongside US1 because it is part of the same broken feature surface.

**Independent Test**: Log in as a tester-tagged user (e.g., an owner with the tester tag), send a message that triggers RAG retrieval, and verify the "Sources" control appears on the AI response in the chat interface. Then log in as a non-tester user and verify no RAG controls appear.

**Acceptance Scenarios**:

1. **Given** a user WITH the tester tag, **When** they receive an AI response that used RAG, **Then** the RAGDetailPanel is visible below the assistant message in the chat interface.
2. **Given** a user WITHOUT the tester tag, **When** they receive an AI response that used RAG, **Then** no RAGDetailPanel appears.
3. **Given** a tester-tagged user, **When** they receive an AI response NOT using RAG, **Then** no RAGDetailPanel appears.
4. **Given** the `GET /api/auth/me` response, **When** a tester-tagged user is logged in, **Then** the response includes `testerTagAssigned: true`.
5. **Given** a tester-tagged Owner who can access both the chat and review interfaces, **When** they view the same RAG-enabled AI response in both interfaces, **Then** RAG details are available in both.

---

### User Story 3 — Backend Includes RAG Metadata in Message Payloads (Priority: P1)

Message response payloads on both the review endpoint and the chat message endpoint include `ragCallDetail` when RAG retrieval occurred, gated by appropriate authorization. For non-tester users in the chat context, the field is absent.

**Why this priority**: Without backend data, the frontend panels have nothing to display. If the data layer does not return RAG metadata, the UI fix alone is insufficient. This is a prerequisite for both US1 and US2.

**Independent Test**: Call the session messages endpoint as a reviewer/owner and verify RAG metadata is present on RAG-enabled AI responses. Call the chat messages endpoint as a tester-tagged user and verify the same. Call as a non-tester and verify RAG metadata is absent.

**Acceptance Scenarios**:

1. **Given** a review session with RAG messages, **When** `GET /api/review/sessions/:id` is called by an authorized reviewer, **Then** messages with RAG include `ragCallDetail` in the response.
2. **Given** a tester-tagged user sends a message that triggers RAG, **When** `POST /api/chat/message` returns, **Then** the assistant message in the response includes `ragCallDetail`.
3. **Given** a non-tester user sends a message that triggers RAG, **When** `POST /api/chat/message` returns, **Then** the assistant message does NOT include `ragCallDetail`.
4. **Given** `GET /api/auth/me` for a tester-tagged user, **When** the response is returned, **Then** `data.testerTagAssigned` is `true`.

---

### Edge Cases

- What happens when the Owner role is not explicitly listed in the permission check for RAG visibility? The system must treat Owner as having all permissions through role hierarchy inheritance — Owner inherits all permissions below.
- What happens when a tester tag is added to a user mid-session? The tag takes effect on the next message fetch — previously loaded messages may need a page refresh to show RAG details.
- What happens when a message is known to be RAG-based but its detailed retrieval metadata is missing? The "Sources" control still appears, and opening it shows "No retrieval data available."
- What happens when retrieval ran but returned zero documents? The "Sources" control still appears, and opening it indicates that retrieval ran but no documents were found.
- What happens when the RAG metadata schema from the AI service changes or includes unexpected fields? The system should gracefully render known fields and ignore unrecognized fields without crashing or hiding the entire panel.
- What happens when the RAG panel component exists in code but is never rendered due to a conditional rendering bug? The fix must verify that the conditional logic checking for RAG data presence and user permissions correctly evaluates to true for eligible users and messages.
- What happens when the session contains a mix of RAG and non-RAG messages? Each message is evaluated independently — RAG panels appear only on messages that have retrieval metadata.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST include RAG retrieval metadata (retrieval query, retrieved documents with titles, relevance scores, content snippets, and retrieval timestamp) in the message response payload for all AI messages that involved RAG retrieval, when serving data through the review endpoint to any user with review permissions (Reviewer, Senior Reviewer, Supervisor, Moderator, Commander, Admin, Owner).
- **FR-002**: System MUST include RAG retrieval metadata in the message response payload when serving data through the chat endpoint to users who have a "tester" tag, regardless of their role.
- **FR-003**: System MUST NOT include RAG retrieval metadata in the chat endpoint response for users without a "tester" tag.
- **FR-004**: System MUST NOT include RAG retrieval metadata on AI messages that did not involve a RAG retrieval call, regardless of endpoint or user permissions.
- **FR-005**: System MUST render an expandable "Sources" control on each AI response message in the review/workbench interface when RAG retrieval metadata is present in the message data.
- **FR-006**: System MUST render an expandable "Sources" control on each AI response message in the chat interface when RAG retrieval metadata is present in the message data (only populated for tester-tagged users per FR-002).
- **FR-007**: System MUST display "No retrieval data available" inside the expanded panel when an AI message is known to be RAG-based but the retrieval metadata is empty or missing.
- **FR-008**: System MUST hide the RAG panel and "Sources" control entirely on AI messages that did not involve a RAG retrieval call at all (non-RAG responses like greetings or clarifications).
- **FR-008a**: System MUST keep the "Sources" control visible when a RAG retrieval call ran but returned zero documents, and the expanded panel MUST indicate that no documents were found.
- **FR-009**: System MUST ensure the Owner role has RAG visibility in the review interface through the existing role hierarchy permission inheritance — no special-case logic for Owner should be needed if the permission check correctly includes all roles at or above Reviewer level.
- **FR-010**: The expanded RAG details panel MUST show each retrieved document with its title/identifier, a relevance score, and a content snippet, plus the retrieval query used.

### Key Entities

- **`AuthenticatedUser`** (chat-types) — needs `testerTagAssigned?: boolean` field
- **`AnonymizedMessage`** (chat-types) — needs formal `ragCallDetail?: RAGCallDetail` field
- **`RAGCallDetail`** (chat-types) — already defined; includes `retrievalQuery`, `retrievedDocuments`, `retrievalTimestamp`
- **`RAGDocument`** (chat-types) — already defined; includes `title`, `relevanceScore`, `contentSnippet`
- **Tester Tag**: A user-level tag applied to internal staff or dedicated test accounts granting visibility of diagnostic information (including RAG details) in the chat interface. Not self-service for regular end users.

### Assumptions

- The AI service already logs RAG retrieval metadata as part of the response generation pipeline, and this metadata is stored and accessible through existing message metadata storage. The bug is in retrieving, serving, or rendering this data — not in its original capture.
- The role hierarchy is: Reviewer < Senior Reviewer < Supervisor < Moderator < Commander < Admin < Owner. Any permission granted to Reviewer is inherited by all higher roles.
- The `tester` tag is part of the existing tagging system (spec 010) and can be checked on the authenticated user during message endpoint requests.
- The `Owner` role does not bypass the chat-interface `tester` tag gate; `Owner` sees RAG details in chat only when explicitly tagged as a tester.
- A user who has the `tester` tag can see chat-interface RAG details in all eligible sessions they can access; the tag is not scoped per group or per session.
- The mechanism for assigning or removing the `tester` tag exists outside the scope of this bugfix and is delivered by `024-tester-tag-workbench`.
- The RAG detail data model (`RAGCallDetail`) and types are already defined in chat-types as part of the 011 spec implementation.
- The original tasks T052–T060 from spec 011 define the intended implementation paths for this feature. This bugfix may involve completing, correcting, or unblocking work described in those tasks.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of AI responses that involved RAG retrieval display an expandable "Sources" panel in the review interface for all users with Reviewer role or above.
- **SC-002**: 100% of AI responses that involved RAG retrieval display an expandable "Sources" panel in the chat interface for all tester-tagged users.
- **SC-003**: 0% of AI responses are shown with a RAG panel for non-tester users in the chat interface.
- **SC-004**: 0% of non-RAG AI responses (greetings, clarifications) show a RAG panel in any interface.
- **SC-005**: RAG details panels load and expand within 1 second of user interaction in both the review and chat interfaces.
- **SC-006**: The Owner role can see RAG details in the review interface without any additional configuration, tag assignment, or workaround.
- **SC-007**: When RAG metadata is absent on a RAG-flagged message, the panel displays the "No retrieval data available" fallback message instead of showing an empty or broken state.
- **SC-008**: When retrieval runs but returns zero documents, 100% of eligible users see the "Sources" control and an explicit empty-result message rather than a hidden panel or broken state.

---

## Out of Scope

- Tester tag assignment/management UI (delivered by `024-tester-tag-workbench`)
- Changes to how RAG data is stored in the database
- Changes to the Dialogflow CX integration or metadata schema
- Admin session conversation endpoint (`GET /api/admin/sessions/:id/conversation`)

# Feature Specification: Fix RAG Call Details Panel Visibility

**Feature Branch**: `023-fix-rag-panel-visibility`  
**Created**: 2026-03-11  
**Status**: Draft  
**Jira Bug**: MTB-691  
**Jira Epic**: MTB-229 (011-chat-review-supervision)  
**Input**: User description: "Fix: RAG Call Details panel is not visible in Chat and Review UI for users with Owner role (and potentially other elevated roles). The RAG panel was specified in spec 011-chat-review-supervision (User Story 6, FR-015/FR-015a/FR-016) to display retrieved documents, relevance scores, and retrieval queries on AI responses — expandable in the review/workbench interface for all reviewers and supervisors, and in the chat interface for tester-tagged users. Currently the panel does not appear at all."

**Related Specs**:
- `011-chat-review-supervision` — Original specification defining RAG Call Details (User Story 6, FR-015/FR-015a/FR-016, tasks T052–T060)
- `002-chat-moderation-review` — Base chat moderation and review system
- `003-chat-moderation-review` — Split-repo implementation of the review system
- `024-tester-tag-workbench` — Dedicated workbench UI for managing the `tester` tag

## Clarifications

### Session 2026-03-11

- Q: Should Owner see RAG details in chat only when tagged as tester, or always by role? → A: In chat, only users with the `tester` tag can see RAG details, including `Owner`.
- Q: Is the tester tag user-level, group-specific, or session-specific? → A: `tester` is a user-level tag; if a user has it, they can see chat RAG details in all eligible sessions they access.
- Q: What should happen when a message is known to be RAG-based but detailed retrieval metadata is missing? → A: Show the `Sources` control and display `No retrieval data available` inside the panel.
- Q: Who may receive the `tester` tag? → A: Only internal staff or dedicated test accounts may receive the `tester` tag.
- Q: What should happen when retrieval ran but returned zero documents? → A: Show the `Sources` control and indicate that retrieval ran but returned no documents.
- Q: Should tester-tag management remain part of this bugfix spec? → A: No. Tester-tag management UI is out of scope for this bugfix and should remain only as a dependency.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - RAG Details Visible in Review Interface for Elevated Roles (Priority: P1)

A reviewer, supervisor, moderator, or owner opens a completed chat session in the review/workbench interface. For each AI response that involved a RAG retrieval call, an expandable "Sources" control appears on the message. Clicking or tapping the control reveals a panel showing the retrieval query, a list of retrieved documents with their titles, relevance scores, and content snippets, and the retrieval timestamp. The panel is collapsed by default. If the AI response did not use RAG (e.g., a greeting or clarification), no "Sources" control appears. If the AI service did not log retrieval metadata for a RAG-enabled response, the panel shows "No retrieval data available." If retrieval ran but returned zero documents, the panel shows that retrieval ran but no documents were found.

**Why this priority**: The review interface is the primary workspace for quality assurance. Reviewers and supervisors cannot assess whether the AI retrieved appropriate sources without this panel. Clinical safety reviews depend on source transparency. This directly blocks the QA workflow.

**Independent Test**: Can be fully tested by logging in as an owner (or reviewer/supervisor), opening a session containing at least one AI response that used RAG retrieval, and verifying the "Sources" control appears on that message and expands to show retrieval details.

**Acceptance Scenarios**:

1. **Given** a user with the Reviewer role opens a chat session in the review interface, **When** an AI response in that session used RAG retrieval, **Then** a "Sources" or "Info" control is visible on the AI message, and expanding it shows the retrieval query, retrieved documents with titles, relevance scores, and content snippets.
2. **Given** a user with the Supervisor role opens the same session, **When** they view the same AI response, **Then** the same RAG details panel is available and functional.
3. **Given** a user with the Owner role opens the same session, **When** they view the same AI response, **Then** the same RAG details panel is available and functional.
4. **Given** any reviewer-or-above user views an AI response that did not involve RAG retrieval, **When** the response is displayed, **Then** no "Sources" control or RAG panel appears on that message.
5. **Given** an AI response is known to have used RAG but the retrieval metadata was not logged by the AI service, **When** the response is displayed, **Then** the "Sources" control still appears and the expanded panel displays "No retrieval data available."
6. **Given** a RAG response with multiple retrieved documents, **When** the details panel is expanded, **Then** each document shows its title/identifier, a relevance score, and a content snippet.
7. **Given** an AI response is known to have used RAG and retrieval ran but returned zero documents, **When** the panel is expanded, **Then** the "Sources" control still appears and the panel indicates that no documents were found.

---

### User Story 2 - RAG Details Visible in Chat Interface for Tester-Tagged Users (Priority: P1)

A user who has been tagged as a "tester" views their own chat session in the end-user chat interface. For each AI response that involved a RAG retrieval call, the same expandable "Sources" control appears. Tester-tagged users with any role — including Owner — can see RAG details in chat. Regular (non-tester) users never see RAG controls or panels in the chat interface, regardless of their role. Management of the `tester` tag itself is outside the scope of this bugfix and is treated as a dependency.

**Why this priority**: Tester-tagged users (including owners performing QA) rely on in-chat RAG visibility to validate retrieval behavior in real time without switching to the review interface. This is equally critical alongside US1 because it is part of the same broken feature surface.

**Independent Test**: Can be fully tested by logging in as a tester-tagged user (e.g., an owner with the tester tag), sending a message that triggers RAG retrieval, and verifying the "Sources" control appears on the AI response in the chat interface. Then log in as a non-tester user and verify no RAG controls appear.

**Acceptance Scenarios**:

1. **Given** a tester-tagged user (any role, including Owner) viewing an AI response in the chat interface, **When** that response involved RAG retrieval, **Then** a "Sources" or "Info" control is visible on the AI message, and expanding it shows retrieval query, retrieved documents, relevance scores, and snippets.
2. **Given** a regular (non-tester) user viewing the same AI response in the chat interface, **When** the response is displayed, **Then** no RAG details control or panel is shown.
3. **Given** a tester-tagged user viewing an AI response that did not use RAG, **When** the response is displayed, **Then** no RAG details control or panel appears.
4. **Given** a tester-tagged Owner who can access both the chat and review interfaces, **When** they view the same RAG-enabled AI response in both interfaces, **Then** RAG details are available in both.

---

### User Story 3 - Backend Includes RAG Metadata in Message Payloads (Priority: P1)

When the system serves chat session messages through its data endpoints, RAG retrieval metadata is included in the response payload for AI messages that involved RAG. In the review context, RAG metadata is always included for all authenticated users with review permissions. In the chat context, RAG metadata is included only when the authenticated user has a tester tag. For AI messages that did not involve RAG, or when the user lacks the appropriate permission/tag, the RAG metadata field is absent or null.

**Why this priority**: Without backend data, the frontend panels have nothing to display. If the data layer does not return RAG metadata, the UI fix alone is insufficient. This is a prerequisite for both US1 and US2.

**Independent Test**: Can be tested by calling the session messages endpoint directly (using a tool or browser network inspector) as a reviewer/owner and verifying RAG metadata is present on RAG-enabled AI responses. Then calling the chat messages endpoint as a tester-tagged user and verifying the same. Finally, calling as a non-tester and verifying RAG metadata is absent.

**Acceptance Scenarios**:

1. **Given** an authenticated user with review permissions requests session messages from the review endpoint, **When** an AI message in the session used RAG retrieval, **Then** the response payload for that message includes retrieval metadata (query, documents, scores).
2. **Given** an authenticated tester-tagged user requests session messages from the chat endpoint, **When** an AI message used RAG retrieval, **Then** the response payload includes retrieval metadata.
3. **Given** a non-tester user requests session messages from the chat endpoint, **When** an AI message used RAG retrieval, **Then** the response payload does not include retrieval metadata.
4. **Given** any user requests messages where the AI response did not involve RAG, **When** the response is returned, **Then** no retrieval metadata is included for that message.

---

### Edge Cases

- What happens when the Owner role is not explicitly listed in the permission check for RAG visibility? The system must treat Owner as having all permissions, including RAG detail visibility, by inheritance from the role hierarchy (Owner inherits all permissions below).
- What happens when a tester tag is added to a user mid-session? The tester tag should take effect on the next message fetch — previously loaded messages may need a page refresh to show RAG details.
- What happens when a message is known to be RAG-based but its detailed retrieval metadata is missing? The "Sources" control still appears, and opening it shows "No retrieval data available."
- What happens when retrieval ran but returned zero documents? The "Sources" control still appears, and opening it indicates that retrieval ran but no documents were found.
- What happens when the RAG metadata schema from the AI service changes or includes unexpected fields? The system should gracefully render known fields and ignore unrecognized fields without crashing or hiding the entire panel.
- What happens when the RAG panel component exists in code but is never rendered due to a conditional rendering bug? The fix must verify that the conditional logic checking for RAG data presence and user permissions correctly evaluates to true for eligible users and messages.
- What happens when the session contains a mix of RAG and non-RAG messages? Each message is evaluated independently — RAG panels appear only on messages that have retrieval metadata.

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

- **RAG Call Detail**: Metadata from a retrieval-augmented generation call associated with an AI response. Key attributes: retrieval query, list of retrieved documents (each with title/identifier, relevance score, content snippet), retrieval timestamp. Already defined in spec 011 data model.
- **Tester Tag**: A tag applied to a user account indicating they should see technical diagnostic information (including RAG details) in the chat interface. Defined in the tagging system (spec 010).
  The tag is user-level rather than group-specific or session-specific.
  Only internal staff or dedicated test accounts may receive this tag.

### Assumptions

- The AI service (chatbot backend) already logs RAG retrieval metadata as part of the AI response generation pipeline, and this metadata is stored and accessible through the existing message metadata storage. The bug is in retrieving, serving, or rendering this data — not in its original capture.
- The role hierarchy is: Reviewer < Senior Reviewer < Supervisor < Moderator < Commander < Admin < Owner. Any permission granted to Reviewer is inherited by all higher roles.
- The "tester" tag is part of the existing tagging system (spec 010) and can be checked on the authenticated user during message endpoint requests.
- The `Owner` role does not bypass the chat-interface `tester` tag gate; `Owner` sees RAG details in chat only when explicitly tagged as a tester.
- A user who has the `tester` tag can see chat-interface RAG details in all eligible sessions they can access; the tag is not scoped per group or per session.
- The `tester` tag is reserved for internal staff or dedicated test accounts and is not self-service for regular end users.
- The mechanism for assigning or removing the `tester` tag exists outside the scope of this bugfix and may be delivered by separate feature work.
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

# Feature Specification: Release Batch Documentation — v2026.03.11

**Feature Branch**: `026-release-batch-docs`
**Created**: 2026-03-11
**Status**: Draft
**Input**: User description: "update the spec with the recent changes in all the repositories"

## Overview

This specification documents the features and improvements shipped in the coordinated
`v2026.03.11` release batch across `chat-backend`, `chat-frontend`, and `workbench-frontend`.
The batch covers four functional areas:

1. **Chat session resilience** — users can resume interrupted conversations
2. **RAG transparency for testers** — tester-tagged users can inspect AI knowledge retrieval
3. **Survey gate integration** — users complete intake surveys before accessing chat
4. **Survey schema editor enhancements** — admins author complex surveys with advanced logic

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Chat Session Resilience (Priority: P1)

A returning user closes or refreshes their browser tab mid-conversation. When they reopen
the chat, their conversation history is still there and they can continue from where they
left off — no need to re-introduce themselves or repeat context.

Additionally, if a user loses internet connectivity while typing, their message is queued
and sent automatically once the connection is restored, with a clear offline indicator
shown during the outage.

**Why this priority**: Session loss is a trust-damaging experience in a mental health context.
Users who are mid-disclosure lose important continuity; requiring them to start over
reduces engagement and willingness to re-open. This is the highest-impact UX improvement
in this batch.

**Independent Test**: Log in → send messages → hard-reload the tab. Conversation history
reappears and input works immediately. Disable network → type and send a message →
amber banner appears and message stays pending → re-enable network → message sends
automatically and banner disappears.

**Acceptance Scenarios**:

1. **Given** an authenticated user with an active session, **When** they reload the page,
   **Then** the previous conversation is restored and they can continue chatting without
   starting a new session.

2. **Given** an authenticated user who explicitly ended their session, **When** they reload
   the page, **Then** a fresh empty session starts (no previous conversation shown).

3. **Given** a user who loses network connectivity, **When** they send a message,
   **Then** an amber offline banner appears and the message is marked as pending (not failed).

4. **Given** a user whose network has been restored, **When** reconnection is detected,
   **Then** all pending messages are sent automatically and the offline banner disappears.

5. **Given** a guest (unauthenticated) user, **When** they reload the page,
   **Then** a new session always starts (no resume — guests have no persistent identity).

---

### User Story 2 — RAG Transparency for Tester-Tagged Users (Priority: P2)

A user with the tester tag enabled can see, after each AI response, a collapsible panel
that shows which knowledge base documents were retrieved to generate that response. This
helps testers evaluate the quality of the AI's knowledge retrieval and report grounding issues.

**Why this priority**: Essential for the quality feedback loop. Testers need visibility into
why the AI says what it says to meaningfully flag incorrect or irrelevant responses.

**Independent Test**: Log in with a tester-tagged account → send a message → verify a
RAG detail panel appears below the assistant response showing retrieved document excerpts.
Log in with a non-tester account → no panel visible.

**Acceptance Scenarios**:

1. **Given** a tester-tagged authenticated user, **When** the assistant responds,
   **Then** a collapsible RAG detail panel appears beneath the response showing
   the documents and passages retrieved during response generation.

2. **Given** a non-tester-tagged user, **When** the assistant responds,
   **Then** no RAG detail panel is shown (feature is fully hidden).

3. **Given** a response where no documents were retrieved (zero-doc case),
   **When** the tester views the RAG panel, **Then** a clear empty state is shown
   ("No documents retrieved") rather than a blank or broken panel.

---

### User Story 3 — Survey Gate Before Chat Access (Priority: P2)

New users (or users in a group configured with a gate survey) must complete a short intake
survey before the chat interface becomes available. Once submitted, the survey is not
shown again for that user. The survey supports multiple question types and shows progress
as the user advances through questions.

**Why this priority**: Required for several research groups to gather baseline data before
therapy interactions. Without this, groups cannot use the platform for structured studies.

**Independent Test**: Assign a gate survey to a group → log in as a member of that group →
verify survey screens appear before chat → complete the survey → verify chat interface
loads immediately after submission → reload the page → verify survey does not appear again.

**Acceptance Scenarios**:

1. **Given** a user in a group with a gate survey configured, **When** they navigate to
   chat, **Then** the survey is displayed before the chat interface.

2. **Given** a user completing the gate survey, **When** they reach the final step,
   **Then** they can review their answers before submitting.

3. **Given** a user who has already completed the gate survey, **When** they return to
   chat (including after reload or new session), **Then** the survey is not shown again.

4. **Given** a user without a gate survey configured, **When** they navigate to chat,
   **Then** the chat interface loads directly with no survey step.

---

### User Story 4 — Survey Schema Editor Enhancements (Priority: P3)

An administrator building a survey schema can write multi-line markdown instructions for
each question group, define complex visibility conditions (including NOT_IN operators and
multiple simultaneous conditions), add freetext options to choice questions, and preview
the survey as it will appear to respondents — all from the workbench editor.

Changes auto-save as the admin works, and the schema can be exported and imported as JSON
for backup or sharing across environments.

**Why this priority**: Enables richer, more clinically meaningful surveys. The previous
editor could only support simple single-condition visibility and no markdown formatting,
limiting what research teams could design.

**Independent Test**: Open Survey Schemas → create a schema with markdown instructions,
two visibility conditions on one question, a choice question with a freetext option →
save → open Preview → verify the survey renders as designed → export JSON → import it
in a new schema slot → verify all settings are preserved.

**Acceptance Scenarios**:

1. **Given** an admin editing a survey schema, **When** they type markdown in the
   instructions field, **Then** the preview renders formatted text (bold, lists, links).

2. **Given** an admin adding visibility conditions, **When** they add multiple conditions
   to a single question, **Then** all conditions are evaluated and the question only
   appears when all conditions are met.

3. **Given** a choice question, **When** the admin enables a freetext option,
   **Then** respondents who select that choice see a text input for their own answer.

4. **Given** an admin who has been editing a schema, **When** they navigate away,
   **Then** their changes are auto-saved without requiring an explicit save action.

5. **Given** an admin who exports a schema to JSON, **When** they import that JSON
   into a new schema, **Then** all questions, conditions, and settings are fully restored.

---

### Edge Cases

- What happens if a session stored in localStorage has expired (>30 min of inactivity)?
  The resume attempt gets a non-active status from the server → fall through to new session.
- What happens if the backend is unreachable during a session resume attempt?
  Network error during resume → fall through to new session (graceful degradation).
- What happens if a tester's account has the tester tag revoked mid-session?
  The RAG panel is gated on the tester tag at response time; new responses will not
  include the panel once the tag is revoked.
- What happens if a gate survey schema is deleted after some users have completed it?
  Users who completed it retain their gate-passed status; new users see no survey.

---

## Requirements *(mandatory)*

### Functional Requirements

**Session Resilience**

- **FR-001**: The system MUST persist the active session identifier on the client
  across page reloads for authenticated users.
- **FR-002**: On load, the system MUST attempt to restore an active session from the
  persisted identifier before creating a new session.
- **FR-003**: The system MUST clear the persisted session identifier when a user
  explicitly ends their session.
- **FR-004**: The system MUST clear the persisted session identifier when the
  authenticated user identity changes (logout or account switch).
- **FR-005**: When a message send fails due to network unavailability, the system MUST
  mark the message as pending (not failed) and display an offline indicator.
- **FR-006**: When network connectivity is restored, the system MUST automatically
  retry all pending messages without user action.
- **FR-007**: Guest users MUST always start a fresh session (no resume).

**RAG Transparency**

- **FR-008**: For tester-tagged users, each assistant message MUST include metadata
  about which knowledge base documents were retrieved during response generation.
- **FR-009**: The RAG detail panel MUST be hidden for all non-tester-tagged users.
- **FR-010**: When no documents were retrieved, the panel MUST show a clear empty state.

**Survey Gate**

- **FR-011**: The system MUST intercept chat navigation for users in groups with a gate
  survey configured and display the survey before granting chat access.
- **FR-012**: Once a user completes and submits the gate survey, the system MUST record
  their completion so the survey is not shown again.
- **FR-013**: The gate survey MUST support text, single-choice, and multi-choice question
  types with a progress indicator.
- **FR-014**: Users MUST be able to review their answers before final submission.

**Survey Schema Editor**

- **FR-015**: The schema editor MUST support multi-line markdown-formatted instructions
  per question group.
- **FR-016**: Visibility conditions MUST support multiple simultaneous conditions (AND
  logic) and the NOT_IN operator.
- **FR-017**: Choice questions MUST support a freetext ("other") option that reveals a
  text input when selected.
- **FR-018**: Schema edits MUST auto-save without requiring an explicit user action.
- **FR-019**: Schemas MUST be exportable and importable as JSON with full fidelity.

### Key Entities

- **Session**: An active or ended chat conversation. Has a status (`active`, `ended`,
  `expired`) and an owner (authenticated user or guest). Persisted server-side.
- **RAGCallDetail**: Metadata about knowledge base documents retrieved during a
  single assistant response. Attached to the message for tester users only; never stored.
- **SurveySchema**: The template definition of a survey — questions, types, visibility
  conditions, and instructions. Reusable across groups.
- **SurveyResponse**: A single user's answers to a survey schema instance. Tracks
  completion status used for gate checks.
- **GateCheck**: Server-side evaluation of whether a user has completed the required
  gate survey for their group before chat access is granted.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users who reload an active chat tab see their previous conversation restored
  within the normal page load time — no additional wait beyond a standard page load.
- **SC-002**: Zero messages are permanently lost when a user reconnects after an
  offline period; all messages queued during the outage are delivered.
- **SC-003**: Tester-tagged users can identify the knowledge source for any assistant
  response within one interaction (open RAG panel → see documents).
- **SC-004**: RAG retrieval details are never visible to non-tester users under any
  circumstances (verified by role-based UI test).
- **SC-005**: Users complete the gate survey in one linear flow with no navigation
  dead-ends; 100% of completions result in immediate chat access.
- **SC-006**: Admins can build a survey schema with multi-condition visibility and
  markdown instructions without writing any code or markup outside the editor UI.
- **SC-007**: Schema export/import round-trip preserves all questions, conditions, and
  settings with zero data loss.

---

## Assumptions

- The 30-minute session TTL on the backend is unchanged; expired sessions always result
  in a new session start on resume attempt.
- The `testerTagAssigned` field is authoritative at response-generation time; no caching
  of this flag is assumed.
- Gate survey completion is tracked per user per survey schema instance; switching a
  group to a different schema resets the gate for all members.
- Auto-save in the schema editor triggers on field blur or a short debounce; explicit
  save is not required but a save button may still be provided as affordance.

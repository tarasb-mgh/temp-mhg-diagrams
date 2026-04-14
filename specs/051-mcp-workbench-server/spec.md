# Feature Specification: MCP Workbench Server

**Feature Branch**: `051-mcp-workbench-server`
**Created**: 2026-04-15
**Status**: Draft
**Input**: User description: "MCP SSE Workbench Server — a remote MCP server that exposes MHG Workbench tools over SSE transport, enabling Claude Code users to perform workbench operations from within the Claude environment."

## Summary

Enable administrators, moderators, developers, and AI agents to perform MHG Workbench operations directly from Claude Code (or any MCP-compatible client) without opening a browser. The server exposes workbench functionality as discoverable, role-scoped tools over the Model Context Protocol (MCP) using Server-Sent Events (SSE) transport. Users authenticate through a browser-based device authorization flow and interact with the same workbench capabilities they have in the web UI.

## User Scenarios & Testing

### User Story 1 - Authenticate and Discover Available Tools (Priority: P1)

A workbench user adds the MCP server URL to their Claude Code configuration. On first use, they are prompted to open a browser URL and log in with their existing credentials. After authentication, Claude Code discovers the tools available to them based on their role — a moderator sees review and user management tools; an owner sees everything including supervision and escalation tools.

**Why this priority**: Authentication is the gateway to all other functionality. Without it, no tools are usable. Dynamic tool discovery based on role ensures users see only what they can use, preventing confusion and wasted operations.

**Independent Test**: Can be fully tested by configuring a Claude Code client to connect to the MCP server, completing the device auth flow in a browser, and verifying that `tools/list` returns only the tools permitted for the authenticated user's role.

**Acceptance Scenarios**:

1. **Given** a user has added the MCP server URL to their Claude Code config, **When** they invoke any MCP tool for the first time, **Then** they receive a message with a URL and short code to complete authentication in their browser.
2. **Given** a user opens the verification URL (which includes the device code in the URL), **When** they log in with valid credentials on that page, **Then** the MCP session becomes authenticated and tools are available within 10 seconds. The user does not need to manually type a code — the verification URL embeds it.
3. **Given** a moderator has authenticated, **When** Claude Code requests the tool list, **Then** only tools matching the moderator's permissions are returned (no supervision, escalation, or security admin tools).
4. **Given** a user's authentication session expires, **When** they invoke a tool, **Then** they are prompted to re-authenticate via the device flow without needing to restart Claude Code.
5. **Given** a user has not completed authentication within 15 minutes of initiating the device flow, **When** they attempt to complete it, **Then** the device code is expired and they must start a new flow.

---

### User Story 2 - Review Chat Sessions (Priority: P1)

A reviewer uses Claude Code to browse pending review sessions, read the conversation messages, submit a rating with comments, and manage safety flags — all without leaving their terminal. This is the most frequent daily workflow for moderators.

**Why this priority**: Session review is the core workbench workflow used multiple times daily by every moderator. Enabling it through Claude Code removes the friction of switching between browser and terminal.

**Independent Test**: Can be fully tested by authenticating as a reviewer, listing pending sessions, opening one, reading messages, submitting a review with a rating and comment, and verifying the session moves to the completed state.

**Acceptance Scenarios**:

1. **Given** an authenticated reviewer, **When** they request the review queue with tab "pending", **Then** they receive a paginated list of sessions with session ID, message count, risk level, and language.
2. **Given** a list of sessions, **When** the reviewer requests details for a specific session, **Then** they receive the full conversation (user and assistant messages), review history, and metadata.
3. **Given** a session detail view, **When** the reviewer submits a review with a rating (1-10) and comment, **Then** the review is recorded and the session status updates accordingly.
4. **Given** an elevated (safety-flagged) session, **When** the reviewer views the review queue, **Then** elevated sessions appear with a clear indicator and are listed before non-elevated sessions.
5. **Given** an elevated session, **When** the reviewer resolves the safety flag with a disposition and notes, **Then** the flag is resolved and the session returns to normal priority.

---

### User Story 3 - Manage Users (Priority: P2)

An administrator searches for users, views profiles, approves pending registrations, and manages user access — streamlining the user management workflow for teams that process many approval requests.

**Why this priority**: User approval is a blocking workflow — pending users cannot access the platform until approved. Enabling this through Claude Code allows admins to process approvals quickly without context-switching.

**Independent Test**: Can be fully tested by authenticating as an admin, listing users with various filters, viewing a user profile, and approving a pending user.

**Acceptance Scenarios**:

1. **Given** an authenticated admin, **When** they search users by email or name, **Then** they receive a filtered list of matching users with role and status.
2. **Given** a pending user exists, **When** the admin approves them, **Then** the user status changes to active and they can access the platform.
3. **Given** a user profile, **When** the admin requests the profile detail, **Then** they see email, role, status, creation date, and group memberships.
4. **Given** an active user, **When** the admin blocks them, **Then** the user status changes to blocked and they cannot access the platform.

---

### User Story 4 - Manage Surveys (Priority: P2)

A researcher or admin creates survey schemas, publishes them, deploys instances to groups with date ranges, and monitors completion rates — enabling the full survey lifecycle from Claude Code.

**Why this priority**: Surveys are time-sensitive operations (deployment dates, expiration gates). CLI access allows rapid iteration on survey design and deployment without navigating the multi-step web UI.

**Independent Test**: Can be fully tested by creating a draft schema with questions, publishing it, deploying an instance to a group with dates, and verifying completion stats appear.

**Acceptance Scenarios**:

1. **Given** an authenticated researcher, **When** they create a survey schema with title, description, and questions (free text, single choice, multi choice, boolean), **Then** a draft schema is created and returned with its ID.
2. **Given** a draft schema, **When** the researcher publishes it, **Then** the schema becomes immutable and available for deployment.
3. **Given** a published schema, **When** the admin deploys an instance with assigned groups and date range, **Then** the instance is created and becomes active at the start date.
4. **Given** an active survey instance, **When** the admin checks completion stats, **Then** they see response counts per group and overall completion percentage.
5. **Given** a survey instance with problematic responses, **When** the admin invalidates responses (instance-wide, per-group, or per-user), **Then** the invalidation is recorded and affected users are prompted to retake the survey.

---

### User Story 5 - Review Dashboards and Team Stats (Priority: P3)

A reviewer or supervisor checks their personal review stats, views team-level metrics, and accesses review reports — enabling quick status checks without opening the workbench.

**Why this priority**: Dashboards are read-only and informational. They enhance situational awareness but don't block any workflows.

**Independent Test**: Can be fully tested by authenticating as a reviewer, requesting personal dashboard stats, and verifying they include review count, average score, and pending count.

**Acceptance Scenarios**:

1. **Given** an authenticated reviewer, **When** they request their personal dashboard, **Then** they receive reviews completed, average score, and pending review count.
2. **Given** an authenticated supervisor, **When** they request the team dashboard, **Then** they receive per-reviewer metrics including completion rates.
3. **Given** an authenticated user with report access, **When** they request review reports, **Then** they receive available reports with summary data.
4. **Given** escalated sessions exist, **When** a supervisor lists escalations, **Then** they receive a list of sessions requiring escalation review.

---

### User Story 6 - Manage Groups (Priority: P3)

An administrator browses groups, views group members, and checks group-specific chats and surveys — providing group oversight from the terminal.

**Why this priority**: Group management is primarily read-heavy (viewing members, checking surveys). It supports admin oversight but is less frequent than review or survey operations.

**Independent Test**: Can be fully tested by listing groups, viewing a group's member list, and checking group-specific survey instances.

**Acceptance Scenarios**:

1. **Given** an authenticated admin, **When** they list groups, **Then** they receive all groups with name and member count.
2. **Given** a group, **When** the admin views its detail, **Then** they see the member list with roles.
3. **Given** a group with active surveys, **When** the admin lists group surveys, **Then** they see survey instances scoped to that group with completion data.

---

### User Story 7 - Supervise Reviews (Priority: P3)

A supervisor approves or rejects completed reviews from their queue, providing quality oversight without switching to the browser.

**Why this priority**: Supervision is a secondary workflow that builds on the review system. It requires review tools to be working first.

**Independent Test**: Can be fully tested by authenticating as a supervisor, listing the supervision queue, and approving or rejecting a review with a reason.

**Acceptance Scenarios**:

1. **Given** an authenticated supervisor, **When** they list the supervision queue, **Then** they receive reviews awaiting supervisor decision.
2. **Given** a review in the supervision queue, **When** the supervisor approves it, **Then** the review status updates to approved.
3. **Given** a review in the supervision queue, **When** the supervisor rejects it with a reason, **Then** the review status updates to rejected with the reason recorded.

---

### User Story 8 - Manage Review Tags (Priority: P3)

An admin creates tag definitions and reviewers assign tags to sessions during review, enabling consistent categorization across the review process.

**Why this priority**: Tags enhance the review workflow but are supplementary — reviews function without them.

**Independent Test**: Can be fully tested by creating a tag, listing tags, and assigning a tag to a review session.

**Acceptance Scenarios**:

1. **Given** an authenticated admin, **When** they create a review tag with a name, **Then** the tag is created and available for assignment.
2. **Given** existing tags, **When** a reviewer assigns a tag to a session, **Then** the tag appears on the session and is included in session detail responses.

---

### User Story 9 - Session Introspection (Priority: P1)

Any authenticated user can invoke a "who am I" query to see their identity, role, active permissions, and which tool categories are available to them — providing full transparency about what they can do in the current session.

**Why this priority**: Self-service introspection prevents frustration and wasted attempts. Users immediately understand their capabilities without trial and error.

**Independent Test**: Can be fully tested by authenticating as any role and invoking the introspection tool.

**Acceptance Scenarios**:

1. **Given** an authenticated user, **When** they invoke the session introspection tool, **Then** they receive their email, role, list of active permissions, and the categories of tools available to them.
2. **Given** a user whose permissions were loaded at session start, **When** permissions have potentially changed, **Then** the introspection tool indicates when permissions were last loaded and how to refresh them.

---

### Edge Cases

- What happens when the backend API is temporarily unavailable? Tools return a clear "service unavailable" error with a suggestion to retry, not a cryptic protocol error.
- What happens when a user's role changes between sessions? The user reconnects and the tool list updates to reflect their new permissions.
- What happens when a tool is called with invalid parameters? The system validates input before making any backend call and returns a specific validation error listing the invalid fields.
- What happens when the user's access token expires mid-operation? The system automatically refreshes the token and retries the operation once. If refresh also fails (refresh token expired or revoked), the user is prompted to re-authenticate via a new device flow.
- What happens when two Claude Code sessions are open with the same user? Each session operates independently with its own authentication and token lifecycle.
- What happens when a review session has hundreds of messages? The response is paginated, returning the most recent messages with an indicator that more messages are available.
- What happens when the server instance restarts? All SSE connections drop. Clients automatically reconnect and must re-authenticate via the device flow.
- What happens when a tool call exceeds the rate limit? The system returns a clear rate limit error with the reset time, preventing runaway automated loops from overloading the backend.
- What happens when the MCP client uses an unsupported protocol version? The server rejects the connection with a clear error indicating the supported protocol version(s), rather than silently failing or producing malformed responses.
- What happens when a destructive operation (survey invalidation, user block) is invoked via MCP? The same backend validation and audit logging applies as when performed through the web UI. The MCP server does not bypass any backend safeguards.

## Requirements

### Functional Requirements

- **FR-001**: System MUST expose workbench operations as discoverable MCP tools over SSE transport.
- **FR-002**: System MUST authenticate users via a device authorization flow where the user completes login in their browser using existing workbench credentials (OTP or third-party identity provider).
- **FR-003**: System MUST dynamically register only the MCP tools that the authenticated user's role and permissions allow — users never see tools they cannot use.
- **FR-004**: System MUST provide a session introspection tool (`whoami`) that returns the user's identity, role, permissions, and available tool categories.
- **FR-005**: System MUST transparently refresh expired access tokens using the refresh token, retrying the failed operation once before prompting re-authentication.
- **FR-006**: System MUST map backend errors to user-friendly MCP error responses with actionable messages (not raw HTTP status codes or stack traces).
- **FR-007**: System MUST enforce per-session rate limiting on tool invocations (default: 60 invocations per minute) to prevent backend overload from automated loops. The limit MUST be configurable per environment.
- **FR-008**: System MUST paginate list responses with a default page size of 25 items (maximum 100), returning an opaque cursor for retrieving subsequent pages.
- **FR-009**: System MUST validate all tool inputs against their schema before making any backend API call.
- **FR-010**: System MUST support concurrent authenticated sessions from different users, each with independent authentication state and token lifecycle.
- **FR-011**: System MUST expire device authorization codes after 15 minutes if the user does not complete authentication.
- **FR-012**: System MUST provide review queue tools supporting all queue tabs (pending, flagged, in progress, completed, excluded, supervision, awaiting) with filtering by risk level, language, and date range.
- **FR-013**: System MUST provide review submission tools accepting rating, comments, and tag assignments.
- **FR-014**: System MUST provide safety flag tools for listing, creating, and resolving risk flags with disposition and notes.
- **FR-015**: System MUST provide user management tools for listing, viewing profiles, approving pending users, and toggling block status.
- **FR-016**: System MUST provide survey schema tools for listing, viewing, creating, publishing, and cloning schemas.
- **FR-017**: System MUST provide survey instance tools for listing, viewing, deploying, and invalidating responses.
- **FR-018**: System MUST provide dashboard tools for personal stats, team metrics, reports, and escalation lists.
- **FR-019**: System MUST provide group management tools for listing groups, viewing members, and accessing group-scoped chats and surveys.
- **FR-020**: System MUST provide supervision tools for listing the supervision queue and recording approve/reject decisions.
- **FR-021**: System MUST provide review tag tools for listing, creating, and assigning tags.
- **FR-022**: System MUST never expose authentication tokens, internal identifiers, or stack traces in tool responses or error messages.
- **FR-023**: System MUST be deployed as separate instances per environment (development and production) with each instance communicating exclusively with its designated backend.
- **FR-024**: All tool invocations that modify data (write operations) MUST be logged on the same audit trail as web UI actions — the backend's existing audit logging covers this since the MCP server uses the same authenticated API calls.
- **FR-025**: System MUST reject connections from clients using unsupported MCP protocol versions with a clear error indicating the supported version(s).

### Key Entities

- **MCP Session**: A single SSE connection from a client, bound to one authenticated user with their token lifecycle and permission set.
- **Device Authorization Request**: A time-bounded request linking a device code (for the MCP server to poll) with a user code (for the human to enter in their browser).
- **Tool Registration**: A mapping from an MCP tool name to a backend API operation, gated by one or more required permissions.
- **Tool Invocation**: A single request-response cycle where the client calls a tool with typed parameters and receives structured data or an error.

## Success Criteria

### Measurable Outcomes

- **SC-001**: Users can connect and authenticate from Claude Code in under 60 seconds (from adding the config to having tools available).
- **SC-002**: All tools defined in FR-012 through FR-021 (plus the `whoami` introspection tool from FR-004) complete successfully against the development backend for users with appropriate permissions.
- **SC-003**: A moderator's tool list contains only moderator-permitted tools (zero forbidden tools visible) — verified across all defined roles.
- **SC-004**: Token refresh is transparent — users are never interrupted for re-authentication during normal usage within a single working session (tokens refresh automatically).
- **SC-005**: Tool responses return within 5 seconds for standard operations (list, view, submit) under normal backend load.
- **SC-006**: Error messages from tool failures contain actionable information (what went wrong, what to do) — no raw HTTP codes, no stack traces, no leaked credentials.
- **SC-007**: Per-session rate limiting caps tool invocations at the configured limit (default 60/minute). Clients exceeding the limit receive a clear error with retry-after timing. Other sessions are unaffected.
- **SC-008**: The service handles at least 80 concurrent SSE connections (based on expected team size of ~40 users with potential dual-session usage) and gracefully rejects connections beyond capacity with a clear "service at capacity" error.
- **SC-009**: Each environment (dev, prod) operates independently — a deployment or failure in one does not affect the other.

## Assumptions

- The existing chat-backend API already exposes all endpoints needed for the tools defined in FR-012 through FR-021. No new business logic endpoints are required (only new device auth endpoints). This assumption MUST be validated during Phase 0 research by cross-referencing each tool with the backend's API contracts.
- The existing workbench RBAC permission model is granular enough to map each tool to one or more permissions.
- Claude Code (and other MCP clients) support SSE transport for remote MCP servers.
- Users have browser access to complete the device authorization flow (this is not a fully headless/offline scenario).
- The existing `GET /api/permissions` endpoint returns the user's effective permissions in a format suitable for filtering tool registrations.

## Dependencies

- **Chat Backend**: Must add 3 device authorization endpoints: (1) initiate device flow, (2) browser-based verification page, (3) token polling endpoint. All other business logic endpoints already exist.
- **Workbench Frontend**: Must add a small device authorization verification page where users enter the code and complete login.
- **DNS/Load Balancer**: Must add `mcp.dev.mentalhelp.chat` and `mcp.mentalhelp.chat` routing rules.
- **Cloud Run**: Must provision new services (`mcp-server-dev`, `mcp-server-prod`).
- **Artifact Registry**: Must allow the new repo's CI to push container images.
- **`@mentalhelpglobal/chat-types`**: Shared type definitions used by the MCP server for type safety.

## Out of Scope

- **Real-time notifications/push**: The server exposes request-response tools only. Server-initiated push notifications (e.g., "new session arrived in your queue") are not included.
- **Streamable HTTP transport**: Only SSE transport is supported. The newer MCP Streamable HTTP transport is a future enhancement.
- **Chat frontend operations**: The MCP server exposes workbench functionality only. End-user chat operations (sending messages, managing conversations) are not included.
- **Headless/offline authentication**: Users must have browser access to complete the device authorization flow. Fully headless or offline authentication is not supported.
- **MCP Resources and Prompts**: Only MCP tools are exposed. MCP resource subscriptions (read-only data streams) and prompt templates are future enhancements.
- **Bulk operations**: No "approve all pending users" or "submit multiple reviews at once." All tools operate on individual entities.
- **Deanonymization tools**: Identity reveal workflows are excluded due to their sensitive, audit-heavy nature — these remain browser-only.
- **Security admin tools**: Permission management, feature flag toggles, and principal group configuration remain browser-only.
- **GDPR export/erasure**: Regulatory data operations remain browser-only due to audit and compliance requirements.

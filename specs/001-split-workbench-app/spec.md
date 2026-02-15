# Feature Specification: Split Chat and Workbench Experiences

**Feature Branch**: `001-split-workbench-app`  
**Created**: 2026-02-14  
**Status**: Draft  
**Input**: User description: "berofe movement to SPA I want application to be split into chat and workbench parts. Technically moving workbench part into the separate application"

## Clarifications

### Session 2026-02-14

- Q: Should the split include backend scope or frontend only? -> A: Include both frontend and backend.
- Q: Which backend split model should be used, and what domain pattern should be used? -> A: Use independently deployable chat/workbench backend services for independent scaling; keep chat domains unchanged, and use `workbench.mentalhelp.chat` + `api.workbench.mentalhelp.chat` for production and the same pattern for dev.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Access Chat and Workbench as Separate Experiences (Priority: P1)

As a signed-in user, I can open chat and workbench as separate application experiences with clear entry points, so each workflow is focused and not mixed into one surface.

**Why this priority**: This is the core scope change and enables all follow-on improvements; without this split, the feature has no user value.

**Independent Test**: Sign in, open chat from the primary entry point, open workbench from its dedicated entry point, and confirm each experience loads its own navigation and primary actions.

**Acceptance Scenarios**:

1. **Given** a signed-in user at the main entry page, **When** they choose chat, **Then** chat opens in the chat experience without workbench-only controls.
2. **Given** a signed-in user at the main entry page, **When** they choose workbench, **Then** workbench opens in the workbench experience without chat-only controls.
3. **Given** a user deep-links to either experience, **When** the page opens, **Then** the correct experience loads directly and remains functional.
4. **Given** a production user opens the workbench URL, **When** the request resolves, **Then** frontend loads at `workbench.mentalhelp.chat` and workbench API requests use `api.workbench.mentalhelp.chat`.

---

### User Story 2 - Preserve Role-Based Access and Context Separation (Priority: P2)

As an organization user, I can only access the experience allowed by my role, and I do not lose my valid account/session context while moving between allowed entry points.

**Why this priority**: The split must not weaken permissions or create accidental exposure of restricted capabilities.

**Independent Test**: Validate access with at least one chat-only user and one workbench-authorized user, ensuring denied routes are blocked and allowed routes retain valid context.

**Acceptance Scenarios**:

1. **Given** a user without workbench permission, **When** they attempt to open workbench, **Then** access is denied with a clear message and safe fallback path.
2. **Given** a workbench-authorized user, **When** they open workbench from a valid session, **Then** required context (identity and allowed scope) is preserved.
3. **Given** a user changes from one allowed experience to another, **When** navigation completes, **Then** no unauthorized data from the previous experience is exposed.
4. **Given** independent backend scaling events for one surface, **When** traffic shifts, **Then** the other surface remains unaffected and continues meeting access constraints.

---

### User Story 3 - Maintain Stable User Flows During Transition (Priority: P3)

As a returning user, I can continue using bookmarked routes and existing critical journeys during the transition period without confusion or broken pages.

**Why this priority**: Transition reliability reduces disruption and support load while the architecture evolves.

**Independent Test**: Use a set of existing known routes/bookmarks and verify users are redirected or routed correctly with no blocked critical actions.

**Acceptance Scenarios**:

1. **Given** a user opens an old route format, **When** the route is no longer canonical, **Then** the user is redirected to the correct current entry point.
2. **Given** a user starts a critical workflow in chat or workbench, **When** they complete the flow, **Then** the split architecture does not block task completion.
3. **Given** an unavailable or invalid route, **When** a user opens it, **Then** they receive a clear recovery path to the correct experience.

---

### Edge Cases

- A user has a valid account but permission for only one of the two experiences.
- A user opens stale bookmarks or shared links created before the split.
- A session expires while switching from one experience to the other.
- A user attempts direct access to restricted workbench paths without required permissions.
- Concurrent browser tabs are open in both experiences and one tab signs out.
- Frontend routes are split but backend endpoints are not, creating authorization drift between surfaces.
- Production and dev domain routing are misaligned between frontend and API hosts, causing cross-surface API leakage or CORS failures.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide separate user entry points for chat and workbench experiences.
- **FR-002**: System MUST ensure each experience presents only the controls and navigation relevant to that experience.
- **FR-003**: System MUST enforce role-based access for workbench capabilities.
- **FR-004**: System MUST preserve valid authenticated context when moving between allowed experiences.
- **FR-005**: System MUST prevent unauthorized access to restricted experience routes, including direct URL access.
- **FR-006**: System MUST provide predictable routing for existing links by redirecting deprecated paths to the correct current experience.
- **FR-007**: System MUST provide user-visible recovery guidance when a route is invalid, unavailable, or unauthorized.
- **FR-008**: System MUST preserve existing localization and accessibility behavior across both experiences.
- **FR-009**: For user-facing UI, system MUST provide responsive behavior across modern mobile/tablet/desktop viewports.
- **FR-010**: For installable web clients, system MUST preserve PWA installability and fallback behavior where installation is unsupported.
- **FR-011**: System MUST include release verification evidence for split-routing behavior, permission boundaries, and critical journey continuity.
- **FR-012**: System MUST split backend API surfaces for chat and workbench capabilities with explicit route boundaries and access control enforcement aligned to frontend experience separation.
- **FR-013**: System MUST ensure backend responses and data contracts remain isolated by surface so workbench-only capabilities are not exposed through chat API paths.
- **FR-014**: System MUST provide independently deployable backend services for chat and workbench so each backend surface can scale independently.
- **FR-015**: System MUST expose workbench frontend and API on dedicated production domains: `workbench.mentalhelp.chat` and `api.workbench.mentalhelp.chat`, while preserving existing chat domains.
- **FR-016**: System MUST expose corresponding dedicated workbench frontend and API domains in development using the same naming pattern as production.

### Key Entities *(include if feature involves data)*

- **Experience Surface**: A user-facing application context (`chat` or `workbench`) with distinct navigation and actions.
- **Entry Point**: A route or launcher action that opens a specific experience surface.
- **Access Policy**: Rules defining which user roles can enter and use each experience surface.
- **Route Mapping Rule**: A transition rule that maps legacy routes to current canonical routes.
- **Session Context**: The active user identity and allowed scope that must remain valid across permitted transitions.
- **Backend Surface Boundary**: A backend API capability boundary that separates chat and workbench endpoints, authorization checks, and exposed data contracts.
- **Domain Topology**: Canonical environment-specific frontend/API hostnames for each surface, including production and development mappings.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of defined critical chat and workbench journeys complete successfully in release validation.
- **SC-002**: 100% of restricted workbench access attempts by unauthorized users are blocked with clear user guidance.
- **SC-003**: At least 95% of tested legacy bookmarks/links resolve to a valid current experience route without manual support.
- **SC-004**: User-reported navigation confusion incidents related to chat/workbench switching decrease by at least 50% within one release cycle after launch, measured against the immediately preceding release baseline using the same support-ticket category and in-app feedback tag.

## Assumptions

- Existing identity and role assignments remain the source of truth for access decisions.
- A defined list of critical chat/workbench journeys exists for release validation.
- Some legacy routes will remain in circulation during transition and require compatibility handling.
- The split is an interim stage prior to broader architecture evolution; user continuity is prioritized over structural purity.
- "Separate application" for this feature includes both frontend experience separation and independently deployable backend API surface separation for independent scaling.
- Chat production and development domains remain unchanged; workbench uses dedicated frontend/API domains per environment.

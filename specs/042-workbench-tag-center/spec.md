# Feature Specification: Unified Workbench Tag Center

**Feature Branch**: `042-workbench-tag-center`  
**Created**: 2026-03-30  
**Status**: Draft  
**Jira Epic**: [MTB-1049](https://mentalhelpglobal.atlassian.net/browse/MTB-1049)  
**Input**: User description: "Unify tagging into a single Workbench Tag Center focused on clarity, control, and low-error workflows."

## Summary

Create one unified tagging entry point in Workbench that consolidates tag operations while preserving clear semantic separation between user tagging and review tagging. Replace special-case tester-tag behavior with a standard user-tag model, unify backend tag authorization and validation patterns, and ensure operators can complete core happy flows with minimal friction and low error rates.

## Clarifications

### Session 2026-03-30

- Q: How should review-tag deletion behave when historical links exist? -> A: Block deletion if the tag was used in any review record (active or historical); allow archiving only.
- Q: How should rights management and user-tag assignment be split? -> A: `moderator+` manages rights, while user-tag assignment is performed without capability checks.
- Q: How should SC-003 be measured? -> A: Use automated E2E validation in dev with 10 consecutive executions, counting each execution as one run.
- Q: Which users can receive user-tag assignments without capability checks? -> A: All users, with no exceptions.
- Q: How should the archive-return terminology be standardized? -> A: Use only `archive/unarchive`; do not use `restore`.

## User Scenarios & Testing

### User Story 1 - Manage User Tags and Assignments in One Place (Priority: P1)

An operator opens Tag Center in User Tags mode and can manage user tag definitions and user tag assignments without switching between separate pages. Assignment actions are available for all users without capability checks, while rights management remains limited to moderator-or-higher operators. The operator can find users and tags quickly, assign or remove tags, and verify results immediately.

**Why this priority**: User tagging affects security, access behavior, and review management outcomes. This flow carries the highest operational impact and must be reliable first.

**Independent Test**: A permitted operator creates a user tag, assigns it to a user, unassigns it, edits tag metadata, and archives or deletes the tag from the same Tag Center area, with expected confirmations and visible state changes.

**Acceptance Scenarios**:

1. **Given** an operator with user-tag definition write capability, **When** they create a new user tag in User Tags mode, **Then** the tag appears in the user tag list and can be assigned to users.
2. **Given** an operator acting on any target user, **When** they assign and then remove a user tag from that user, **Then** the user state reflects each action after the operation completes and without requiring navigation to another page.
3. **Given** an operator searching users or tags, **When** they apply search or filters, **Then** results match case-insensitive partial text on supported fields (user name, user email, tag name) and apply combined filters with AND logic.
4. **Given** a tag named `tester`, **When** it is managed in User Tags mode, **Then** it behaves as a normal user tag with no dedicated special-case workflow.
5. **Given** an existing user tag definition, **When** an authorized operator edits its metadata, **Then** the updated metadata is shown consistently in Tag Center views.
6. **Given** an existing user tag definition, **When** an authorized operator archives it, **Then** it is no longer available for new assignments and remains visible as archived state.
7. **Given** an existing user tag definition with active assignments, **When** an authorized operator attempts to delete it, **Then** deletion is blocked, assignments remain intact, and guidance is provided to remove assignments first.
8. **Given** an operator in `User Tags` mode, **When** the page is rendered on desktop or mobile, **Then** high-frequency actions (definitions and assignments) remain visually primary and low-frequency rights controls are compact and embedded contextually in the assignments header to reduce visual noise.
9. **Given** desktop viewport sizing, **When** Tag Center is opened in either mode, **Then** the route content fits into a single visible workbench viewport and long lists scroll inside their own panels instead of expanding the whole page.
10. **Given** mobile viewport sizing, **When** Tag Center is opened, **Then** the page retains natural vertical scrolling and all required controls remain reachable without horizontal overflow.

---

### User Story 2 - Manage Review Tags Separately but from Same Entry Point (Priority: P1)

A review operator enters Tag Center and switches to Review Tags mode to manage review/chat tag definitions without mixing those controls with user assignment controls.

**Why this priority**: Review operations need fast, focused control of review tags, but the organization wants one intuitive entry point for all tagging.

**Independent Test**: A permitted operator switches to Review Tags mode and completes create, edit, archive, and delete operations without navigating to a separate feature page.

**Acceptance Scenarios**:

1. **Given** an operator with review-tag definition write capability, **When** they open Review Tags mode, **Then** they can create, edit, archive, and delete review tags.
2. **Given** Tag Center has both User Tags and Review Tags modes, **When** an operator switches modes, **Then** each mode shows only the controls and data relevant to that domain.
3. **Given** an operator lacks review-tag write capability, **When** they are in Review Tags mode, **Then** restricted controls are hidden or disabled and forbidden actions are blocked.
4. **Given** a review tag is referenced by any review record (active or historical), **When** an authorized operator attempts to delete it, **Then** deletion is blocked and guidance is shown to archive instead.

---

### User Story 3 - See All Assigned User Tags in User Profile (Priority: P2)

An operator views a user profile and sees all user tags assigned to that user so they can understand access-relevant categorization and operational context without checking another page.

**Why this priority**: Profile-level visibility reduces context switching and prevents mistakes caused by incomplete tag awareness.

**Independent Test**: Assign multiple user tags to a user, open the user profile, and verify that all assigned tags are visible and consistent with Tag Center assignment state.

**Acceptance Scenarios**:

1. **Given** a user has multiple assigned user tags, **When** an operator opens that user profile, **Then** the profile displays all currently assigned user tags.
2. **Given** a user tag assignment changes in Tag Center, **When** the user profile is reopened or refreshed, **Then** displayed tags reflect the latest assignment state.

---

### User Story 4 - Capability-Driven Access Across UI and API (Priority: P1)

Authorization for rights-management and tag-definition actions is made by capabilities, not hardcoded role checks, and is enforced consistently in both interface behavior and backend operations. User-tag assignment actions are available for all users and are not capability-gated.

**Why this priority**: Inconsistent authorization is a high-risk failure mode for tagging operations that influence access and review workflows.

**Independent Test**: Validate multiple capability combinations for rights-management and tag-definition actions, and confirm assignment actions are available for all users without capability gating.

**Acceptance Scenarios**:

1. **Given** an operator has read but not write capability for a domain, **When** they open that mode, **Then** they can view data but cannot perform write actions.
2. **Given** an operator attempts a forbidden write operation, **When** the action is submitted, **Then** the operation is blocked and the interface shows a denial message stating that the operator lacks required capability.
3. **Given** capability grants are changed, **When** the operator reloads Tag Center, **Then** visible controls and permitted actions update accordingly.

---

### Edge Cases

- A tag name conflicts with an existing tag in the same scope; the system prevents duplication and preserves existing data.
- An operator has permissions for User Tags but not Review Tags; the interface still remains understandable and does not expose inapplicable controls.
- Concurrent edits occur on the same tag by different operators; users receive clear conflict feedback and do not lose confirmed updates silently.
- A tag is archived while still assigned to users; existing assignments remain visible for context, no new assignments can be created for that archived tag, and operators are guided to unassign or unarchive as allowed.
- A delete request targets a user tag that is still assigned; deletion is blocked until assignments are removed, and no orphaned assignment state is introduced.
- A profile is opened immediately after assignment changes; profile tag display remains accurate after refresh.
- An operator attempts cross-domain or bypass behavior (for example, acting on Review Tags with only User Tags write rights); unauthorized actions remain blocked even when attempted directly.
- An operator opens an old bookmarked tagging URL after migration; no legacy route compatibility is required and operators must use Tag Center as the supported navigation path.

## Requirements

### Functional Requirements

- **FR-001**: The system MUST provide one unified Tag Center entry point in Workbench for tagging operations.
- **FR-002**: Tag Center MUST provide two clearly separated modes: `User Tags` and `Review Tags`.
- **FR-003**: In `User Tags` mode, the system MUST allow authorized operators to create, edit, and archive user tag definitions, and delete user tag definitions when deletion preconditions are satisfied.
- **FR-004**: In `User Tags` mode, the system MUST allow assignment and unassignment of user tags to all users without capability-based gating on the assignment action itself.
- **FR-005**: In `User Tags` mode, the system MUST support case-insensitive partial-text search on user name, user email, and tag name, with combined filters applied using AND logic.
- **FR-006**: The system MUST treat `tester` as a standard user tag and MUST remove dedicated special-case tester-tag workflow behavior.
- **FR-007**: In `Review Tags` mode, the system MUST allow authorized operators to create, edit, and archive review tag definitions, and allow delete only when the tag is not referenced by any review record (active or historical).
- **FR-008**: The UI MUST keep user-tag assignment controls available only in `User Tags` mode and review-tag definition controls available only in `Review Tags` mode.
- **FR-009**: User profile pages MUST display all user tags currently assigned to that user.
- **FR-010**: Authorization for rights-management and tag-definition actions MUST be capability-based across Tag Center behaviors.
- **FR-011**: Backend authorization for rights-management and tag-definition operations MUST enforce the same capability model as the UI.
- **FR-012**: For equivalent operation attempts under equivalent preconditions, both domains MUST communicate failures using the same four meanings: invalid input, insufficient permission, missing target, and conflicting state.
- **FR-013**: Deleting a tag definition that still has active assignments MUST be blocked until assignments are removed, and the operator MUST receive actionable guidance.
- **FR-014**: Localization for new Tag Center content MUST be delivered with priority order: English, then Ukrainian, then Russian.
- **FR-015**: The solution MUST provide explicit, repeatable validation coverage for core create/edit/archive/delete/assign/unassign/search/permission/error flows across both modes.
- **FR-016**: Workbench navigation MUST expose Tag Center as the supported tagging entry point and remove legacy tagging page links from standard navigation.
- **FR-017**: Any required guidance message for blocked delete actions MUST include both the blocking reason and the next required operator step.
- **FR-018**: Tag Center layout MUST prioritize high-frequency actions and reduce visual noise by keeping low-frequency rights-management controls compact, secondary, and contextually placed near assignment workflows.
- **FR-019**: On desktop breakpoints, Tag Center MUST use a shell-aware single-viewport layout where outer page scrolling is avoided for this route and overflow is handled by internal panel-level scroll regions.
- **FR-020**: On mobile breakpoints, Tag Center MUST preserve standard page scrolling behavior, keep section cards visually separated, and prevent horizontal overflow.

### Key Entities

- **Tag Center**: Unified Workbench entry point for all tagging operations.
- **Tag Definition**: A named label with domain scope (`user` or `review`) and lifecycle state (active or archived).
- **User Tag Assignment**: Relationship between a user and one or more user tag definitions.
- **Capability**: Authorization unit defining whether an operator can read or write definitions or assignments in each tag domain.
- **User Profile Tag View**: Profile representation of all currently assigned user tags for a specific user.

## Non-Goals

- Bulk assignment or bulk removal operations in this phase.
- Redirects or compatibility routes for legacy tagging URLs in this phase.
- Changes to non-Workbench clients or unrelated product surfaces outside Tag Center and user profile tag display.

## Dependencies and Assumptions

- Existing tagging data remains valid and is migrated without loss of assignments.
- Capability catalog and policy mapping are available for both UI and backend enforcement.
- Existing quality checks support execution of required E2E scenarios and screenshot evidence in the team's Playwright-based validation workflow.

## Success Criteria

### Measurable Outcomes

- **SC-001**: Operators can complete the primary user-tag happy flow (create tag -> assign -> verify in profile -> unassign) in one Tag Center entry point without navigating to legacy tag pages.
- **SC-002**: Operators can complete the primary review-tag happy flow (create -> edit -> archive/delete) within Review Tags mode without accessing a separate review-tags page.
- **SC-003**: During automated E2E validation in the dev environment, each defined happy flow MUST be executed in 10 consecutive runs (each run counted independently), and no more than 2 runs may contain a blocking user-visible failure event where the intended outcome is not completed or resulting state is incorrect.
- **SC-004**: Capability-based access validation confirms restricted rights-management and tag-definition actions are consistently blocked for all mandatory permission scenarios: read-only access, denied write access, and cross-domain access attempts.
- **SC-005**: User profile validation confirms all assigned user tags are shown for tested users.
- **SC-006**: Validation evidence confirms pass/fail coverage for each mandatory operation and each required authorization and error-handling scenario defined in this specification.

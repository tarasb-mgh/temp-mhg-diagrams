# Feature Specification: Cross-Group Review Access and Group Filter Scoping

**Feature Branch**: `028-cross-group-reviews`
**Created**: 2026-03-12
**Status**: Draft
**Input**: "Researchers and Supervisors should have access to chat reviews from all the groups/spaces. Group filter in chat list interface should display the chats only from the group selected"

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Researcher/Supervisor Sees Reviews Across All Groups (Priority: P1)

A Researcher or Supervisor logs into the workbench and navigates to the review queue or session list. Currently they only see chat sessions belonging to their own active group. After this change, they see sessions from every group in the system, giving them the full picture needed for research analysis and clinical supervision across the platform.

**Why this priority**: Cross-group visibility is the primary ask and unblocks research and supervision workflows that currently require belonging to each group individually. This is the highest-value unlock.

**Independent Test**: A user with the Researcher or Supervisor role can view and open sessions from groups they are not a member of — confirmed by seeing sessions from at least two distinct groups in the session list.

**Acceptance Scenarios**:

1. **Given** a Researcher is logged in with no active group membership, **When** they open the review session list, **Then** sessions from all groups are visible and reviewable.
2. **Given** a Supervisor is a member of Group A, **When** they open the review session list with no group filter applied, **Then** they see sessions from Group A, Group B, and all other groups — not just Group A.
3. **Given** a standard Reviewer (non-Researcher, non-Supervisor), **When** they open the review session list, **Then** they see only sessions from their own group (no change to Reviewer behaviour).
4. **Given** a Researcher opens a session from a group they are not a member of, **When** they view the session detail, **Then** the full conversation and review panel are accessible without an authorisation error.

---

### User Story 2 — Group Filter Scopes Session List to Selected Group (Priority: P2)

In the workbench review interface, there is a group filter control. When a Researcher or Supervisor (or any role that can see multiple groups) selects a specific group from this filter, the session list should show only sessions belonging to that group — nothing more, nothing less.

**Why this priority**: Without correct filter scoping, the cross-group list (US1) becomes difficult to navigate. The filter is the primary way users drill into a single group's data.

**Independent Test**: Selecting Group B from the group filter on the session list returns only Group B sessions; selecting a different group returns only that group's sessions; clearing the filter restores the full visible set.

**Acceptance Scenarios**:

1. **Given** a Researcher has an unfiltered session list showing sessions from multiple groups, **When** they select Group A from the group filter, **Then** only sessions belonging to Group A are displayed.
2. **Given** the group filter is set to Group A, **When** the user clears the filter, **Then** all sessions visible to the user (across all groups for Researchers/Supervisors, or own group for Reviewers) are shown again.
3. **Given** a group is selected in the filter, **When** a session from a different group exists in the system, **Then** that session is not shown in the filtered list.
4. **Given** a Reviewer (not Researcher/Supervisor) is viewing their own group's sessions, **When** the group filter is present but that Reviewer only has one group, **Then** the filter behaves consistently: selecting their group shows only their sessions, clearing shows all their visible sessions.

---

### Edge Cases

- What happens when a Researcher has no active group at all? They should still see all sessions (the group is not a prerequisite for access).
- What if a group has no sessions? The filtered list returns empty — not an error.
- What if the Researcher's own group is deleted after login? The cross-group list should remain functional.
- What if a session belongs to no group (group_id is null)? These unassigned sessions should only appear when the filter is cleared — not when a specific group is selected.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Users with the Researcher role MUST have read access to all chat sessions across all groups for review purposes, regardless of their own group membership.
- **FR-002**: Users with the Supervisor role MUST have read access to all chat sessions across all groups for review purposes, regardless of their own group membership.
- **FR-003**: Users with the Reviewer role (without Researcher or Supervisor elevation) MUST continue to see only sessions from their own group — existing behaviour unchanged.
- **FR-004**: The review session list MUST apply the group filter as an exact scope: when a group is selected, only sessions with that group assignment are returned.
- **FR-005**: Clearing the group filter MUST restore the full set of sessions visible to the current user (all groups for Researcher/Supervisor; own group for Reviewer).
- **FR-006**: Sessions with no group assignment (unassigned) MUST NOT appear when a specific group is selected in the filter.
- **FR-007**: The authorisation check on individual session detail views MUST allow Researchers and Supervisors to open any session regardless of group.

### Key Entities

- **Session**: A chat conversation between a user and the AI assistant; belongs to a group via `group_id`. The key attribute here is whether the reviewer is authorised to access it.
- **Group / Space**: An organisational unit that scopes sessions and memberships. Researchers and Supervisors need cross-group visibility.
- **Researcher role**: An elevated review role that grants platform-wide session visibility.
- **Supervisor role**: An elevated review role (clinical supervision context) that grants platform-wide session visibility.
- **Group filter**: A UI control in the workbench session list that restricts displayed sessions to a specific group.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A Researcher or Supervisor can see and open sessions from every group in the system without any additional group membership configuration.
- **SC-002**: Selecting a group in the filter reduces the visible session count to exactly the sessions belonging to that group — no sessions from other groups appear.
- **SC-003**: Existing Reviewer access behaviour is unchanged — Reviewers can only see sessions from their own group before and after this change.
- **SC-004**: No authorisation errors occur when a Researcher or Supervisor opens a session from a group they are not a member of.
- **SC-005**: The group filter clears and restores the full visible set in a single interaction with no page reload required.

## Assumptions

- "Researcher" and "Supervisor" are distinct permission values already defined in the system's permission model (distinct from the base "Reviewer" permission).
- The workbench session list already has a group filter UI control — this change fixes its scoping behaviour, not adds the control from scratch.
- "All groups" means all groups within the same platform/tenant — there is no multi-tenant boundary consideration in scope.
- Read access for cross-group sessions means viewing session details and writing reviews; it does not include administrative actions on the group itself (adding members, deleting sessions).
- The group filter applies only to the session list view, not to other workbench views such as the survey schema editor or group admin panel.

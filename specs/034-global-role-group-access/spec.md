# Feature Specification: Global Role Group Access

**Feature Branch**: `034-global-role-group-access`
**Created**: 2026-03-19
**Status**: Draft
**Jira Epic**: [PENDING: Epic creation failed 2026-03-19T00:00:00Z — Atlassian MCP unavailable. Sync retroactively with `/mhg.sync push`]
**Input**: User description: "Global role holders (Researcher, Moderator, Supervisor, Owner) must be able to access all group-scoped workbench functionality for any group without being explicit group members."

## Summary

Global role holders — Researcher, Moderator, Supervisor, and Owner — currently cannot access group-scoped workbench features (review queues, group configuration, analytics) for groups they are not explicitly added to as members. Group membership is a chat-user concept: ordinary users join groups to participate in chat sessions. Requiring global role holders to be manually added to every group is operationally tedious and semantically incorrect — it conflates cross-group oversight with regular group participation and pollutes member lists.

This feature introduces a two-tier access resolution model so that global role holders can access all group-scoped workbench functionality for any group without being explicit group members, while preserving clean group member lists that only contain actual chat users.

## User Scenarios & Testing

### User Story 1 — Researcher Reviews Sessions Across All Groups (Priority: P1)

A Researcher with zero group memberships opens the workbench and needs to review chat sessions from any group. Today, the group selector shows only groups they belong to (possibly none), blocking their ability to perform cross-group research and review work.

**Why this priority**: This is the most common workflow blocked by the current design. Researchers are hired specifically for cross-group oversight and cannot do their core job without this.

**Independent Test**: Log in as a Researcher with no group memberships. Verify the group selector lists all groups and that selecting any group shows its sessions in the review queue.

**Acceptance Scenarios**:

1. **Given** a Researcher with no group memberships, **When** they open the workbench group selector, **Then** all groups in the system are listed.
2. **Given** a Researcher selects a group they are not a member of, **When** they view the review queue, **Then** sessions from that group are displayed and reviewable.
3. **Given** a Researcher selects a group they are not a member of, **When** they submit a review for a session in that group, **Then** the review is recorded successfully.

---

### User Story 2 — Supervisor Configures Any Group's Review Policy (Priority: P1)

A Supervisor needs to adjust supervision policy (all/sampled/none), reviewer count, or survey ordering for a group they do not belong to. Currently they must first be added as a group member to access the configuration panel.

**Why this priority**: Supervisors manage review quality across the platform. Blocking configuration changes on membership defeats the purpose of the role.

**Independent Test**: Log in as a Supervisor with no group memberships. Navigate to any group's configuration panel and modify supervision policy.

**Acceptance Scenarios**:

1. **Given** a Supervisor who is not a member of Group X, **When** they navigate to Group X's configuration, **Then** the configuration panel is accessible.
2. **Given** a Supervisor edits Group X's supervision policy from "none" to "sampled" at 20%, **When** they save, **Then** the change persists and takes effect.
3. **Given** a Supervisor modifies reviewer count for Group X, **When** they save, **Then** the new reviewer count applies to subsequent review assignments in that group.

---

### User Story 3 — Owner Has Full Access to All Groups (Priority: P1)

An Owner needs unrestricted access to every group's workbench features — reviews, configuration, analytics, member lists, survey management — without being added as a member anywhere.

**Why this priority**: Owners are system administrators. Any access restriction on them is a functional defect.

**Independent Test**: Log in as an Owner with no group memberships. Verify access to all group-scoped features for any group.

**Acceptance Scenarios**:

1. **Given** an Owner with no group memberships, **When** they access any group's workbench features, **Then** all features available to that group are accessible.
2. **Given** an Owner views the member list of a group they are not a member of, **When** the member list loads, **Then** the Owner does not appear in the list.

---

### User Story 4 — Moderator Manages Escalations Across Groups (Priority: P2)

A Moderator handles risk escalations and queue management across the entire platform. They need to access escalation queues, approve deanonymization requests, and manage review assignments for any group.

**Why this priority**: Moderators handle safety-critical workflows. While slightly less frequent than Researcher reviews, blocking escalation handling is a safety risk.

**Independent Test**: Log in as a Moderator with no group memberships. Access the escalation queue filtered to a specific group and process an escalation.

**Acceptance Scenarios**:

1. **Given** a Moderator who is not a member of Group Y, **When** they filter the escalation queue to Group Y, **Then** Group Y's escalations are visible and actionable.
2. **Given** a Moderator approves a deanonymization request for a session in a group they don't belong to, **When** the approval is submitted, **Then** the request is processed successfully.

---

### User Story 5 — QA Specialist Remains Group-Gated (Priority: P2)

A QA Specialist (Reviewer) should continue to see only the groups they are explicitly assigned to. They do not receive implicit cross-group access.

**Why this priority**: This is a negative test case ensuring the access resolution correctly excludes the lowest workbench role from implicit access.

**Independent Test**: Log in as a QA Specialist with membership in Group A only. Verify the group selector shows only Group A.

**Acceptance Scenarios**:

1. **Given** a QA Specialist who is a member of Group A only, **When** they open the group selector, **Then** only Group A is listed.
2. **Given** a QA Specialist with no group memberships, **When** they open the group selector, **Then** the selector is empty and no group-scoped features are accessible.

---

### User Story 6 — Audit Trail Distinguishes Access Type (Priority: P3)

When a global role holder performs an action in a group they don't belong to, the audit trail must record that access was granted via global role rather than group membership. This supports compliance and traceability.

**Why this priority**: Important for compliance but does not block the core access functionality.

**Independent Test**: As a Supervisor (non-member of Group X), perform an action in Group X. Verify the audit log entry indicates role-based access.

**Acceptance Scenarios**:

1. **Given** a Supervisor (not a member of Group X) modifies Group X's config, **When** the audit log is reviewed, **Then** the entry shows the access type as "global_role" (not "membership").
2. **Given** a Researcher (who IS a member of Group Y) submits a review in Group Y, **When** the audit log is reviewed, **Then** the entry shows the access type as "membership".

---

### Edge Cases

- **Role downgrade**: When a user is demoted from Researcher to QA Specialist, they immediately lose implicit access to non-member groups. Access is resolved at request time with no cached state to invalidate.
- **Dual path (global role + explicit membership)**: A user who holds a global role AND is an explicit member of a group retains access through membership if their global role is later removed. Both paths are independent.
- **Group deletion or archival**: Implicit access follows the group's lifecycle. Deleted or archived groups are inaccessible to everyone, including global role holders.
- **Empty group list for QA Specialist**: A QA Specialist with zero memberships sees an empty group selector. This is correct — they must be explicitly assigned.
- **API vs UI consistency**: The access resolution must be enforced server-side. A UI-only change that shows all groups in the dropdown but doesn't authorize the backend request is a security gap.

## Requirements

### Functional Requirements

- **FR-001**: The system MUST resolve group access through two independent paths: explicit group membership OR holding a global role at or above Researcher level.
- **FR-002**: Users with a global role of Researcher, Moderator, Supervisor, or Owner MUST be able to access all group-scoped workbench features for any group without being an explicit member of that group.
- **FR-003**: The workbench group selector MUST list all groups in the system for users with a global role at or above Researcher level.
- **FR-004**: The workbench group selector for QA Specialists MUST list only groups where the user has explicit membership.
- **FR-005**: Group member list endpoints MUST return only users with explicit group membership. Global role holders who access a group via their role MUST NOT appear in the group's member list.
- **FR-006**: The system MUST enforce group access authorization on the server side. Client-side filtering alone is insufficient.
- **FR-007**: When a global role holder performs an action in a group they are not a member of, the audit log MUST record the access type as role-based (distinct from membership-based access).
- **FR-008**: When a user's global role is downgraded below Researcher, they MUST immediately lose implicit access to groups they are not explicit members of. No manual cleanup or cache invalidation should be required.
- **FR-009**: The chat frontend MUST remain unchanged. Group membership continues to gate chat participation for ordinary users.
- **FR-010**: A user who holds both a global role and explicit group membership MUST retain group access through membership if their global role is later removed.

### Key Entities

- **Access Resolution**: A logical check that determines whether a user can access a given group's workbench features. Inputs: user identity, target group. Outputs: access granted (with access type: membership or global_role) or access denied.
- **Global Role**: One of Owner, Moderator, Supervisor, Researcher, or QA Specialist. Assigned per user at the platform level. Determines capability set and, with this feature, implicit group access for Researcher and above.
- **Group Membership**: An explicit record linking a user to a group. Remains the sole mechanism for chat participation and the sole source of group member list data.

## Success Criteria

### Measurable Outcomes

- **SC-001**: A Researcher, Moderator, Supervisor, or Owner with zero group memberships can access workbench features for 100% of groups in the system.
- **SC-002**: QA Specialists with no group memberships can access workbench features for 0% of groups (empty group selector).
- **SC-003**: Group member list endpoints return zero global-role-only users across all groups (no phantom memberships).
- **SC-004**: 100% of group-scoped workbench actions by non-member global role holders produce audit log entries with a role-based access type marker.
- **SC-005**: Role downgrade from Researcher to QA Specialist results in immediate loss of implicit group access with zero manual intervention.
- **SC-006**: Zero regressions in chat frontend behavior — group membership continues to gate chat participation identically to current behavior.

## Assumptions

- The existing role hierarchy (QA Specialist < Researcher < Supervisor < Moderator < Owner) is stable and will not change as part of this feature.
- The `REVIEW_CROSS_GROUP` permission introduced in spec 028 already establishes the Researcher threshold for cross-group access. This feature generalizes that pattern to all group-scoped workbench features.
- Audit logging infrastructure already exists and can accept a new access-type field without schema-level changes.
- The number of groups in the system is small enough that listing all groups in the selector is practical without pagination or search (if this changes, pagination is a separate enhancement).

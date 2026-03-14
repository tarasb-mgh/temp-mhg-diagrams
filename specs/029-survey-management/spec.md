# Feature Specification: Survey Instance Management

**Feature Branch**: `029-survey-management`
**Created**: 2026-03-14
**Status**: Draft
**Input**: User description: "I need to change the expiration date on a survey instance and be able to change the group assignment mid-flight. The completed surveys are preserved. Also I need to see the survey statistics to be able to identify the group users who have not completed the survey"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Edit Survey Expiration Date (Priority: P1)

A workbench admin has deployed a survey to a group and needs to extend (or shorten) the deadline. They navigate to the survey instance in the workbench, change the expiration date, and save. The survey immediately reflects the new deadline — active participants can still submit within the updated window, and previously completed responses are unaffected.

**Why this priority**: Deadline changes are a routine operational need. Without this capability, admins must delete and re-create survey instances, losing all completion data.

**Independent Test**: Can be fully tested by editing the expiration date on an existing survey instance and confirming: (a) the new date is persisted, (b) the survey is accessible before the new expiry, (c) completed responses remain intact.

**Acceptance Scenarios**:

1. **Given** an active survey instance with a future expiration date, **When** an admin updates the expiration date to a later date and saves, **Then** the survey instance displays the new expiration date and remains open to uncompleted users.
2. **Given** an active survey instance, **When** an admin updates the expiration date to an earlier (but still future) date and saves, **Then** the survey closes at the new earlier date and all completed responses are preserved.
3. **Given** an active survey instance with some completed responses, **When** an admin changes the expiration date, **Then** the previously completed responses are unchanged and still visible in statistics.
4. **Given** an admin attempts to set an expiration date that is in the past, **When** they try to save, **Then** the system rejects the change with a clear validation message indicating past dates are not allowed.

---

### User Story 2 - Change Group Assignment Mid-Flight (Priority: P2)

A workbench admin realises the survey was assigned to the wrong group, or the survey scope has shifted. While the survey is active (some users may have already completed it), the admin reassigns it to a different group. The completed responses from any user are preserved. Users in the new group who have not yet completed the survey can now access and submit it.

**Why this priority**: Operational corrections without data loss are critical for survey integrity. A mid-flight reassignment allows course corrections without destroying collected data.

**Independent Test**: Can be fully tested by changing a survey's group assignment while at least one response is already recorded, then confirming: (a) the existing response is preserved, (b) the new group's users can access the survey, (c) users from the old group who have completed are visible in history.

**Acceptance Scenarios**:

1. **Given** an active survey with completed responses from users in Group A, **When** an admin reassigns the survey to Group B, **Then** all previously completed responses are preserved and the survey becomes accessible to Group B users.
2. **Given** a survey reassigned from Group A to Group B, **When** a user from Group B opens the survey, **Then** they see a fresh, unsubmitted survey (their own completion state is independent).
3. **Given** a survey reassigned to Group B, **When** an admin views the completion statistics, **Then** the statistics reflect Group B's membership as the active population for pending/completion tracking.
4. **Given** an admin attempts to assign a survey to a group that has no members, **When** they save, **Then** the system shows a warning that the group is empty but allows the assignment.

---

### User Story 3 - View Survey Completion Statistics with Non-Completers (Priority: P3)

A workbench admin wants to know who in the assigned group has not yet completed the survey, so they can follow up. They open the survey statistics view and see a breakdown: total group members, how many have completed, how many are pending, and a list of the specific users who have not yet submitted.

**Why this priority**: Identifying non-completers enables targeted follow-up and improves survey response rates. It does not block survey operations but provides essential administrative insight.

**Independent Test**: Can be fully tested by viewing statistics on a survey with a mix of completed and pending group members, then confirming the non-completer list accurately reflects those who have not submitted.

**Acceptance Scenarios**:

1. **Given** a survey assigned to a group where some users have completed and some have not, **When** an admin opens the survey statistics, **Then** they see the total group member count, completed count, pending count, and completion rate percentage.
2. **Given** the survey statistics view, **When** an admin looks at the non-completers section, **Then** they see a list of specific users (name and/or identifier) from the current group who have not submitted the survey.
3. **Given** all users in the assigned group have completed the survey, **When** an admin views statistics, **Then** the non-completers list is empty and the completion rate shows 100%.
4. **Given** a survey whose group was changed mid-flight, **When** an admin views statistics, **Then** the statistics reflect the current assigned group's membership (non-completers = current group members minus those who submitted).

---

### Edge Cases

- What happens when the expiration date is changed to a date that has already passed?
- How does the system handle a group reassignment where a user exists in both the old and new groups and has already completed the survey?
- What if the survey is expired at the moment of a group reassignment — does the reassignment also require extending the expiry?
- How does the non-completer list behave when the group has no members?
- What if the survey has no group assigned (unassigned state) — can statistics still be viewed for historical completions?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Admins MUST be able to edit the expiration date of an existing survey instance from the workbench without deleting and recreating the instance.
- **FR-002**: The system MUST reject expiration date changes where the new date is in the past, displaying a clear validation error.
- **FR-003**: Admins MUST be able to reassign a survey instance to a different group while the survey is active (mid-flight).
- **FR-004**: The system MUST preserve all existing completed survey responses when the expiration date is changed or when the group assignment is changed.
- **FR-005**: After a group reassignment, the system MUST make the survey accessible to members of the new group who have not yet submitted.
- **FR-006**: Admins MUST be able to view a statistics summary for a survey instance showing: total members in the current assigned group, number of completions, number of pending (non-completed), and completion rate as a percentage.
- **FR-007**: The statistics view MUST display a list of individual users in the currently assigned group who have not yet submitted the survey.
- **FR-008**: Survey statistics MUST update in near real-time to reflect the current state of completions as users submit.
- **FR-009**: When a group assignment is changed, the completion statistics MUST reflect the new group's membership as the reference population for pending tracking.
- **FR-010**: The system MUST provide a visible warning when an admin assigns a survey to a group with zero members.

### Key Entities

- **Survey Instance**: A specific deployment of a survey template, with an assigned group, expiration date, and collection of responses. Key attributes: survey template reference, assigned group, expiration date, status (active/expired/draft).
- **Survey Response**: An individual user's submission for a survey instance. Belongs to a survey instance; linked to a user. Preserved regardless of group reassignment.
- **Group**: A named collection of users. A survey instance is assigned to exactly one group at a time.
- **Completion Statistics**: A derived view over a survey instance showing aggregated and per-user completion state relative to the currently assigned group's membership.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Admins can update a survey's expiration date in under 30 seconds from opening the survey instance edit view to seeing the confirmation.
- **SC-002**: Group reassignment completes without data loss — 100% of responses recorded before reassignment remain accessible after reassignment.
- **SC-003**: The non-completers list accurately identifies all group members who have not submitted, with zero false positives and zero false negatives relative to actual submission records.
- **SC-004**: Completion statistics refresh within 10 seconds of a user submitting a survey response, reflecting the up-to-date counts without a page reload.
- **SC-005**: Admins can identify all non-completers for a survey group in a single view without needing to cross-reference external data sources.

## Assumptions

- Only users with workbench admin or survey-manager role can edit survey instances (expiration date, group assignment).
- "Group assignment" means a survey is assigned to exactly one group at a time; this is a replacement, not an addition.
- Completed responses are stored at the user level and are not deleted by group reassignment or expiration date changes.
- A "survey instance" is a deployed survey — distinct from the survey template/definition.
- Non-completer statistics are scoped to the currently assigned group. Historical responses from users in previous groups remain in the system but are not counted as "pending" for the current group.
- The statistics view is available from the workbench survey management interface.
- Users who are members of both the old and new group retain their existing completion state.

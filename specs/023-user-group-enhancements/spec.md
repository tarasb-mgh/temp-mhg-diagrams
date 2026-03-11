# Feature Specification: User Group and Management Interface Enhancements

**Feature Branch**: `023-user-group-enhancements`
**Created**: 2026-03-10
**Status**: Implemented
**Jira Epic**: [MTB-657](https://mentalhelpglobal.atlassian.net/browse/MTB-657)
**Input**: User description: "1. privileged accounts can participate in user groups 2. when a new user group is created, the spaces list on top of the page should be updated 3. if a user is not privileged and is only a participant of a single space - they shouldn't see spaces dropdown 4. user group should have a Group surveys section with the possibility to reorder survey appearence within the group 5. if the user is part of several groups he only finishes the same survey instance once 6. group all response invalidation controls into invalidation menu with confirmation popup 7. in user group interface allow to lookup users for global privileged roles 8. on user management interface only navigate to user card when [View] is clicked. Add copy icon near user email in the list and on the card. do not drop search filter after navigating to the card and back"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Privileged Account Group Participation (Priority: P1)

A privileged account holder (e.g., an admin or supervisor) needs to be included as a member of a user group, not just as its manager. Currently privileged accounts cannot participate in groups as regular members, which prevents them from completing group-assigned surveys or being treated as group participants.

**Why this priority**: Privileged accounts are key organizational actors. Blocking them from group participation creates gaps in survey coverage and workflow completeness.

**Independent Test**: Can be fully tested by creating a user group, adding a privileged account as a participant, and verifying the privileged user appears in the group member list and receives group-scoped survey assignments.

**Acceptance Scenarios**:

1. **Given** a privileged account exists, **When** an administrator adds it to a user group as a participant, **Then** the privileged account appears in the group's member list alongside non-privileged users.
2. **Given** a privileged account is a group member, **When** the group has assigned surveys, **Then** the privileged account is included in the group survey completion flow.
3. **Given** a privileged account is a group member, **When** the group member list is viewed, **Then** the privileged account is visible and distinguishable by their role indicator.

---

### User Story 2 - Spaces List Refresh After Group Creation (Priority: P1)

When a new user group is created, the spaces navigation list displayed at the top of the workbench page must refresh automatically to reflect the new group's space. Currently users must manually reload the page to see newly created groups in the spaces list.

**Why this priority**: Stale navigation state after group creation creates confusion and forces unnecessary page reloads, breaking the flow of administrators setting up groups.

**Independent Test**: Can be fully tested by creating a new user group and verifying the spaces list at the top of the page updates without a page reload.

**Acceptance Scenarios**:

1. **Given** the workbench page is open, **When** a new user group is successfully created, **Then** the spaces list at the top of the page updates to include the new group's space without requiring a page reload.
2. **Given** the spaces list is visible, **When** a group creation is cancelled or fails, **Then** the spaces list remains unchanged.

---

### User Story 3 - Hide Spaces Dropdown for Single-Space Non-Privileged Users (Priority: P2)

A non-privileged user who belongs to only one space should not see the spaces dropdown selector, as it offers no value and adds visual clutter to their interface. The dropdown should only appear when a user has access to multiple spaces.

**Why this priority**: Reduces interface noise for the majority of end users who have no need to switch spaces.

**Independent Test**: Can be fully tested by logging in as a non-privileged user who is a member of exactly one space and verifying the spaces dropdown is absent from the top navigation.

**Acceptance Scenarios**:

1. **Given** a non-privileged user is a member of exactly one space, **When** they log in and view the main page, **Then** the spaces dropdown is not displayed.
2. **Given** a non-privileged user is a member of two or more spaces, **When** they view the main page, **Then** the spaces dropdown is displayed normally.
3. **Given** a privileged account is a member of one or more spaces, **When** they view the main page, **Then** the spaces dropdown is always displayed regardless of space count.

---

### User Story 4 - Group Surveys Section with Reordering (Priority: P2)

Within a user group's configuration interface, administrators need a dedicated "Group Surveys" section that lists surveys assigned to that group and allows reordering the sequence in which surveys appear to group members. Survey order within a group affects the workflow and priority for members completing assignments.

**Why this priority**: Survey ordering within a group directly impacts member experience and workflow prioritization, and is a missing capability in the current group management interface.

**Independent Test**: Can be fully tested by navigating to a user group, opening the Group Surveys section, and dragging/reordering surveys to confirm the new order persists and reflects for group members.

**Acceptance Scenarios**:

1. **Given** a user group has surveys assigned, **When** an administrator opens the group configuration, **Then** a "Group Surveys" section is visible listing all surveys assigned to the group.
2. **Given** the Group Surveys section is open, **When** an administrator reorders surveys using drag-and-drop or up/down controls, **Then** the new order is saved and immediately reflects in the surveys presented to group members.
3. **Given** a group has no surveys assigned, **When** the Group Surveys section is viewed, **Then** an appropriate empty state message is shown with guidance to assign surveys.

---

### User Story 5 - Deduplicated Survey Completion Across Groups (Priority: P2)

When a user is a member of multiple groups that share the same survey, they should complete that survey only once. The system must recognize that a survey instance already completed in one group counts as completed for all other groups that share the same survey, preventing redundant re-completion.

**Why this priority**: Survey duplication across groups creates a poor user experience and produces duplicate data, undermining analytics accuracy.

**Independent Test**: Can be fully tested by adding a user to two groups sharing the same survey, completing the survey via one group, and verifying the survey shows as completed (not re-assignable) in the second group.

**Acceptance Scenarios**:

1. **Given** a user belongs to Group A and Group B, both having Survey X assigned, **When** the user completes Survey X via Group A, **Then** Survey X is also marked complete for the user in Group B.
2. **Given** a user has already completed a shared survey, **When** they navigate to another group containing the same survey, **Then** the survey shows as completed and does not prompt them to complete it again.
3. **Given** two groups share the same underlying survey (same survey ID) but with different group-specific display settings, **When** a user completes the survey in one group, **Then** the completion is recognized system-wide and the survey is marked complete in all other groups containing that survey, regardless of display differences.

---

### User Story 6 - Consolidated Response Invalidation Menu with Confirmation (Priority: P3)

All controls that allow invalidating survey responses (e.g., invalidating individual answers, bulk invalidation) must be grouped into a single "Invalidation" menu. Any invalidation action must trigger a confirmation popup before executing, to prevent accidental data loss.

**Why this priority**: Destructive actions scattered across the interface increase the risk of accidental data deletion. Consolidation and confirmation prompts are safety-critical for data integrity.

**Independent Test**: Can be fully tested by navigating to any survey response view, confirming all invalidation controls appear only in an "Invalidation" menu, and verifying that each action triggers a confirmation dialog before proceeding.

**Acceptance Scenarios**:

1. **Given** a survey response is being viewed, **When** an administrator looks for invalidation controls, **Then** all invalidation options are found exclusively within a single "Invalidation" menu/button group, not scattered across the interface.
2. **Given** an administrator selects an invalidation action from the menu, **When** they click the action, **Then** a confirmation popup appears describing the action and its consequences before any data is modified.
3. **Given** the confirmation popup is shown, **When** the administrator cancels, **Then** no data is modified and the popup closes.
4. **Given** the confirmation popup is shown, **When** the administrator confirms, **Then** the invalidation is applied and the interface reflects the updated state.
5. **Given** a standard administrator opens the Invalidation menu, **When** they view the available actions, **Then** higher-risk actions (e.g., bulk or permanent invalidation) are disabled or hidden, visible only to elevated/privileged roles.
6. **Given** a privileged-role user opens the Invalidation menu, **When** they view the available actions, **Then** all invalidation actions including higher-risk ones are available to them.

---

### User Story 7 - Privileged Account Lookup in User Group Interface (Priority: P3)

Within the user group management interface, administrators need a way to search for and find privileged accounts (e.g., system admins, global supervisors). This supports assigning privileged accounts to groups without requiring separate navigation to the user management interface.

**Why this priority**: Without a privileged account filter, finding and adding privileged accounts to groups requires navigating away to a separate interface, interrupting the group management workflow.

**Independent Test**: Can be fully tested by opening a user group and using the user search/lookup feature with a filter for privileged accounts, verifying that only privileged accounts appear in results.

**Acceptance Scenarios**:

1. **Given** an administrator is managing a user group, **When** they open the user lookup/search within the group interface, **Then** a filter option for "privileged accounts" is available.
2. **Given** the privileged accounts filter is applied, **When** search results are returned, **Then** only privileged accounts appear in the results.
3. **Given** a privileged account is found via lookup, **When** the administrator selects them, **Then** the user is added to the group with their privileged account indicator visible.

---

### User Story 8 - User Management Interface Navigation and Copy Improvements (Priority: P3)

On the user management interface (user list and user card), several micro-interaction improvements are needed:
- Clicking a user row should **not** navigate to the user card; only clicking the explicit **[View]** button should.
- A **copy icon** should appear next to the user's email address both in the list and on the card, allowing quick clipboard copy.
- When navigating from the user list to a user card and back, the **search filter** in the list should be preserved, not cleared.

**Why this priority**: These are usability refinements that reduce friction in daily user management workflows, particularly for administrators managing large user lists.

**Independent Test**: Can be fully tested by: (1) clicking a user row outside [View] and confirming no navigation occurs, (2) clicking the copy icon and confirming the email is in the clipboard, (3) navigating to a card and back and confirming the search filter is intact.

**Acceptance Scenarios**:

1. **Given** the user list is displayed, **When** an administrator clicks anywhere on a user row except the [View] button, **Then** the interface does not navigate to the user card.
2. **Given** the user list is displayed, **When** an administrator clicks the [View] button for a user, **Then** the interface navigates to that user's card.
3. **Given** a user's email is displayed in the list or on the card, **When** an administrator clicks the copy icon next to the email, **Then** the email address is copied to the clipboard and visual feedback confirms the copy.
4. **Given** an administrator has applied a search filter and navigated to a user card via [View], **When** they navigate back to the user list, **Then** the previously applied search filter is still active and the filtered results are shown.

---

### Edge Cases

- When a privileged user (or any user) is removed from a group, their completed survey instances remain counted; completions are user-level records independent of current group membership.
- When a user's space membership changes from multiple spaces to one, the spaces dropdown hides on the user's next page load; real-time mid-session hiding is not required.
- What happens if two groups share the same survey but one group's survey has been deleted—does prior completion still count?
- How does the spaces list update if the group creation process succeeds but the page was navigated away before the group was finalized?
- What happens when all surveys in a group are removed—does the Group Surveys section show an empty state or disappear?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST allow privileged accounts to be added as participants in user groups.
- **FR-002**: When a new user group is successfully created, the spaces navigation list MUST update to include the new group's space without requiring a manual page reload. The update MUST be triggered reactively after the successful group creation API response; a periodic polling mechanism MUST also run as a fallback to keep the spaces list in sync.
- **FR-003**: The spaces dropdown MUST be hidden from non-privileged users who are participants of exactly one space. Visibility is evaluated on page load; mid-session reactive hiding is not required.
- **FR-004**: The spaces dropdown MUST remain visible for privileged accounts regardless of how many spaces they belong to.
- **FR-005**: User group configuration MUST include a "Group Surveys" section listing all surveys assigned to that group.
- **FR-006**: Administrators MUST be able to reorder surveys within the Group Surveys section, with the order persisting and reflecting to group members on their next page load or navigation to the survey list; real-time push to active sessions is not required.
- **FR-007**: When a user belongs to multiple groups sharing the same survey instance (same instance ID, assigned to multiple groups via the `group_ids[]` array), the system MUST count one completion as fulfilling the requirement across all groups containing that instance, regardless of group-specific display settings. Survey completions are user-level records and MUST persist even if the user is subsequently removed from a group.
- **FR-008**: All survey response invalidation controls MUST be consolidated into a single "Invalidation" menu or grouped control area, visible to all administrator roles. Consolidation applies to both the response list view and the response detail view, where invalidation controls currently exist scattered across each.
- **FR-008a**: Higher-risk invalidation actions within the Invalidation menu (e.g., bulk or group-level invalidation) MUST be restricted to management roles (OWNER, MODERATOR, SUPERVISOR). QA_SPECIALIST and RESEARCHER roles MUST NOT be able to execute higher-risk invalidation actions, even though they are considered privileged for other purposes (e.g., group participant lookup, spaces dropdown visibility).
- **FR-009**: Every invalidation action MUST require confirmation via a popup dialog before executing.
- **FR-010**: The user group interface MUST provide a user lookup capability that can filter by privileged accounts. Privileged accounts for this lookup are users with roles: OWNER, MODERATOR, SUPERVISOR, QA_SPECIALIST, or RESEARCHER.
- **FR-011**: On the user management interface, navigation to a user card MUST only occur when the explicit [View] button is clicked, not on general row click.
- **FR-012**: A copy-to-clipboard icon MUST appear adjacent to user email addresses in both the user list and the user card.
- **FR-013**: The user list search filter MUST be preserved when navigating to a user card and returning to the list.

### Key Entities

- **User Group**: A collection of users (participants) with associated surveys and a defined order for those surveys.
- **Space**: A top-level organizational unit that groups users; determines visibility of the spaces dropdown.
- **Survey Instance**: A specific assigned occurrence of a survey; shared across groups when the same survey is assigned to multiple groups.
- **Privileged Account**: A user account with elevated (global) permissions. Encompasses roles: OWNER, MODERATOR, SUPERVISOR, QA_SPECIALIST, RESEARCHER. Privileged accounts can participate in groups as members and appear in privileged account lookup filters. Note: for destructive invalidation actions, only the subset of **management roles** (OWNER, MODERATOR, SUPERVISOR) have access — QA_SPECIALIST and RESEARCHER are privileged but not management.
- **Survey Response**: A completed survey submission by a user; subject to invalidation controls.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of privileged accounts can be added to user groups without errors, and they appear in group member lists.
- **SC-002**: The spaces list updates within 2 seconds of a new group being created, with no manual page reload required.
- **SC-003**: Non-privileged users in a single space never see the spaces dropdown on any page load.
- **SC-004**: Administrators can reorder surveys in the Group Surveys section in under 30 seconds, with order changes persisting across sessions.
- **SC-005**: A user completing a survey shared across groups is never prompted to complete the same survey instance more than once.
- **SC-006**: Zero invalidation controls exist outside the consolidated Invalidation menu; every invalidation triggers a confirmation dialog; higher-risk invalidation actions are inaccessible to standard administrators.
- **SC-007**: Administrators can locate any privileged account via the in-group lookup without navigating away from the group management interface.
- **SC-008**: 0% of row clicks (outside [View]) navigate to the user card; 100% of [View] button clicks navigate to the user card.
- **SC-009**: Search filter state is preserved in 100% of navigate-to-card-and-back flows.

## Assumptions

- "Privileged accounts" refers to users with system-wide elevated roles (e.g., admins, supervisors); the distinction from regular users is already tracked by the system.
- "Same survey" deduplication is based on survey instance ID. A single survey instance is assigned to multiple groups via the `group_ids[]` array on the instance record — this is the canonical "same survey across groups" pattern. Completing that instance once (identified by its instance ID + the user's pseudonymous ID) marks it complete for all groups sharing the instance, regardless of group-specific display settings. Schema-level deduplication (two separate instances of the same schema template) is out of scope.
- Survey reordering within a group only affects display order for group members; it does not change the underlying survey configuration.
- The spaces list at the top of the page is a navigation component already present; this feature requires it to refresh reactively.
- The copy-to-clipboard feature uses standard browser clipboard API with a visual toast or icon state change as confirmation.
- "Navigating back" to the user list (preserving search) covers both browser back-button navigation and in-app back navigation.
- Invalidation controls being consolidated does not change their underlying functionality—only their location in the UI.

## Clarifications

### Session 2026-03-10

- Q: What defines "the same survey" for cross-group deduplication? → A: Same survey instance ID (one instance assigned to multiple groups via group_ids[]); completing the instance once marks it complete in all groups sharing it. Schema-level deduplication (separate instances of the same template) is out of scope.
- Q: Which roles can access the Invalidation menu and execute invalidation actions? → A: All administrator roles can see and open the Invalidation menu; higher-risk invalidation actions within the menu are restricted to elevated/privileged roles.
- Q: Are "privileged accounts" (group membership) and "global privileged roles" (lookup filter) the same set of users? → A: Yes — same set; canonical term is "privileged accounts" used consistently across the spec.
- Q: How should the spaces list refresh be triggered after group creation? → A: Post-API reactive update (re-fetch on successful group creation API response) plus periodic polling as a fallback to keep the list in sync.
- Q: When a survey order is saved in Group Surveys, when does it take effect for group members? → A: Next page load or navigation — real-time push to active sessions is not required.
- Q: Which views currently have invalidation controls that need consolidating? → A: Both the response list view and the response detail view.
- Q: When a user is removed from a group, do their prior survey completions still count for cross-group deduplication? → A: Yes — completions persist as user-level records, independent of current group membership.
- Q: When a user's space membership drops to one, when does the spaces dropdown hide? → A: Next page load only — real-time mid-session hiding is not required.

### Session 2026-03-11 (Bug Fixes Applied During Implementation)

- Q: Which roles can execute higher-risk invalidation actions (FR-008a)? → A: Management roles only: OWNER, MODERATOR, SUPERVISOR. QA_SPECIALIST and RESEARCHER can open the Invalidation menu and execute low-risk actions (e.g., invalidate a single response), but are blocked from higher-risk bulk/permanent invalidation. The implementation uses a distinct `isManagementRole` predicate (subset of `isPrivilegedRole`) for this gate.
- Q: Which roles are included in "privileged accounts" for user group participant lookup (FR-010)? → A: OWNER, MODERATOR, SUPERVISOR, QA_SPECIALIST, and RESEARCHER. The backend user lookup query explicitly filters to these five roles.
- Q: How should criteria feedback sentinel values (checkbox-only ratings with no detail text) be stored? → A: The criterion key name (e.g. `'relevance'`) is stored as the `feedback_text` value when a criteria checkbox is checked without accompanying detail text. The DB-level `CHECK (LENGTH(feedback_text) >= 10)` constraint was dropped via migration to allow these short sentinel keys (migration 031).
- Q: What happens to review sessions that were previously in `in_progress` status when the expiration concept is removed? → A: Migration 030 (remove review expiration) Step 1 now correctly identifies and closes sessions stuck with `in_progress` assignments — the EXISTS predicate was widened to include `in_progress` (not only `pending`) and the NOT EXISTS guard now only exempts `completed` assignments, preventing permanently-stuck sessions.
- Q: How should the session message archive operation behave under concurrent calls? → A: The archive operation is atomic and idempotent: it runs inside a single DB transaction with a `SELECT ... FOR UPDATE` lock on the session row, checks `messages_archived_at IS NULL` before proceeding, writes both the content wipe and the timestamp stamp in the same transaction, and inserts an audit log entry. A second concurrent call will either block until the first commits (then find `messages_archived_at` already set and no-op) or fail safely on rollback.

### Session 2026-03-11 (Cross-Feature — publicHeader Migration Impact)

- Q: Should the Group Surveys section in GroupSurveyList display a per-survey Instructions (publicHeader) field from the survey instance? → A: No — the `publicHeader` field was removed from `SurveyInstance` and `SurveyInstanceListItem` types as part of spec-022 migration (chat-types v1.12.0). `GroupSurveyList.tsx` had a `publicHeader: string | null` field on its `SurveyItem` interface and a conditional display block that was removed. Instructions are now schema-level only and not surfaced in the group survey list.
- Q: Should the Instance Create Form (used when launching a survey from a group) include an Instructions field? → A: No — `InstanceCreateForm.tsx` previously had a `publicHeader` state, setter, and textarea. These were removed as part of the spec-022 migration. Instructions are authored once in the schema editor; instance creation inherits them from the schema snapshot automatically.

## Out of Scope

- Creating or configuring new user roles or permission levels (this spec assumes existing role types).
- Bulk group creation or bulk group survey assignment.
- Changing how surveys are assigned to groups (only reordering within a group is in scope).
- Cross-group survey analytics or reporting on deduped completions.
- Email notifications triggered by group changes or survey assignments.

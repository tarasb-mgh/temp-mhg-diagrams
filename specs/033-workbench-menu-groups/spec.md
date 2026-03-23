# Feature Specification: Workbench Sidebar Menu Reorganization

**Feature Branch**: `033-workbench-menu-groups`  
**Created**: 2026-03-17  
**Status**: Draft  
**Jira Epic**: [MTB-783](https://mentalhelpglobal.atlassian.net/browse/MTB-783)  
**Input**: User description: "Reorganize the workbench sidebar menu — make it logical, group related items together, based on deep analysis and 029-workbench-ux-wayfinding findings."

## Clarifications

### Session 2026-03-17

- Q: Should the Reviews group (7 items) be split into sub-groups or kept as a single group? → A: Keep Reviews as a single group. Permission filtering ensures most roles see only 2-4 items, so effective size per role is manageable.
- Q: Should legacy research routes (`/workbench/research-legacy`) and redirect routes (`/workbench/research`) be addressed in this reorganization? → A: Out of scope. Legacy routes remain hidden, existing redirects continue to work. Cleanup is a separate code-hygiene task.
- Q: What should the default expand/collapse state be for menu groups on first load? → A: All groups expanded by default. Maximizes discoverability for new and infrequent users. Power users can collapse groups and the state persists.
- Q: Where should the Group Resources contextual block appear relative to the new static menu groups? → A: At the bottom, after all static groups and before Settings. Maintains stable item positions and clear separation between static and context-dependent navigation.
- Q: Should the Supervision route (`/workbench/review/supervision/:sessionReviewId`) be surfaced in the Reviews sidebar group? → A: No. Supervision is a detail view reached from within a review session (requires `:sessionReviewId`), not a standalone browsable destination.

## Background: Current State Analysis

### Current Menu Structure (from `WorkbenchLayout.tsx`)

The sidebar currently renders 15 navigation items in three loosely defined sections:

**Main nav (flat list):**

1. Dashboard — always visible
2. User Management — `WORKBENCH_USER_MANAGEMENT`
3. Group management — `WORKBENCH_USER_MANAGEMENT` or survey permissions
4. Tester Tag Access — `TESTER_TAG_MANAGE`
5. Approvals — `WORKBENCH_USER_MANAGEMENT`
6. Privacy Controls — `WORKBENCH_PRIVACY`
7. Survey Schemas — `SURVEY_SCHEMA_MANAGE`
8. Survey Instances — `SURVEY_INSTANCE_MANAGE` or `SURVEY_INSTANCE_VIEW`
9. Settings — always visible

**Research section (collapsible):**

10. Research & Moderation — `REVIEW_ACCESS`
11. Reports & Analytics — `REVIEW_REPORTS`
12. Tag Management — `TAG_MANAGE`

**Group resources (separate block, contextual):**

13. Group Dashboard — `WORKBENCH_GROUP_DASHBOARD`
14. Group Users — `WORKBENCH_GROUP_USERS`
15. Group Chats — `WORKBENCH_GROUP_RESEARCH` or `WORKBENCH_USER_MANAGEMENT`
16. Group Surveys — survey permissions + active group (dynamic)

### Identified Problems (from 029 Baseline + Code Analysis)

1. **No logical grouping in the main section**: Dashboard, User Management, Group management, Tester Tag Access, Approvals, Privacy Controls, Survey Schemas, Survey Instances, and Settings are in a flat list with no visual or conceptual grouping. Users must scan 9+ items to find what they need.

2. **Inconsistent naming**: "User Management" vs "Group management" (capitalization mismatch), "Research & Moderation" (combines two concepts), "Tester Tag Access" (unclear purpose), "Privacy Controls" (vague scope).

3. **Related items are scattered**: Survey Schemas and Survey Instances are separated from Group Surveys. User Management and Approvals are related but not grouped. Tester Tag Access is an admin tool buried among top-level items.

4. **Duplicate iconography**: Users icon is used for User Management, Group management, and Group Users — no visual differentiation. FileBarChart is used for Reports, Survey Schemas, Survey Instances, and Group Surveys — 4 items sharing one icon.

5. **Missing routes in sidebar**: Several important routes exist but have no sidebar entry (Review Dashboard, Team Dashboard, Escalation Queue, Deanonymization Panel, Review Configuration). Users can only reach them by knowing the URL or navigating from within review flow.

6. **Group section feels disconnected**: The Group resources block has a different visual treatment but no clear explanation of why it exists separately or how it relates to the main Group management item.

7. **029 Finding F5 (P1)**: Navigation hierarchy is not validated against discoverability and return-path outcomes. Prior functional passes miss that users still get lost.

8. **029 Target IA Gap**: The 029 spec proposed a target IA (Dashboard, Reviews, Surveys, Groups, Settings, Help and Guidance) but it was never implemented as a concrete menu restructuring spec.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Grouped Sidebar Navigation (Priority: P1)

A workbench user in any role (owner, admin, reviewer, researcher, group-admin) opens the sidebar and immediately understands the menu organization through clearly labeled groups, consistent naming, and distinct icons — without needing to scan every item to find what they need.

**Why this priority**: The flat, ungrouped main section is the primary source of navigation confusion identified in 029. Grouping is the highest-impact change that reduces cognitive load for every role.

**Independent Test**: A user can identify which group contains a target feature within 3 seconds of opening the sidebar, and reaches the target in 2 clicks or fewer (open group → click item).

**Acceptance Scenarios**:

1. **Given** a user opens the workbench sidebar, **When** they look at the menu, **Then** items are organized into visually distinct groups with clear group headings.
2. **Given** a user wants to manage surveys, **When** they look at the sidebar, **Then** all survey-related items (schemas, instances) are under one "Surveys" group.
3. **Given** a user wants to review chat sessions, **When** they look at the sidebar, **Then** review-related items (queue, reports, tags) are under one "Reviews" group.
4. **Given** a user has limited permissions, **When** a group has zero visible items for their role, **Then** the entire group heading is hidden — no empty groups appear.

---

### User Story 2 - Consistent Naming and Iconography (Priority: P1)

Menu items use clear, concise, non-overlapping labels and distinct icons so that each item's purpose is immediately apparent and no two items look the same.

**Why this priority**: Inconsistent naming and duplicate icons compound the flat-list problem and create uncertainty about which item does what — especially for new users.

**Independent Test**: Each menu item has a unique icon and a label that distinguishes it from all other items without requiring tooltip or context.

**Acceptance Scenarios**:

1. **Given** a user reads the sidebar labels, **When** they compare "User Management" and "Group management", **Then** both use consistent capitalization and phrasing style.
2. **Given** a user sees the sidebar icons, **When** they compare any two visible items, **Then** no two items share the same icon.
3. **Given** a user encounters "Tester Tag Access", **When** they read the label, **Then** it clearly conveys its function (e.g., "Tester Tags" or "Tag Access Control").

---

### User Story 3 - Collapsible Groups with Persistent State (Priority: P2)

Each menu group can be collapsed or expanded by clicking its heading, and the collapse state persists across page navigation within the same session so users can customize their view.

**Why this priority**: Once items are grouped, power users benefit from collapsing groups they don't use frequently to reduce visual noise — but this is a refinement, not a prerequisite for usability.

**Independent Test**: A user collapses the "Surveys" group, navigates to another page, and returns — the "Surveys" group remains collapsed.

**Acceptance Scenarios**:

1. **Given** a user clicks a group heading, **When** the group is expanded, **Then** it collapses and hides its child items.
2. **Given** a user has collapsed a group, **When** they navigate to another page and return, **Then** the group remains collapsed.
3. **Given** a user is on a page belonging to a collapsed group, **When** the sidebar renders, **Then** the group auto-expands to show the active item.

---

### User Story 4 - Surfacing Hidden Review Sub-Routes (Priority: P3)

Important review management routes (Review Dashboard, Team Dashboard, Escalation Queue, Review Configuration) that currently have no sidebar entries become discoverable through the Reviews group, so users don't need to know URLs.

**Why this priority**: These routes exist and are used, but their absence from the sidebar creates dead-end navigation. This is a cleanup task that builds on the grouping work.

**Independent Test**: A user with appropriate permissions can navigate to Review Dashboard, Team Dashboard, Escalation Queue, and Review Configuration through the sidebar.

**Acceptance Scenarios**:

1. **Given** a user has `REVIEW_ACCESS` permission, **When** they expand the Reviews group, **Then** they see "Review Dashboard" as a navigable item.
2. **Given** a user has `REVIEW_TEAM_DASHBOARD` permission, **When** they expand the Reviews group, **Then** they see "Team Dashboard" as a navigable item.
3. **Given** a user has `REVIEW_ESCALATION` permission, **When** they expand the Reviews group, **Then** they see "Escalations" as a navigable item.
4. **Given** a user has `REVIEW_CONFIGURE` permission, **When** they expand the Reviews group, **Then** they see "Review Settings" as a navigable item.

---

### Edge Cases

- What happens when a user's permissions result in exactly one group with one item? The group heading still renders for consistency, the item is directly clickable.
- How does the sidebar behave on mobile (off-canvas drawer)? Groups work identically; collapse/expand state is shared with desktop.
- What happens if a new menu item is added in the future? The group system must support adding items to existing groups without structural changes.
- How does the active group context interact with menu groups? The "Group" section (contextual group resources) remains a separate visual block as it depends on the selected group scope, not a static menu group.

## Proposed Menu Structure

### Group 1: Home (no heading, always visible)

| Item | Route | Icon | Permissions |
| ---- | ----- | ---- | ----------- |
| Dashboard | `/workbench` | LayoutDashboard | none |

### Group 2: Reviews (collapsible heading)

| Item | Route | Icon | Permissions |
| ---- | ----- | ---- | ----------- |
| Review Queue | `/workbench/review` | ClipboardCheck | `REVIEW_ACCESS` |
| Review Dashboard | `/workbench/review/dashboard` | BarChart3 | `REVIEW_ACCESS` |
| Reports | `/workbench/review/reports` | FileBarChart | `REVIEW_REPORTS` |
| Team Dashboard | `/workbench/review/team` | UsersRound | `REVIEW_TEAM_DASHBOARD` |
| Escalations | `/workbench/review/escalations` | AlertTriangle | `REVIEW_ESCALATION` |
| Review Tags | `/workbench/review/tags` | Tags | `TAG_MANAGE` |
| Review Settings | `/workbench/review/config` | Wrench | `REVIEW_CONFIGURE` |

### Group 3: Surveys (collapsible heading)

| Item | Route | Icon | Permissions |
| ---- | ----- | ---- | ----------- |
| Survey Templates | `/workbench/surveys/schemas` | FileText | `SURVEY_SCHEMA_MANAGE` |
| Survey Instances | `/workbench/surveys/instances` | ListChecks | `SURVEY_INSTANCE_MANAGE` or `SURVEY_INSTANCE_VIEW` |

### Group 4: People & Access (collapsible heading)

| Item | Route | Icon | Permissions |
| ---- | ----- | ---- | ----------- |
| Users | `/workbench/users` | UserCog | `WORKBENCH_USER_MANAGEMENT` |
| Groups | `/workbench/groups` | Building2 | `WORKBENCH_USER_MANAGEMENT` or survey permissions |
| Approvals | `/workbench/approvals` | UserCheck | `WORKBENCH_USER_MANAGEMENT` |
| Tester Tags | `/workbench/users/tester-tags` | TagIcon | `TESTER_TAG_MANAGE` |
| Privacy | `/workbench/privacy` | ShieldCheck | `WORKBENCH_PRIVACY` |

### Contextual Block: Group Resources (after static groups, before Settings; visible only when a group is selected)

| Item | Route | Icon | Permissions |
| ---- | ----- | ---- | ----------- |
| Group Dashboard | `/workbench/group` | LayoutDashboard | `WORKBENCH_GROUP_DASHBOARD` |
| Group Users | `/workbench/group/users` | Users | `WORKBENCH_GROUP_USERS` |
| Group Chats | `/workbench/group/sessions` | MessageSquare | `WORKBENCH_GROUP_RESEARCH` or `WORKBENCH_USER_MANAGEMENT` |
| Group Surveys | `/workbench/groups/:groupId/surveys` | ClipboardList | survey permissions + active group |

### Group 5: Settings (no heading, bottom-pinned, always below Group Resources)

| Item | Route | Icon | Permissions |
| ---- | ----- | ---- | ----------- |
| Settings | `/workbench/settings` | Settings | none |

### Visual Order Summary

1. Dashboard (ungrouped, top)
2. Reviews (collapsible group)
3. Surveys (collapsible group)
4. People & Access (collapsible group)
5. Group Resources (contextual block, only when group selected)
6. Settings (ungrouped, bottom-pinned)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The sidebar MUST organize navigation items into named groups with visible group headings.
- **FR-002**: Each group MUST be independently collapsible/expandable via its heading.
- **FR-003**: Collapse state MUST persist within the same browser session (page navigation does not reset it).
- **FR-004**: If a user navigates to a page belonging to a collapsed group, the group MUST auto-expand to reveal the active item.
- **FR-005**: If a group contains zero items visible to the current user's permissions, the entire group (heading included) MUST be hidden.
- **FR-006**: All sidebar menu items MUST have unique icons — no two items may share the same icon component.
- **FR-007**: All sidebar labels MUST use consistent capitalization (Title Case) and concise phrasing (2-3 words maximum).
- **FR-008**: The sidebar MUST surface routes for Review Dashboard, Team Dashboard, Escalations, and Review Settings under the Reviews group for users with appropriate permissions.
- **FR-009**: The "Group Resources" contextual block MUST remain visually distinct from static menu groups and continue to depend on the active group selection.
- **FR-010**: The sidebar MUST maintain mobile-responsive behavior (off-canvas drawer with hamburger toggle) unchanged from current implementation.
- **FR-011**: Dashboard and Settings items MUST remain ungrouped — Dashboard at the top, Settings pinned near the bottom.
- **FR-012**: The sidebar MUST support adding new items to existing groups without requiring structural code changes (data-driven group assignment).
- **FR-013**: "Survey Schemas" MUST be renamed to "Survey Templates" to match user mental model.
- **FR-014**: All label changes MUST be applied across all supported locales (en, uk, ru).
- **FR-015**: All menu groups MUST default to expanded state on first visit (no prior user interaction). User-initiated collapse state MUST override the default for subsequent navigations within the session.

### Key Entities

- **NavGroup**: A named collection of navigation items with a label key, collapsible state, and ordered child items.
- **NavItem**: A sidebar entry with path, label key, icon, and permission requirements (unchanged from current `NavItemConfig`).
- **GroupCollapseState**: A session-scoped map of group identifiers to boolean collapsed/expanded state.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users identify the correct menu group for a target feature in under 3 seconds (measured via task-based usability test with 5-role matrix).
- **SC-002**: 100% of sidebar items have unique icons — verified by automated test asserting no duplicate icon component names in the nav items array.
- **SC-003**: All menu labels use Title Case and are 3 words or fewer — verified by automated lint or snapshot test.
- **SC-004**: Zero empty groups render for any tested role in the 5-role matrix (owner, admin, reviewer, researcher, group-admin).
- **SC-005**: Review Dashboard, Team Dashboard, Escalations, and Review Settings are reachable via sidebar for users with matching permissions — verified by Playwright navigation test.
- **SC-006**: Group collapse state survives 5 consecutive page navigations without resetting — verified by manual or automated session persistence test.
- **SC-007**: 90% first-click success rate (user clicks into the correct group on first attempt) across 5-role usability test, matching the 029 spec `three_click_discoverability >= 90%` gate.

## Assumptions

- The existing `WorkbenchLayout.tsx` component and `navItems` array are the single source of truth for sidebar rendering — no other component generates sidebar entries.
- The existing permission model (`Permission` enum, `user.permissions` array) is sufficient and does not need new permission types for this feature.
- Collapse state can be stored in component state or a lightweight store (e.g., `workbenchStore`) without backend persistence — session-level persistence is sufficient.
- The Deanonymization Panel route (`/workbench/review/deanonymization`) is intentionally excluded from the sidebar due to its sensitive nature and should remain accessible only via in-flow navigation.
- The Supervision route (`/workbench/review/supervision/:sessionReviewId`) is excluded from the sidebar because it is a detail-level view requiring a specific session review ID, not a standalone destination.
- Legacy research routes (`/workbench/research-legacy`, `/workbench/research`) are out of scope — they remain hidden with existing redirects intact. Cleanup is a separate initiative.
- Localization keys will be added for new group headings and renamed items in all three locales (en, uk, ru).

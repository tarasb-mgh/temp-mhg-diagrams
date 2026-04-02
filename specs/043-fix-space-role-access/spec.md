# Feature Specification: Fix Workbench Space Selector Role-Based Access

**Feature Branch**: `043-fix-space-role-access`
**Created**: 2026-04-02
**Status**: Draft
**Jira Epic**: [MTB-1243](https://mentalhelpglobal.atlassian.net/browse/MTB-1243)
**Input**: User description: "Fix workbench Space selector to respect global role access when switching spaces. Global role holders (Researcher, Supervisor, Moderator, Owner) must be able to switch to any Space via the workbench header dropdown without being redirected or reset to a different Space."

## Summary

Global role holders (Researcher, Supervisor, Moderator, Owner) cannot reliably switch to a Space they are not a member of using the workbench header dropdown. When a non-member global role holder selects a Space, the system falls back to the first Space where they have membership. This contradicts the two-tier access model defined in spec 034 (Global Role Group Access), which specifies that users with a global role at or above Researcher level should access any Space without membership. The fix must correct the space-switching flow end-to-end — from the group list endpoint through active group assignment to the frontend selector — so that global role holders can freely navigate between all Spaces.

## Clarifications

### Session 2026-04-02

- Q: Where should the system redirect a downgraded user (Researcher → QA Specialist) who has multiple membership Spaces? → A: Clear active group, show empty state ("select a Space" prompt) — do not auto-select any Space.
- Q: What should the frontend do when the server returns an error (500, timeout) during Space switch? → A: Stay on the current Space and display an error notification — do not reset or retry.

## User Scenarios & Testing

### User Story 1 — Global Role Holder Switches to Non-Member Space (Priority: P1)

A Researcher (or Supervisor, Moderator, Owner) opens the workbench and uses the Space selector dropdown in the header. They select a Space they are not a member of. The system must set that Space as their active group and display its content without redirecting to a different Space.

**Why this priority**: This is the core broken behavior. Global role holders cannot perform their cross-group oversight duties if the Space selector resets their choice.

**Independent Test**: Log in as a Researcher with membership in Space A only. Open the Space selector. Verify all Spaces are listed. Select Space B (non-member). Verify Space B is now active and its content (review queue, dashboard) is displayed. Refresh the page and verify Space B remains active.

**Acceptance Scenarios**:

1. **Given** a Researcher who is a member of Space A only, **When** they open the Space selector dropdown, **Then** all non-archived Spaces in the system are listed (not just Space A).
2. **Given** a Researcher selects Space B (non-member) from the dropdown, **When** the selection completes, **Then** Space B is set as the active Space and its workbench content is displayed.
3. **Given** a Researcher has switched to Space B (non-member), **When** they refresh the page, **Then** Space B remains the active Space (no reset to Space A).
4. **Given** an Owner with zero group memberships, **When** they select any Space from the dropdown, **Then** that Space becomes active and its content is displayed.

---

### User Story 2 — QA Specialist Remains Membership-Gated (Priority: P1)

A QA Specialist must continue to see only the Spaces they are explicitly assigned to. The fix must not grant QA Specialists implicit access to non-member Spaces.

**Why this priority**: This is the critical negative test ensuring the fix does not over-broaden access. QA Specialists are the workbench role explicitly excluded from cross-group access.

**Independent Test**: Log in as a QA Specialist with membership in Space A only. Open the Space selector. Verify only Space A is listed. Attempt to access Space B via direct URL manipulation. Verify access is denied.

**Acceptance Scenarios**:

1. **Given** a QA Specialist who is a member of Space A only, **When** they open the Space selector dropdown, **Then** only Space A is listed.
2. **Given** a QA Specialist with no group memberships, **When** they open the Space selector, **Then** the selector shows no Spaces and no group-scoped features are accessible.
3. **Given** a QA Specialist attempts to set Space B (non-member) as active via any means, **When** the request reaches the server, **Then** the server denies the request.

---

### User Story 3 — Space Switch Persists Across Navigation (Priority: P2)

After a global role holder switches to a non-member Space, navigating between workbench sections (review queue, dashboard, configuration, surveys) must retain the selected Space context. The active Space must not reset when the user moves between pages.

**Why this priority**: A Space switch that resets on navigation renders the fix ineffective for real workflows where users move between sections.

**Independent Test**: Log in as a Supervisor with no memberships. Select Space C. Navigate to review queue, then to dashboard, then to group configuration. Verify Space C remains active throughout.

**Acceptance Scenarios**:

1. **Given** a Supervisor has selected Space C (non-member), **When** they navigate from the review queue to the dashboard, **Then** Space C remains the active Space.
2. **Given** a Supervisor has selected Space C (non-member), **When** they navigate to group configuration, **Then** the configuration for Space C is displayed.
3. **Given** a Supervisor has selected Space C, **When** they return to the review queue from configuration, **Then** the review queue is filtered to Space C.

---

### User Story 4 — Role Downgrade Revokes Implicit Access (Priority: P3)

When a user's global role is downgraded from Researcher (or above) to QA Specialist (or below), they must immediately lose the ability to switch to Spaces they are not members of. No manual intervention or session restart should be required beyond the role change taking effect.

**Why this priority**: Security boundary enforcement. Less frequent than normal operations but critical for access control correctness.

**Independent Test**: Log in as a Researcher. Select a non-member Space. Have an admin downgrade the user to QA Specialist. Refresh the workbench. Verify the non-member Space is no longer accessible and the user is redirected to a member Space (or empty state).

**Acceptance Scenarios**:

1. **Given** a user was Researcher with Space B active (non-member), **When** their role is downgraded to QA Specialist, **Then** on next request the system denies access to Space B, clears the active group, and presents an empty state prompting the user to select a Space from their membership list.
2. **Given** a user with Researcher role AND explicit membership in Space A has Space B (non-member) active, **When** their role is downgraded to QA Specialist, **Then** they lose access to Space B but retain access to Space A via membership.

---

### User Story 5 — Unified Space Selector with All Spaces (Priority: P1)

The header Space selector MUST include an "All Spaces" option as the first entry. When selected, group-scoped pages (Review Queue, Group Dashboard, Group Users, Group Sessions) show cross-group data or a "Select a Space" prompt. The Review Queue's independent local scope dropdown is removed — the header selector becomes the single source of truth for Space context across the entire workbench.

**Why this priority**: Without a unified selector, changing Space in the header has no effect on review pages, creating a confusing split-brain UX.

**Acceptance Scenarios**:

1. **Given** a global role holder opens the Space selector, **When** they select "All Spaces", **Then** the Review Queue shows sessions from all groups, and Group Dashboard shows "Select a Space to view group details".
2. **Given** a user selects "All Spaces" and refreshes the page, **Then** "All Spaces" remains selected (no auto-revert to a membership group).
3. **Given** a user is on the Review Queue with "All Spaces" selected, **Then** no local scope dropdown is visible on the Review Queue page (removed).
4. **Given** a user switches from "All Spaces" to a specific Space, **Then** the Review Queue re-fetches and shows only that Space's sessions.

---

### User Story 6 — Responsive Header Redesign (Priority: P2)

The workbench header MUST be fully functional across mobile (<640px), tablet (640–1024px), and desktop (>1024px) viewports. The Space selector must be accessible at every breakpoint. Header controls should use compact icon-only rendering to save horizontal space.

**Why this priority**: Currently the Space selector is completely invisible below 1024px — tablet and mobile users cannot switch spaces at all.

**Independent Test**: Open workbench on a 375px-wide viewport. The Space selector must be accessible (via sidebar/burger menu). PII toggle shows as icon only with tooltip. Language selector shows flag only.

**Acceptance Scenarios**:

1. **Given** a user is on a mobile viewport (<640px), **When** they open the burger menu, **Then** the Space selector dropdown is visible inside the sidebar, above navigation items.
2. **Given** a user is on a tablet viewport (640–1024px), **When** they view the header, **Then** the Space selector is visible in the header bar (not hidden).
3. **Given** any viewport, **When** the user views the PII toggle, **Then** it renders as an icon only (Eye/EyeOff) with a tooltip on hover showing "PII Masked" or "PII Visible".
4. **Given** any viewport, **When** the user views the language selector, **Then** only the flag emoji is displayed; the dropdown options still show full language names.
5. **Given** a tablet or mobile viewport, **When** the user opens the sidebar, **Then** the user's name, role, and Sign Out button are visible at the bottom of the sidebar.
6. **Given** any viewport, **When** the user clicks "Workbench / Admin Panel" in the sidebar header, **Then** they navigate to the workbench dashboard (`/workbench`).
7. **Given** PII masking is enabled, **When** the logged-in user's own name is displayed, **Then** it is NOT masked (the user should see their own name clearly).

---

### Edge Cases

- **Archived Space selection**: If a global role holder attempts to select an archived Space, the system must deny the switch and display an appropriate message. Archived Spaces must not appear in the dropdown.
- **All-Spaces-archived scenario**: If all Spaces are archived, every user (including Owners) sees an empty Space selector with no group-scoped features available.
- **Concurrent role change**: If a user's role changes while they have the workbench open, the next server-side request must enforce the new role. No stale session state should bypass access checks.
- **Single Space for QA Specialist**: A QA Specialist with exactly one Space membership should have the dropdown hidden (per spec 023 behavior) — this fix must not alter that UX.
- **Dual-path user**: A user who is both a member of Space A and holds a global role should retain Space A access via membership if their global role is later removed.
- **Server error during Space switch**: If the server returns an error (500, timeout, network failure) when the user attempts to switch Space, the frontend must remain on the currently active Space and display an error notification. The dropdown selection must revert to the previous active Space.

## Requirements

### Functional Requirements

- **FR-001**: The Space selector dropdown MUST list all non-archived Spaces in the system for users whose global role is Researcher, Supervisor, Moderator, or Owner.
- **FR-002**: The Space selector dropdown for QA Specialists and Group Admins MUST list only Spaces where the user has explicit active membership.
- **FR-003**: When a global role holder (Researcher or above) selects a Space they are not a member of, the system MUST set that Space as their active group without falling back to a different Space.
- **FR-004**: The active group assignment MUST validate only that the target Space exists and is not archived for global role holders — membership MUST NOT be checked.
- **FR-005**: The active group assignment for QA Specialists and Group Admins MUST continue to validate explicit membership before allowing the switch.
- **FR-006**: The active Space selection MUST persist across page refreshes and workbench section navigation.
- **FR-007**: All access authorization MUST be enforced server-side. Client-side filtering alone is insufficient and constitutes a security gap.
- **FR-008**: When a user's global role is downgraded below Researcher level, they MUST immediately lose the ability to switch to or remain on non-member Spaces on the next server-side request.
- **FR-009**: The chat frontend MUST remain unchanged. Group membership continues to gate chat participation for all users.
- **FR-010**: The fix MUST NOT alter the interface or behavior of the existing access resolution function. It must remain compatible with future activation of the Dynamic Permissions Engine (spec 035).
- **FR-011**: Archived Spaces MUST NOT appear in the Space selector dropdown for any user role.
- **FR-012**: If the Space switch request fails (server error, timeout, network failure), the frontend MUST remain on the previously active Space, revert the dropdown selection, and display an error notification to the user.
- **FR-013**: When a user's role is downgraded and their active Space is no longer accessible, the system MUST clear the active group and present an empty state prompting the user to select a Space — it MUST NOT auto-select a Space on behalf of the user.
- **FR-014**: The header Space selector MUST include an "All Spaces" option. When selected, `activeGroupId` is set to null. Group-scoped pages show a "Select a Space" prompt; the Review Queue shows sessions from all groups.
- **FR-015**: The Review Queue MUST NOT have its own independent scope dropdown. It MUST read `activeGroupId` from the auth store (set by the header selector).
- **FR-016**: The Team Dashboard MUST show a local membership-based dropdown when multiple memberships exist. With zero memberships, it shows an empty state. It does NOT use the header `activeGroupId` directly — it uses the user's memberships.
- **FR-017**: The Space selector MUST be accessible at all viewports. On mobile (<640px), it MUST appear inside the sidebar/burger menu. On tablet (640–1024px) and desktop, it MUST appear in the header bar.
- **FR-018**: The PII toggle MUST render as an icon only (Eye/EyeOff) at all viewports, with a tooltip showing the current state on hover.
- **FR-019**: The language selector MUST display only the flag emoji as the selected value. The dropdown options MUST retain full language names.
- **FR-020**: The logged-in user's own display name MUST NOT be masked by the PII toggle. PII masking applies to other users' data, not to the current user's identity.
- **FR-021**: The "Workbench / Admin Panel" title in the sidebar MUST be clickable and navigate to `/workbench` (dashboard).
- **FR-022**: On tablet and mobile viewports, user name, role, and Sign Out MUST be rendered inside the sidebar, not in the header bar.

### Key Entities

- **Active Group**: The currently selected Space for a user's workbench session. Stored per-user and determines which Space's data is displayed across all group-scoped workbench features.
- **Global Role Access**: The ability for users with roles at or above Researcher level to access any non-archived Space without explicit membership. Determined at request time based on the user's current role.
- **Group Membership**: An explicit record linking a user to a Space with active status. Remains the sole mechanism for chat participation and for QA Specialist/Group Admin workbench access.

## Success Criteria

### Measurable Outcomes

- **SC-001**: A Researcher, Supervisor, Moderator, or Owner with zero group memberships can switch to and remain on 100% of non-archived Spaces in the system via the Space selector.
- **SC-002**: QA Specialists with membership in exactly one Space see only that Space in the selector (0% of non-member Spaces visible).
- **SC-003**: After switching to a non-member Space, the selected Space persists through 100% of workbench section navigations and page refreshes within the same session.
- **SC-004**: Role downgrade from Researcher to QA Specialist results in loss of non-member Space access within the first subsequent server request — zero stale-session access.
- **SC-005**: Zero regressions in chat frontend behavior — group membership continues to gate chat participation identically to pre-fix behavior.
- **SC-006**: Space switching completes (dropdown selection to content display) within 2 seconds under normal conditions.
- **SC-007**: "All Spaces" selection persists across page refresh — does not revert to a membership group.
- **SC-008**: Review Queue has zero local scope dropdowns — only the header Space selector controls filtering.
- **SC-009**: On a 375px viewport, 100% of header actions (PII toggle, language switch, Space switch, sign out) are accessible.
- **SC-010**: PII toggle renders as icon-only at all viewports — no text label visible in the header.
- **SC-011**: Language selector shows flag-only in header at all viewports — full names only in dropdown options.

## Assumptions

- The existing role constant that defines global-access-eligible roles (Researcher, Supervisor, Moderator, Owner) is correctly defined and stable.
- The access resolution function correctly implements the two-tier access model. The bug is in the space-switching flow (active group assignment and frontend fallback logic), not in the access resolution function itself.
- The role-check helper function is available and returns the correct boolean for each role.
- The number of Spaces in the system is small enough that listing all Spaces in the dropdown is practical without pagination.
- The workbench frontend uses a reactive state management approach where setting the active group triggers content reload for the selected Space.
- Group Admin role is correctly excluded from global-access-eligible roles — Group Admins have elevated permissions only within their member Spaces, not platform-wide.

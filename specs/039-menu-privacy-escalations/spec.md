# Feature Specification: Move Privacy to Security & Hide Escalations

**Feature Branch**: `039-menu-privacy-escalations`
**Created**: 2026-03-24
**Status**: Draft
**Jira Epic**: [MTB-984](https://mentalhelpglobal.atlassian.net/browse/MTB-984)
**Input**: User description: "Move Privacy Controls from People & Access to Security group (bottom of group). Hide Escalations from sidebar menu — do NOT delete the page itself."

## Background

Spec 033-workbench-menu-groups established the current sidebar structure with four collapsible groups: Reviews, Surveys, People & Access, and (via 035) Security. Two adjustments are needed to align the menu with updated organizational intent:

1. **Privacy Controls** currently lives under **People & Access** (`/workbench/privacy`, permission `WORKBENCH_PRIVACY`). It belongs semantically under the **Security** group introduced in 035-dynamic-permissions-engine, as privacy management is a security concern, not a people/access concern.

2. **Escalations** currently lives under **Reviews** (`/workbench/review/escalations`, permission `REVIEW_ESCALATION`). The page and route must remain functional (direct URL access, links from review flows), but the sidebar menu item should be hidden. The escalation workflow is accessed through in-flow navigation within reviews, not as a standalone destination.

### Current State (post-033 + 035)

**People & Access** group:
- Users — `/workbench/users`
- Groups — `/workbench/groups`
- Approvals — `/workbench/approvals`
- Tester Tags — `/workbench/users/tester-tags`
- **Privacy** — `/workbench/privacy` ← moving out

**Reviews** group:
- Review Queue — `/workbench/review`
- Review Dashboard — `/workbench/review/dashboard`
- Reports — `/workbench/review/reports`
- Team Dashboard — `/workbench/review/team`
- **Escalations** — `/workbench/review/escalations` ← hiding
- Review Tags — `/workbench/review/tags`
- Review Settings — `/workbench/review/config`

**Security** group (from 035):
- Security Dashboard — `/workbench/security`
- Principal Groups — `/workbench/security/principal-groups`
- Permissions — `/workbench/security/permissions`
- Assignments — `/workbench/security/assignments`
- Effective Viewer — `/workbench/security/effective`

### Target State

**People & Access** group:
- Users — `/workbench/users`
- Groups — `/workbench/groups`
- Approvals — `/workbench/approvals`
- Tester Tags — `/workbench/users/tester-tags`

**Reviews** group:
- Review Queue — `/workbench/review`
- Review Dashboard — `/workbench/review/dashboard`
- Reports — `/workbench/review/reports`
- Team Dashboard — `/workbench/review/team`
- Review Tags — `/workbench/review/tags`
- Review Settings — `/workbench/review/config`

**Security** group:
- Security Dashboard — `/workbench/security`
- Principal Groups — `/workbench/security/principal-groups`
- Permissions — `/workbench/security/permissions`
- Assignments — `/workbench/security/assignments`
- Effective Viewer — `/workbench/security/effective`
- **Privacy** — `/workbench/privacy` ← added at bottom

## User Scenarios & Testing

### User Story 1 — Privacy Controls Appears Under Security (Priority: P1)

An administrator navigates to the workbench sidebar and finds Privacy under the Security group (as the last item) instead of under People & Access. The route, page functionality, and permission (`WORKBENCH_PRIVACY`) remain unchanged.

**Why this priority**: This is the primary structural change. Privacy is a security function and should be discoverable alongside other security tools.

**Independent Test**: Log in as a user with `WORKBENCH_PRIVACY` permission. Verify "Privacy" appears under the Security group in the sidebar, not under People & Access. Click it and verify the privacy page loads at `/workbench/privacy`.

**Acceptance Scenarios**:

1. **Given** a user with `WORKBENCH_PRIVACY` permission and Security group visibility, **When** they view the sidebar, **Then** "Privacy" appears as the last item under the Security group.
2. **Given** a user with `WORKBENCH_PRIVACY` permission but WITHOUT Security group visibility (not Owner / Security Admin), **When** they view the sidebar, **Then** "Privacy" is NOT visible (it inherits the Security group's visibility requirement).
3. **Given** a user navigating to `/workbench/privacy` directly via URL, **When** they have `WORKBENCH_PRIVACY` permission, **Then** the page loads normally regardless of sidebar visibility.
4. **Given** the People & Access group after this change, **When** any user views it, **Then** "Privacy" no longer appears in that group.

---

### User Story 2 — Escalations Hidden from Sidebar (Priority: P1)

A reviewer no longer sees "Escalations" in the sidebar under the Reviews group. The escalation page at `/workbench/review/escalations` remains fully functional — it can be accessed via direct URL or through in-flow navigation links within the review workflow.

**Why this priority**: The menu item removal is equally important and independent of the Privacy move. Both changes ship together for a single deployment.

**Independent Test**: Log in as a user with `REVIEW_ESCALATION` permission. Verify "Escalations" does NOT appear in the Reviews sidebar group. Navigate to `/workbench/review/escalations` directly and verify the page loads and functions normally.

**Acceptance Scenarios**:

1. **Given** a user with `REVIEW_ESCALATION` permission, **When** they view the Reviews group in the sidebar, **Then** "Escalations" is NOT listed.
2. **Given** a user navigating to `/workbench/review/escalations` via direct URL, **When** they have `REVIEW_ESCALATION` permission, **Then** the page loads and functions exactly as before.
3. **Given** an in-flow link to escalations from within a review session, **When** the user clicks it, **Then** the escalation page loads normally.
4. **Given** the route definition for `/workbench/review/escalations`, **When** inspecting the codebase, **Then** the route and component remain intact — only the sidebar `NavItemConfig` entry is removed.

---

### Edge Cases

- What happens if a user has `WORKBENCH_PRIVACY` but is not a member of Owners/Security Admins principal groups? They cannot see the Security group, so Privacy becomes invisible in the sidebar. They can still access `/workbench/privacy` via direct URL if the route-level permission check passes. This is the intended behavior — Privacy is now a Security-group feature.
- What if the Security group from 035 is not yet deployed? Privacy should remain in People & Access until 035 is deployed. This spec depends on 035 being in place.
- What happens to the Reviews group if all P3 items are eventually hidden? The group remains visible as long as at least one item passes permission filtering (FR-005 from 033).

## Requirements

### Functional Requirements

- **FR-001**: The "Privacy" nav item MUST be removed from the `peopleAccess` nav group configuration.
- **FR-002**: The "Privacy" nav item MUST be added as the last item in the `security` nav group configuration, preserving its existing `path` (`/workbench/privacy`), `icon` (`ShieldCheck`), and `permission` (`WORKBENCH_PRIVACY`).
- **FR-003**: The "Escalations" nav item MUST be removed from the `reviews` nav group configuration.
- **FR-004**: The route for `/workbench/review/escalations` MUST remain functional — the route definition, component, and permission guard MUST NOT be modified or removed.
- **FR-005**: The route for `/workbench/privacy` MUST remain functional — the route definition, component, and permission guard MUST NOT be modified or removed.
- **FR-006**: No localization key changes are required — the existing `workbench.nav.privacy` and `workbench.nav.escalations` keys remain valid.
- **FR-007**: The sidebar auto-expand behavior (FR-004 from 033) MUST work correctly: if a user navigates to `/workbench/privacy`, the Security group auto-expands; the People & Access group does NOT auto-expand for this path.

### Key Entities

- **NavGroupConfig** (unchanged): The `security` group gains one item; the `peopleAccess` group loses one item; the `reviews` group loses one item.
- **NavItemConfig** (unchanged): The Privacy item's config object moves between groups with no property changes. The Escalations item's config object is removed from the group array.

## Dependencies

- **035-dynamic-permissions-engine**: The Security nav group must exist before Privacy can be moved into it. This spec MUST be implemented after 035's sidebar changes are deployed.
- **033-workbench-menu-groups**: The grouped sidebar structure (NavGroupConfig, collapse state, permission filtering) must be in place.

## Success Criteria

### Measurable Outcomes

- **SC-001**: "Privacy" appears as the last item in the Security sidebar group for users with both Security group visibility and `WORKBENCH_PRIVACY` permission — verified by Playwright navigation test.
- **SC-002**: "Privacy" does NOT appear in the People & Access sidebar group for any user — verified by Playwright sidebar inspection.
- **SC-003**: "Escalations" does NOT appear in the Reviews sidebar group for any user — verified by Playwright sidebar inspection.
- **SC-004**: `/workbench/review/escalations` loads successfully when accessed via direct URL by a user with `REVIEW_ESCALATION` permission — verified by Playwright navigation test.
- **SC-005**: `/workbench/privacy` loads successfully when accessed via direct URL by a user with `WORKBENCH_PRIVACY` permission — verified by Playwright navigation test.
- **SC-006**: The Security sidebar group auto-expands when the user is on `/workbench/privacy` — verified by manual or Playwright test.

# Feature Specification: Restore Missing Workbench Navigation Links

**Feature Branch**: `053-restore-nav-links`
**Created**: 2026-04-15
**Status**: Draft
**Input**: User description: "Restore missing sidebar navigation links (Tag Center, Settings on mobile) — make them user-friendly using the design system"

## Background

During the Workbench MVP refactor (feature 048, merged 2026-04-09), two navigation links were unintentionally dropped from the sidebar:

1. **Tag Center** (`/workbench/tags`) — the route and page exist and function correctly, but no sidebar link points to it. Previously located in the "People & Access" navigation group.
2. **Settings** (`/workbench/settings`) — visible on desktop via the avatar dropdown menu, but completely inaccessible on mobile/tablet because the avatar dropdown only renders on `lg:` breakpoints and the sidebar button was removed.

Both pages are fully functional — only the navigation paths are missing, making them unreachable through normal UI interaction.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Tag Center is discoverable in the sidebar (Priority: P1)

An operator (admin, moderator, reviewer) opens the Workbench and needs to manage user tags or review tags. They look in the sidebar for a "Tag Center" link, find it in the "People & Access" section alongside Users, Groups, and Approvals, and navigate there with one click.

**Why this priority**: Tag Center is a core operator workflow for managing user and review tags. Without a sidebar link it is effectively hidden — operators cannot discover it unless they know the URL.

**Independent Test**: Log in as an operator with `TAG_MANAGE` permission, open the sidebar, confirm "Tag Center" appears in "People & Access" group, click it, confirm the Tag Center page loads.

**Acceptance Scenarios**:

1. **Given** an operator with `TAG_MANAGE` permission is logged in, **When** they view the sidebar, **Then** "Tag Center" appears in the "People & Access" navigation group with an appropriate icon.
2. **Given** an operator without `TAG_MANAGE` permission is logged in, **When** they view the sidebar, **Then** "Tag Center" does not appear.
3. **Given** an operator clicks "Tag Center" in the sidebar, **When** the page loads, **Then** the Tag Center page renders correctly and the sidebar item is highlighted as active.
4. **Given** an operator is on a mobile device, **When** they open the sidebar menu, **Then** "Tag Center" is visible and tappable with sufficient touch target size (minimum 44px height).

---

### User Story 2 — Settings accessible on all screen sizes (Priority: P1)

A user on a mobile or tablet device needs to access their Workbench settings (preferences, profile). They open the sidebar and find a "Settings" link at the bottom, same as on desktop.

**Why this priority**: Settings is a universal navigation target that must be accessible on every device. Currently mobile users have no path to reach Settings since the avatar dropdown is desktop-only.

**Independent Test**: Open the Workbench on a mobile viewport (< 768px), open the hamburger sidebar, confirm Settings appears and navigates to the Settings page.

**Acceptance Scenarios**:

1. **Given** a user on a mobile device, **When** they open the sidebar, **Then** a "Settings" link is visible.
2. **Given** a user on a tablet, **When** they open the sidebar, **Then** a "Settings" link is visible.
3. **Given** a user on a desktop, **When** they view the sidebar, **Then** a "Settings" link is visible (in addition to the avatar dropdown path).
4. **Given** a user taps "Settings" in the mobile sidebar, **When** the page loads, **Then** the Settings page renders and the sidebar closes.

---

### User Story 3 — Navigation follows design system conventions (Priority: P2)

All restored links follow the existing Workbench navigation design patterns: same icon style (Lucide, 20px/`w-5 h-5`), same interaction states (hover, active highlight), same spacing and typography, same permission-gating behavior.

**Why this priority**: Visual and interaction consistency with the existing sidebar ensures operators don't experience jarring differences. The design system is already established — this story ensures the restored links conform to it.

**Independent Test**: Compare the rendered Tag Center and Settings sidebar items against existing items (Users, Groups, Review Queue) for consistent visual treatment: icon size, padding, font, colors, hover/active states.

**Acceptance Scenarios**:

1. **Given** the Tag Center link is in the sidebar, **When** the user hovers over it, **Then** it shows the same hover style as other sidebar items (neutral-50 background).
2. **Given** the user is on the Tag Center page, **When** they view the sidebar, **Then** the Tag Center item has the active style (primary-50 background, primary-700 text, font-medium).
3. **Given** the Settings link is in the sidebar, **When** compared to other sidebar items, **Then** it uses the same icon size (w-5 h-5), minimum touch height (44px on mobile, 40px on desktop), and text size.

---

### Edge Cases

- What happens when the sidebar nav group containing Tag Center is collapsed? Tag Center should follow the same expand/collapse behavior as other items in the group.
- What happens if a user navigates directly to `/workbench/tags` via URL? The sidebar should highlight the Tag Center item as active (this already works via existing `isActive` logic).
- What happens if the user has no permissions for any item in the "People & Access" group? The entire group should be hidden, consistent with existing filtering behavior.

## Clarifications

### Session 2026-04-15

- Q: Where should Settings be placed in the sidebar? → A: Standalone button at the bottom of the navigation list, before "Back to Chat" (restoring pre-048 behavior).
- Q: Should Settings remain in the avatar dropdown after restoring the sidebar link? → A: Yes, keep both paths. Settings is accessible from both the sidebar and the avatar dropdown (standard dual-path UX).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The sidebar MUST include a "Tag Center" link in the "People & Access" navigation group, positioned before the "Users" link.
- **FR-002**: The Tag Center link MUST be permission-gated to users with the `TAG_MANAGE` capability, consistent with the route guard.
- **FR-003**: The sidebar MUST include a "Settings" link as a standalone button at the bottom of the navigation list, before "Back to Chat", visible to all authenticated Workbench users regardless of screen size.
- **FR-004**: The Settings link MUST be visible and functional on mobile (< 768px), tablet (768–1023px), and desktop (≥ 1024px) viewports.
- **FR-005**: Both restored links MUST use Lucide icons at 20px (`w-5 h-5`) consistent with other sidebar items.
- **FR-006**: Both restored links MUST have minimum touch target height of 44px on mobile and 40px on desktop, matching existing sidebar items.
- **FR-007**: The Tag Center link MUST show the active highlight state when the user is on `/workbench/tags` or any sub-path.
- **FR-008**: The Settings link MUST show the active highlight state when the user is on `/workbench/settings`.
- **FR-009**: Both links MUST support the existing i18n translation keys for labels (existing keys: `workbench.nav.tagCenter`, `workbench.nav.settings`).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of users with `TAG_MANAGE` permission see the Tag Center link in the sidebar on all viewports (mobile, tablet, desktop).
- **SC-002**: 100% of authenticated Workbench users can access Settings from the sidebar on any device without needing the avatar dropdown.
- **SC-003**: Both restored links pass visual consistency check against existing sidebar items: identical icon size, spacing, hover states, and active states.
- **SC-004**: No regression in existing navigation behavior — all previously visible sidebar items remain unchanged.

## Assumptions

- The Tag Center translation key `workbench.nav.tagCenter` already exists in all locale files (en, uk, ru) from the original 042 implementation.
- The Settings translation key `workbench.nav.settings` already exists in all locale files.
- The `Tags` icon from Lucide (used in the original Tag Center nav entry) is the appropriate icon choice.
- No new routes or pages need to be created — only sidebar navigation entries are added.
- The avatar dropdown Settings path on desktop remains unchanged (additive, not replacement). Both sidebar and dropdown paths coexist as dual-path navigation.

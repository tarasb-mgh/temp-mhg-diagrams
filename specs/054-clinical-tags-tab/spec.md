# Feature Specification: Clinical Tags Tab in Tag Center

**Feature Branch**: `054-clinical-tags-tab`  
**Created**: 2026-04-15  
**Status**: Draft  
**Input**: User description: "Add a Clinical Tags tab to /workbench/tags with full tag management flow, consistent with existing User Tags and Review Tags tabs, using the design system and existing components."

## Clarifications

### Session 2026-04-15

- Q: Should the expert assignment panel show all users or only expert-role users? → A: Only users with expert role; the panel filters automatically.
- Q: Should expert tag assignments auto-save per toggle or use a batch Save button? → A: Auto-save per toggle, consistent with User Tags assignment behavior.
- Q: Should the MVP bug (draft clinical tag comments saving to wrong table) be fixed in this feature scope? → A: Yes, include the fix — draft comment table name must be corrected to match the canonical table used by migrations and the clinical tag service.
- Q: How should the clinical tag create form work given clinical tags have both name and description? → A: Single-line input for name only (consistent with User Tags / Review Tags). Description is added afterward via a separate expandable editor on the tag row.
- Q: Should existing description be visible in collapsed tag row or hidden until expanded? → A: Always visible as grey text next to the tag name; the expand action is only for editing.
- Q: Implementation approach — lift & adapt, generic factory, or embed as-is? → A: Lift & Adapt — new ClinicalTagDefinitionsPanel and ClinicalTagAssignmentsPanel built from scratch following existing panel patterns; existing panels remain untouched.
- Q: Should Tag Center use tabs, or sub-routes with landing page and breadcrumb dropdown? → A: Sub-routes (`/tags/user`, `/tags/review`, `/tags/clinical`) plus a landing page at `/tags` with 3 summary cards, plus a breadcrumb dropdown for quick switching between sections.

## Summary

Integrate clinical tag management into the unified Tag Center at `/workbench/tags` as a dedicated section alongside User Tags and Review Tags. Currently, clinical tag administration lives on a separate, isolated page (`/workbench/review/clinical-tags`) with its own layout and UX. This feature consolidates it into Tag Center, providing a consistent admin experience for creating, editing, and deleting clinical tags that drive the reviewer-to-expert assessment pipeline. The new section also introduces expert assignment management — linking clinical tags to experts so that tagged sessions route correctly for clinical expertise review.

As part of this work, Tag Center navigation is restructured from in-page tabs to sub-routes with a landing page and breadcrumb-based section switching, improving discoverability, deep-linking, and overall navigation clarity.

## User Scenarios & Testing

### User Story 1 — Manage Clinical Tag Definitions from Tag Center (Priority: P1)

An administrator navigates to Tag Center, enters the Clinical Tags section, and manages clinical tag definitions (create, edit, delete) without navigating to a separate page. The experience mirrors the patterns established in User Tags and Review Tags — inline creation, edit actions, expandable description editor, and consistent visual treatment.

**Why this priority**: Clinical tags are the backbone of the reviewer→expert pipeline. Administrators must be able to manage them efficiently. Today's separate page breaks discoverability and consistency.

**Independent Test**: An admin creates a clinical tag "ANXIETY", adds a description via the expandable editor, verifies session usage count is shown, and deletes an unused tag — all from the Clinical Tags section without leaving Tag Center.

**Acceptance Scenarios**:

1. **Given** an admin with TAG_MANAGE permission navigates to `/workbench/tags/clinical`, **When** the page loads, **Then** they see the list of all clinical tag definitions with name, description (grey text), and session usage count.
2. **Given** an admin in the Clinical Tags section, **When** they enter a tag name in the single-line input and click Create, **Then** a new clinical tag definition is created with no description and immediately visible in the list.
3. **Given** a clinical tag exists, **When** the admin clicks the rename action (pencil icon), **Then** the name becomes an inline editable input; saving updates the name.
4. **Given** a clinical tag exists, **When** the admin clicks the description action icon, **Then** an expandable area appears below the tag row with a text input pre-populated with the existing description (or empty if none) and a confirm button; saving updates the description.
5. **Given** a clinical tag with an existing description, **Then** the description is always visible as grey text in the collapsed tag row, without needing to expand.
6. **Given** a clinical tag with no active session references, **When** the admin clicks delete, **Then** a confirmation dialog appears; upon confirmation the tag is removed.
7. **Given** a clinical tag referenced in active reviews (sessionCount > 0), **When** the admin attempts to delete, **Then** deletion is blocked with a message explaining the tag is in use and showing the session count.
8. **Given** the Clinical Tags section is rendered on desktop, **Then** the definitions panel follows the same left-column layout pattern as the User Tags definitions panel, with scrollable list within the viewport.
9. **Given** the Clinical Tags section is rendered on mobile, **Then** the definitions stack vertically with natural page scroll and no horizontal overflow.

---

### User Story 2 — Assign Clinical Tags to Experts (Priority: P1)

An administrator assigns clinical tags to expert users so that sessions tagged during review are routed to the correct expert for clinical assessment. This follows the same two-column pattern as User Tags: definitions on the left, expert assignments on the right.

**Why this priority**: Without expert-to-tag assignment in Tag Center, the admin must use a separate workflow to link experts to their areas of expertise. Consolidating this completes the clinical tagging admin workflow.

**Independent Test**: Admin selects an expert from the user list, toggles the "PTSD" clinical tag checkbox, verifies it auto-saves, and confirms the assignment persists on page reload.

**Acceptance Scenarios**:

1. **Given** an admin on the Clinical Tags section, **When** definitions are loaded, **Then** a right-side panel shows a searchable list containing only users with expert role; non-expert users do not appear.
2. **Given** the admin selects an expert user, **When** the user is selected, **Then** checkboxes appear for each active clinical tag showing current assignment state.
3. **Given** the admin checks/unchecks a clinical tag for an expert, **When** the toggle occurs, **Then** the expert-tag assignment is auto-saved immediately and the checkbox state reflects the persisted result.
4. **Given** the admin searches for an expert by name or email, **When** partial text is entered, **Then** results filter case-insensitively.
5. **Given** a clinical tag is deleted while assigned to an expert, **Then** the assignment is removed accordingly (the tag cannot be deleted if it has active session references, but orphan expert assignments are cleaned up).

---

### User Story 3 — Tag Center Navigation Redesign with Landing Page (Priority: P1)

Tag Center is restructured from in-page tabs to a route-based architecture with a landing page at `/workbench/tags`, dedicated sub-routes for each section (`/tags/user`, `/tags/review`, `/tags/clinical`), and a breadcrumb dropdown for quick section switching.

**Why this priority**: Adding a third section to the existing tab-based UI creates discoverability and navigation challenges. Route-based navigation provides deep linking, clearer breadcrumbs, and a landing page that orients administrators immediately.

**Independent Test**: Navigate to Tag Center via sidebar; land on the overview page with 3 cards; click Clinical Tags card; verify URL is `/workbench/tags/clinical`; use breadcrumb dropdown to switch to User Tags; verify URL updates to `/workbench/tags/user`; click "Tags" in breadcrumb; return to landing page.

**Acceptance Scenarios**:

1. **Given** an admin clicks "Tag Center" in the sidebar navigation, **When** the page loads, **Then** they see the landing page at `/workbench/tags` with three summary cards (User Tags, Review Tags, Clinical Tags).
2. **Given** the landing page, **When** the admin clicks a card, **Then** they navigate to the corresponding sub-route (e.g., `/workbench/tags/clinical`).
3. **Given** the admin is inside a Tag Center section, **When** they look at the breadcrumb, **Then** it shows `Workbench › Tags › [Section Name ▾]` where the last segment is a dropdown selector.
4. **Given** the breadcrumb dropdown, **When** the admin clicks it, **Then** they see all three sections and can switch directly without returning to the landing page.
5. **Given** the admin is inside a section, **When** they click "Tags" in the breadcrumb, **Then** they return to the landing page.
6. **Given** the landing page cards, **Then** each card displays the section name, a brief description, and summary statistics (tag count, assignment/expert count where applicable).
7. **Given** the landing page rendered on mobile, **Then** the three cards stack vertically with natural page scroll.

---

### User Story 4 — Deprecate Standalone Clinical Tag Admin Page (Priority: P2)

After the Clinical Tags section is fully functional in Tag Center, the standalone `/workbench/review/clinical-tags` page is removed from navigation and the route redirects to the Clinical Tags section.

**Why this priority**: Maintaining two admin surfaces for the same feature causes confusion and maintenance overhead, but removing the old page is lower priority than delivering the new one.

**Independent Test**: Navigate to `/workbench/review/clinical-tags` and verify redirect to `/workbench/tags/clinical`; verify the sidebar no longer links to the old page.

**Acceptance Scenarios**:

1. **Given** the old clinical tag admin route, **When** a user navigates to it directly, **Then** they are redirected to `/workbench/tags/clinical`.
2. **Given** the sidebar navigation, **When** rendered for an admin, **Then** no link to the standalone clinical tag admin page exists.

---

### User Story 5 — Fix MVP Draft Comment Persistence Bug (Priority: P1)

The draft persistence layer for clinical tag comments writes to the wrong database table, causing draft comments to be silently lost. This is corrected as part of the clinical tags consolidation.

**Why this priority**: Data loss bug that affects the clinical review workflow. Must be fixed before the feature is considered complete.

**Independent Test**: A reviewer saves a draft clinical tag comment during a review session; reload the page; verify the draft comment is restored from persistence.

**Acceptance Scenarios**:

1. **Given** a reviewer adds a clinical tag comment during a review, **When** the draft is auto-saved, **Then** the comment is persisted to the canonical comments table.
2. **Given** a persisted draft comment, **When** the review session is reloaded, **Then** the draft comment is restored correctly.

---

### Edge Cases

- Admin creates a clinical tag with a name that already exists — system prevents duplication with a clear error message. Duplicate detection is case-insensitive ("Anxiety" is treated as a duplicate of "ANXIETY").
- Admin has TAG_MANAGE permission but no experts exist in the system — expert assignment panel shows an empty state with guidance.
- Network failure during tag creation — error banner appears, form state is preserved so the user can retry.
- Concurrent admin edits the same tag — last write wins, no silent data loss; stale-state feedback if detectable.
- Clinical tag is deleted in a concurrent session while another admin is viewing it — list refreshes on next action; no ghost entries persist.
- Admin with TAG_MANAGE permission but without broader user-management permissions — can still search and assign expert tags within the Clinical Tags context.
- Expert user has their role changed while they have clinical tag assignments — assignments remain until explicitly removed; no automatic cleanup on role change.
- Admin navigates directly to `/workbench/tags/clinical` via bookmark — page loads correctly without going through landing page first.
- Landing page summary statistics fail to load — cards still render with section name and description; stats show a fallback state.

## Requirements

### Functional Requirements

**Tag Center Navigation:**

- **FR-001**: Tag Center MUST be restructured into route-based navigation with a landing page at `/workbench/tags` and dedicated sub-routes: `/workbench/tags/user`, `/workbench/tags/review`, `/workbench/tags/clinical`.
- **FR-002**: The landing page MUST display three summary cards — one per section — each showing the section name, a brief description, and section-specific summary statistics: User Tags card shows tag count and assignment count; Review Tags card shows tag count; Clinical Tags card shows tag count and expert count.
- **FR-003**: Breadcrumbs within a Tag Center section MUST show `Workbench › Tags › [Section Name]` where the last segment is a dropdown that allows direct navigation to any other section.
- **FR-004**: Clicking "Tags" in the breadcrumb MUST navigate back to the landing page.
- **FR-005**: The sidebar navigation entry "Tag Center" MUST link to the landing page `/workbench/tags`.

**Clinical Tag Definitions:**

- **FR-006**: The Clinical Tags section MUST display all clinical tag definitions with name, optional description (visible as inline grey text), and session usage count.
- **FR-007**: Tag creation MUST use a single-line input for name only, with a Create button — consistent with User Tags and Review Tags creation patterns. Description is added afterward. Clinical tag names MUST be unique; the system MUST reject creation or rename operations that would produce a case-insensitive duplicate, and MUST display a clear error message to the operator.
- **FR-008**: Each tag row MUST provide a rename action (pencil icon) for inline name editing, and a separate description action icon that expands an inline editor pre-populated with the existing description (or empty if none) for adding or modifying the description, with a confirm control.
- **FR-009**: Authorized administrators MUST be able to delete clinical tag definitions that have zero session references.
- **FR-010**: Deletion of a clinical tag with active session references (sessionCount > 0) MUST be blocked, and the operator MUST see the session count and a message explaining why deletion is not allowed.
- **FR-011**: Clinical tag definitions MUST display a visual status indicator (active dot) consistent with tag status indicators in other sections. This indicator is included for visual consistency; it will become functional when clinical tag archiving is introduced in a future phase.

**Expert Assignments:**

- **FR-012**: The Clinical Tags section MUST include an expert assignment panel that lists only users with expert role and allows toggling clinical tag assignments per expert. Non-expert users MUST NOT appear in this panel.
- **FR-013**: Expert assignment panel MUST support case-insensitive partial-text search on expert name and email, scoped to expert-role users only.
- **FR-014**: Expert tag assignment toggles MUST auto-save immediately per checkbox change, consistent with User Tags assignment behavior.

**Layout and Responsiveness:**

- **FR-015**: The Clinical Tags section MUST use the same two-column layout as User Tags: definitions on the left, expert assignments on the right (on desktop breakpoints).
- **FR-016**: The Clinical Tags section MUST reuse existing Tag Center UI patterns (definition list items, create input row, action buttons, error banners, confirmation dialogs) for visual and behavioral consistency.
- **FR-017**: On desktop viewports, Tag Center sections MUST fit within the shell-aware single-viewport layout with internal panel scrolling (no outer page scroll).
- **FR-018**: On mobile viewports, Tag Center sections MUST use natural vertical scrolling with visually separated sections and no horizontal overflow. Landing page cards MUST stack vertically.

**Authorization and Deprecation:**

- **FR-019**: Authorization for clinical tag management MUST be based on TAG_MANAGE permission, consistent with the existing standalone clinical tag admin.
- **FR-020**: The existing standalone clinical tag admin page (`/workbench/review/clinical-tags`) MUST be deprecated by removing its navigation link and adding a redirect to `/workbench/tags/clinical`.
- **FR-021**: The Clinical Tags section MUST be localized with priority order: English, Ukrainian, Russian.

**Backend and Data Integrity:**

- **FR-022**: The backend MUST continue to support clinical tag definition operations without breaking existing integrations; UI-layer changes adapt to existing API contracts.
- **FR-023**: Expert-to-clinical-tag assignment MUST use the existing expert tag management API without requiring new endpoints.
- **FR-024**: The base set of clinical tags (ANXIETY, DEPRESSION, PTSD, BURNOUT) MUST be manageable — creatable, editable, and deletable — through the Clinical Tags section by an administrator.
- **FR-025**: The draft persistence layer for clinical tag comments MUST be corrected to write to the canonical comments table, fixing the MVP-era table name mismatch that causes draft comments to be lost.

### Key Entities

- **Clinical Tag Definition**: A named label with optional description, categorized as clinical, with an active lifecycle state. Carries a session usage count reflecting how many review sessions reference this tag.
- **Expert Tag Assignment**: Relationship between a user with expert role and one or more clinical tag definitions, determining which expert sees which tagged sessions in the expertise queue.
- **Tag Center Section**: A routed sub-page within Tag Center (user, review, or clinical), each with its own URL and content.
- **Tag Center Landing**: Overview page at `/workbench/tags` with summary cards for all sections, serving as the primary entry point and discovery surface.

## Non-Goals

- Changes to the reviewer-side clinical tag picker used during session review (ClinicalTagPicker component).
- Changes to the expert session view or expertise queue filtering logic.
- Changes to the clinical tag comment flow within review sessions (beyond the draft table bugfix).
- Bulk expert assignment operations in this phase.
- Clinical tag archiving (current backend supports only create/update/delete for clinical scope; archive can be added later if needed).
- Refactoring existing User Tags or Review Tags panels — new clinical panels are built from scratch following their patterns.

## Dependencies and Assumptions

- The existing clinical tag API (`/api/admin/clinical-tags`) and expert tag API (`/api/admin/users/:userId/expert-tags`) are stable and will not change contracts.
- TAG_MANAGE permission already gates clinical tag admin access; no new permissions are needed.
- The Tag Center component patterns (UserTagDefinitionsPanel, UserTagAssignmentsPanel, ReviewTagDefinitionsPanel) are reusable as reference for building clinical panels.
- Expert users are identifiable by their role field (`expert`); the assignment panel filters the user list to this role exclusively.
- The `ClinicalTagAdmin` component at `/workbench/review/clinical-tags` will be deprecated and eventually removed after migration.
- A known MVP bug exists where the draft route writes clinical tag comments to a mismatched table name; this will be corrected as part of this feature.
- The workbench shell supports breadcrumb customization including dropdown segments.

## Success Criteria

### Measurable Outcomes

- **SC-001**: Administrators can complete the full clinical tag lifecycle (create → add description → edit → verify usage count → delete unused) from the Clinical Tags section in Tag Center without navigating to any other page.
- **SC-002**: Administrators can assign and unassign clinical tags to expert users from the Clinical Tags section, and assignments are reflected in the expertise queue routing.
- **SC-003**: The Clinical Tags section passes visual consistency review — uses the same component patterns, spacing, error handling, and responsive behavior as User Tags and Review Tags sections.
- **SC-004**: Tag Center landing page displays all three sections with summary statistics and provides one-click navigation to each section.
- **SC-005**: Breadcrumb dropdown allows switching between Tag Center sections without returning to the landing page.
- **SC-006**: The old standalone clinical tag admin page is no longer accessible via navigation and redirects to the Clinical Tags section in Tag Center.
- **SC-007**: All three Tag Center sections remain functional and free of regression after the restructuring (existing E2E tests for User Tags and Review Tags continue passing).
- **SC-008**: The clinical tag happy flow (create → assign to expert → edit description → delete unused) completes end-to-end in the dev environment with no data loss, permission errors, or broken navigation.
- **SC-009**: Draft clinical tag comments persist correctly across page reloads after the bugfix.

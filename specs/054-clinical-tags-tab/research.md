# Research: Clinical Tags Tab in Tag Center

**Feature**: 054-clinical-tags-tab  
**Date**: 2026-04-15

## Decision 1: Expert User Search API

**Decision**: Use `GET /api/admin/users?role=expert&search=...` for the expert assignment panel.

**Rationale**: The admin users endpoint already supports `role` as a query parameter with full pagination and search. No backend change needed. The tag-center-specific user search (`/api/admin/tag-center/users`) does not support role filtering and is scoped to tag assignments — it's the wrong endpoint for this use case.

**Alternatives considered**:
- Extend `/api/admin/tag-center/users` with `role` parameter — rejected because the expert panel is semantically different from user-tag assignment panel, and the admin users endpoint already works.
- Create a dedicated expert listing endpoint — rejected as unnecessary when the existing endpoint covers the need.

## Decision 2: Breadcrumb Dropdown Implementation

**Decision**: Extend the existing `BreadcrumbSegment` type with an optional `menuItems` property and add dropdown rendering logic to the `Breadcrumb` component.

**Rationale**: The current breadcrumb (`Breadcrumb.tsx`) is flat — segments are labels or navigation buttons, no dropdown support. Adding dropdown requires:
1. Extending `BreadcrumbSegment` interface with `menuItems?: Array<{ label: string; path: string }>`.
2. Updating the `Breadcrumb` component render to show a dropdown button+menu for segments with `menuItems`.
3. Updating `useBreadcrumbs` or adding custom logic in the Tag Center layout to inject dropdown segments.

**Alternatives considered**:
- Use a separate tab/nav component instead of breadcrumb dropdown — rejected because it adds a UI element vs reusing existing breadcrumb space.
- Use React Router `NavLink` tabs within the page — rejected per brainstorm decision favoring breadcrumb-based navigation.

## Decision 3: Tag Center Routing Architecture

**Decision**: Convert the flat `path="tags"` route in WorkbenchShell to a nested route with layout outlet. Add child routes for `user`, `review`, `clinical`, and an `index` route for the landing page.

**Rationale**: WorkbenchShell already uses both sibling and nested route patterns. The nested approach is cleaner because:
- A shared Tag Center layout component can render the breadcrumb with dropdown and wrap `<Outlet />`.
- The landing page becomes the `index` route.
- Each section is a separate child route with its own component.
- Permission guard (TAG_MANAGE) stays at the parent route level.

**Implementation**:
```
<Route path="tags" element={<SubRouteGuard ...><TagCenterLayout /></SubRouteGuard>}>
  <Route index element={<TagCenterLanding />} />
  <Route path="user" element={<UserTagsSection />} />
  <Route path="review" element={<ReviewTagsSection />} />
  <Route path="clinical" element={<ClinicalTagsSection />} />
</Route>
```

**Alternatives considered**:
- Keep state-based mode switching and just add URL sync — rejected per brainstorm decision for full sub-routes.
- Sibling routes without a shared layout — rejected because we need shared breadcrumb dropdown across all sections.

## Decision 4: Landing Page Statistics Source

**Decision**: Derive landing card stats from existing list endpoints without new backend changes.

**Rationale**: All three definition list endpoints return arrays. Tag counts = `data.length`. Expert count is available via `GET /api/admin/users?role=expert&limit=1` → `meta.total`. No new endpoints needed for MVP.

**Statistics per card**:
- **User Tags**: tag count from `listTagCenterDefinitions({ scope: 'user' })` length.
- **Review Tags**: tag count from `listTagCenterDefinitions({ scope: 'review' })` length.
- **Clinical Tags**: tag count from `listClinicalTagDefinitions()` length; expert count from `GET /api/admin/users?role=expert&limit=1` → `meta.total`.

**Alternatives considered**:
- New backend aggregate endpoint — rejected as over-engineering for 3 small lists.
- Include user assignment count on User Tags card — deferred; requires backend change for a non-critical stat.

## Decision 5: Draft Bug Fix

**Decision**: Change table name in `review.draft.ts` line 143 from `clinical_tag_comments` to `review_clinical_tag_comments`.

**Rationale**: The migration (`054_048-clinical-tags.sql`) creates `review_clinical_tag_comments`. The service (`clinicalTag.service.ts`) reads/writes to `review_clinical_tag_comments`. But the draft route writes to `clinical_tag_comments` (non-existent table), and the error is silently caught. This is a one-line fix.

**Files affected**:
- `chat-backend/src/routes/review.draft.ts` line 143: change `clinical_tag_comments` → `review_clinical_tag_comments`

## Decision 6: Existing Panel Adaptation Strategy

**Decision**: Create new `ClinicalTagDefinitionsPanel` and `ClinicalTagAssignmentsPanel` components from scratch, using existing panel components as pattern reference. Existing panels remain untouched.

**Rationale**: The existing panels (`UserTagDefinitionsPanel`, `UserTagAssignmentsPanel`, `ReviewTagDefinitionsPanel`) have domain-specific logic tightly coupled to their UI. Extracting shared abstractions would require refactoring working code with regression risk. Building new panels following the same patterns is safer and maintains isolation.

**Key pattern differences for clinical panels**:
- Definition panel: adds description display (grey text), session count badge, expandable description editor, separate rename/description actions.
- Assignment panel: uses `GET /api/admin/users?role=expert` instead of `searchTagCenterUsers()`. Uses `expert-tags` API instead of `tag-center` assignment API.

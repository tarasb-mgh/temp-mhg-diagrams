# Implementation Plan: Clinical Tags Tab in Tag Center

**Branch**: `054-clinical-tags-tab` | **Date**: 2026-04-15 | **Spec**: [spec.md](spec.md)  
**Input**: Feature specification from `specs/054-clinical-tags-tab/spec.md`

## Summary

Integrate clinical tag administration into the unified Tag Center as a third section with route-based navigation. Restructure Tag Center from in-page tabs to sub-routes with a landing page and breadcrumb dropdown navigation. Build new clinical tag definition and expert assignment panels following existing UI patterns. Fix the MVP draft comment persistence bug.

Two repositories are affected: `workbench-frontend` (UI restructure + new components) and `chat-backend` (one-line bugfix). No new API endpoints are needed — all backend contracts are stable.

## Technical Context

**Language/Version**: TypeScript 5.x, React 18  
**Primary Dependencies**: React Router 6 (routing), react-i18next (localization), Tailwind CSS (styling via design system preset), @mentalhelpglobal/chat-frontend-common (auth, permissions), @mentalhelpglobal/chat-types (shared types)  
**Storage**: PostgreSQL (existing schema, no migrations)  
**Testing**: Vitest + React Testing Library (workbench-frontend), Vitest (chat-backend), Playwright regression suite (chat-ui)  
**Target Platform**: Web (desktop + mobile responsive)  
**Project Type**: Multi-repository web application  
**Performance Goals**: Standard admin UI — sub-second navigation, responsive interactions  
**Constraints**: No new backend endpoints; reuse existing API contracts; design system compliance (constitution VI-B)  
**Scale/Scope**: Low-volume admin feature (~10-50 tag definitions, ~5-20 expert users)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Spec-First Development | PASS | Spec complete with 7 clarifications, 25 FRs, 9 SCs |
| II. Multi-Repository Orchestration | PASS | Two repos: workbench-frontend, chat-backend. Cross-repo dependencies documented |
| III. Test-Aligned Development | PASS | Positive + negative tests per scenario; regression test for bugfix |
| IV. Branch and Integration | PASS | Feature branch `054-clinical-tags-tab` in all affected repos |
| V. Privacy and Security | PASS | No new PII handling; TAG_MANAGE permission already enforced |
| VI. Accessibility and i18n | PASS | Localization: en, uk, ru (FR-021); keyboard nav follows existing patterns |
| VI-B. Design System | PASS | Reuse existing design system tokens; no ad-hoc styling (FR-016) |
| VII. Split-Repository First | PASS | All changes in split repos only |
| IX. Responsive UX | PASS | Desktop two-column + mobile stack (FR-015, FR-017, FR-018) |
| X. Jira Traceability | PASS | Epic + Stories + Tasks to be created via /speckit.taskstoissues |
| XI. Documentation | DEFERRED | Confluence updates after dev deployment |
| XII. Release Engineering | N/A | Dev deployment only; production release requires owner approval |

## Project Structure

### Documentation (this feature)

```text
specs/054-clinical-tags-tab/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Phase 0: technical research
├── data-model.md        # Phase 1: entity definitions
├── quickstart.md        # Phase 1: setup guide
└── checklists/
    └── requirements.md  # Spec quality checklist
```

### Source Code Changes

```text
workbench-frontend/src/
├── features/workbench/
│   ├── WorkbenchShell.tsx          # MODIFY: restructure tags route to nested routes
│   ├── WorkbenchLayout.tsx         # MODIFY: update sidebar nav path, breadcrumb integration
│   ├── components/
│   │   └── Breadcrumb.tsx          # MODIFY: add dropdown segment support
│   └── tags/
│       ├── TagCenterPage.tsx       # MODIFY: extract to UserTagsSection + ReviewTagsSection
│       ├── TagCenterLayout.tsx     # NEW: shared layout with breadcrumb dropdown + Outlet
│       ├── TagCenterLanding.tsx    # NEW: landing page with 3 summary cards
│       ├── UserTagsSection.tsx     # NEW: wrapper for existing User Tags content
│       ├── ReviewTagsSection.tsx   # NEW: wrapper for existing Review Tags content
│       ├── ClinicalTagsSection.tsx # NEW: orchestrator for clinical panels
│       └── components/
│           ├── UserTagDefinitionsPanel.tsx      # UNCHANGED
│           ├── UserTagAssignmentsPanel.tsx      # UNCHANGED
│           ├── ReviewTagDefinitionsPanel.tsx     # UNCHANGED
│           ├── ClinicalTagDefinitionsPanel.tsx   # NEW: clinical tag CRUD panel
│           ├── ClinicalTagAssignmentsPanel.tsx   # NEW: expert assignment panel
│           └── TagCenterCard.tsx                 # NEW: reusable landing page card
├── services/
│   └── tagApi.ts                   # MODIFY: add expert user search helper

chat-backend/src/
└── routes/
    └── review.draft.ts             # MODIFY: fix table name (line 143)
```

**Structure Decision**: Multi-repository split-repo pattern. workbench-frontend receives all UI changes; chat-backend receives the one-line bugfix. No changes to chat-types, chat-frontend-common, or chat-frontend.

## Implementation Phases

### Phase 1: Backend Bugfix (chat-backend)

**Scope**: Fix draft clinical tag comment table name.

**Changes**:
- `src/routes/review.draft.ts` line 143: `clinical_tag_comments` → `review_clinical_tag_comments`

**Tests**:
- Regression test: save draft with clinical_tag_comment → verify row appears in `review_clinical_tag_comments`
- Negative test: verify saving with empty comment is handled gracefully

**Estimated effort**: Minimal (1 file, 1 line)

---

### Phase 2: Breadcrumb Enhancement (workbench-frontend)

**Scope**: Extend Breadcrumb component to support dropdown segments.

**Changes**:
- `src/features/workbench/components/Breadcrumb.tsx`:
  - Extend `BreadcrumbSegment` type with optional `menuItems: Array<{ label: string; path: string }>`
  - For segments with `menuItems`: render a button with dropdown indicator (▾) that opens a positioned menu
  - Menu items navigate via `useNavigate` on click
  - Close menu on outside click and escape key
  - Keyboard accessible: arrow keys navigate menu items

**Tests**:
- Positive: breadcrumb with dropdown renders menu items, clicking navigates
- Negative: segments without menuItems render as before (no regression)

**Design system compliance**: Use `neutral-*` colors for dropdown, `primary-*` for active item, `shadow-soft` for dropdown panel.

---

### Phase 3: Tag Center Routing Restructure (workbench-frontend)

**Scope**: Convert Tag Center from single-page with state-based tabs to nested routes with shared layout.

**Changes**:

1. **TagCenterLayout.tsx** (NEW):
   - Renders breadcrumb with dropdown segment for Tag Center sections
   - Renders `<Outlet />` for child routes
   - Manages section metadata (labels, paths) for breadcrumb dropdown
   - Shell-aware viewport layout (no outer scroll)

2. **WorkbenchShell.tsx** (MODIFY):
   - Replace flat `path="tags"` route with nested structure:
     ```
     <Route path="tags" element={<SubRouteGuard ...><TagCenterLayout /></SubRouteGuard>}>
       <Route index element={<TagCenterLanding />} />
       <Route path="user" element={<UserTagsSection />} />
       <Route path="review" element={<ReviewTagsSection />} />
       <Route path="clinical" element={<ClinicalTagsSection />} />
     </Route>
     ```
   - Add redirect from old `/review/clinical-tags` route to `/tags/clinical`

3. **WorkbenchLayout.tsx** (MODIFY):
   - Update sidebar nav item path from `/workbench/tags` to `/workbench/tags` (stays the same — landing page)
   - Update `isTagCenterRoute` check to match all `/workbench/tags/*` sub-routes for layout overflow handling

4. **UserTagsSection.tsx** (NEW):
   - Extracts User Tags mode logic from TagCenterPage into standalone routed component
   - Renders `UserTagDefinitionsPanel` + `UserTagAssignmentsPanel`
   - Manages its own state (definitions, users, assignments, rights)

5. **ReviewTagsSection.tsx** (NEW):
   - Extracts Review Tags mode logic from TagCenterPage into standalone routed component
   - Renders `ReviewTagDefinitionsPanel`
   - Manages its own state (definitions)

6. **TagCenterPage.tsx** (DEPRECATE):
   - After extraction, this file is no longer used. Keep temporarily as reference, remove in cleanup.

**Tests**:
- Navigation: landing → section → breadcrumb switch → back to landing
- Deep linking: direct URL to `/workbench/tags/clinical` loads correctly
- Redirect: `/workbench/review/clinical-tags` → `/workbench/tags/clinical`
- Regression: User Tags and Review Tags function identically after restructure

---

### Phase 4: Landing Page (workbench-frontend)

**Scope**: Tag Center entry page with 3 summary cards.

**Changes**:

1. **TagCenterLanding.tsx** (NEW):
   - Fetches stats from existing endpoints on mount:
     - User tag count: `listTagCenterDefinitions({ scope: 'user' })` → `data.length`
     - Review tag count: `listTagCenterDefinitions({ scope: 'review' })` → `data.length`
     - Clinical tag count: `listClinicalTagDefinitions()` → `data.length`
     - Expert count: `GET /api/admin/users?role=expert&limit=1` → `meta.total`
   - Renders 3 `TagCenterCard` components
   - Cards navigate to sub-routes on click
   - Mobile: cards stack vertically
   - Desktop: cards in a responsive grid

2. **TagCenterCard.tsx** (NEW):
   - Reusable card component: icon, title, description, stats, onClick
   - Design system: `card` class, `neutral-*` text, stats in `badge-*` style
   - Loading state: skeleton placeholder for stats
   - Error state: card renders without stats, no blocking error

3. **tagApi.ts** (MODIFY):
   - Add `searchExperts(query?: string)` helper that calls `GET /api/admin/users?role=expert&search=...`
   - Add `getExpertCount()` helper that calls `GET /api/admin/users?role=expert&limit=1` and returns `meta.total`

**Tests**:
- Positive: landing page renders 3 cards with stats
- Negative: stats API failure → cards render without stats
- Mobile: cards stack vertically

---

### Phase 5: Clinical Tags Section (workbench-frontend)

**Scope**: Core clinical tag management UI.

**Changes**:

1. **ClinicalTagsSection.tsx** (NEW):
   - Orchestrator component, same role as TagCenterPage was for modes
   - Manages clinical definitions state, expert users state, error state
   - Two-column layout on desktop, stacked on mobile
   - Renders `ClinicalTagDefinitionsPanel` (left) + `ClinicalTagAssignmentsPanel` (right)

2. **ClinicalTagDefinitionsPanel.tsx** (NEW):
   - Single-line create input (name only) + Create button
   - Tag list with:
     - Active dot indicator (always green for now)
     - Tag name as badge (violet accent)
     - Description as grey inline text (always visible if exists)
     - Session count as amber badge ("X sessions")
     - Action icons: ✏️ rename, 📝 description, 🗑 delete
   - Rename action: inline input replaces name, save/cancel
   - Description action: expandable row below tag with pre-populated text input + confirm
   - Delete: confirmation dialog, blocked if sessionCount > 0 with explanation
   - Duplicate name: case-insensitive check, error message on create/rename

3. **ClinicalTagAssignmentsPanel.tsx** (NEW):
   - Search input for expert users (calls `searchExperts(query)`)
   - Expert user list (left sidebar within panel)
   - Selected expert: checkboxes for each clinical tag
   - Auto-save per toggle (POST/DELETE expert-tags endpoint)
   - Empty state when no experts exist
   - Loading states for expert list and tag assignments

**API calls** (all via existing `tagApi.ts` helpers):
- `listClinicalTagDefinitions()` → definitions list
- `createClinicalTagDefinition({ name })` → create
- `updateClinicalTagDefinition(id, { name })` → rename
- `updateClinicalTagDefinition(id, { description })` → update description
- `deleteClinicalTagDefinition(id)` → delete (409 if in use)
- `searchExperts(query)` → expert user list (NEW helper)
- `GET/POST/DELETE /api/admin/users/:userId/expert-tags` → expert assignments

**Tests**:
- CRUD: create, rename, edit description, delete clinical tag
- Delete blocked: tag with sessionCount > 0 shows blocking message
- Expert assignment: toggle checkbox → auto-saved
- Expert search: partial text filtering
- Empty states: no tags, no experts
- Duplicate name: case-insensitive rejection

---

### Phase 6: Deprecation and Cleanup (workbench-frontend)

**Scope**: Remove old clinical tag admin page from navigation.

**Changes**:
- `WorkbenchShell.tsx`: route for `/review/clinical-tags` → `<Navigate to="/workbench/tags/clinical" replace />`
- Sidebar: remove any direct link to the old clinical tag admin page (if present in nav config)
- `ClinicalTagAdmin.tsx`: keep file but it's no longer routed to directly

**Tests**:
- Redirect from old URL works
- No sidebar link to old page

---

### Phase 7: Localization (workbench-frontend)

**Scope**: Add i18n keys for all new UI text.

**Priority order**: English → Ukrainian → Russian.

**Key namespaces**:
- `tagCenter.landing.*` — landing page cards
- `tagCenter.clinical.*` — clinical tag section
- `tagCenter.breadcrumb.*` — breadcrumb dropdown labels
- `tagCenter.modes.clinical` — section name

**Files**:
- `public/locales/en/translation.json`
- `public/locales/uk/translation.json`
- `public/locales/ru/translation.json`

---

### Phase 8: Testing and Validation (workbench-frontend, chat-backend)

**Scope**: Comprehensive test coverage per constitution III requirements.

**Unit tests (Vitest)**:
- Breadcrumb dropdown rendering and interaction
- TagCenterLanding stats loading and error handling
- ClinicalTagDefinitionsPanel CRUD operations
- ClinicalTagAssignmentsPanel expert search and toggle
- Routing: correct components render for each sub-route

**Regression tests**:
- Draft bugfix: clinical tag comment persists to correct table
- User Tags section: identical behavior after routing restructure
- Review Tags section: identical behavior after routing restructure

**Regression suite (YAML)**:
- Add clinical tag management test cases to `regression-suite/`
- Cover: create → assign expert → edit description → delete flow

## Cross-Repository Dependencies

```
chat-backend (Phase 1)
  └── bugfix complete, deployed to dev
       ↓
workbench-frontend (Phases 2-7)
  └── all UI changes, can develop in parallel
       ↓
Both deployed to dev → validation (Phase 8)
```

**Execution order**: Backend bugfix has no frontend dependency and should be merged first. Frontend phases 2-7 can proceed in parallel with backend deployment but should be validated against the fixed backend.

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Breadcrumb dropdown breaks existing breadcrumbs | High | Optional `menuItems` field; segments without it render unchanged |
| Routing restructure breaks User/Review Tags | High | Extract logic verbatim; regression tests before adding clinical |
| Expert user search performance with large user base | Low | Paginated endpoint with limit; admin feature, low concurrency |
| Landing page stats requests slow on large datasets | Low | Lists are small (<50 items); parallel fetch with loading skeletons |
| Breadcrumb dropdown not accessible | Medium | Keyboard navigation, focus trap, escape to close |

## Complexity Tracking

No constitution violations requiring justification.

# Quickstart: Clinical Tags Tab in Tag Center

**Feature**: 054-clinical-tags-tab  
**Date**: 2026-04-15

## Prerequisites

- Access to `workbench-frontend` and `chat-backend` repositories
- Node.js 20+, npm
- TAG_MANAGE permission on dev environment account

## Repositories Affected

| Repository | Changes |
|------------|---------|
| workbench-frontend | New components, routing restructure, breadcrumb enhancement, deprecation redirect, localization |
| chat-backend | One-line bugfix in review.draft.ts |

## Development Setup

### workbench-frontend

```bash
cd /Users/malyarevich/dev/workbench-frontend
git checkout develop && git pull
git checkout -b 054-clinical-tags-tab
npm install
npm run dev
```

Key files to read before starting:
- `src/features/workbench/tags/TagCenterPage.tsx` — current Tag Center (reference patterns)
- `src/features/workbench/tags/components/` — existing panel components
- `src/features/workbench/admin/ClinicalTagAdmin.tsx` — existing standalone page (logic to adapt)
- `src/services/tagApi.ts` — clinical tag API calls
- `src/features/workbench/WorkbenchShell.tsx` — routing
- `src/features/workbench/WorkbenchLayout.tsx` — sidebar nav, breadcrumbs
- `src/features/workbench/components/Breadcrumb.tsx` — breadcrumb component

### chat-backend

```bash
cd /Users/malyarevich/dev/chat-backend
git checkout develop && git pull
git checkout -b 054-clinical-tags-tab
npm install
```

Key file for bugfix:
- `src/routes/review.draft.ts` line 143 — change `clinical_tag_comments` → `review_clinical_tag_comments`

## Implementation Order

1. **Backend bugfix** (chat-backend) — one-line table name fix + regression test
2. **Breadcrumb enhancement** (workbench-frontend) — extend BreadcrumbSegment with dropdown support
3. **Tag Center routing restructure** (workbench-frontend) — convert to nested routes with layout
4. **Landing page** (workbench-frontend) — TagCenterLanding with 3 summary cards
5. **Existing sections migration** (workbench-frontend) — wrap UserTagsSection and ReviewTagsSection as routed components
6. **Clinical Tags section** (workbench-frontend) — ClinicalTagDefinitionsPanel + ClinicalTagAssignmentsPanel
7. **Deprecation** (workbench-frontend) — redirect old route, remove sidebar link
8. **Localization** (workbench-frontend) — en, uk, ru translations

## API Endpoints Used

| Endpoint | Purpose | Existing? |
|----------|---------|-----------|
| GET /api/admin/clinical-tags | List clinical tag definitions with session counts | Yes |
| POST /api/admin/clinical-tags | Create clinical tag | Yes |
| PATCH /api/admin/clinical-tags/:tagId | Update name/description | Yes |
| DELETE /api/admin/clinical-tags/:tagId | Delete (409 if in use) | Yes |
| GET /api/admin/users?role=expert | List expert users | Yes |
| GET /api/admin/users/:userId/expert-tags | List expert's tag assignments | Yes |
| POST /api/admin/users/:userId/expert-tags | Assign tag to expert | Yes |
| DELETE /api/admin/users/:userId/expert-tags | Remove tag from expert | Yes |
| GET /api/admin/tag-center/definitions?scope=user | User tag definitions | Yes |
| GET /api/admin/tag-center/definitions?scope=review | Review tag definitions | Yes |

## Validation

```bash
# Run workbench-frontend dev server
cd /Users/malyarevich/dev/workbench-frontend && npm run dev

# Navigate to https://workbench.dev.mentalhelp.chat/workbench/tags
# Verify: landing page with 3 cards
# Click Clinical Tags card → /workbench/tags/clinical
# Verify: definitions list, create input, expert assignment panel
# Test breadcrumb dropdown switching
# Navigate to /workbench/review/clinical-tags → verify redirect
```

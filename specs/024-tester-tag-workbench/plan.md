# Implementation Plan: Workbench Tester Tag Assignment UI

**Branch**: `024-tester-tag-workbench` | **Date**: 2026-03-11 | **Spec**: [spec.md](./spec.md)
**Jira Epic**: [MTB-692](https://mentalhelpglobal.atlassian.net/browse/MTB-692)
**Input**: Feature specification from `/specs/024-tester-tag-workbench/spec.md`

## Summary

Add a dedicated workbench page for managing the existing `tester` user tag, limited to `Admin`, `Supervisor`, and `Owner`, while keeping tester status read-only but visible on user profiles. Implementation should reuse the existing tagging model, expose a narrow backend contract for tester-tag state and updates, block assignment to regular end-user accounts, and preserve existing chat behavior where tester-tagged users can see tester-only technical details such as RAG sources.

**Key context**: This feature is not a general tagging redesign. It is a focused workbench management surface for a single existing user tag, with explicit scope for future expansion but no requirement to expose broader user-tag editing in this release.

## Technical Context

**Language/Version**: TypeScript 5.x (backend: Node.js + Express 5, frontend: React 18 + Vite)  
**Primary Dependencies**:
- Backend: Express 5.x, `pg` 8.x, existing auth/role middleware
- Frontend: React 18.x, Zustand, i18next, existing workbench routing/UI components
- Shared: `@mentalhelpglobal/chat-types`, `@mentalhelpglobal/chat-frontend-common`
**Storage**: PostgreSQL via the existing user-tagging model introduced by spec `010-chat-review-tagging`; no new persistence model expected  
**Testing**: Vitest (backend + frontend unit), React Testing Library (frontend), Playwright (`chat-ui`) for workbench E2E coverage  
**Target Platform**: GCP Cloud Run (backend), static-hosted React frontend for workbench  
**Project Type**: Web application (split frontend/backend/shared types)  
**Performance Goals**: Tester-tag page loads and save actions complete within 1 second under normal admin usage; status remains visible on profile reload  
**Constraints**:
- Only `Admin`, `Supervisor`, and `Owner` can access the dedicated page
- Regular end-user accounts cannot receive the `tester` tag from this UI
- User profile page is read-only for tester status
- All user-visible text must support `uk`, `en`, and `ru`
- UI must remain keyboard-accessible and screen-reader friendly
**Scale/Scope**: Single dedicated workbench management page plus user-profile tester-status visibility; low operational scale (internal staff/test accounts only)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| # | Principle | Status | Notes |
|---|-----------|--------|-------|
| I | Spec-First Development | PASS | `spec.md` exists, clarifications completed, bounded scope |
| II | Multi-Repository Orchestration | PASS | Planned changes target split repos only: `workbench-frontend`, `chat-backend`, optional `chat-types`, `chat-frontend-common`, `chat-ui` |
| III | Test-Aligned Development | PASS | Uses existing Vitest/RTL/Playwright patterns already defined by repo constitution |
| IV | Branch and Integration Discipline | PASS | Active feature branch `024-tester-tag-workbench`; target integration remains `develop` in implementation repos |
| V | Privacy and Security First | PASS | Sensitive admin operation; plan includes role-gated access, internal-only eligibility, and audit-oriented behavior |
| VI | Accessibility and Internationalization | PASS | Page labels, warnings, errors, and tester status require `uk/en/ru` support plus accessible interaction states |
| VII | Split-Repository First | PASS | No `chat-client` work planned; implementation is split-repo only |
| VIII | GCP CLI Infrastructure Management | PASS | No infrastructure change required |
| IX | Responsive UX and PWA Compatibility | PASS | Workbench page and profile status are user-facing and must remain usable on common workbench breakpoints |
| X | Jira Traceability and Project Tracking | PASS | Plan artifacts remain traceable to this feature branch/spec |
| XI | Documentation Standards | PASS | User-facing workbench changes require documentation-ready flow and UI terminology |
| XII | Release Engineering and Production Readiness | PASS | No deploy-topology change; release verification remains standard app/UI regression coverage |

**Gate result: PASS** — No violations. Proceeding to Phase 0 and Phase 1 outputs.

## Project Structure

### Documentation (this feature)

```text
specs/024-tester-tag-workbench/
├── plan.md                 # This file
├── research.md             # Phase 0 output
├── data-model.md           # Phase 1 output
├── quickstart.md           # Phase 1 output
├── contracts/
│   └── tester-tag-api.yaml # Dedicated tester-tag management API
└── tasks.md                # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
# Shared types
chat-types/src/
├── tags.ts                     # MAY MODIFY — reuse/add tester-tag management DTOs
└── rbac.ts                     # MAY MODIFY — confirm/manage permission constants if needed

# Shared frontend library
chat-frontend-common/src/
├── api/
│   └── testerTag.ts            # NEW — API client for tester-tag management/status
└── permissions/
    └── workbenchPermissions.ts # MODIFY — helper for page access gating if shared here

# Backend
chat-backend/src/
├── routes/
│   └── admin.testerTags.ts     # NEW — dedicated tester-tag read/update endpoints
├── services/
│   ├── testerTag.service.ts    # NEW — eligibility, read, assign, remove logic
│   └── userTag.service.ts      # MODIFY — reuse existing tag assignment primitives if present
├── middleware/
│   └── reviewAuth.ts           # MODIFY — enforce Admin/Supervisor/Owner access where appropriate
└── db/
    └── migrations/             # No new migration expected unless tester tag bootstrap is missing

# Workbench frontend
workbench-frontend/src/
├── features/users/
│   ├── TesterTagManagementPage.tsx    # NEW — dedicated management page
│   ├── components/
│   │   ├── TesterTagAssignmentCard.tsx # NEW — assign/remove tester-tag control
│   │   ├── TesterEligibilityNotice.tsx # NEW — internal-use and ineligible-user messaging
│   │   └── TesterStatusBadge.tsx       # NEW or shared — visible profile indicator
│   └── services/
│       └── testerTagApi.ts             # NEW — page-level API wrapper if not shared
├── features/userProfile/
│   └── UserProfileView.tsx             # MODIFY — show read-only tester status
├── router/
│   └── routes.tsx                      # MODIFY — add dedicated page route
└── locales/
    ├── en/*.json                       # MODIFY — tester-tag strings
    ├── uk/*.json                       # MODIFY — tester-tag strings
    └── ru/*.json                       # MODIFY — tester-tag strings

# E2E
chat-ui/tests/e2e/
└── workbench/
    └── tester-tag-management.spec.ts   # NEW — dedicated page/profile visibility/access tests
```

**Structure Decision**: Use the existing split-repository web application layout. Keep tester-tag management isolated to a dedicated workbench page and a narrow backend route/service pair, while profile visibility stays as a small additive change in the existing user-profile area.

## Cross-Repository Dependencies

### Execution Order

```text
1. chat-types / chat-frontend-common  → confirm shared DTOs/helpers for tester-tag status and permissions
2. chat-backend                       → add dedicated tester-tag endpoints and eligibility logic
3. workbench-frontend                 → add dedicated page, profile visibility, route gating, i18n
4. chat-ui                            → add Playwright coverage for access, assign/remove, and profile visibility
```

### Inter-repo Dependencies

| From | To | Dependency |
|------|----|------------|
| `chat-types` | `chat-backend`, `workbench-frontend` | Shared request/response types if new DTOs are introduced |
| `chat-frontend-common` | `workbench-frontend` | Shared API client and permission helpers if reused |
| `chat-backend` | `workbench-frontend` | Dedicated tester-tag endpoints must exist before UI integration |
| `workbench-frontend` | `chat-ui` | Dedicated page and profile badge must be deployed for E2E validation |
| `024-tester-tag-workbench` | `023-fix-rag-panel-visibility` | `023` depends on tester-tag existence but not on this UI implementation |

## Phase 0 Research Summary

Research decisions are captured in `research.md` and resolved without outstanding clarifications:

1. Reuse the existing tag model rather than creating a special tester-only storage path
2. Add a dedicated backend contract for tester-tag status/updates instead of exposing generic tag CRUD to the page
3. Keep user-profile visibility read-only while centralizing changes on a dedicated management page
4. Block assignment for regular end-user accounts using backend eligibility validation, with mirrored UI feedback
5. Keep the page tester-focused now, but shape the workflow for future user-tag expansion

## Phase 1 Design Summary

Phase 1 outputs define:

- A data model centered on `TesterTagStatus`, `TesterTagAssignmentCommand`, and read-only `UserProfileTesterStatus`
- A dedicated OpenAPI contract for reading and updating tester-tag state
- A quickstart validation path covering access control, assignment, removal, invalid-user blocking, and profile visibility
- No new infrastructure or deployment topology changes

## Post-Design Constitution Check

| # | Principle | Status | Notes |
|---|-----------|--------|-------|
| V | Privacy and Security First | PASS | Dedicated page access is role-gated and backend eligibility prevents assignment to regular end-user accounts |
| VI | Accessibility and Internationalization | PASS | Design keeps profile status visible and requires localized guidance/errors on the dedicated page |
| VII | Split-Repository First | PASS | Design remains fully within split repos; no legacy monorepo work added |
| IX | Responsive UX and PWA Compatibility | PASS | Dedicated page and profile status remain planned as standard responsive workbench UI |
| XI | Documentation Standards | PASS | Dedicated page flow and profile status are documentable as discrete user-facing workbench flows |

**Post-design gate result: PASS** — Phase 1 design remains constitution-compliant.

## Key Implementation Decisions

### Dedicated Page Instead Of Inline Profile Editing

Tester-tag changes happen only on a dedicated management page. User profiles remain read-only for tester status to reduce accidental edits and to keep management of this sensitive internal-use tag behind a narrower access surface.

### Backend-Enforced Eligibility

Eligibility is not trusted to the UI alone. The backend must reject attempts to assign the `tester` tag to regular end-user accounts, even if a caller bypasses frontend controls. The UI mirrors that rule with clear messaging.

### Narrow Tester-Tag Contract

The management page should consume a dedicated API contract for:
- listing or searching candidate users for tester-tag management
- retrieving current tester-tag state and eligibility
- setting tester-tag assigned/not-assigned state

This keeps the page focused and avoids binding it directly to generic tag-administration behavior.

### User Profile Status Data Source

User profile tester status must be exposed either through the existing user-profile API response or through a dedicated read endpoint that the profile page can reuse. The profile view cannot rely only on dedicated page state because tester visibility must remain accurate for any workbench user who can access the profile.

### Future Expansion Without Generalization Now

The page is intentionally named and structured so additional user tags can be added later, but this release should expose only `tester` behavior in the UI, copy, and acceptance tests.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| None | N/A | N/A |

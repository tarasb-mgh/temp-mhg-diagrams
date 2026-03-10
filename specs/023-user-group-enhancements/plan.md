# Implementation Plan: User Group and Management Interface Enhancements

**Branch**: `023-user-group-enhancements` | **Date**: 2026-03-10 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/023-user-group-enhancements/spec.md`

## Summary

Eight targeted enhancements to the workbench user-group and user-management interfaces. Primary technical work is split across `workbench-frontend` (all 8 UI user stories) and `chat-backend` (US1: remove privileged-role group membership block; US7: add privileged-role filter to user search). Survey completion deduplication (US5) is already implemented at the DB level via shared `survey_instance_id`; the plan verifies and documents it. The Group Surveys section (US4) is largely pre-built at `GroupSurveysPage`; the plan confirms its spec conformance. The invalidation controls (US6) are consolidated from scattered `window.prompt()` calls into a proper `InvalidationMenu` component with a confirmation modal.

## Technical Context

**Language/Version**: TypeScript 5.x (both target repos)
**Primary Dependencies (workbench-frontend)**: React 18, Vite, Zustand, react-router-dom v6, @dnd-kit/sortable, react-i18next, lucide-react, TailwindCSS 3, `@mentalhelpglobal/chat-frontend-common`, `@mentalhelpglobal/chat-types`
**Primary Dependencies (chat-backend)**: Express.js 4, node-postgres, `@mentalhelpglobal/chat-types`
**Storage**: PostgreSQL — `group_memberships`, `survey_instances` (with `group_ids[]` array column), `survey_responses`, `group_survey_order`, `users` tables. No schema migrations required.
**Testing**: Vitest + React Testing Library (workbench-frontend), Vitest (chat-backend), Playwright (chat-ui)
**Target Platform**: Browser SPA (React) + Node.js on Cloud Run
**Performance Goals**: Spaces list refreshes within 2 s of group creation; polling interval 30 s
**Constraints**: WCAG AA, i18n keys for all new user-visible text (uk/en/ru), responsive (mobile/tablet/desktop), clipboard API with visual feedback
**Project Type**: Web application (multi-repo)
**Scale/Scope**: UI-only + two backend service changes; no DB migrations

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Spec-First | ✅ Pass | spec.md complete and clarified |
| II. Multi-Repo Orchestration | ✅ Pass | Plan covers workbench-frontend + chat-backend; other repos unaffected |
| III. Test-Aligned Development | ✅ Pass | Vitest in each repo; Playwright E2E for critical flows |
| IV. Branch and Integration Discipline | ✅ Pass | Feature branch `023-user-group-enhancements` in both repos |
| V. Privacy and Security First | ✅ Pass | Privileged role access remains OWNER-gated at the API layer; copy-to-clipboard uses browser native API (no server round-trip) |
| VI. Accessibility and i18n | ✅ Pass | All new UI strings require i18n keys; WCAG AA focus/aria-label requirements applied |
| VII. Split-Repository First | ✅ Pass | No chat-client (legacy) changes |
| VIII. GCP CLI Infra | ✅ Pass | No infrastructure changes |
| IX. Responsive UX and PWA | ✅ Pass | New components inherit responsive Tailwind layout patterns |
| X. Jira Traceability | ✅ Pass | Epic, Stories, Tasks will be created via /speckit.tasks |
| XI. Documentation Standards | ✅ Pass | User Manual, Release Notes, Non-Technical Onboarding updates due at production deploy |
| XII. Release Engineering | ✅ Pass | No new services; existing CI/CD pipelines apply |

**Constitution violations**: None. Complexity Tracking section not required.

## Project Structure

### Documentation (this feature)

```text
specs/023-user-group-enhancements/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output — API change contracts
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (affected repositories)

```text
# workbench-frontend
src/features/workbench/
├── components/
│   └── GroupScopeSelector.tsx           [US2 US3] add polling + privileged-always-show
├── groups/
│   ├── GroupsView.tsx                   [US1 US2 US7] group creation refresh trigger + privileged lookup
│   └── GroupSurveysPage.tsx             [US4] verify spec conformance (largely pre-built)
├── surveys/
│   ├── SurveyInstanceDetailView.tsx     [US6] replace scattered buttons with <InvalidationMenu>
│   ├── SurveyResponseListView.tsx       [US6] replace scattered buttons with <InvalidationMenu>
│   └── components/
│       └── InvalidationMenu.tsx         [US6] NEW — consolidated invalidation dropdown + confirmation modal
├── users/
│   ├── UserListView.tsx                 [US8] remove row-click nav, add copy icon, preserve filter in URL
│   └── UserProfileCard.tsx             [US8] add copy icon next to email
└── stores/
    └── workbenchStore.ts               [US2] add groupListVersion counter for selector refresh signal

# chat-backend
src/
├── services/
│   └── group.service.ts                [US1] remove FORBIDDEN_TARGET_ROLE for privileged accounts
└── routes/
    └── users.ts                        [US7] expose privileged-only filter param to user search
```

**Structure Decision**: Web application (Option 2 layout). All feature changes are surgical edits to existing files, except `InvalidationMenu.tsx` which is a new shared component within the surveys feature.

## Complexity Tracking

No violations. No additional entries required.

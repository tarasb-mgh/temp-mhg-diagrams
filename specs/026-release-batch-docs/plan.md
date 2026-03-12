# Implementation Plan: Release Batch Documentation — v2026.03.11

**Branch**: `026-release-batch-docs` | **Date**: 2026-03-11 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/026-release-batch-docs/spec.md`

> **Note**: This is a retrospective plan. All implementation described herein is
> already shipped to production (tags `v2026.03.11e`, `v2026.03.11h`,
> `v2026.03.11c-workbench`). Phase 0 and Phase 1 artifacts record decisions as made.

---

## Summary

Four feature areas shipped across three repositories in a coordinated release:

1. **Chat session resilience** (`chat-frontend`) — localStorage session ID persistence,
   session restore on page load, offline detection, pending-message auto-retry on reconnect.
2. **RAG transparency** (`chat-backend` + `chat-frontend`) — tester-tagged users see
   knowledge retrieval details per assistant response; non-testers see nothing.
3. **Survey gate integration** (`chat-backend` + `chat-frontend`) — gate-check API +
   survey-responses API wired to the chat loading flow.
4. **Survey schema editor enhancements** (`workbench-frontend` + `chat-backend`) —
   markdown instructions, multi-condition visibility (AND/NOT_IN), freetext options,
   autosave, export/import.

---

## Technical Context

**Language/Version**: TypeScript 5.6 (all repos)
**Primary Dependencies**:
- `chat-frontend`: React 18, Zustand 5, Vite 5, react-router-dom 6, i18next 23
- `chat-backend`: Express, PostgreSQL (via pg), Dialogflow CX
- `workbench-frontend`: React 18, Zustand 5, Vite 5
- Shared types: `@mentalhelpglobal/chat-types` (GitHub Packages)

**Storage**: PostgreSQL (`chat-db-dev` / `chat-db-prod` on Cloud SQL)
- New tables: `survey_responses` (gate completion tracking)
- Modified tables: `survey_schemas` (added `instructions` field, moved from `survey_instances`)

**Testing**:
- Unit: Vitest + React Testing Library (all three repos)
- E2E: Playwright in `chat-ui` against dev environment

**Target Platform**: Web (PWA-capable); Cloud Run (Node.js 20 runtime)
**Performance Goals**: Session restore within normal page load time (<3 s p95)
**Constraints**: Session TTL 30 min server-side; localStorage key `mhg_chat_session_id`
**Scale/Scope**: ~100 concurrent dev users; production scale TBD

---

## Constitution Check

*GATE: Evaluated against constitution v3.9.0*

| Principle | Status | Notes |
|---|---|---|
| I. Spec-First Development | ✅ | Retrospective spec; production code already exists |
| II. Multi-Repository Orchestration | ✅ | Changes span chat-backend, chat-frontend, workbench-frontend; dependencies documented below |
| III. Test-Aligned Development | ✅ | Unit tests added/updated in all affected repos; UI regression sweep on dev |
| IV. Branch and Integration Discipline | ✅ | Feature branches → PRs → develop → release/* → main; backmerges applied |
| V. Privacy and Security First | ✅ | localStorage cleared on user switch; RAG data never persisted; PII masking unchanged |
| VI. Accessibility and i18n | ✅ | All new UI text has i18n keys (en/uk); offline banner translated |
| VII. Split-Repository First | ✅ | All work in split repos only |
| VIII. GCP CLI Infrastructure | ✅ | No infrastructure changes in this batch |
| IX. Responsive UX / PWA | ✅ | Offline banner respects safe-area-inset; no new non-responsive elements |
| XII. Production Deployment Gate | ✅ | Owner approved release explicitly in this session |

**No violations.** No Complexity Tracking entry required.

---

## Cross-Repository Execution Order

Dependencies flow in this order (must be respected for type safety and API availability):

```
1. chat-types          ← add 'pending' to client.status union  (v1.12.1)
2. chat-backend        ← RAG detail, gate-check, survey-responses API endpoints
3. chat-frontend       ← session resilience, RAG panel, gate survey wiring
4. workbench-frontend  ← schema editor enhancements (depends on backend survey instructions API)
```

---

## Project Structure

### Documentation (this feature)

```text
specs/026-release-batch-docs/
├── plan.md              ← this file
├── research.md          ← Phase 0: technical decisions
├── data-model.md        ← Phase 1: entities and schema changes
├── contracts/
│   └── api.md           ← Phase 1: new and changed API endpoints
└── checklists/
    └── requirements.md
```

### Source Code (affected paths per repository)

**`chat-types`** (`@mentalhelpglobal/chat-types` v1.12.1)
```text
src/entities.ts       ← ChatMessage.metadata.client.status: added 'pending'
```

**`chat-backend`** (tag `v2026.03.11e`)
```text
src/routes/chat.ts          ← GET /api/chat/sessions/:id/conversation (resume)
                               GET /api/chat/gate-check
                               POST /api/chat/survey-responses
                               PATCH /api/chat/survey-responses/:id
src/routes/auth.ts          ← tester_tag_assigned subquery in all auth SELECTs
src/services/dialogflow.ts  ← ragCallDetail attached for tester users
src/db/migrations/          ← survey_schemas.instructions field added
```

**`chat-frontend`** (tag `v2026.03.11h`)
```text
src/stores/chatStore.ts              ← session persistence, resume, offline, retry
src/features/chat/ChatInterface.tsx  ← isOffline state, online listener, offline banner
src/features/chat/MessageBubble.tsx  ← RAGDetailPanel gate on testerTagAssigned
src/features/chat/RAGDetailPanel.tsx ← new component
```

**`workbench-frontend`** (tag `v2026.03.11c-workbench`)
```text
src/features/survey/SchemaEditor.tsx      ← markdown instructions, autosave
src/features/survey/VisibilityEditor.tsx  ← multi-condition, NOT_IN operator
src/features/survey/PreviewModal.tsx      ← survey preview
src/features/survey/ExportImport.tsx      ← JSON export/import
src/features/review/ReviewConfiguration.tsx ← new nav item added
```

---

## Phase 0: Research (Retrospective)

*Full record in [research.md](research.md).*

| Decision | Choice Made | Rationale |
|---|---|---|
| Session persistence storage | `localStorage` key `mhg_chat_session_id` | Survives reload; cleared on logout/user-switch; not accessible cross-origin |
| Network error detection | `TypeError` message heuristic | No reliable cross-browser `NetworkError` type; catches `fetch`/`network`/`Failed` patterns |
| Retry re-entrancy guard | Module-level `retryPendingLock` boolean | Prevents double-send if `online` fires multiple times before retry loop completes |
| RAG visibility gate | `testerTagAssigned` on `AuthenticatedUser` | Evaluated at response generation time; revocation takes effect on next response |
| Survey gate state | Server-side `survey_responses` table | Must be server-side; localStorage cannot be trusted for security gate bypass |
| Schema instructions location | `survey_schemas` (moved from `survey_instances`) | Instructions describe question structure, not instance-specific behaviour |

---

## Phase 1: Design Artifacts

- [data-model.md](data-model.md) — entity definitions and schema changes
- [contracts/api.md](contracts/api.md) — new and modified API endpoints

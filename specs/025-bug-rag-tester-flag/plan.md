# Implementation Plan: Bug Fix — RAG Panel Never Visible (025)

**Branch**: `025-bug-rag-tester-flag` | **Date**: 2026-03-11 | **Spec**: [spec.md](./spec.md)  
**Jira Bug**: [MTB-706](https://mentalhelpglobal.atlassian.net/browse/MTB-706) | **Epic**: [MTB-229](https://mentalhelpglobal.atlassian.net/browse/MTB-229)  
**Input**: Feature specification from `specs/025-bug-rag-tester-flag/spec.md`

## Summary

Three independent defects fully prevent the RAG Call Details Panel from appearing in the chat interface for tester-tagged users, despite spec 023 implementation work having been merged:

1. **`dbUserToAuthUser()` omits `testerTagAssigned`** — `chat-backend/src/types/index.ts` builds the `AuthenticatedUser` object without mapping `tester_tag_assigned` from the DB row, making `req.user.testerTagAssigned` always `undefined`.
2. **`POST /api/chat/message` never returns `ragCallDetail`** — `chat-backend/src/routes/chat.ts` does not call `extractRAGDetails()` and never attaches RAG metadata to the assistant message response.
3. **`chat-frontend` has no RAG panel component** — `chat-frontend/src/components/MessageBubble.tsx` contains no rendering path for `ragCallDetail`; the `RAGDetailPanel` component exists only in `workbench-frontend`.

**Technical approach**: Fix each defect in dependency order (types → backend → frontend), add a Playwright E2E test, and validate on `dev` only. Zero production changes without explicit owner approval.

---

## Technical Context

**Language/Version**: TypeScript 5.x (backend: Node.js 20, frontend: React 18)  
**Primary Dependencies**:
- `chat-types` — `@mentalhelpglobal/chat-types` shared type package
- `chat-backend` — Express.js, Prisma-free (raw Postgres), `extractRAGDetails()` utility in `rag.service.ts`
- `chat-frontend` — React 18, Zustand (`authStore`), component library from `chat-frontend-common`
- `chat-ui` — Playwright E2E test runner
**Storage**: PostgreSQL; `tester_tag_assigned` is a computed column (EXISTS subquery) returned by `getUserById()`  
**Testing**: Vitest (unit), Playwright (E2E in `chat-ui`)  
**Target Platform**: Cloud Run (GCP); dev environment at `https://dev.mentalhelp.chat`  
**Project Type**: Multi-repository web service  
**Performance Goals**: No new endpoints; patch to existing `POST /api/chat/message` — latency impact negligible  
**Constraints**: No DB migrations required; no new npm packages; `testerTagAssigned` already declared in `chat-types`  
**Scale/Scope**: Affects ~3 files across 3 split repos + 1 new E2E test in `chat-ui`

---

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

| Gate | Status | Notes |
|------|--------|-------|
| Spec-First Development (I) | ✅ PASS | `spec.md` exists and is complete |
| Multi-Repository Orchestration (II) | ✅ PASS | All affected repos listed; plan references explicit file paths |
| Test-Aligned Development (III) | ✅ PASS | Vitest unit tests required per repo; Playwright E2E required per FR-008 |
| Branch and Integration Discipline (IV) | ✅ PASS | Feature branch `025-bug-rag-tester-flag` created; PRs to `develop` only; CI gate enforced |
| Split-Repository First (VII) | ✅ PASS | `chat-client` monorepo untouched; split repos only |
| Jira Traceability (X) | ✅ PASS | MTB-706 bug ticket and MTB-229 epic already created |
| Release Engineering (XII) | ✅ PASS | All validation on `dev`; SC-007 prohibits prod deployment without approval |
| **CI Gate (IV new)** | ✅ PASS | All PRs must have CI passing before merge; no bypass |
| **Prod Approval Gate (XII new)** | ✅ PASS | No release branch will be cut without explicit written owner approval |

**No violations.**

---

## Project Structure

### Documentation (this feature)

```text
specs/025-bug-rag-tester-flag/
├── plan.md              ← this file
├── research.md          ← Phase 0 output
├── data-model.md        ← Phase 1 output
├── quickstart.md        ← Phase 1 output
├── contracts/
│   └── bug-fix-api.yaml ← Phase 1 output (delta from 023 contract)
└── tasks.md             ← Phase 2 output (/speckit.tasks)
```

### Source Code (affected repositories)

```text
chat-types/
└── src/
    └── entities.ts                       # Add testerTagAssigned to AuthenticatedUser

chat-backend/
├── src/
│   ├── types/
│   │   └── index.ts                      # Fix dbUserToAuthUser() — map testerTagAssigned
│   └── routes/
│       └── chat.ts                       # Fix POST /api/chat/message — attach ragCallDetail
└── src/services/
    └── rag.service.ts                    # Reuse existing extractRAGDetails() — no change

chat-frontend/
└── src/
    ├── components/
    │   ├── MessageBubble.tsx             # Add RAGDetailPanel rendering
    │   └── RAGDetailPanel.tsx            # New component (copied/adapted from workbench-frontend)
    └── stores/
        └── authStore.ts                  # Verify testerTagAssigned is stored (read-only verify)

workbench-frontend/
└── src/features/workbench/review/components/
    └── ReviewSessionView.tsx             # Remove (message as any).ragCallDetail cast (polish)

chat-ui/
└── tests/
    └── rag-panel-visibility.spec.ts      # New Playwright E2E test
```

**Structure Decision**: Multi-repository web application (Option 2 variant). Fix spans types → backend → frontend in strict dependency order. `workbench-frontend` fix is a polish item (P3) and may be deferred.

---

## Complexity Tracking

No constitution violations. All changes are minimal targeted patches to existing files. No new infrastructure, no new endpoints, no DB migrations.

---

## Phase 0: Research

*Research is inherited from spec 023 investigation. All unknowns were resolved during the Playwright + GitHub source inspection session on 2026-03-11. See `research.md` for full findings.*

**Key decisions already made:**

| # | Question | Decision |
|---|----------|----------|
| R1 | Where is `testerTagAssigned` already declared? | `chat-types/src/entities.ts` on `User` but NOT on `AuthenticatedUser`. Fix: add it to `AuthenticatedUser`. |
| R2 | Does the DB query already return `tester_tag_assigned`? | Yes — `getUserById()` includes EXISTS subquery. `dbUserToUser()` maps it; `dbUserToAuthUser()` does not. |
| R3 | How is RAG metadata extracted from Dialogflow response? | `extractRAGDetails()` in `chat-backend/src/services/rag.service.ts` — already exists, reusable. |
| R4 | Does `chat-frontend` have any RAGDetailPanel? | No — it exists only in `workbench-frontend`. Must be duplicated to `chat-frontend` for this bugfix. |
| R5 | What is the gate condition for showing the panel? | `isAssistant && user?.testerTagAssigned === true && message.ragCallDetail != null` |
| R6 | Does `chat-types` AnonymizedMessage declare `ragCallDetail`? | Not formally (as of 023 research). Adding it is part of this fix too. |

---

## Phase 1: Design

### Entities Changed

See `data-model.md` for full entity definitions.

**`AuthenticatedUser`** (chat-types): add `testerTagAssigned: boolean`  
**`AnonymizedMessage`** (chat-types): add `ragCallDetail?: RAGCallDetail`  
**`RAGDetailPanel`** (chat-frontend): new component  
**`MessageBubble`** (chat-frontend): updated to conditionally render `RAGDetailPanel`

### Interface Contracts

See `contracts/bug-fix-api.yaml` — documents the delta over spec 023 contracts. The key changes are:
- `AuthenticatedUser` schema: `testerTagAssigned` is now `required` (not nullable) — always `true` or `false`
- `POST /api/chat/message` assistant message: `ragCallDetail` field formally defined as present for tester users, absent otherwise

### Implementation Order (strict)

```
1. chat-types: add testerTagAssigned to AuthenticatedUser + ragCallDetail to AnonymizedMessage
   └─ bump patch version, publish
2. chat-backend: update dbUserToAuthUser() to map testerTagAssigned
   └─ depends on step 1
3. chat-backend: update POST /api/chat/message to attach ragCallDetail
   └─ depends on step 2
4. chat-frontend: add RAGDetailPanel component
   └─ depends on step 1 (types)
5. chat-frontend: update MessageBubble to render RAGDetailPanel
   └─ depends on step 4
6. chat-ui: add Playwright E2E test
   └─ depends on steps 2, 3, 5 (deployed to dev)
7. workbench-frontend: remove (message as any) cast (polish, P3)
   └─ depends on step 1
```

### Quickstart

See `quickstart.md` for local dev setup and testing instructions per repository.

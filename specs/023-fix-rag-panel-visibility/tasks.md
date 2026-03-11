# Tasks: Fix RAG Panel Visibility (023-fix-rag-panel-visibility)

**Input**: Design documents from `/specs/023-fix-rag-panel-visibility/`
**Jira Bug**: [MTB-691](https://mentalhelpglobal.atlassian.net/browse/MTB-691) | **Jira Epic**: [MTB-229](https://mentalhelpglobal.atlassian.net/browse/MTB-229)
**Jira Story US1** (workbench review): ? MTB-TBD | **Jira Story US2** (chat tester): ? MTB-TBD | **Jira Story US3** (backend metadata): ? MTB-TBD
**Prerequisites**: spec.md ✅ plan.md ✅ research.md ✅ data-model.md ✅ quickstart.md ✅ contracts/ ✅
**Affected repos**: `chat-types` → `chat-backend` → `workbench-frontend`, `chat-frontend`

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel (different files, no unmet dependencies)
- **[USn]**: Which user story this task belongs to
  - US1 = RAG details in review interface (workbench-frontend)
  - US2 = RAG details in chat interface for tester-tagged users (chat-frontend)
  - US3 = Backend includes RAG metadata in message payloads (chat-backend)

---

## Phase 1: Foundational — Shared Type Changes in `chat-types` (Blocking prerequisite)

**Purpose**: Both type gaps (RC1 and RC3) live in `chat-types`. Every other phase depends on the compiled output of this package. No frontend or backend work can be completed until `chat-types` is built with these changes.

**⚠️ CRITICAL**: All three user stories are blocked until T003 (`npm run build`) is complete.

**Branch**: `023-fix-rag-panel-visibility` on `chat-types`

- [x] T001 Add `testerTagAssigned?: boolean` field to `AuthenticatedUser` interface in `chat-types/src/entities.ts` (RC1 fix — allows chat-frontend to gate RAG visibility without `as any`)
- [x] T002 [P] Add `ragCallDetail?: RAGCallDetail` field to `AnonymizedMessage` interface in `chat-types/src/review.ts` (RC3 fix — formalises the field already spread by `anonymizeMessage()`)
- [x] T003 Run `npm run build` in `chat-types/` and bump patch version in `chat-types/package.json` — confirm `dist/` emits both changed interfaces without TypeScript errors

**Checkpoint**: `chat-types` built — downstream repos can now install the updated package and implement their changes

---

## Phase 2: User Story 3 — Backend Includes RAG Metadata (Priority: P1) 🎯 MVP

> **Note**: This phase implements **US3** from spec.md (backend) before US1 and US2 because the backend data layer is a prerequisite for end-to-end verification of both frontend stories. The spec story numbering (US1=workbench, US2=chat, US3=backend) reflects user value priority, not implementation order.

**Goal**: `GET /api/auth/me` returns `testerTagAssigned: true` for tester-tagged users; `POST /api/chat/message` includes `ragCallDetail` on the assistant message for tester-tagged users only.

**Independent Test**:
```bash
# auth/me for a tester user → testerTagAssigned: true
curl -s -H "Authorization: Bearer $TESTER_TOKEN" \
  https://api.dev.mentalhelp.chat/api/auth/me | jq '.data.testerTagAssigned'
# Expected: true

# chat/message for a tester user → ragCallDetail present
curl -s -X POST -H "Authorization: Bearer $TESTER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"message":"tell me about cognitive behavioral therapy"}' \
  https://api.dev.mentalhelp.chat/api/chat/message \
  | jq '.data.assistantMessage.ragCallDetail'
# Expected: non-null object (when RAG triggered)

# chat/message for a non-tester user → ragCallDetail absent
curl -s -X POST -H "Authorization: Bearer $NON_TESTER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"message":"tell me about cognitive behavioral therapy"}' \
  https://api.dev.mentalhelp.chat/api/chat/message \
  | jq '.data.assistantMessage | has("ragCallDetail")'
# Expected: false
```

**Branch**: `023-fix-rag-panel-visibility` on `chat-backend`

### Implementation for User Story 3

- [x] T004 [US3] Update `dbUserToAuthUser()` in `chat-backend/src/types/index.ts` to forward `testerTagAssigned` from the DB user object: `testerTagAssigned: (dbUser as any).tester_tag_assigned === true || (dbUser as any).testerTagAssigned === true` (RC2 fix)
- [x] T005 [P] [US3] Import `extractRAGDetails` from `'../services/rag.service'` in `chat-backend/src/routes/chat.ts`; after building `assistantMessage`, check `req.user?.testerTagAssigned === true` and spread `ragCallDetail` onto the outgoing message when the extraction returns non-null (RC4 fix)
- [x] T006 [P] [US3] Write unit test in `chat-backend/tests/unit/auth.service.test.ts` asserting that `getAuthUserById` output includes `testerTagAssigned: true` when the DB row has `tester_tag_assigned: true`, and `testerTagAssigned: false` when absent
- [x] T007 [P] [US3] Write unit test in `chat-backend/tests/unit/chat.route.test.ts` (or extend existing) asserting: (a) `ragCallDetail` present on assistant message response for tester-tagged user when RAG metadata exists in the stored message; (b) `ragCallDetail` absent for non-tester user even when RAG metadata exists
- [x] T008 [US3] Run `npm run typecheck && npm test` in `chat-backend/` — confirm all existing tests pass and new tests pass

**Checkpoint**: US3 is independently verifiable — backend correctly gates and surfaces RAG metadata. US1 and US2 frontend work can now be validated end-to-end.

---

## Phase 3: User Story 1 — RAG Details in Review Interface (Priority: P1)

**Goal**: Remove `as any` type casts in `workbench-frontend` now that `AnonymizedMessage` formally has `ragCallDetail`; fix the zero-document edge case in `RAGDetailPanel` so an empty-document RAG response shows "No retrieval data available" instead of hiding the panel.

**Independent Test**:
1. Log in as any staff user (Reviewer through Owner) at `https://workbench.dev.mentalhelp.chat`
2. Open a past session that had RAG-assisted responses
3. Confirm `RAGDetailPanel` renders below the relevant assistant messages
4. Expand the panel — verify retrieval query and document list are shown
5. Open a session with a RAG response that returned zero documents — confirm the panel renders with a fallback message, not `null`

**Branch**: `023-fix-rag-panel-visibility` on `workbench-frontend`

### Implementation for User Story 1

- [x] T009 [US1] In `workbench-frontend/src/features/workbench/review/ReviewSessionView.tsx`, replace the two `(message as any).ragCallDetail` casts with typed access `message.ragCallDetail` now that `AnonymizedMessage` has the field (install updated `chat-types` first)
- [x] T010 [P] [US1] In `workbench-frontend/src/features/workbench/review/components/RAGDetailPanel.tsx`, update the zero-document guard to handle both distinct empty states: (1) `ragDetail.retrievalQuery` present but `ragDetail.retrievedDocuments` is empty → render "No documents found" message (FR-008a — retrieval ran but returned zero results); (2) `ragCallDetail` object present but all fields null/empty → render "No retrieval data available" message (FR-007 — RAG-flagged message with missing metadata); in both cases the panel must remain visible and not return `null`
- [x] T011 [US1] Run `npm run typecheck && npm test` in `workbench-frontend/` — confirm no new type errors and existing test suite passes

**Checkpoint**: US1 is fully functional — all roles ≥ Reviewer see RAGDetailPanel in the workbench, including the zero-document fallback

---

## Phase 4: User Story 2 — RAG Details in Chat Interface for Tester-Tagged Users (Priority: P1)

**Goal**: `chat-frontend` renders a `RAGDetailPanel` below assistant message bubbles for tester-tagged users when `ragCallDetail` is present. Non-tester users see no panel.

**Independent Test**:
1. Log in as a tester-tagged user at `https://dev.mentalhelp.chat`
2. Send a message that triggers RAG retrieval (e.g. "tell me about cognitive behavioral therapy")
3. Confirm the RAG panel appears below the assistant message
4. Log in as a non-tester user — confirm no RAG panel appears on the same message type
5. Send a non-RAG message as a tester — confirm no RAG panel appears

**Branch**: `023-fix-rag-panel-visibility` on `chat-frontend`

### Implementation for User Story 2

- [x] T012 [US2] Create `chat-frontend/src/components/RAGDetailPanel.tsx` — adapt from `workbench-frontend/src/features/workbench/review/components/RAGDetailPanel.tsx`; accept `ragDetail: RAGCallDetail` prop; render retrieval query, document list with relevance scores and snippets; handle both distinct empty states: (1) `retrievalQuery` present but `retrievedDocuments` empty → render "No documents found" (FR-008a); (2) all fields null/empty → render "No retrieval data available" (FR-007); all user-visible strings MUST use the project's i18n mechanism (translation keys for uk/en/ru — see T022); import `RAGCallDetail` and `RAGDocument` from `@mentalhelpglobal/chat-types`
- [x] T013 [US2] In `chat-frontend/src/features/chat/MessageBubble.tsx`, read `user?.testerTagAssigned` from the auth store; after the assistant bubble content, conditionally render `<RAGDetailPanel ragDetail={ragCallDetail} />` only when `isAssistant && isTester && message.ragCallDetail` is truthy; use typed access `message.ragCallDetail as RAGCallDetail | undefined` (do NOT use `(message as any)` — T001/T002/T003 add the proper type); import `RAGDetailPanel` and `RAGCallDetail`
- [x] T014 [P] [US2] Verify `useAuthStore` in `chat-frontend` persists the full `AuthenticatedUser` object as returned by `GET /api/auth/me` (including `testerTagAssigned`) — confirmed: store sets `user: response.data.user` directly in `initializeAuth`, `verifyOtp`, `refreshSession`, and `googleLogin`; `testerTagAssigned` flows through automatically without any store changes
- [x] T015 [US2] Run `npm run typecheck && npm test` in `chat-frontend/` — confirm no type errors and existing test suite passes

**Checkpoint**: US2 is fully functional — tester-tagged users see RAGDetailPanel in chat; non-tester users see nothing

---

## Phase 5: Polish & Cross-Cutting

**Purpose**: Cross-repo validation, PR hygiene, and Jira traceability.

- [ ] T016 [P] Validate end-to-end flow using quickstart.md against `https://api.dev.mentalhelp.chat` and `https://workbench.dev.mentalhelp.chat` — run all three curl smoke tests from quickstart.md; additionally: (a) log in as an **Owner-role user** at `https://workbench.dev.mentalhelp.chat`, open a RAG session, confirm RAGDetailPanel is visible (FR-009 / SC-006 Owner validation); (b) verify RAGDetailPanel does not overflow at 375px viewport width in both chat and workbench (Constitution IX responsive check); (c) manually time the panel expand interaction and confirm it completes in < 1 second (SC-005 performance validation) — **blocked on dev deployment** (all four PRs merged to develop/main on 2026-03-11; awaiting CI deploy to dev environments)
- [x] T017 [P] Open PR for `chat-types` branch `023-fix-rag-panel-visibility` → `main`; PR [#16](https://github.com/MentalHelpGlobal/chat-types/pull/16)
- [x] T018 [P] Open PR for `chat-backend` branch `023-fix-rag-panel-visibility` → `develop`; PR [#146](https://github.com/MentalHelpGlobal/chat-backend/pull/146)
- [x] T019 [P] Open PR for `workbench-frontend` branch `023-fix-rag-panel-visibility` → `develop`; PR [#63](https://github.com/MentalHelpGlobal/workbench-frontend/pull/63)
- [x] T020 [P] Open PR for `chat-frontend` branch `023-fix-rag-panel-visibility` → `develop`; PR [#78](https://github.com/MentalHelpGlobal/chat-frontend/pull/78)
- [x] T021 Confirm all four PRs are green (typecheck + unit tests); merge in dependency order: chat-types → chat-backend → workbench-frontend + chat-frontend (last two in parallel); delete all remote and local `023-fix-rag-panel-visibility` branches after merge; sync local `develop` in each repo — all four PRs merged: chat-types@b88f90e → main; chat-backend@0c017d1 → develop; workbench-frontend@06a18dd → develop; chat-frontend@dfc8c38 → develop (2026-03-11)
- [x] T022 [P] Add i18n translation keys for all user-visible strings introduced by RAGDetailPanel: `rag.sources_label`, `rag.query_label`, `rag.no_documents_found` added to `chat-frontend/src/locales/en.json`, `uk.json`, `ru.json` (Constitution VI)
- [x] T023 [P] Update Confluence User Manual page ([https://mentalhelpglobal.atlassian.net/wiki/spaces/UD/pages/8749070/User+Manual](https://mentalhelpglobal.atlassian.net/wiki/spaces/UD/pages/8749070/User+Manual)) with a section describing the RAGDetailPanel — added "RAG Call Details Panel" section (version 7) covering: Where It Appears table (Workbench vs Chat), role/tag visibility rules, step-by-step expand instructions, empty-state note, and Assigning the Tester Tag procedure (Constitution XI)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Foundational — chat-types)**: No dependencies — start immediately
- **Phase 2 (US3 — chat-backend)**: Requires T003 (`chat-types` built) before `npm run typecheck` can pass; T004 and T005 can be written before build if using the local file ref; T008 (typecheck gate) requires T003
- **Phase 3 (US1 — workbench-frontend)**: Requires T003 (`chat-types` built); T009 typed access requires the new field to exist in the package
- **Phase 4 (US2 — chat-frontend)**: Requires T003 (`chat-types` built); T013 and T012 imports require the types; T014 is confirmatory only
- **Phase 5 (Polish)**: Requires Phase 2 complete (for smoke tests) and Phases 3+4 complete (for PRs); T022 and T023 can run in parallel with T017–T021 once Phase 4 is done

### User Story Dependencies

- **US3 (P1 — backend)**: Unblocked after Phase 1; BLOCKS end-to-end verification of US1 and US2 but not their code authoring
- **US1 (P1 — workbench)**: Unblocked after Phase 1; can proceed in parallel with US2
- **US2 (P1 — chat)**: Unblocked after Phase 1; can proceed in parallel with US1

### Within Each Phase

- T001 and T002 can run in parallel (different files in `chat-types`)
- T004, T005, T006, T007 can run in parallel (different files in `chat-backend`)
- T009 and T010 can run in parallel (different files in `workbench-frontend`)
- T012, T013, T014 can run in parallel (different files in `chat-frontend`)
- T016–T020 can all run in parallel
- T022 and T023 can run in parallel with each other and with T016–T020

### Parallel Execution Example

```bash
# Phase 1: parallel type additions
# Dev A edits chat-types/src/entities.ts (T001)
# Dev B edits chat-types/src/review.ts (T002)
# Both wait for T003 (build)

# Phase 2+3+4 after T003 completes:
# Dev A: chat-backend T004–T008
# Dev B: workbench-frontend T009–T011
# Dev C: chat-frontend T012–T015
```

---

## Implementation Strategy

### MVP (Unblock US1 review visibility — minimum viable fix)

1. Complete T001–T003 (chat-types, both type fixes)
2. Complete T009–T011 (workbench-frontend type cleanup + zero-doc edge case)
3. Validate: owner can open a reviewed session and see RAGDetailPanel

### Full Delivery

1. MVP above
2. T004–T008 (backend: testerTagAssigned forwarding + chat message enrichment) — US3 complete
3. T012–T015 (chat-frontend: RAGDetailPanel in MessageBubble) — US2 complete
4. T016–T021 (smoke tests, PRs, merge) + T022 (i18n) + T023 (Confluence docs) — shipped

---

## Jira Ticket Mapping

| Tasks | Story | Jira |
|-------|-------|------|
| T001–T003 (chat-types) | Foundational | MTB-691 (Bug) — foundational type changes |
| T004–T008 (chat-backend US3) | US3 | ? MTB-TBD (Story) — backend RAG metadata gating |
| T009–T011 (workbench-frontend US1) | US1 | ? MTB-TBD (Story) — workbench RAGDetailPanel type cleanup & edge case |
| T012–T015 (chat-frontend US2) | US2 | ? MTB-TBD (Story) — chat RAGDetailPanel for tester-tagged users |
| T016–T021 (Polish) | — | MTB-691 — validation, PRs, merge |
| T022 (i18n) | Cross-cutting | MTB-691 — i18n translation keys for RAGDetailPanel strings |
| T023 (Confluence docs) | Cross-cutting | MTB-691 — User Manual update with RAGDetailPanel screenshot |

> **Action required before implementation**: Create three Jira Stories under [MTB-229](https://mentalhelpglobal.atlassian.net/browse/MTB-229) for US1, US2, and US3. Replace `? MTB-TBD` above with the assigned keys.

---

## Notes

- `chat-types` must be built and available as a local file reference (`"@mentalhelpglobal/chat-types": "file:../chat-types"`) or published patch before dependents can typecheck cleanly
- Migration `032_seed_tester_tag_definition.sql` (from `001-fix-tester-tags-users`) must already be applied — the `tester` tag definition must exist in the DB for tester-tag lookups to resolve
- The review sessions endpoint (`GET /api/review/sessions/:id`) already calls `extractRAGDetails()` — no backend route change is needed for US1 beyond the chat-types type fix
- `chat-types` must be rebuilt (T003) before the typed `message.ragCallDetail` access in T009 and T013 compiles cleanly — do not use `(message as any)` in any task implementation
- Merge order is strict: `chat-types` PR must merge first so CI in `chat-backend`, `workbench-frontend`, and `chat-frontend` resolves the updated package
- Jira Stories for US1, US2, US3 must be created under MTB-229 and their keys recorded in tasks.md before beginning Phase 2 (Constitution X)

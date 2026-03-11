# Tasks: Bug Fix — RAG Panel Never Visible in Chat (025)

**Input**: Design documents from `specs/025-bug-rag-tester-flag/`  
**Jira Bug**: [MTB-706](https://mentalhelpglobal.atlassian.net/browse/MTB-706) | **Epic**: [MTB-229](https://mentalhelpglobal.atlassian.net/browse/MTB-229)  
**Branch**: `025-bug-rag-tester-flag` in all affected repos

**Format**: `- [ ] T### [P?] [US?] Description — repo: file/path`  
**[P]** = parallelizable (different files, no blocking deps) | **[US#]** = user story reference

---

## Phase 1: Setup (Branch Preparation)

**Purpose**: Create feature branches in all affected repositories.

- [ ] T001 Create branch `025-bug-rag-tester-flag` from `develop` in `chat-types` repo
- [ ] T002 [P] Create branch `025-bug-rag-tester-flag` from `develop` in `chat-backend` repo
- [ ] T003 [P] Create branch `025-bug-rag-tester-flag` from `develop` in `chat-frontend` repo
- [ ] T004 [P] Create branch `025-bug-rag-tester-flag` from `develop` in `chat-ui` repo

---

## Phase 2: Foundational — `chat-types` Type Fixes (Blocking)

**Purpose**: Add missing type fields that all downstream fixes depend on. MUST complete before any backend or frontend work.

**⚠️ CRITICAL**: All Phase 3, 4, 5 work is blocked until this phase is merged.

- [ ] T005 Add `testerTagAssigned: boolean` field to `AuthenticatedUser` interface — `chat-types`: `src/entities.ts`
- [ ] T006 Add `ragCallDetail?: RAGCallDetail` field to `AnonymizedMessage` interface — `chat-types`: `src/review.ts`
- [ ] T007 Bump patch version in `chat-types/package.json` and rebuild (`npm run build`)
- [ ] T008 Open PR for `chat-types` branch → `develop`; verify CI passes; merge

**Checkpoint**: `chat-types` published/merged — backend and frontend can proceed in parallel.

---

## Phase 3: User Story 1 — Auth Response Correctly Exposes `testerTagAssigned` (Priority: P1)

**Goal**: Fix `dbUserToAuthUser()` so that `testerTagAssigned` is included in every auth response. After this phase, `GET /api/auth/me` and OTP verify return `testerTagAssigned: true/false`.

**Independent Test**: Log in as `e2e-owner@test.local`; inspect `/api/auth/me` response — must contain `testerTagAssigned: true`. Log in as a non-tester user — must contain `testerTagAssigned: false`.

- [ ] T009 [US1] Add `testerTagAssigned: (dbUser as any).tester_tag_assigned === true` to `dbUserToAuthUser()` return object — `chat-backend`: `src/types/index.ts`
- [ ] T010 [US1] Update `chat-backend/package.json` to reference `chat-types` branch `025-bug-rag-tester-flag` (or bumped version from T007)
- [ ] T011 [US1] Write Vitest unit test for `dbUserToAuthUser()`: assert `testerTagAssigned: true` when `tester_tag_assigned: true` in input; assert `false` when absent — `chat-backend`: `src/types/index.test.ts`
- [ ] T012 [US1] Run `npm test` in `chat-backend`; verify all tests pass including T011
- [ ] T013 [US1] Open PR for `chat-backend` branch → `develop` for T009–T012; verify CI passes; DO NOT merge yet (T016 must be included)

**Checkpoint**: `testerTagAssigned` correctly returned in auth responses on dev after merge.

---

## Phase 4: User Story 2 — Chat Message Endpoint Returns `ragCallDetail` for Tester Users (Priority: P1)

**Goal**: Fix `POST /api/chat/message` to attach `ragCallDetail` for tester-tagged users. Depends on Phase 3 (T009 must be complete so `req.user.testerTagAssigned` is populated).

**Independent Test**: As tester-tagged user, send `"розкажи про депресію"` to `POST /api/chat/message`; inspect response — `data.assistantMessage.ragCallDetail` must be present. Repeat as non-tester — field must be absent.

- [ ] T014 [US2] Import `extractRAGDetails` from `../services/rag.service` in `chat-backend`: `src/routes/chat.ts` (if not already imported)
- [ ] T015 [US2] After building `assistantMessage` in `POST /api/chat/message` handler, add: check `req.user?.testerTagAssigned === true`, call `extractRAGDetails()` on `dialogflowResponse.diagnosticInfo`, spread result onto response object — `chat-backend`: `src/routes/chat.ts`
- [ ] T016 [US2] Write Vitest unit test for the chat route handler: mock `req.user.testerTagAssigned = true` → assert `ragCallDetail` present in response; mock `testerTagAssigned = false` → assert absent — `chat-backend`: `src/routes/chat.test.ts`
- [ ] T017 [US2] Run `npm test` in `chat-backend`; verify all tests pass including T016
- [ ] T018 [US2] Add T014–T017 commits to the open `chat-backend` PR (T013); verify CI still passes; merge PR into `develop`

**Checkpoint**: `POST /api/chat/message` returns `ragCallDetail` for tester users on dev after merge.

---

## Phase 5: User Story 3 — RAG Panel Renders in Chat UI (Priority: P1)

**Goal**: Create `RAGDetailPanel` component and render it in `MessageBubble` for tester-tagged users. Depends on Phase 2 (chat-types) for prop types; independent of Phase 3/4 for component creation, but requires deployed backend for E2E test.

**Independent Test**: In chat UI as tester-tagged user with US1+US2 fixes deployed, send RAG-triggering message — "Sources" expandable panel appears. Click to expand — documents shown. As non-tester user — panel absent.

- [ ] T019 [P] [US3] Update `chat-frontend/package.json` to reference `chat-types` branch `025-bug-rag-tester-flag` (or bumped version from T007) — `chat-frontend`: `package.json`
- [ ] T020 [P] [US3] Create `RAGDetailPanel` component adapted from workbench version: renders collapsible "Sources" section with retrieval query, document list (title, score, snippet), and "No documents retrieved" empty state — `chat-frontend`: `src/components/RAGDetailPanel.tsx`
- [ ] T021 [US3] Update `MessageBubble` to import `RAGDetailPanel` and render it when `isAssistant && user?.testerTagAssigned && message.ragCallDetail` — `chat-frontend`: `src/components/MessageBubble.tsx`
- [ ] T022 [US3] Write Vitest + RTL unit test for `RAGDetailPanel`: renders documents when `retrievedDocuments` present; shows "No documents retrieved" when empty array — `chat-frontend`: `src/components/RAGDetailPanel.test.tsx`
- [ ] T023 [US3] Write Vitest + RTL unit test for `MessageBubble`: renders `RAGDetailPanel` when `testerTagAssigned=true` and `ragCallDetail` present; does not render when either condition false — `chat-frontend`: `src/components/MessageBubble.test.tsx`
- [ ] T024 [US3] Run `npm test` in `chat-frontend`; verify all tests pass including T022–T023
- [ ] T025 [US3] Open PR for `chat-frontend` branch → `develop`; verify CI passes; merge PR into `develop`

**Checkpoint**: RAG panel renders in chat UI for tester users on dev after merge + deploy.

---

## Phase 6: E2E Test (Playwright) — Regression Gate

**Purpose**: Validate the full flow end-to-end on `dev` environment. Must run AFTER all Phase 3–5 changes are deployed to dev.

**FR-008 requirement**: E2E test must exist and pass before any release is cut.

- [ ] T026 Write Playwright E2E test `rag-panel-visibility.spec.ts`: login as `e2e-owner@test.local` → send `"розкажи про депресію"` → wait for response → assert "Sources" panel visible → expand → assert document content visible — `chat-ui`: `tests/rag-panel-visibility.spec.ts`
- [ ] T027 Write Playwright E2E test: login as non-tester user → send same message → assert "Sources" panel NOT visible — `chat-ui`: `tests/rag-panel-visibility.spec.ts` (second test case)
- [ ] T028 Run `npx playwright test rag-panel-visibility.spec.ts` against `https://dev.mentalhelp.chat`; confirm both tests PASS
- [ ] T029 Open PR for `chat-ui` branch → `develop`; verify CI passes; merge

**Checkpoint**: E2E test passing on dev — feature is validated end-to-end. Release may now be discussed with owner.

---

## Phase 7: Polish (P3 — Optional)

**Purpose**: Remove `as any` cast in workbench-frontend now that `AnonymizedMessage` formally declares `ragCallDetail`.

- [ ] T030 Remove `(message as any).ragCallDetail` cast and replace with `message.ragCallDetail` — `workbench-frontend`: `src/features/workbench/review/components/ReviewSessionView.tsx` (or wherever the cast exists)
- [ ] T031 Run `npm test` in `workbench-frontend`; verify no regressions
- [ ] T032 Open PR for `workbench-frontend` branch → `develop`; verify CI passes; merge

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1 (Setup)           → no deps
Phase 2 (chat-types)      → requires Phase 1
Phase 3 (US1 auth fix)    → requires Phase 2 merged
Phase 4 (US2 chat fix)    → requires Phase 3 (T009 complete, testerTagAssigned available in req.user)
Phase 5 (US3 frontend)    → requires Phase 2 merged (types); T019–T020 parallelizable with Phase 3
Phase 6 (E2E)             → requires Phases 3, 4, 5 deployed to dev
Phase 7 (Polish)          → requires Phase 2 merged; independent of Phases 3–6
```

### Parallel Opportunities

- T001–T004 (branch creation): all in parallel
- T005–T006 (chat-types fields): in parallel within Phase 2
- T009 (auth fix) and T019–T020 (frontend component creation): can proceed in parallel once Phase 2 is merged
- T022–T023 (frontend tests): in parallel
- T026–T027 (E2E test cases): in parallel within the same file

### Critical Path

```
T001 → T005 → T007 → T008
                         ↓
              T009 → T011 → T012 → T013
                                       ↓
                         T014 → T015 → T016 → T017 → T018
                                                          ↓
                         T019 → T020 → T021 → T022 → T024 → T025
                                                                   ↓
                                              T026 → T028 → T029
```

---

## Implementation Strategy

### MVP (US1 + US2 only — backend fixes)

1. Phase 1: Setup branches
2. Phase 2: Fix chat-types, merge
3. Phase 3: Fix `dbUserToAuthUser()`, merge → deploy to dev
4. Phase 4: Fix `POST /api/chat/message`, merge → deploy to dev
5. **Validate**: Auth response has `testerTagAssigned`, chat response has `ragCallDetail`
6. Proceed to Phase 5 (frontend) only after backend validated

### Full Delivery

1. MVP (above)
2. Phase 5: Frontend RAG panel, merge → deploy to dev
3. Phase 6: E2E test passing on dev
4. Phase 7: Polish (optional)
5. **After E2E green + explicit owner approval**: cut release branch

---

## Notes

- All PRs must have CI checks **run and passed** before merge (constitution Principle IV)
- No release branch until E2E (T028) passes AND explicit written owner approval received (SC-007, Principle XII)
- All validation on `dev` environment: `https://dev.mentalhelp.chat` / `https://api.dev.mentalhelp.chat`
- RAG trigger phrase confirmed: `"розкажи про депресію"` (known to invoke Dialogflow CX data store retrieval)
- Tester-tagged test account: `e2e-owner@test.local` (Owner role, tester tag confirmed assigned via workbench)

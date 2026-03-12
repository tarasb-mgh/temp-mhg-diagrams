# Tasks: Release Batch Documentation — v2026.03.11

**Input**: Design documents from `/specs/026-release-batch-docs/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/api.md ✅

> **Context**: All implementation is already shipped to production (tags `v2026.03.11e`,
> `v2026.03.11h`, `v2026.03.11c-workbench`). Tasks here complete the documentation and
> traceability cycle for the four feature areas in this batch.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1–US4)

---

## Phase 1: Setup (Spec Artifact Verification)

**Purpose**: Confirm all speckit artifacts for this batch are committed and complete.

- [x] T001 spec.md complete with 4 user stories, 19 FRs, 7 SCs in specs/026-release-batch-docs/spec.md
- [x] T002 plan.md complete with technical context, constitution check, and execution order in specs/026-release-batch-docs/plan.md
- [x] T003 [P] research.md complete with 6 decision records in specs/026-release-batch-docs/research.md
- [x] T004 [P] data-model.md complete with all entity changes in specs/026-release-batch-docs/data-model.md
- [x] T005 [P] contracts/api.md complete with 4 new endpoints + 3 modified in specs/026-release-batch-docs/contracts/api.md
- [x] T006 [P] checklists/requirements.md complete and all items passing in specs/026-release-batch-docs/checklists/requirements.md

---

## Phase 2: Foundational (Release Verification)

**Purpose**: Confirm the shipped release is correctly tagged and deployed before closing out tasks.

**⚠️ CRITICAL**: Verify before marking any user story tasks complete.

- [x] T007 Verify tag v2026.03.11e on chat-backend main commit 94e88e9
- [x] T008 [P] Verify tag v2026.03.11h on chat-frontend main commit 290ca3f
- [x] T009 [P] Verify tag v2026.03.11c-workbench on workbench-frontend main commit 9f68a63
- [x] T010 Production smoke check — api.mentalhelp.chat /api/settings → 200
- [x] T011 [P] Production smoke check — mentalhelp.chat → 200
- [x] T012 [P] Production smoke check — workbench.mentalhelp.chat → 200
- [x] T013 Backmerge main → develop applied in chat-backend (PR #161)
- [x] T014 [P] Backmerge main → develop applied in chat-frontend (PR #104)
- [x] T015 [P] Backmerge main → develop applied in workbench-frontend (PR #80)

**Checkpoint**: Release verified — user story documentation tasks can proceed.

---

## Phase 3: User Story 1 — Chat Session Resilience (Priority: P1)

**Goal**: Confirm session resilience implementation is documented and verified end-to-end.

**Independent Test**: Hard-reload dev.mentalhelp.chat after a chat → conversation resumes.
Disable network → send message → amber banner + pending status. Re-enable → auto-sent.

- [x] T016 [US1] Verify session resume confirmed on dev regression sweep (Flow 1 in this session)
- [x] T017 [P] [US1] Verify session resume confirmed on production (direct observation post-deploy)
- [x] T018 [P] [US1] Document localStorage key contract in data-model.md specs/026-release-batch-docs/data-model.md
- [x] T019 [US1] Document session restore API endpoint in specs/026-release-batch-docs/contracts/api.md
- [x] T020 [US1] Sync Jira epic for session resilience to Done status (MTB-554)

**Checkpoint**: US1 fully shipped, documented, and Jira closed.

---

## Phase 4: User Story 2 — RAG Transparency for Testers (Priority: P2)

**Goal**: Confirm RAG detail panel is documented and gating is correct.

**Independent Test**: Tester-tagged account sees RAG panel after assistant response.
Non-tester account sees no panel. Zero-docs case shows empty state (not blank).

- [x] T021 [US2] Verify RAG panel visible on dev for tester-tagged accounts (regression sweep)
- [x] T022 [P] [US2] Document RAGCallDetail transient entity in specs/026-release-batch-docs/data-model.md
- [x] T023 [P] [US2] Document POST /api/chat/message ragCallDetail extension in specs/026-release-batch-docs/contracts/api.md
- [x] T024 [US2] Sync Jira epic for RAG tester flag to Done status (MTB-706)

**Checkpoint**: US2 fully shipped, documented, and Jira closed.

---

## Phase 5: User Story 3 — Survey Gate Integration (Priority: P2)

**Goal**: Confirm survey gate flow is documented and gate-check API is correct.

**Independent Test**: User in survey-gated group sees survey on first chat visit.
After completion, chat loads directly on subsequent visits. Gate-check returns
`completed: true` for that user.

- [x] T025 [US3] Verify gate survey flow on dev regression sweep (Flow 1 — SurveyGateTest group)
- [x] T026 [P] [US3] Document SurveyResponse entity in specs/026-release-batch-docs/data-model.md
- [x] T027 [P] [US3] Document gate-check, survey-responses POST/PATCH in specs/026-release-batch-docs/contracts/api.md
- [x] T028 [US3] Sync Jira epic for survey gate integration to Done status (MTB-583)

**Checkpoint**: US3 fully shipped, documented, and Jira closed.

---

## Phase 6: User Story 4 — Survey Schema Editor Enhancements (Priority: P3)

**Goal**: Confirm schema editor enhancements are documented with updated visibility model.

**Independent Test**: Workbench Schema Editor shows markdown instructions field, allows
multi-condition visibility rules with NOT_IN, saves freetext option on choice questions,
auto-saves on field blur, and exports/imports JSON with full fidelity.

- [x] T029 [US4] Verify schema editor enhancements on dev regression sweep (Flow 3 — workbench review)
- [x] T030 [P] [US4] Document SurveySchema instructions field change in specs/026-release-batch-docs/data-model.md
- [x] T031 [P] [US4] Document VisibilityCondition multi-condition schema in specs/026-release-batch-docs/data-model.md
- [x] T032 [P] [US4] Document survey-schemas GET/PUT instructions in specs/026-release-batch-docs/contracts/api.md
- [x] T033 [US4] Sync Jira epic for survey schema editor enhancements to Done status (MTB-606)

**Checkpoint**: US4 fully shipped, documented, and Jira closed.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Close out the release cycle and publish the activity report.

- [x] T034 All feature + bugfix branches deleted from chat-frontend, chat-backend, workbench-frontend
- [x] T035 [P] All local develop branches synced to origin/develop across repos
- [x] T036 Open PR from 026-release-batch-docs → main in MentalHelpGlobal/client-spec
- [x] T037 [P] Run /speckit.sync push to transition locally-done tasks to Jira Done
- [ ] T038 [P] Publish biweekly activity report to Confluence covering this batch (/mhg.activity-report)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: All pre-complete — spec artifacts committed ✅
- **Phase 2 (Foundational)**: Pre-complete — release deployed and verified ✅
- **Phases 3–6 (User Stories)**: All pre-complete — implementation shipped ✅
- **Phase 7 (Polish)**: Only T036–T038 remain — open now

### User Story Dependencies

- **US1 (P1)**: Independent — no dependency on other stories
- **US2 (P2)**: Independent — gating is orthogonal to session resilience
- **US3 (P2)**: Independent — survey gate runs before session creation, no coupling
- **US4 (P3)**: Independent — workbench editor changes do not affect chat runtime

### Parallel Opportunities

All remaining open tasks (T020, T024, T028, T033, T036, T037, T038) can be executed
concurrently — they touch different systems (Jira, GitHub, Confluence) with no shared state.

---

## Parallel Example: Remaining Work

```bash
# All can run simultaneously:
Task T020: Sync Jira — session resilience epic → Done
Task T024: Sync Jira — RAG tester flag epic → Done (MTB-706)
Task T028: Sync Jira — survey gate epic → Done
Task T033: Sync Jira — schema editor epic → Done
Task T036: Open PR 026-release-batch-docs → main in client-spec
Task T037: /speckit.sync push
Task T038: /mhg.activity-report publish
```

---

## Implementation Strategy

### MVP (already shipped — P1 story)

Session resilience (US1) was the highest-priority item and shipped as the lead
feature in PR #101. The other stories (US2, US3, US4) shipped in the same batch.

### Remaining Open Tasks (5 of 38)

| Task | Description | Owner |
|---|---|---|
| T020 | Jira sync — session resilience | `/speckit.sync push` |
| T024 | Jira sync — RAG tester flag (MTB-706) | `/speckit.sync push` |
| T028 | Jira sync — survey gate | `/speckit.sync push` |
| T033 | Jira sync — schema editor | `/speckit.sync push` |
| T036 | Open client-spec PR → main | `gh pr create` |
| T037 | speckit.sync push | `/speckit.sync push` |
| T038 | Publish activity report | `/mhg.activity-report` |

---

## Notes

- [P] tasks = different systems/files, no dependencies — all can run concurrently
- Pre-checked tasks [x] are verified complete; only unchecked [ ] tasks remain
- T036 + T037 + T038 are the recommended next actions after this tasks.md is committed

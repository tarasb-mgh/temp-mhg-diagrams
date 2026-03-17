# Tasks: Workbench UX Wayfinding and Information Architecture Overhaul

**Input**: Design documents from `specs/029-workbench-ux-wayfinding/`  
**Prerequisites**: `plan.md` (required), `spec.md` (required), `research.md`, `data-model.md`, `contracts/`, `quickstart.md`  
**Branch**: `029-workbench-ux-wayfinding` | **Date**: 2026-03-13

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no blocking dependency)
- **[Story]**: User story reference (`[US1]`, `[US2]`, `[US3]`)
- Every task includes an explicit file path

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Initialize planning artifacts needed by all stories.

- [X] T001 Create role matrix section scaffold in `specs/029-workbench-ux-wayfinding/research.md`. ? MTB-731
- [X] T002 [P] Create rerun results section scaffold in `specs/029-workbench-ux-wayfinding/research.md`. ? MTB-724
- [X] T003 [P] Create remediation item table scaffold in `specs/029-workbench-ux-wayfinding/contracts/remediation-backlog.md`. ? MTB-727

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Enforce hard gates before any story-level work.

**CRITICAL**: No story work starts before this phase is complete.

- [X] T004 Enforce 5-role required matrix in `specs/029-workbench-ux-wayfinding/spec.md` and `specs/029-workbench-ux-wayfinding/quickstart.md`. ? MTB-723
- [X] T005 Enforce OTP fallback as primary dev audit sign-in in `specs/029-workbench-ux-wayfinding/spec.md` and `specs/029-workbench-ux-wayfinding/quickstart.md`. ? MTB-725
- [X] T006 Enforce rerun fail gate on blocked roles in `specs/029-workbench-ux-wayfinding/spec.md` and `specs/029-workbench-ux-wayfinding/checklists/requirements.md`. ? MTB-728
- [X] T007 [P] Enforce 90-day raw evidence retention rule in `specs/029-workbench-ux-wayfinding/spec.md` and `specs/029-workbench-ux-wayfinding/contracts/ux-audit-contract.md`. ? MTB-726
- [X] T008 [P] Add "without manual guidance" measurable validation rule to `specs/029-workbench-ux-wayfinding/spec.md` and `specs/029-workbench-ux-wayfinding/quickstart.md`. ? MTB-730

**Checkpoint**: Foundational quality gates are explicit and consistent across core artifacts.

---

## Phase 3: User Story 1 - Role-Based UX Baseline Audit (Priority: P1)

**Goal**: Produce deterministic baseline evidence and a normalized defect backlog across all required roles.

**Independent Test**: The 5-role baseline run produces complete evidence plus a severity-tagged issue table.

### Implementation for User Story 1

- [X] T009 [US1] Record approved role/account matrix (owner, admin, reviewer, researcher, group-admin) in `specs/029-workbench-ux-wayfinding/research.md`. ? MTB-732
- [X] T010 [P] [US1] Document baseline run metadata contract mapping in `specs/029-workbench-ux-wayfinding/contracts/ux-audit-contract.md`. ? MTB-729
- [X] T011 [P] [US1] Capture owner role evidence paths and outcomes in `specs/029-workbench-ux-wayfinding/research.md`. ? MTB-735
- [X] T012 [P] [US1] Capture admin and group-admin evidence paths and outcomes in `specs/029-workbench-ux-wayfinding/research.md`. ? MTB-737
- [X] T013 [P] [US1] Capture reviewer and researcher evidence paths and outcomes in `specs/029-workbench-ux-wayfinding/research.md`. ? MTB-738
- [X] T014 [US1] Consolidate normalized findings table (id, severity, role, flow, step, impact, evidence, proposal, owner) in `specs/029-workbench-ux-wayfinding/research.md`. ? MTB-733
- [X] T015 [US1] Add baseline blocker list with explicit P1/P2/P3 prioritization in `specs/029-workbench-ux-wayfinding/spec.md`. ? MTB-734
- [X] T016 [US1] Add evidence retention verification entry for baseline run in `specs/029-workbench-ux-wayfinding/checklists/requirements.md`. ? MTB-739

**Checkpoint**: US1 is complete when the baseline is fully documented for all 5 roles and blockers are prioritized.

---

## Phase 4: User Story 2 - Intuitive Navigation and Menu Clarity (Priority: P1)

**Goal**: Deliver implementation-ready IA and wayfinding contracts that prevent user disorientation.

**Independent Test**: IA artifacts demonstrate 3-click discoverability and deterministic return-path behavior for critical flows.

### Implementation for User Story 2

- [X] T017 [US2] Build current-state navigation map by role in `specs/029-workbench-ux-wayfinding/data-model.md`. ? MTB-748
- [X] T018 [US2] Define target IA hierarchy (sections, labels, parent-child flow) in `specs/029-workbench-ux-wayfinding/data-model.md`. ? MTB-747
- [X] T019 [P] [US2] Define navigation and deep-flow contract details in `specs/029-workbench-ux-wayfinding/contracts/ux-audit-contract.md`. ? MTB-751
- [X] T020 [P] [US2] Convert P1/P2 findings into remediation items with required fields in `specs/029-workbench-ux-wayfinding/contracts/remediation-backlog.md`. ? MTB-746
- [X] T021 [US2] Add repository routing for each remediation item (`workbench-frontend`, `chat-frontend-common`, conditional `chat-backend`) in `specs/029-workbench-ux-wayfinding/contracts/remediation-backlog.md`. ? MTB-745
- [X] T022 [US2] Define measurable wayfinding quality gates (first-click success, backtrack clarity, dead-end reduction) in `specs/029-workbench-ux-wayfinding/spec.md`. ? MTB-740
- [X] T023 [US2] Document sign-in discoverability and localization remediation scope in `specs/029-workbench-ux-wayfinding/research.md`. ? MTB-744

**Checkpoint**: US2 is complete when remediation backlog items are implementation-ready and mapped to owner repositories.

---

## Phase 5: User Story 3 - First-Use Guidance for Complex Flows (Priority: P2)

**Goal**: Define first-use guidance patterns that reduce uncertainty and errors in complex flows.

**Independent Test**: Task-based usability script shows users can complete selected flows with in-product cues and <=1 failed attempt per flow.

### Implementation for User Story 3

- [X] T024 [US3] Identify top confusion points from baseline findings in `specs/029-workbench-ux-wayfinding/research.md`. ? MTB-749
- [X] T025 [US3] Define contextual guidance patterns (purpose hint, next step, consequence visibility) in `specs/029-workbench-ux-wayfinding/contracts/ux-audit-contract.md`. ? MTB-752
- [X] T026 [P] [US3] Define risky-action guardrails (confirmation, rollback path, post-success routing) in `specs/029-workbench-ux-wayfinding/contracts/ux-audit-contract.md`. ? MTB-736
- [X] T027 [US3] Formalize first-use validation script and scoring in `specs/029-workbench-ux-wayfinding/quickstart.md`. ? MTB-741
- [X] T028 [US3] Add usability acceptance checks tied to SC-003 in `specs/029-workbench-ux-wayfinding/checklists/requirements.md`. ? MTB-750

**Checkpoint**: US3 is complete when first-use guidance and validation protocol are testable and measurable.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Execute rerun gate and produce final acceptance output.

- [X] T029 [US1] Run full 5-role rerun and record role outcomes in `specs/029-workbench-ux-wayfinding/research.md`. ? MTB-743
- [X] T030 [US2] Compare baseline vs rerun metrics and document deltas in `specs/029-workbench-ux-wayfinding/research.md`. ? MTB-754
- [X] T031 [US3] Validate rerun fail/pass gate logic in `specs/029-workbench-ux-wayfinding/checklists/requirements.md`. ? MTB-753
- [X] T032 Publish final rerun report and unresolved blocker list in `specs/029-workbench-ux-wayfinding/research.md`. ? MTB-742

---

## Phase 7: Real-Repo Delivery and Validation

**Purpose**: Ensure UX improvements are implemented and validated in target repositories, not only in specification artifacts.

- [X] T033 [US2] Validate and harden Workbench login UX entry in `../workbench-frontend/src/features/auth/WorkbenchLoginPage.tsx` (OTP primary + Google fallback status). ? MTB-759
- [X] T034 [US2] Validate and polish navigation context bar in `../workbench-frontend/src/features/workbench/WorkbenchLayout.tsx` for deep-flow return clarity. ? MTB-757
- [X] T035 [US2] Finalize shared auth-state noise reduction in `../chat-frontend-common/src/stores/authStore.ts` and verify no redundant post-refresh logout calls. ? MTB-758
- [X] T036 [US1] Run Playwright rerun against dev URL for all 5 roles and store evidence in `artifacts/workbench-ux-audit-<timestamp>/`. ? MTB-755
- [X] T037 [US1] Update `specs/029-workbench-ux-wayfinding/research.md` with authenticated rerun outcomes and final SC-003/SC-004/SC-005 verdict. ? MTB-756

---

## Dependencies & Execution Order

### Phase Dependencies

- Phase 1 -> Phase 2 -> Phase 3/4/5 -> Phase 6 -> Phase 7
- User story phases depend on completion of Phase 2
- Phase 6 depends on completion of US1, US2, and US3 deliverables
- Phase 7 depends on completion of Phase 6 documentation outputs and target-repo implementation readiness

### User Story Dependencies

- **US1 (P1)**: starts after Foundational phase
- **US2 (P1)**: starts after Foundational phase; can run in parallel with US1 after baseline inputs exist
- **US3 (P2)**: starts after baseline findings from US1

### Parallel Opportunities

- Phase 1: `T002`, `T003`
- Phase 2: `T007`, `T008`
- US1: `T010`, `T011`, `T012`, `T013`
- US2: `T019`, `T020`
- US3: `T026`

---

## Parallel Example: User Story 1

```text
T011 [US1] Capture owner role evidence paths and outcomes in specs/029-workbench-ux-wayfinding/research.md.
T012 [US1] Capture admin and group-admin evidence paths and outcomes in specs/029-workbench-ux-wayfinding/research.md.
T013 [US1] Capture reviewer and researcher evidence paths and outcomes in specs/029-workbench-ux-wayfinding/research.md.
```

---

## Implementation Strategy

### MVP First (US1 only)

1. Complete Phase 1 and Phase 2
2. Complete Phase 3 (US1)
3. Validate baseline quality gates before moving on

### Incremental Delivery

1. Deliver US1 baseline and blocker inventory
2. Deliver US2 IA/remediation backlog
3. Deliver US3 guidance and usability protocol
4. Execute Phase 6 rerun and acceptance

### Suggested MVP Scope

- Phases 1-3 only (through `T016`) for the first executable increment

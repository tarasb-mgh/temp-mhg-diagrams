# Tasks: Split Chat and Workbench Frontend + Backend

**Input**: Design documents from `/specs/001-split-workbench-app/`  
**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/`, `quickstart.md`

**Tests**: Included because the spec explicitly requires validation evidence for route split, backend boundary isolation, domain topology, access policies, and journey continuity.

**Organization**: Tasks grouped by user story for independent delivery. Backend, infra, and domain work is distributed across Setup/Foundational and story phases.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Parallelizable (different files, no unmet dependencies)
- **[Story]**: `[US1]`, `[US2]`, `[US3]` in story phases only
- All tasks include exact file paths

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Scaffold shared structures across frontend, backend, infra, and evidence.

- [x] T001 Create feature evidence index in `client-spec/evidence/001-split-workbench-app/README.md`
- [x] T002 Create frontend split-route configuration scaffold in `chat-frontend/src/routes/experienceRoutes.ts`
- [x] T003 [P] Create frontend split-navigation constants in `chat-frontend/src/routes/experienceNav.ts`
- [x] T004 [P] Create backend workbench service scaffold — SERVICE_SURFACE filtering in `chat-backend/src/index.ts`
- [x] T005 [P] Create infra domain topology config scaffold in `chat-infra/config/domain-topology.json`
- [x] T006 [P] Create E2E validation fixtures scaffold in `chat-ui/tests/e2e/routing/fixtures/experience-split.fixtures.ts`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core FE/BE/infra primitives that all stories depend on.

**⚠️ CRITICAL**: Complete before user-story implementation.

### Frontend foundations

- [x] T007 Implement canonical chat/workbench route resolver in `chat-frontend/src/routes/experienceRoutes.ts`
- [x] T008 Implement shared session-surface context guard in `chat-frontend/src/services/sessionSurfaceGuard.ts`
- [x] T009 Implement access-policy evaluation utility in `chat-frontend/src/services/accessPolicy.ts`
- [x] T010 Implement legacy-route mapping registry in `chat-frontend/src/routes/legacyRouteMap.ts`

### Backend foundations

- [x] T011 Implement backend route namespace split (chat routes vs workbench routes) in `chat-backend/src/index.ts`
- [x] T012 Implement workbench-only middleware/authorization guard in `chat-backend/src/middleware/workbenchGuard.ts`
- [x] T013 [P] Implement CORS policy enforcement per surface host in `chat-backend/src/index.ts`

### Infra foundations

- [x] T014 Provision workbench DNS records for prod and dev in `chat-infra/terraform/dns/records.tf`
- [x] T015 Configure LB host rules for workbench FE/API domains in `chat-infra/scripts/gcloud/url-map-https.yaml`
- [x] T016 [P] Configure independent Cloud Run service for workbench backend in `chat-infra/scripts/gcloud/provision-workbench-domains.ps1`

### Test/CI foundations

- [x] T017 [P] Add split regression test helpers in `chat-ui/tests/e2e/routing/helpers/splitAssertions.ts`
- [x] T018 [P] Add CI dual-deploy for split backend in `chat-backend/.github/workflows/ci.yml`

**Checkpoint**: Foundation complete; stories can proceed.

---

## Phase 3: User Story 1 - Access Chat and Workbench as Separate Experiences (Priority: P1) 🎯 MVP

**Goal**: Users open chat and workbench through separate entry points, on separate domains, backed by separate services.

**Independent Test**: Sign in, open chat at existing host, open workbench at `workbench.mentalhelp.chat` (prod pattern), verify isolated controls/navigation and API host usage.

### Tests for User Story 1

- [x] T019 [P] [US1] Add FE entry-point split unit tests in `chat-frontend/src/test/unit/experienceRoutes.test.ts`
- [x] T020 [P] [US1] Add FE/BE split E2E test in `chat-ui/tests/e2e/routing/experience-entrypoints.spec.ts`
- [x] T021 [P] [US1] Add responsive split-surface viewport regression test in `chat-ui/tests/e2e/routing/experience-responsive.spec.ts`
- [x] T022 [P] [US1] Add domain topology correctness E2E test in `chat-ui/tests/e2e/api/domain-topology.spec.ts`

### Implementation for User Story 1

- [x] T023 [US1] Implement separate chat/workbench launch navigation in `chat-frontend/src/App.tsx`
- [x] T024 [P] [US1] Implement chat surface shell isolation in `chat-frontend/src/features/chat/ChatShell.tsx`
- [x] T025 [P] [US1] Implement workbench surface shell isolation in `chat-frontend/src/features/workbench/WorkbenchShell.tsx`
- [x] T026 [US1] Wire deep-link handling for both surfaces in `chat-frontend/src/App.tsx`
- [x] T027 [US1] Wire workbench frontend to use dedicated workbench API host in `chat-frontend/src/services/apiClient.ts`
- [x] T028 [US1] Deploy workbench backend service independently — CI workflow in `chat-backend/.github/workflows/ci.yml`

**Checkpoint**: US1 independently functional on split domains.

---

## Phase 4: User Story 2 - Preserve Role-Based Access and Context Separation (Priority: P2)

**Goal**: Role boundaries are enforced across FE and BE surfaces; valid context is preserved across allowed transitions; backend contracts remain isolated.

**Independent Test**: Chat-only user is blocked from workbench FE routes and workbench API paths; workbench-authorized user retains session context; workbench-only data is not exposed on chat API.

### Tests for User Story 2

- [x] T029 [P] [US2] Add FE access-policy unit tests in `chat-frontend/src/test/unit/accessPolicy.test.ts`
- [x] T030 [P] [US2] Add FE/BE role-boundary E2E test in `chat-ui/tests/e2e/workbench/access-boundary.spec.ts`
- [x] T031 [P] [US2] Add backend contract isolation E2E test in `chat-ui/tests/e2e/api/contract-isolation.spec.ts`
- [x] T032 [P] [US2] Add accessibility and locale regression checks for split surfaces in `chat-ui/tests/e2e/workbench/accessibility-i18n.spec.ts`

### Implementation for User Story 2

- [x] T033 [US2] Enforce workbench FE route guard behavior in `chat-frontend/src/routes/workbenchGuard.tsx`
- [x] T034 [P] [US2] Implement denied-access fallback UX in `chat-frontend/src/features/workbench/WorkbenchAccessDenied.tsx`
- [x] T035 [P] [US2] Preserve cross-surface session context transitions in `chat-frontend/src/services/sessionSurfaceGuard.ts`
- [x] T036 [US2] Ensure unauthorized deep-link fallback behavior in `chat-frontend/src/App.tsx`
- [x] T037 [US2] Enforce workbench-only backend authorization and contract isolation in `chat-backend/src/middleware/workbenchGuard.ts`

**Checkpoint**: US2 independently functional.

---

## Phase 5: User Story 3 - Maintain Stable User Flows During Transition (Priority: P3)

**Goal**: Legacy links and critical journeys keep working through deterministic routing across old/new domains.

**Independent Test**: Known legacy bookmarks/routes resolve to canonical split hosts/routes; critical journeys complete.

### Tests for User Story 3

- [x] T038 [P] [US3] Add legacy-route mapping unit tests in `chat-frontend/src/test/unit/legacyRouteMap.test.ts`
- [x] T039 [P] [US3] Add legacy bookmark continuity E2E test in `chat-ui/tests/e2e/routing/legacy-route-compat.spec.ts`

### Implementation for User Story 3

- [x] T040 [US3] Implement legacy-to-canonical redirect rules in `chat-frontend/src/routes/legacyRedirects.tsx`
- [x] T041 [P] [US3] Implement invalid-route recovery experience in `chat-frontend/src/routes/RouteRecovery.tsx`
- [x] T042 [P] [US3] Integrate journey continuity checks for split routes in `chat-ui/tests/e2e/chat/journey-continuity.spec.ts`
- [x] T043 [US3] Document supported legacy route matrix in `client-spec/specs/001-split-workbench-app/quickstart.md`

**Checkpoint**: US3 independently functional.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final validation, evidence capture, and governance completion.

- [x] T044 [P] Align validation contract fields with implemented checks in `client-spec/specs/001-split-workbench-app/contracts/experience-split-validation.yaml`
- [x] T045 [P] Capture split-routing, backend boundary, and domain evidence summary in `client-spec/evidence/001-split-workbench-app/validation-summary.md`
- [x] T046 Update post-deploy smoke checklist for split routes, domains, and key APIs in `client-spec/specs/001-split-workbench-app/quickstart.md`
- [x] T047 Add split feature merge and gate checklist notes in `client-spec/specs/001-split-workbench-app/plan.md`
- [x] T048 Record branch hygiene completion (remote/local delete + develop sync) in `client-spec/evidence/001-split-workbench-app/branch-hygiene.md`
- [x] T049 [P] Add explicit responsive breakpoint verification checklist in `client-spec/specs/001-split-workbench-app/quickstart.md`
- [x] T050 [P] Add explicit PWA installability and fallback verification checks in `client-spec/specs/001-split-workbench-app/quickstart.md`
- [x] T051 [P] Add accessibility and localization continuity evidence checklist in `client-spec/specs/001-split-workbench-app/quickstart.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: starts immediately.
- **Phase 2 (Foundational)**: depends on Phase 1; blocks all story work.
- **Phase 3 (US1)**: depends on Phase 2; MVP-first.
- **Phase 4 (US2)**: depends on Phase 2; can progress in parallel with US1 after shared route/service wiring stabilizes.
- **Phase 5 (US3)**: depends on Phase 2; can progress in parallel with US1/US2.
- **Phase 6 (Polish)**: depends on completion of selected stories.

### User Story Dependencies

- **US1 (P1)**: no dependency on other stories after foundational phase.
- **US2 (P2)**: reuses foundational route/access utilities and backend guard; independently testable.
- **US3 (P3)**: reuses foundational route mapping; independently testable.

### Parallel Opportunities

- Setup: `T003`, `T004`, `T005`, `T006`
- Foundational: `T013`, `T016`, `T017`, `T018`
- US1: `T019`, `T020`, `T021`, `T022`, `T024`, `T025`
- US2: `T029`, `T030`, `T031`, `T032`, `T034`, `T035`
- US3: `T038`, `T039`, `T041`, `T042`
- Polish: `T044`, `T045`, `T049`, `T050`, `T051`

---

## Parallel Example: User Story 1

```bash
Task: "Add FE entry-point split unit tests in chat-frontend/src/routes/experienceRoutes.test.ts"
Task: "Add FE/BE split E2E test in chat-ui/tests/routing/experience-entrypoints.spec.ts"
Task: "Add domain topology correctness E2E test in chat-ui/tests/api/domain-topology.spec.ts"

Task: "Implement chat surface shell isolation in chat-frontend/src/features/chat/ChatShell.tsx"
Task: "Implement workbench surface shell isolation in chat-frontend/src/features/workbench/WorkbenchShell.tsx"
```

---

## Parallel Example: User Story 2

```bash
Task: "Add FE access-policy unit tests in chat-frontend/src/services/accessPolicy.test.ts"
Task: "Add FE/BE role-boundary E2E test in chat-ui/tests/workbench/access-boundary.spec.ts"
Task: "Add backend contract isolation E2E test in chat-ui/tests/api/contract-isolation.spec.ts"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phases 1-2 (setup + foundation across FE/BE/infra).
2. Complete Phase 3 (US1): FE split + BE split + domain wiring.
3. Validate on dedicated workbench domains independently.
4. Demo/release MVP increment.

### Incremental Delivery

1. Foundation complete (Phases 1-2).
2. Deliver US1 (experience split with backend/domain separation).
3. Deliver US2 (role enforcement and contract isolation).
4. Deliver US3 (legacy route continuity).
5. Complete polish and evidence tasks.

### Parallel Team Strategy

1. Team completes Setup + Foundational phases collaboratively.
2. Then split:
   - Developer A: US1 (FE shell + BE service + infra)
   - Developer B: US2 (access policy FE + BE guard + contract isolation)
   - Developer C: US3 (legacy routing + recovery)
3. Converge for Phase 6 evidence and release hygiene.

---

## Notes

- All tasks follow strict checklist format.
- Story labels used only in story phases.
- Backend tasks span `chat-backend` (service split, guards, CORS).
- Infra tasks span `chat-infra` (DNS, LB, Cloud Run).
- PR-only integration into `develop` for all affected split repositories.
- Post-deploy smoke checks cover both domain and service boundaries.

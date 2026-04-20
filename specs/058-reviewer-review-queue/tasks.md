---
description: "Tasks: Reviewer Review Queue — Full Implementation and E2E Validation"
---

# Tasks: Reviewer Review Queue — Full Implementation and E2E Validation

**Jira Epic**: [MTB-1449](https://mentalhelpglobal.atlassian.net/browse/MTB-1449)
**Jira Stories**: US-1 MTB-1450 · US-2 MTB-1451 · US-3 MTB-1452 · US-4 MTB-1453 · US-5 MTB-1454 · US-6 MTB-1455 · US-7 MTB-1456 · US-8 MTB-1457

**Input**: Design documents from `/specs/058-reviewer-review-queue/`
**Prerequisites**: `plan.md` ✓, `spec.md` ✓, `research.md` ✓, `data-model.md` ✓, `contracts/openapi.yaml` ✓, `quickstart.md` ✓
**Tests**: Constitution III mandates positive + negative tests for every user-facing scenario; tests are NOT optional and are first-class tasks here.
**Organization**: One Phase per spec User Story; foundational + setup + polish phases bracket the story phases.

## Format: `- [ ] [TaskID] [P?] [Story?] Description with file path`

- **[P]**: Different file, no incomplete-task dependencies — safe to parallelise.
- **[Story]**: `[US1]`..`[US8]` only on user-story phase tasks. Setup / Foundational / Polish carry no story label.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Cross-repo bring-up: types, design-system, feature flag, branches.

- [ ] T001 Verify branch `058-reviewer-review-queue` exists in `client-spec`, create matching branches in `chat-types`, `chat-backend`, `workbench-frontend`, `chat-frontend-common`, `chat-ui` per Constitution VII (e.g., `058-reviewer-review-queue` in each)
- [ ] T002 [P] Create scaffold folder `chat-types/src/reviewer-review-queue/` with empty `index.ts` exporting later modules
- [ ] T003 [P] Create scaffold folder `chat-backend/src/modules/reviewer-queue/` with `routes/`, `services/`, `repos/`, `middleware/` subfolders and `index.ts` registration stub
- [ ] T004 [P] Create scaffold folder `workbench-frontend/src/modules/reviewer-queue/` with `pages/`, `components/`, `hooks/`, `services/`, `i18n/` subfolders and `index.ts`
- [ ] T005 [P] Add feature flag `feature.reviewer_review_queue_v2` to `chat-backend/src/config/feature-flags.ts` (default OFF in dev, ON in dev only after smoke green)
- [ ] T006 [P] Add same feature flag to `workbench-frontend/src/config/feature-flags.ts`
- [ ] T007 Audit `chat-frontend-common/src/components/` to confirm whether a canonical `<Toggle>` exists; if missing, create `chat-frontend-common/src/components/Toggle.tsx` with WCAG-AA-compliant accessible name + keyboard operability (FR-031d)
- [ ] T008 [P] Tag a minor release of `chat-frontend-common` containing the canonical Toggle (only if T007 introduced it) and bump dependency in `workbench-frontend/package.json`

**Checkpoint**: All five repos have a `058-reviewer-review-queue` branch, scaffolds exist, feature flag wired, canonical Toggle available.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Shared types, DB schema, RBAC middleware, audit middleware, PII detector — every user story depends on these.

⚠️ **CRITICAL**: User-story phases MUST NOT begin until this phase is complete in `chat-types` and `chat-backend`.

- [ ] T009 [P] Create shared type module `chat-types/src/reviewer-review-queue/session.ts` with `Space`, `ChatSession`, `SessionCard`, `SessionDetail` matching `data-model.md` §2–§4
- [ ] T010 [P] Create shared type module `chat-types/src/reviewer-review-queue/review.ts` with `Review`, `Rating`, `RatingUpsert` matching `data-model.md` §5, §12
- [ ] T011 [P] Create shared type module `chat-types/src/reviewer-review-queue/tags.ts` with `ClinicalTagDef`, `ClinicalTagAttachment`, `ReviewTagDef`, `ReviewTagAttachment`, `MessageTagComment` per `data-model.md` §6–§10
- [ ] T012 [P] Create shared type module `chat-types/src/reviewer-review-queue/red-flag.ts` with `RedFlag` per `data-model.md` §11
- [ ] T013 [P] Create shared type module `chat-types/src/reviewer-review-queue/change-request.ts` with `ChangeRequest` per `data-model.md` §13
- [ ] T014 [P] Create shared type module `chat-types/src/reviewer-review-queue/notification.ts` with `Notification` and the three category enums per `data-model.md` §14
- [ ] T015 [P] Create shared type module `chat-types/src/reviewer-review-queue/reports.ts` with `ReviewerReports` per contract `openapi.yaml#/components/schemas/ReviewerReports`
- [ ] T016 [P] Extend `chat-types/src/audit-log.ts` to add `legalHold: boolean` and `tier: 'hot'|'warm'|'cold'` per `data-model.md` §15
- [ ] T017 Re-export every new module from `chat-types/src/reviewer-review-queue/index.ts` and `chat-types/src/index.ts`
- [ ] T018 Tag a `chat-types` minor release; bump dependency in `chat-backend/package.json` and `workbench-frontend/package.json`
- [ ] T019 Create migration file `chat-backend/migrations/2026XXXXXX_058_reviewer_review_queue.ts` adding columns and tables per `data-model.md` (clinical_tag_defs.language_group/description/deleted_at; review_tag_defs.language_group/description/deleted_at; new tables: clinical_tag_attachments, review_tag_attachments, message_tag_comments, red_flags, reviews, ratings, change_requests, notifications; audit_log_entries.legal_hold + tier; indexes per `data-model.md`)
- [ ] T020 [P] Create RBAC middleware `chat-backend/src/modules/reviewer-queue/middleware/space-scope.ts` enforcing FR-010 (request narrowed to Reviewer's Space membership; "All Spaces" lifts narrowing only over member set)
- [ ] T021 [P] Create audit middleware `chat-backend/src/modules/reviewer-queue/middleware/audit-emitter.ts` emitting append-only entries for every state-changing endpoint (FR-049, FR-050)
- [ ] T022 Create PII detector middleware `chat-backend/src/modules/reviewer-queue/middleware/pii-detector.ts` wrapping responses for `/api/reviewer/sessions/:id` and `/api/reviewer/sessions/:id/state` (FR-047c)
- [ ] T023 [P] Create out-of-process Python PII worker `chat-backend/src/workers/pii-presidio.py` (Presidio + custom recognisers for clinical IDs); wire as gRPC / local HTTP service started by chat-backend on boot
- [ ] T024 [P] Create unit tests `chat-backend/tests/unit/middleware/pii-detector.test.ts` with the canonical PII corpus (positive: each FR-047c category masked; negative: malformed input → safe fallback) — **mandatory positive + negative per Constitution III**
- [ ] T025 [P] Create unit tests `chat-backend/tests/unit/middleware/space-scope.test.ts` (positive: in-Space access succeeds; negative: out-of-Space access returns 403)
- [ ] T026 [P] Create unit tests `chat-backend/tests/unit/middleware/audit-emitter.test.ts` (positive: emission shape; negative: malformed event drops with structured error)
- [ ] T027 Wire `chat-backend/src/app.ts` to mount the new `reviewer-queue` router behind the feature flag (`feature.reviewer_review_queue_v2`)
- [ ] T028 [P] Add `GET /api/health/ping` endpoint per contract; ensure it responds < 50 ms; create unit test (positive: 200 OK; negative: simulated upstream failure → still responds, distinguishing-mode helper documented)
- [ ] T029 [P] Add `GET /api/spaces/me` handler in `chat-backend/src/modules/reviewer-queue/routes/spaces.ts` returning Reviewer's member Spaces only (FR-010a); create unit test (positive: Spaces returned; negative: non-Reviewer role → 403)

**Checkpoint**: Shared types published, DB migrated, RBAC + audit + PII middleware in place with mandatory tests, ping + spaces endpoints live behind the flag.

---

## Phase 3: User Story 1 — Reviewer rates a brand-new session end-to-end (Priority: P1) 🎯 MVP

**Goal**: Reviewer signs in, opens a NEW session, rates every assistant reply with the score selector + criterion + comments + validated answer per FR-016/FR-017, and submits. Session moves to Completed with full Audit Log trail.

**Independent Test**: Quickstart §"Manual happy path — single Reviewer" steps 1–6 + step 10. Constitution III mandates positive + negative test for every acceptance scenario.

### Tests for User Story 1

- [ ] T030 [P] [US1] Backend integration test `chat-backend/tests/integration/reviewer-queue/rating-upsert.test.ts` — positive: PUT `/api/reviewer/reviews/:id/ratings/:msg` with score 9 succeeds; negative: PUT with score 5 + missing criterion returns 422
- [ ] T031 [P] [US1] Backend integration test `chat-backend/tests/integration/reviewer-queue/submit.test.ts` — positive: every assistant message rated → submit returns 200; negative: submit with missing rating → 422
- [ ] T032 [P] [US1] Frontend unit test `workbench-frontend/tests/unit/components/SubmitButton.test.tsx` — positive: enabled when all gating conditions met; negative: disabled when any condition unmet
- [ ] T033 [P] [US1] Frontend unit test `workbench-frontend/tests/unit/components/CriterionSelector.test.tsx` — positive: emits stable criterionId on selection; negative: blank selection blocks submit when score < 8
- [ ] T034 [P] [US1] E2E YAML test cases RQ-001..RQ-008 in `regression-suite/19-reviewer-review-queue.yaml` covering happy path login → open NEW session → rate every reply → submit → see in Completed

### Implementation for User Story 1

- [ ] T035 [P] [US1] Implement `chat-backend/src/modules/reviewer-queue/repos/sessions-repo.ts` with `getQueuePage()`, `getDetail()`, `getState()`
- [ ] T036 [P] [US1] Implement `chat-backend/src/modules/reviewer-queue/repos/reviews-repo.ts` with `getOrCreateDraft(sessionId, reviewerId)`, `submit(reviewId)`, version-status transitions per `data-model.md` §12
- [ ] T037 [P] [US1] Implement `chat-backend/src/modules/reviewer-queue/repos/ratings-repo.ts` with upsert, validation (FR-016/FR-017), and Rating shape per contract
- [ ] T038 [US1] Implement `chat-backend/src/modules/reviewer-queue/services/queue-service.ts` orchestrating queue paging, filters (chip, language, date), Space scope (depends on T035, T020)
- [ ] T039 [US1] Implement `chat-backend/src/modules/reviewer-queue/services/review-service.ts` for draft creation, rating CRUD, submit gating (depends on T036, T037)
- [ ] T040 [US1] Implement `GET /api/reviewer/queue` route in `chat-backend/src/modules/reviewer-queue/routes/queue.ts` (FR-006..FR-010, FR-009b)
- [ ] T041 [US1] Implement `GET /api/reviewer/sessions/:sessionId` route in `chat-backend/src/modules/reviewer-queue/routes/session.ts` (FR-008, FR-021a, FR-024c, FR-047c)
- [ ] T042 [US1] Implement `PUT /api/reviewer/reviews/:reviewId/ratings/:messageId` route in `chat-backend/src/modules/reviewer-queue/routes/ratings.ts`
- [ ] T043 [US1] Implement `POST /api/reviewer/reviews/:reviewId/submit` route enforcing FR-018 gating server-side; emit `review.submitted` audit entry
- [ ] T044 [P] [US1] Implement `workbench-frontend/src/modules/reviewer-queue/services/reviewerApi.ts` axios client mapping every contract endpoint
- [ ] T045 [P] [US1] Implement `workbench-frontend/src/modules/reviewer-queue/hooks/useReviewerQueue.ts` (paged + filtered fetch with refresh-on-action triggers per FR-008a)
- [ ] T046 [US1] Implement `workbench-frontend/src/modules/reviewer-queue/hooks/useReviewerSession.ts` (FR-008 fresh fetch on session open)
- [ ] T047 [US1] Implement `workbench-frontend/src/modules/reviewer-queue/hooks/useSubmitGate.ts` mirroring backend gating (FR-018a..d) for fast UX feedback
- [ ] T048 [P] [US1] Implement `workbench-frontend/src/modules/reviewer-queue/components/SessionCard.tsx` (FR-008)
- [ ] T049 [P] [US1] Implement `workbench-frontend/src/modules/reviewer-queue/components/QueueTabs.tsx` (Pending + Completed) and update `App.tsx` routes
- [ ] T050 [P] [US1] Implement `workbench-frontend/src/modules/reviewer-queue/components/Paginator.tsx` (FR-009b)
- [ ] T051 [US1] Implement `workbench-frontend/src/modules/reviewer-queue/pages/ReviewQueuePage.tsx` composing tabs + chip filter + paginator + cards
- [ ] T052 [P] [US1] Implement `workbench-frontend/src/modules/reviewer-queue/components/ScoreSelector.tsx` (FR-011, FR-012 with i18n tooltips)
- [ ] T053 [P] [US1] Implement `workbench-frontend/src/modules/reviewer-queue/components/CriterionSelector.tsx` (FR-014, eight stable IDs)
- [ ] T054 [P] [US1] Implement `workbench-frontend/src/modules/reviewer-queue/components/ValidatedAnswerField.tsx` (FR-015)
- [ ] T055 [P] [US1] Implement `workbench-frontend/src/modules/reviewer-queue/components/SubmitButton.tsx` (FR-018, FR-018a — countdown UX is in US-2 polish but the basic enable/disable lives here)
- [ ] T056 [US1] Implement `workbench-frontend/src/modules/reviewer-queue/pages/ReviewSessionPage.tsx` composing the rating editor (depends on T046, T052..T055)
- [ ] T057 [P] [US1] Add i18n strings to `workbench-frontend/src/modules/reviewer-queue/i18n/{en,uk,ru}.json` for the namespaces `reviewer.queue` and `reviewer.session` (FR-002a, FR-014 labels)
- [ ] T058 [US1] Wire `feature.reviewer_review_queue_v2` flag to render the new pages in place of the legacy implementation
- [ ] T059 [US1] Manual validation against quickstart §"Manual happy path — single Reviewer" steps 1–6, 10 — record evidence in `evidence/058-T059/`

**Checkpoint**: Reviewer can complete a full single-session happy path on dev. MVP value delivered.

---

## Phase 4: User Story 2 — Reviewer resumes an unfinished review (Priority: P1)

**Goal**: Autosave on blur + page-unload, offline mode with banner + IndexedDB queue, recovery + Submit countdown, reload-confirm modal, multi-tab focus-fetch reconciliation.

**Independent Test**: Quickstart §"Manual happy path — autosave + offline mode" + §"Manual happy path — multi-tab reconciliation".

### Tests for User Story 2

- [ ] T060 [P] [US2] Backend integration test `chat-backend/tests/integration/reviewer-queue/autosave-debounce.test.ts` — positive: rapid blur events all persist; negative: malformed payload → 422
- [ ] T061 [P] [US2] Frontend unit test `workbench-frontend/tests/unit/hooks/useAutosave.test.ts` — positive: blur fires debounced save; negative: simulated 500 from server triggers retry sequence
- [ ] T062 [P] [US2] Frontend unit test `workbench-frontend/tests/unit/hooks/useOfflineMode.test.ts` — positive: ping fail flips to offline + banner; negative: single-request fail does NOT flip to offline (toast path)
- [ ] T063 [P] [US2] Frontend integration test `workbench-frontend/tests/integration/multi-tab.test.tsx` covering FR-034a: positive (non-conflicting EC-19); negative (conflict EC-20)
- [ ] T064 [P] [US2] E2E YAML test cases RQ-009..RQ-018 in `regression-suite/19-reviewer-review-queue.yaml` for autosave / offline / reload-confirm / multi-tab / Submit countdown

### Implementation for User Story 2

- [ ] T065 [P] [US2] Implement `workbench-frontend/src/modules/reviewer-queue/services/offlineQueue.ts` IndexedDB wrapper using `idb`, per-Reviewer namespace
- [ ] T066 [US2] Implement `workbench-frontend/src/modules/reviewer-queue/hooks/useAutosave.ts` (FR-031: blur + beforeunload triggers, request through offlineQueue if backend unreachable)
- [ ] T067 [US2] Implement `workbench-frontend/src/modules/reviewer-queue/hooks/useOfflineMode.ts` (FR-031a/b: ping endpoint poll, mode flip, banner state, queue replay)
- [ ] T068 [P] [US2] Implement `workbench-frontend/src/modules/reviewer-queue/components/OfflineBanner.tsx` (FR-031b, aria-live polite)
- [ ] T069 [P] [US2] Implement `workbench-frontend/src/modules/reviewer-queue/components/ReloadConfirmModal.tsx` (FR-033, focus trap, keyboard reachable)
- [ ] T070 [US2] Update `SubmitButton.tsx` to render the `⟳ Submit (N)` countdown label during replay (FR-018a)
- [ ] T071 [US2] Implement `workbench-frontend/src/modules/reviewer-queue/hooks/useFocusFetch.ts` (FR-034a focus-fetch + per-field reconciliation against snapshot)
- [ ] T072 [P] [US2] Implement `chat-backend/src/modules/reviewer-queue/routes/state.ts` for `GET /api/reviewer/sessions/:id/state` (lightweight payload for focus-fetch reconciliation)
- [ ] T073 [P] [US2] Add admin setting `verbose_autosave_failures` to `chat-backend/src/modules/admin-settings/` and surface it in the admin Settings UI as the canonical Toggle (FR-031c, FR-031d) — depends on T007 / T008
- [ ] T074 [P] [US2] Add i18n strings to `reviewer-queue/i18n/{en,uk,ru}.json` for namespace `reviewer.errors` (offline banner, ping retry toast, multi-tab indicators)
- [ ] T075 [US2] Manual validation against quickstart §"Manual happy path — autosave + offline mode" and §"Manual happy path — multi-tab reconciliation" — record evidence in `evidence/058-T075/`

**Checkpoint**: Reviewer can leave / return / lose connection without losing work; multi-tab safe.

---

## Phase 5: User Story 3 — Reviewer adds clinical tags and raises a Red Flag (Priority: P1)

**Goal**: Per-message clinical tag attachments + per-(message, Reviewer) tag comment + Red Flag with mandatory description; Red Flag email triggers ONLY on submit (FR-028, EC-01).

**Independent Test**: Quickstart §"Manual happy path — single Reviewer" steps 8–9 (tag + Red Flag), confirm session with tag appears in Expert queue.

### Tests for User Story 3

- [ ] T076 [P] [US3] Backend integration test `chat-backend/tests/integration/reviewer-queue/tags.test.ts` — positive: attach Clinical Tag → Tag Center call succeeds + audit emission; negative: attach soft-deleted tag → 422
- [ ] T077 [P] [US3] Backend integration test `chat-backend/tests/integration/reviewer-queue/red-flag.test.ts` — positive: raise Red Flag + submit → email dispatched (EC-01); negative: raise Red Flag without submit → no email
- [ ] T078 [P] [US3] Frontend unit test `workbench-frontend/tests/unit/components/TagChip.test.tsx` — positive: tooltip shows description; negative: empty description → no tooltip
- [ ] T079 [P] [US3] Frontend unit test `workbench-frontend/tests/unit/components/RedFlagModal.test.tsx` — positive: confirm with description succeeds; negative: empty description blocks confirm
- [ ] T080 [P] [US3] E2E YAML test cases RQ-019..RQ-028 in `regression-suite/19-reviewer-review-queue.yaml` for tag attach / detach, per-message comment, Red Flag flow, Expert queue fan-out

### Implementation for User Story 3

- [ ] T081 [P] [US3] Implement `chat-backend/src/modules/reviewer-queue/repos/clinical-tags-repo.ts` with attach / detach + soft-delete-aware filter (FR-021b)
- [ ] T082 [P] [US3] Implement `chat-backend/src/modules/reviewer-queue/repos/review-tags-repo.ts` (visible across Reviewers per FR-024f)
- [ ] T083 [P] [US3] Implement `chat-backend/src/modules/reviewer-queue/repos/red-flags-repo.ts`
- [ ] T084 [P] [US3] Implement `chat-backend/src/modules/reviewer-queue/repos/message-tag-comments-repo.ts`
- [ ] T085 [US3] Implement Clinical Tag attach / detach routes (`POST` + `DELETE /api/reviewer/reviews/:id/tags`)
- [ ] T086 [US3] Implement Review Tag attach / detach routes (`POST` + `DELETE /api/reviewer/sessions/:id/review-tags`)
- [ ] T087 [US3] Implement Red Flag upsert / clear routes (`PUT` + `DELETE /api/reviewer/reviews/:id/red-flags/:msg`)
- [ ] T088 [US3] Implement Message Tag Comment upsert route (`PUT /api/reviewer/reviews/:id/tag-comments/:msg`)
- [ ] T089 [US3] Wire submit flow to dispatch Supervisor email when session contains a Red Flag (FR-028) — use existing email infra
- [ ] T090 [US3] Wire submit flow to enqueue session into Expert queue when at least one Clinical Tag matches an Expert assignment AND `language_group` covers the chat language (FR-024)
- [ ] T091 [P] [US3] Implement `workbench-frontend/src/modules/reviewer-queue/components/ClinicalTagSelector.tsx` (FR-020, FR-021a — chat-language-aware)
- [ ] T092 [P] [US3] Implement `workbench-frontend/src/modules/reviewer-queue/components/ReviewTagSelector.tsx` (FR-024a, FR-024c)
- [ ] T093 [P] [US3] Implement `workbench-frontend/src/modules/reviewer-queue/components/TagChip.tsx` reused in selector / transcript / session card; renders `(deleted)` prefix and retirement-date tooltip per FR-021b
- [ ] T094 [P] [US3] Implement `workbench-frontend/src/modules/reviewer-queue/components/RedFlagButton.tsx` and `RedFlagModal.tsx` (FR-025, FR-026, focus trap)
- [ ] T095 [P] [US3] Implement `workbench-frontend/src/modules/reviewer-queue/components/MessageTagComment.tsx` (FR-022, per (message, Reviewer))
- [ ] T096 [US3] Update `ReviewSessionPage.tsx` to compose tag selectors, chips, Red Flag controls, and per-message tag comment fields
- [ ] T097 [P] [US3] Manual validation against quickstart §"Manual happy path — single Reviewer" steps 8–9 + Expert-queue fan-out check — record evidence in `evidence/058-T097/`

**Checkpoint**: Tag + Red Flag flows complete; clinical-routing fan-out verified end-to-end.

---

## Phase 6: User Story 4 — Reviewer requests changes after finalising a review (Priority: P2)

**Goal**: Read-only completed reviews + change-request with mandatory reason + Supervisor decision flow + REPEAT label + canonical / superseded versioning.

**Independent Test**: Quickstart §"Manual happy path — change request flow" steps 1–7.

### Tests for User Story 4

- [ ] T098 [P] [US4] Backend integration test `chat-backend/tests/integration/reviewer-queue/change-request.test.ts` — positive: send → approve → review reopens with REPEAT; negative: approve after supervision returns 409 SESSION_NOT_EDITABLE_AFTER_SUPERVISION (EC-08)
- [ ] T099 [P] [US4] Backend integration test for repeat-rating canonicality — positive: repeat submit makes new Review canonical, prior superseded (EC-11); negative: analytics aggregate excludes superseded (SC-011)
- [ ] T100 [P] [US4] Frontend unit test `workbench-frontend/tests/unit/pages/ReviewSessionPage.read-only.test.tsx` — positive: completed review renders read-only; negative: edit attempts are blocked
- [ ] T101 [P] [US4] E2E YAML test cases RQ-029..RQ-035 in `regression-suite/19-reviewer-review-queue.yaml` for the full change-request flow including REPEAT label and superseded version visibility

### Implementation for User Story 4

- [ ] T102 [P] [US4] Implement `chat-backend/src/modules/reviewer-queue/repos/change-requests-repo.ts`
- [ ] T103 [US4] Implement `POST /api/reviewer/reviews/:id/change-requests` route + `decision` callback that re-opens the Review as REPEAT_DRAFT and marks the prior canonical Review superseded
- [ ] T104 [US4] Implement EC-08 guard in the Supervisor approve path returning 409 with structured error
- [ ] T105 [P] [US4] Update `workbench-frontend/src/modules/reviewer-queue/pages/ReviewSessionPage.tsx` to render the read-only state + `Request changes` form for completed reviews
- [ ] T106 [P] [US4] Add the `change_request.decision` notification handling to `useReviewerNotifications` (depends on US-7 hooks)
- [ ] T107 [P] [US4] Add i18n strings for the change-request form, status indicator, and notification banner texts
- [ ] T108 [US4] Manual validation against quickstart §"Manual happy path — change request flow" — record evidence in `evidence/058-T108/`

**Checkpoint**: Reviewer can correct mistakes via Supervisor-mediated change requests with full version history.

---

## Phase 7: User Story 5 — Reviewer reviews their own analytics in Reports (Priority: P2)

**Goal**: Reports page with Reviewer-scope only (no performer filter in DOM), period filter, the metrics catalogue listed in FR-044, no export controls.

**Independent Test**: Quickstart §"Reports validation" steps 1–4.

### Tests for User Story 5

- [ ] T109 [P] [US5] Backend integration test `chat-backend/tests/integration/reviewer-queue/reports.test.ts` — positive: returns only current Reviewer's data; negative: explicit performer query parameter is rejected with 400
- [ ] T110 [P] [US5] Frontend unit test `workbench-frontend/tests/unit/pages/ReviewerReportsPage.no-performer-filter.test.tsx` — positive: only period filter rendered; negative: assert no element matching `[data-testid="performer-filter"]` is in DOM
- [ ] T111 [P] [US5] E2E YAML test cases RQ-036..RQ-040 covering Reports content + the absence of the performer filter

### Implementation for User Story 5

- [ ] T112 [P] [US5] Implement `chat-backend/src/modules/reviewer-queue/services/reports-service.ts` returning `ReviewerReports` per contract; SERVER MUST reject any non-self performer parameter with 400 (FR-043)
- [ ] T113 [US5] Implement `GET /api/reviewer/reports` route in `chat-backend/src/modules/reviewer-queue/routes/reports.ts`
- [ ] T114 [P] [US5] Implement `workbench-frontend/src/modules/reviewer-queue/pages/ReviewerReportsPage.tsx` reusing existing chart components from `chat-frontend-common` (Score Distribution, Average Score Trend); NO performer filter, NO export control
- [ ] T115 [P] [US5] Add i18n strings for the Reports page namespace `reviewer.reports`
- [ ] T116 [US5] Manual validation against quickstart §"Reports validation" — record evidence in `evidence/058-T116/`

**Checkpoint**: Reviewer sees self-only analytics with no leak.

---

## Phase 8: User Story 6 — Cross-Reviewer data isolation (Priority: P1)

**Goal**: Hard guarantee that Reviewer A cannot see Reviewer B's data — UI absence + backend RBAC + URL-tampering response — plus a 2-account E2E.

**Independent Test**: Quickstart §"Manual cross-Reviewer isolation" steps 1–4 + SC-013a 2-Reviewer E2E.

### Tests for User Story 6

- [ ] T117 [P] [US6] Backend integration test `chat-backend/tests/integration/reviewer-queue/isolation.test.ts` — positive: Reviewer B receives empty / sanitised payload for sessions they don't own; negative: direct API call probing Reviewer A's URL returns 403/404
- [ ] T118 [P] [US6] Frontend unit test `workbench-frontend/tests/unit/services/reviewerApi.cross-account.test.ts` — positive: token swap masks data; negative: tampered URL emits an error state
- [ ] T119 [P] [US6] E2E YAML test cases RQ-041..RQ-045 with two Reviewer fixtures (`e2e-researcher@test.local` + a sibling Reviewer) covering UI + Reports + direct API

### Implementation for User Story 6

- [ ] T120 [US6] Audit and tighten every Reviewer-queue route to enforce Space scope + per-Reviewer ownership for tags / flags / ratings / notifications (depends on T020, T021)
- [ ] T121 [P] [US6] Add structured 403 responses with code `OUT_OF_SPACE_OR_NOT_OWNER`
- [ ] T122 [P] [US6] Update `EmptyState`, `ErrorState`, and the URL-tampering error page to render the localised "Access denied" message (FR-046d)
- [ ] T123 [US6] Manual validation against quickstart §"Manual cross-Reviewer isolation" with two accounts — record evidence in `evidence/058-T123/`

**Checkpoint**: 0 cross-Reviewer leak observations across UI + API + Reports.

---

## Phase 9: User Story 7 — Minimal interface with 2FA (Priority: P2)

**Goal**: Sidebar shows ONLY Review Queue + Reports for Reviewer role; account dropdown surfaces Settings + Sign Out; 2FA mandatory per environment; inactivity timeout default 30 min.

**Independent Test**: Quickstart §"Sign-in" + §"Sidebar check" + verify auto-logout after timeout with draft preserved.

### Tests for User Story 7

- [ ] T124 [P] [US7] Backend integration test for inactivity timeout — positive: idle longer than configured value redirects to login, draft preserved (EC-08); negative: active user keeps session alive
- [ ] T125 [P] [US7] Frontend unit test `workbench-frontend/tests/unit/components/Sidebar.reviewer-scope.test.tsx` — positive: only Review Queue + Reports rendered; negative: any other module entry would assert false
- [ ] T126 [P] [US7] E2E YAML test cases RQ-046..RQ-050 covering 2FA dev OTP path, sidebar scope, account dropdown, and timeout behaviour

### Implementation for User Story 7

- [ ] T127 [US7] Update `workbench-frontend/src/modules/shell/Sidebar.tsx` to hide everything except Review Queue + Reports when role is Reviewer / Researcher AND `feature.reviewer_review_queue_v2` is ON
- [ ] T128 [P] [US7] Verify the existing account dropdown shows Settings + Sign Out only (no Reviewer kabinet entries leaked into the sidebar) and add a unit test
- [ ] T129 [P] [US7] Verify the 2FA flow on dev (email OTP via console) and prod (TOTP) is enforced for Reviewer; add a backend integration test asserting the OTP step is mandatory regardless of role
- [ ] T130 [P] [US7] Add i18n strings for the sidebar reduced-scope state
- [ ] T131 [US7] Manual validation against quickstart §"Sign-in" + §"Sidebar check" — record evidence in `evidence/058-T131/`

**Checkpoint**: Reviewer UX is minimal and locked to authorised modules; 2FA enforced.

---

## Phase 10: User Story 8 — Audit logging of every Reviewer action (Priority: P3)

**Goal**: Every Reviewer state change emits an Audit Log entry with timestamp / user / role / IP / target / event type; append-only; 5-year tiered retention with cold archive.

**Independent Test**: Quickstart §"Audit Log validation" enumeration of expected event types.

### Tests for User Story 8

- [ ] T132 [P] [US8] Backend integration test `chat-backend/tests/integration/reviewer-queue/audit-emissions.test.ts` — positive: every action emits exactly the expected event type; negative: a bypassed code path (mock) does NOT silently fail to emit
- [ ] T133 [P] [US8] Backend integration test `chat-backend/tests/integration/audit-log/append-only.test.ts` — positive: SELECT works; negative: UPDATE / DELETE attempts are denied at the DB role level
- [ ] T134 [P] [US8] Backend integration test for retention job — positive: rows older than 60 months purged + summary entry emitted; negative: rows with `legal_hold = true` are NOT purged (SC-013q)
- [ ] T135 [P] [US8] E2E YAML test cases RQ-051..RQ-058 verifying each emission category surfaces in the live Audit Log within ≤ 60 seconds

### Implementation for User Story 8

- [ ] T136 [P] [US8] Add audit emissions to every state-changing route already implemented in earlier phases (rating CRUD, tag attach/detach, Red Flag CRUD, change-request send / approve / reject, notification.read, settings change, login success/fail, logout)
- [ ] T137 [P] [US8] Implement Cloud Run Job source `chat-backend/src/workers/audit-archive-job.ts` migrating month-36+ partitions to GCS Parquet (FR-050a)
- [ ] T138 [P] [US8] Implement Terraform module `chat-infra/terraform/modules/audit-log-archive/` deploying the Cloud Run Job + GCS bucket lifecycle policy (Constitution VIII)
- [ ] T139 [US8] Document the manual restore-from-cold procedure in `quickstart.md` §"Audit Log validation" follow-up section
- [ ] T140 [US8] Manual validation against quickstart §"Audit Log validation" — record evidence in `evidence/058-T140/`

**Checkpoint**: Every Reviewer action is auditable and retention is governed.

---

## Phase 11: Polish & Cross-Cutting Concerns

**Purpose**: Constitution-mandated quality gates: WCAG, performance budgets, responsive coverage, PWA verification, browser matrix, regression-suite acceptance, documentation, Jira sync.

- [ ] T141 [P] Add `@axe-core/playwright` to `chat-ui` and the regression-suite YAML harness; gate every Reviewer-route E2E with `axe-core` zero-critical / zero-serious assertions (FR-047b, SC-013g)
- [ ] T142 [P] Configure Lighthouse CI in `chat-ci` to run against `https://workbench.dev.mentalhelp.chat/workbench/review` for every PR deploy; fail on budget regression (SC-013o)
- [ ] T143 [P] Add `web-vitals` to `workbench-frontend`; sample at 10% in production via `POST /api/telemetry/web-vitals`
- [ ] T144 [P] Add E2E YAML cases RQ-059..RQ-065 covering responsive parity (1280 / 768 / 360 px), Submit countdown (SC-013d), notification categories (SC-013e), counter freshness (SC-013f), browser parity (SC-013n), state coverage (SC-013h), tag soft-delete (SC-013i), Required reviewer count change (SC-013j), multi-tab reconciliation (SC-013k), accessibility (SC-013g), PWA (SC-013m), performance budget (SC-013o), PII protection (SC-013p), retention (SC-013q)
- [ ] T145 Insert `19-reviewer-review-queue` into `regression-suite/_config.yaml` `execution_order` after `04-review-session`
- [ ] T146 [P] Verify the `workbench-pwa` shell scope covers the Reviewer routes; if not, file a one-line manifest fix (FR-046g, SC-013m)
- [ ] T147 [P] Add the `BrowserNotSupportedNotice.tsx` full-page guard for hard prerequisite misses (FR-046i)
- [ ] T148 Run `mhg.regression module:19-reviewer-review-queue level:smoke` 3 consecutive times on dev; require all green (SC-005)
- [ ] T149 Run `mhg.regression module:19-reviewer-review-queue level:standard` once green; record evidence
- [ ] T150 Run `mhg.regression module:19-reviewer-review-queue level:full` once green; record evidence
- [ ] T151 [P] Update Confluence User Manual page with screenshots captured via Playwright MCP against dev (Constitution XI)
- [ ] T152 [P] Update Confluence Technical Onboarding page with the new Reviewer module structure (Constitution XI)
- [ ] T153 [P] Run `/speckit.taskstoissues` to mirror this `tasks.md` into Jira Stories + Tasks under the feature Epic; record MTB key in `spec.md` header (Constitution X)
- [ ] T154 [P] Run `/speckit.analyze` for cross-artefact consistency before opening the PR
- [ ] T155 Open feature PRs in each affected split repo (chat-types, chat-backend, workbench-frontend, chat-frontend-common, chat-ui, chat-infra) targeting `develop`; gather owner approval before any merge (Constitution IV)
- [ ] T156 After owner-approved merges to `develop` in every repo, complete branch-cleanup (delete remote + local feature branches in each repo; sync local `develop` to `origin/develop`) per Constitution IV

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: no dependency — start immediately.
- **Foundational (Phase 2)**: depends on Setup; **BLOCKS every user-story phase**.
- **User Story phases (3–10)**: each depends on Foundational; can proceed in parallel after that.
- **Polish (Phase 11)**: depends on every user-story phase being complete on dev.

### User Story Order Recommendations

- US-1 first → MVP value (rate + submit one session).
- US-2 immediately after US-1 → autosave + offline + multi-tab harden the editor.
- US-3 after US-1 (US-2 helpful) → tag + Red Flag turn the editor clinical.
- US-6 after US-1..US-3 → cross-Reviewer isolation hardens RBAC across new features.
- US-7 in parallel with US-1 (sidebar + 2FA touch the shell, not the editor logic).
- US-4 once US-1..US-3 are stable → change-request flow needs the full editor underneath.
- US-5 after US-1..US-4 → Reports aggregates over real Reviewer activity.
- US-8 last among user stories → audit emissions can be folded in once the routes exist (T136 parallelises across earlier phases).

### Parallel Opportunities

- All `[P]` Setup tasks (T002, T003, T004, T005, T006, T007, T008) — 6 different files / repos.
- All `[P]` Foundational tasks (T009–T016 are independent type modules; T020, T021, T023, T024, T025, T026, T028, T029 are independent middleware / route stubs / tests).
- Within each user-story phase, tests `[P]`, repos `[P]`, components `[P]`, and i18n `[P]` are independent of each other; orchestration tasks (services, pages, manual validation) are sequential within the phase.
- Different user-story phases can be tackled by different developers in parallel after Phase 2 is complete.
- Polish phase tasks T141..T147 are independent and parallelisable.

---

## Implementation Strategy

### MVP First

1. Phase 1 (Setup) → Phase 2 (Foundational) → Phase 3 (US-1).
2. Stop and validate US-1 end-to-end on dev.
3. Demo / proceed.

### Incremental Delivery

1. After MVP: ship US-2 + US-7 together (both touch the shell + editor lifecycle).
2. Then US-3 (clinical tagging + Red Flag).
3. Then US-6 (isolation hardening).
4. Then US-4 + US-5 + US-8 + Polish for the release candidate.

### Parallel Team Strategy

With ≥ 3 developers:

- Dev A: US-1 → US-4 → US-5
- Dev B: US-2 → US-3 → US-8
- Dev C: US-6 + US-7 + Polish accessibility / performance / regression suite

---

## Notes

- 156 tasks total. 8 user-story phases + Setup + Foundational + Polish.
- Every phase ends in a Checkpoint that is a deployable, testable increment.
- Tests are MANDATORY per Constitution III — positive + negative for every user-facing scenario; not optional.
- Manual validation tasks (T059, T075, T097, T108, T116, T123, T131, T140) require evidence directories per Constitution III "Test evidence" line.
- Out-of-scope items from `spec.md` (`legal_hold` UI, PII reveal flows, admin tag CRUD UI beyond the language-group extension, etc.) are explicitly excluded — do not let them sneak into any phase.
- Each task is small enough that an LLM can complete it in one focused turn given the spec + plan + data-model + contracts as context.

---

**Phase 0 (research)**: COMPLETE.
**Phase 1 (design + contracts + quickstart)**: COMPLETE.
**Phase 2 (tasks)**: COMPLETE — this file.
**Next command**: `/speckit.analyze` for cross-artefact consistency, OR `/speckit.taskstoissues` to mirror into Jira, OR `/speckit.implement` to begin execution against the first phase.

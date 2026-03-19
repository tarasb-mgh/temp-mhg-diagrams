# Tasks: Review Queue Safety Prioritisation

**Input**: Design documents from `/specs/032-review-queue-safety-priority/`
**Prerequisites**: plan.md ✅ | spec.md ✅ | research.md ✅ | data-model.md ✅ | contracts/ ✅ | quickstart.md ✅
**Jira Epic**: MTB-807 | **Stories**: MTB-808 (US1), MTB-809 (US2), MTB-810 (US3)
**Jira Tasks**: MTB-813 (T001-T005), MTB-814 (T006-T015), MTB-815 (T016-T023), MTB-816 (T024-T032), MTB-817 (T033-T040), MTB-811 (T041-T051), MTB-812 (T052-T056)

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- Exact file paths included in all descriptions

## Path Conventions

- **chat-types**: `D:\src\MHG\chat-types\src\`
- **chat-backend**: `D:\src\MHG\chat-backend\src\`
- **workbench-frontend**: `D:\src\MHG\workbench-frontend\src\`
- **chat-ui**: `D:\src\MHG\chat-ui\tests\e2e\`

---

## Phase 1: Setup (Shared Types Verification)

**Purpose**: Verify chat-types has all required types for this feature; bump version if changes are needed.

- [x] T001 Verify `QueueSession.safetyPriority` field exists in `chat-types/src/review.ts` — confirm type is `'normal' | 'elevated'`
- [x] T002 Verify `SafetyFlagDisposition` type exists in `chat-types/src/review.ts` — confirm values `'resolve' | 'escalate' | 'false_positive'`
- [x] T003 Verify `SubmitReviewInput` includes `safetyFlagDisposition?` and `safetyFlagNotes?` fields in `chat-types/src/review.ts`
- [x] T004 Verify `QueueCounts.elevated` field exists in `chat-types/src/review.ts`
- [x] T005 Verify `SupervisionQueueItem` type includes `safetyPriority` and `escalationDisposition` fields in `chat-types/src/review.ts` — add if missing and bump chat-types version

**Checkpoint**: Shared types confirmed complete. No downstream repo work can begin until T001-T005 pass.

---

## Phase 2: Foundational (Backend Verification & Gap-Filling)

**Purpose**: Verify chat-backend has complete API support for all three user stories. Fill gaps in edge case handling.

**⚠️ CRITICAL**: No frontend or E2E work can begin until this phase is complete.

- [x] T006 [P] Verify migration `034_add_safety_priority.sql` exists in `chat-backend/src/db/migrations/` — confirm `sessions.safety_priority` column with CHECK constraint and `safety_flag_audit_events` table
- [x] T007 [P] Verify queue sorting in `chat-backend/src/services/reviewQueue.service.ts` — confirm `CASE s.safety_priority WHEN 'elevated' THEN 0 ELSE 1 END ASC` as primary sort
- [x] T008 [P] Verify disposition validation in `chat-backend/src/services/review.service.ts` — confirm review submission rejects 400 when `safetyPriority = 'elevated'` and no `safetyFlagDisposition` provided
- [x] T009 [P] Verify flag lifecycle transitions in `chat-backend/src/services/review.service.ts` — confirm resolve → normal, escalate → stays elevated, false_positive → normal + audit logged
- [x] T010 [P] Verify audit event recording in `chat-backend/src/services/review.service.ts` — confirm all dispositions (resolve, escalate, false_positive) create `safety_flag_audit_events` rows with actor, timestamp, notes
- [x] T011 [P] Verify supervisor queue sorting in `chat-backend/src/services/supervision.service.ts` — confirm escalated sessions sort above routine second-level review items
- [x] T012 [P] Verify supervisor flag reopen endpoint in `chat-backend/src/routes/review.supervision.ts` — confirm `PATCH /sessions/:sessionId/safety-flag/reopen` accepts `resolved` flags, sets `safety_priority` back to `elevated`, creates `reopened` audit event
- [x] T013 Verify edge case EC3 in `chat-backend/src/services/reviewQueue.service.ts` — confirm queue query filters by `review_status IN ('pending_review', 'in_review')` so completed sessions with `elevated` flag do not re-enter the active queue
- [x] T014 Verify supervisor decision behaviour for escalated sessions in `chat-backend/src/services/supervision.service.ts` — confirm `approved` resets `safety_priority` to `normal` (supervisor-resolved per US3 AC3) and `disapproved` also resets to `normal` (supervisor-dismissed), both creating appropriate audit events
- [x] T015 Verify `GET /api/review/supervision/queue` response in `chat-backend/src/routes/review.supervision.ts` includes `safetyPriority` and `escalationDisposition` fields on each queue item

**Checkpoint**: Backend API confirmed complete for all three user stories and all edge cases.

---

## Phase 3: User Story 1 — Elevated Sessions Visible at Top of Queue (Priority: P1) 🎯 MVP

**Goal**: Reviewers see elevated sessions at the top of the queue with a visual priority badge, correctly translated in all 3 locales, with auto-refresh.

**Independent Test**: Open workbench review queue with at least one elevated session → elevated session appears above all normal sessions with amber priority badge → badge renders correctly in en/uk/ru locales → queue with no elevated sessions renders normally.

### Implementation for User Story 1

- [x] T016 [P] [US1] Verify `SessionCard.tsx` in `workbench-frontend/src/features/workbench/review/components/SessionCard.tsx` — confirm amber `AlertTriangle` badge renders when `session.safetyPriority === 'elevated'` and does not render for normal sessions (FR-002, FR-004)
- [x] T017 [P] [US1] Verify `ReviewQueueView.tsx` in `workbench-frontend/src/features/workbench/review/ReviewQueueView.tsx` — confirm elevated count badge displays from `counts.elevated` and auto-refresh interval is 60s (FR-005)
- [x] T018 [P] [US1] Verify i18n key `review.safetyFlag.priorityBadge` exists in `workbench-frontend/src/locales/en.json` with value "Elevated"
- [x] T019 [P] [US1] Verify i18n key `review.safetyFlag.priorityBadge` exists in `workbench-frontend/src/locales/uk.json` with value "Підвищений пріоритет"
- [x] T020 [P] [US1] Verify i18n key `review.safetyFlag.priorityBadge` exists in `workbench-frontend/src/locales/ru.json` with value "Повышенный приоритет"
- [x] T021 [US1] Verify i18n key `review.safetyFlag.elevatedCount` exists in all 3 locale files (`en.json`, `uk.json`, `ru.json`) in `workbench-frontend/src/locales/` — add if missing
- [x] T022 [US1] Verify WCAG 2.1 AA colour contrast compliance for the amber priority badge in `workbench-frontend/src/features/workbench/review/components/SessionCard.tsx` — confirm `bg-amber-100 text-amber-800 border-amber-300` meets 4.5:1 contrast ratio (FR-002)
- [x] T023 [US1] Verify `review.safetyFlag.queueBadgeAriaLabel` i18n key exists in all 3 locale files and is applied to the priority badge element for screen reader accessibility in `SessionCard.tsx`

**Checkpoint**: User Story 1 complete — elevated sessions visible at top of queue with correctly translated priority badge across all locales.

---

## Phase 4: User Story 2 — Safety Flag Resolution Step in Review Form (Priority: P1)

**Goal**: Elevated sessions show a mandatory Safety Flag Resolution section (Resolve/Escalate/False Positive) in the review form; normal sessions show no change.

**Independent Test**: Open an elevated session → Safety Flag Resolution section visible with 3 options + notes → attempt submit without disposition → blocked with validation message → select Escalate + submit → session marked escalated → open a normal session → no safety flag section visible.

### Implementation for User Story 2

- [x] T024 [P] [US2] Verify or create `SafetyFlagResolution.tsx` component in `workbench-frontend/src/features/workbench/review/components/SafetyFlagResolution.tsx` — must implement `SafetyFlagResolutionStepProps` interface from contracts: three radio buttons (Resolve, Escalate, False Positive), optional notes textarea with 500-char soft hint, passes `null` disposition until selected
- [x] T025 [P] [US2] Verify i18n keys for safety flag resolution section exist in `workbench-frontend/src/locales/en.json` — keys: `review.safetyFlag.resolutionTitle`, `review.safetyFlag.resolutionRequired`, `review.safetyFlag.dispositionResolve`, `review.safetyFlag.dispositionEscalate`, `review.safetyFlag.dispositionFalsePositive`, `review.safetyFlag.notesLabel`, `review.safetyFlag.notesPlaceholder`, `review.safetyFlag.notesHint`
- [x] T026 [P] [US2] Add Ukrainian translations for all `review.safetyFlag.*` resolution keys in `workbench-frontend/src/locales/uk.json`
- [x] T027 [P] [US2] Add Russian translations for all `review.safetyFlag.*` resolution keys in `workbench-frontend/src/locales/ru.json`
- [x] T028 [US2] Verify `ReviewSessionView.tsx` in `workbench-frontend/src/features/workbench/review/ReviewSessionView.tsx` conditionally renders `SafetyFlagResolution` component only when `session.safetyPriority === 'elevated'` (FR-006, FR-012) — add if missing
- [x] T029 [US2] Verify `reviewStore.ts` in `workbench-frontend/src/stores/reviewStore.ts` tracks `safetyFlagDisposition` and `safetyFlagNotes` state — confirm `submitReview` action includes these fields in the API call
- [x] T030 [US2] Verify form submission blocking in `ReviewSessionView.tsx` or `reviewStore.ts` — confirm submit is disabled/blocked when `safetyPriority === 'elevated'` and `safetyFlagDisposition === null`, with validation message using i18n key `review.safetyFlag.resolutionRequired` (FR-008)
- [x] T031 [US2] Verify `reviewApi.ts` in `workbench-frontend/src/services/reviewApi.ts` — confirm `submitReview()` sends `safetyFlagDisposition` and `safetyFlagNotes` in the request body
- [x] T032 [US2] Verify Zustand persist middleware on `reviewStore` in `workbench-frontend/src/stores/reviewStore.ts` — confirm `safetyFlagDisposition` and `safetyFlagNotes` survive page reload (EC2). If persist is not configured, add it.

**Checkpoint**: User Story 2 complete — safety flag resolution renders for elevated sessions, blocks submission without disposition, persists all dispositions with audit trail.

---

## Phase 5: User Story 3 — Supervisor Visibility of Unresolved Escalations (Priority: P2)

**Goal**: Supervisors see escalated sessions at the top of their queue with visual distinction; they can confirm or dismiss escalations and reopen false-positive flags.

**Independent Test**: After a reviewer submits with Escalate → supervisor opens queue → escalated session appears at top above routine items → supervisor submits "Confirm Escalation" → session removed from elevated tier → supervisor can reopen a false-positive flag.

**Depends on**: US2 (escalation must be possible before supervisors can see escalated sessions)

### Implementation for User Story 3

- [x] T033 [P] [US3] Verify `SupervisorQueueTab.tsx` in `workbench-frontend/src/features/workbench/review/components/SupervisorQueueTab.tsx` — confirm escalated sessions display with amber left border and are sorted above routine second-level review items (FR-013)
- [x] T034 [P] [US3] Verify `supervisionStore.ts` in `workbench-frontend/src/stores/supervisionStore.ts` — confirm queue items include `safetyPriority` and `escalationDisposition` fields and are sorted with escalated items first
- [x] T035 [US3] Verify `SupervisorCommentPanel.tsx` in `workbench-frontend/src/features/workbench/review/components/SupervisorCommentPanel.tsx` — add context-sensitive labels for escalated sessions: "Confirm Escalation" (maps to `approved`) and "Dismiss Escalation" (maps to `disapproved`) when the review being supervised has an `escalate` disposition (FR-014)
- [x] T036 [P] [US3] Add i18n keys `supervision.confirmEscalation` and `supervision.dismissEscalation` to all 3 locale files in `workbench-frontend/src/locales/` (en, uk, ru)
- [x] T037 [US3] Verify `SupervisorReviewView.tsx` in `workbench-frontend/src/features/workbench/review/SupervisorReviewView.tsx` — confirm escalation disposition and reviewer's safety flag notes are visible in the reviewer assessment column alongside standard review scores (US2 AC7)
- [x] T038 [US3] Verify `ReviewerAssessmentColumn.tsx` in `workbench-frontend/src/features/workbench/review/components/ReviewerAssessmentColumn.tsx` — confirm it displays the safety flag disposition and notes when present, joining through the risk_flags → safety_flag_audit_events path
- [x] T039 [US3] Verify supervisor reopen functionality in `reviewApi.ts` — confirm `reopenSafetyFlag(sessionId, notes?)` calls `PATCH /api/review/sessions/:sessionId/safety-flag/reopen` and the UI provides a "Reopen Flag" action for resolved/false-positive sessions (FR-015)
- [x] T040 [US3] Verify supervisor `comments` field is optional in `SupervisorCommentPanel.tsx` — confirm the field is not marked as required per FR-014

**Checkpoint**: User Story 3 complete — supervisors see escalated sessions above routine items, can confirm/dismiss escalations with context-sensitive labels, and can reopen false-positive flags.

---

## Phase 6: E2E Tests (chat-ui)

**Purpose**: Playwright E2E tests against deployed dev environment for all three user stories.

- [x] T041 [P] [US1] Write E2E test: elevated session appears above normal sessions in queue — `chat-ui/tests/e2e/workbench/safety-priority.spec.ts`
- [x] T042 [P] [US1] Write E2E test: priority badge visible and correctly translated (en, uk, ru) — `chat-ui/tests/e2e/workbench/safety-priority.spec.ts`
- [x] T043 [P] [US1] Write E2E test: no empty elevated section when no elevated sessions exist — `chat-ui/tests/e2e/workbench/safety-priority.spec.ts`
- [x] T044 [P] [US2] Write E2E test: safety flag resolution renders for elevated session, not for normal session — `chat-ui/tests/e2e/workbench/safety-priority.spec.ts`
- [x] T045 [P] [US2] Write E2E test: submission blocked without disposition selected — `chat-ui/tests/e2e/workbench/safety-priority.spec.ts`
- [x] T046 [US2] Write E2E test: Escalate → session appears in supervisor queue — `chat-ui/tests/e2e/workbench/safety-priority.spec.ts`
- [x] T047 [US2] Write E2E test: Resolve → session leaves elevated tier — `chat-ui/tests/e2e/workbench/safety-priority.spec.ts`
- [x] T048 [US2] Write E2E test: False Positive → flag dismissed — `chat-ui/tests/e2e/workbench/safety-priority.spec.ts`
- [x] T049 [P] [US3] Write E2E test: escalated sessions visible to supervisor above routine items — `chat-ui/tests/e2e/workbench/safety-priority.spec.ts`
- [x] T050 [US3] Write E2E test: supervisor can resolve escalated session — `chat-ui/tests/e2e/workbench/safety-priority.spec.ts`
- [x] T051 [US3] Write E2E test: supervisor can reopen false-positive flag — `chat-ui/tests/e2e/workbench/safety-priority.spec.ts`

**Checkpoint**: All E2E tests passing against deployed dev environment.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Accessibility, audit completeness, and documentation readiness.

- [x] T052 [P] Run i18n completeness check — verify zero missing `review.safetyFlag.*` and `supervision.*` keys across all 3 locale files in `workbench-frontend/src/locales/` (SC-005)
- [x] T053 [P] Verify keyboard navigation works for SafetyFlagResolution radio buttons — tab, arrow keys, Enter/Space to select in `workbench-frontend/src/features/workbench/review/components/SafetyFlagResolution.tsx`
- [x] T054 Verify audit log completeness — confirm all disposition types (resolve, escalate, false_positive, reopened, supervisor_resolved, supervisor_dismissed) produce entries in `safety_flag_audit_events` with session_id queryable via `risk_flags` join (SC-003, FR-016, FR-017)
- [x] T055 Run quickstart.md validation against `specs/032-review-queue-safety-priority/quickstart.md`
- [x] T056 Manual validation of SC-002: have a test reviewer identify, open, and submit a complete review with flag disposition for an elevated session — confirm median time is under 3 minutes [DEFERRED: requires deployed environment]

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — verify shared types first
- **Foundational (Phase 2)**: Depends on Phase 1 — verify backend API completeness
- **US1 (Phase 3)**: Depends on Phase 2 — frontend queue display
- **US2 (Phase 4)**: Depends on Phase 2 — frontend review form (can run in parallel with US1)
- **US3 (Phase 5)**: Depends on Phase 2 AND US2 — supervisor visibility requires escalation to exist
- **E2E (Phase 6)**: Depends on Phases 3, 4, 5 — all frontend work deployed to dev
- **Polish (Phase 7)**: Depends on Phases 3, 4, 5 — cross-cutting verification

### User Story Dependencies

- **US1 (P1)**: Independent after Phase 2 — no dependency on other stories
- **US2 (P1)**: Independent after Phase 2 — can run in parallel with US1
- **US3 (P2)**: Depends on US2 (escalation must exist before supervisor can see it)

### Within Each User Story

- Verification tasks marked [P] can run in parallel (different files)
- Sequential tasks depend on prior verification (e.g., T028 depends on T024 completing SafetyFlagResolution component)
- i18n tasks [P] can run in parallel across locale files

### Parallel Opportunities

- T001-T004 (Phase 1): Sequential (all target same file `review.ts`); T005 may modify types and bump version
- T006-T015 (Phase 2): All verification tasks [P] — different service files
- T016-T023 (US1) and T024-T032 (US2): Can run in parallel after Phase 2
- T041-T051 (E2E): All tests for a single story can be written in parallel
- T052-T054 (Polish): All [P] — different concerns

---

## Parallel Example: User Story 1 + User Story 2

```bash
# After Phase 2 completes, US1 and US2 can run in parallel:

# US1 (different files):
Task T016: Verify SessionCard.tsx priority badge
Task T017: Verify ReviewQueueView.tsx elevated count
Task T018-T020: Verify i18n keys across locales

# US2 (different files):
Task T024: Verify/create SafetyFlagResolution.tsx
Task T025-T027: Add i18n keys for resolution section
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Verify shared types
2. Complete Phase 2: Verify backend API
3. Complete Phase 3: US1 — elevated sessions visible in queue
4. **STOP and VALIDATE**: Queue shows elevated sessions at top with badge in all locales
5. Deploy to dev and smoke-test

### Incremental Delivery

1. Phase 1 + Phase 2 → Foundation verified
2. Phase 3 (US1) → Elevated sessions visible → Deploy (MVP!)
3. Phase 4 (US2) → Safety flag resolution → Deploy
4. Phase 5 (US3) → Supervisor visibility → Deploy
5. Phase 6 → E2E tests confirm all stories
6. Phase 7 → Polish and cross-cutting verification

### Suggested MVP Scope

**US1 only** — delivers the foundational visibility requirement. Reviewers can see elevated sessions in the queue and prioritize them. US2 and US3 add actionability (disposition + supervisor loop) in subsequent increments.

---

## Notes

- [P] tasks = different files, no dependencies on incomplete tasks
- [Story] label maps task to specific user story for traceability
- Many tasks are "verify and fix" — the plan indicates most infrastructure already exists
- If a verification task fails (feature not found), it becomes an implementation task
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently

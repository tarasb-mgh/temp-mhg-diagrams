# Tasks: Non-Therapy Technical Backlog

**Input**: Design documents from `/specs/030-non-therapy-backlog/`
**Prerequisites**: plan.md ✅ spec.md ✅ research.md ✅ data-model.md ✅ contracts/ ✅ quickstart.md ✅

**Repositories affected**: `chat-types`, `chat-backend`, `workbench-frontend`, `chat-infra`, `chat-ui`

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: User story label (US1–US7)
- All paths are relative to the target repository root

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Branch setup and shared type definitions in chat-types — must precede all backend/frontend work

- [X] T001 Create feature branch `030-non-therapy-backlog` in chat-types, chat-backend, workbench-frontend, chat-infra, chat-ui (all from develop) — GH-37
- [X] T002 [P] Add identity types to chat-types: `src/identity.types.ts` — ConsentRecord, IdentityMapping, ErasureJob — GH-38
- [X] T003 [P] Add cohort types to chat-types: `src/cohort.types.ts` — Cohort, CohortMembership, InviteCode — GH-39
- [X] T004 [P] Add assessment types to chat-types: `src/assessment.types.ts` — AssessmentSession, AssessmentItem, AssessmentScore, ScoreTrajectory, AssessmentSchedule, RiskThreshold — GH-40
- [X] T005 [P] Add analytics types to chat-types: `src/analytics.types.ts` — AnalyticsEventType (8 variants), AnalyticsEvent, GDPRAuditEntry — GH-41
- [X] T006 [P] Add annotation types to chat-types: `src/annotation.types.ts` — Annotation, SamplingRun, KappaResult, CategoryMetrics, ModelMetrics — GH-42
- [X] T007 [P] Add AI filter types to chat-types: `src/ai-filter.types.ts` — FilterEvent, FilterResult, ScoreContextCache — GH-43
- [X] T008 Export all new types from chat-types `src/index.ts` barrel; bump package version; publish to GitHub Packages — GH-44
- [X] T009 Update chat-backend package.json to consume new chat-types version; run `npm install`; confirm TypeScript compilation passes — GH-45

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Infrastructure provisioning and base middleware that MUST complete before any user story work begins

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T010 Write and run chat-infra script `scripts/030-create-identity-map-instance.sh` — creates `chat-identity-map-dev` Cloud SQL PostgreSQL 15 instance (private IP, no public IP, europe-central2) — GH-46
- [X] T011 Write and run chat-infra script `scripts/030-iam-identity-map-bindings.sh` — creates `auth-identity-map-sa` service account; binds `roles/cloudsql.client` to SA; adds IAM deny policy for all other SAs — GH-47
- [X] T012 Write and run chat-infra script `scripts/030-cloud-tasks-assessment-queue.sh` — creates `assessment-scheduler` Cloud Tasks queue in `mental-help-global-25`, region `europe-central2` — GH-48
- [X] T013 Write and run chat-infra script `scripts/030-audit-log-retention.sh` — configures Cloud Logging sink to Cloud Storage with 3-year lifecycle retention policy on `gdpr_audit_log` exports — GH-49
- [X] T014 Write data migration script `chat-backend/migrations/data/030-001-assign-pseudonymous-ids.ts` — assigns UUID v4 + per-user salt to any existing users before schema migration runs — GH-50
- [X] T015 Write and apply migration `chat-backend/migrations/030-001-pseudonymous-users.sql` — redesign `users` table: add `pseudonymous_user_id` UUID PK, `salt` BYTEA, `created_at`, `deleted_at`; remove all PII columns — GH-51
- [X] T016 Implement `chat-backend/src/auth/pii-rejection.middleware.ts` — Express middleware applied to all routes; compiles regex patterns for email, UA phone format, name-length strings at startup; returns 400 + logs to `gdpr_audit_log` on match — GH-52
- [X] T017 Add `pii-rejection.middleware.ts` to Express app entry point `chat-backend/src/app.ts` before all route handlers; write integration test `chat-backend/tests/integration/pii-rejection.test.ts` confirming 400 on PII input and pass-through on clean input — GH-53

**Checkpoint**: Infrastructure provisioned, users table migrated, PII middleware active — user story phases can now begin

---

## Phase 3: User Story 1 — Privacy & Identity Infrastructure (Priority: P1) 🎯 Sprint 1 MVP

**Goal**: DPO can verify no PII in any health data table, trigger erasure, confirm cascade completion, and verify cross-service access control on the identity map.

**Independent Test**: Run `tests/integration/erasure-cascade.test.ts` — confirms identity_map deletion → FK nullification → audit log entry. Attempt cross-service identity map query → confirm 403.

- [X] T018 [US1] Write and apply migration `chat-backend/migrations/030-002-user-identity-map-remote.sql` — document that `user_identity_map` table resides on `chat-identity-map-dev` instance; create connection config in `chat-backend/src/db/identity-map.db.ts` using `auth-identity-map-sa` credentials — GH-54
- [X] T019 [US1] Implement `chat-backend/src/auth/identity-map.service.ts` — createIdentityMapping(), lookupPseudonymousId(), retireDeviceEntry() (for guest→OTP), deleteForErasure(); enforces auth-service-only access by catching connection errors from non-auth services — GH-55
- [X] T020 [US1] Implement `POST /auth/identity` endpoint in `chat-backend/src/auth/identity.controller.ts` — generates UUID v4 + per-user salt; writes to `users` (main DB) and `user_identity_map` (identity map DB); no PII in request or response — GH-56
- [X] T021 [US1] Implement `chat-backend/src/erasure/erasure-cascade.service.ts` — async job: (1) delete identity_map record, (2) nullify FK references in `sessions`, `assessment_scores`, `risk_flags`, `user_intake` via UPDATE SET pseudonymous_user_id = NULL WHERE ..., (3) set `users.deleted_at`, (4) write completion event to `gdpr_audit_log` — GH-57
- [X] T022 [US1] Implement `POST /gdpr/erasure` and `GET /gdpr/erasure/:jobId` endpoints in `chat-backend/src/erasure/erasure.controller.ts`; queue job via Cloud Tasks; return 202 with job_id — GH-58
- [X] T023 [US1] Implement `chat-backend/src/analytics/gdpr-audit.service.ts` — writeAuditEvent() writes to `gdpr_audit_log` table with event_type, actor, pseudonymous_user_id_hash (SHA-256), details JSONB, outcome — GH-59
- [X] T024 [US1] Write integration test `chat-backend/tests/integration/erasure-cascade.test.ts` — seed user with sessions + assessments + flags → submit erasure → verify identity_map deleted, all FK references nullified, audit log entry created, job status = completed — GH-60
- [X] T025 [US1] Verify cross-service access control: write test `chat-backend/tests/integration/identity-map-access-control.test.ts` — attempt identity_map query from session service SA → assert permission denied error → assert attempt logged to gdpr_audit_log — GH-61
- [X] T026 [US1] Run chat-infra script `scripts/030-audit-log-retention.sh` for prod; verify Cloud Logging sink and 3-year retention lifecycle policy via `gcloud logging sinks describe` — GH-62
- [X] T027 [US1] Verify Cloud SQL at-rest encryption: add verification step to `chat-infra/scripts/030-encryption-audit.sh` that queries `gcloud sql instances describe` for `diskEncryptionConfiguration`; output result to `evidence/T027/encryption-audit.txt` — GH-63

**Checkpoint**: US1 fully functional — DPO can trigger erasure, verify no PII in operational tables, confirm cross-service isolation

---

## Phase 4: User Story 2 — Consent & Cohort Onboarding (Priority: P1) 🎯 Sprint 1

**Goal**: Cohort admin generates QR invite codes; officers join anonymously; analytics locked below 25 users; guest→OTP upgrade preserves pseudonymous ID.

**Independent Test**: Create cohort code → join as guest with 24 test accounts → confirm analytics returns "cohort too small" → join account 25 → confirm analytics unlocks → upgrade guest to OTP → confirm same pseudonymous_user_id.

- [ ] T028 [US2] Write and apply migration `chat-backend/migrations/030-003-consent-records.sql` — create `consent_records` table per data-model.md; UNIQUE constraint on (pseudonymous_user_id, consent_version) — GH-64
- [ ] T029 [US2] Write and apply migration `chat-backend/migrations/030-004-cohorts.sql` — create `cohorts` table with CHECK constraint on `invite_code` format `'^[A-HJ-NP-Z2-9]{8}$'`; create `cohort_memberships` table; create `supervisor_cohort_assignments` table — GH-65
- [ ] T030 [US2] Implement `chat-backend/src/consent/consent.service.ts` — recordConsent(), getCurrentConsentStatus(), checkCategoryConsent(userId, category); throws ConsentRequiredError if category not accepted — GH-66
- [ ] T031 [US2] Implement consent enforcement middleware `chat-backend/src/consent/consent.middleware.ts` — reads required category from route metadata; calls checkCategoryConsent(); returns 403 on violation; applies category 1 to session routes, category 2 to intake routes, category 3 to assessment routes — GH-67
- [ ] T032 [US2] Implement `POST /consent` and `GET /consent/current` endpoints in `chat-backend/src/consent/consent.controller.ts` — GH-68
- [ ] T033 [US2] Write integration test `chat-backend/tests/integration/consent-enforcement.test.ts` — verify 403 returned for session, intake, and assessment routes without valid consent; verify pass-through with valid consent; verify no DB write occurs before consent for all three categories — GH-69
- [ ] T034 [US2] Implement `chat-backend/src/cohort/invite-code.service.ts` — generateCode() produces 8-char uppercase code excluding O/0/I/1; generateQR() returns base64 PNG at scale:50 (≥300 DPI) using `qrcode` npm package; validateCode() checks expiry and is_active — GH-70
- [ ] T035 [US2] Implement `chat-backend/src/cohort/cohort.service.ts` — createCohort(), joinCohort(), deactivateCode(), getCohortMemberCount(); joinCohort() returns 410 if expired, 403 if deactivated — GH-71
- [ ] T036 [US2] Implement `POST /cohorts`, `POST /cohorts/join`, `PATCH /cohorts/:id/deactivate` in `chat-backend/src/cohort/cohort.controller.ts` — GH-72
- [ ] T037 [US2] Implement cohort analytics guard `chat-backend/src/cohort/cohort-analytics.middleware.ts` — runs before all workbench analytics routes; queries `SELECT COUNT(*) FROM cohort_memberships WHERE cohort_id = $1`; returns 200 with `{suppressed: true, reason: "cohort_too_small"}` if count < 25 — GH-73
- [ ] T038 [US2] Implement `POST /auth/identity/upgrade` in `chat-backend/src/auth/identity.controller.ts` — calls IdentityMapService.retireDeviceEntry(); merges device UUID session into OTP session preserving pseudonymous_user_id; sets upgraded_at on old identity_map entry — GH-74
- [ ] T039 [US2] Add `qrcode` npm dependency to `chat-backend/package.json`; run `npm install` — GH-75
- [ ] T040 [US2] Implement workbench cohort management UI `workbench-frontend/src/features/cohort-management/InviteCodeManager.tsx` — form to create cohort code; displays generated code + QR image; shows member_count and is_active status; deactivate button — GH-76
- [ ] T041 [US2] Implement `workbench-frontend/src/features/cohort-management/CohortAnalyticsGuard.tsx` — wrapper component that displays "Cohort too small — analytics available when ≥ 25 users have joined" message when API returns suppressed:true; wraps all cohort analytics views — GH-77
- [ ] T042 [US2] Add uk/en/ru translation keys for all cohort onboarding UI text to `workbench-frontend/src/i18n/` locale files — GH-78

**Checkpoint**: US2 fully functional — invite code generation, cohort join, analytics guard, and guest→OTP upgrade all working

---

## Phase 5: User Story 3 — Clinical Assessment Data Schema (Priority: P1) 🎯 Sprint 2

**Goal**: Backend engineer stores completed PHQ-9 with items + score, queries longitudinal trajectories, verifies append-only integrity — independent of Dialogflow CX.

**Independent Test**: Seed 3 PHQ-9 assessments (scores 18, 12, 7) → query trajectory view → confirm RCI values + CMI flag on 18→7 delta → attempt UPDATE on assessment_scores → confirm trigger blocks it.

- [ ] T043 [US3] Write and apply migration `chat-backend/migrations/030-005-assessment-schema.sql` — create `assessment_sessions`, `assessment_items`, `assessment_scores` tables; create `enforce_append_only()` PL/pgSQL function; create triggers on all three tables (BEFORE UPDATE OR DELETE) — GH-79
- [ ] T044 [US3] Write integration test `chat-backend/tests/integration/assessment-append-only.test.ts` — insert test assessment → attempt UPDATE on assessment_scores → assert exception raised; attempt DELETE → assert exception raised; verify GDPR erasure cascade can still nullify via erasure service role — GH-80
- [ ] T045 [US3] Write and apply migration `chat-backend/migrations/030-006-score-trajectories.sql` — create `score_trajectories` materialised view with rolling_30d_mean, RCI (Jacobson-Truax formula), CMI flags per instrument type; add unique index on (pseudonymous_user_id, instrument_type, administered_at); schedule pg_cron job for 15-min CONCURRENTLY refresh — GH-81
- [ ] T046 [US3] Implement `chat-backend/src/assessment/assessment-sessions.service.ts` — createSession(), recordItem(), completeSession() (computes score + scoring_key_hash + severity_band, triggers trajectory refresh), abandonSession(); all writes check Category 3 consent via ConsentService — GH-82
- [ ] T047 [US3] Implement `POST /assessments/sessions`, `POST /assessments/sessions/:id/items`, `POST /assessments/sessions/:id/complete`, `POST /assessments/sessions/:id/abandon` in `chat-backend/src/assessment/assessment.controller.ts` — GH-83
- [ ] T048 [US3] Implement `chat-backend/src/assessment/score-trajectories.service.ts` — getTrajectories(userId, instrumentType): queries score_trajectories view; triggers on-demand REFRESH if last_refresh > 15 min; enforces supervisor cohort scoping (calls SupervisorCohortService) — GH-84
- [ ] T049 [US3] Implement `GET /assessments/trajectories/:userId` endpoint in `chat-backend/src/assessment/assessment.controller.ts`; add p95 response-time assertion to integration test (< 200ms) — GH-85
- [ ] T050 [US3] Write and apply migration `chat-backend/migrations/030-007-assessment-schedule.sql` — create `assessment_schedule` table per data-model.md — GH-86
- [ ] T051 [US3] Implement `chat-backend/src/assessment/assessment-scheduler.service.ts` — getNextInterval(severityBand): returns 14d/28d/35d; scheduleNextAssessment(userId, instrumentType, severityBand): creates Cloud Tasks task with scheduleTime; cancelTask(cloudTaskName); pauseSchedule(userId) — GH-87
- [ ] T052 [US3] Wire assessment scheduler to completeSession() in assessment-sessions.service.ts — on completion: call scheduleNextAssessment() with new severity band; cancel prior pending task if cloud_task_name set — GH-88
- [ ] T053 [US3] Implement `GET/PATCH /assessments/schedule/:userId` endpoints in `chat-backend/src/assessment/assessment.controller.ts` — GH-89
- [ ] T054 [US3] Write and apply migration `chat-backend/migrations/030-008-risk-thresholds.sql` — create `risk_thresholds` table with effective_from column; append-only (no trigger needed — clinical lead adds new rows, old rows retained) — GH-90
- [ ] T055 [US3] Implement `chat-backend/src/assessment/risk-threshold.service.ts` — getActiveThresholds(instrumentType, assessedAt): queries WHERE effective_from <= assessedAt; evaluateThresholds(score, items, assessedAt): returns tier or null; createThreshold() logs to gdpr_audit_log — GH-91
- [ ] T056 [US3] Implement `GET /assessments/thresholds`, `POST /assessments/thresholds` in `chat-backend/src/assessment/assessment.controller.ts`; guard POST with clinical_lead role claim — GH-92
- [ ] T057 [US3] Update flag creation logic in existing `chat-backend/src/flags/flag.service.ts` — add deduplication: UPDATE existing open Urgent flag vs. always-INSERT Critical; add `resolved_by` and `resolved_at` columns via migration `030-009-risk-flags-update.sql` — GH-93
- [ ] T058 [US3] Implement workbench score trajectory view `workbench-frontend/src/features/assessment-trajectories/ScoreTrajectoryView.tsx` — line chart per instrument; shows score history, rolling mean, CMI flag markers; uses `/assessments/trajectories/:userId` endpoint; respects supervisor cohort scoping — GH-94
- [ ] T059 [US3] Add uk/en/ru translation keys for assessment trajectory UI to `workbench-frontend/src/i18n/` locale files — GH-95

**Checkpoint**: US3 fully functional — assessment storage, trajectories, scheduler, and risk threshold config all working

---

## Phase 6: User Story 4 — AI Safety & Response Filtering (Priority: P2) 🎯 Sprint 3

**Goal**: AI responses containing clinical language or numeric score leakage are blocked server-side; only severity band + direction injected into system prompt.

**Independent Test**: Send message with "PHQ-9: 18" pattern through AI pipeline → confirm filtered response + fallback returned + filter_event logged. Confirm system prompt contains "Moderate, improving" not a numeric score.

- [ ] T060 [US4] Implement `chat-backend/src/ai-filter/post-generation-filter.ts` — compile PROHIBITED_PATTERNS array at module load (see research.md R-07); compile PROHIBITED_KEYWORDS Set; export postGenerationFilter(response): FilterResult; returns {blocked, reason, original} — NO async calls (synchronous) — GH-96
- [ ] T061 [US4] Write unit test `chat-backend/tests/unit/ai-filter.test.ts` — ≥50 test cases per prohibited category (numeric scores near instrument names, diagnostic terms, urgency language); assert blocked=true on all prohibited; assert blocked=false on ≥20 clean message samples — GH-97
- [ ] T062 [US4] Integrate `postGenerationFilter` into AI message delivery pipeline in `chat-backend/src/chat/message.service.ts` — run filter before write to DB and before send to client; on block: write filter_event to `gdpr_audit_log` with original content; replace response with fallback message key from config table — GH-98
- [ ] T063 [US4] Implement `chat-backend/src/ai-filter/score-context-injector.ts` — injectScoreContext(userId, systemPrompt): fetches severity band + trajectory direction from score_trajectories view (NOT numeric scores); 200ms timeout via Promise.race(); on timeout: return systemPrompt unchanged (fail open); format: "{band}, {direction}" e.g. "Moderate, improving" — GH-99
- [ ] T064 [US4] Implement `chat-backend/src/ai-filter/score-context-cache.ts` — Redis-backed per-session cache: getContext(userId, sessionId), setContext(userId, sessionId, context), invalidate(userId): clears all sessions for user (called on assessment completion in assessmentSessionsService.completeSession()) — GH-100
- [ ] T065 [US4] Wire score-context-injector into system prompt construction in `chat-backend/src/chat/session.service.ts` — call injectScoreContext() before system prompt is sent to Dialogflow CX; log timeout events to analytics — GH-101
- [ ] T066 [US4] Wire score-context-cache invalidation in `chat-backend/src/assessment/assessment-sessions.service.ts` — call scoreContextCache.invalidate(userId) after successful completeSession() — GH-102

**Checkpoint**: US4 fully functional — AI filter blocks prohibited content; score context injection uses bands only; cache invalidates on new assessment

---

## Phase 7: User Story 5 — Analytics Instrumentation & RBAC (Priority: P2) 🎯 Sprint 3

**Goal**: All 8 event types captured; cohort analytics returns 403 for cross-role access; k=10 suppression enforced at data layer; GDPR audit log queryable by admin with CSV export.

**Independent Test**: Fire all 8 events in staging → confirm all in analytics store within 5s. Call restricted endpoint as supervisor without cohort assignment → 403. Query cohort of 9 members → suppressed result.

- [ ] T067 [US5] Write and apply migration `chat-backend/migrations/030-010-analytics-events.sql` — create `analytics_events` table per data-model.md — GH-103
- [ ] T068 [US5] Implement `chat-backend/src/analytics/event-instrumentation.service.ts` — recordEvent(eventType, userId, cohortId, metadata): writes to analytics_events; validates eventType is one of 8 permitted enum values; validates metadata contains no PII — GH-104
- [ ] T069 [US5] Wire recordEvent() calls at all 8 trigger points: session start/end in `chat-backend/src/chat/session.service.ts`; message_sent in `chat-backend/src/chat/message.service.ts`; assessment_completed/abandoned in `chat-backend/src/assessment/assessment-sessions.service.ts`; flag_created/resolved in `chat-backend/src/flags/flag.service.ts`; review_submitted in `chat-backend/src/review/review.service.ts` — GH-105
- [ ] T070 [US5] Implement `chat-backend/src/analytics/anonymity-guard.ts` — withKAnonymityGuard(query, k=10): adds HAVING COUNT(DISTINCT pseudonymous_user_id) >= 10 to Knex query builder; export as shared helper used by ALL analytics query methods — GH-106
- [ ] T071 [US5] Implement `chat-backend/src/analytics/rbac.middleware.ts` — reads JWT role claim; for supervisor role: queries supervisor_cohort_assignments to get allowed cohort IDs; attaches allowedCohortIds to request context; for admin: no cohort restriction; for others: 403 immediately — GH-107
- [ ] T072 [US5] Implement `chat-backend/src/analytics/supervisor-cohort.service.ts` — getSupervisorCohorts(supervisorId): returns cohort IDs from supervisor_cohort_assignments; applyCohortScope(query, allowedCohortIds): adds WHERE cohort_id IN (...) guard to Knex query — GH-108
- [ ] T073 [US5] Implement `GET /analytics/cohorts/:cohortId/outcomes` in `chat-backend/src/analytics/analytics.controller.ts` — applies rbac.middleware + cohortAnalyticsMiddleware (k≥25) + anonymity-guard (k=10 on all aggregate queries); returns CohortOutcomeSummary per analytics-api.yaml contract — GH-109
- [ ] T074 [US5] Implement `GET /gdpr/audit-log` in `chat-backend/src/analytics/audit-log.controller.ts` — admin only; paginated; includes alerts[] for erasure requests where created_at < NOW() - 30 days AND status != 'completed' — GH-110
- [ ] T075 [US5] Implement `POST /gdpr/audit-log/export` in `chat-backend/src/analytics/audit-log.controller.ts` — generates CSV with fields: audit_id, event_type, actor, occurred_at, outcome; NO clinical data; logs this export action itself to gdpr_audit_log — GH-111
- [ ] T076 [US5] Implement workbench GDPR audit log dashboard `workbench-frontend/src/features/gdpr-audit/AuditLogDashboard.tsx` — table view of audit events; alert banner for overdue erasure requests; filter by event_type and date range; WCAG AA compliant — GH-112
- [ ] T077 [US5] Implement `workbench-frontend/src/features/gdpr-audit/AuditCsvExport.tsx` — button that calls `POST /gdpr/audit-log/export`; triggers file download; admin role only (hidden for non-admin) — GH-113
- [ ] T078 [US5] Add uk/en/ru translation keys for audit log UI to `workbench-frontend/src/i18n/` locale files — GH-114

**Checkpoint**: US5 fully functional — 8-event instrumentation, k=10 suppression, RBAC 403 enforcement, and GDPR audit dashboard all working

---

## Phase 8: User Story 6 — Annotation & Inter-Rater Reliability (Priority: P3) 🎯 Sprint 4

**Goal**: Two annotators label same transcript without seeing peer labels until both submit; kappa computed automatically; alert fires if κ < 0.6; model performance metrics available.

**Independent Test**: Create two annotation sessions on same transcript → Annotator A submits → confirm Annotator B cannot see A's labels → B submits → confirm is_visible_to_peers=true → kappa computed → verify against manual reference within ±0.001.

- [ ] T079 [US6] Write and apply migration `chat-backend/migrations/030-011-annotations.sql` — create `annotations` table with `is_visible_to_peers` BOOLEAN NOT NULL DEFAULT FALSE; create `sampling_runs` table per data-model.md — GH-115
- [ ] T080 [US6] Implement `chat-backend/src/annotation/annotation-blinding.service.ts` — assignAnnotators(transcriptId, annotatorIds): creates annotation records with is_visible_to_peers=false; getMyAssignment(transcriptId, annotatorId): returns transcript + own labels only (WHERE annotator_id = $annotatorId); checkAllSubmitted(transcriptId): returns boolean; revealPeerLabels(transcriptId): sets is_visible_to_peers=true for all annotations on transcript — GH-116
- [ ] T081 [US6] Implement `POST /annotation/assignments`, `GET /annotation/transcripts/:id/my-assignment`, `POST /annotation/transcripts/:id/submit` in `chat-backend/src/annotation/annotation.controller.ts` — submit endpoint: saves labels → checks all submitted → if yes: calls revealPeerLabels() + triggers kappa computation — GH-117
- [ ] T082 [US6] Implement `chat-backend/src/annotation/kappa.service.ts` — computeCohenKappa(pairs): pairwise kappa; computeWeightedKappa(pairs, weightType: 'linear'|'quadratic'): weighted variants; computeFleissKappa(matrix): for ≥3 raters; bootstrapCI(annotations, iterations=1000): returns {lower, upper, mean}; buildConfusionMatrix(pairs): per category — GH-118
- [ ] T083 [US6] Write unit test `chat-backend/tests/unit/kappa.test.ts` — use published reference dataset with known κ values; assert computed kappa matches reference within ±0.001 for pairwise, linear-weighted, quadratic-weighted; assert bootstrapCI produces valid interval (lower < mean < upper) — GH-119
- [ ] T084 [US6] Wire kappa computation to annotation submission: after revealPeerLabels(), call kappaService.computeAll(transcriptId); if result.pairwiseKappa < 0.6: call notificationService.alertClinicalLead(transcriptId, kappaResult) — GH-120
- [ ] T085 [US6] Implement `GET /annotation/transcripts/:id/adjudication`, `GET /annotation/transcripts/:id/kappa` in `chat-backend/src/annotation/annotation.controller.ts`; adjudication endpoint returns 403 if not all annotators submitted — GH-121
- [ ] T086 [US6] Implement `chat-backend/src/annotation/transcript-sampling.service.ts` — sampleTranscripts(config, size): stratified sampling by flag_type, session_length, region, severity; deterministic via seeded PRNG (log seed to sampling_runs); redactPII(transcriptIds): scans for pseudonymous_user_id patterns and removes; returns SamplingRunResponse — GH-122
- [ ] T087 [US6] Implement `POST /annotation/sampling/runs` in `chat-backend/src/annotation/annotation.controller.ts`; admin only — GH-123
- [ ] T088 [US6] Implement `chat-backend/src/annotation/model-metrics.service.ts` — computeMetrics(groundTruthAnnotations, modelPredictions): sensitivity, specificity, PPV, NPV, FNR, F1, fBeta(β=4.47) per category and aggregate; fBeta formula: `(1 + β²) × (precision × recall) / (β² × precision + recall)` — GH-124
- [ ] T089 [US6] Write unit test `chat-backend/tests/unit/model-metrics.test.ts` — verify sensitivity/specificity/F-beta against manually computed reference values; assert fBeta(β=4.47) with known precision/recall matches reference within ±0.001 — GH-125
- [ ] T090 [US6] Implement `GET /annotation/metrics` in `chat-backend/src/annotation/annotation.controller.ts` — GH-126
- [ ] T091 [US6] Implement annotation interface `workbench-frontend/src/features/annotation/AnnotationInterface.tsx` — shows PII-redacted transcript messages; label input per message (label_category + confidence slider + rationale textarea); submit button; peer labels hidden until is_visible_to_peers=true; keyboard navigable (WCAG AA) — GH-127
- [ ] T092 [US6] Implement `workbench-frontend/src/features/annotation/AdjudicationView.tsx` — side-by-side view of Annotator A and B labels (anonymous indices) after both submit; shows adjudicated_label field for admin to fill — GH-128
- [ ] T093 [US6] Implement `workbench-frontend/src/features/annotation/KappaResultPanel.tsx` — displays κ value, CI bounds, confusion matrix; shows alert badge if κ < 0.6 — GH-129
- [ ] T094 [US6] Add uk/en/ru translation keys for annotation UI to `workbench-frontend/src/i18n/` locale files — GH-130

**Checkpoint**: US6 fully functional — annotation blinding, kappa computation with CI, alerts, sampling pipeline, model metrics all working

---

## Phase 9: User Story 7 — DevOps, Scale & Regional Deployment (Priority: P3) 🎯 Sprint 4

**Goal**: Platform validated for 1,000-user scale; autoscaling fires in < 30s; regional deployment playbook executable.

**Independent Test**: Run `chat-ui/tests/load/chat-load-1000.spec.ts` → p95 chat < 500ms; run `workbench-load-1000.spec.ts` → p95 workbench < 1,000ms; error rate < 0.1%; autoscale adds capacity within 30s.

- [ ] T095 [US7] Write chat-infra script `scripts/030-autoscaling-review.sh` — documents current Cloud Run min/max instances, concurrency, CPU/memory for chat-backend and workbench-frontend; proposes values for 1,000-user scale based on load test results; outputs current config to `evidence/T095/autoscaling-config.txt` — GH-131
- [ ] T096 [US7] Review and apply Cloud Run autoscaling config updates via `scripts/030-autoscaling-review.sh` — set recommended min/max instances, concurrency limits; deploy to dev; document changes in chat-infra README — GH-132
- [ ] T097 [US7] Write chat-infra script `scripts/030-cloudsql-pooling-review.sh` — queries current connection pool config; runs pg_stat_activity analysis; projects connection count at 1,000 users; outputs recommendations to `evidence/T097/pooling-config.txt` — GH-133
- [ ] T098 [US7] Apply Cloud SQL connection pooling config updates — update Cloud Run env vars for pool size; update pgBouncer config if applicable; validate under staging load — GH-134
- [ ] T099 [US7] Write load test `chat-ui/tests/load/chat-load-1000.spec.ts` — Playwright test: 1,000 concurrent virtual users; measures p95, p99, error rate; asserts p95 < 500ms; asserts error rate < 0.1%; outputs results to `evidence/T099/chat-load-results.json` — GH-135
- [ ] T100 [US7] Write load test `chat-ui/tests/load/workbench-load-1000.spec.ts` — same pattern; asserts p95 workbench < 1,000ms; outputs results to `evidence/T100/workbench-load-results.json` — GH-136
- [ ] T101 [US7] Run load tests against dev environment; capture autoscale timing evidence; assert capacity available within 30 seconds of threshold crossing; save evidence to `evidence/T101/autoscale-timing.txt` — GH-137
- [ ] T102 [US7] Write regional deployment playbook `chat-infra/docs/030-regional-deployment-playbook.md` — sections: (1) invite code initialisation for new region, (2) KPI dashboard template configuration, (3) go-live checklist (mirrors PRD-1.6 §B with infra additions), (4) 30-day post-launch monitoring checklist with health indicators (error rate, latency p95, data growth, flag SLA compliance) and remediation steps per out-of-range indicator — GH-138

**Checkpoint**: US7 fully functional — load tests green, autoscaling validated, playbook documented

---

## Phase 10: Polish & Cross-Cutting Concerns

**Purpose**: Security review sign-off, a11y validation, and final verification checklist

- [ ] T103 [P] Run security review checklist from plan.md — verify each item in `evidence/T103/security-review.md`: identity map SA permissions, PII middleware false-positive rate, consent enforcement test coverage, erasure cascade with in-progress session, AI filter regression suite (≥50 cases/category), k=10 unit test coverage across all analytics paths, annotation blinding DB-layer test — GH-139
- [ ] T104 [P] Run quickstart.md verification checklist — confirm all 10 items pass on a clean dev schema; capture output to `evidence/T104/quickstart-verification.txt` — GH-140
- [ ] T105 [P] Accessibility audit for all new workbench components (InviteCodeManager, AuditLogDashboard, AnnotationInterface, AdjudicationView) — run `axe-core` automated scan; verify WCAG AA contrast ratios; verify keyboard navigation and focus indicators; document results in `evidence/T105/a11y-audit.md` — GH-141
- [ ] T106 Confirm all 9 backend migrations apply cleanly on a fresh schema in CI; update `chat-backend/CLAUDE.md` with new service directories and migration naming convention — GH-142

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1 (Setup)     → no dependencies — start immediately
Phase 2 (Foundational) → requires Phase 1 (T001–T009 complete)
Phase 3 (US1)       → requires Phase 2 complete (T010–T017)
Phase 4 (US2)       → requires Phase 2 complete; benefits from US1 (consent audit log)
Phase 5 (US3)       → requires Phase 2 complete; requires US1 (erasure cascade) + US2 (consent check)
Phase 6 (US4)       → requires Phase 2 complete; requires US3 (score trajectories for context injection)
Phase 7 (US5)       → requires Phase 2 complete; requires US1 (audit log) + US2 (cohort scoping)
Phase 8 (US6)       → requires Phase 2 complete; standalone (no dependency on US3–US5)
Phase 9 (US7)       → requires Phase 2 complete; run load tests after Phase 3–7 deployed to dev
Phase 10 (Polish)   → requires all user story phases complete
```

### User Story Hard Dependencies

| Story | Depends On | Reason |
|-------|-----------|--------|
| US3 (Assessment Schema) | US1 (erasure cascade) | Erasure cascade must nullify assessment rows |
| US3 (Assessment Schema) | US2 (consent enforcement) | Assessment API requires Category 3 consent check |
| US4 (AI Safety) | US3 (score trajectories) | Score context injection reads from score_trajectories view |
| US5 (Analytics RBAC) | US1 (audit log service) | GDPR audit log dashboard uses GDPRAuditService |
| US5 (Analytics RBAC) | US2 (cohort assignments) | supervisor_cohort_assignments table needed for RBAC scoping |

### Parallel Opportunities Per Sprint

**Sprint 1** (after Phase 2 complete):
```
Parallel track A: US1 (T018–T027) — Privacy & Identity
Parallel track B: US2 (T028–T042) — Consent & Cohort
```

**Sprint 2** (after US1 + US2 complete):
```
US3 (T043–T059) — sequential (depends on US1 + US2)
```

**Sprint 3** (after US3 complete):
```
Parallel track A: US4 (T060–T066) — AI Safety
Parallel track B: US5 (T067–T078) — Analytics & RBAC
```

**Sprint 4** (after Phase 2 complete — independent of US3–US5):
```
Parallel track A: US6 (T079–T094) — Annotation & ML
Parallel track B: US7 (T095–T102) — DevOps & Scale
```

---

## Parallel Execution Examples

### Phase 3 (US1) — Inner Parallel Tasks
```
# These tasks in US1 can run in parallel (different files):
T018: identity-map DB connection config
T023: gdpr-audit.service.ts
T026: infra retention script verification
T027: encryption audit script
```

### Phase 4 (US2) — Inner Parallel Tasks
```
# These tasks can run in parallel after T028–T029 migrations complete:
T034: invite-code.service.ts (backend)
T040: InviteCodeManager.tsx (frontend)
T042: i18n translation keys
```

### Phase 8 (US6) — Inner Parallel Tasks
```
# These can run in parallel once T079 migration complete:
T082: kappa.service.ts
T086: transcript-sampling.service.ts
T088: model-metrics.service.ts
T091: AnnotationInterface.tsx (frontend)
```

---

## Implementation Strategy

### MVP: Sprint 1 (US1 + US2 only — P1 goals)

1. Complete Phase 1: Setup (T001–T009)
2. Complete Phase 2: Foundational (T010–T017) — CRITICAL GATE
3. Complete Phase 3: US1 Privacy & Identity (T018–T027)
4. Complete Phase 4: US2 Consent & Cohort (T028–T042)
5. **STOP and VALIDATE**: Erasure cascade works, consent enforced, invite codes generated, cohort join tested
6. Deploy to dev and run Playwright E2E smoke tests

### Incremental Delivery

```
Sprint 1: US1 + US2 → Privacy-safe user onboarding (pilot go-live prerequisite)
Sprint 2: US3       → Assessment data schema (enables Phase 2 Dialogflow work)
Sprint 3: US4 + US5 → AI safety + analytics RBAC (enables Phase 3 dashboards)
Sprint 4: US6 + US7 → Annotation ML + scale validation (Phase 4 prerequisites)
```

### Jira Epic Mapping (created via /speckit.taskstoissues)

| User Story | Epic | Jira Story Count |
|------------|------|-----------------|
| US1: Privacy & Identity | 1 Epic | ~10 Stories |
| US2: Consent & Cohort | 1 Epic | ~15 Stories |
| US3: Assessment Schema | 1 Epic | ~17 Stories |
| US4: AI Safety | 1 Epic | ~7 Stories |
| US5: Analytics & RBAC | 1 Epic | ~12 Stories |
| US6: Annotation & ML | 1 Epic | ~16 Stories |
| US7: DevOps & Scale | 1 Epic | ~8 Stories |

---

## Notes

- [P] tasks have no shared file conflicts and can run concurrently within the same phase
- All migrations prefixed `030-NNN-` in numeric order — run with `npx knex migrate:up` one at a time
- Migration 030-001 is breaking — data migration script (T014) MUST run before schema migration (T015)
- `user_identity_map` infra (T010–T011) MUST complete before T018 (identity map DB config)
- `qrcode` npm package required for T034 — added in T039
- Therapy-gated items (SLA values, risk threshold values, fallback message content, taxonomy labels) are excluded — schema and infrastructure are built; values populated after clinical sign-off
- Evidence files should be committed to the feature branch in `evidence/` directory

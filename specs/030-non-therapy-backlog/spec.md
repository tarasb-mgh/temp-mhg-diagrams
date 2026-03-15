# Feature Specification: Non-Therapy Technical Backlog

**Feature Branch**: `030-non-therapy-backlog`
**Created**: 2026-03-15
**Status**: Draft
**Input**: User description: "Non-therapy technical backlog — 38 requirements implementable without therapy team approval, covering privacy & identity infrastructure, consent & cohort onboarding, clinical assessment data schema, AI safety & filtering, analytics infrastructure & RBAC, annotation & ML infrastructure, and DevOps & scale."

---

## Overview

This specification covers 38 technical, security, and compliance requirements that the engineering team can implement without therapy team approval. They are grouped into seven independently deliverable categories. Each category has a dedicated user story and is designed to be specced, planned, and executed as a standalone sprint increment.

Items explicitly gated on therapy/clinical team sign-off (SLA threshold values, risk threshold values, SafetyProtocolFlow content, AI response guideline content, taxonomy label definitions, and instrument licensing decisions) are **out of scope** for this spec.

---

## Clarifications

### Session 2026-03-15

- Q: Should GDPR "right to erasure" be implemented via physical data deletion or via anonymisation (severing the identity link while preserving anonymised health data records)? → A: Anonymisation — delete the identity map record to irreversibly sever the credential-to-pseudonymous-ID link; retain all health data records in place (they are now anonymous, not personal data). Do NOT nullify foreign keys in health data tables.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Privacy & Identity Infrastructure (Priority: P1)

A data privacy officer needs to be able to verify at any time that no personally identifiable information exists in any health-data table, request account erasure on behalf of a user, and receive a confirmed completion record for that erasure within the legal deadline — without relying on manual processes or engineering intervention for each request.

**Why this priority**: This is a prerequisite for pilot go-live. GDPR Article 25, Article 17, and Ukrainian Law No. 2297-VI require pseudonymisation and erasure capability before any user health data is collected. No other feature can be deployed without this foundation.

**Independent Test**: A DPO can submit an erasure request through a test account, confirm the erasure job completes, and verify via schema inspection that no PII remains in any operational table row. This test delivers value independently as a compliance audit tool.

**Acceptance Scenarios**:

1. **Given** a registered user exists with session and assessment data, **When** an erasure request is submitted, **Then** the identity-map record is deleted (credential-to-pseudonymous-ID link irreversibly severed), the user record is marked `anonymised_at`, all health data records are retained in place (now anonymous), and a completion event is logged to the audit trail within 24 hours. Foreign keys in session, assessment, annotation, and analytics tables MUST remain intact — no FK is nullified.
2. **Given** an API request is submitted containing an email address in the request body, **When** the request reaches any health-data endpoint, **Then** the system rejects the request with an error and logs a PII-rejection event — no data is written.
3. **Given** any service other than the authentication service attempts to query the identity mapping store, **When** the query reaches the data layer, **Then** the request is denied with a permission error and the attempt is logged.
4. **Given** an audit log entry is written to the retention store, **When** the log age reaches 3 years, **Then** the record is retained (not purged) — verified by retention policy configuration inspection.
5. **Given** all data at rest is stored in the Cloud SQL database, **When** a DPO requests an encryption status report, **Then** the report confirms all Cloud SQL instances use at-rest encryption with a managed key.

---

### User Story 2 — Consent & Cohort Onboarding (Priority: P1)

A regional programme coordinator needs to distribute join materials to a unit of officers that allow them to enrol in the platform anonymously — with no digital trace linking a specific officer to their act of joining. A clinical supervisor needs aggregate analytics to be locked until the cohort is large enough to prevent re-identification. A returning user needs to be able to upgrade from a guest session to a verified session without losing any prior history.

**Why this priority**: Cohort onboarding is the entry point for all platform data. Without privacy-safe join mechanics and minimum-size enforcement, the platform cannot be deployed to real users without re-identification risk.

**Independent Test**: A test coordinator creates an invite code, distributes it to 30 test accounts, verifies analytics remain unavailable until account 25 joins, then confirms a guest user who upgrades to verified status retains all prior session data under the same identity.

**Acceptance Scenarios**:

1. **Given** a cohort admin generates an invite code, **When** the code is used to join, **Then** the joining user is assigned a pseudonymous identity with no PII stored — the code itself encodes only organisation and optional role category, never an individual identifier.
2. **Given** a cohort has 24 registered members, **When** a supervisor queries cohort analytics, **Then** the system returns a "cohort too small" message and no aggregate data — this guard is enforced at the data layer, not the UI.
3. **Given** an invite code has passed its expiry date, **When** a new user attempts to join with that code, **Then** the system returns an expiry error and creates no user record.
4. **Given** a guest user has completed three sessions, **When** they upgrade to OTP-verified status, **Then** all three prior sessions are accessible under the same identity after upgrade — no session data is lost or re-linked to a new identity.
5. **Given** the consent version has been incremented, **When** a returning user starts a new session, **Then** the system presents the updated consent before any data-writing operation — prior data is not retroactively affected.
6. **Given** a user has not yet provided consent, **When** any health-data write is attempted, **Then** the system returns an error — no database record is created.

---

### User Story 3 — Clinical Assessment Data Schema (Priority: P1)

A backend engineer needs a stable, append-only schema for storing completed clinical assessments so that clinical supervision views and Phase 3 dashboards can be built on top of it — even before the Dialogflow CX assessment flows exist. A clinical supervisor needs to query a user's score history over time and see whether their wellbeing is improving, stable, or deteriorating.

**Why this priority**: The assessment data schema is the foundation for Phases 2, 3, and 4 of the roadmap. Without it, clinical supervision views, dashboards, and outcome reporting cannot be built. The schema is independent of the Dialogflow flows and can be validated with seeded test data.

**Independent Test**: An engineer seeds three completed PHQ-9 assessments for a test user, queries the longitudinal trajectory view, confirms correct reliable-change-index computation and clinically-meaningful-improvement flags, then attempts an UPDATE on the scores table and confirms it is blocked. This delivers value as a standalone integration test suite.

**Acceptance Scenarios**:

1. **Given** a completed assessment is submitted, **When** the data is persisted, **Then** one session record, one score record, and one item record per question are created — all rows contain no PII, only pseudonymous identity references.
2. **Given** an attempt to UPDATE or DELETE a row in the scores table is made outside the approved erasure process, **When** the database receives the command, **Then** the command is rejected — append-only integrity is enforced at the data layer, not only by application logic.
3. **Given** a user has three historical PHQ-9 scores (18, 12, 7), **When** the longitudinal trajectory view is queried, **Then** the reliable change index is correctly computed for each consecutive pair and the 18→7 delta is flagged as a clinically meaningful improvement.
4. **Given** a request is submitted to the internal score aggregation endpoint, **When** the response is measured under concurrent load, **Then** 95% of responses are returned within the defined SLA — verified by a staging load test.
5. **Given** an assessment schedule is created for a user with a severe severity band, **When** the scheduler runs, **Then** the next assessment is triggered at a 14-day interval; if the band is moderate, 28 days; if mild, 35 days.
6. **Given** a GDPR erasure cascade runs for a user with assessment data, **When** the cascade completes, **Then** all assessment rows linked to that pseudonymous identity are retained in place — the pseudonymous identity is now anonymous (identity map deleted), so the records are no longer personal data. Aggregate counts across all users remain correct and unaffected.

---

### User Story 4 — AI Safety & Response Filtering (Priority: P2)

An AI response that contains clinical diagnostic language, numeric assessment scores, or clinical urgency terms must be intercepted before it reaches the user, replaced with a pre-approved safe fallback message, and logged for clinical review. The AI system should receive contextual information about a user's wellbeing trajectory — but only in the form of a severity band label and direction, never a raw numeric score.

**Why this priority**: Patient safety. The platform's EU AI Act Article 14 compliance and clinical governance requirements prohibit the AI from delivering diagnostic-sounding statements. This filter is a prerequisite for any production deployment of the AI chat feature.

**Independent Test**: A test message containing a PHQ-9 numeric score pattern is submitted to the AI pipeline; the test confirms the message is filtered before delivery, the fallback message is returned, and the interception is logged. A second test confirms the AI's system prompt receives a severity band label ("Moderate, improving") not a raw score ("PHQ-9: 12").

**Acceptance Scenarios**:

1. **Given** the AI generates a response containing a numeric pattern near an instrument name (e.g., "PHQ-9: 18"), **When** the post-generation filter runs, **Then** the response is blocked, replaced with the approved fallback, and a filter-event log entry is created.
2. **Given** the AI generates a response containing diagnostic terminology or clinical urgency language, **When** the post-generation filter runs, **Then** the response is blocked and replaced — the user never sees the original response.
3. **Given** a user has a completed assessment on record, **When** the AI system prompt is constructed for that user's session, **Then** it contains the severity band label and trajectory direction only — no numeric score value is included.
4. **Given** the score context lookup service is unavailable, **When** the system prompt is being constructed, **Then** the session proceeds without score context — the filter does not block the session, it fails open.
5. **Given** a user completes a new assessment during a session, **When** the next message is processed, **Then** the score context in the system prompt reflects the new assessment result, not the prior session's cached value.

---

### User Story 5 — Analytics Instrumentation & Access Control (Priority: P2)

A clinical supervisor needs to be able to view outcome data for the users in their assigned cohort — and only those users. An admin needs to query a full audit log of GDPR-sensitive events and export it as a CSV file for regulatory submissions. An engineer needs confidence that every access control rule is enforced at the data layer, not only at the UI, so that direct API calls cannot bypass restrictions.

**Why this priority**: GDPR Article 5(1)(f) and ISO 27701 require data access to be limited to the minimum necessary. A supervisor who can see data outside their cohort, or a UI that hides data an API still serves, is a compliance failure.

**Independent Test**: A supervisor account without a cohort assignment calls a restricted analytics endpoint directly — the system returns a 403. An admin fires all 8 instrumented events in staging, then exports the audit log CSV and confirms all event types appear with correct metadata.

**Acceptance Scenarios**:

1. **Given** a clinical supervisor is assigned to Cohort A, **When** they query outcome data, **Then** only records belonging to Cohort A users are returned — records from any other cohort are absent from the response at the data layer.
2. **Given** a user with a supervisor role makes a direct API call to an admin-only endpoint, **When** the request reaches the API, **Then** a 403 response is returned — no data is returned regardless of whether the UI hides the endpoint.
3. **Given** a cohort has fewer than 10 active members, **When** any cohort-level analytics query runs, **Then** no row-level data is returned — the suppression applies to all query paths, not only the dashboard UI.
4. **Given** a GDPR erasure request is submitted, **When** an admin queries the audit log, **Then** the request event, completion event, and actor details are visible — and an alert is raised if the request has not completed within 30 days.
5. **Given** an admin requests a CSV export of the audit log, **When** the export is generated, **Then** the file contains metadata only (event type, timestamp, actor, outcome) — no clinical session content or assessment scores are included.
6. **Given** all 8 instrumented event types fire in a staging test session, **When** the analytics store is queried, **Then** all 8 events are present with correct pseudonymous identity references, cohort IDs, and timestamps.

---

### User Story 6 — Annotation & Inter-Rater Reliability (Priority: P3)

A researcher needs to assign two annotators to the same conversation transcript and be confident that neither can see the other's labels before both have submitted — preventing anchoring bias. After both submit, inter-rater reliability statistics must be computed automatically and an alert must fire if agreement falls below the minimum acceptable threshold.

**Why this priority**: Annotation quality is the foundation of the ML training pipeline. Contaminated labels (where annotators influenced each other) invalidate model training. This infrastructure can be built independently of clinical content decisions and enables the ML team to begin reliability testing.

**Independent Test**: Two annotator accounts are assigned the same transcript; Annotator A submits labels; the system confirms Annotator B cannot see A's labels; Annotator B submits; kappa is computed and the result is compared against a known manual calculation to confirm accuracy within tolerance.

**Acceptance Scenarios**:

1. **Given** two annotators are assigned the same transcript, **When** Annotator A submits their labels, **Then** Annotator B's interface shows no indication of A's labels — blinding is enforced at the data layer, not only the UI.
2. **Given** both annotators have submitted their labels, **When** the system computes inter-rater reliability, **Then** Cohen's kappa (pairwise), weighted kappa (linear and quadratic), and Fleiss' kappa (for ≥3 raters) are all computed with a 1,000-iteration bootstrap confidence interval.
3. **Given** the computed kappa falls below 0.6, **When** the computation completes, **Then** an alert is sent to the Clinical Lead — the alert includes the transcript ID, annotator pair, kappa value, and confidence interval.
4. **Given** a sampling pipeline run is triggered, **When** transcripts are selected for annotation, **Then** the sample is stratified by flag type, session length, region, and severity — the random seed is logged so the sample can be reproduced exactly.
5. **Given** a transcript is selected for annotation, **When** it is exported to the annotator interface, **Then** all personally identifiable information has been automatically redacted — no annotator ever sees a pseudonymous ID or any PII.
6. **Given** a model evaluation run completes, **When** performance metrics are computed, **Then** sensitivity, specificity, PPV, NPV, FNR, F1, and F-beta (with β=4.47 for a 20:1 false-negative cost asymmetry) are all computed per category and in aggregate.

---

### User Story 7 — DevOps, Scale & Regional Deployment (Priority: P3)

An operations engineer needs to deploy the platform to a new region by following a documented playbook, and needs confidence that the existing infrastructure can handle the load of 1,000 concurrent users before a pilot launch.

**Why this priority**: Infrastructure capacity and a repeatable deployment process gate every pilot expansion. Without load validation and a deployment playbook, each new regional launch is ad hoc and risky.

**Independent Test**: A load test is run against the staging environment targeting 1,000 concurrent users; the test confirms all latency and autoscaling targets are met. A second test executes the deployment playbook in a second environment to confirm it is complete and accurate.

**Acceptance Scenarios**:

1. **Given** 1,000 concurrent users are active on the platform, **When** load is measured at the 95th percentile, **Then** the chat interface responds within the defined SLA and the workbench interface responds within its defined SLA — without error rate exceeding the threshold.
2. **Given** load spikes from normal to peak concurrency, **When** the autoscaling system responds, **Then** the additional compute capacity is available within 30 seconds — no requests are dropped during the scale-up window.
3. **Given** an operations engineer follows the regional deployment playbook for a new region, **When** all checklist items are completed, **Then** the new region is fully operational: invite codes are configured, KPI dashboard templates are applied, and the go-live checklist is signed off.
4. **Given** the platform has been running for 30 days post-launch in a region, **When** the post-launch monitoring checklist is reviewed, **Then** all health indicators (error rate, latency, data growth, flag SLA compliance) are within acceptable ranges — any out-of-range item triggers a documented remediation step.

---

### Edge Cases

- A user submits an erasure request while an assessment session is actively in progress (status: in_progress) — the anonymisation cascade must handle in-progress sessions gracefully: the identity map is deleted immediately; the in-progress session record is retained (now anonymous) with its incomplete status preserved.
- A cohort's membership drops below k=10 after analytics have already been queried and displayed — retroactive suppression behaviour must be explicitly defined.
- The PII-rejection middleware fires a false positive on a legitimate non-PII input string that matches the detection pattern — the false positive rate must be monitored and tunable.
- The score context lookup times out (200ms threshold exceeded) during system prompt construction — the system must fail open and proceed without score context rather than blocking the session.
- A guest user with prior sessions attempts an OTP upgrade from a different device — identity merge must handle cross-device upgrade without creating duplicate identity records.
- An annotation is submitted for a transcript whose source session has since been erased (pseudonymous_user_id nullified) — the annotation record must remain valid for ML purposes while the identity reference is absent.
- A Clinical Lead updates a risk threshold value in the configuration while an assessment is actively being scored — the new threshold must apply only to new assessments, not retroactively to the in-flight one.
- A load test autoscale event fires during a deployment window — autoscaling configuration changes must not interrupt in-flight requests.

---

## Requirements *(mandatory)*

### Functional Requirements

#### Security & Identity

- **FR-001**: The system MUST assign every new user a pseudonymous identity at account creation. The identity MUST be generated using a cryptographically secure random value with a per-user salt. No table containing session data, assessment scores, risk flags, or intake responses MUST contain any column holding personally identifiable information.
- **FR-002**: The identity mapping store (linking authentication credentials to pseudonymous identities) MUST reside in a separate data store from all operational tables, with distinct access controls. Only the authentication service MUST have read access to this store.
- **FR-003**: The system MUST implement a right-to-erasure cascade using **anonymisation** (not physical deletion of health data): (1) delete the identity mapping record so the link between authentication credentials and the pseudonymous identity is irreversibly severed; (2) mark the user record as anonymised (`anonymised_at` timestamp) and clear any remaining PII fields on that record; (3) retain all health data records (sessions, assessments, annotations) — these records reference only the pseudonymous identity which is now permanently unresolvable, making them legally anonymous rather than personal data. FK references in health data tables MUST NOT be nullified. Completion MUST be logged to the audit trail, and the full cascade MUST complete within the 30-day legal SLA (target: within 24 hours).
- **FR-004**: All API endpoints that accept health data MUST enforce a runtime check rejecting any request body that contains patterns matching email addresses, phone numbers, or other common personally identifiable information formats. Rejected requests MUST be logged.
- **FR-005**: Any service other than the authentication service that attempts to access the identity mapping store MUST receive a permission-denied error. All such attempts MUST be logged.
- **FR-006**: The audit log retention policy MUST be configured for a minimum of 3 years across all retention stores. This MUST be verified by policy inspection, not manual review.
- **FR-007**: All data at rest in the database must be verified as encrypted using a managed encryption key. Verification MUST be documented as part of the go-live security checklist.

#### Consent & Cohort Onboarding

- **FR-008**: The system MUST maintain a versioned consent record for each user, storing pseudonymous identity, consent version, timestamp, accepted categories, and consent method. When the consent version changes, the system MUST prompt returning users before any data-writing operation.
- **FR-009**: Consent enforcement MUST be applied at the data layer (not UI only) per category: basic session consent checked by the session service; intake data consent checked by the intake API; clinical assessment consent checked by the assessment API. A missing or revoked consent category MUST result in a 403 error, not a silent skip.
- **FR-010**: The system MUST prevent any database write from occurring before a user has affirmed consent. This constraint MUST be enforced both client-side (early return) and server-side (guard before write), and MUST be verified by an integration test.
- **FR-011**: Invite codes MUST be organisation-level only (no individual-level codes). Each code MUST be an 8-character uppercase alphanumeric string excluding visually ambiguous characters. A scannable QR representation MUST be generated at a minimum resolution of 300 DPI for physical distribution.
- **FR-012**: The system MUST enforce a minimum cohort size of 25 registered members before any cohort-level analytics are made available. This guard MUST be applied at the data query layer, not the UI layer.
- **FR-013**: Expired invite codes MUST return an expiry error and MUST NOT create any user record. The system MUST NOT silently accept or queue the join request.
- **FR-014**: The system MUST support a guest-to-verified upgrade path that merges the guest device session into the verified session, preserving the pseudonymous identity and all prior session references. The old guest credential entry MUST be marked as upgraded, not deleted.

#### Clinical Assessment Data Schema

- **FR-015**: The system MUST maintain three append-only tables for clinical assessment data: one for assessment sessions, one for item-level responses, and one for computed scores. No UPDATE or DELETE operation MUST be permitted on these tables outside the GDPR erasure cascade. This constraint MUST be enforced by a database-level trigger, not application logic only.
- **FR-016**: The system MUST maintain a longitudinal trajectory view per user per instrument, computing: score history sorted by date, rolling 30-day mean, reliable change index (using the Jacobson-Truax formula with published standard error of measurement values), and a clinically meaningful improvement flag (PHQ-9: ≥5-point reduction; GAD-7: ≥4-point reduction; PCL-5: ≥10-point reduction; WHO-5: ≥10-point increase). This view MUST refresh on a maximum 15-minute schedule.
- **FR-017**: An internal score aggregation endpoint MUST return longitudinal trajectories per user per instrument. Under concurrent load, 95% of responses MUST be returned within the defined response time SLA.
- **FR-018**: The assessment data schema MUST be designed to enable future FHIR export. Item-level responses MUST be mappable to FHIR QuestionnaireResponse resources. Score records MUST be mappable to FHIR Observation resources using published LOINC codes (PHQ-9: 44249-1; GAD-7: 69737-5; PCL-5: 91703-5; WHO-5: local code).
- **FR-019**: The system MUST maintain an assessment schedule record per user, tracking deferral count and a pause flag. A Cloud Tasks–based scheduler MUST trigger re-assessments at adaptive intervals based on the user's most recent severity band: severe band → 14 days; moderate band → 28 days; mild band → 35 days.
- **FR-020**: The system MUST maintain a configurable risk threshold table editable by the clinical lead. Each rule MUST specify threshold type (absolute score, deterioration delta, or item-level response pattern). All threshold changes MUST be logged with actor and timestamp. New threshold values MUST apply only to assessments completed after the change, not retroactively.
- **FR-021**: Risk flag creation MUST implement deduplication: a new Urgent-tier flag for a user with an existing open Urgent flag MUST update the existing flag rather than creating a duplicate. Critical-tier flags MUST always create a new record. All flags MUST support a resolution workflow recording the resolving supervisor and resolution timestamp.

#### AI Safety & Filtering

- **FR-022**: A server-side post-generation filter MUST run on every AI response before delivery. The filter MUST detect and block: numeric score values near instrument names, clinical diagnostic terminology, and clinical urgency language. Blocked responses MUST be replaced with an approved fallback message and logged with the original content for clinical review.
- **FR-023**: When constructing the AI system prompt for a session, the system MUST inject the user's current severity band label and trajectory direction (e.g., "Moderate, improving"). The system MUST NOT inject raw numeric score values. The context lookup MUST complete within 200ms; if it exceeds this threshold, the session MUST proceed without context injection (fail open).
- **FR-024**: Score context used in the system prompt MUST be cached at the session level per user. The cache MUST be invalidated when a new assessment session is completed for that user.

#### Analytics Instrumentation & RBAC

- **FR-025**: The system MUST instrument eight analytics events: session started, session ended, message sent, assessment completed, assessment abandoned, risk flag created, risk flag resolved, and review submitted. Every event MUST carry a pseudonymous identity reference, cohort identifier, and timestamp.
- **FR-026**: All cohort-level analytics queries MUST suppress results when the cohort member count is fewer than 10. This suppression MUST apply at the data query layer — not only the UI — and MUST be consistent across all query paths.
- **FR-027**: All analytics API endpoints MUST enforce role-based access at the data layer. A supervisor_cohort_assignments record MUST gate which cohort data a supervisor can access. Supervisors MUST receive a 403 error for any cohort not in their assignments. Admins have full access. End users have no access.
- **FR-028**: The system MUST provide an admin-accessible GDPR audit log view showing: erasure requests with 30-day SLA status, consent revocation events, PII masking events, and data export events. Any erasure request that has not been completed within 30 days MUST generate an alert.
- **FR-029**: Admins MUST be able to export the audit log as a CSV file. The export MUST contain event metadata only (event type, timestamp, actor, outcome) — no clinical session content, assessment scores, or other health data.

#### Annotation & ML Infrastructure

- **FR-030**: The annotation interface MUST enforce label blinding: an annotator MUST NOT be able to view another annotator's labels for the same transcript until both annotators have submitted. This constraint MUST be enforced at the data layer. After both submissions, a side-by-side adjudication view MUST be available.
- **FR-031**: The system MUST maintain an annotations table storing: transcript reference, message reference, annotator identity, label category, confidence score (0–1), free-text rationale, adjudicated label (post-review), and a ground-truth flag.
- **FR-032**: The transcript sampling pipeline MUST select transcripts using stratified sampling across flag type, session length, region, and severity band. Each sampling run MUST log its random seed so the sample can be reproduced exactly. All personally identifiable information MUST be automatically redacted from transcripts before they are made available to annotators.
- **FR-033**: The system MUST compute inter-rater reliability statistics after each annotation pair is completed: pairwise Cohen's kappa, linearly and quadratically weighted Cohen's kappa, and (for ≥3 raters) Fleiss' kappa. Each statistic MUST include a 1,000-iteration bootstrap confidence interval. A confusion matrix MUST be generated per label category. If the kappa value falls below 0.6, an alert MUST be sent to the Clinical Lead.
- **FR-034**: The system MUST compute model performance metrics per label category and in aggregate: sensitivity, specificity, positive predictive value, negative predictive value, false negative rate, F1, and F-beta with β=4.47 (reflecting a 20:1 cost asymmetry between false negatives and false positives in clinical safety contexts).
- **FR-035**: A load testing framework MUST be established targeting: p95 chat interface response time under 500ms, p95 workbench response time under 1,000ms, error rate under 0.1%, and the autoscaling system adding capacity within 30 seconds when load exceeds the threshold.

#### DevOps & Scale

- **FR-036**: Cloud compute autoscaling configuration MUST be reviewed and validated for 1,000-user scale, covering minimum and maximum instance counts, per-instance concurrency limits, and CPU/memory allocation.
- **FR-037**: Database connection pooling and failover configuration MUST be validated against a 12-month data growth projection. The validation MUST confirm the configuration supports peak load without connection exhaustion.
- **FR-038**: A regional deployment playbook template MUST be created covering: invite code initialisation, KPI dashboard configuration, go-live checklist, and a 30-day post-launch monitoring checklist with defined health indicators and remediation steps.

---

### Key Entities

- **User**: Pseudonymous identity (non-reversible random value). No PII columns. The only cross-table join key for all health data. On erasure: marked with `anonymised_at` timestamp; any residual PII-adjacent fields on the record are cleared. The record itself is retained so aggregate counts and health data FKs remain valid.
- **IdentityMapping**: Links an authentication credential (hashed phone number or device identifier) to a pseudonymous identity. Stored in a separate, access-controlled data store. **Deleted on erasure request** — this deletion is the act of anonymisation: once the mapping is gone, the pseudonymous identity in all health data tables is permanently unresolvable to a real person, making that data legally anonymous rather than personal data.
- **ConsentRecord**: Records a user's consent affirmation per version. Attributes: pseudonymous identity, consent version, timestamp, accepted category list, consent method. Versioned — a new record is created on re-consent, not an update.
- **Cohort**: An organisation-level group. Attributes: organisation, region, optional role category, invite code, expiry date, active status. Analytics are gated until membership ≥25.
- **AssessmentSession**: A single completed or abandoned clinical screening instance. Append-only. Attributes: pseudonymous identity, instrument reference, source session reference, start time, completion time, status.
- **AssessmentItem**: A single item-level response within an assessment session. Append-only. Attributes: session reference, item position, item key, response value, response timestamp.
- **AssessmentScore**: The computed score for a completed assessment session. Append-only. Attributes: session reference, instrument type, total score, severity band, instrument version reference, score computation timestamp, scoring key hash (for audit).
- **ScoreTrajectory**: A derived view per user per instrument, computed from AssessmentScore history. Contains: score history, rolling 30-day mean, reliable change index, clinically meaningful improvement flag. Refreshed on a scheduled basis.
- **AssessmentSchedule**: Tracks when the next assessment should be triggered for a user. Attributes: pseudonymous identity, instrument reference, next trigger date, deferral count, pause flag.
- **RiskThreshold**: A configurable threshold rule for flag creation. Attributes: threshold type, instrument reference, threshold value, configured by, configured at. Changes are audited and apply prospectively only.
- **RiskFlag**: A clinical alert created when a threshold rule fires. Attributes: pseudonymous identity, tier (Critical/Urgent/Routine), trigger reason, created at, resolved by, resolved at. Deduplication: Urgent flags are updated if an open one exists; Critical flags always create new records.
- **Annotation**: A label assignment for a transcript message. Attributes: transcript reference, message reference, annotator identity, label category, confidence, rationale, adjudicated label, ground truth flag.
- **GDPRAuditLog**: An immutable record of GDPR-sensitive operations. Attributes: event type, actor, pseudonymous identity reference (hashed), timestamp, outcome. Retained for a minimum of 3 years.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Zero personally identifiable information columns exist in any session, assessment, flag, or intake data table — verified by automated schema inspection that runs on every deployment.
- **SC-002**: Every erasure request is fully completed within 24 hours of submission in production — verified by audit log timestamp comparison across 100% of requests in the first 60 days of pilot operation.
- **SC-003**: Every consent enforcement check (session, intake, assessment) returns the correct allow/deny decision in 100% of integration test cases — no consent bypass is possible via direct API access.
- **SC-004**: All 8 analytics events are captured for 100% of qualifying user actions in staging — verified by a test session that intentionally triggers each event type and confirms all appear in the analytics store within 5 seconds.
- **SC-005**: All analytics API endpoints return a 403 response for 100% of cross-role access test cases — verified by an automated access control test suite that runs on every deployment.
- **SC-006**: Cohort-level data is suppressed for 100% of queries where cohort size is below 10 — verified by unit tests covering all analytics query paths.
- **SC-007**: Score trajectory data for a user with 5+ completed assessments is returned within the defined response time SLA at the 95th percentile under concurrent load — verified by a staging load test.
- **SC-008**: The AI response filter blocks 100% of test cases containing known prohibited patterns (instrument scores, diagnostic terms, urgency language) in a regression test suite of at least 50 test cases per category.
- **SC-009**: Cohen's kappa computed by the system matches a manual reference calculation for the same input within ±0.001 — verified by a unit test with a published reference dataset.
- **SC-010**: The platform sustains 1,000 concurrent users with p95 chat response time under 500ms and p95 workbench response time under 1,000ms, with an error rate below 0.1% — verified by a staged load test.
- **SC-011**: Infrastructure autoscaling adds capacity within 30 seconds of a load spike — verified by a load test that measures time from threshold crossing to additional capacity availability.

---

## Assumptions

- The authentication service and session service are already deployed in split-repository form. This spec adds capabilities on top of existing infrastructure — it does not replace any component.
- The Dialogflow CX agent is live (per MTB-707) but undocumented. Assessment data schema (US-3) can be validated with seeded test data before CX flows are built.
- The workbench survey schema (MTB-405, MTB-446, MTB-583, MTB-606 — all Done) provides the data-type and schema layer. The clinical assessment tables (US-3) are distinct from workbench survey tables and must be created as a separate migration.
- Invite codes encode organisation and optional role category only — encoding additional metadata in codes is out of scope.
- The scoring key hash mechanism (FR-015) is implemented using SHA-256 of the instrument version's scoring key JSON at time of computation.
- "Fail open" for AI context injection (FR-023) means: proceed with the session and no score context in the system prompt. It does not mean: retry the context lookup.
- The annotation and ML infrastructure (US-6) is independent of clinical taxonomy label definitions. The schema (FR-031) accommodates any label set; the label definitions themselves are therapy-gated and out of scope.

---

## Out of Scope (Therapy-Gated — Requires Clinical Team Sign-Off)

The following items require explicit sign-off from the Clinical Lead or therapy team before they can be implemented. They are **not** part of this specification:

| Item | Gating Requirement |
|------|--------------------|
| SLA threshold values (Critical ≤4h, Urgent ≤24h, Routine ≤5d) | Clinical Lead configures values in `sla_config` table — schema is in scope, values are not |
| Risk threshold values (e.g. PHQ-9 ≥20 → Critical flag) | Clinical Lead configures values in `risk_thresholds` table — schema is in scope, values are not |
| SafetyProtocolFlow content (crisis message text, resources) | Clinical governance sign-off required — infrastructure hooks are in scope, content is not |
| Severity-tiered AI response guideline content | Defines what the AI says per severity band — clinical sign-off required; filter infrastructure is in scope |
| 9-class annotation taxonomy label definitions | Codebook and Ukrainian cultural disambiguation examples — clinical sign-off required; schema is in scope |
| PHQ-9 / GAD-7 / PCL-5 / WHO-5 licensing decisions | PCL-5 path decision, WHO-5 commercial license, Ukrainian cultural adaptation sign-off — out of scope |

---

_Last updated: 2026-03-15 | Status: Draft_

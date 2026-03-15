# Data Model: Non-Therapy Technical Backlog

**Branch**: `030-non-therapy-backlog` | **Date**: 2026-03-15
**Source**: spec.md Key Entities + research.md design decisions

---

## Entity Relationship Summary

```
User ─────────────────────────────────────────────────────────────────────────┐
  │ (pseudonymous_user_id only — no PII)                                       │
  │                                                                             │
  ├── ConsentRecord (versioned, one per consent event)                          │
  ├── CohortMembership → Cohort (org-level grouping)                           │
  ├── AssessmentSession → AssessmentItem[] + AssessmentScore (append-only)     │
  ├── AssessmentSchedule (next trigger + deferral count)                       │
  ├── RiskFlag (Critical always-new; Urgent deduped)                           │
  └── (via separate instance) IdentityMapping (auth SA only)                  │
                                                                               │
IdentityMapping (separate Cloud SQL instance)                                  │
  └── auth_credential_hash → pseudonymous_user_id                             │
                                                                               │
Annotation → Transcript → Session ────────────────────────────────────────────┘
  └── AnnotationPair → KappaResult
```

---

## Tables

### `users` (redesigned — FR-001)

| Column | Type | Constraints | Notes |
|--------|------|------------|-------|
| pseudonymous_user_id | UUID | PK, NOT NULL | Generated server-side; UUID v4; no sequential IDs |
| salt | BYTEA | NOT NULL | Per-user salt; stored only here, never in operational tables |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | |
| deleted_at | TIMESTAMPTZ | NULLABLE | Soft-delete timestamp; set by erasure cascade |

**Rules**: No PII columns. No name, email, phone, device_id columns permitted. `salt` is stored here (not in identity map) because it is needed for pseudonym generation, not for identity resolution.

---

### `user_identity_map` (separate Cloud SQL instance — FR-002)

| Column | Type | Constraints | Notes |
|--------|------|------------|-------|
| identity_map_id | UUID | PK, NOT NULL | |
| auth_credential_hash | TEXT | NOT NULL, UNIQUE | SHA-256 of phone hash or device UUID |
| pseudonymous_user_id | UUID | NOT NULL | FK to users.pseudonymous_user_id (cross-instance reference — enforced at app layer) |
| auth_method | ENUM | NOT NULL | `otp_phone` \| `google_oauth` \| `device_uuid` |
| created_at | TIMESTAMPTZ | NOT NULL | |
| upgraded_at | TIMESTAMPTZ | NULLABLE | Set when guest→OTP upgrade completes |
| is_active | BOOLEAN | NOT NULL, DEFAULT TRUE | Set to FALSE on upgrade; never hard-deleted (except erasure cascade) |

**Access**: Only `auth-identity-map-sa` service account has SELECT/INSERT access. Erasure cascade uses a separate short-lived role.

---

### `consent_records` (FR-008)

| Column | Type | Constraints | Notes |
|--------|------|------------|-------|
| consent_record_id | UUID | PK, NOT NULL | |
| pseudonymous_user_id | UUID | NOT NULL | FK to users |
| consent_version | TEXT | NOT NULL | e.g. `"2026-03-15"` |
| accepted_categories | JSONB | NOT NULL | Array of accepted category codes: `[1, 2, 3]` |
| method | ENUM | NOT NULL | `explicit_tap` \| `re_consent_prompt` |
| consented_at | TIMESTAMPTZ | NOT NULL | |
| revoked_at | TIMESTAMPTZ | NULLABLE | Set on revocation |

**Rules**: Append-only. Each version change creates a new record. `accepted_categories` JSONB enables partial consent (user can accept categories 1+2 without category 3).

**Category semantics** (defined by consent spec):
- Category 1: Basic session service
- Category 2: Intake data processing
- Category 3: Clinical assessment data processing

---

### `cohorts` (FR-011)

| Column | Type | Constraints | Notes |
|--------|------|------------|-------|
| cohort_id | UUID | PK, NOT NULL | |
| organisation_id | UUID | NOT NULL | FK to organisations table |
| region | TEXT | NOT NULL | e.g. `"Kyiv"` |
| role_category | TEXT | NULLABLE | e.g. `"Patrol"`, `"Investigative"` |
| invite_code | TEXT | NOT NULL, UNIQUE | 8-char uppercase alphanumeric, no O/0/I/1 |
| created_at | TIMESTAMPTZ | NOT NULL | |
| expires_at | TIMESTAMPTZ | NULLABLE | NULL = never expires |
| is_active | BOOLEAN | NOT NULL, DEFAULT TRUE | |

**Validation**: `invite_code` format enforced by `CHECK (invite_code ~ '^[A-HJ-NP-Z2-9]{8}$')`.

---

### `cohort_memberships` (FR-011, FR-012)

| Column | Type | Constraints | Notes |
|--------|------|------------|-------|
| membership_id | UUID | PK, NOT NULL | |
| pseudonymous_user_id | UUID | NOT NULL | FK to users |
| cohort_id | UUID | NOT NULL | FK to cohorts |
| joined_at | TIMESTAMPTZ | NOT NULL | |

**Rules**: No PII. `UNIQUE (pseudonymous_user_id, cohort_id)`.

**Analytics guard**: All cohort analytics queries include `WHERE (SELECT COUNT(*) FROM cohort_memberships WHERE cohort_id = c.cohort_id) >= 25`.

---

### `supervisor_cohort_assignments` (FR-027)

| Column | Type | Constraints | Notes |
|--------|------|------------|-------|
| assignment_id | UUID | PK, NOT NULL | |
| supervisor_user_id | UUID | NOT NULL | FK to users |
| cohort_id | UUID | NOT NULL | FK to cohorts |
| assigned_at | TIMESTAMPTZ | NOT NULL | |
| assigned_by | UUID | NOT NULL | FK to users (admin who made assignment) |

**Rules**: `UNIQUE (supervisor_user_id, cohort_id)`. All supervisor analytics queries filter by `WHERE cohort_id IN (SELECT cohort_id FROM supervisor_cohort_assignments WHERE supervisor_user_id = $current_user)`.

---

### `assessment_sessions` (FR-015, append-only)

| Column | Type | Constraints | Notes |
|--------|------|------------|-------|
| assessment_session_id | UUID | PK, NOT NULL | |
| pseudonymous_user_id | UUID | NOT NULL | FK to users; NULLABLE post-erasure |
| instrument_id | UUID | NOT NULL | FK to instruments table |
| session_id | UUID | NULLABLE | FK to chat sessions (null for standalone assessments) |
| administered_at | TIMESTAMPTZ | NOT NULL | When the assessment started |
| completed_at | TIMESTAMPTZ | NULLABLE | NULL if abandoned or in-progress |
| status | ENUM | NOT NULL | `in_progress` \| `completed` \| `abandoned` |

**Append-only trigger**: `enforce_append_only()` fires BEFORE UPDATE OR DELETE (see research.md R-03).
**Erasure**: `pseudonymous_user_id` set to NULL by erasure cascade; row is preserved.

---

### `assessment_items` (FR-015, append-only)

| Column | Type | Constraints | Notes |
|--------|------|------------|-------|
| item_response_id | UUID | PK, NOT NULL | |
| assessment_session_id | UUID | NOT NULL | FK to assessment_sessions |
| item_index | INTEGER | NOT NULL | 0-based position within instrument |
| item_key | TEXT | NOT NULL | Key from instrument config (e.g. `"phq9_q1"`) |
| response_value | INTEGER | NOT NULL | Numeric response (0–3 for PHQ-9/GAD-7; 0–4 for PCL-5) |
| responded_at | TIMESTAMPTZ | NOT NULL | |

**FHIR mapping**: → QuestionnaireResponse.item, linkId = item_key.

---

### `assessment_scores` (FR-015, FR-018, append-only)

| Column | Type | Constraints | Notes |
|--------|------|------------|-------|
| score_id | UUID | PK, NOT NULL | |
| assessment_session_id | UUID | NOT NULL | FK to assessment_sessions |
| instrument_type | ENUM | NOT NULL | `PHQ9` \| `GAD7` \| `PCL5` \| `WHO5` |
| total_score | INTEGER | NOT NULL | Sum of all response_values |
| severity_band | ENUM | NOT NULL | `minimal` \| `mild` \| `moderate` \| `moderately_severe` \| `severe` |
| instrument_version | TEXT | NOT NULL | Version string from instrument config |
| computed_at | TIMESTAMPTZ | NOT NULL | |
| scoring_key_hash | TEXT | NOT NULL | SHA-256 of the instrument version's scoring key JSON |

**FHIR mapping**: → Observation with LOINC code per instrument_type (see research.md R-08).

---

### `score_trajectories` (materialised view — FR-016)

| Column | Type | Notes |
|--------|------|-------|
| pseudonymous_user_id | UUID | |
| instrument_type | ENUM | |
| total_score | INTEGER | Current assessment score |
| administered_at | TIMESTAMPTZ | |
| rolling_30d_mean | NUMERIC | Rolling 30-day mean score |
| rci | NUMERIC | Reliable Change Index vs prior score (Jacobson-Truax) |
| clinically_meaningful_improvement | BOOLEAN | True if delta meets CMI threshold |

**Refresh**: `REFRESH MATERIALIZED VIEW CONCURRENTLY score_trajectories` via pg_cron every 15 minutes.
**Unique index required**: `(pseudonymous_user_id, instrument_type, administered_at)` for CONCURRENTLY refresh.

---

### `assessment_schedule` (FR-019)

| Column | Type | Constraints | Notes |
|--------|------|------------|-------|
| schedule_id | UUID | PK, NOT NULL | |
| pseudonymous_user_id | UUID | NOT NULL | FK to users |
| instrument_type | ENUM | NOT NULL | |
| next_trigger_at | TIMESTAMPTZ | NOT NULL | Set by adaptive interval logic |
| deferral_count | INTEGER | NOT NULL, DEFAULT 0 | Incremented on user deferral |
| scheduler_paused | BOOLEAN | NOT NULL, DEFAULT FALSE | Admin or clinical lead can pause |
| last_severity_band | ENUM | NULLABLE | Band from most recent completed assessment |
| cloud_task_name | TEXT | NULLABLE | Cloud Tasks task name for cancellation |

---

### `risk_thresholds` (FR-020)

| Column | Type | Constraints | Notes |
|--------|------|------------|-------|
| threshold_id | UUID | PK, NOT NULL | |
| instrument_type | ENUM | NOT NULL | |
| threshold_type | ENUM | NOT NULL | `absolute` \| `deterioration` \| `item_response` |
| threshold_value | JSONB | NOT NULL | Type-specific: `{"score": 20}` or `{"delta": -5}` or `{"item_index": 8, "min_value": 1}` |
| tier | ENUM | NOT NULL | `critical` \| `urgent` \| `routine` |
| configured_by | UUID | NOT NULL | FK to users (clinical lead) |
| configured_at | TIMESTAMPTZ | NOT NULL | |
| effective_from | TIMESTAMPTZ | NOT NULL | Applies only to assessments administered AFTER this timestamp |

**Rules**: New threshold inserts are append-only. Queries use `WHERE effective_from <= assessment.administered_at` to apply correct threshold per assessment.

---

### `risk_flags` (updated — FR-021)

| Column | Type | Constraints | Notes |
|--------|------|------------|-------|
| flag_id | UUID | PK, NOT NULL | |
| pseudonymous_user_id | UUID | NOT NULL | FK to users |
| tier | ENUM | NOT NULL | `critical` \| `urgent` \| `routine` |
| trigger_reason | TEXT | NOT NULL | Human-readable reason |
| trigger_source | ENUM | NOT NULL | `score_threshold` \| `item_response` \| `ai_filter` \| `deterioration` |
| created_at | TIMESTAMPTZ | NOT NULL | |
| acknowledged_at | TIMESTAMPTZ | NULLABLE | |
| resolved_by | UUID | NULLABLE | FK to users (supervisor) |
| resolved_at | TIMESTAMPTZ | NULLABLE | |
| status | ENUM | NOT NULL, DEFAULT 'open' | `open` \| `acknowledged` \| `resolved` |

**Deduplication rule** (enforced at service layer):
- `urgent` tier: `UPDATE ... SET trigger_reason = ..., updated_at = NOW() WHERE pseudonymous_user_id = $uid AND tier = 'urgent' AND status = 'open'` if exists; else INSERT.
- `critical` tier: Always INSERT (never deduplicate — each critical event is a distinct record).

---

### `gdpr_audit_log` (FR-028)

| Column | Type | Constraints | Notes |
|--------|------|------------|-------|
| audit_id | UUID | PK, NOT NULL | |
| event_type | ENUM | NOT NULL | `erasure_requested` \| `erasure_completed` \| `consent_revoked` \| `pii_masked` \| `data_exported` \| `pii_rejected` \| `cross_service_denied` |
| actor | TEXT | NOT NULL | Service name or `user_initiated` |
| pseudonymous_user_id_hash | TEXT | NULLABLE | SHA-256 of pseudonymous_user_id (double-hashed for audit log) |
| details | JSONB | NOT NULL | Event-specific metadata (no PII) |
| occurred_at | TIMESTAMPTZ | NOT NULL | |
| outcome | ENUM | NOT NULL | `success` \| `failure` \| `pending` |

**Retention**: Cloud Logging sink exports to Cloud Storage with 3-year retention lifecycle policy.

---

### `analytics_events` (FR-025)

| Column | Type | Constraints | Notes |
|--------|------|------------|-------|
| event_id | UUID | PK, NOT NULL | |
| event_type | ENUM | NOT NULL | `session_start` \| `session_end` \| `message_sent` \| `assessment_completed` \| `assessment_abandoned` \| `flag_created` \| `flag_resolved` \| `review_submitted` |
| pseudonymous_user_id | UUID | NULLABLE | FK to users; nullable post-erasure |
| cohort_id | UUID | NULLABLE | FK to cohorts |
| occurred_at | TIMESTAMPTZ | NOT NULL | |
| metadata | JSONB | NOT NULL | Event-specific fields (no PII) |

---

### `annotations` (FR-031)

| Column | Type | Constraints | Notes |
|--------|------|------------|-------|
| annotation_id | UUID | PK, NOT NULL | |
| transcript_id | UUID | NOT NULL | FK to transcripts table |
| message_id | UUID | NULLABLE | FK to specific message (null for session-level annotations) |
| annotator_id | UUID | NOT NULL | FK to users (annotator's pseudonymous ID) |
| label_category | TEXT | NOT NULL | From taxonomy (values are therapy-gated — schema is agnostic) |
| confidence | NUMERIC(3,2) | NOT NULL | 0.00–1.00 |
| rationale | TEXT | NULLABLE | Free-text justification |
| submitted_at | TIMESTAMPTZ | NOT NULL | |
| adjudicated_label | TEXT | NULLABLE | Set post-adjudication |
| is_ground_truth | BOOLEAN | NOT NULL, DEFAULT FALSE | |
| is_visible_to_peers | BOOLEAN | NOT NULL, DEFAULT FALSE | Set to TRUE only after all annotators for this transcript have submitted |

**Blinding enforcement**: `is_visible_to_peers = FALSE` until all annotators submit. All peer-label queries include `WHERE is_visible_to_peers = TRUE`.

---

### `sampling_runs` (FR-032)

| Column | Type | Constraints | Notes |
|--------|------|------------|-------|
| run_id | UUID | PK, NOT NULL | |
| run_at | TIMESTAMPTZ | NOT NULL | |
| random_seed | TEXT | NOT NULL | Logged for reproducibility |
| sample_size | INTEGER | NOT NULL | |
| stratification_config | JSONB | NOT NULL | `{flag_type, session_length, region, severity}` |
| sampled_transcript_ids | UUID[] | NOT NULL | |
| pii_redacted | BOOLEAN | NOT NULL, DEFAULT FALSE | Set to TRUE after PII redaction pass |

---

## State Transitions

### RiskFlag States

```
[created] open → acknowledged → resolved
                              ↗
[auto-escalation fires]  open (if not acknowledged within SLA)
```

### AssessmentSession States

```
[CX flow starts]   in_progress
                       │
            ┌──────────┴──────────┐
       [completed]           [user exits / timeout]
        completed                abandoned
```

### ConsentRecord

```
[user consents]  active (consented_at set, revoked_at NULL)
      │
[user revokes]  revoked (revoked_at set)
      │
[new version]   new record created (prior record retained for audit)
```

---

## Migration Execution Order

```
030-001-pseudonymous-users.sql          # Redesign users table (breaking)
030-002-consent-records.sql             # consent_records table
030-003-cohorts.sql                     # cohorts + cohort_memberships
030-004-assessment-schema.sql           # assessment_sessions/items/scores + triggers
030-005-score-trajectories.sql          # materialised view + pg_cron schedule
030-006-assessment-schedule.sql         # assessment_schedule table
030-007-risk-thresholds.sql             # risk_thresholds config table
030-008-supervisor-cohorts.sql          # supervisor_cohort_assignments
030-009-annotations.sql                 # annotations + sampling_runs
```

**Note**: Migration 030-001 is a breaking change to the `users` table. A data migration script (not schema migration) must be written separately to assign `pseudonymous_user_id` to any existing users before the schema migration runs.

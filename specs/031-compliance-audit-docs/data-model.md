# Data Model: Compliance Audit Documentation (031)

**Phase**: 1 — Design
**Date**: 2026-03-15
**Feature**: 031-compliance-audit-docs

---

## Overview

This feature produces Confluence documentation artefacts, not database entities. The "data model" here defines the **content schema** for each compliance document — the sections, tables, and fields that every page must contain, as derived from the spec requirements (FR-001 through FR-016).

---

## Entity 1: ComplianceDocument (Confluence Page)

Every compliance document page has the following structure:

### Page Header (FR-004, FR-005)
| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `title` | string | ✓ | Regulation name + "Compliance Report" |
| `version` | string | ✓ | e.g., `1.0` — increment on each update |
| `created_date` | date | ✓ | ISO 8601 |
| `last_updated` | date | ✓ | ISO 8601 — updated within 10 business days of relevant platform change |
| `owner_role` | string | ✓ | Role, not individual (e.g., "Engineering Team / DPO") |
| `review_schedule` | string | ✓ | e.g., "Quarterly — next review: 2026-06-15" |
| `scope_statement` | text | ✓ | Which components, services, data flows are in scope |
| `regulation_framework` | string | ✓ | GDPR / Clinical-HIPAA-equivalent / ISO 27001-aligned / Research Ethics |

### Sections (FR-001 through FR-009)
| Section | Content | Required |
|---------|---------|----------|
| Scope Statement | Components, services, data flows in scope | ✓ (FR-005) |
| Regulation Mapping Table | See RegulationMapping entity below | ✓ (FR-002) |
| Compliance Gap Register | See GapRegisterEntry entity below | ✓ (FR-003) |
| Change Log | Version history with change descriptions | ✓ (FR-004) |

---

## Entity 2: RegulationMapping (Table Row)

One row per regulatory article or control addressed. Forms the body of the regulation mapping table (FR-002).

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `article_control_id` | string | ✓ | e.g., `Art. 5(1)(c)`, `A.9.2.1`, `ICH E9 §7.2` |
| `obligation_description` | text | ✓ | Plain-language statement of what the regulation requires |
| `what_is_implemented` | text | ✓ | What exists in the platform to meet this obligation |
| `how_achieved` | text | ✓ | Mechanism description (FR-006): sufficient for non-technical auditor |
| `verification_artefact` | VerificationArtefact[] | ✓ | Min 1 per mapping (FR-007) |
| `data_flow_description` | text | ✓ | Which components handle data at this control point (FR-008) |
| `config_value` | string | ○ | Specific config value if control is configuration-based (FR-009) |
| `status` | enum | ✓ | `Compliant` / `Partial` / `Deferred` |

**Table columns in Confluence** (ordered for readability):
`Article/Control | Obligation | What Is Implemented | How It Is Achieved | Verification Artefact | Status`

---

## Entity 3: GapRegisterEntry (Table Row)

One row per partially-addressed or deferred obligation. Required even if empty — "No gaps" must be stated explicitly (FR-003, SC-004).

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `control_id` | string | ✓ | Reference to article/control ID from mapping table |
| `gap_description` | text | ✓ | What is missing or incomplete |
| `risk_level` | enum | ✓ | `High` / `Medium` / `Low` |
| `owner_role` | string | ✓ | Responsible role (not individual) |
| `mitigation_in_place` | text | ○ | Interim controls if any |
| `target_date` | date | ✓ | Planned remediation date (ISO 8601) |

**Table columns in Confluence**:
`Control ID | Gap Description | Risk Level | Owner | Mitigation In Place | Target Date`

---

## Entity 4: VerificationArtefact (Inline Reference)

An auditor-accessible pointer to evidence. Referenced inline in the RegulationMapping table `Verification Artefact` column (FR-007).

| Field | Type | Notes |
|-------|------|-------|
| `type` | enum | `spec-section` / `task-evidence` / `migration` / `gcp-resource` / `confluence-page` / `test-output` |
| `location` | string | Path, URL, or resource name |
| `description` | string | Brief description of what this artefact proves |

**Format by type**:
- Spec section: `` `specs/030/spec.md: FR-001` ``
- Task evidence: `` `chat-infra/evidence/T027/encryption-audit.txt` ``
- Migration: `` `chat-backend: 20260310_create_users_pseudonymous` ``
- GCP resource: `` `Cloud SQL: chat-db-dev` / `Cloud SQL: chat-identity-map-dev` ``
- Confluence page: `[PRD-1.3 GDPR Consent Screen](URL)`
- Test output: `` `chat-backend: test/integration/erasure.test.ts` ``

---

## Per-Document Content Scope

### Document 1: GDPR Compliance Report (US1, FR-013)
Mandatory articles to cover:
- Art. 5 — data minimisation, purpose limitation, storage limitation
- Art. 6/7 — lawful basis and consent
- Art. 12–15 — transparency and access rights
- Art. 17 — right to erasure (anonymisation cascade, 30-day SLA)
- Art. 25 — data protection by design
- Art. 30 — records of processing activities
- Art. 32 — security of processing
- Art. 33/34 — breach notification readiness
- Art. 35 — DPIA status

**Key artefact sources**: specs/030 FR-001 through FR-009 and FR-028; `gdpr_audit_log`; `consent_records`; erasure job evidence; PII-rejection middleware; identity map isolation

### Document 2: Clinical Data & Safety Compliance Report (US2, FR-014)
Mandatory areas:
- Minimum necessary standard (score band vs. raw score in AI context)
- Audit controls (append-only assessment data)
- Access controls (cohort-scoped RBAC, k=10 suppression)
- AI safety filtering (post-generation filter, fail-open behaviour)
- Risk flag resolution audit trail

**Key artefact sources**: specs/030 FR-015 through FR-027; `assessment_sessions`/`assessment_scores` tables; AI safety layer evidence

### Document 3: ISO 27001-aligned Security Controls Report (US3, FR-015)
Mandatory Annex A controls:
- A.9 — access control (identity map SA, instance-scoped IAM)
- A.10 — cryptography (at-rest encryption, per-user salt)
- A.12.4 — logging (Cloud Logging sink, 3-year retention)
- A.14 — secure development (append-only triggers, PII-rejection middleware)
- A.18 — compliance mapping

**Key artefact sources**: `chat-infra/evidence/T027/encryption-audit.txt`; Cloud SQL configs; Cloud Logging retention; IAM bindings

### Document 4: Research Ethics & IRR Report (US4, FR-016)
Mandatory areas:
- Annotation blinding methodology
- Cohen's κ and Fleiss' κ (weighted variants, bootstrap CI)
- Model performance metrics (F-beta with β=4.47 cost asymmetry)
- Transcript sampling pipeline (stratified, PII redaction, deterministic seed)

**Key artefact sources**: specs/030 FR-030 through FR-034; `annotations` table schema; kappa computation spec

---

## State Transitions

Compliance documents follow a simple lifecycle:
```
Draft → Published → Under Review → Updated
                         ↑              ↓
                         └──────────────┘ (quarterly cycle)
```

- **Draft**: Content authored but not yet published to Confluence
- **Published**: Live Confluence page, version 1.0+
- **Under Review**: Quarterly review in progress
- **Updated**: New version published post-review or post-platform-change

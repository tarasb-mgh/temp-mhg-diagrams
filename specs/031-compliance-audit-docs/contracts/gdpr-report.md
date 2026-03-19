# Content Contract: GDPR Compliance Report

**Target Confluence Page**: "GDPR Compliance Report"
**Parent**: Compliance Documentation
**Space**: UD (User Documentation)
**Format**: Markdown

---

## Page Content Template

```markdown
# GDPR Compliance Report

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Created** | 2026-03-15 |
| **Last Updated** | 2026-03-15 |
| **Owner Role** | Engineering Team (technical record) / DPO (review) |
| **Review Schedule** | Quarterly — next review: 2026-06-15 |
| **Regulation** | Regulation (EU) 2016/679 — General Data Protection Regulation |
| **Primary Applicable Standard** | GDPR (EU data subjects) |

---

## Scope Statement

This document covers the processing of personal data by the MentalHelpGlobal (MHG) platform as it relates to GDPR obligations. In scope: the chat session service, assessment data pipeline, analytics service, consent management system, GDPR audit log, and the identity map isolation architecture. Out of scope: third-party processors (Google Cloud Platform, Dialogflow CX) — covered by Google's own compliance artefacts and BAAs.

All user data is processed in a pseudonymous form. A `pseudonymous_user_id` (UUID v4) is used across all operational systems. The mapping between authentication credentials and `pseudonymous_user_id` is held exclusively in an isolated Cloud SQL instance (`chat-identity-map-dev` / `chat-identity-map-prod`) with restricted access.

---

## Regulation-to-Implementation Mapping

| Article/Control | Obligation | What Is Implemented | How It Is Achieved | Verification Artefact | Status |
|---|---|---|---|---|---|
| Art. 5(1)(c) — Data minimisation | Collect only personal data adequate, relevant and limited to what is necessary | Pseudonymous UUID schema — no PII columns in operational tables (`sessions`, `assessment_scores`, `risk_flags`, `user_intake`) | `users` table stores only `pseudonymous_user_id` (UUID v4), server-side generated. PII-rejection middleware (regex pattern matching) rejects any API input resembling email, phone, or name-length strings with 400 Bad Request | `specs/030-non-therapy-technical-backlog/spec.md: FR-001, FR-004`; Cloud SQL: `chat-db-dev` schema inspection | Compliant |
| Art. 5(1)(b) — Purpose limitation | Personal data collected for specified, explicit and legitimate purposes | Assessment data stored per instrument type with explicit `instrument_type` and `session_id` foreign keys; no repurposing outside clinical and analytics workflows | Append-only `assessment_sessions`, `assessment_items`, `assessment_scores` tables with trigger-enforced no UPDATE/DELETE. Data flows: session service → assessment service → analytics only | `specs/030-non-therapy-technical-backlog/spec.md: FR-015` | Compliant |
| Art. 5(1)(e) — Storage limitation | Not kept longer than necessary | Soft-delete pattern with `deleted_at`; GDPR erasure cascade de-identifies data within 24 hours of request (30-day legal max) | Erasure cascade: async job deletes identity_map entry → nullifies FK references in all tables → sets `deleted_at`. Assessment data is anonymised (UUID nullified), not hard-deleted, preserving aggregate integrity | `specs/030-non-therapy-technical-backlog/spec.md: FR-003`; `chat-infra/evidence/T027/` | Compliant |
| Art. 6 / Art. 7 — Lawful basis and consent | Processing must have a lawful basis; consent must be freely given, specific, informed, unambiguous | `consent_records` table stores per-user consent per category with version, timestamp, and method | Consent is recorded at onboarding via explicit consent screen (PRD-1.3). Three consent categories enforced at API layer: category 1 by session service, category 2 by intake API, category 3 by assessment API. No DB write before consent affirmation | `specs/030-non-therapy-technical-backlog/spec.md: FR-008, FR-009, FR-010`; [PRD-1.3 GDPR Consent Screen](https://mentalhelpglobal.atlassian.net/wiki/spaces/UD/pages/10190849) | Compliant |
| Art. 12–15 — Transparency and access rights | Data subjects have rights to information, access, rectification, and to receive data | GDPR audit log dashboard exposes audit trail; consent revocations, PII mask events, and export audit trail are queryable by admin role | `gdpr_audit_log` captures: erasure requests, consent revocations, PII mask events, data export events. Admin dashboard queries this log. CSV export available for DPA submissions | `specs/030-non-therapy-technical-backlog/spec.md: FR-028, FR-029`; [PRD-3.8 GDPR Audit Log Dashboard](https://mentalhelpglobal.atlassian.net/wiki/spaces/UD/pages/10420250) | Compliant |
| Art. 17 — Right to erasure | Data subjects have the right to erasure ("right to be forgotten") | Erasure cascade: anonymisation of all pseudonymous data linked to a user, completed within 24 hours | **Anonymisation approach (not hard deletion)**: identity_map entry deleted → all FK references to `pseudonymous_user_id` nullified across operational tables → `deleted_at` soft-delete set. Assessment data rows remain (with nullified FK) for aggregate statistical integrity. SLA: 24-hour internal, 30-day legal maximum. Erasure events written to `gdpr_audit_log` | `specs/030-non-therapy-technical-backlog/spec.md: FR-003`; `gdpr_audit_log` table | Compliant |
| Art. 25 — Data protection by design | Privacy by design and by default | Pseudonymous architecture enforced at schema level; identity isolation; PII-rejection middleware | UUID-based schema means PII is structurally excluded. Identity map in separate DB instance with restricted SA access. PII-rejection middleware rejects PII at ingress before any DB write | `specs/030-non-therapy-technical-backlog/spec.md: FR-001, FR-002, FR-004`; GCP: `chat-identity-map-dev` Cloud SQL instance | Compliant |
| Art. 30 — Records of processing activities | Controller must maintain a record of processing activities | This Compliance Report constitutes the Art. 30 record for the MHG platform | Document covers: purposes of processing, categories of data subjects and data, recipients, transfers, retention periods, and security measures. Updated within 10 business days of relevant platform changes | This document | Compliant |
| Art. 32 — Security of processing | Implement appropriate technical and organisational measures | At-rest encryption, TLS in transit, RBAC, audit logging, and pseudonymous architecture | Cloud SQL encryption at rest (Google-managed AES-256 confirmed — `diskEncryptionConfiguration` field absent = Google-managed active). TLS enforced on all Cloud Run services. RBAC via `supervisor_cohort_assignments` table and 403 enforcement at API layer. 3-year audit log retention in Cloud Logging | `chat-infra/evidence/T027/encryption-audit.txt`; Cloud Logging retention config; `specs/030-non-therapy-technical-backlog/spec.md: FR-006, FR-007` | Compliant |
| Art. 33/34 — Breach notification readiness | Report personal data breaches to supervisory authority within 72 hours | `gdpr_audit_log` captures security events; alert thresholds on erasure SLA (30-day) | Log-based alerts in Cloud Logging can be configured for anomalous access patterns. Erasure SLA alert fires if request exceeds 30-day window. Breach notification procedure: owner-driven, using audit log as primary evidence source | `specs/030-non-therapy-technical-backlog/spec.md: FR-028`; Cloud Logging: `gdpr_audit_log` | Partial |
| Art. 35 — Data Protection Impact Assessment | High-risk processing requires DPIA | DPIA not yet formally completed; platform characteristics assessed against Art. 35(3) triggers | Assessment data (health data under Art. 9) and systematic monitoring trigger Art. 35. DPIA is in scope for the DPO to complete as a governance artefact; this technical record provides the implementation evidence required as DPIA input | N/A — governance artefact | Deferred |

---

## Compliance Gap Register

| Control ID | Gap Description | Risk Level | Owner | Mitigation In Place | Target Date |
|---|---|---|---|---|---|
| Art. 33/34 | Formal breach notification runbook not documented; alert configuration for anomalous Cloud SQL access not yet set up | Medium | Engineering Team | `gdpr_audit_log` captures all data events; manual review process in place | 2026-04-30 |
| Art. 35 | Formal DPIA not completed — required for health data processing and systematic monitoring under Art. 35(3)(b)(c) | High | DPO | This technical record provides DPIA input evidence; processing already implements PbD (Art. 25) | 2026-06-01 |
| Art. 32 | IAM deny policy for `chat-identity-map-dev` pending `iam.denyAdmin` grant to enable cross-service access restriction | Medium | Infrastructure Team | Identity map SA access restricted by VPC and IAM role conditions; deny policy adds defence-in-depth | 2026-04-01 |

---

## Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-03-15 | Engineering Team | Initial publication |
```

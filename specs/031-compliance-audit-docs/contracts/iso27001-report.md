# Content Contract: ISO 27001-aligned Security Controls Report

**Target Confluence Page**: "ISO 27001-aligned Security Controls Report"
**Parent**: Compliance Documentation
**Space**: UD (User Documentation)
**Format**: Markdown

---

## Page Content Template

```markdown
# ISO 27001-aligned Security Controls Report

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Created** | 2026-03-15 |
| **Last Updated** | 2026-03-15 |
| **Owner Role** | Engineering Team (technical record) / Information Security Lead (review) |
| **Review Schedule** | Quarterly — next review: 2026-06-15 |
| **Standard** | ISO/IEC 27001:2022 Annex A (applied as equivalent-standard framework) |
| **Note** | The platform is not ISO 27001 certified. These controls are implemented to ISO 27001 Annex A equivalent standard as required by enterprise client and NHS/HSE procurement frameworks. Formal certification is out of scope for this document. |

---

## Scope Statement

This document covers the technical and organisational security controls implemented for the MHG platform. In scope: GCP infrastructure (Cloud SQL, Cloud Run, Cloud Logging, Secret Manager, IAM), application-layer security controls (RBAC, HTTPS enforcement, PII-rejection middleware, append-only triggers), and the identity isolation architecture. Out of scope: physical security (Google Cloud data centre controls covered by Google's compliance artefacts), third-party processor security (Dialogflow CX).

---

## Regulation-to-Implementation Mapping

| Annex A Control | Obligation | What Is Implemented | How It Is Achieved | Verification Artefact | Status |
|---|---|---|---|---|---|
| A.9.1 — Access control policy | Establish, document, and review access control rules | RBAC via `supervisor_cohort_assignments` table; role-gated API endpoints | All API endpoints enforce role-based access at the route level (not UI-only). Supervisor endpoints include cohort scope guard. Admin endpoints restricted to `admin` role. 403 returned on violation — not 404 | `specs/030-non-therapy-technical-backlog/spec.md: FR-027` | Compliant |
| A.9.2 — Identity management | Manage user access throughout identity lifecycle | Pseudonymous identity with separate Cloud SQL identity map | `user_identity_map` stored in dedicated `chat-identity-map-dev` Cloud SQL instance with a dedicated service account (SA). Only the auth service SA has SELECT on the identity map. No operational service can resolve UUID → credentials directly | `specs/030-non-therapy-technical-backlog/spec.md: FR-002, FR-005`; GCP: `chat-identity-map-dev`; Cloud SQL IAM bindings | Partial |
| A.9.4 — Access control for systems and applications | Prevent unauthorised access to systems and applications | Service-account-based access; instance-scoped IAM condition; VPC-level firewall | `chat-identity-map-dev` Cloud SQL instance uses a dedicated SA with instance-scoped IAM condition (`resource.name` matches). IAM deny policy (defence-in-depth layer) pending `iam.denyAdmin` grant — see gap register | `chat-infra/evidence/T027/encryption-audit.txt`; IAM policy audit | Partial |
| A.10.1 — Cryptographic controls | Implement appropriate cryptographic controls | At-rest encryption on all Cloud SQL instances; per-user cryptographic salt | All Cloud SQL instances (`chat-db-dev`, `chat-identity-map-dev`) use Google-managed AES-256 encryption at rest. Confirmed: `diskEncryptionConfiguration` field absent in describe output = Google-managed encryption active (CMEK field only present when customer-managed key is configured). Per-user salt used for auth credential hashing | `chat-infra/evidence/T027/encryption-audit.txt` — "Passed: 2 (Google-managed encryption confirmed on both instances)" | Compliant |
| A.10.2 — Key management | Manage cryptographic keys | Google-managed key lifecycle for at-rest encryption; no CMEK at this time | Google Cloud manages key rotation and lifecycle for Google-managed AES-256. CMEK not implemented at this stage — Google-managed keys satisfy the equivalent-standard requirement for the current scale. CMEK is a gap register item for future enterprise client requirements | `chat-infra/evidence/T027/encryption-audit.txt` | Compliant |
| A.12.4 — Logging and monitoring | Record events and produce evidence | Cloud Logging sink capturing all platform events; 3-year retention; GDPR audit log | Cloud Logging configured with minimum 3-year retention for `gdpr_audit_log` events. All 8 analytics events (session_start, session_end, message_sent, assessment_completed, assessment_abandoned, flag_created, flag_resolved, review_submitted) are instrumented and flow to the analytics store | `specs/030-non-therapy-technical-backlog/spec.md: FR-006, FR-025`; Cloud Logging retention config | Compliant |
| A.12.6 — Technical vulnerability management | Identify and remediate technical vulnerabilities | OWASP-aligned security audit completed 2026-03-12; findings tracked | Security audit (mhg.security-audit skill v1.0.0) mapped findings to OWASP Top 10, OWASP API Security Top 10, and OWASP ASVS Level 1. Findings tracked in Confluence Security Audits section | [Security Audit 2026-03-12](https://mentalhelpglobal.atlassian.net/wiki/spaces/UD/pages/21463041) | Compliant |
| A.14.1 — Security in development | Information security requirements included in development | Spec-first development with security requirements in spec.md; constitution mandates privacy-first | All features begin with a specification that includes security/privacy requirements. PII-rejection middleware deployed as a cross-cutting control. Append-only triggers enforce data integrity at DB layer | `specs/030-non-therapy-technical-backlog/spec.md: FR-004, FR-015`; constitution principle V | Compliant |
| A.14.2 — Security in development — PII controls | Prevent PII from entering the system | PII-rejection middleware on all API inputs | Regex-based middleware checks all incoming API requests for patterns matching email, phone (UA format), and name-length strings. Returns 400 Bad Request on match. Runs before any DB write | `specs/030-non-therapy-technical-backlog/spec.md: FR-004` | Compliant |
| A.14.3 — Test data protection | Test data must not contain production data | Pseudonymous architecture prevents PII in test data | UUID-based schema means there is no PII to leak from test data. Test fixtures use UUID v4 values. Annotation pipeline applies PII auto-redaction before transcript export to annotators | `specs/030-non-therapy-technical-backlog/spec.md: FR-032` | Compliant |
| A.18.1 — Compliance with legal requirements | Identify legal requirements; implement controls | GDPR compliance documented (cross-reference); regulatory mapping maintained | This document cross-references the GDPR Compliance Report for Art. 32 overlap. Regulatory obligations mapped across GDPR, clinical standards, and research ethics in separate compliance documents | [GDPR Compliance Report](../GDPR Compliance Report) | Compliant |

---

## Cross-Reference Note

A.9 (access control) and GDPR Art. 32 (security of processing) overlap on the identity isolation and encryption controls. To avoid conflicting descriptions, the authoritative technical detail for these controls is in this ISO 27001 document. The GDPR Compliance Report cross-references here for Art. 32 evidence.

---

## Compliance Gap Register

| Control ID | Gap Description | Risk Level | Owner | Mitigation In Place | Target Date |
|---|---|---|---|---|---|
| A.9.2 / A.9.4 | IAM deny policy for `chat-identity-map-dev` not yet created — requires `iam.denyAdmin` grant to service account | Medium | Infrastructure Team | Identity map SA access restricted by VPC firewall and IAM role-based conditions; deny policy adds defence-in-depth layer | 2026-04-01 |
| A.9.4 | Cloud SQL `chat-identity-map-dev` uses public IP in dev environment (private IP reserved for prod) | Low | Infrastructure Team | Authorised networks configured; access restricted to Cloud Run service IPs. Low risk in dev; private IP mandatory for prod | 2026-06-01 (prod) |
| A.10.2 | Customer-Managed Encryption Keys (CMEK) not implemented — Google-managed keys only | Low | Engineering Team | Google-managed AES-256 satisfies equivalent-standard requirement; CMEK adds key rotation control for enterprise clients | 2026-Q4 (if required by enterprise client) |

---

## Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-03-15 | Engineering Team | Initial publication |
```

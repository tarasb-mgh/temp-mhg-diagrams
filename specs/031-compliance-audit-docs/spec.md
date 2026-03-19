# Feature Specification: Compliance Audit Documentation

**Feature Branch**: `031-compliance-audit-docs`
**Created**: 2026-03-15
**Status**: Draft
**Jira Epic**: MTB-760

---

## Published Pages

Published on 2026-03-15. All pages are in the UD (User Documentation) Confluence space.

| Title | Page ID | URL |
|---|---|---|
| Compliance Documentation (parent) | `26214401` | `/spaces/UD/pages/26214401` |
| GDPR Compliance Report | `26247169` | `/spaces/UD/pages/26247169/GDPR+Compliance+Report` |
| Clinical Data & Safety Compliance Report | `26181634` | `/spaces/UD/pages/26181634/Clinical+Data+Safety+Compliance+Report` |
| ISO 27001-aligned Security Controls Report | `26279937` | `/spaces/UD/pages/26279937/ISO+27001-aligned+Security+Controls+Report` |
| Research Ethics & Inter-Rater Reliability Report | `26181653` | `/spaces/UD/pages/26181653/Research+Ethics+Inter-Rater+Reliability+Report` |

---

## Overview

MentalHelpGlobal operates under multiple regulatory frameworks including GDPR, HIPAA-equivalent clinical data standards, ISO 27001, and research ethics guidelines (ICH E9). As a regulated solution handling sensitive mental health data, the platform must maintain exhaustive, up-to-date compliance documentation in Confluence for each applicable regulation.

These documents serve as the primary evidence artefacts for external auditors, Data Protection Authorities (DPAs), and internal governance reviews. Each document must map every regulatory obligation to a specific, verifiable implementation in the platform, providing sufficient detail for an auditor to assess conformance without requiring access to source code.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 — GDPR Compliance Report (Priority: P1)

An external Data Protection Authority auditor or DPO reviews the GDPR compliance document in Confluence to assess whether the platform's processing of personal data (pseudonymous mental health data) meets the obligations of the GDPR. The document must be self-contained — the auditor should be able to reach a conformance determination without requesting additional evidence, as all artefact references are embedded or linked.

**Why this priority**: GDPR is the primary regulatory framework governing the platform. Any DPA investigation, subject access request dispute, or erasure request challenge would begin here. A missing or incomplete GDPR report represents the highest legal and reputational risk.

**Independent Test**: The GDPR report is publishable as a standalone Confluence page. A reviewer unfamiliar with the codebase can read it and identify, for each GDPR article addressed, (a) what the obligation is, (b) what is implemented to meet it, and (c) where the implementation evidence resides.

**Acceptance Scenarios**:

1. **Given** an auditor opens the GDPR compliance page, **When** they navigate to the Right to Erasure section, **Then** they can read the erasure cascade process, the 30-day SLA commitment, the anonymisation approach (not deletion), the audit trail mechanism, and a reference to the erasure job evidence — without needing to ask any follow-up questions.

2. **Given** a new GDPR article is addressed in a platform update, **When** the compliance document is updated, **Then** the article appears in the document with implementation details and a cross-reference to the relevant spec or task evidence.

3. **Given** an auditor asks for evidence of data minimisation, **When** they consult the GDPR document, **Then** they find a description of the pseudonymous UUID schema, the PII-rejection middleware, and the absence of PII columns — each linked to a verifiable artefact.

---

### User Story 2 — Clinical Data & Safety Compliance Report (Priority: P1)

A clinical governance lead or external clinical auditor reviews the clinical data compliance document to assess whether the platform meets HIPAA-equivalent standards for handling sensitive mental health assessment data, including data access controls, audit trails, and the AI safety filtering layer.

**Why this priority**: The platform processes PHQ-9, GAD-7, PCL-5, and WHO-5 assessment data and routes risk flags to clinical supervisors. Clinical data mishandling or inadequate access controls carry direct patient safety implications and regulatory sanctions.

**Independent Test**: A clinical governance reviewer can read the document and verify that assessment data is stored append-only, that score data never reaches the AI model as raw numbers, and that risk flag resolution has a documented audit trail — each with a reference to the implementation.

**Acceptance Scenarios**:

1. **Given** a clinical auditor reviews the AI safety section, **When** they read the score context injection description, **Then** they find a clear statement that only severity band labels (not numeric scores) reach the AI model, the fail-open behaviour on timeout, and the session-level caching mechanism.

2. **Given** an auditor reviews data access controls, **When** they check the RBAC section, **Then** they find the supervisor cohort assignment model, the 403 enforcement at the API layer, and the k=10 anonymity suppression rule — each with its test evidence reference.

---

### User Story 3 — Information Security (ISO 27001-aligned) Compliance Report (Priority: P2)

An information security auditor reviews the ISO 27001-aligned security controls document to assess whether the platform's technical and organisational security measures are adequate for handling sensitive health data at scale.

**Why this priority**: ISO 27001 alignment is increasingly required by enterprise clients and NHS/HSE procurement frameworks. The document supports both internal ISMS reviews and client due diligence questionnaires.

**Independent Test**: A security auditor can read the document and identify the control implemented for each applicable ISO 27001 Annex A domain, with a reference to the verification evidence.

**Acceptance Scenarios**:

1. **Given** an auditor reviews access control (A.9), **When** they check the identity map section, **Then** they find the separate Cloud SQL instance, the dedicated service account with instance-scoped IAM condition, and the IAM deny policy status.

2. **Given** an auditor reviews cryptography (A.10), **When** they check the encryption section, **Then** they find the at-rest encryption status for each Cloud SQL instance and the per-user cryptographic salt mechanism.

---

### User Story 4 — Inter-Rater Reliability & Research Ethics Report (Priority: P3)

A research ethics board reviewer or ML auditor reviews the annotation and model quality documentation to assess whether the inter-rater reliability methodology, model performance metrics, and bias controls meet research ethics standards (ICH E9 / GCP).

**Why this priority**: The annotation pipeline and kappa metrics feed directly into clinical AI model validation. A weakness here would undermine the scientific validity of the model's deployment in a mental health context.

**Independent Test**: A research reviewer can read the document and verify that kappa computation methodology is described with reference values, that bootstrap CI methodology is documented, and that model performance metrics use clinically appropriate cost asymmetry.

**Acceptance Scenarios**:

1. **Given** a reviewer examines the IRR methodology, **When** they read the kappa section, **Then** they find the Cohen 1960 reference dataset, the weighted kappa methodology, the 1,000-iteration bootstrap CI approach, and the κ < 0.6 alert threshold rationale.

---

### Edge Cases

- A regulatory article is partially addressed — the document must clearly state what is implemented, what is deferred, and the planned timeline for full coverage rather than omitting the article.
- An implementation detail changes after the document is published — the document must include a version/last-updated date and a change log so auditors can assess currency.
- Two regulations overlap on the same control (e.g., GDPR Art. 32 and ISO 27001 A.10 both address encryption) — the document must cross-reference rather than duplicate, avoiding conflicting descriptions.
- A previously documented control is found to be incomplete (e.g., IAM deny policy pending `iam.denyAdmin` grant) — the document must record the gap, the risk assessment, and the remediation plan with a target date.

---

## Requirements *(mandatory)*

### Functional Requirements

**Document Structure**

- **FR-001**: Each compliance document MUST cover exactly one regulatory framework (GDPR, Clinical/HIPAA-equivalent, ISO 27001-aligned, Research Ethics) and be published as a distinct Confluence page under the MHG Compliance space.
- **FR-002**: Each document MUST contain a regulation-to-implementation mapping table: regulation article/control → what is implemented → how it is achieved → verification evidence reference.
- **FR-003**: Each document MUST include a compliance gap register listing any partially-addressed or deferred obligations, with risk level, owner, and target remediation date.
- **FR-004**: Each document MUST carry a version number, creation date, last-updated date, and a named document owner (role, not individual).
- **FR-005**: Each document MUST include a scope statement defining which components, services, and data flows are in scope for that regulation.

**Content Depth**

- **FR-006**: For each regulatory obligation addressed, the document MUST describe the specific implementation mechanism in plain language sufficient for a non-technical auditor to understand the control without reading source code.
- **FR-007**: For each control, the document MUST reference at least one verifiable artefact (spec section, task evidence file, migration name, Cloud Run service name, GCP resource name, or test output) that an auditor can use to independently verify the claim.
- **FR-008**: The document MUST describe the data flow relevant to each control — identifying which system components handle the data and at which points the control applies.
- **FR-009**: Where a control relies on a configuration (e.g., Cloud SQL encryption, Cloud Run autoscaling, Redis session keys), the document MUST state the specific configuration value and where it is set.

**Maintenance**

- **FR-010**: The document MUST be updated within 10 business days whenever a relevant platform change is deployed to production that affects a documented control.
- **FR-011**: The compliance gap register MUST be reviewed and updated at the start of each sprint cycle.
- **FR-012**: Each document MUST include a review schedule (minimum: quarterly) and record the date of the most recent review.

**Coverage — GDPR**

- **FR-013**: The GDPR document MUST address: Art. 5 (data minimisation, purpose limitation, storage limitation), Art. 6/7 (lawful basis and consent), Art. 12–15 (transparency and access rights), Art. 17 (erasure), Art. 25 (data protection by design), Art. 30 (records of processing), Art. 32 (security), Art. 33/34 (breach notification readiness), Art. 35 (DPIA status).

**Coverage — Clinical/HIPAA-equivalent**

- **FR-014**: The clinical data document MUST address: minimum necessary standard (score band vs. raw score in AI context), audit controls (append-only assessment data), access controls (cohort-scoped RBAC, k=10 suppression), AI safety filtering (post-generation filter, fail-open behaviour), and risk flag resolution audit trail.

**Coverage — ISO 27001-aligned**

- **FR-015**: The ISO 27001 document MUST address applicable Annex A controls: A.9 (access control — identity map SA, instance-scoped IAM), A.10 (cryptography — at-rest encryption, per-user salt), A.12.4 (logging — Cloud Logging sink, 3-year retention), A.14 (secure development — append-only triggers, PII-rejection middleware), A.18 (compliance — regulatory mapping).

**Coverage — Research Ethics**

- **FR-016**: The research ethics document MUST address: annotation blinding methodology, inter-rater reliability computation (Cohen's κ, Fleiss' κ, weighted variants, bootstrap CI), model performance metrics methodology (F-beta with cost asymmetry rationale), and transcript sampling pipeline controls (stratified sampling, PII redaction, deterministic seed).

### Key Entities

- **ComplianceDocument**: Confluence page per regulation — version, owner role, last reviewed, scope statement, regulation mapping table, gap register, change log.
- **RegulationMapping**: Row in the mapping table — regulation article/control ID, obligation description, implementation description, how achieved, verification artefact reference, status (Compliant / Partial / Deferred).
- **GapRegisterEntry**: Identified gap — control ID, gap description, risk level (High/Medium/Low), owner (role), target date, mitigation in place.
- **VerificationArtefact**: A referenced piece of evidence — type (spec section / task evidence / migration / GCP resource / test output), location (Confluence link, file path, or GCP resource name), last verified date.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All four compliance documents (GDPR, Clinical, ISO 27001, Research Ethics) are published in Confluence within the MHG Compliance space and accessible to any authenticated team member.
- **SC-002**: Each document covers 100% of the regulatory obligations listed in FR-013 through FR-016 — no article or control is omitted without a gap register entry explaining the omission.
- **SC-003**: Every regulation-to-implementation mapping entry includes at least one verifiable artefact reference that an auditor can locate and inspect independently.
- **SC-004**: The gap register for each document lists all known partial implementations with a risk level and a target remediation date — zero gaps are left without an owner or timeline.
- **SC-005**: An external auditor unfamiliar with the platform can determine, for any given regulatory obligation, whether it is met — without requesting additional documentation — in under 10 minutes per obligation.
- **SC-006**: Documents are updated within 10 business days of any production deployment that changes a documented control, as evidenced by the last-updated date on the Confluence page.
- **SC-007**: All four documents pass an internal peer review (by a second team member not involved in writing) before publication, with no major factual errors found post-publication by an external reviewer.

---

## Assumptions

- The Confluence space and MHG project are already accessible via the Atlassian MCP integration.
- The compliance documents are authored by the engineering team and reviewed by the DPO / clinical governance lead — not authored by legal counsel (this is a technical implementation record, not a legal opinion).
- The platform operates under GDPR as the primary regulation (EU data subjects); HIPAA and ISO 27001 are applied as equivalent-standard frameworks, not as formal certifications.
- "Auditor-ready" means a document that can be submitted to a DPA or clinical governance board without redaction or supplementary explanation — all sensitive implementation details are either anonymised or presented at an appropriate abstraction level.
- The research ethics document covers the annotation and model quality pipeline only; clinical trial registration and informed consent flows are out of scope for this feature.
- Documents will be maintained as living documents — they are not point-in-time snapshots and must reflect the current state of the platform at all times.

---

## Out of Scope

- Legal opinions or formal regulatory certifications (ISO 27001 certification audit, GDPR Article 35 DPIA formal approval) — these require external bodies.
- Compliance documentation for regulations not yet applicable to the platform (e.g., EU AI Act full conformity assessment — pending 2026 applicability date).
- Compliance documentation for third-party processors (Dialogflow CX, Google Cloud Platform) — those are covered by Google's own compliance artefacts and BAAs.
- Source code or technical implementation work — this spec covers documentation only; any gaps found that require code changes are tracked in separate specs.

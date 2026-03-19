# Research: Compliance Audit Documentation (031)

**Phase**: 0 — Research & Unknowns Resolution
**Date**: 2026-03-15
**Feature**: 031-compliance-audit-docs

---

## Decision 1: Confluence Space and Page Hierarchy

**Decision**: Use the existing `UD` (User Documentation) space (ID: `8454147`). Create a new top-level "Compliance Documentation" parent page under the root "MHG Documentation" page (ID: `8454317`). All four compliance documents are created as child pages under this parent.

**Rationale**: No dedicated MHG Compliance space exists. The `UD` space hosts all project documentation including Technical Onboarding, User Manual, Security Audits, and Activity Reports. Placing compliance docs here follows the established pattern (Security Audits page ID `21430273` is also top-level under MHG Documentation). A dedicated parent page groups all four documents together and provides a single entry point for auditors.

**Alternatives considered**:
- Create a new Confluence space (e.g., "MHG Compliance") — rejected: space creation overhead, no precedent, harder to discover for existing users
- Add pages under "Technical Onboarding" — rejected: compliance docs target external auditors, not developers; wrong audience grouping
- Add pages under an existing PRD section — rejected: PRD pages are feature specs, not regulatory artefacts

**Page hierarchy**:
```
MHG Documentation (8454317)
└── Compliance Documentation  [NEW — parent page]
    ├── GDPR Compliance Report  [NEW — US1]
    ├── Clinical Data & Safety Compliance Report  [NEW — US2]
    ├── ISO 27001-aligned Security Controls Report  [NEW — US3]
    └── Research Ethics & Inter-Rater Reliability Report  [NEW — US4]
```

---

## Decision 2: Confluence Content Format

**Decision**: Use `markdown` content format for all page creation and updates via the Atlassian MCP `createConfluencePage` and `updateConfluencePage` tools.

**Rationale**: Markdown is human-readable in the plan/tasks file, simpler to author, and fully sufficient for regulation mapping tables, gap register tables, and structured text sections. ADF (Atlassian Document Format) would require complex JSON construction with no material benefit for static compliance documents. The `markdown` format renders properly in Confluence including tables.

**Alternatives considered**:
- ADF format — rejected: overly complex JSON, no benefit for this content type; reserved for pages requiring macros, mentions, or panels
- Storage format (XHTML) — not supported by MCP tools

---

## Decision 3: Regulation Mapping Table Format

**Decision**: Each compliance document uses a flat Markdown table with columns: `Article/Control | Obligation | What Is Implemented | How It Is Achieved | Verification Artefact | Status`.

**Rationale**: Flat tables render correctly in Confluence markdown format. The column structure maps directly to FR-002 requirements. Status column (Compliant / Partial / Deferred) enables gap identification at a glance. Accordion macros or nested structures are ADF-only and not needed for readability.

**Table template**:
```
| Article/Control | Obligation | What Is Implemented | How It Is Achieved | Verification Artefact | Status |
|---|---|---|---|---|---|
| Art. 5(1)(c) | Data minimisation | Pseudonymous UUID schema — no PII in operational tables | ... | specs/030: FR-001 | Compliant |
```

---

## Decision 4: Gap Register Format

**Decision**: Each document includes a `## Compliance Gap Register` section with a Markdown table: `Control ID | Gap Description | Risk Level | Owner | Mitigation In Place | Target Date`.

**Rationale**: Satisfies FR-003 (gap register mandatory), FR-004 (owner required), and SC-004 (every gap has owner + timeline). Empty gap registers (all compliant) are represented by a "No gaps identified" note — not an omitted section.

---

## Decision 5: Artefact Reference Convention

**Decision**: Verification artefacts are referenced using this hierarchy:
1. Spec section: `specs/030-non-therapy-technical-backlog/spec.md: FR-001`
2. Task evidence: `chat-infra/evidence/T027/`
3. Migration name: `chat-backend/src/db/migrations/YYYYMMDD_create_users.sql`
4. GCP resource: `Cloud SQL: chat-db-dev` / `Cloud Run: chat-backend-dev`
5. Confluence page: `[PRD-1.3 GDPR Consent Screen](https://mentalhelpglobal.atlassian.net/wiki/...)`

**Rationale**: Satisfies FR-007 (at least one verifiable artefact per control). Using spec/evidence paths ensures an auditor can trace claims to committed code and infrastructure evidence without source code access.

---

## Decision 6: Document Ownership and Versioning

**Decision**: Each document includes a standard header block:
- **Version**: 1.0
- **Created**: 2026-03-15
- **Last Updated**: 2026-03-15
- **Owner Role**: Engineering Team / DPO (review)
- **Review Schedule**: Quarterly (next review: 2026-06-15)
- **Scope**: [regulation-specific scope statement]

**Rationale**: Satisfies FR-004 (version, dates, named owner role) and FR-012 (review schedule). Owner is a role, not an individual, per spec assumption.

---

## Decision 7: No Source Code Changes Required

**Decision**: This feature produces zero source code changes. All implementation tasks consist of researching existing platform implementation, authoring Confluence page content, and publishing via MCP tools.

**Rationale**: The spec explicitly states "Source code or technical implementation work" is out of scope. The feature produces documentation artefacts only. No `chat-backend`, `chat-frontend`, or other repo branches needed.

**Implication**: No multi-repo coordination, no PRs, no CI/CD gating. Implementation is complete when all four Confluence pages are published with verified content and the gap register is populated.

---

## Known Gaps Identified During Research

The following items are expected to appear in compliance gap registers based on prior session findings:

| Gap | Regulation | Risk | Status |
|-----|-----------|------|--------|
| IAM deny policy for `chat-identity-map-dev` pending `iam.denyAdmin` grant | GDPR Art. 32 / ISO A.9 | Medium | Owner: infra, Target: 2026-04-01 |
| Cloud SQL private IP not enabled on dev (public IP with auth networks) | ISO A.9 | Low (dev only) | Owner: infra, Target: prod setup |
| IAM deny policy creation blocked pending elevated IAM permissions | ISO A.9 | Medium | Owner: owner, Target: 2026-04-01 |

---

## Atlassian MCP Tool Availability

Confirmed available tools for implementation:
- `createConfluencePage` — create new pages with parentId, spaceId, markdown body
- `updateConfluencePage` — update existing pages (for future maintenance tasks)
- `getConfluencePage` — read existing page content
- `searchConfluenceUsingCql` — verify pages exist/find pages
- `createJiraIssue` — create Epic/Story/Task
- `addCommentToJiraIssue` — log activity on Epic
- `transitionJiraIssue` — mark tasks Done

---

## Implementation Notes

- **Cloud ID**: `3aca5c6d-161e-42c2-8945-9c47aeb2966d`
- **UD Space ID**: `8454147`
- **Root page ID**: `8454317` (MHG Documentation)
- **Security Audits precedent page**: `21430273` (same level in hierarchy as new Compliance Documentation parent)
- All four compliance documents are GDPR Art. 30 Record of Processing compatible — the GDPR document itself satisfies the Art. 30 obligation

---

## Published Page IDs

All pages published on 2026-03-15.

| Title | Confluence Page ID | URL |
|---|---|---|
| Compliance Documentation (parent) | `26214401` | `/spaces/UD/pages/26214401` |
| GDPR Compliance Report | `26247169` | `/spaces/UD/pages/26247169/GDPR+Compliance+Report` |
| Clinical Data & Safety Compliance Report | `26181634` | `/spaces/UD/pages/26181634/Clinical+Data+Safety+Compliance+Report` |
| ISO 27001-aligned Security Controls Report | `26279937` | `/spaces/UD/pages/26279937/ISO+27001-aligned+Security+Controls+Report` |
| Research Ethics & Inter-Rater Reliability Report | `26181653` | `/spaces/UD/pages/26181653/Research+Ethics+Inter-Rater+Reliability+Report` |

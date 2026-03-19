# Implementation Plan: Compliance Audit Documentation

**Branch**: `031-compliance-audit-docs` | **Date**: 2026-03-15 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/031-compliance-audit-docs/spec.md`
**Jira Epic**: MTB-760

---

## Summary

Publish four regulation-specific compliance audit documents in Confluence (UD space, under a new "Compliance Documentation" parent page), each containing a regulation-to-implementation mapping table, a compliance gap register, and verifiable artefact references. The content is authored by synthesising implementation evidence from specs/030, `chat-infra` evidence files, and GCP resource configurations. No source code changes are involved — all tasks are research + authoring + Confluence MCP publishing.

---

## Technical Context

**Language/Version**: N/A — documentation-only feature
**Primary Dependencies**: Atlassian MCP (`plugin-atlassian-atlassian`) — `createConfluencePage`, `updateConfluencePage`, `addCommentToJiraIssue`
**Storage**: Confluence (UD space, ID: `8454147`, Cloud ID: `3aca5c6d-161e-42c2-8945-9c47aeb2966d`)
**Testing**: Peer review by second team member (SC-007); Confluence page accessibility to authenticated users (SC-001)
**Target Platform**: Confluence Cloud (Atlassian MCP)
**Project Type**: Documentation publication
**Performance Goals**: Auditor can determine conformance for any obligation in < 10 minutes (SC-005)
**Constraints**: Each document must be self-contained — auditor requires no follow-up requests; gap register mandatory; version tracking required
**Scale/Scope**: 4 compliance documents × ~10–15 regulation mapping entries each ≈ 50 total mapping rows

---

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Spec-First | ✓ PASS | spec.md complete, checklist passed |
| II. Multi-Repository | ✓ PASS | Documentation-only; `client-spec` is the only affected repo |
| III. Test-Aligned | ✓ PASS | No code tests required; peer review is the validation mechanism |
| IV. Branch and Integration | ✓ PASS | On feature branch `031-compliance-audit-docs`; no PR to `develop` needed (doc-only) |
| V. Privacy and Security | ✓ PASS | Compliance docs must not contain raw credentials or PII; all artefact refs use anonymised resource names |
| VI. Accessibility & i18n | N/A | Confluence pages are English; not user-facing UI |
| VII. Split-Repository First | ✓ PASS | No split-repo changes; `client-spec` only |
| VIII. GCP CLI Infra | N/A | No infrastructure changes |
| IX. Responsive UX / PWA | N/A | Not a UI feature |
| X. Jira Traceability | ✓ PASS | Epic MTB-760 created; Stories and Tasks to be created via `/speckit.tasks` |
| XI. Documentation Standards | ✓ PASS | This feature IS the documentation work; published to UD space per constitution |
| XII. Release Engineering | N/A | No deployment; Confluence publication does not trigger production deploy |

**Result: All applicable gates PASS.** No complexity violations.

---

## Project Structure

### Documentation (this feature)

```text
specs/031-compliance-audit-docs/
├── spec.md                  # Feature specification ✓
├── plan.md                  # This file ✓
├── research.md              # Phase 0 output ✓
├── data-model.md            # Phase 1 output ✓
├── contracts/               # Phase 1 output — Confluence page content contracts
│   ├── gdpr-report.md       # Full GDPR page content contract
│   ├── clinical-report.md   # Full Clinical/HIPAA-equivalent page content contract
│   ├── iso27001-report.md   # Full ISO 27001-aligned page content contract
│   └── irr-report.md        # Full IRR/Research Ethics page content contract
├── checklists/
│   └── requirements.md      # Spec quality checklist ✓
└── tasks.md                 # Phase 2 output (via /speckit.tasks)
```

### Source Code (repository root)

N/A — documentation-only feature. No source code in any split repository.

### Confluence Page Hierarchy (target output)

```text
MHG Documentation (ID: 8454317)
└── Compliance Documentation        [T001 — new parent page]
    ├── GDPR Compliance Report      [T002 — US1]
    ├── Clinical Data & Safety Compliance Report  [T003 — US2]
    ├── ISO 27001-aligned Security Controls Report  [T004 — US3]
    └── Research Ethics & IRR Report  [T005 — US4]
```

---

## Phase 0: Research Summary

**Status**: Complete → see [research.md](./research.md)

Key decisions made:
1. **Confluence space**: `UD` (ID: `8454147`) — no separate compliance space needed
2. **Parent page**: Create "Compliance Documentation" under root "MHG Documentation" (`8454317`)
3. **Content format**: Markdown (simpler than ADF, fully sufficient for tables)
4. **Mapping table columns**: Article/Control | Obligation | What Is Implemented | How It Is Achieved | Verification Artefact | Status
5. **Gap register**: Always present even if empty; columns: Control ID | Gap | Risk | Owner | Mitigation | Target Date
6. **No source code changes**: Documentation-only; implementation = research + write + publish via MCP

Known gaps to document in compliance registers:
- IAM deny policy for `chat-identity-map-dev` (pending `iam.denyAdmin` grant) — GDPR Art.32 / ISO A.9
- Cloud SQL dev using public IP (private IP reserved for prod) — ISO A.9 (Low risk, dev only)

---

## Phase 1: Design

### Content Contracts (`contracts/`)

Each contract file contains the full authoring template for one Confluence page, pre-populated with:
- Standard header (version, dates, owner role, scope)
- Regulation mapping table with all mandatory articles/controls pre-populated (empty `What Is Implemented` and `How It Is Achieved` cells to be filled during implementation)
- Gap register table pre-populated with known gaps
- Change log entry for v1.0

The contracts serve as the authoritative content specification that tasks.md tasks reference for authoring.

### Data Model

See [data-model.md](./data-model.md) for:
- `ComplianceDocument` — page structure schema
- `RegulationMapping` — table row schema (FR-002)
- `GapRegisterEntry` — gap register row schema (FR-003)
- `VerificationArtefact` — evidence reference format (FR-007)

---

## Phase 2: Implementation Tasks (via `/speckit.tasks`)

Task phases:
1. **Setup**: Create "Compliance Documentation" parent page in Confluence
2. **US1 (P1)**: Research + author + publish GDPR Compliance Report
3. **US2 (P1)**: Research + author + publish Clinical Data & Safety Compliance Report
4. **US3 (P2)**: Research + author + publish ISO 27001-aligned Security Controls Report
5. **US4 (P3)**: Research + author + publish Research Ethics & IRR Report
6. **Polish**: Internal peer review, gap register validation, spec.md update with Confluence page IDs

Each user-story phase follows the pattern:
1. Research existing implementation evidence (read relevant spec sections, evidence files)
2. Author page content following the content contract
3. Publish via `createConfluencePage` MCP tool
4. Verify page is accessible and renders correctly

---

## Implementation Notes

- **Cloud ID**: `3aca5c6d-161e-42c2-8945-9c47aeb2966d`
- **UD Space ID**: `8454147`
- **Root page ID**: `8454317` (MHG Documentation)
- **Jira Epic**: MTB-760
- All artefact references use relative paths or GCP resource names — no raw credentials, no PII
- GDPR Art. 17 erasure: anonymisation cascade (nullify FKs + soft-delete) — NOT hard deletion
- Content for `Verification Artefact` cells draws primarily from `specs/030-non-therapy-technical-backlog/spec.md` and `chat-infra/evidence/`

---

## Complexity Tracking

N/A — no constitution violations.

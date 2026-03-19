# Tasks: Compliance Audit Documentation (031)

**Input**: Design documents from `specs/031-compliance-audit-docs/`
**Prerequisites**: spec.md ✓, plan.md ✓, research.md ✓, data-model.md ✓, contracts/ ✓
**Jira Epic**: MTB-760

**Organisation**: Tasks are grouped by user story to enable independent publication and verification of each compliance document.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel
- **[Story]**: Which user story this task belongs to (US1–US4)

## Story Mapping

- US1 → `MTB-761`
- US2 → `MTB-762`
- US3 → `MTB-763`
- US4 → `MTB-764`

---

## Phase 1: Setup

**Purpose**: Create the Confluence parent page that hosts all four compliance documents

- [X] T001 Create "Compliance Documentation" parent page in Confluence UD space ? MTB-765 (spaceId: `8454147`, parentId: `8454317`) using `createConfluencePage` MCP tool with markdown body: `# Compliance Documentation\n\nThis section contains the platform's regulatory compliance audit documents. Each document maps a specific regulation to its implementation in the MentalHelpGlobal platform, providing exhaustive evidence for external auditors, Data Protection Authorities, and clinical governance reviewers.\n\n## Documents\n\n- [GDPR Compliance Report](./GDPR+Compliance+Report) — GDPR obligations for EU data subjects\n- [Clinical Data & Safety Compliance Report](./Clinical+Data+%26+Safety+Compliance+Report) — HIPAA-equivalent clinical controls\n- [ISO 27001-aligned Security Controls Report](./ISO+27001-aligned+Security+Controls+Report) — Annex A security controls\n- [Research Ethics & IRR Report](./Research+Ethics+%26+IRR+Report) — Annotation methodology and model quality`; record the returned page ID in research.md under a "Published Page IDs" section

---

## Phase 2: Foundational

**Purpose**: Blocking prerequisites before publishing individual documents

**⚠️ CRITICAL**: Phase 1 must complete before publishing child pages; parent page ID needed as `parentId`

- [X] T002 Record the Jira Epic key `MTB-760` in `specs/031-compliance-audit-docs/spec.md` ? MTB-766 header (add a `**Jira Epic**: MTB-760` line after the Feature Branch line) to satisfy constitution Principle X traceability requirement

---

## Phase 3: User Story 1 — GDPR Compliance Report (Priority: P1) 🎯 MVP

**Goal**: Publish a self-contained GDPR compliance report in Confluence that allows a DPA auditor to assess conformance for any GDPR article without requesting supplementary documentation.

**Independent Test**: Open the published Confluence page, navigate to the Right to Erasure section, confirm: (a) anonymisation cascade description (not hard deletion), (b) 30-day SLA, (c) `gdpr_audit_log` artefact reference, (d) gap register with DPIA and breach notification entries — all visible without clicking any links.

- [X] T003 [US1] Read `specs/031-compliance-audit-docs/contracts/gdpr-report.md` ? MTB-767 to load the full GDPR page content template (10 articles mapped: Art. 5(1)(c), Art. 5(1)(b), Art. 5(1)(e), Art. 6/7, Art. 12–15, Art. 17, Art. 25, Art. 30, Art. 32, Art. 33/34, Art. 35; 3-entry gap register; change log)
- [X] T004 [US1] Create "GDPR Compliance Report" Confluence page ? MTB-768 as child of the "Compliance Documentation" parent page (parentId from T001) in UD space using `createConfluencePage` with `contentFormat: "markdown"` and the full content from the contract file; record the returned page ID
- [X] T005 [US1] Verify the GDPR Compliance Report page is accessible ? MTB-769: use `getConfluencePage` to read back the published page; confirm the regulation mapping table renders with all 10 article rows and the gap register section is present; if any content is truncated or missing, use `updateConfluencePage` to correct

**Checkpoint**: GDPR Compliance Report published, accessible, and independently verifiable by an auditor ✓

---

## Phase 4: User Story 2 — Clinical Data & Safety Compliance Report (Priority: P1)

**Goal**: Publish a clinical compliance report that allows a clinical governance lead or external auditor to verify AI safety controls, RBAC, append-only data storage, and risk flag audit trail — each with an artefact reference.

**Independent Test**: Open the published page, find the AI Safety Filtering section, confirm: (a) score band labels only reach AI (not numeric scores), (b) fail-open behaviour on timeout described, (c) session-level cache invalidation described — all present without follow-up questions.

- [X] T006 [P] [US2] Read `specs/031-compliance-audit-docs/contracts/clinical-report.md` ? MTB-770 to load the full Clinical page content template (9 controls: minimum necessary, append-only, RBAC, k=10, post-generation filter, fail-open, session cache, risk flag audit trail, adaptive scheduling; 2-entry gap register)
- [X] T007 [US2] Create "Clinical Data & Safety Compliance Report" Confluence page ? MTB-771 as child of the "Compliance Documentation" parent page using `createConfluencePage` with `contentFormat: "markdown"` and full content from the contract file; record the returned page ID
- [X] T008 [US2] Verify the Clinical page renders correctly using `getConfluencePage` ? MTB-772; confirm all 9 control rows in the mapping table and gap register entries for fallback strings and risk thresholds are present

**Checkpoint**: Clinical Data & Safety Compliance Report published and independently verifiable ✓

---

## Phase 5: User Story 3 — ISO 27001-aligned Security Controls Report (Priority: P2)

**Goal**: Publish an ISO 27001-aligned security controls report that maps Annex A controls to platform implementation, enabling a security auditor to verify identity isolation, encryption, and logging controls.

**Independent Test**: Open the published page, find the A.10 cryptography section, confirm: (a) Google-managed AES-256 encryption stated, (b) `diskEncryptionConfiguration` absent = Google-managed explanation present, (c) link to `chat-infra/evidence/T027/encryption-audit.txt` — all without additional requests.

- [X] T009 [P] [US3] Read `specs/031-compliance-audit-docs/contracts/iso27001-report.md` ? MTB-773 to load the full ISO 27001 page content template (11 Annex A controls: A.9.1, A.9.2, A.9.4, A.10.1, A.10.2, A.12.4, A.12.6, A.14.1, A.14.2, A.14.3, A.18.1; 3-entry gap register including IAM deny policy and CMEK gaps; cross-reference note)
- [X] T010 [US3] Create "ISO 27001-aligned Security Controls Report" Confluence page ? MTB-774 as child of the "Compliance Documentation" parent page using `createConfluencePage` with `contentFormat: "markdown"` and full content from the contract file; record the returned page ID
- [X] T011 [US3] Verify the ISO 27001 page renders correctly using `getConfluencePage` ? MTB-775; confirm the cross-reference note to the GDPR document is present and all 11 Annex A control rows are visible in the mapping table

**Checkpoint**: ISO 27001 Security Controls Report published and independently verifiable ✓

---

## Phase 6: User Story 4 — Research Ethics & IRR Report (Priority: P3)

**Goal**: Publish a research ethics and inter-rater reliability report that documents the annotation methodology, kappa computation, bootstrap CI approach, and F-beta cost asymmetry rationale for a research ethics board reviewer or ML auditor.

**Independent Test**: Open the published page, find the Cohen's κ section, confirm: (a) pairwise + Fleiss' κ variants described, (b) 1,000-iteration bootstrap CI documented, (c) κ < 0.6 alert threshold with rationale, (d) F-beta β=4.47 with 20:1 cost asymmetry explanation — all present.

- [X] T012 [P] [US4] Read `specs/031-compliance-audit-docs/contracts/irr-report.md` ? MTB-776 to load the full Research Ethics page content template (7 areas: annotation blinding, transcript sampling, Cohen's κ, Fleiss' κ, bootstrap CI, model performance metrics, confusion matrices; κ threshold table; cost asymmetry rationale; 2-entry gap register)
- [X] T013 [US4] Create "Research Ethics & IRR Report" Confluence page ? MTB-777 as child of the "Compliance Documentation" parent page using `createConfluencePage` with `contentFormat: "markdown"` and full content from the contract file; record the returned page ID
- [X] T014 [US4] Verify the IRR page renders correctly using `getConfluencePage` ? MTB-778; confirm the κ threshold table and the cost asymmetry rationale section (β=4.47, 20:1 cost ratio) are present and readable

**Checkpoint**: Research Ethics & IRR Report published and independently verifiable ✓

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Final validation, traceability updates, and peer review gate

- [X] T015 Update the "Compliance Documentation" parent page body ? MTB-779 (T001) using `updateConfluencePage` to include direct hyperlinks to each of the four published child pages using their Confluence page IDs (recorded in T004, T007, T010, T013)
- [X] T016 [P] Update `specs/031-compliance-audit-docs/spec.md` header to record published Confluence page IDs ? MTB-780 for all four documents (add a `## Published Pages` section listing page IDs and titles for auditor reference)
- [X] T017 [P] Run a cross-document consistency check ? MTB-781: confirm the ISO 27001 report's A.18.1 row links to the GDPR report, and the GDPR Art. 32 row references the ISO 27001 document — avoiding duplicate conflicting descriptions per spec edge case FR-002/FR-007
- [X] T018 Internal peer review gate ? MTB-782: a second team member reads each published page and verifies (a) no GDPR article from FR-013 is missing without a gap register entry, (b) every mapping row has at least one artefact reference, (c) gap register has owner + target date for every entry — record review outcome as a comment on MTB-760

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Can run in parallel with Phase 1
- **US1 (Phase 3)**: Requires T001 (parent page ID needed as parentId)
- **US2 (Phase 4)**: Requires T001 — can start in parallel with US1 once parent page created
- **US3 (Phase 5)**: Requires T001 — can start in parallel with US1/US2
- **US4 (Phase 6)**: Requires T001 — can start in parallel with US1/US2/US3
- **Polish (Phase 7)**: Requires T004, T007, T010, T013 (all four pages published)

### User Story Dependencies

All four US are independent of each other — only the shared parent page (T001) must exist first.

- **US1 (P1)**: Can start after T001. No dependency on US2/US3/US4.
- **US2 (P1)**: Can start after T001. No dependency on US1/US3/US4.
- **US3 (P2)**: Can start after T001. References GDPR document for cross-reference (informational only, not blocking).
- **US4 (P3)**: Can start after T001. Fully independent.

### Parallel Opportunities

- T006 [US2] read, T009 [US3] read, T012 [US4] read — can all run in parallel with T003 [US1] read (different contract files)
- T007, T010, T013 — Confluence page creation calls can run in parallel after T001 completes
- T015, T016, T017 — Polish tasks can run in parallel

---

## Parallel Example: All User Stories (after T001)

```
After T001 (parent page created):
  T003 [US1] Read gdpr-report.md contract
  T006 [US2] Read clinical-report.md contract     ← parallel
  T009 [US3] Read iso27001-report.md contract      ← parallel
  T012 [US4] Read irr-report.md contract           ← parallel

Then (each independent):
  T004 [US1] Create GDPR page
  T007 [US2] Create Clinical page                  ← parallel with T004
  T010 [US3] Create ISO 27001 page                 ← parallel with T004/T007
  T013 [US4] Create IRR page                       ← parallel with T004/T007/T010
```

---

## Implementation Strategy

### MVP First (US1 + US2 — both P1)

1. Complete Phase 1: Create "Compliance Documentation" parent page (T001)
2. Complete Phase 2: Update spec.md with Epic key (T002)
3. Complete Phase 3: Publish GDPR Compliance Report (T003–T005) — highest regulatory risk
4. Complete Phase 4: Publish Clinical Data & Safety Compliance Report (T006–T008)
5. **STOP and VALIDATE**: Both P1 documents independently auditable
6. Continue with Phase 5 (ISO 27001) and Phase 6 (IRR) in priority order

### Incremental Delivery

1. T001–T002: Foundation → parent page live
2. T003–T005: GDPR Report live → DPA auditor can review
3. T006–T008: Clinical Report live → Clinical governance auditor can review
4. T009–T011: ISO 27001 Report live → Security auditor can review
5. T012–T014: IRR Report live → Research ethics board can review
6. T015–T018: Cross-linking, spec update, peer review → Feature complete

### Key Implementation Notes

- All page creation uses `createConfluencePage` MCP tool with `cloudId: "3aca5c6d-161e-42c2-b2a1-d0fc0026df49"` and `contentFormat: "markdown"`
- Wait for each `createConfluencePage` call to return a `pageId` before recording it
- If a page creation call fails, check: (a) parentId is correct, (b) spaceId is `8454147`, (c) title is unique in the space
- The contract files in `contracts/` are the authoritative content source — do not rewrite content during publication, publish as-is
- GDPR Art. 17 erasure: always describe as **anonymisation** (FK nullification + soft-delete), never as "hard deletion"

---

## Notes

- [P] tasks = different contract files / different Confluence pages, no file conflicts
- [Story] label maps each task to a user story for Jira traceability
- Each user story phase is independently publishable and verifiable
- After T018 (peer review), feature is complete — no further implementation needed
- Confluence page IDs must be recorded in research.md and spec.md for future update/maintenance tasks

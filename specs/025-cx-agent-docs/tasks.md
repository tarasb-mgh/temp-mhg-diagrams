# Tasks: CX Agent Architecture Documentation

**Input**: Design documents from `/specs/025-cx-agent-docs/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, quickstart.md ✅

**Tests**: Not applicable — documentation feature.

**Organization**: Tasks grouped by user story. Each story produces a self-contained
Confluence section verifiable independently.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (no dependencies on incomplete tasks)
- **[Story]**: User story this task belongs to (US1, US2, US3)
- Confluence target: `https://mentalhelpglobal.atlassian.net/wiki/spaces/UD/pages/8847361/Technical+Onboarding`

---

## Phase 1: Setup

**Purpose**: Verify artifacts exist and read current Confluence page state.

- [X] T001 Read current Confluence Technical Onboarding page (pageId 8847361) to capture existing structure, current version number, and identify the insertion point for the new cx-agent-definition section — Confluence: https://mentalhelpglobal.atlassian.net/wiki/spaces/UD/pages/8847361/Technical+Onboarding
- [X] T002 [P] Verify all plan artifacts exist in specs/025-cx-agent-docs/ (spec.md, plan.md, research.md, data-model.md, quickstart.md)
- [X] T003 [P] Verify cx-agent-definition repo is present at D:\src\MHG\cx-agent-definition and README.md, agent.json are readable

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Draft the full cx-agent-definition Confluence section as a single cohesive document
before publishing. All US phases contribute content to this section.

**⚠️ CRITICAL**: No Confluence publish (T013) can happen until all US phases are drafted.

- [X] T004 Draft the top-level section heading and intro paragraph for "cx-agent-definition Repository" in the Confluence content — covering: what the agent is, GCP project, GitHub URL, local clone path specs/025-cx-agent-docs/quickstart.md

---

## Phase 3: User Story 1 — Developer Onboarding (Priority: P1) 🎯 MVP

**Goal**: A developer can identify which file to change for any of the 5 most common
modification types within 5 minutes of reading the documentation.

**Independent Test**: After publishing Phase 3 content, a developer unfamiliar with
Dialogflow CX can answer "which file do I edit to add a training phrase?" without
asking for help.

### Implementation for User Story 1

- [X] T005 [US1] Write "Repository Layout" subsection — annotated directory tree of cx-agent-definition/ showing each directory's role, based on specs/025-cx-agent-docs/research.md §Repository Layout
- [X] T006 [US1] Write "Component Reference" subsection — table listing all 8 components (Agent, Flow, Intents ×6, EntityTypes ×3, Playbook, Tool, Generator, GenerativeSettings) with their file paths and one-line purpose, based on specs/025-cx-agent-docs/data-model.md
- [X] T007 [P] [US1] Write "Common Change Tasks" subsection — 5 step-by-step developer procedures (add training phrase, update playbook, add entity value, update generative settings, add knowledge base content), based on specs/025-cx-agent-docs/quickstart.md §Common Change Tasks
- [X] T008 [P] [US1] Write "Developer Prerequisites and Setup" subsection — git clone command, GCP CLI requirement, Dialogflow CX console URL, local path — from specs/025-cx-agent-docs/quickstart.md §Prerequisites and §Clone the Repository

**Checkpoint**: Phase 3 content drafted. A developer can onboard to cx-agent-definition from
this section alone.

---

## Phase 4: User Story 2 — Operator Understanding (Priority: P2)

**Goal**: A non-developer (operator, product manager) can answer capability questions about
the agent (crisis escalation, languages, knowledge base management) from the documentation.

**Independent Test**: After publishing Phase 4 content, an operator can correctly describe
what happens when a user says "I want to die" — without reading raw JSON files.

### Implementation for User Story 2

- [X] T009 [US2] Write "Agent Capabilities Overview" subsection — what the agent can do (mental health support, multilingual, crisis detection, escalation) and explicit boundaries (no diagnosis, no medication advice, no enabling harm), based on specs/025-cx-agent-docs/research.md §Playbook §Safety Boundaries
- [X] T010 [P] [US2] Write "Crisis Detection and Escalation" subsection — table of crisis intents (SUICIDAL_IDEATION, HOMICIDAL_IDEATION, DELUSIONAL_THINKING, REQUEST_HUMAN) with trigger description, extracted parameters, and expected agent response, based on specs/025-cx-agent-docs/research.md §Conversation Flow Architecture and intent data
- [X] T011 [P] [US2] Write "Language Support" subsection — primary language (Ukrainian), additional languages (Russian, English), language detection behavior, and the "one polite ask" policy, based on specs/025-cx-agent-docs/research.md §Playbook §Language Policy
- [X] T012 [US2] Write "Knowledge Base Management" subsection — what the knowledge base contains (protocols, general knowledge, conversation examples), how content is stored (GCS mhg-doc-connector), and how to add new content (upload to GCS → trigger re-index), based on specs/025-cx-agent-docs/research.md §Tool

**Checkpoint**: Phase 4 content drafted. An operator can understand agent capabilities and
configure it correctly from this section.

---

## Phase 5: User Story 3 — CI/CD and Version Control (Priority: P3)

**Goal**: A developer can describe the end-to-end flow from "edit a JSON file" to "change
live in Dialogflow CX" — and knows how to rotate the Git integration token.

**Independent Test**: After publishing Phase 5 content, a developer can perform a token
rotation without asking for help.

### Implementation for User Story 3

- [X] T013 [US3] Write "Git Integration" subsection — Push/Restore workflow explanation, GCP Secret Manager token path (projects/942889188964/secrets/github-cx-agent-token/versions/latest), IAM requirement (Dialogflow service agent), and end-to-end change workflow (edit → commit → push → Push in CX console), based on specs/025-cx-agent-docs/research.md §Git Integration and specs/025-cx-agent-docs/quickstart.md §Git Integration
- [X] T014 [US3] Write "Token Rotation Procedure" subsection — step-by-step gcloud commands for reading the current token, adding a new version, and verifying IAM, from specs/025-cx-agent-docs/quickstart.md §Token rotation

**Checkpoint**: All three user story sections drafted. Ready for Confluence publication.

---

## Phase 6: Publish and Verify

**Purpose**: Assemble and publish the complete cx-agent-definition section to Confluence,
then verify all functional requirements are met.

- [X] T015 Assemble all drafted subsections (T004–T014) into a single cohesive "cx-agent-definition Repository" section — ensure consistent heading hierarchy (H2 section, H3 subsections), no orphaned content, logical reading order
- [X] T016 Publish the assembled section to the Confluence Technical Onboarding page (pageId 8847361) using updateConfluencePage — append the cx-agent-definition section after the last existing section; version = current version + 1
- [X] T017 [P] Verify FR-001 through FR-009 are all present in the published Confluence page — read the published page back and check each requirement against the checklist in specs/025-cx-agent-docs/checklists/requirements.md
- [X] T018 [P] Update specs/025-cx-agent-docs/checklists/requirements.md with final verification status for each FR after publication

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately; T002 and T003 run in parallel
- **Foundational (Phase 2)**: Depends on T001 completing (need current page version number)
- **US1 (Phase 3)**: Depends on Phase 2 (T004 intro drafted first); T007 and T008 run in parallel
- **US2 (Phase 4)**: Depends on Phase 2; T010, T011 run in parallel; T012 depends on T010 for context
- **US3 (Phase 5)**: Depends on Phase 2; T013 and T014 run in parallel
- **Publish (Phase 6)**: T015 depends on all US phases complete; T016 depends on T015; T017/T018 depend on T016

### User Story Dependencies

- **US1 (P1)**: Independent — can complete before US2/US3
- **US2 (P2)**: Independent — can complete before or after US1
- **US3 (P3)**: Independent — can complete before or after US1/US2
- All three user story phases feed into T015 (assembly) before publishing

### Parallel Opportunities

- T002 and T003 run in parallel (both setup verifications)
- T007 and T008 within US1 run in parallel (different subsections)
- T010 and T011 within US2 run in parallel (different subsections)
- T013 and T014 within US3 run in parallel (different subsections)
- T017 and T018 run in parallel (both post-publish verifications)

---

## Parallel Example: User Story 1

```
T005 — Repository Layout subsection    (sequential, sets context)
T006 — Component Reference subsection (sequential, references T005 layout)
T007 — Common Change Tasks             (parallel with T008)
T008 — Developer Prerequisites         (parallel with T007)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001–T003)
2. Complete Phase 2: Foundational (T004)
3. Complete Phase 3: User Story 1 (T005–T008)
4. Publish Phase 3 content only as initial Confluence section (T015–T016 scoped to US1)
5. **STOP and VALIDATE**: Can a developer onboard from the published section?

### Full Delivery

1. Complete Setup + Foundational
2. Complete all three US phases (can work them in parallel)
3. Assemble → Publish → Verify (T015–T018)

---

## Story Mapping

| Story | Jira |
|-------|------|
| US1 — Developer Onboarding to cx-agent-definition | [MTB-708](https://mentalhelpglobal.atlassian.net/browse/MTB-708) |
| US2 — Operator Understanding of Agent Capabilities | [MTB-709](https://mentalhelpglobal.atlassian.net/browse/MTB-709) |
| US3 — CI/CD and Version Control Clarity | [MTB-710](https://mentalhelpglobal.atlassian.net/browse/MTB-710) |

## Notes

- All tasks produce content for the single Confluence "cx-agent-definition Repository" section
- No code changes — this is a documentation-only feature
- The spec artifacts (research.md, data-model.md, quickstart.md) are the source of truth; the
  Confluence page presents the same information in a more accessible format
- [P] tasks in the same phase can be assigned to parallel agents or tackled simultaneously

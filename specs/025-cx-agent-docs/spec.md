# Feature Specification: Dialogflow CX Agent — Architecture Documentation

**Feature Branch**: `025-cx-agent-docs`
**Jira Epic**: [MTB-707](https://mentalhelpglobal.atlassian.net/browse/MTB-707)
**Created**: 2026-03-11
**Status**: Implemented
**Input**: User description: "Review the structure of the Dialogflow CX agent source and add implementation details to the spec and Confluence documentation"

## Overview

The MHG platform includes a **Mental Health First Responder** conversational AI agent built on
Google Dialogflow CX. This specification documents the agent's architecture, configuration, and
integration points so that developers, technical writers, and operators have a single authoritative
reference. The deliverable is twofold: (1) a complete spec artifact in `client-spec` and (2) a
published Confluence Technical Onboarding page for the `cx-agent-definition` repository.

## User Scenarios & Testing

### User Story 1 — Developer Onboarding to cx-agent-definition (Priority: P1)

A new developer joining the project needs to understand the CX agent's purpose, structure, and how
to make changes to it — without needing a walkthrough from an existing team member.

**Why this priority**: `cx-agent-definition` is now a primary target repository. Without
documentation, any change to the agent (adding intents, modifying playbook instructions, updating
tools) requires tribal knowledge.

**Independent Test**: A developer unfamiliar with Dialogflow CX reads the documentation and can
locate the correct file to modify when asked to add a new intent, update the crisis protocol text,
or change a knowledge base pointer — without asking for help.

**Acceptance Scenarios**:

1. **Given** a developer has cloned `cx-agent-definition`, **When** they read the Technical
   Onboarding Confluence page, **Then** they understand the repository layout, the role of each
   directory, and which files to edit for common change types.
2. **Given** a developer needs to add a training phrase to `SUICIDAL_IDEATION`, **When** they
   follow the documented procedure, **Then** they know the file path, format, and how to push the
   change back to the agent via the Dialogflow CX Git integration.
3. **Given** a developer needs to update the playbook's crisis protocol wording, **When** they
   consult the documentation, **Then** they can identify the correct playbook file and understand
   the instruction block structure.

---

### User Story 2 — Operator Understanding of Agent Capabilities (Priority: P2)

A support operator or product manager needs to understand what the CX agent can and cannot do —
specifically its crisis escalation paths, supported languages, and knowledge base scope — without
reading raw JSON files.

**Why this priority**: Operators make decisions about when to escalate, which crisis resources to
configure, and what content goes into the knowledge base. Undocumented capabilities lead to
misconfiguration.

**Independent Test**: A non-developer reads the documentation and correctly answers: "What happens
when a user expresses suicidal ideation?", "Which languages does the agent support?", and "How is
the knowledge base updated?"

**Acceptance Scenarios**:

1. **Given** a support operator reviews the documentation, **When** they look for crisis
   escalation behavior, **Then** they find a clear description of `SUICIDAL_IDEATION`,
   `HOMICIDAL_IDEATION`, and `REQUEST_HUMAN` intents and the responses they trigger.
2. **Given** a product manager wants to know the agent's language support, **When** they check the
   documentation, **Then** they find that Ukrainian is the primary language with Russian and
   English also supported.
3. **Given** an operator wants to add content to the knowledge base, **When** they read the
   documentation, **Then** they understand that content is stored in GCS and surfaced via the
   Dialogflow CX Data Store connector.

---

### User Story 3 — CI/CD and Version Control Clarity (Priority: P3)

A developer needs to understand how changes to the `cx-agent-definition` repo are deployed back
to the live Dialogflow CX agent — the Git integration, branch strategy, and push/restore workflow.

**Why this priority**: Without understanding the deploy path, developers may edit files and not
know how or when they take effect in the agent.

**Independent Test**: A developer can describe the end-to-end flow from "edit a JSON file locally"
to "change live in Dialogflow CX" after reading the documentation.

**Acceptance Scenarios**:

1. **Given** a developer edits an intent training phrase, **When** they follow the documented
   deploy procedure, **Then** they know to commit to `main`, and trigger or await the Dialogflow
   CX Git Push to apply the change.
2. **Given** the Dialogflow CX Git integration is configured with the GCP Secret Manager token,
   **When** a developer needs to rotate the token, **Then** the documentation describes the secret
   path (`projects/942889188964/secrets/github-cx-agent-token/versions/latest`) and rotation
   procedure.

---

### Edge Cases

- What happens if the Git integration token expires or is revoked mid-session?
- How does the agent behave if the GCS knowledge base is unavailable (retrieval failure)?
- What is the fallback if Gemini 2.5 Flash is rate-limited or unavailable?
- How are language detection failures handled (user writes in an unsupported script)?

## Requirements

### Functional Requirements

- **FR-001**: The `cx-agent-definition` repository structure MUST be documented with the purpose
  of each directory and file type.
- **FR-002**: Each intent (Welcome, Negative, SUICIDAL_IDEATION, HOMICIDAL_IDEATION,
  DELUSIONAL_THINKING, REQUEST_HUMAN) MUST be documented with its trigger conditions, parameters
  extracted, and the agent's expected response behavior.
- **FR-003**: The playbook instruction structure MUST be documented — including the Five Acts
  Reflex, crisis protocol, language policy, and safety boundaries.
- **FR-004**: The Mental Health Knowledge Base tool MUST be documented — including its GCS
  backing, retrieval model, grounding confidence setting, and how content is added or updated.
- **FR-005**: The Git integration between Dialogflow CX and `cx-agent-definition` MUST be
  documented — including the GCP Secret Manager token path, IAM requirements, and push/restore
  workflow.
- **FR-006**: The generative AI safety settings MUST be documented — including the permissive RAI
  configuration (BLOCK_NONE for crisis support) and its rationale.
- **FR-007**: The entity types (Method, TargetPerson, RiskLevel) MUST be documented with their
  values and the intents that use them.
- **FR-008**: The Confluence Technical Onboarding page MUST include a dedicated section for the
  `cx-agent-definition` repository covering all of FR-001 through FR-007.
- **FR-009**: The local clone path (`D:\src\MHG\cx-agent-definition`) and GitHub repository URL
  MUST be documented as part of the developer setup instructions.

### Key Entities

- **Agent**: The Dialogflow CX agent "Mental Health First Responder" — entry point, language
  settings, GCP project binding, start playbook reference.
- **Flow**: "Default Start Flow" — routes welcome intent to playbook, handles no-match/no-input
  fallback events.
- **Intent**: NLU classification unit — maps user utterances to structured outcomes; crisis
  intents (SUICIDAL_IDEATION, HOMICIDAL_IDEATION) carry parameter extraction.
- **Entity Type**: Structured value extractor — Method (harm means), TargetPerson (self/other),
  RiskLevel (severity tier).
- **Playbook**: "Mental Help Assistant" — LLM-driven behavior definition including goals,
  instructions, tool references, and model configuration.
- **Tool**: "Mental Health Knowledge Base" — Dialogflow CX data store backed by GCS documents;
  provides RAG-style retrieval for grounded responses.
- **Generator**: "MHG Responder Generator" — fallback response generator for unmatched inputs.
- **Generative Settings**: Language-level LLM parameters and RAI (safety filter) configuration.

## Success Criteria

### Measurable Outcomes

- **SC-001**: A developer new to the project can identify the correct file to modify for any of
  the five most common change types (intent phrase, playbook instruction, entity value, tool
  config, generative setting) within 5 minutes of reading the documentation.
- **SC-002**: The Confluence Technical Onboarding page includes a self-contained
  `cx-agent-definition` section covering repository layout, component roles, Git integration,
  and knowledge base management.
- **SC-003**: All 8 documentation functional requirements (FR-001 through FR-008) are verifiably
  present in the published Confluence page — reviewable via a checklist.
- **SC-004**: The spec artifact in `client-spec` accurately reflects the current state of
  `cx-agent-definition` (verified by cross-referencing against repo files at time of publication).

## Assumptions

- The `cx-agent-definition` repository structure as explored on 2026-03-11 is the current
  authoritative state (single flow, six intents, one playbook, one tool, one generator).
- The Dialogflow CX Git integration pushes the entire repository to the agent on each "Push" —
  no partial syncing.
- The knowledge base content (GCS bucket backing) is managed separately from `cx-agent-definition`
  and is out of scope for this spec (covered only in terms of configuration, not content curation).
- Documentation targets the Confluence Technical Onboarding section; User Manual and
  Non-Technical Onboarding are out of scope as the CX agent is not directly user-operated via
  the web UI.

## Dependencies

- `cx-agent-definition` repo cloned locally at `D:\src\MHG\cx-agent-definition`
- Confluence Technical Onboarding page:
  https://mentalhelpglobal.atlassian.net/wiki/spaces/UD/pages/8847361/Technical+Onboarding
- Atlassian MCP available for Confluence page updates
- GCP Secret Manager secret:
  `projects/942889188964/secrets/github-cx-agent-token/versions/latest`

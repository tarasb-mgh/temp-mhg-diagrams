# Implementation Plan: CX Agent Clinical Playbooks (Depression & Anxiety)

**Branch**: `052-cx-clinical-playbooks` | **Date**: 2026-04-15 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/052-cx-clinical-playbooks/spec.md`
**Jira Epic**: MTB-1340

## Summary

Add two specialized clinical playbooks (Depression Protocol, Anxiety Protocol) to the existing Dialogflow CX agent with hybrid intent+LLM routing, severity-adaptive communication, and persistence via the existing assessment schema and agent memory system. Primarily a CX agent configuration project with backend schema extensions for assessment recording.

## Technical Context

**Language/Version**: Dialogflow CX agent definition (JSON/YAML), Node.js/TypeScript (chat-backend)
**Primary Dependencies**: Dialogflow CX, Gemini 2.5 Flash, existing assessment services, agent memory service
**Storage**: Google Cloud Storage (agent memory), Cloud SQL PostgreSQL (assessment schema, analytics, risk flags)
**Testing**: Regression-suite YAML test cases (Playwright MCP-driven conversation testing), Vitest for backend service extensions
**Target Platform**: Dialogflow CX (Google Cloud), chat-backend on Cloud Run
**Project Type**: Agent configuration + backend service extension
**Performance Goals**: No additional latency on conversational responses; session-end webhook completes within 5 seconds
**Constraints**: Must not modify existing Mental Help Assistant core behavior; must maintain GDPR compliance via pseudonymous_user_id; Gemini safety overrides must not affect non-playbook conversations
**Scale/Scope**: ~300 concurrent CX agent sessions, 2 new playbooks, 2 new intents, 1 backend migration, 1 webhook endpoint

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Spec-First Development | PASS | Spec complete at spec.md, Epic MTB-1340 created |
| II. Multi-Repository Orchestration | PASS | Affects cx-agent-definition and chat-backend only |
| III. Test-Aligned Development | PASS | Conversation tests via regression-suite YAML; backend unit tests via Vitest |
| IV. Branch and Integration Discipline | PASS | Feature branch per repo, PRs to develop |
| V. Privacy and Security First | PASS | All assessment data uses pseudonymous_user_id; GDPR erasure cascade applies; no new PII collection |
| VI. Accessibility and i18n | PASS | Trilingual support (uk/ru/en); no UI changes needed |
| VI-B. Design System Compliance | N/A | No frontend UI changes |
| VII. Split-Repository First | PASS | Implementation in split repos (cx-agent-definition, chat-backend) |
| X. Jira Traceability | PASS | Epic MTB-1340; tasks will create child issues |
| XI. Documentation Standards | PASS | All spec/plan docs in English |

No violations. No complexity justification needed.

## Project Structure

### Documentation (this feature)

```text
specs/052-cx-clinical-playbooks/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (webhook API)
└── tasks.md             # Phase 2 output
```

### Source Code (across repositories)

```text
cx-agent-definition/                        # Dialogflow CX agent (primary)
├── intents/
│   ├── DEPRESSION_SIGNALS/                 # NEW: Depression detection intent
│   │   └── DEPRESSION_SIGNALS.json         # Training phrases (uk/ru/en)
│   └── ANXIETY_SIGNALS/                    # NEW: Anxiety detection intent
│       └── ANXIETY_SIGNALS.json            # Training phrases (uk/ru/en)
├── playbooks/
│   ├── Mental Help Assistant/
│   │   └── Mental Help Assistant.json      # MODIFY: Add handoff instructions
│   ├── Depression Protocol/                # NEW: Depression playbook
│   │   └── Depression Protocol.json        # Screening, scoring, tone rules
│   └── Anxiety Protocol/                   # NEW: Anxiety playbook
│       └── Anxiety Protocol.json           # Screening, scoring, tone rules, acute mode
├── flows/
│   └── Default Start Flow/
│       └── Default Start Flow.json         # MODIFY: Add routes for new intents
└── generators/
    └── banned-phrases.json                 # NEW: Post-processing phrase filter

chat-backend/                               # Backend (secondary)
├── src/
│   ├── db/migrations/
│   │   └── 052_052-cx-assessment-types.sql # NEW: Extend CHECK constraints
│   ├── services/
│   │   ├── agentMemory/
│   │   │   └── agentMemory.service.ts      # MODIFY: Add CX screening state timeline helper
│   │   └── cx-webhook.service.ts           # NEW: Session-end webhook handler
│   ├── routes/
│   │   └── cx-webhook.routes.ts            # NEW: Webhook endpoint
│   └── assessment/
│       └── assessment-sessions.service.ts  # MODIFY: Support CX_DEP/CX_ANX instruments
└── tests/
    └── cx-webhook.test.ts                  # NEW: Webhook unit tests

regression-suite/                           # Conversation tests
├── 17-cx-depression.yaml                   # NEW: Depression playbook test cases
└── 18-cx-anxiety.yaml                      # NEW: Anxiety playbook test cases
```

**Structure Decision**: This is a cross-repo feature. The cx-agent-definition repo holds all Dialogflow CX configuration (intents, playbooks, flows, generators). The chat-backend repo holds the session-end webhook and database migration. No frontend changes.

## Implementation Phases

### Phase 0: Research

Research tasks documented in [research.md](research.md).

### Phase 1: Design

Data model documented in [data-model.md](data-model.md).
API contract documented in [contracts/](contracts/).
Setup guide documented in [quickstart.md](quickstart.md).

### Phase 2: Implementation (via /speckit.tasks)

Implementation broken into phases:
1. **Database migration** — Extend assessment_scores CHECK, add instrument_params rows, add risk thresholds
2. **CX Intents** — Create DEPRESSION_SIGNALS and ANXIETY_SIGNALS intents with trilingual training phrases
3. **Depression Playbook** — Create playbook with screening bank, scoring logic, severity protocols, safety overrides
4. **Anxiety Playbook** — Create playbook with screening bank, scoring logic, acute intervention mode, safety overrides
5. **Mental Help Assistant update** — Add signal detection and handoff instructions
6. **Flow routing** — Update Default Start Flow with new intent routes
7. **Banned phrases filter** — Create post-processing generator configuration
8. **Session-end webhook** — Backend endpoint for assessment persistence, risk flags, analytics
9. **Agent memory integration** — State Timeline persistence and cross-session loading
10. **Regression test cases** — YAML test suites for depression and anxiety conversation flows
11. **Integration testing** — End-to-end validation on dev environment

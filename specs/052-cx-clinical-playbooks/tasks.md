# Tasks: CX Agent Clinical Playbooks (Depression & Anxiety)

**Input**: Design documents from `/specs/052-cx-clinical-playbooks/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/cx-webhook.yaml
**Jira Epic**: MTB-1340

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story. Some tasks serve multiple stories and are labeled with their primary story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2)
- File paths use repository-relative notation: `cx-agent-definition/...` and `chat-backend/...`

---

## Phase 1: Setup

**Purpose**: Repository preparation and branch creation

- [X] T001 Create feature branch `052-cx-clinical-playbooks` in cx-agent-definition repository
- [X] T002 [P] Create feature branch `052-cx-clinical-playbooks` in chat-backend repository
- [X] T003 Define Dialogflow CX session parameters (active_playbook, severity_level, yes_count, critical_flags, questions_covered, co_occurring_signals) in cx-agent-definition agent configuration

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Database migration and shared infrastructure that MUST be complete before any user story work

**CRITICAL**: No user story work can begin until this phase is complete

- [X] T004 Create database migration `052_052-cx-assessment-types.sql` in chat-backend/src/db/migrations/ to extend assessment_scores instrument_type CHECK constraint with CX_DEP and CX_ANX values
- [X] T005 [P] Add instrument_params rows for CX_DEP and CX_ANX (provisional SD=4.0, reliability=0.85, CMI threshold=3) in chat-backend/src/db/migrations/052_052-cx-assessment-types.sql
- [X] T006 [P] Add risk_thresholds seed rows (CX_DEP absolute score>=11 urgent, CX_DEP item D18 critical, CX_ANX absolute score>=11 urgent, CX_ANX item A05 routine) in chat-backend/src/db/migrations/052_052-cx-assessment-types.sql
- [X] T007 Run migration against dev database and verify assessment_scores accepts CX_DEP/CX_ANX instrument types

**Checkpoint**: Database ready — assessment schema supports new instrument types

---

## Phase 3: User Story 1 — Depression Signal Detection and Screening (Priority: P1)

**Goal**: Users expressing depression signals are detected and screened through phased hybrid questioning with severity scoring

**Independent Test**: Send depression-related messages in Ukrainian, verify Depression Protocol activates, screening proceeds conversationally, severity is scored correctly

### Implementation for User Story 1

- [X] T008 [US1] Create DEPRESSION_SIGNALS intent directory and JSON definition with 35+ Ukrainian training phrases covering sadness, hopelessness, anhedonia, worthlessness, emptiness, fatigue, inability to function, sleep/appetite changes, death ideation in cx-agent-definition/intents/DEPRESSION_SIGNALS/DEPRESSION_SIGNALS.json
- [X] T009 [US1] Create Depression Protocol playbook directory and JSON with model config (Gemini 2.5 Flash, temperature 0.7) and safety settings (BLOCK_NONE for dangerous content, harassment, hate speech) in cx-agent-definition/playbooks/Depression Protocol/Depression Protocol.json
- [X] T010 [US1] Write Depression Protocol playbook goal text: screening question bank (D01-D20 with domain IDs, conditional follow-ups), phased hybrid screening instructions (conversational mapping + natural gap-filling), in cx-agent-definition/playbooks/Depression Protocol/Depression Protocol.json
- [X] T011 [US1] Write Depression Protocol severity scoring instructions in playbook goal text: yes_count thresholds (0-3 none, 4-6 mild, 7-10 moderate, 11+ severe), critical override for D16/D17/D18 (auto-elevate to moderate), D18 self-harm sub-question override (floor=severe, trigger crisis) in cx-agent-definition/playbooks/Depression Protocol/Depression Protocol.json
- [X] T012 [US1] Write Depression Protocol severity-adaptive communication instructions in playbook goal text: mild (calm, concrete actions, cognitive distortion awareness), moderate (slow, structured, one-symptom-at-a-time, professional help mention), severe (minimal text, safety-first, professional referral emphasis) in cx-agent-definition/playbooks/Depression Protocol/Depression Protocol.json
- [X] T013 [US1] Write Depression Protocol crisis escalation instructions in playbook goal text: when critical_flags=self_harm, calm safety check, do NOT contradict, provide 112/103/7333, stay present, set active_playbook=crisis in cx-agent-definition/playbooks/Depression Protocol/Depression Protocol.json
- [X] T014 [US1] Write Depression Protocol behavioral override instructions in playbook goal text: no AI disclaimers, no safety footers, no toxic positivity, no diagnosis, no speculative language, no banned phrases, explicit directive for D16-D18 direct asking in cx-agent-definition/playbooks/Depression Protocol/Depression Protocol.json
- [X] T015 [US1] Write Depression Protocol session parameter management instructions: increment yes_count on affirmative, append to questions_covered, update severity_level per thresholds, set critical_flags on D18, detect co_occurring_signals for anxiety domain in cx-agent-definition/playbooks/Depression Protocol/Depression Protocol.json

**Checkpoint**: Depression Protocol playbook complete with screening, scoring, tone protocols, and safety overrides

---

## Phase 4: User Story 2 — Anxiety Signal Detection and Screening (Priority: P1)

**Goal**: Users expressing anxiety signals are detected and screened with severity scoring and acute intervention mode for active panic

**Independent Test**: Send anxiety-related messages, verify Anxiety Protocol activates, acute intervention triggers for panic symptoms, screening proceeds after acute state resolves

### Implementation for User Story 2

- [X] T016 [US2] Create ANXIETY_SIGNALS intent directory and JSON definition with 35+ Ukrainian training phrases covering worry, panic, physical fear symptoms, avoidance, inability to relax, dread, irritability in cx-agent-definition/intents/ANXIETY_SIGNALS/ANXIETY_SIGNALS.json
- [X] T017 [US2] Create Anxiety Protocol playbook directory and JSON with model config (Gemini 2.5 Flash, temperature 0.7) and safety settings (BLOCK_NONE for dangerous content, harassment, hate speech) in cx-agent-definition/playbooks/Anxiety Protocol/Anxiety Protocol.json
- [X] T018 [US2] Write Anxiety Protocol playbook goal text: screening question bank (A01-A19 with domain IDs, conditional follow-ups), phased hybrid screening instructions in cx-agent-definition/playbooks/Anxiety Protocol/Anxiety Protocol.json
- [X] T019 [US2] Write Anxiety Protocol Acute Intervention Mode instructions: detect active panic symptoms, bypass screening, provide immediate grounding steps (4s inhale/6s exhale, stand up, focus on 3 objects), check if better, only proceed to screening after acute state resolves in cx-agent-definition/playbooks/Anxiety Protocol/Anxiety Protocol.json
- [X] T020 [US2] Write Anxiety Protocol severity scoring instructions: yes_count thresholds on A01-A16 (0-3 none, 4-6 mild, 7-10 moderate, 11+ severe), no critical override equivalent in cx-agent-definition/playbooks/Anxiety Protocol/Anxiety Protocol.json
- [X] T021 [US2] Write Anxiety Protocol severity-adaptive communication instructions: core response structure (acknowledge, normalize, ground, step-by-step, prioritize), mild (calm, rationalize), moderate (slow, one-problem-at-a-time, trigger list), severe (professional referral, short text, no arguing with catastrophic thinking) in cx-agent-definition/playbooks/Anxiety Protocol/Anxiety Protocol.json
- [X] T022 [US2] Write Anxiety Protocol behavioral override and session parameter management instructions (same structure as Depression Protocol adapted for anxiety domain) in cx-agent-definition/playbooks/Anxiety Protocol/Anxiety Protocol.json
- [X] T023 [US2] Write shared tone anti-pattern instructions for Anxiety Protocol: no robotic tone, no dramatic reassurance, no toxic positivity, simple grounded language, example correct vs incorrect responses in cx-agent-definition/playbooks/Anxiety Protocol/Anxiety Protocol.json

**Checkpoint**: Anxiety Protocol playbook complete with screening, acute mode, scoring, tone protocols

---

## Phase 5: User Story 7 — LLM Safety Override + User Story 3 — Severity-Adaptive Communication (Priority: P1)

**Goal**: Gemini safety filters are disabled for clinical conversations; communication adapts by severity; banned phrases are filtered from output

**Independent Test**: Send self-harm statements, verify agent responds per clinical protocol without disclaimers; verify banned phrases are filtered

### Implementation for User Stories 3 and 7

- [X] T024 [US7] Configure banned-phrase post-processing in Dialogflow CX generator settings: add trilingual banned phrase list (AI self-identification, toxic validation, false reassurance, safety footers) in cx-agent-definition/generators/banned-phrases.json
- [X] T025 [US3] Update Mental Help Assistant playbook to add mid-conversation depression/anxiety signal detection instructions: monitor for 3+ distinct symptom domain clusters, set active_playbook parameter, transition naturally without announcing switch in cx-agent-definition/playbooks/Mental Help Assistant/Mental Help Assistant.json
- [X] T026 [US3] Add transition routes in Default Start Flow for DEPRESSION_SIGNALS intent routing to Depression Protocol playbook and ANXIETY_SIGNALS intent routing to Anxiety Protocol playbook in cx-agent-definition/flows/Default Start Flow/Default Start Flow.json
- [X] T027 [US7] Add Dialogflow CX fallback handler for Gemini unavailability: static crisis contact information (112, 103, 7333) as fallback response when LLM fails to respond in cx-agent-definition/flows/Default Start Flow/Default Start Flow.json

**Checkpoint**: Full routing pipeline operational — intents, LLM detection, playbook handoff, safety overrides, banned phrases

---

## Phase 6: User Story 8 — Trilingual Support (Priority: P2)

**Goal**: Intent detection and playbook responses work across Ukrainian, Russian, and English

**Independent Test**: Send depression/anxiety statements in all three languages, verify intent matching and language-appropriate responses

### Implementation for User Story 8

- [X] T028 [US8] Add 35+ Russian training phrases to DEPRESSION_SIGNALS intent covering sadness, hopelessness, anhedonia, worthlessness, fatigue, sleep/appetite changes, death ideation in cx-agent-definition/intents/DEPRESSION_SIGNALS/DEPRESSION_SIGNALS.json
- [X] T029 [P] [US8] Add 35+ English training phrases to DEPRESSION_SIGNALS intent in cx-agent-definition/intents/DEPRESSION_SIGNALS/DEPRESSION_SIGNALS.json
- [X] T030 [P] [US8] Add 35+ Russian training phrases to ANXIETY_SIGNALS intent covering worry, panic, physical symptoms, avoidance, dread, irritability in cx-agent-definition/intents/ANXIETY_SIGNALS/ANXIETY_SIGNALS.json
- [X] T031 [P] [US8] Add 35+ English training phrases to ANXIETY_SIGNALS intent in cx-agent-definition/intents/ANXIETY_SIGNALS/ANXIETY_SIGNALS.json
- [X] T032 [US8] Add Russian and English equivalents to banned-phrase filter list in cx-agent-definition/generators/banned-phrases.json
- [X] T033 [US8] Add language detection and response language instructions to both playbooks: respond in user's detected language, ask if uncertain, never output English system refusals in non-English conversations in cx-agent-definition/playbooks/Depression Protocol/Depression Protocol.json and cx-agent-definition/playbooks/Anxiety Protocol/Anxiety Protocol.json

**Checkpoint**: All intents and playbooks support Ukrainian, Russian, and English

---

## Phase 7: User Story 4 — Co-Occurrence Handling (Priority: P2)

**Goal**: When users show signals for both depression and anxiety, the agent completes the primary screening first, then transitions to the second playbook

**Independent Test**: Express both depression and anxiety signals in one conversation, verify sequential screening with two distinct severity scores

### Implementation for User Story 4

- [X] T034 [US4] Add co-occurrence detection instructions to Depression Protocol: when anxiety-domain signals are mentioned during depression screening, set co_occurring_signals=anxiety without interrupting current screening in cx-agent-definition/playbooks/Depression Protocol/Depression Protocol.json
- [X] T035 [P] [US4] Add co-occurrence detection instructions to Anxiety Protocol: when depression-domain signals are mentioned during anxiety screening, set co_occurring_signals=depression in cx-agent-definition/playbooks/Anxiety Protocol/Anxiety Protocol.json
- [X] T036 [US4] Add completion-and-handoff instructions to both playbooks: after primary screening completes, check co_occurring_signals, if not none then naturally invite user to discuss other domain, reset yes_count and questions_covered for new screening, transition active_playbook in cx-agent-definition/playbooks/Depression Protocol/Depression Protocol.json and cx-agent-definition/playbooks/Anxiety Protocol/Anxiety Protocol.json
- [X] T037 [US4] Add return-to-general routing: after specialized playbook completes (no co-occurrence), set active_playbook=general and return to Mental Help Assistant in cx-agent-definition/playbooks/Depression Protocol/Depression Protocol.json and cx-agent-definition/playbooks/Anxiety Protocol/Anxiety Protocol.json

**Checkpoint**: Co-occurrence handling complete — sequential playbook handoff with independent severity scores

---

## Phase 8: User Story 6 — Assessment Data Recording and Reporting (Priority: P2)

**Goal**: Structured assessment data persisted at session end, anonymized analytics emitted, risk flags auto-created

**Independent Test**: Complete a screening, end session, verify database records exist in assessment tables, analytics_events, and risk_flags

### Implementation for User Story 6

- [X] T038 [US6] Create cx-webhook.service.ts in chat-backend/src/services/ implementing the session-end webhook handler: parse CxMentalStatePayload, create assessment_sessions row, write assessment_items per question, write assessment_scores with severity band
- [X] T039 [US6] Add risk threshold evaluation to webhook handler: evaluate CX_DEP/CX_ANX thresholds against assessment scores, create risk_flags rows for threshold violations (critical for self-harm, urgent for severe scores) in chat-backend/src/services/cx-webhook.service.ts
- [X] T040 [US6] Add analytics event emission to webhook handler: emit assessment_completed event with instrument_type, severity_band, total_score, screening metadata using pseudonymous_user_id only, best-effort (failures logged but don't block) in chat-backend/src/services/cx-webhook.service.ts
- [X] T041 [US6] Add assessment scheduling to webhook handler: schedule next assessment using adaptive intervals (14d severe, 28d moderate, 35d mild) via existing assessment-schedule service in chat-backend/src/services/cx-webhook.service.ts
- [X] T042 [US6] Create cx-webhook.routes.ts in chat-backend/src/routes/ exposing POST /api/cx-sessions/:sessionId/mental-state endpoint with request validation per contracts/cx-webhook.yaml
- [X] T043 [US6] Register cx-webhook routes in chat-backend/src/app.ts or main router file
- [X] T044 [US6] Write unit tests for cx-webhook.service.ts: test assessment record creation, risk threshold evaluation, analytics emission, error handling (partial persistence) in chat-backend/tests/cx-webhook.test.ts

**Checkpoint**: Session-end webhook operational — assessments persisted, risk flags created, analytics emitted

---

## Phase 9: User Story 5 — Cross-Session Persistence (Priority: P2)

**Goal**: Severity scores persist across sessions via agent memory; returning users receive contextual reference to prior assessment

**Independent Test**: Complete a screening in one session, end it, start new session, verify agent references prior state

### Implementation for User Story 5

- [X] T045 [US5] Add CX screening State Timeline helper to agentMemory.service.ts in chat-backend/src/services/agentMemory/: function to create State Timeline entry from CX screening results (timestamp, instrument type, severity, yes_count, questions covered, narrative summary)
- [X] T046 [US5] Integrate State Timeline persistence into cx-webhook.service.ts: call agentMemory helper after assessment record creation, persist to GCS via existing saveAgentMemorySystemMessages in chat-backend/src/services/cx-webhook.service.ts
- [X] T047 [US5] Add cross-session reference instructions to both playbooks: when State Timeline memory contains prior screening data, reference it naturally ("Минулого разу ми говорили..."), re-assess based on current session (not prior score) in cx-agent-definition/playbooks/Depression Protocol/Depression Protocol.json and cx-agent-definition/playbooks/Anxiety Protocol/Anxiety Protocol.json
- [X] T048 [US5] Add unit test for State Timeline memory creation in chat-backend/tests/cx-webhook.test.ts

**Checkpoint**: Cross-session persistence operational — returning users get contextual continuity

---

## Phase 10: Regression Test Cases

**Purpose**: Conversation-level test cases for AI agent execution via Playwright MCP

- [X] T049 [P] Create 17-cx-depression.yaml regression test suite in regression-suite/ with test cases: depression intent detection (Ukrainian), LLM mid-conversation handoff, severity scoring (mild/moderate/severe), critical override (D16/D17/D18), self-harm crisis escalation, phased hybrid screening flow, tone adaptation verification
- [X] T050 [P] Create 18-cx-anxiety.yaml regression test suite in regression-suite/ with test cases: anxiety intent detection (Ukrainian), acute intervention mode (active panic), severity scoring, tone adaptation, Russian language intent matching, English language intent matching
- [X] T051 Add co-occurrence test case to 17-cx-depression.yaml: user expresses both depression and anxiety signals, verify sequential handoff and dual assessment records in regression-suite/17-cx-depression.yaml
- [X] T052 Add cross-session persistence test case to 17-cx-depression.yaml: complete screening, end session, start new session, verify prior state reference in regression-suite/17-cx-depression.yaml
- [X] T053 Update regression-suite/_config.yaml to include new test modules 17-cx-depression and 18-cx-anxiety with module metadata

**Checkpoint**: Regression test suite covers all user stories and edge cases

---

## Phase 11: Polish & Cross-Cutting Concerns

**Purpose**: Integration testing, deployment, and documentation

- [ ] T054 Deploy CX agent changes to Dialogflow CX dev environment (push cx-agent-definition changes via Dialogflow CX API or console)
- [ ] T055 Deploy chat-backend changes to dev environment (run migration, deploy webhook endpoint)
- [ ] T056 Configure Dialogflow CX session-end webhook to call POST /api/cx-sessions/:sessionId/mental-state on the dev backend
- [ ] T057 Run smoke regression tests (depression intent detection, anxiety intent detection, acute intervention, crisis escalation) on dev environment
- [ ] T058 Run full regression test suite (modules 17 and 18) on dev environment and record results in regression-suite/results/
- [ ] T059 Verify assessment records appear in dev database after test conversations (assessment_sessions, assessment_items, assessment_scores)
- [ ] T060 Verify risk flags are created for severe scores and self-harm detection in dev database
- [ ] T061 Verify analytics_events contain assessment_completed events with correct metadata
- [ ] T062 Verify agent memory State Timeline entries are created in GCS after test sessions
- [ ] T063 Test cross-session continuity: complete screening, end session, start new session, verify prior state reference
- [ ] T064 Test co-occurrence flow: express both depression and anxiety signals, verify sequential screening and dual records
- [ ] T065 Test trilingual support: send depression/anxiety signals in Ukrainian, Russian, and English, verify intent matching and language-appropriate responses

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion — BLOCKS all backend user stories
- **US1 Depression (Phase 3)**: Can start after Setup (CX-only, no backend dependency)
- **US2 Anxiety (Phase 4)**: Can start after Setup, parallelizable with US1 (CX-only)
- **US7+US3 Safety+Routing (Phase 5)**: Depends on US1 and US2 playbooks existing
- **US8 Trilingual (Phase 6)**: Depends on intents existing from US1 and US2
- **US4 Co-Occurrence (Phase 7)**: Depends on both playbooks being complete (Phase 3+4)
- **US6 Assessment Recording (Phase 8)**: Depends on Foundational (Phase 2) for DB schema
- **US5 Persistence (Phase 9)**: Depends on US6 webhook (Phase 8) and playbooks (Phase 3+4)
- **Regression Tests (Phase 10)**: Can start after Phase 5 (routing complete)
- **Polish (Phase 11)**: Depends on all previous phases

### Parallel Opportunities

- **Phase 3 + Phase 4**: Depression and Anxiety playbooks can be built simultaneously (different files)
- **Phase 3/4 + Phase 8**: CX agent configuration and backend webhook development can proceed in parallel
- **T028-T031**: All trilingual training phrase additions are parallelizable
- **T034 + T035**: Co-occurrence instructions for both playbooks are parallelizable
- **T049 + T050**: Both regression test suite files can be created simultaneously

### Within CX Agent Definition

```
T008 (depression intent) ──→ T009-T015 (depression playbook) ──→ T025-T026 (routing)
T016 (anxiety intent) ────→ T017-T023 (anxiety playbook) ───→ T025-T026 (routing)
                                                                      ↓
                                                               T024 (banned phrases)
                                                               T034-T037 (co-occurrence)
                                                               T028-T033 (trilingual)
                                                               T047 (cross-session instructions)
```

### Within Chat Backend

```
T004-T006 (migration) ──→ T007 (verify) ──→ T038-T043 (webhook) ──→ T045-T046 (memory)
                                                    ↓
                                             T044, T048 (tests)
```

---

## Parallel Example: CX Agent + Backend

```bash
# CX Agent work (no backend dependency):
Agent A: T008 → T009-T015 (Depression playbook)
Agent A: T016 → T017-T023 (Anxiety playbook)

# Backend work (parallel with CX agent):
Agent B: T004-T007 (Migration)
Agent B: T038-T044 (Webhook service)
Agent B: T045-T048 (Memory integration)
```

---

## Implementation Strategy

### MVP First (Depression Screening Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (DB migration)
3. Complete Phase 3: US1 — Depression Protocol
4. Complete Phase 5: Routing + Safety (partial — depression only)
5. **STOP and VALIDATE**: Test depression screening end-to-end on dev
6. Deploy/demo if ready

### Incremental Delivery

1. Setup + Foundational → Database ready
2. US1 Depression + Routing → First playbook operational (MVP)
3. US2 Anxiety → Second playbook operational
4. US7+US3 Safety + Tone → Clinical protocols complete
5. US8 Trilingual → Full language coverage
6. US4 Co-Occurrence → Dual-signal handling
7. US6 Assessment Recording → Data persistence
8. US5 Persistence → Cross-session continuity
9. Regression tests + Polish → Production-ready

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- CX agent tasks are configuration-only (JSON playbook files) — no code compilation
- Backend tasks are TypeScript (Node.js) requiring npm build + test
- Regression tests are YAML definitions executed by AI agent via Playwright MCP
- Total: 65 tasks across 11 phases

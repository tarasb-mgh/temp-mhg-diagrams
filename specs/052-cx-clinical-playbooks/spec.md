# Feature Specification: CX Agent Clinical Playbooks (Depression & Anxiety)

**Feature Branch**: `052-cx-clinical-playbooks`
**Created**: 2026-04-15
**Status**: Draft
**Input**: Extend the MHG Dialogflow CX agent with two specialized clinical playbooks (Depression Protocol, Anxiety Protocol) with hybrid routing, severity-adaptive communication protocols, and persistence via existing assessment and memory infrastructure.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Depression Signal Detection and Screening (Priority: P1)

A user in emotional distress begins chatting with the CX agent and expresses feelings of sadness, hopelessness, or loss of interest. The agent detects depression signals — either immediately through an explicit statement ("я в депресії") matched by a Dialogflow intent, or gradually through conversational cues recognized by the LLM mid-conversation. The agent transitions smoothly into the Depression Protocol playbook without announcing the switch, begins a phased screening by first mapping what the user has already shared to screening items, then naturally fills gaps for unassessed items. The agent tracks severity based on affirmative responses and adapts its communication tone accordingly.

**Why this priority**: Depression screening is the core clinical capability. Without it, the agent cannot assess or respond appropriately to the most common mental health concern users present with.

**Independent Test**: Can be tested by initiating a chat with depression-related statements and verifying the agent activates the depression playbook, conducts screening, scores severity correctly, and adapts tone.

**Acceptance Scenarios**:

1. **Given** a user sends "мене нічого не радує, я не бачу сенсу в житті", **When** the CX agent processes the message, **Then** the DEPRESSION_SIGNALS intent fires and the agent transitions to the Depression Protocol playbook
2. **Given** a user is chatting generally and mentions fatigue, sleep problems, and loss of interest across multiple messages (each distinct symptom domain counts as one signal), **When** the LLM identifies 3+ distinct symptom domains mapping to depression screening items, **Then** the Mental Help Assistant hands off to the Depression Protocol naturally
3. **Given** the Depression Protocol is active and the user has confirmed 8 out of 18 screening items, **When** the agent calculates severity, **Then** severity_level is set to "moderate" and the agent adapts to moderate-depression communication protocol
4. **Given** the user confirms item D16 (meaninglessness), **When** severity is below moderate, **Then** severity is automatically elevated to moderate regardless of total count
5. **Given** the user confirms self-harm ideation on D18 sub-question, **When** critical_flags is updated, **Then** the agent immediately activates crisis protocol with emergency contacts

---

### User Story 2 - Anxiety Signal Detection and Screening (Priority: P1)

A user contacts the CX agent describing anxiety symptoms — constant worry, panic attacks, physical symptoms like chest tightness or shaking. The agent detects anxiety signals through intent matching or LLM detection and transitions to the Anxiety Protocol. The agent screens through phased hybrid questioning and scores severity. If the user is in active distress (panic attack), the agent enters Acute Intervention Mode, providing immediate grounding techniques before any screening.

**Why this priority**: Anxiety is the second core clinical capability and equally critical for the agent's mission. Users in active panic require immediate, structured intervention.

**Independent Test**: Can be tested by chatting with anxiety-related statements and verifying intent detection, playbook activation, screening, severity scoring, and acute intervention mode.

**Acceptance Scenarios**:

1. **Given** a user sends "у мене паніка, серце вискакує з грудей, не можу дихати", **When** the CX agent processes the message, **Then** the ANXIETY_SIGNALS intent fires and the agent detects acute distress, entering Acute Intervention Mode
2. **Given** Acute Intervention Mode is active, **When** the agent responds, **Then** it provides immediate grounding steps (4-second inhale / 6-second exhale, stand up, focus on 3 objects) without long explanations or questions
3. **Given** the acute state resolves, **When** the user confirms they feel better, **Then** the agent transitions to standard anxiety screening via phased hybrid approach
4. **Given** the Anxiety Protocol is active and the user has confirmed 11 out of 16 screening items, **When** severity is calculated, **Then** severity_level is set to "severe" and the agent primarily focuses on professional referral
5. **Given** a user writes anxiety-related messages in Russian ("я постоянно тревожусь, не могу расслабиться"), **When** processed, **Then** the ANXIETY_SIGNALS intent matches and the agent responds in Russian

---

### User Story 3 - Severity-Adaptive Communication (Priority: P1)

As screening progresses and severity is determined, the agent adapts its communication style. For mild cases, the agent maintains a normal, calm tone with concrete actionable suggestions. For moderate cases, communication becomes slower and more structured, addressing one issue at a time. For severe cases, the agent uses minimal text, focuses on safety, and prioritizes professional referral.

**Why this priority**: The differentiated communication protocol is the clinical backbone — the same information delivered in the wrong tone can worsen a user's state.

**Independent Test**: Can be tested by simulating conversations at each severity level and verifying tone, structure, and content match the protocol specifications.

**Acceptance Scenarios**:

1. **Given** severity_level is "mild" for depression, **When** the agent provides recommendations, **Then** it suggests concrete minimal actions (e.g., "спробуйте прогулятися 5 хвилин") in a calm, non-dramatizing tone
2. **Given** severity_level is "moderate" for depression, **When** the agent discusses symptoms, **Then** it addresses one symptom at a time, explains it as a physiological change (not weakness), and mentions professional help non-pushily
3. **Given** severity_level is "severe" for depression, **When** the agent communicates, **Then** messages are short, step-by-step, with minimal cognitive load, focusing on safety and professional referral
4. **Given** severity_level is "moderate" for anxiety, **When** the agent responds, **Then** it works through stressors one at a time, helps build a trigger list, and avoids topic-jumping
5. **Given** a user expresses catastrophic thinking ("я знаю що помру"), **When** the agent responds, **Then** the response does NOT contain direct contradiction of the user's statement, does NOT contain phrases like "that's not true" or "you're wrong", and DOES contain a safety-focused redirect (safety check question or crisis contact information)

---

### User Story 4 - Co-Occurrence Handling (Priority: P2)

During a depression screening, the user also mentions anxiety symptoms (or vice versa). The agent notes co-occurring signals without interrupting the current playbook. After completing the primary screening and initial support, the agent transitions to the second playbook: "Ви також згадували про тривогу — можемо поговорити й про це?"

**Why this priority**: Depression and anxiety frequently co-occur. Handling this gracefully prevents missed assessments while avoiding user overwhelm.

**Independent Test**: Can be tested by expressing both depression and anxiety signals in one conversation and verifying sequential screening with two distinct severity scores.

**Acceptance Scenarios**:

1. **Given** the Depression Protocol is active and the user mentions panic attacks, **When** the agent processes this, **Then** co_occurring_signals is set to "anxiety" but the depression screening continues uninterrupted
2. **Given** the Depression Protocol completes and co_occurring_signals is "anxiety", **When** the agent transitions, **Then** it naturally invites the user to discuss anxiety concerns
3. **Given** both screenings complete, **When** persistence fires at session end, **Then** two separate assessment records are created (CX_DEP and CX_ANX) with independent severity scores

---

### User Story 5 - Cross-Session Persistence (Priority: P2)

A user who was assessed as "moderate depression" in a previous session returns for a new chat. The agent loads prior assessment state from memory and references the previous conversation naturally, then re-assesses based on the current conversation rather than assuming the prior score is still accurate.

**Why this priority**: Persistent state enables continuity of care and prevents users from having to repeat themselves, which is especially important for users with limited energy (depression) or heightened frustration (anxiety).

**Independent Test**: Can be tested by completing a screening in one session, ending it, starting a new session, and verifying the agent references prior state and adapts its approach.

**Acceptance Scenarios**:

1. **Given** a user was assessed as "moderate depression" in a prior session, **When** they start a new chat, **Then** the agent receives prior state via memory and references it naturally ("Минулого разу ми говорили про те, як ви себе почуваєте — щось змінилося?")
2. **Given** prior state is loaded with severity "moderate", **When** the user's current statements only match 2 screening items, **Then** the current session's severity_level is set based solely on the current session's yes_count (in this case "none"), independent of the prior session's severity
3. **Given** a session ends with active screening data, **When** the session-end webhook fires, **Then** a State Timeline memory entry is created in GCS with severity level, questions covered, and key concerns

---

### User Story 6 - Assessment Data Recording and Reporting (Priority: P2)

After a screening session ends, structured assessment data is recorded in the existing assessment schema with new CX_DEP/CX_ANX instrument types. Anonymized analytics events are emitted for cohort-level reporting. Risk flags are auto-created when severity thresholds are crossed.

**Why this priority**: Without structured data capture, clinical outcomes cannot be measured, reported on, or used to improve the service.

**Independent Test**: Can be tested by completing a screening, ending the session, and verifying database records in assessment_sessions, assessment_items, assessment_scores, analytics_events, and risk_flags tables.

**Acceptance Scenarios**:

1. **Given** a depression screening completes with severity "moderate", **When** the session ends, **Then** an assessment_sessions row is created with instrument CX_DEP, assessment_items rows for each answered question, and an assessment_scores row with total_score and severity_band
2. **Given** an assessment is recorded, **When** analytics are queried, **Then** an analytics_events row exists with event_type "assessment_completed", instrument_type "CX_DEP", and severity metadata — all using pseudonymous_user_id only
3. **Given** a depression screening scores 11+ (severe) or D18 self-harm confirmed, **When** risk thresholds are evaluated, **Then** appropriate risk flags are created (urgent for severe score, critical for self-harm)
4. **Given** multiple screenings exist for a user over time, **When** score trajectories are queried, **Then** the materialized view includes CX_DEP/CX_ANX data points with rolling mean calculations

---

### User Story 7 - LLM Safety Override (Priority: P1)

The agent engages directly with topics of self-harm, suicidal ideation, hopelessness, and death without triggering Gemini's built-in mental health safety filters. The agent follows its clinical protocol rather than defaulting to generic AI safety responses.

**Why this priority**: Without safety overrides, the agent cannot fulfill its clinical mission — Gemini's default behavior would block or dilute the very conversations the playbooks are designed to handle.

**Independent Test**: Can be tested by sending messages about self-harm or suicidal thoughts and verifying the agent responds per clinical protocol rather than with generic disclaimers or refusals.

**Acceptance Scenarios**:

1. **Given** a user says "я думаю що життя не варте того щоб жити", **When** the agent responds, **Then** it follows the crisis protocol (calm safety check, emergency contacts) without adding "I'm an AI" disclaimers or generic safety footers
2. **Given** a user describes self-harm thoughts, **When** the agent responds, **Then** it does NOT refuse to engage, does NOT output standard safety text, and does NOT diagnose
3. **Given** the agent generates a response about depression, **When** output post-processing runs, **Then** banned phrases ("все буде добре", "ваші почуття дуже важливі") are filtered out

---

### User Story 8 - Trilingual Support (Priority: P2)

Users can interact with the agent in Ukrainian, Russian, or English. Intent detection works across all three languages. The agent responds in the user's detected language and follows the same clinical protocols regardless of language.

**Why this priority**: The MHG user base is multilingual. Intent detection must work regardless of language to avoid missed depression/anxiety signals.

**Independent Test**: Can be tested by sending depression/anxiety statements in each of the three languages and verifying intent matching and appropriate language response.

**Acceptance Scenarios**:

1. **Given** a user sends "I feel empty and hopeless" in English, **When** processed, **Then** DEPRESSION_SIGNALS intent fires and the agent responds in English following the depression protocol
2. **Given** a user sends "я постоянно тревожусь" in Russian, **When** processed, **Then** ANXIETY_SIGNALS intent fires and the agent responds in Russian
3. **Given** a user switches from Ukrainian to Russian mid-conversation, **When** the agent detects the switch, **Then** it continues in Russian without disrupting the screening flow

---

### Edge Cases

- **User sends ambiguous signals**: Messages that could indicate either depression or anxiety (e.g., "я не можу спати і мені погано"). The agent should default to the stronger signal cluster or, if equal, begin with depression protocol (more safety-critical due to suicidal ideation path).
- **User refuses to engage with screening**: The agent should not force screening. If a user clearly wants general support, the Mental Help Assistant continues without playbook handoff.
- **Session drops mid-screening**: Partial screening state should be persisted. On reconnection, the agent can reference what was discussed without restarting from zero.
- **User explicitly asks for a diagnosis**: The agent must never provide diagnoses. It explains that it can help understand their experience but diagnosis requires a professional assessment.
- **Contradictory responses**: User says "yes" to a screening item then later contradicts it. The agent should use the most recent response for scoring.
- **Extremely low engagement**: User responds with single words or minimal input. The agent adapts by simplifying questions further and not requiring elaboration.
- **User in crisis before any screening begins**: Crisis protocol takes priority over playbook activation. The agent skips screening entirely and focuses on immediate safety.
- **LLM incorrectly maps a statement to a screening item**: The phased hybrid approach relies on the LLM inferring which screening items a user's statements cover. If the LLM incorrectly marks a screening item as confirmed (false positive), especially on high-risk items like D18 (death ideation), it could trigger unnecessary crisis escalation. Mitigation: for critical items (D16, D17, D18, and the self-harm sub-question), the playbook instructions MUST require explicit confirmation from the user rather than inference — the agent must directly ask about these items rather than inferring from context.
- **Gemini safety filter override failure**: If Gemini blocks or filters a response despite BLOCK_NONE configuration (e.g., due to model version changes or Google policy updates), the agent must not output a refusal or empty response. Fallback: the playbook instructions include a directive to follow the crisis protocol (safety check, emergency contacts, stay present) if the LLM finds itself unable to respond to a user's statement about self-harm.
- **Concurrent sessions for the same user**: If the same user has two active sessions simultaneously, each session operates independently with its own session parameters. At session end, the most recent session's assessment overwrites the State Timeline memory entry (last-write-wins). Assessment records in the append-only schema are not affected — both sessions create independent records.
- **LLM fails to detect genuine self-harm statement (false negative on D18)**: The most dangerous failure mode. Mitigation: the SUICIDAL_IDEATION intent (existing, with 24 training phrases) acts as a parallel safety net — even if the LLM within the playbook misses a self-harm statement, the Dialogflow NLU layer may still match it. Additionally, the playbook instructions MUST include a directive to proactively and directly ask about D16-D18 items during every depression screening rather than waiting for the user to volunteer these topics, reducing reliance on passive detection.
- **Gemini API unavailability or rate limiting mid-conversation**: If the LLM fails to respond (timeout, error, rate limit), the Dialogflow CX fallback flow activates. For users in crisis, the fallback MUST include static crisis contact information (112, 103, 7333) rather than an empty or generic error response.
- **Screening never completes (user goes off-topic indefinitely)**: If a screening session is active but fewer than half the scoring items have been covered after 30 conversational turns, the agent should persist partial results at session end with assessment status "abandoned" rather than "completed". Partial data is still recorded in assessment_items for whatever was covered.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST detect depression signals via a dedicated DEPRESSION_SIGNALS Dialogflow CX intent with training phrases in Ukrainian, Russian, and English (minimum 35 phrases per language)
- **FR-002**: System MUST detect anxiety signals via a dedicated ANXIETY_SIGNALS Dialogflow CX intent with training phrases in Ukrainian, Russian, and English (minimum 35 phrases per language)
- **FR-003**: The Mental Help Assistant playbook MUST monitor for depression/anxiety signals during general conversation and hand off to the appropriate specialized playbook when 3+ distinct symptom domains within one condition (depression or anxiety) are detected. Each screening item's domain counts as one signal — e.g., mood, anhedonia, sleep, energy are four separate depression signals
- **FR-004**: System MUST implement a Depression Protocol playbook with 20 screening items (D01-D20) using phased hybrid questioning (conversational mapping + natural gap-filling)
- **FR-005**: System MUST implement an Anxiety Protocol playbook with 19 screening items (A01-A19) using phased hybrid questioning
- **FR-006**: Depression severity MUST be scored on items D01-D18 only (D19 help-seeking and D20 coping are contextual questions that inform the conversation but do not contribute to the severity score). The total_score equals the count of affirmatively answered items (unweighted, binary yes/no per item, maximum 18). Severity bands: 0-3 = none, 4-6 = mild, 7-10 = moderate, 11+ = severe
- **FR-007**: If any of items D16 (meaninglessness), D17 (negative self-talk), or D18 (death ideation) is affirmed, severity MUST be elevated to at minimum "moderate" regardless of total count
- **FR-008**: If D18 sub-question (self-harm ideation) is confirmed, severity floor MUST become "severe" and crisis protocol MUST activate
- **FR-009**: Anxiety severity MUST be scored on items A01-A16 only (A17 coping, A18 social support, and A19 professional help are contextual questions that inform the conversation but do not contribute to the severity score). The total_score equals the count of affirmatively answered items (unweighted, binary yes/no per item, maximum 16). Severity bands: 0-3 = none, 4-6 = mild, 7-10 = moderate, 11+ = severe
- **FR-010**: System MUST implement Acute Intervention Mode for anxiety: when active panic symptoms are detected, bypass screening and provide immediate grounding steps (breathing technique, physical movement, sensory focus)
- **FR-011**: Communication tone and structure MUST adapt based on severity level per the defined protocols (mild = calm/actionable, moderate = slow/structured/one-at-a-time, severe = minimal/safety-first/professional-referral)
- **FR-012**: System MUST track co-occurring signals for the non-active domain and transition to the second playbook after the primary completes
- **FR-013**: System MUST maintain 6 session parameters throughout the conversation: active_playbook, severity_level, yes_count, critical_flags, questions_covered, co_occurring_signals
- **FR-014**: System MUST persist assessment results at session end via the existing agent memory State Timeline in GCS
- **FR-015**: System MUST record structured assessment data in the existing assessment schema using new instrument types CX_DEP and CX_ANX
- **FR-016**: System MUST emit anonymized analytics events (event_type: assessment_completed) with severity, instrument type, and screening metadata using pseudonymous_user_id only
- **FR-017**: System MUST evaluate risk thresholds on assessment completion and auto-create risk flags (critical tier for self-harm, urgent tier for severe scores)
- **FR-018**: System MUST load prior assessment state from agent memory at session start and reference it naturally in the new conversation
- **FR-019**: Gemini safety category thresholds MUST be set to BLOCK_NONE for HARM_CATEGORY_DANGEROUS_CONTENT, HARM_CATEGORY_HARASSMENT, and HARM_CATEGORY_HATE_SPEECH on both new playbooks
- **FR-020**: Both playbooks MUST include explicit behavioral override instructions preventing AI disclaimers, generic safety footers, toxic positivity, diagnosis, and speculative language
- **FR-021**: System MUST implement a banned-phrase post-processing filter covering at minimum these categories: AI self-identification ("я лише штучний інтелект" / "я всего лишь ИИ" / "I'm just an AI"), toxic validation ("ваші почуття дуже важливі" / "ваши чувства очень важны" / "your feelings are very important"), false reassurance ("все буде добре" / "всё будет хорошо" / "everything will be okay"), and standard safety footers ("якщо ви або хтось" / "если вы или кто-то" / "if you or someone you know"). The full phrase list MUST be maintained as a configurable resource in the agent definition
- **FR-022**: Both playbooks MUST operate in Ukrainian, Russian, and English, responding in the user's detected language
- **FR-023**: Crisis protocol (safety check, emergency contacts 112/103/7333, stay present) MUST be reachable from any point in either playbook when self-harm or unresolvable acute distress is detected
- **FR-024**: Session-end webhook MUST persist final state, create assessment records, evaluate risk thresholds, schedule next assessment, and emit analytics events in a single sequential flow. Each step is best-effort: if risk threshold evaluation fails, the assessment record MUST still be persisted (no rollback). Failures in non-critical steps (analytics emission, scheduling) MUST be logged but MUST NOT prevent assessment and risk flag persistence

### Key Entities

- **Screening Item**: An individual question from the depression (D01-D20) or anxiety (A01-A19) bank, with domain classification, core question text, and conditional follow-ups
- **Severity Assessment**: A computed severity level (none/mild/moderate/severe) based on affirmative response count with critical overrides, linked to a specific instrument type (CX_DEP or CX_ANX)
- **Session State**: The set of 6 session parameters tracking active playbook, severity, question coverage, critical flags, and co-occurrence during a conversation
- **Assessment Record**: A structured record in the assessment schema (assessment_sessions + assessment_items + assessment_scores) created at session end for longitudinal tracking
- **State Timeline Entry**: A memory entry in GCS capturing assessment summary for cross-session persistence

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Agent correctly detects and activates the depression playbook for 90%+ of a predefined test suite of 30 depression-signal conversations (10 per language, covering intent-matched and LLM-detected scenarios)
- **SC-002**: Agent correctly detects and activates the anxiety playbook for 90%+ of a predefined test suite of 30 anxiety-signal conversations (10 per language)
- **SC-003**: Severity scoring matches expected level in 95%+ of 20 pre-scored test scenarios (conversations with known correct severity) when compared against manual scoring
- **SC-004**: Agent response tone matches the specified protocol for the assessed severity level — verified by the clinical team reviewing a sample of 15 conversations (5 per severity level) using a binary checklist per response: (a) no banned phrases present, (b) response length appropriate for severity, (c) no diagnoses or speculative language, (d) actionable content matches severity level. 85%+ of individual response checks must pass across the sample
- **SC-005**: Zero instances of prohibited behaviors in evaluated conversations: no diagnoses given, no "I'm an AI" disclaimers, no toxic positivity, no aggressive contradiction of crisis statements
- **SC-006**: 100% of completed screenings result in a persisted assessment record with correct instrument type, severity band, and item responses
- **SC-007**: Acute Intervention Mode activates within the first response when active panic symptoms are detected, providing grounding steps without asking exploratory questions first
- **SC-008**: Cross-session continuity works: returning users receive a contextual reference to their prior assessment state in the opening exchange
- **SC-009**: All three languages (Ukrainian, Russian, English) trigger correct intent matching and receive responses in the user's language
- **SC-010**: Co-occurring signals are detected and the second playbook is offered after primary screening completes in 90%+ of dual-signal test conversations

## Assumptions

- The existing Dialogflow CX agent infrastructure (cx-agent-definition repository) is the deployment target and is accessible for configuration changes
- The existing assessment schema tables (assessment_sessions, assessment_items, assessment_scores) support ALTER operations to extend CHECK constraints with new instrument types
- The existing agent memory service (GCS-based State Timeline) has sufficient capacity for additional screening state entries
- The existing analytics_events table and event-instrumentation service support the assessment_completed event type for CX-originated assessments
- The existing risk_thresholds and risk_flags tables support new instrument types without schema changes (threshold_value is JSONB)
- Gemini 2.5 Flash supports BLOCK_NONE safety settings when configured through Dialogflow CX playbook generative settings
- The score_trajectories materialized view auto-includes new instrument types added to assessment_scores without view recreation (only instrument_params rows needed)
- No new frontend UI is required — existing workbench dashboards display assessment and risk flag data generically
- The CX screening instruments (CX_DEP, CX_ANX) are operational protocols, not clinically validated psychometric instruments — they do not require formal validation before deployment
- RCI parameters (SD, reliability) for the new instruments will be provisional and calibrated after sufficient data accumulates

## Out of Scope

- **Real-time clinician alerting**: Risk flags are created in the database but real-time notifications (push, SMS, email) to clinical staff are not part of this feature. Existing workbench flag views apply.
- **External crisis hotline API integration**: Emergency contacts (112, 103, 7333) are provided as text in agent responses. Automated API calls to hotline services are out of scope.
- **A/B testing or gradual rollout**: Both playbooks are deployed as-is. A/B testing infrastructure or feature flags for gradual rollout are not included.
- **New frontend UI**: No new workbench screens for viewing CX screening results. Existing assessment and risk flag views in the workbench are sufficient.
- **Chat frontend changes**: No modifications to the user-facing chat interface.
- **Formal clinical validation**: The CX_DEP and CX_ANX instruments are operational screening protocols, not validated psychometric instruments (unlike PHQ-9, GAD-7). Formal validation studies are out of scope.
- **Screening item content authoring**: The D01-D20 and A01-A19 question banks are provided as input to this feature (defined in the design document). Content authoring and clinical review of the questions themselves is complete.
- **Changes to the existing Five Acts Reflex framework**: The Mental Help Assistant playbook gains handoff instructions only. Its core behavioral framework is unchanged.

## Dependencies

- Dialogflow CX agent configuration access (cx-agent-definition repository)
- Chat-backend assessment services (assessment-sessions.service.ts, event-instrumentation.service.ts)
- Agent memory service (agentMemory.service.ts) for State Timeline persistence
- Risk threshold evaluation pipeline for auto-flag creation
- Database migration capability for extending CHECK constraints on assessment_scores

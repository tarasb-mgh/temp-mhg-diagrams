# Research: CX Agent Clinical Playbooks

**Feature**: 052-cx-clinical-playbooks
**Date**: 2026-04-15

## R1: Dialogflow CX Playbook Configuration Format

**Decision**: Use Dialogflow CX native playbook JSON format with generative model settings for Gemini 2.5 Flash.

**Rationale**: The existing "Mental Help Assistant" playbook uses this format. The playbook JSON structure supports: goal text (main instructions), step definitions, model selection (gemini-2.5-flash), temperature control, safety settings per harm category, and tool integration. This is the only supported format for Dialogflow CX playbooks.

**Alternatives considered**:
- Custom webhook-driven conversation engine: Rejected — duplicates Dialogflow CX functionality, adds latency, harder to maintain
- Vertex AI Conversation (standalone): Rejected — would require migrating away from existing Dialogflow CX infrastructure

**Key findings**:
- Playbook goal text supports up to ~32K characters of instructions (sufficient for screening banks + tone protocols)
- Safety settings are per-playbook, so overrides on Depression/Anxiety playbooks don't affect the main playbook
- Temperature 0.7 is appropriate for clinical conversations (lower than creative 1.0, higher than deterministic 0.0)
- Session parameters are accessible within playbook instructions via `$session.params.parameter_name`

## R2: Dialogflow CX Intent Training Phrase Requirements

**Decision**: 35+ training phrases per language per intent, across Ukrainian, Russian, and English.

**Rationale**: Dialogflow CX NLU model (MODEL_TYPE_ADVANCED) needs sufficient training data for reliable classification. The existing SUICIDAL_IDEATION intent has 24 phrases and works well at 0.30 threshold. Depression and anxiety signals are broader and more varied than crisis phrases, requiring more training data for reliable matching.

**Alternatives considered**:
- Fewer phrases (15-20): Rejected — higher risk of missed matches for nuanced expressions
- Regex-based matching: Rejected — Dialogflow CX uses ML-based NLU, not regex; would bypass the classification system

**Key findings**:
- Training phrases should cover: clinical language ("я в депресії"), colloquial expressions ("мені фігово"), metaphorical language ("я як робот, нічого не відчуваю"), and compound statements
- Ukrainian and Russian share some lexical overlap but have distinct expressions for emotional states
- English phrases needed for international users and multilingual speakers

## R3: Gemini Safety Category Override Behavior

**Decision**: Set BLOCK_NONE on HARM_CATEGORY_DANGEROUS_CONTENT, HARM_CATEGORY_HARASSMENT, HARM_CATEGORY_HATE_SPEECH per playbook. HARM_CATEGORY_SEXUALLY_EXPLICIT stays at BLOCK_ONLY_HIGH.

**Rationale**: The existing Mental Help Assistant already operates with BLOCK_NONE for RAI settings at the agent level. Playbook-level safety settings provide an additional layer of control. Gemini 2.5 Flash supports per-request safety settings when invoked through Dialogflow CX.

**Alternatives considered**:
- Agent-level BLOCK_NONE only (no per-playbook settings): Current state — adding per-playbook settings is defense-in-depth
- Custom safety classifier: Rejected — over-engineered for this use case

**Key findings**:
- Even with BLOCK_NONE, Gemini's base training may cause occasional refusals on extremely sensitive content (self-harm methods, explicit suicidal plans). The playbook instructions must include explicit behavioral overrides and a fallback directive.
- Google may change enforcement policies. The fallback edge case (documented in spec) addresses this risk.
- The banned-phrase filter (Layer 4) operates independently of Gemini safety settings — it's output post-processing, not input filtering.

## R4: Session Parameter Persistence in Dialogflow CX

**Decision**: Use 6 Dialogflow CX session parameters tracked by the LLM within playbook instructions, with a session-end webhook for external persistence.

**Rationale**: Dialogflow CX session parameters persist for the duration of the session and are accessible to all playbooks and flows. The LLM (Gemini) can read and update parameters as instructed in the playbook goal text. This avoids per-turn webhook latency while maintaining structured state.

**Alternatives considered**:
- Per-turn webhook for state management: Rejected — adds 100-200ms latency per turn, unnecessary for LLM-managed state
- Custom session store: Rejected — Dialogflow CX provides native session parameter support

**Key findings**:
- Session parameters are typed (string, integer) and must be defined in the agent's parameter configuration
- The LLM reliably updates parameters when explicitly instructed (e.g., "After each screening item confirmation, increment yes_count by 1 and append the item ID to questions_covered")
- Parameters survive playbook handoffs within the same session — critical for the hub-and-spoke architecture
- Parameters are included in the webhook payload at session end

## R5: Assessment Schema Extension Approach

**Decision**: ALTER existing CHECK constraint on assessment_scores.instrument_type to add CX_DEP and CX_ANX. Add rows to instrument_params for score trajectory calculations.

**Rationale**: The existing assessment schema is designed for extensibility. The instrument_type CHECK constraint is the only change needed — all other columns (total_score, severity_band, scoring_key_hash) already support the new instruments' data shapes. The append-only enforcement and GDPR erasure cascade apply automatically.

**Alternatives considered**:
- New separate table for CX assessments: Rejected — duplicates schema, loses trajectory/threshold integration
- New migration creating parallel tables: Rejected — the existing assessment pipeline handles everything needed

**Key findings**:
- The migration must be idempotent (use IF NOT EXISTS patterns where possible)
- instrument_params needs SD, reliability, and CMI threshold values — provisional values acceptable for initial deployment
- The score_trajectories materialized view auto-includes new instrument types once assessment_scores rows exist
- Risk threshold rows must be seeded in the same migration

## R6: Agent Memory State Timeline Format

**Decision**: Use existing State Timeline memory kind with screening-specific content format. Persist via updateAgentMemoryOnSessionEnd().

**Rationale**: The State Timeline category already supports timestamped state snapshots. Adding screening results as timeline entries fits the existing data model. The compaction logic preserves the last 20 entries, providing sufficient history.

**Alternatives considered**:
- New memory kind ("screening"): Rejected — would require modifying the agentMemory.service.ts compaction logic
- Survey memory kind: Considered — but Survey kind is designed for structured questionnaire responses, not screening summaries

**Key findings**:
- The State Timeline entry should include: timestamp, instrument type, severity level, yes_count, questions covered, critical flags, and a brief narrative summary
- The narrative summary helps the LLM in the next session understand context without parsing structured data
- Memory loading at session start is automatic — the Mental Help Assistant playbook receives all memory entries as system messages

## R7: Banned Phrase Post-Processing in Dialogflow CX

**Decision**: Use Dialogflow CX generator banned phrase configuration to filter prohibited output phrases.

**Rationale**: Dialogflow CX generators support configurable response post-processing including banned phrase lists. This operates at the platform level, independent of the LLM, providing a reliable safety net.

**Alternatives considered**:
- Custom webhook-based output filter: Rejected — adds latency, harder to maintain
- Rely solely on playbook instructions: Rejected — LLM instructions are probabilistic, not deterministic

**Key findings**:
- Banned phrases should be exact match and substring match (e.g., "все буде добре" should match "я впевнений що все буде добре")
- The phrase list must cover all three languages
- Generator settings are per-agent, not per-playbook — the banned phrases will apply to all playbook responses, which is acceptable since the phrases are universally undesirable

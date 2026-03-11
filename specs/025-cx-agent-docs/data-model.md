# Data Model: CX Agent Architecture Documentation

**Feature**: 025-cx-agent-docs
**Date**: 2026-03-11

This document defines the conceptual entities of the Dialogflow CX agent
(`cx-agent-definition`). These are not database entities — they are the
architectural components of the Dialogflow CX configuration.

---

## Agent

The top-level configuration object. One per Dialogflow CX project.

| Field | Type | Description |
|-------|------|-------------|
| displayName | string | "Mental Health First Responder" |
| defaultLanguageCode | string | "uk" — primary language |
| supportedLanguageCodes | string[] | ["ru", "en"] |
| timeZone | string | "Europe/Kaliningrad" |
| enableLogging | boolean | true — interaction logs enabled |
| startPlaybook | ref → Playbook | "Mental Help Assistant" — entry point |
| projectNumber | number | 942889188964 (GCP) |
| audioExportGcsDestination | string | GCS URI for conversation audio export |
| genAppBuilderSettings | object | Search engine ID for knowledge base |

**File**: `agent.json`

---

## Flow

A named conversation graph. Currently one flow exists.

| Field | Type | Description |
|-------|------|-------------|
| displayName | string | "Default Start Flow" |
| transitionRoutes | TransitionRoute[] | Routes intent matches to playbooks/pages |
| eventHandlers | EventHandler[] | Handles no-match, no-input system events |
| nluSettings | NluSettings | Model type, classification threshold |

### NluSettings

| Field | Value | Description |
|-------|-------|-------------|
| modelType | MODEL_TYPE_ADVANCED | High-quality NLU model |
| classificationThreshold | 0.30 | Minimum confidence for intent match |
| multiLanguageSettings.enableMultiLanguageDetection | true | Auto-detect language |
| supportedResponseLanguageCodes | ["ru", "en"] | Languages for generated responses |

**File**: `flows/Default Start Flow/flow.json`

---

## Intent

An NLU classification unit mapping user utterances to a named outcome.

| Field | Type | Description |
|-------|------|-------------|
| displayName | string | Intent name (e.g., SUICIDAL_IDEATION) |
| trainingPhrases | TrainingPhrase[] | Example utterances for NLU training |
| parameters | Parameter[] | Entities to extract from matched utterances |
| isFallback | boolean | True for Default Negative Intent only |
| priority | number | 500000 for all intents |
| description | string | Human-readable purpose |

### Crisis Intents (extract parameters)

| Intent | Extracts | Trigger |
|--------|----------|---------|
| SUICIDAL_IDEATION | targetperson, method | Self-harm / suicidal ideation language |
| HOMICIDAL_IDEATION | targetperson, method | Harm-to-others language |
| DELUSIONAL_THINKING | targetperson, method | Delusional or psychotic ideation language |
| REQUEST_HUMAN | method, targetperson | Escalation / live operator request |

**Files**: `intents/<intent-name>/trainingPhrases/uk.json`, `intents/<intent-name>/<intent-name>.json`

---

## Entity Type

A structured value extractor. Used by crisis intents to capture key parameters.

| Entity | Kind | Description |
|--------|------|-------------|
| Method | KIND_MAP | Maps 20+ harm methods to canonical names; fuzzy extraction on |
| TargetPerson | KIND_MAP | "myself" (self-harm) vs "them" (harm to others); fuzzy extraction on |
| RiskLevel | KIND_LIST | critical / high / medium / low / flag |

### Method Entity — Canonical Values

cutting, overdose, jumping, shooting, pills, sleeping pills, meds, tablets,
take 10 pills, razor, cut my wrists, knife, slit, bleed, jump off, bridge,
roof, building, gun, shotgun, shoot, bullet

### TargetPerson Entity — Canonical Values

- `myself` — me, my own life, myself (Ukrainian + English synonyms)
- `them` — her, him, my boss, my ex, those people (other person)

**Files**: `entityTypes/<type-name>/entityType.json`,
`entityTypes/<type-name>/entities/<language>.json`

---

## Playbook

The primary behavior definition. Combines goal statement, LLM configuration,
structured instructions, and tool references.

| Field | Type | Description |
|-------|------|-------------|
| displayName | string | "Mental Help Assistant" |
| playbookType | string | ROUTINE |
| goal | string | Trauma-informed support mission statement |
| instruction | InstructionBlock | Behavioral rules, Five Acts Reflex, crisis protocol |
| referencedTools | Tool[] | ["Mental Health Knowledge Base"] |
| llmModelSettings | LlmSettings | Model, temperature, token limits |
| tokenCount | number | 1289 (instruction token budget) |

### LlmModelSettings

| Parameter | Value |
|-----------|-------|
| model | gemini-2.5-flash |
| temperature | 1.0 |
| inputTokenLimit | INPUT_TOKEN_LIMIT_LONG |
| outputTokenLimit | OUTPUT_TOKEN_LIMIT_LONG |

**File**: `playbooks/<displayName>/<displayName>.json` (e.g., `playbooks/Mental Help Assistant/Mental Help Assistant.json`)

---

## Tool

An external capability callable by the playbook during a conversation turn.

| Field | Type | Description |
|-------|------|-------------|
| displayName | string | "Mental Health Knowledge Base" |
| toolType | string | CUSTOMIZED_TOOL (Data Store) |
| description | string | Protocols, general knowledge, conversation examples |
| dataStoreSpec | DataStoreSpec | GCS connector config, grounding, summarizer |

### DataStoreSpec

| Parameter | Value |
|-----------|-------|
| Engine type | SEARCH_ENGINE |
| Data source | GCS — `mhg-doc-connector` |
| Collection | projects/942889188964/locations/global/collections/mhg-doc-connector |
| Summarization model | gemini_25_flash_lite |
| Rewriter model | gemini_25_flash_lite |
| Grounding confidence | HIGH |
| Max snippets | 5 |

**File**: `tools/<displayName>/<displayName>.json` (e.g., `tools/Mental Health Knowledge Base/Mental Health Knowledge Base.json`)

---

## Generator

A lightweight LLM call for specific response generation tasks (e.g., fallback).

| Field | Type | Description |
|-------|------|-------------|
| displayName | string | "MHG Responder Generator" |
| model | string | gemini-2.5-flash-lite |
| temperature | float | 2.0 (maximum diversity) |
| prompt | string | Role and behavioral constraints |

**Used by**: `sys.no-match-default` and `sys.no-input-default` event handlers in Default Start Flow.

**File**: `generators/<displayName>/<displayName>.json` (e.g., `generators/MHG Responder Generator/MHG Responder Generator.json`)

---

## GenerativeSettings

Language-scoped LLM and safety configuration that applies globally to the agent.

| Field | Type | Description |
|-------|------|-------------|
| languageCode | string | "uk" |
| llmModelSettings.model | string | gemini-2.5-flash |
| llmModelSettings.temperature | float | 0.9 |
| raiSettings | SafetySettings | Per-category block thresholds |
| promptSecuritySettings | SecuritySettings | Injection protection config |

### RAI Settings (Responsible AI)

| Category | Block Level | Rationale |
|----------|-------------|-----------|
| DANGEROUS_CONTENT | BLOCK_NONE | Crisis discussions require this |
| SEXUALLY_EXPLICIT_CONTENT | BLOCK_NONE | Trauma-related disclosures |
| HARASSMENT | BLOCK_NONE | Interpersonal violence discussions |
| HATE_SPEECH | BLOCK_NONE | Dehumanizing experience disclosures |

### PromptSecuritySettings

| Parameter | Value |
|-----------|-------|
| enabled | true |
| sensitivityLevel | 3 |
| minQueryLength | 15 characters |

**File**: `generativeSettings/uk.json`

---

## Component Relationships

```
Agent
 └── startPlaybook ──────────────────► Playbook: Mental Help Assistant
                                              └── referencedTools ──► Tool: Mental Health KB

Agent
 └── flows ────────────────────────► Flow: Default Start Flow
                                          ├── transitionRoute ──► Intent: Default Welcome
                                          │       └── fulfillment ──► Playbook invocation
                                          ├── transitionRoute ──► Intent: SUICIDAL_IDEATION
                                          │       └── fulfillment ──► Playbook invocation
                                          ├── transitionRoute ──► Intent: HOMICIDAL_IDEATION
                                          │       └── fulfillment ──► Playbook invocation
                                          ├── transitionRoute ──► Intent: DELUSIONAL_THINKING
                                          │       └── fulfillment ──► Playbook invocation
                                          ├── transitionRoute ──► Intent: REQUEST_HUMAN
                                          │       └── fulfillment ──► Playbook invocation
                                          ├── eventHandler: no-match ──► Generator (fallback)
                                          └── eventHandler: no-input ──► Generator (fallback)

Intents (crisis)
 └── parameters ────────────────────► EntityType: Method (harm means)
                                    ► EntityType: TargetPerson (self / other)

GenerativeSettings
 └── uk.json ─────────────────────► Applied globally to all LLM calls for "uk" language
```

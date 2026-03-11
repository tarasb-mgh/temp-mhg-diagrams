# Research: CX Agent Architecture Documentation

**Feature**: 025-cx-agent-docs
**Date**: 2026-03-11
**Source**: Direct exploration of `D:\src\MHG\cx-agent-definition` (cloned 2026-03-11)

---

## Agent Identity

| Field | Value |
|-------|-------|
| Display name | Mental Health First Responder |
| GCP Project | `mental-help-global-25` (number: 942889188964) |
| Default language | `uk` (Ukrainian) |
| Supported languages | `ru` (Russian), `en` (English) |
| Time zone | Europe/Kaliningrad |
| Start playbook | Mental Help Assistant |
| Interaction logging | Enabled |
| Answer feedback | Enabled |
| Speech endpointer sensitivity | 90% |
| No-speech timeout | 5 seconds |
| Audio export | `gs://mental-health-global-conversation-history/draft` |
| GCP Search Engine | `192578e5-f119...` (Gen App Builder) |

---

## Repository Layout

```
cx-agent-definition/
├── agent.json               # Agent identity, language, GCP bindings, start playbook
├── entityTypes/
│   ├── Method/              # 20+ harm-method synonyms (KIND_MAP, fuzzy extraction on)
│   ├── TargetPerson/        # "myself" vs "them" (KIND_MAP, fuzzy extraction on)
│   └── RiskLevel/           # critical / high / medium / low / flag (KIND_LIST)
├── flows/
│   └── Default Start Flow/  # Welcome → playbook; no-match/no-input fallback events
├── intents/
│   ├── Default Welcome Intent/     # 53 greeting training phrases (uk)
│   ├── Default Negative Intent/    # Fallback (isFallback: true)
│   ├── SUICIDAL_IDEATION/          # 24 phrases; extracts targetperson + method
│   ├── HOMICIDAL_IDEATION/         # 18 phrases; extracts targetperson + method
│   ├── DELUSIONAL_THINKING/        # 22 phrases; extracts targetperson + method
│   └── REQUEST_HUMAN/              # 20 phrases; escalation to operator
├── playbooks/
│   └── Mental Help Assistant/      # Gemini 2.5 Flash, temp=1.0; Five Acts Reflex
├── tools/
│   └── Mental Health Knowledge Base/  # GCS-backed RAG; gemini_25_flash_lite summarizer
├── generativeSettings/
│   └── uk.json                     # Gemini 2.5 Flash, temp=0.9; RAI BLOCK_NONE
└── generators/
    └── MHG Responder Generator/    # Gemini 2.5 Flash-lite, temp=2.0; fallback UX
```

---

## Conversation Flow Architecture

```
User message
    │
    ▼
Default Start Flow (NLU, threshold 0.30)
    │
    ├── Intent: Default Welcome Intent
    │       └── → Mental Help Assistant (playbook)
    │
    ├── Intent: SUICIDAL_IDEATION / HOMICIDAL_IDEATION / DELUSIONAL_THINKING / REQUEST_HUMAN
    │       └── → Mental Help Assistant (playbook) with extracted params
    │
    ├── Intent: Default Negative Intent (no match, confidence < 0.30)
    │       └── Event handler → MHG Responder Generator (generative fallback)
    │
    └── Event: no-input-default
            └── Event handler → MHG Responder Generator (generative fallback)
```

---

## Playbook: Mental Help Assistant

### Goal
Trauma-informed support that preserves dignity, prevents harm, helps user feel heard,
regain safety/agency, and take a next small step.

### LLM Configuration
| Parameter | Value |
|-----------|-------|
| Model | gemini-2.5-flash |
| Temperature | 1.0 (full creativity) |
| Input token limit | INPUT_TOKEN_LIMIT_LONG |
| Output token limit | OUTPUT_TOKEN_LIMIT_LONG |
| Referenced tool | Mental Health Knowledge Base |

### Behavioral Framework (Five Acts Reflex)
When a user shares distress:
1. **Acknowledge** — one sentence
2. **Validate** — emotion/need (not harmful belief)
3. **Ground** — offer a small stabilizing option
4. **Clarify** — one open question
5. **Support** — one realistic next step

### Safety Boundaries (Immutable)
- MUST NOT provide strategies enabling self-harm or harm to others
- MUST NOT give medication dosing or change advice
- MUST NOT diagnose or present as clinician
- MUST NOT echo or agree with self-harm endorsement

### Crisis Protocol
On self-harm / "I don't want to live" signals:
1. Calm direct safety check: "Ви зараз у безпеці? Чи є ризик...?"
2. Encourage immediate help: 112 (emergency), 103 (medical)
3. Provide crisis resource: Lifeline Ukraine `7333`
4. Stay present; keep brief

### Language Policy
- Respond ONLY in user's detected language
- Ask once if uncertain: "Вам зручніше українською чи іншою мовою?"
- Never output English system-style refusals in non-English conversations

---

## Tool: Mental Health Knowledge Base

| Field | Value |
|-------|-------|
| Tool UUID | a4d27f07-c37b-41dd-b859-b53a1c5f2f0e |
| Type | CUSTOMIZED_TOOL (Dialogflow CX Data Store) |
| Engine type | SEARCH_ENGINE |
| Data source | GCS — `mhg-doc-connector` collection |
| Summarization model | gemini_25_flash_lite |
| Rewriter model | gemini_25_flash_lite |
| Grounding confidence | HIGH |
| Max snippets | 5 |

**Summarization prompt pattern**: Sources-grounded only; outputs `NOT_ENOUGH_INFORMATION` when
sources insufficient; no hallucination; language-matched; no citations unless required.

**Content management**: Documents are stored in GCS and indexed via the Gen App Builder connector.
Adding new content = uploading documents to the GCS bucket and triggering re-indexing.

---

## Generative Settings (uk.json)

| Setting | Value | Rationale |
|---------|-------|-----------|
| Model | gemini-2.5-flash | Main conversational model |
| Temperature | 0.9 | Creative but controlled |
| DANGEROUS_CONTENT | BLOCK_NONE | Crisis support requires harm discussion |
| SEXUALLY_EXPLICIT_CONTENT | BLOCK_NONE | Avoids blocking trauma discussions |
| HARASSMENT | BLOCK_NONE | Allows discussion of interpersonal violence |
| HATE_SPEECH | BLOCK_NONE | Allows discussion of dehumanizing experiences |
| Prompt injection protection | Enabled (sensitivity 3, min 15 chars) | Security |
| Knowledge connector grounding | HIGH | Accuracy over recall |

**Important**: The BLOCK_NONE RAI settings are deliberate and required for crisis support. Do not
change them without a clinical/product review.

---

## Generator: MHG Responder Generator

| Parameter | Value |
|-----------|-------|
| Generator UUID | 5994d2e3-b731-4cd7-ba57-6e8fdd708143 |
| Model | gemini-2.5-flash-lite |
| Temperature | 2.0 (maximum — for diverse fallback responses) |
| topP | 0.95 |
| topK | 40 |
| Max tokens | 1024 |
| Prompt | "You are a helpful mental help first responder. Be polite, empathetic and strictly follow the rules" |

Used by: Default Start Flow `sys.no-match-default` and `sys.no-input-default` event handlers.

---

## Git Integration

| Field | Value |
|-------|-------|
| GitHub repository | https://github.com/MentalHelpGlobal/cx-agent-definition |
| Branch | `main` |
| Access token (GCP Secret) | `projects/942889188964/secrets/github-cx-agent-token/versions/latest` |
| IAM required | `secretmanager.secretAccessor` on `github-cx-agent-token` for Dialogflow service agent |
| Dialogflow service agent | `service-942889188964@gcp-sa-dialogflow.iam.gserviceaccount.com` |

**Push**: Writes the current Dialogflow CX agent configuration to the `main` branch of the GitHub
repository — full snapshot of all flows, intents, playbooks, tools, entity types, etc.

**Restore**: Reads from the GitHub repository and overwrites the Dialogflow CX agent configuration.

**Workflow for changes**:
1. Pull the latest from Dialogflow CX via Restore (if starting from UI edits)
2. OR edit JSON files locally in the cloned repo
3. Commit and push to `main`
4. Trigger Push in Dialogflow CX Git integration (or it syncs on next agent load)

---

## Decisions and Rationale

| Decision | Choice | Rationale |
|----------|--------|-----------|
| NLU classification threshold | 0.30 | Permissive; mental health conversations are semantically varied |
| Language model | Gemini 2.5 Flash | Balances quality and cost; supports long context for playbook instructions |
| RAI safety level | BLOCK_NONE (all categories) | Crisis support requires discussing dangerous topics; LLM refusals would harm users in crisis |
| Grounding confidence | HIGH | Prevent hallucinated mental health advice; accuracy over coverage |
| Fallback generator temperature | 2.0 | Maximize variety in fallback responses to avoid "scripted" feel |
| Knowledge base storage | GCS-backed connector | Allows non-developers to add content without code changes |
| Multi-language support | uk (primary) + ru + en | Serves Ukrainian users post-2022 conflict; Russian and English for diaspora |

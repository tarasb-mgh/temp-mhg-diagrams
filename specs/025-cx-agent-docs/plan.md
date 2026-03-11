# Implementation Plan: Dialogflow CX Agent — Architecture Documentation

**Branch**: `025-cx-agent-docs` | **Date**: 2026-03-11 | **Spec**: [specs/025-cx-agent-docs/spec.md](./spec.md)
**Input**: Feature specification from `/specs/025-cx-agent-docs/spec.md`

## Summary

Document the `cx-agent-definition` repository — the Dialogflow CX "Mental Health First Responder" agent — as a complete Technical Onboarding reference for developers and operators. The deliverable is documentation artifacts in `client-spec` (this plan, research.md, data-model.md, quickstart.md) plus a published Confluence Technical Onboarding page section. No code is written; `cx-agent-definition` is read-only source material.

**Status**: Confluence Technical Onboarding page updated to v10 on 2026-03-11 with the `cx-agent-definition` section covering all FR-001 through FR-009. All remaining tasks are documentation artifact generation (research.md, data-model.md, quickstart.md) and Jira Epic creation.

## Technical Context

**Language/Version**: JSON (Dialogflow CX export format — no build step)
**Primary Dependencies**: Dialogflow CX (Google Cloud), Vertex AI Search, GCS, GCP Secret Manager, Gemini 2.5 Flash
**Storage**: N/A (source repo is JSON config files; knowledge base content is in GCS, external to this repo)
**Testing**: N/A (documentation feature — acceptance verified by checklist review against Confluence page)
**Target Platform**: Dialogflow CX (GCP project `mental-help-global-25`, project number `942889188964`)
**Project Type**: Documentation + Confluence publication
**Performance Goals**: N/A
**Constraints**: Confluence publication via Atlassian MCP; cx-agent-definition repo is read-only for planning
**Scale/Scope**: 1 Confluence page section; 6 intents, 3 entity types, 1 playbook, 1 tool, 1 generator documented

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Spec-First Development | ✅ PASS | `spec.md` exists and is complete |
| II. Multi-Repository Orchestration | ✅ PASS | `cx-agent-definition` is an active target repo per constitution v3.8.1; cloned at `D:\src\MHG\cx-agent-definition` |
| III. Test-Aligned Development | ✅ N/A | Documentation feature — no code tests required |
| IV. Branch and Integration Discipline | ✅ PASS | Feature branch `025-cx-agent-docs` created; no code PRs needed (docs-only) |
| V. Privacy and Security First | ✅ PASS | No PII changes; Git integration token path documented for rotation procedure only |
| VI. Accessibility and Internationalization | ✅ N/A | No user-facing UI changes |
| VII. Split-Repository First | ✅ N/A | No code changes to split repos |
| VIII. GCP CLI Infrastructure Management | ✅ PASS | Token rotation procedure documented using `gcloud` commands |
| IX. Responsive UX and PWA | ✅ N/A | No frontend changes |
| X. Jira Traceability | ✅ PASS | Jira Epic MTB-707 created on 2026-03-11; recorded in spec.md header |
| XI. Documentation Standards | ✅ PASS | This feature IS the Technical Onboarding update (Principle XI mandate) |
| XII. Release Engineering | ✅ N/A | No deployment — pure documentation |

**All gates pass.**

## Project Structure

### Documentation (this feature)

```text
specs/025-cx-agent-docs/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Phase 0: agent component analysis
├── data-model.md        # Phase 1: Dialogflow CX entity model
├── quickstart.md        # Phase 1: developer setup and common tasks
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Material (read-only)

```text
cx-agent-definition/
├── agent.json                              # Agent identity, language, GCP binding
├── entityTypes/
│   ├── Method/Method.json                  # KIND_MAP, fuzzyExtraction=true
│   │   └── entities/uk.json               # 22 crisis-related term values
│   ├── TargetPerson/TargetPerson.json
│   │   └── entities/uk.json               # 2 values: myself / them
│   └── RiskLevel/RiskLevel.json
│       └── entities/uk.json               # 5 values: critical/high/medium/low/flag
├── flows/
│   └── Default Start Flow/
│       └── Default Start Flow.json         # Routing + no-match/no-input fallback
├── intents/
│   ├── Default Welcome Intent/
│   │   ├── Default Welcome Intent.json
│   │   └── trainingPhrases/uk.json        # 53 phrases; also en.json, ru.json
│   ├── Default Negative Intent/
│   │   └── Default Negative Intent.json   # isFallback: true
│   ├── SUICIDAL_IDEATION/
│   │   ├── SUICIDAL_IDEATION.json         # 24 phrases; params: targetperson, method
│   │   └── trainingPhrases/uk.json
│   ├── HOMICIDAL_IDEATION/
│   │   ├── HOMICIDAL_IDEATION.json        # 18 phrases; params: targetperson, method
│   │   └── trainingPhrases/uk.json
│   ├── DELUSIONAL_THINKING/
│   │   ├── DELUSIONAL_THINKING.json       # 22 phrases; params: targetperson, Method
│   │   └── trainingPhrases/uk.json
│   └── REQUEST_HUMAN/
│       ├── REQUEST_HUMAN.json             # 20 phrases; params: method, targetperson
│       └── trainingPhrases/uk.json
├── playbooks/
│   └── Mental Help Assistant/
│       └── Mental Help Assistant.json     # LLM behavior, Five Acts Reflex, crisis protocol
├── tools/
│   └── Mental Health Knowledge Base/
│       └── Mental Health Knowledge Base.json  # GCS data store, gemini_25_flash_lite summarizer
├── generativeSettings/
│   └── uk.json                            # Gemini 2.5 Flash; BLOCK_NONE RAI for all categories
└── generators/
    └── MHG Responder Generator/
        ├── MHG Responder Generator.json   # gemini-2.5-flash-lite, temp=2.0
        └── phrases/uk.json
```

### Target (write)

```text
Confluence:
└── Technical Onboarding (8847361)
    └── ## cx-agent-definition Repository   ← updated to v10 on 2026-03-11
```

**Structure Decision**: Documentation-only. No source code written. All changes are confined to: (a) `specs/025-cx-agent-docs/` artifact files in `client-spec`, (b) the Confluence Technical Onboarding page via Atlassian MCP.

## Complexity Tracking

No constitution violations. No complexity justifications needed.

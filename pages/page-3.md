# 3. Conversational Agent Architecture

**What this is:** The Dialogflow CX agent's internal structure and its external dependencies.

---

## Agent Overview

| Property | Value |
|---|---|
| Agent ID | `projects/mental-help-global-25/locations/global/agents/192578e5-f119-436e-9718-abb9d9d1c8b1` |
| Display Name | Mental Health First Responder |
| Default Language | uk (Ukrainian) |
| Time Zone | Europe/Kaliningrad |
| LLM Backend | gemini-2.5-flash (via Dialogflow CX generative settings) |
| Safety Settings | `BLOCK_NONE` for clinical mission (DANGEROUS_CONTENT, HARASSMENT, HATE_SPEECH, SEXUALLY_EXPLICIT_CONTENT) |
| Deployment Method | REST API only (not "Restore from Git") |
| Source Repository | `MentalHelpGlobal/cx-agent-definition` (branch: `main`) |

---

## Agent Structure

```mermaid
graph TB
    AGENT["Dialogflow CX Agent\nMental Health First Responder"]

    subgraph Flows["Flows"]
        F_DEFAULT["Default Start Flow\n(3 transition routes)"]
    end

    subgraph Playbooks["Playbooks"]
        P_MAIN["Mental Help Assistant\nTrauma-informed support assistant"]
        P_DEP["Depression Protocol\nScreening & severity scoring"]
        P_ANX["Anxiety Protocol\nScreening & acute intervention"]
    end

    subgraph Intents["Intents"]
        I_DEP["DEPRESSION_SIGNALS"]
        I_ANX["ANXIETY_SIGNALS"]
        I_SUI["SUICIDAL_IDEATION"]
        I_HOM["HOMICIDAL_IDEATION"]
        I_DEL["DELUSIONAL_THINKING"]
        I_REQ["REQUEST_HUMAN"]
        I_WEL["Default Welcome Intent"]
        I_NEG["Default Negative Intent"]
    end

    subgraph Tools["Tools"]
        T_KB["Mental Health Knowledge Base\nData Store (Vertex AI Search)"]
    end

    AGENT --> F_DEFAULT
    F_DEFAULT --> P_MAIN
    P_MAIN --> P_DEP
    P_MAIN --> P_ANX
    P_DEP --> I_DEP
    P_ANX --> I_ANX
    P_MAIN --> I_SUI
    P_MAIN --> I_HOM
    P_MAIN --> I_DEL
    P_MAIN --> I_REQ
    P_MAIN --> I_WEL
    P_MAIN --> I_NEG
    P_MAIN --> T_KB
```

---

## Resource Inventory

| Resource Type | Name | Display Name | Purpose |
|---|---|---|---|
| Playbook | Mental Help Assistant | Mental Help Assistant | Trauma-informed support assistant |
| Playbook | Depression Protocol | Depression Protocol | Depression screening & severity scoring |
| Playbook | Anxiety Protocol | Anxiety Protocol | Anxiety screening & acute intervention |
| Intent | DEPRESSION_SIGNALS | DEPRESSION_SIGNALS | Detects depression signals (0 params) |
| Intent | ANXIETY_SIGNALS | ANXIETY_SIGNALS | Detects anxiety signals (0 params) |
| Intent | SUICIDAL_IDEATION | SUICIDAL_IDEATION | Crisis detection (2 params) |
| Intent | HOMICIDAL_IDEATION | HOMICIDAL_IDEATION | Crisis detection (2 params) |
| Intent | DELUSIONAL_THINKING | DELUSIONAL_THINKING | Crisis detection (2 params) |
| Intent | REQUEST_HUMAN | REQUEST_HUMAN | Handoff request (2 params) |
| Intent | Default Welcome Intent | Default Welcome Intent | Greeting (0 params) |
| Intent | Default Negative Intent | Default Negative Intent | Fallback (0 params) |
| Flow | Default Start Flow | Default Start Flow | Entry point with 3 transition routes |
| Tool | Mental Health Knowledge Base | Mental Health Knowledge Base | Data Store containing protocols and knowledge |

---

## External Dependencies

```mermaid
flowchart LR
    subgraph Backend["chat-backend"]
        WEBHOOK["cx-webhook.service.ts\nSession-end webhook"]
    end

    subgraph GCP["GCP"]
        CX["Dialogflow CX Agent"]
        VA["Vertex AI\ngemini-2.5-flash"]
        DS["Data Store\nMental Health Knowledge Base"]
        GCS["Cloud Storage\nState Timeline"]
        SQL["Cloud SQL\nStructured Assessments"]
    end

    WEBHOOK -->|POST| CX
    CX -->|LLM call| VA
    CX -->|knowledge retrieval| DS
    CX -->|state persistence| GCS
    WEBHOOK -->|assessment write| SQL
```

---

## Configuration Sources

| What the agent needs | Where it comes from | How it's deployed |
|---|---|---|
| Playbook instructions | `cx-agent-definition` repo, `playbooks/*.json` | Manual `curl PATCH` to Dialogflow CX API |
| Intent training phrases | `cx-agent-definition` repo, `intents/{NAME}/trainingPhrases/{lang}.json` | Manual `curl POST` to Dialogflow CX API |
| Generative settings (RAI) | `cx-agent-definition` repo, `generativeSettings/uk.json` | Manual `curl PATCH` to Dialogflow CX API |
| Referenced tools | Full resource paths in playbook JSON | Deployed with playbook |
| Data store corpus | Vertex AI Search data store | Managed via Vertex AI Console / API |

---

**Last Verified:** 2026-05-08 by Taras Bobrovytskyi
**Regeneration:** Inspect `cx-agent-definition` repo contents.

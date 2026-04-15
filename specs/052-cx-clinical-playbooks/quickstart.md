# Quickstart: CX Agent Clinical Playbooks

**Feature**: 052-cx-clinical-playbooks
**Date**: 2026-04-15

## Prerequisites

- Access to the `cx-agent-definition` repository (Dialogflow CX agent source)
- Access to the `chat-backend` repository
- Google Cloud project `mental-health-global-25` with Dialogflow CX API enabled
- Dialogflow CX console access for agent deployment
- PostgreSQL database access for migration execution
- Node.js 20+ for backend development

## Setup Steps

### 1. Clone repositories

```bash
git clone git@github.com:MentalHelpGlobal/cx-agent-definition.git
git clone git@github.com:MentalHelpGlobal/chat-backend.git
```

### 2. Create feature branches

```bash
cd cx-agent-definition && git checkout -b 052-cx-clinical-playbooks
cd ../chat-backend && git checkout -b 052-cx-clinical-playbooks
```

### 3. Backend: Run database migration

```bash
cd chat-backend
npm install
# Apply migration to extend assessment_scores CHECK constraint
# and seed instrument_params + risk_thresholds rows
npm run migrate
```

### 4. Backend: Implement webhook endpoint

The webhook endpoint at `POST /api/cx-sessions/:sessionId/mental-state` receives session-end data from Dialogflow CX and:
1. Creates assessment_sessions + assessment_items + assessment_scores records
2. Evaluates risk thresholds and creates risk_flags
3. Updates agent memory State Timeline via agentMemory.service
4. Emits analytics_events (best-effort)

### 5. CX Agent: Create intents

In `cx-agent-definition/intents/`, create:
- `DEPRESSION_SIGNALS/DEPRESSION_SIGNALS.json` — 35+ training phrases per language (uk/ru/en)
- `ANXIETY_SIGNALS/ANXIETY_SIGNALS.json` — 35+ training phrases per language (uk/ru/en)

### 6. CX Agent: Create playbooks

In `cx-agent-definition/playbooks/`, create:
- `Depression Protocol/Depression Protocol.json` — screening items D01-D20, severity scoring, tone protocols, safety overrides
- `Anxiety Protocol/Anxiety Protocol.json` — screening items A01-A19, severity scoring, acute intervention mode, safety overrides

### 7. CX Agent: Update routing

In `cx-agent-definition/flows/Default Start Flow/`, add transition routes:
- DEPRESSION_SIGNALS intent → Depression Protocol playbook
- ANXIETY_SIGNALS intent → Anxiety Protocol playbook

### 8. CX Agent: Update Mental Help Assistant

Add mid-conversation signal detection and handoff instructions to the existing Mental Help Assistant playbook goal text.

### 9. Deploy and test

```bash
# Deploy CX agent changes via Dialogflow CX console or API
# Deploy backend changes via CI/CD pipeline
# Run regression test suite
```

## Verification

1. Send a depression-signal message in Ukrainian — verify Depression Protocol activates
2. Send an anxiety-signal message in Russian — verify Anxiety Protocol activates
3. Complete a full depression screening — verify severity scoring and tone adaptation
4. Trigger crisis protocol via D18 self-harm — verify emergency contacts provided
5. End session — verify assessment records in database and memory entry in GCS
6. Start new session — verify prior state is referenced

# Quickstart: cx-agent-definition Developer Guide

**Feature**: 025-cx-agent-docs
**Date**: 2026-03-11
**Repository**: https://github.com/MentalHelpGlobal/cx-agent-definition
**Local path**: `D:\src\MHG\cx-agent-definition`

---

## Prerequisites

- Git installed and authenticated to `MentalHelpGlobal` GitHub org
- GCP CLI (`gcloud`) configured for project `mental-help-global-25`
- Access to Dialogflow CX console: https://dialogflow.cloud.google.com/
- Agent: **Mental Health First Responder** (project `mental-help-global-25`)

---

## Clone the Repository

```bash
git clone https://github.com/MentalHelpGlobal/cx-agent-definition D:/src/MHG/cx-agent-definition
```

The repository contains the exported configuration of the Dialogflow CX agent. All files are
JSON — no build step is required to read or edit them.

---

## Repository Layout

```
cx-agent-definition/
├── agent.json                    # Agent identity, language settings, GCP bindings
├── entityTypes/
│   ├── Method/                   # Harm-method entity (20+ values, fuzzy match)
│   ├── TargetPerson/             # Self vs. others entity
│   └── RiskLevel/                # Risk severity (critical/high/medium/low/flag)
├── flows/
│   └── Default Start Flow/       # Conversation routing + fallback event handlers
│       └── flow.json
├── intents/
│   ├── Default Welcome Intent/   # Greeting detection (53 training phrases)
│   ├── Default Negative Intent/  # Fallback (isFallback: true)
│   ├── SUICIDAL_IDEATION/        # Crisis: self-harm ideation
│   ├── HOMICIDAL_IDEATION/       # Crisis: harm-to-others ideation
│   ├── DELUSIONAL_THINKING/      # Mental health concern
│   └── REQUEST_HUMAN/            # Escalation to live operator
├── playbooks/
│   └── <uuid>/                   # Mental Help Assistant
│       └── playbook.json
├── tools/
│   └── <uuid>/                   # Mental Health Knowledge Base (GCS-backed)
│       └── tool.json
├── generativeSettings/
│   └── uk.json                   # LLM config + RAI safety settings
└── generators/
    └── <uuid>/                   # MHG Responder Generator (fallback responses)
        └── generator.json
```

---

## Common Change Tasks

### Add a training phrase to an intent

1. Open `intents/<intent-name>/trainingPhrases/uk.json`
2. Add a new entry following the existing format:
   ```json
   {
     "parts": [{ "text": "your new phrase" }],
     "repeatCount": 1,
     "languageCode": "uk"
   }
   ```
3. Commit and push to `main`
4. In Dialogflow CX console → Git integration → **Push** to deploy

### Update playbook instructions

1. Open `playbooks/<uuid>/playbook.json`
2. Edit the `instruction.steps` array — each step is a structured instruction block
3. Keep the Five Acts Reflex and crisis protocol intact (see `research.md`)
4. Commit, push to `main`, then Push in Dialogflow CX

### Add a new entity value to Method

1. Open `entityTypes/Method/entities/uk.json`
2. Add a new entry with `value` (canonical name) and `synonyms` array
3. Commit, push to `main`, then Push in Dialogflow CX

### Update generative settings (LLM parameters)

1. Open `generativeSettings/uk.json`
2. Edit `llmModelSettings.temperature` or other parameters
3. **Do NOT change RAI settings (BLOCK_NONE) without clinical/product review**
4. Commit, push to `main`, then Push in Dialogflow CX

### Add content to the knowledge base

The knowledge base is backed by a GCS bucket (not a file in this repo).
To add documents:
1. Upload files to the GCS bucket backing `mhg-doc-connector`
2. Trigger re-indexing in GCP → Vertex AI Search (or wait for scheduled sync)
3. No changes to this repository are needed

---

## Dialogflow CX Git Integration

The Dialogflow CX console maintains a bidirectional link to this GitHub repository.

| Setting | Value |
|---------|-------|
| Repository URL | https://github.com/MentalHelpGlobal/cx-agent-definition |
| Branch | `main` |
| Access token (GCP Secret) | `projects/942889188964/secrets/github-cx-agent-token/versions/latest` |

### Push (Dialogflow → GitHub)
Exports the current live agent configuration to the `main` branch.
Use when: you made changes in the Dialogflow CX UI and want to commit them to Git.

### Restore (GitHub → Dialogflow)
Imports the `main` branch configuration into the live agent.
Use when: you made changes to files in this repository and want to apply them.

### Token rotation
If the Push/Restore fails with an auth error:
```bash
# Verify current token still valid
gcloud secrets versions access latest \
  --secret=github-cx-agent-token \
  --project=mental-help-global-25

# Add new version with updated token
echo -n "github_pat_..." | gcloud secrets versions add github-cx-agent-token \
  --project=mental-help-global-25 --data-file=-

# Ensure Dialogflow service agent has access
gcloud secrets add-iam-policy-binding github-cx-agent-token \
  --project=mental-help-global-25 \
  --member="serviceAccount:service-942889188964@gcp-sa-dialogflow.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

---

## Accessing the Live Agent

**Dialogflow CX Console**:
https://dialogflow.cloud.google.com/ → Project `mental-help-global-25` → Mental Health First Responder

**Test in simulator**: Use the built-in simulator in the Dialogflow CX console to test intents
and playbook responses without deploying to production.

**Conversation logs**: Exported to
`gs://mental-health-global-conversation-history/draft` (interaction logging is enabled).

---

## Key Contacts / Resources

| Resource | Link |
|----------|------|
| Dialogflow CX documentation | https://cloud.google.com/dialogflow/cx/docs |
| GCP Secret Manager | https://console.cloud.google.com/security/secret-manager?project=mental-help-global-25 |
| Vertex AI Search (knowledge base) | https://console.cloud.google.com/gen-app-builder?project=mental-help-global-25 |
| GitHub repository | https://github.com/MentalHelpGlobal/cx-agent-definition |

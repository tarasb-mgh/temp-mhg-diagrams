# Data Model: Cloud Resource Tagging

**Feature**: 041-cloud-resource-tagging
**Date**: 2026-03-30

## Entities

### Label Taxonomy

The controlled vocabulary for all GCP resource labels in the MHG project.

| Label Key | Allowed Values | Description |
|-----------|---------------|-------------|
| `subsystem` | `client`, `workbench`, `delivery`, `shared` | The product area that owns the resource |
| `environment` | `dev`, `prod`, `shared` | The deployment environment the resource belongs to. `shared` is for cross-environment resources (e.g., Artifact Registry) |

**Constraints**:
- Both labels are **required** on every persistent GCP resource (unless the resource type does not support labels — see exceptions below).
- Values are lowercase, no spaces, max 63 characters (GCP label constraint).
- Adding a new subsystem or environment value requires updating only the taxonomy configuration file.

### Resource Inventory

Complete mapping of GCP resources to their target labels.

| Resource Name | Resource Type | subsystem | environment | Notes |
|---------------|--------------|-----------|-------------|-------|
| `mental-help-global-25-dev-frontend` | GCS bucket | client | dev | Chat frontend static assets |
| `mental-help-global-25-frontend` | GCS bucket | client | prod | Chat frontend static assets |
| `mental-help-global-25-chat-conversations` | GCS bucket | client | shared | Chat conversation storage |
| `chat-backend-dev` | Cloud Run service | client | dev | Chat API backend |
| `chat-backend` | Cloud Run service | client | prod | Chat API backend |
| `mental-help-global-25-dev-workbench-frontend` | GCS bucket | workbench | dev | Workbench static assets |
| `mental-help-global-25-workbench-frontend` | GCS bucket | workbench | prod | Workbench static assets |
| `workbench-backend-dev` | Cloud Run service | workbench | dev | Workbench API backend |
| `workbench-backend` | Cloud Run service | workbench | prod | Workbench API backend |
| `mental-help-global-25-delivery-frontend` | GCS bucket | delivery | prod | Delivery static assets |
| `delivery-workbench-api` | Cloud Run service | delivery | prod | Delivery API backend |
| `chat-db-dev` | Cloud SQL instance | shared | dev | Shared database (dev) |
| `chat-db` | Cloud SQL instance | shared | prod | Shared database (prod) |
| `delivery-db` | Cloud SQL instance | delivery | prod | Delivery database |
| `chat-identity-map-dev` | Cloud SQL instance | client | dev | Identity mapping DB |
| `n8n` | Cloud Run service | shared | prod | Automation platform |
| `n8n-postgres` | Cloud SQL instance | shared | prod | Automation DB |
| `chat-backend` (AR) | Artifact Registry | client | shared | Chat backend container images |
| `delivery-workbench` (AR) | Artifact Registry | delivery | shared | Delivery container images |
| `cloud-run-source-deploy` (AR) | Artifact Registry | shared | shared | Cloud Run build artifacts |
| `mhg-domain-http-fr` | Compute forwarding rule | shared | shared | GCLB HTTP ingress (global) |
| `mhg-domain-https-fr` | Compute forwarding rule | shared | shared | GCLB HTTPS ingress (global) |
| `bes-chat-backend-dev` | Compute backend service | client | dev | GCLB routing for chat API |
| `bes-chat-backend-prod` | Compute backend service | client | prod | GCLB routing for chat API |
| `bes-workbench-api-dev` | Compute backend service | workbench | dev | GCLB routing for workbench API |
| `bes-workbench-api-prod` | Compute backend service | workbench | prod | GCLB routing for workbench API |
| `bes-delivery-api` | Compute backend service | delivery | prod | GCLB routing for delivery API |
| Dialogflow CX agent | Dialogflow CX | client | — | **Exception: no label support** |
| `mhg-domain-http-redirect-map` | Compute URL map | — | — | **Exception: no label support** |
| `mhg-domain-https-map` | Compute URL map | — | — | **Exception: no label support** |

**Notes**:
- All resource names confirmed via `gcloud` queries on 2026-03-30.
- No Vertex AI endpoints found — model accessed via API, not dedicated endpoint resources.
- Dialogflow CX agent could not be queried (gcloud SDK version limitation) — documented as exception.
- Additional resources discovered: `n8n` automation platform, `delivery-db`, `chat-identity-map-dev`, multiple cloud-ai-platform buckets (excluded as ephemeral/managed).
- GCS buckets not listed (ephemeral/managed): `cloud-ai-platform-*`, `run-sources-*`, `mental-help-global-25_cloudbuild`, `mental-health-global-*`, `mental-help-global-drive-replica`, `mental-help-global-25-ai-assets`.
- Secret Manager secrets are listed separately below due to the duplication strategy.

### Secret Duplication Plan

Secrets that are currently shared will be duplicated per consuming subsystem.

| Current Secret | New Secrets After Duplication | subsystem | environment |
|---------------|------------------------------|-----------|-------------|
| `db-password` | `client-db-password`, `workbench-db-password` | per-copy | dev / prod |
| `jwt-secret` | `client-jwt-secret`, `workbench-jwt-secret` | per-copy | dev / prod |
| `jwt-refresh-secret` | `client-jwt-refresh-secret`, `workbench-jwt-refresh-secret` | per-copy | dev / prod |
| `gmail-client-id` | `client-gmail-client-id` | client | dev / prod |
| `gmail-client-secret` | `client-gmail-client-secret` | client | dev / prod |
| `gmail-refresh-token` | `client-gmail-refresh-token` | client | dev / prod |

**Constraints**:
- Each duplicated secret receives its own `subsystem` label matching the consuming subsystem.
- Service account IAM bindings must be updated to grant access to the new per-subsystem secret names.
- Existing secret references in CI/CD workflows and Cloud Run environment variables must be updated to use the new names.

## Exceptions (No Label Support)

| Resource | Reason | Mitigation |
|----------|--------|------------|
| Dialogflow CX agents | API schema has no labels field | Documented in inventory; single agent maps to `client` subsystem |
| GCLB URL maps | Compute API does not support labels on URL maps | Not a billable resource; forwarding rules are labeled instead |
| Compute backend services | gcloud API does not support labels on backend services | Not independently billable; forwarding rules are labeled instead |
| Cloud SQL instances | `--update-labels` requires `gcloud alpha` | Script uses `gcloud alpha sql instances patch` |

## State Transitions

Not applicable — labels are static metadata, not stateful entities. Labels may be updated (value changed) but do not have lifecycle states.

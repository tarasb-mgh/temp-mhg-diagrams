# Quickstart: Cloud Resource Tagging

**Feature**: 041-cloud-resource-tagging
**Date**: 2026-03-30

## Prerequisites

1. **GCP CLI authenticated** with a principal that has `resourcemanager.projects.get` and label-edit permissions on the target resources:
   ```bash
   gcloud auth login
   gcloud config set project mental-help-global-25
   ```

2. **Verify current labels** on any resource to confirm access:
   ```bash
   gcloud run services describe chat-backend-dev --region=europe-west1 --format="yaml(metadata.labels)"
   ```

3. **Clone the infrastructure repository**:
   ```bash
   git clone git@github.com:MentalHelpGlobal/chat-infra.git
   cd chat-infra
   git checkout 041-cloud-resource-tagging
   ```

## Quick Verification

After labels are applied, verify with:

```bash
# Check a Cloud Run service
gcloud run services describe chat-backend-dev --region=europe-west1 \
  --format="table(metadata.labels)"

# Check a GCS bucket
gcloud storage buckets describe gs://mental-help-global-25-dev-frontend \
  --format="table(labels)"

# Check a Cloud SQL instance
gcloud sql instances describe chat-db \
  --format="table(settings.userLabels)"

# Check a secret
gcloud secrets describe db-password \
  --format="table(labels)"
```

## Running the Compliance Audit

```bash
# From chat-infra repo root
./scripts/audit-labels.sh
```

Expected output: all resources listed with their `subsystem` and `environment` labels, any missing labels flagged.

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `PERMISSION_DENIED` when updating labels | Missing IAM role | Ensure principal has `roles/editor` or specific resource-level label permissions |
| Label update returns success but label not visible | Eventual consistency | Wait 30 seconds and re-query; GCP label updates are near-instant but console may cache |
| Secret name not found after duplication | New secret not yet created | Run the secret duplication script before updating references |
| Cloud Run service restarts after label update | `gcloud run services update` creates a new revision | This is expected behavior — the new revision uses the same image and config |

## Key Constraints

- GCP labels: max 64 per resource, keys max 63 chars, values max 63 chars, lowercase only.
- Dialogflow CX agents and GCLB URL maps do not support labels (documented exceptions).
- Secret duplication changes require corresponding updates to CI/CD workflows and Cloud Run env vars.

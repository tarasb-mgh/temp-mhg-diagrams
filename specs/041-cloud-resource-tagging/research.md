# Research: Cloud Resource Tagging

**Feature**: 041-cloud-resource-tagging
**Date**: 2026-03-30

## Decision 1: Labels vs Resource Manager Tags

**Decision**: Use GCP **labels** (key-value pairs on individual resources).

**Rationale**: Labels are the standard mechanism for cost attribution in GCP billing exports. They appear directly in billing reports and can be used for filtering in the GCP console and monitoring. Resource Manager tags are designed for org-level policy enforcement (conditional IAM, firewall rules) and are overkill for cost tracking and resource identification.

**Alternatives considered**:
- Resource Manager Tags: More powerful but designed for governance/policy, not cost attribution. Would require org-level administration. Rejected as unnecessary complexity.
- Custom metadata fields: Not standardized, not integrated with billing. Rejected.

## Decision 2: Label Key Naming

**Decision**: Use `subsystem` and `environment` as label keys.

**Rationale**: GCP labels must be lowercase with hyphens or underscores. Single-word keys are clearest. `subsystem` maps to the product area (client, workbench, delivery, shared). `environment` maps to the deployment target (dev, prod).

**Alternatives considered**:
- `env` / `svc`: Too abbreviated, unclear when reading billing reports. Rejected.
- `team` / `product`: Don't match the MHG organizational vocabulary. Rejected.

## Decision 3: GCP Label Support by Resource Type

**Decision**: All target resource types support labels natively except Dialogflow CX agents and GCLB URL maps.

| Resource Type | Label Support | gcloud Command |
|---------------|--------------|----------------|
| Cloud Run services | Yes | `gcloud run services update SERVICE --update-labels key=value --region=REGION` |
| Cloud SQL instances | Yes | `gcloud sql instances patch INSTANCE --update-labels key=value` |
| GCS buckets | Yes | `gcloud storage buckets update gs://BUCKET --update-labels key=value` |
| Secret Manager secrets | Yes | `gcloud secrets update SECRET_ID --update-labels key=value` |
| Artifact Registry repos | Yes | `gcloud artifacts repositories update REPO --location=LOCATION --update-labels key=value` |
| Vertex AI endpoints | Yes | `gcloud ai endpoints update ENDPOINT_ID --region=REGION --update-labels key=value` |
| GCLB forwarding rules | Yes | `gcloud compute forwarding-rules update RULE --global --update-labels key=value` |
| GCLB backend services | Yes | `gcloud compute backend-services update BS --global --update-labels key=value` |
| Dialogflow CX agents | **No** | N/A — no labels field in API schema |
| GCLB URL maps | **No** | N/A — no labels field in API resource |

**Rationale**: URL maps are configuration objects that don't generate independent billing line items — labeling the associated forwarding rules and backend services covers GCLB cost attribution. Dialogflow CX agents will be documented as an exception in the resource inventory.

**Alternatives considered**:
- For Dialogflow: Resource Manager tags at project level. Deferred — single Dialogflow agent doesn't justify the overhead.
- For URL maps: No alternative needed — not a billable resource type.

## Decision 4: Compliance Audit Approach

**Decision**: Per-resource-type audit script using `gcloud ... list --format` to check labels.

**Rationale**: Cloud Asset Inventory export to BigQuery is more powerful but requires BigQuery setup and is overkill for ~20 resources. A simple shell script querying each resource type and checking for required label keys is sufficient, fast (< 60 seconds), and has no additional infrastructure dependency.

**Alternatives considered**:
- Cloud Asset Inventory → BigQuery: More scalable but requires BigQuery dataset provisioning. Deferred for future if resource count grows significantly.
- Manual GCP Console checks: Not repeatable, error-prone. Rejected.

## Decision 5: Secret Duplication Strategy

**Decision**: Secrets shared across subsystems will be duplicated so each subsystem owns its own copy. Naming convention: `{subsystem}-{secret-name}` (e.g., `client-jwt-secret`, `workbench-jwt-secret`).

**Rationale**: Per the clarification decision, no secret may carry `subsystem: shared`. Duplication enables independent rotation schedules, per-subsystem access control (each service account reads only its own secrets), and clean cost attribution. With only ~6 secrets, the operational overhead is minimal.

**Alternatives considered**:
- Shared secrets with `subsystem: shared` label: Rejected by product owner — prevents clean per-subsystem cost attribution and access isolation.

## Decision 6: Label Application Method

**Decision**: Create idempotent shell scripts in `chat-infra` that apply labels to all resources. Scripts will be committed and runnable via service account.

**Rationale**: Aligns with Constitution Principle VIII (GCP CLI Infrastructure Management) — all infrastructure changes must be performed via gcloud CLI, scripted and committed to `chat-infra`. Scripts must be idempotent.

**Alternatives considered**:
- Terraform resource import + labels: Would require importing all existing resources into Terraform state. Too risky for a label-only change. Deferred to future Terraform adoption work.
- Manual Console labeling: Prohibited by constitution. Rejected.

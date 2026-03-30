# Feature Specification: Cloud Resource Tagging

**Feature Branch**: `041-cloud-resource-tagging`
**Created**: 2026-03-30
**Status**: Draft
**Jira Epic**: MTB-1003
**Input**: User description: "all the cloud resources should be tagged using the following tags: subsystem (client/workbench/delivery TBD), environment (dev, prod)"

## Clarifications

### Session 2026-03-30

- Q: What environment label should delivery workbench resources receive, given only `dev` and `prod` are allowed but delivery runs as a single environment? → A: `prod` — the single delivery environment serves production traffic.
- Q: How should Secret Manager secrets shared across subsystems be tagged? → A: Per-subsystem with duplication — shared secrets are copied so each subsystem owns its own, eliminating `shared` as a secret subsystem value.

## User Scenarios & Testing

### User Story 1 - Identify Resource Ownership by Subsystem (Priority: P1)

As an infrastructure administrator, I want every GCP resource to carry a `subsystem` label so that I can immediately determine which part of the platform (client, workbench, or delivery) owns a given resource when viewing the GCP console or running billing reports.

**Why this priority**: Without subsystem attribution, there is no way to allocate cloud costs to the correct product area or quickly identify who to contact when a resource has issues. This is the foundational tagging capability all other governance builds on.

**Independent Test**: Can be fully tested by querying GCP resources via console or CLI and confirming every resource carries the correct `subsystem` label. Delivers immediate visibility into resource ownership.

**Acceptance Scenarios**:

1. **Given** a Cloud Run service serving the chat frontend, **When** I inspect its labels in the GCP console, **Then** it shows `subsystem: client`.
2. **Given** a Cloud Run service serving the workbench frontend, **When** I inspect its labels, **Then** it shows `subsystem: workbench`.
3. **Given** a Cloud Run service serving the delivery workbench, **When** I inspect its labels, **Then** it shows `subsystem: delivery`.
4. **Given** a shared resource (e.g., Cloud SQL database used by multiple subsystems), **When** I inspect its labels, **Then** it shows `subsystem: shared`.

---

### User Story 2 - Filter Resources by Environment (Priority: P1)

As an infrastructure administrator, I want every GCP resource to carry an `environment` label (`dev` or `prod`) so that I can filter billing, monitoring, and access policies by environment.

**Why this priority**: Environment separation is critical for cost tracking, security policy enforcement, and ensuring dev resources are never confused with production resources during incident response.

**Independent Test**: Can be fully tested by filtering GCP resources by `environment` label in the console and verifying all resources appear in the correct environment grouping.

**Acceptance Scenarios**:

1. **Given** any resource in the dev project, **When** I filter by `environment: dev`, **Then** all dev-environment resources appear and no prod resources appear.
2. **Given** any resource in the prod project, **When** I filter by `environment: prod`, **Then** all prod-environment resources appear and no dev resources appear.
3. **Given** a newly provisioned resource, **When** it is created through the standard provisioning process, **Then** it automatically receives the correct `environment` label.

---

### User Story 3 - Generate Cost Reports by Subsystem and Environment (Priority: P2)

As a project manager, I want to generate cloud cost breakdowns grouped by subsystem and environment so that I can track spending per product area and compare dev vs. production costs.

**Why this priority**: Cost visibility is a key benefit of tagging but depends on the labels being in place first (US1 and US2). This story validates that the labels are useful for real-world reporting.

**Independent Test**: Can be tested by navigating to GCP Billing reports and grouping costs by `subsystem` and `environment` labels, confirming meaningful breakdowns appear.

**Acceptance Scenarios**:

1. **Given** all resources are tagged, **When** I open GCP Billing and group by `subsystem`, **Then** I see separate cost lines for client, workbench, delivery, and shared.
2. **Given** all resources are tagged, **When** I group by `environment`, **Then** I see separate cost lines for dev and prod.

---

### Edge Cases

- What happens when a new GCP resource is provisioned without tags? The provisioning process must enforce required tags or flag the omission.
- How are shared resources (e.g., a single Cloud SQL instance used by multiple subsystems) labeled? They receive `subsystem: shared`.
- What if a resource belongs to a subsystem not yet defined in the taxonomy? The provisioning process rejects unknown subsystem values.
- How are resources tagged that exist outside the two main environments (e.g., CI/CD build artifacts)? They receive `environment: ci` if environment-specific, or are excluded from the tagging requirement if ephemeral.

## Requirements

### Functional Requirements

- **FR-001**: System MUST apply a `subsystem` label with one of the allowed values (`client`, `workbench`, `delivery`, `shared`) to every persistent GCP resource.
- **FR-002**: System MUST apply an `environment` label with one of the allowed values (`dev`, `prod`, `shared`) to every persistent GCP resource. The `shared` value is reserved for resources that serve all environments (e.g., Artifact Registry).
- **FR-003**: The tagging process MUST cover all existing GCP resource types in the project: Cloud Run services, Cloud SQL instances, GCS buckets, Secret Manager secrets, Artifact Registry repositories, and load balancer configurations.
- **FR-004**: The tagging solution MUST provide a mechanism to detect untagged or incorrectly tagged resources (compliance audit).
- **FR-005**: The tagging solution MUST document the complete mapping of each GCP resource to its correct `subsystem` and `environment` values.
- **FR-006**: New resources provisioned through the standard process MUST receive both required labels at creation time.
- **FR-007**: The allowed values for each label MUST be defined in a single authoritative configuration so that future additions (new subsystems or environments) require updating only one place.
- **FR-008**: Secrets consumed by multiple subsystems MUST be duplicated so that each subsystem has its own copy, tagged with that subsystem's name. No secret may carry the `subsystem: shared` label.

### Subsystem-to-Resource Mapping

The following is the expected mapping based on the current GCP resource inventory:

| Resource | Type | Subsystem | Environment |
|----------|------|-----------|-------------|
| Chat frontend bucket | GCS | client | dev / prod |
| Chat backend service | Cloud Run | client | dev / prod |
| Workbench frontend bucket | GCS | workbench | dev / prod |
| Workbench backend service | Cloud Run | workbench | dev / prod |
| Delivery frontend bucket | GCS | delivery | prod |
| Delivery backend service | Cloud Run | delivery | prod |
| Chat database | Cloud SQL | shared | dev / prod |
| Application secrets | Secret Manager | per-subsystem (duplicated) | dev / prod |
| Container registry | Artifact Registry | shared | shared (cross-env) |
| Vertex AI endpoint | Vertex AI | shared | dev / prod |
| Dialogflow agent | Dialogflow | client | dev / prod |
| Load balancer | GCLB | shared | dev / prod |

### Key Entities

- **Label Taxonomy**: The controlled vocabulary of label keys (`subsystem`, `environment`) and their allowed values. Serves as the single source of truth for tagging compliance.
- **Resource Inventory**: The complete list of GCP resources subject to tagging, with their current and target label assignments.

## Success Criteria

### Measurable Outcomes

- **SC-001**: 100% of persistent GCP resources carry both `subsystem` and `environment` labels after implementation.
- **SC-002**: A compliance audit script can identify any untagged or mis-tagged resources within 60 seconds.
- **SC-003**: Cloud billing reports can be grouped by `subsystem` and `environment` to show per-area cost breakdowns.
- **SC-004**: The label taxonomy is defined in a single configuration artifact, and adding a new subsystem value requires changing only that one artifact.
- **SC-005**: All tagging operations complete without service disruption (zero downtime).

## Assumptions

- The GCP project `mental-help-global-25` is used for both dev and prod environments (with resource naming conventions distinguishing them), or separate projects exist per environment. The tagging approach works in either case.
- The delivery workbench operates in a single environment (not dev/prod split). Its `environment` label is `prod` since it serves production traffic.
- Ephemeral resources (CI build containers, temporary test instances) are excluded from mandatory tagging requirements.
- GCP labels have a 63-character value limit and must be lowercase — the chosen taxonomy values (`client`, `workbench`, `delivery`, `shared`, `dev`, `prod`) all comply.
- Vertex AI and Dialogflow resources support GCP labels. If any resource type does not support labels natively, the mapping will be documented in the resource inventory as an exception.

## Scope & Boundaries

### In Scope
- Defining the label taxonomy (keys, allowed values, governance rules)
- Applying labels to all existing GCP resources
- Creating a compliance audit mechanism
- Documenting the resource-to-label mapping
- Updating provisioning processes to enforce labels on new resources

### Out of Scope
- Automated cost alerting or budget policies based on labels (future enhancement)
- IAM policy changes based on labels (e.g., restricting dev access by label)
- Tagging GitHub resources or non-GCP infrastructure
- Migrating resources between projects based on environment labels

## Dependencies

- Access to the GCP project with permissions to modify resource labels
- The `chat-infra` repository where infrastructure scripts are maintained
- Knowledge of which resources belong to which subsystem (documented in the mapping table above, to be validated during implementation)

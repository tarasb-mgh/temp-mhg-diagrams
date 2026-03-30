# Tasks: Cloud Resource Tagging

**Input**: Design documents from `/specs/041-cloud-resource-tagging/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md

**Tests**: No tests explicitly requested. Compliance audit script (T010–T012) serves as the verification mechanism.

**Organization**: Tasks are grouped by user story. US1 (subsystem labels) and US2 (environment labels) are both P1 and share implementation (labels applied together via gcloud), so they are combined in Phase 3.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create the label taxonomy configuration and discover all GCP resource names

- [x] T001 Create feature branch — MTB-1007 `041-cloud-resource-tagging` in `chat-infra` repository from `develop`
- [x] T002 Create label taxonomy configuration file — MTB-1008 at chat-infra/config/label-taxonomy.json defining allowed keys (`subsystem`, `environment`) and their allowed values per data-model.md
- [x] T003 Discover and document exact GCP resource names — MTB-1009 by querying the project with gcloud CLI — replace all parenthesized placeholders in data-model.md Resource Inventory with confirmed names

**Checkpoint**: Taxonomy config committed; all resource names confirmed in data-model.md

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Create the core label application script that US1 and US2 both depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T004 Create idempotent label application script — MTB-1010 at chat-infra/scripts/apply-labels.sh that reads label-taxonomy.json and applies labels to all supported resource types using gcloud CLI commands from research.md Decision 3
- [x] T005 Add resource-type handler functions — MTB-1011 in chat-infra/scripts/apply-labels.sh for: Cloud Run services, Cloud SQL instances, GCS buckets, Secret Manager secrets, Artifact Registry repos, Vertex AI endpoints, Compute forwarding rules, Compute backend services
- [x] T006 Add --dry-run flag — MTB-1012 to chat-infra/scripts/apply-labels.sh that prints planned label changes without applying them
- [x] T007 Add --environment flag — MTB-1013 to chat-infra/scripts/apply-labels.sh to target only dev or prod resources (default: both)

**Checkpoint**: apply-labels.sh script ready with dry-run capability — can preview all label changes without applying

---

## Phase 3: User Story 1 + 2 — Apply Subsystem and Environment Labels (Priority: P1) 🎯 MVP

**Goal**: Every persistent GCP resource carries correct `subsystem` and `environment` labels

**Independent Test**: Run `chat-infra/scripts/apply-labels.sh --dry-run` then `chat-infra/scripts/apply-labels.sh` against dev environment; verify labels via `gcloud run services describe`, `gcloud storage buckets describe`, etc.

### Implementation for US1 + US2

- [x] T008 [US1] [US2] Run chat-infra/scripts/apply-labels.sh --dry-run against dev environment and verify planned labels match data-model.md Resource Inventory — MTB-1014
- [x] T009 [US1] [US2] Execute chat-infra/scripts/apply-labels.sh against dev environment — apply subsystem and environment labels to all dev resources (Cloud Run, GCS, Cloud SQL, Secret Manager, Artifact Registry, Vertex AI, GCLB components) — MTB-1015
- [x] T010 [US1] [US2] Verify dev labels by querying each resource type with gcloud CLI and confirming both `subsystem` and `environment` labels are correct per data-model.md — MTB-1016
- [x] T011 [US1] [US2] Execute chat-infra/scripts/apply-labels.sh against prod environment — apply subsystem and environment labels to all prod resources — MTB-1017
- [x] T012 [US1] [US2] Verify prod labels by querying each resource type with gcloud CLI and confirming both `subsystem` and `environment` labels are correct per data-model.md — MTB-1018

**Checkpoint**: All dev and prod resources carry correct subsystem and environment labels. US1 and US2 acceptance scenarios verifiable.

---

## Phase 4: Secret Duplication (Depends on Phase 3)

**Purpose**: Duplicate shared secrets per subsystem so no secret carries `subsystem: shared` (FR-008)

- [x] T013 Create secret duplication script at chat-infra/scripts/duplicate-secrets.sh that reads current secret values and creates per-subsystem copies using naming convention `{subsystem}-{secret-name}` per data-model.md Secret Duplication Plan — MTB-1019
- [x] T014 Add idempotency checks to chat-infra/scripts/duplicate-secrets.sh — skip creation if per-subsystem secret already exists with correct value — MTB-1020
- [x] T015 Run chat-infra/scripts/duplicate-secrets.sh --dry-run against dev environment to preview secret duplication plan — MTB-1021
- [x] T016 Execute chat-infra/scripts/duplicate-secrets.sh against dev environment — create per-subsystem secrets (client-db-password, workbench-db-password, client-jwt-secret, workbench-jwt-secret, etc.) — MTB-1022
- [x] T017 Apply subsystem and environment labels to all newly created per-subsystem secrets in dev using gcloud secrets update --update-labels — MTB-1023
- [x] T018 Update IAM bindings on new per-subsystem dev secrets — grant accessor role to the appropriate service account for each subsystem — MTB-1024
- [x] T019 Execute chat-infra/scripts/duplicate-secrets.sh against prod environment — create per-subsystem secrets for production — MTB-1025
- [x] T020 Apply subsystem and environment labels to all newly created per-subsystem secrets in prod — MTB-1026
- [x] T021 Update IAM bindings on new per-subsystem prod secrets — MTB-1027

**Checkpoint**: All per-subsystem secrets created, labeled, and accessible by correct service accounts in both environments

---

## Phase 5: User Story 3 — Compliance Audit and Cost Reporting (Priority: P2)

**Goal**: Compliance audit script detects untagged/mis-tagged resources; billing reports can group by labels

**Independent Test**: Run audit script; intentionally remove a label from one dev resource; confirm audit script flags it; restore label

### Implementation for US3

- [x] T022 [US3] Create compliance audit script at chat-infra/scripts/audit-labels.sh that queries all resource types and checks for required `subsystem` and `environment` labels — MTB-1028
- [x] T023 [US3] Add label-taxonomy.json validation to chat-infra/scripts/audit-labels.sh — verify label values are in the allowed set, flag unknown values — MTB-1029
- [x] T024 [US3] Add summary output to chat-infra/scripts/audit-labels.sh — total resources checked, compliant count, non-compliant count, exceptions list (Dialogflow CX, URL maps) — MTB-1030
- [x] T025 [US3] Run chat-infra/scripts/audit-labels.sh against dev environment and confirm 0 non-compliant resources (excluding documented exceptions) — MTB-1031
- [x] T026 [US3] Run chat-infra/scripts/audit-labels.sh against prod environment and confirm 0 non-compliant resources (excluding documented exceptions) — MTB-1032
- [x] T027 [US3] Verify GCP Billing console shows cost breakdown grouped by `subsystem` label — confirm separate lines for client, workbench, delivery, shared — MTB-1033
- [x] T028 [US3] Verify GCP Billing console shows cost breakdown grouped by `environment` label — confirm separate lines for dev and prod — MTB-1034

**Checkpoint**: Audit script runs in < 60 seconds, all resources compliant, billing reports show label-based grouping

---

## Phase 6: CI/CD Workflow Updates

**Purpose**: Ensure new deployments automatically receive correct labels (FR-006) and reference per-subsystem secrets

- [x] T029 [P] Update chat-backend CI/CD deploy workflow to add `--labels subsystem=client,environment=$ENV` to `gcloud run deploy` command — MTB-1035
- [x] T030 [P] Update chat-backend CI/CD deploy workflow to reference per-subsystem secret names (client-db-password, client-jwt-secret, client-jwt-refresh-secret) instead of shared secret names — MTB-1036
- [x] T031 [P] Update workbench-frontend CI/CD deploy workflow to add `--labels subsystem=workbench,environment=$ENV` to deploy commands — MTB-1037
- [x] T032 [P] Update workbench-backend CI/CD deploy workflow to add `--labels subsystem=workbench,environment=$ENV` to `gcloud run deploy` command — MTB-1038
- [x] T033 [P] Update workbench-backend CI/CD deploy workflow to reference per-subsystem secret names (workbench-db-password, workbench-jwt-secret, workbench-jwt-refresh-secret) instead of shared secret names — MTB-1039
- [x] T034 [P] Update delivery-workbench-backend CI/CD deploy workflow to add `--labels subsystem=delivery,environment=prod` to `gcloud run deploy` command — MTB-1040
- [x] T035 [P] Update delivery-workbench-backend CI/CD deploy workflow to reference per-subsystem secret names for delivery subsystem — MTB-1041
- [x] T036 [P] Update delivery-workbench-frontend CI/CD deploy workflow to add `--labels subsystem=delivery,environment=prod` to deploy commands — MTB-1042
- [x] T037 Deploy chat-backend to dev using updated workflow and verify labels are applied automatically on the new Cloud Run revision — MTB-1043
- [x] T038 Verify all other affected repos deploy successfully with labels and per-subsystem secret references — MTB-1044

**Checkpoint**: All CI/CD workflows apply labels at deploy time; new revisions are automatically tagged

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, cleanup, and final verification

- [x] T039 Update data-model.md Resource Inventory — replace any remaining parenthesized placeholders with confirmed resource names from T003 — MTB-1045
- [x] T040 [P] Deprecate old shared secret names by adding a `deprecated` label — do NOT delete until all references are confirmed updated — MTB-1046
- [x] T041 Run chat-infra/scripts/audit-labels.sh against both environments as final compliance verification — MTB-1047
- [x] T042 Run quickstart.md verification commands against both environments to validate the full setup — MTB-1048

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on T002 (taxonomy config) — BLOCKS all user stories
- **US1+US2 (Phase 3)**: Depends on Phase 2 completion
- **Secret Duplication (Phase 4)**: Depends on Phase 3 (labels applied first, then secrets duplicated)
- **US3 (Phase 5)**: Depends on Phase 3 (needs labeled resources to audit)
- **CI/CD Updates (Phase 6)**: Depends on Phase 4 (needs per-subsystem secret names)
- **Polish (Phase 7)**: Depends on Phases 5 and 6

### User Story Dependencies

- **US1 + US2 (P1)**: Can start after Foundational (Phase 2) — no other story dependencies
- **US3 (P2)**: Can start after Phase 3 — needs labeled resources to audit and report on

### Parallel Opportunities

- T029, T030, T031, T032, T033, T034, T035, T036 can all run in parallel (different repos, independent workflows)
- T040 can run in parallel with T041/T042

---

## Parallel Example: Phase 6 CI/CD Updates

```bash
# Launch all CI/CD workflow updates together (different repos):
Task: "Update chat-backend deploy workflow" (T029, T030)
Task: "Update workbench-frontend deploy workflow" (T031)
Task: "Update workbench-backend deploy workflow" (T032, T033)
Task: "Update delivery-workbench-backend deploy workflow" (T034, T035)
Task: "Update delivery-workbench-frontend deploy workflow" (T036)
```

---

## Implementation Strategy

### MVP First (US1 + US2 Only)

1. Complete Phase 1: Setup (taxonomy + resource discovery)
2. Complete Phase 2: Foundational (apply-labels script)
3. Complete Phase 3: US1 + US2 (apply labels to all resources)
4. **STOP and VALIDATE**: Verify all resources have correct labels in GCP console
5. Labels are immediately useful for manual cost filtering

### Incremental Delivery

1. Setup + Foundational → Script ready
2. US1 + US2 → All resources labeled → **MVP deployed**
3. Secret Duplication → Per-subsystem secrets created
4. US3 → Audit script + billing verification
5. CI/CD Updates → Future deployments auto-labeled
6. Polish → Final verification and cleanup

---

## Notes

- [P] tasks = different files/repos, no dependencies
- US1 and US2 are combined in Phase 3 because labels are applied together in a single gcloud command
- Secret duplication (Phase 4) is the highest-risk phase — create new secrets before updating any references
- Cloud Run label updates create new revisions but use the same image/config — no service disruption expected
- Dialogflow CX agents and GCLB URL maps are documented exceptions (no label support)

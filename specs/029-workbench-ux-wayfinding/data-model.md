# Data Model: Workbench UX Wayfinding (029)

## Overview

This feature is documentation-first and orchestration-focused. The data model defines planning and validation artifacts, not application runtime tables.

## Entities

### 1) RoleAuditMatrix

- Purpose: Canonical list of required roles and account status for baseline/rerun execution.
- Fields:
  - `role`: enum (`owner`, `admin`, `reviewer`, `researcher`, `group-admin`)
  - `account_ref`: string
  - `sign_in_method`: enum (`otp_fallback_dev`)
  - `baseline_status`: enum (`passed`, `blocked`, `not_run`)
  - `rerun_status`: enum (`passed`, `blocked`, `not_run`)
  - `blocker_reason`: string (optional)
  - `evidence_path`: string (optional)
- Validation rules:
  - All 5 roles must exist exactly once.
  - `sign_in_method` must be `otp_fallback_dev` for this initiative.
  - Missing role rows are invalid for acceptance.

### 2) UXFinding

- Purpose: Normalized UX issue record from baseline/rerun.
- Fields:
  - `id`: string (stable identifier)
  - `severity`: enum (`P1`, `P2`, `P3`)
  - `role`: enum (same as RoleAuditMatrix)
  - `flow`: string
  - `step`: string
  - `impact`: string
  - `evidence_path`: string
  - `suspected_cause`: string
  - `proposal`: string
  - `owner_team`: enum (`frontend`, `backend`, `product`)
  - `status`: enum (`open`, `planned`, `implemented`, `validated`)
- Validation rules:
  - `severity`, `role`, `flow`, `impact`, and `proposal` are required.
  - `evidence_path` is required for baseline defects.

### 3) RemediationItem

- Purpose: Implementation-ready backlog item routed to target repositories.
- Fields:
  - `id`: string
  - `source_finding_id`: string
  - `severity`: enum (`P1`, `P2`, `P3`)
  - `owner_repo`: enum (`workbench-frontend`, `chat-frontend-common`, `chat-backend`)
  - `target_path`: string
  - `problem`: string
  - `proposed_change`: string
  - `acceptance_check`: string
  - `dependencies`: array of strings
- Validation rules:
  - `owner_repo`, `target_path`, and `acceptance_check` are mandatory.
  - `source_finding_id` must reference an existing UXFinding.

### 4) EvidenceArtifact

- Purpose: Persist baseline/rerun screenshots and logs.
- Fields:
  - `run_type`: enum (`baseline`, `rerun`)
  - `artifact_dir`: string
  - `artifact_kind`: enum (`screenshot`, `log`, `results_json`)
  - `created_at`: datetime
  - `retention_days`: integer (`90`)
  - `contains_raw_identifiers`: boolean (`true`)
- Validation rules:
  - `retention_days` must be `90`.
  - Artifact directory must be under `artifacts/workbench-ux-audit-<timestamp>/`.

### 5) RerunGateResult

- Purpose: Formal gate outcome for acceptance.
- Fields:
  - `all_roles_completed`: boolean
  - `blocked_roles`: array of role enums
  - `p1_unresolved_count`: integer
  - `sc3_passed`: boolean
  - `sc4_passed`: boolean
  - `sc5_passed`: boolean
  - `final_status`: enum (`pass`, `fail`)
- Validation rules:
  - `final_status` must be `fail` if any role is blocked.
  - `final_status` must be `fail` if `p1_unresolved_count > 0`.

## Relationships

- `RoleAuditMatrix (1) -> (N) UXFinding` by `role`
- `UXFinding (1) -> (0..N) RemediationItem` by `source_finding_id`
- `EvidenceArtifact (N) -> (1) RoleAuditMatrix` by role/run linkage
- `RerunGateResult` aggregates RoleAuditMatrix + UXFinding + EvidenceArtifact outcomes

## Current-State Navigation Map by Role (Baseline)

The baseline run captured unauthenticated entry states only. Current-state role maps below include observed entry behavior and expected post-auth target surfaces.

| role | baseline entry state | observed menu availability | deep-flow status | known return path state |
| --- | --- | --- | --- | --- |
| owner | login screen reached | blocked before sidebar render | not reachable | not testable |
| admin | login screen reached | blocked before sidebar render | not reachable | not testable |
| reviewer | account assignment blocker | not reachable | not reachable | not testable |
| researcher | account assignment blocker | not reachable | not reachable | not testable |
| group-admin | login screen reached | blocked before sidebar render | not reachable | not testable |

## Target IA Hierarchy (Role-Aware)

This target hierarchy defines consistent section taxonomy and parent-child flow so that critical navigation actions are discoverable in three clicks or fewer.

### Level 0: Global Navigation

- Dashboard
- Reviews
- Surveys
- Groups
- Settings
- Help and Guidance

### Level 1 and Level 2 Structure

| parent section | child node | purpose | primary roles |
| --- | --- | --- | --- |
| Dashboard | Activity Overview | Current status and next actions | owner, admin, reviewer, researcher, group-admin |
| Reviews | Queue | Find reviewable sessions quickly | owner, admin, reviewer |
| Reviews | Session Detail | Review decisions and outcomes | owner, admin, reviewer |
| Surveys | Survey List | Discover available surveys | owner, admin, researcher, group-admin |
| Surveys | Survey Instance Detail | Track responses and metadata | owner, admin, researcher, group-admin |
| Groups | Group Directory | Locate active groups and ownership | owner, admin, group-admin |
| Groups | Group Detail | Manage membership and group controls | owner, admin, group-admin |
| Settings | Access and Roles | Permissions and account scopes | owner, admin |
| Help and Guidance | First-Use Tips | Contextual onboarding and next-step hints | owner, admin, reviewer, researcher, group-admin |

### Deterministic Return-Path Rules

- Each Level 2 screen must expose one explicit return path to its Level 1 parent.
- Breadcrumbs must always include Home plus at least one ancestor node.
- Post-success screens must surface one next best action link in the same section.

## State Transitions

### UXFinding.status

`open -> planned -> implemented -> validated`

- `open -> planned`: remediation item created
- `planned -> implemented`: downstream repo change completed
- `implemented -> validated`: rerun evidence confirms fix

### RerunGateResult.final_status

`fail -> pass` only when:

- all 5 roles completed
- no unresolved P1 wayfinding/discoverability blockers
- SC-003, SC-004, and SC-005 conditions met

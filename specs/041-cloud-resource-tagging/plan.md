# Implementation Plan: Cloud Resource Tagging

**Branch**: `041-cloud-resource-tagging` | **Date**: 2026-03-30 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/041-cloud-resource-tagging/spec.md`

## Summary

Apply `subsystem` and `environment` labels to all persistent GCP resources in the MHG project for cost attribution and resource governance. Create idempotent shell scripts in `chat-infra` to apply labels, duplicate shared secrets per subsystem, and provide a compliance audit mechanism. All resource types support labels natively except Dialogflow CX agents and GCLB URL maps (documented exceptions).

## Technical Context

**Language/Version**: Bash (shell scripts), gcloud CLI
**Primary Dependencies**: gcloud CLI (authenticated with project access)
**Storage**: N/A (labels are metadata on existing resources)
**Testing**: Manual verification via gcloud queries + automated audit script
**Target Platform**: GCP project `mental-help-global-25`
**Project Type**: Infrastructure automation (shell scripts in `chat-infra`)
**Performance Goals**: Audit script completes in < 60 seconds
**Constraints**: Zero downtime during label application; Cloud Run label updates create new revisions (non-disruptive)
**Scale/Scope**: ~20 GCP resources across dev and prod environments

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Spec-First Development | ✅ Pass | Spec created and clarified before planning |
| II. Multi-Repository Orchestration | ✅ Pass | Implementation targets `chat-infra` (scripts) with CI/CD updates across affected repos |
| III. Test-Aligned Development | ✅ Pass | Compliance audit script serves as verification mechanism |
| IV. Branch and Integration Discipline | ✅ Pass | Feature branch `041-cloud-resource-tagging` follows convention |
| V. Privacy and Security First | ✅ Pass | Secret duplication improves access isolation; no PII exposure |
| VI. Accessibility and i18n | N/A | Infrastructure feature, no UI |
| VI-B. Design System Compliance | N/A | No UI components |
| VII. Split-Repository First | ✅ Pass | Scripts go to `chat-infra`; CI/CD changes to affected split repos |
| VIII. GCP CLI Infrastructure Management | ✅ Pass | All changes via `gcloud` scripts committed to `chat-infra`; idempotent |
| IX. Responsive UX and PWA | N/A | No UI |
| X. Jira Traceability | ✅ Pass | Will create Jira issues during `/speckit.tasks` |
| XI. Documentation Standards | ✅ Pass | Resource inventory documented in data-model.md |
| XII. Release Engineering | ✅ Pass | Label changes are non-breaking; secret duplication requires coordinated rollout |

**Post-Phase 1 Re-check**: All gates still pass. Secret duplication introduces a cross-repo coordination dependency (CI/CD workflow updates) that must be sequenced carefully.

## Project Structure

### Documentation (this feature)

```text
specs/041-cloud-resource-tagging/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Phase 0: technical decisions
├── data-model.md        # Phase 1: label taxonomy + resource inventory
├── quickstart.md        # Phase 1: verification guide
└── tasks.md             # Phase 2 output (created by /speckit.tasks)
```

### Source Code (repository root)

```text
chat-infra/
├── config/
│   └── label-taxonomy.json       # Authoritative label key/value definitions (FR-007)
├── scripts/
│   ├── apply-labels.sh           # Idempotent label application to all resources
│   ├── audit-labels.sh           # Compliance audit: detect untagged/mis-tagged resources
│   └── duplicate-secrets.sh      # Secret duplication per subsystem (FR-008)
```

**Structure Decision**: All scripts and configuration go to `chat-infra` per Constitution Principle VIII. No application code changes except CI/CD workflow updates in affected repos to reference new per-subsystem secret names.

## Implementation Phases

### Phase 1: Label Taxonomy and Configuration

Create the authoritative `label-taxonomy.json` in `chat-infra/config/` defining allowed label keys and values. This is the single source of truth (FR-007).

### Phase 2: Label Application Script

Create `apply-labels.sh` — an idempotent script that applies `subsystem` and `environment` labels to all GCP resources per the mapping in `data-model.md`. Must handle all supported resource types with appropriate `gcloud` commands.

### Phase 3: Secret Duplication

Create `duplicate-secrets.sh` — duplicates shared secrets per subsystem with the naming convention `{subsystem}-{secret-name}`. Creates new secrets, copies values, and applies correct labels.

### Phase 4: Compliance Audit Script

Create `audit-labels.sh` — queries all resource types and reports any resources missing required labels or having incorrect values. Must complete in < 60 seconds (SC-002).

### Phase 5: CI/CD Workflow Updates

Update Cloud Run deploy workflows in affected repos to:
- Apply labels at deploy time (`--labels` flag)
- Reference new per-subsystem secret names
- Ensure new resources automatically receive required labels (FR-006)

### Phase 6: Verification and Documentation

- Run compliance audit against both environments
- Verify billing report grouping works
- Update resource inventory with confirmed resource names

## Cross-Repository Dependencies

| Repository | Changes Required | Sequence |
|------------|-----------------|----------|
| `chat-infra` | Label taxonomy config, apply/audit/duplicate scripts | First — all scripts created here |
| `chat-backend` | CI/CD workflow: add labels to deploy, update secret references | After secret duplication |
| `workbench-frontend` | CI/CD workflow: add labels to deploy | After chat-infra scripts |
| `workbench-backend` | CI/CD workflow: add labels to deploy, update secret references | After secret duplication |
| `delivery-workbench-backend` | CI/CD workflow: add labels to deploy, update secret references | After secret duplication |
| `delivery-workbench-frontend` | CI/CD workflow: add labels to deploy | After chat-infra scripts |

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Cloud Run label update creates new revision | Low — revision uses same image/config | Expected behavior; no service disruption |
| Secret duplication breaks existing deployments | High — services can't start without secrets | Sequence carefully: create new secrets first, update CI/CD references, then deprecate old names |
| Some resource types don't support labels | Low — only Dialogflow CX and URL maps | Documented exceptions; not billable resources in isolation |
| Wrong subsystem assignment | Medium — incorrect cost attribution | Compliance audit script validates against taxonomy config |

## Complexity Tracking

No constitution violations to justify.

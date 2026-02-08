<!--
  Sync Impact Report
  ==================
  Version change: 2.2.0 → 2.3.0

  Added principles:
  - VIII. GCP CLI Infrastructure Management (NEW)
    Mandates use of gcloud CLI for all cloud infrastructure changes;
    prohibits manual Console edits for reproducibility.

  Modified sections: None
  Removed sections: None

  Templates requiring updates:
  - .specify/templates/plan-template.md: ✅ Compatible (Constitution Check is generic)
  - .specify/templates/spec-template.md: ✅ Compatible (no repo-specific references)
  - .specify/templates/tasks-template.md: ✅ Compatible (path conventions are per-feature)

  Follow-up TODOs: None
-->

# Mental Health Global Client-Spec Constitution

## Core Principles

### I. Spec-First Development

All features MUST begin with a specification before any implementation work.

- Feature work starts with `/speckit.specify` to capture WHAT and WHY
- Technical planning (`/speckit.plan`) follows specification approval
- Implementation (`/speckit.implement`) only proceeds after task breakdown
- No code changes without a corresponding spec in `specs/###-feature-name/`

**Rationale**: Specifications create shared understanding, reduce rework,
and provide traceable requirements for features spanning multiple repositories.

### II. Multi-Repository Orchestration

This repository (`client-spec`) serves as the central orchestration point
for feature development across multiple codebases.

- Specifications and plans live here; implementation happens in target repos
- Primary target repositories: `chat-client` (monorepo), `chat-backend`,
  `chat-frontend`, `chat-ui`, `chat-infra`, `chat-types`, `chat-ci`
- Each spec references target repository paths explicitly
- Cross-repository dependencies MUST be documented in plan.md

**Rationale**: Centralizing specifications enables coordinated feature
development across repositories while maintaining a single source of truth
for requirements.

### III. Test-Aligned Development

Tests MUST align with each repository's established testing culture.

- **Unit tests (backend)**: Vitest in `chat-backend` and `chat-client/server`
- **Unit tests (frontend)**: Vitest + React Testing Library in `chat-frontend`
  and `chat-client/src`
- **E2E tests**: Playwright in `chat-ui` against deployed environments
- **Coverage thresholds**: Respect existing minimums (25% statements,
  15% branches)
- **Test evidence**: Before/after screenshots stored in `evidence/<task-id>/`
- Tests are OPTIONAL in task generation unless explicitly requested

**Rationale**: Both the monorepo and split repositories have their own
testing infrastructure. New features MUST integrate with existing patterns
in each target rather than introduce competing approaches.

### IV. Branch and Integration Discipline

Feature work MUST follow established branch policies.

- Feature branches: `###-feature-name` pattern (auto-numbered)
- Target integration branch: `develop` (not `main`)
- `main` is promotion-only; never commit directly
- All tests MUST pass before merge
- Squash merge for clean history
- Feature branches MUST be created in all affected repositories
  (both monorepo and split repos) using the same branch name

**Rationale**: All repositories enforce strict branch protection. Using
consistent branch names across the monorepo and split repos ensures
traceability and simplifies cross-repo coordination.

### V. Privacy and Security First

Features touching user data MUST address privacy and security
requirements upfront.

- GDPR compliance requirements documented in spec.md
- PII handling explicitly specified (masking, retention, deletion)
- Authentication/authorization changes require security review section
- Audit logging requirements for admin operations

**Rationale**: The application handles sensitive mental health data. Privacy
and security are non-negotiable and must be addressed at specification time,
not retrofitted.

### VI. Accessibility and Internationalization

User-facing features MUST maintain WCAG AA compliance and i18n support.

- Accessibility requirements included in acceptance criteria
- All user-visible text MUST support translation (uk, en, ru)
- Keyboard navigation and screen reader compatibility required
- Contrast ratios and focus indicators specified where relevant

**Rationale**: The application serves Ukrainian users seeking mental health
support. Accessibility and language support are core product requirements,
not optional enhancements.

### VII. Dual-Target Implementation Discipline

All new features MUST be implemented in both the monorepo (`chat-client`)
and the corresponding split repositories. Neither side may be treated as
secondary or deferred.

- Every implementation task MUST produce equivalent changes in both the
  monorepo and the split repo(s)
- The split repos are the canonical source for types, CI, and infra
  (`chat-types`, `chat-ci`, `chat-infra`)
- For application code, changes MUST land in both `chat-client/server`
  (backend) and `chat-backend`, and in both `chat-client/src` (frontend)
  and `chat-frontend`
- Shared type changes MUST go through `chat-types` first, then consumers
  (`chat-backend`, `chat-frontend`, `chat-client`) MUST update their
  dependency
- CI workflow changes MUST go through `chat-ci` and be tagged before
  consumers pick them up
- If a change spans multiple split repos, plan.md MUST document the
  execution order and inter-repo dependencies
- A task is NOT considered complete until the change exists in both
  the monorepo and all affected split repos

**Rationale**: The project maintains both a monorepo and split repos in
active use. Implementing in only one side creates drift that is expensive
to reconcile. Enforcing dual-target delivery keeps both architectures
consistent and deployable.

### VIII. GCP CLI Infrastructure Management

All cloud infrastructure changes MUST be performed via the `gcloud` CLI
(or equivalent GCP SDK tooling). Manual changes through the GCP Console
are prohibited for production and staging environments.

- Infrastructure modifications MUST use `gcloud` commands, scripted and
  committed to `chat-infra` (and `chat-client/infra/` per Principle VII)
- Scripts MUST be idempotent and runnable from a service account with
  appropriate IAM roles
- Ad-hoc `gcloud` commands used during development MUST be captured as
  scripts before the task is considered complete
- Terraform in `chat-infra` remains the preferred tool for declarative
  resource provisioning; `gcloud` CLI is used for imperative operations,
  one-off configurations, and deployment commands
- All `gcloud` commands MUST target the correct project
  (`mental-help-global-25`) explicitly via `--project` flag or
  pre-configured `gcloud config`
- Infrastructure changes MUST be documented in plan.md with the exact
  `gcloud` commands or script references

**Rationale**: CLI-driven infrastructure ensures reproducibility,
auditability, and version control. Manual Console changes are
untraceable, error-prone, and impossible to replicate across
environments. Scripted `gcloud` commands serve as living documentation
of the infrastructure state.

## Multi-Repository Orchestration

### Repository Roles

| Repository | Role | Path |
|------------|------|------|
| `client-spec` | Specifications, plans, task orchestration | `D:\src\MHG\client-spec` |
| `chat-types` | Shared TypeScript types (`@mentalhelpglobal/chat-types`) | `D:\src\MHG\chat-types` |
| `chat-backend` | Express.js backend API (split repo) | `D:\src\MHG\chat-backend` |
| `chat-frontend` | React frontend application (split repo) | `D:\src\MHG\chat-frontend` |
| `chat-ui` | Playwright E2E tests | `D:\src\MHG\chat-ui` |
| `chat-ci` | Reusable GitHub Actions workflows | `D:\src\MHG\chat-ci` |
| `chat-infra` | GCP infrastructure scripts + Terraform | `D:\src\MHG\chat-infra` |
| `chat-client` | Monorepo (backend + frontend, dual-target) | `D:\src\MHG\chat-client` |

### Dual-Target Reference Map

When implementing a feature, apply changes to **both** columns:

| Split Repository | Monorepo Equivalent | Notes |
|-----------------|---------------------|-------|
| `chat-backend/src/` | `chat-client/server/` | All backend code and configs |
| `chat-frontend/src/` | `chat-client/src/` | All frontend code and configs |
| `chat-types/src/` | `chat-client/src/types/` (shared) | Publish new version, update all consumers |
| `chat-ui/tests/e2e/` | `chat-client/tests/e2e/` | E2E tests and fixtures |
| `chat-ui/playwright.config.ts` | `chat-client/playwright.config.ts` | Playwright configuration |
| `chat-infra/` | `chat-client/infra/` | Infrastructure scripts |
| `chat-ci/.github/workflows/` | `chat-client/.github/workflows/` | CI/CD workflow definitions |
| `chat-backend/package.json` | `chat-client/package.json` (server/) | Backend deps and scripts |
| `chat-frontend/package.json` | `chat-client/package.json` (root) | Frontend deps and scripts |

### Dual-Target Implementation Procedure

1. **Plan**: Identify all affected split repos using the map above;
   plan.md MUST list both monorepo and split repo paths for every file
2. **Types first**: If shared types changed, bump `chat-types` version,
   publish, then update `package.json` in `chat-backend`, `chat-frontend`,
   AND `chat-client`
3. **Split repos**: Implement the feature in the split repos on feature
   branches off `develop`
4. **Monorepo**: Apply equivalent changes to `chat-client` on a matching
   feature branch, adapting import paths and project structure as needed
5. **Test both**: Run tests in the split repos AND in the monorepo to
   verify the change works in both contexts
6. **Merge both**: Merge to `develop` in all affected repositories
7. **Verify parity**: Confirm that the monorepo and split repos produce
   functionally equivalent behavior

### Artifact Flow

1. **Specification** (`client-spec`): `/speckit.specify` creates `specs/###-feature/spec.md`
2. **Planning** (`client-spec`): `/speckit.plan` generates technical design artifacts
3. **Task Breakdown** (`client-spec`): `/speckit.tasks` creates actionable task list
4. **Implementation** (target repos): Execute tasks against split repos
   (`chat-backend`, `chat-frontend`, etc.) AND monorepo (`chat-client`)
5. **Verification** (`client-spec`): Update task status, capture evidence

### Cross-Repository References

- Plan.md MUST specify target repository and paths explicitly for both
  split repos and monorepo equivalents
- Use repository name prefixes for clarity (e.g., `chat-backend/src/routes/`,
  `chat-client/server/src/routes/`)
- Shared types are published via `@mentalhelpglobal/chat-types` npm package
- CI workflows are centralized in `chat-ci` and consumed via `uses:` references
- Document any cross-repository dependencies in plan.md

## Development Workflow

### Phase Gates

| Phase | Gate Criteria | Output |
|-------|---------------|--------|
| Specification | No unresolved [NEEDS CLARIFICATION]; checklist passes | `spec.md`, `checklists/requirements.md` |
| Planning | Constitution check passes; technical context complete | `plan.md`, `research.md`, `data-model.md`, `contracts/` |
| Tasks | All user stories mapped; dependencies documented | `tasks.md` |
| Implementation | Tests pass in both monorepo and split repos; code review complete; evidence captured | Updated source in split repos AND monorepo |

### Quality Checkpoints

- **Spec Quality**: Technology-agnostic, measurable success criteria, bounded scope
- **Plan Quality**: Explicit tech stack, structure decisions documented, constitution compliance
- **Task Quality**: Checklist format (`- [ ] T### [P?] [US#] description with file path`)
- **Implementation Quality**: Tests green in both repo targets, CLAUDE.md workflow followed, evidence in `evidence/`

## Governance

This constitution supersedes ad-hoc practices for all feature development
orchestrated through `client-spec`.

### Amendment Process

1. Propose change via spec (use `/speckit.specify` with constitution amendment description)
2. Document rationale and impact on existing workflows
3. Update version according to semantic versioning:
   - MAJOR: Breaking changes to principles or workflows
   - MINOR: New principles or expanded guidance
   - PATCH: Clarifications and refinements
4. Propagate changes to dependent templates

### Compliance Verification

- All PRs/reviews MUST verify constitution compliance
- Checklist validation runs automatically via `/speckit.specify`
- Plan.md includes explicit Constitution Check section
- Non-compliance MUST be justified in Complexity Tracking section

### Reference Documents

- Backend conventions: `D:\src\MHG\chat-backend\CLAUDE.md`
- Frontend conventions: `D:\src\MHG\chat-frontend\CLAUDE.md`
- CI workflows: `D:\src\MHG\chat-ci\README.md`
- E2E tests: `D:\src\MHG\chat-ui\CLAUDE.md`
- Infrastructure: `D:\src\MHG\chat-infra\CLAUDE.md`
- Shared types: `D:\src\MHG\chat-types\package.json`
- Monorepo: `D:\src\MHG\chat-client\AGENTS.md`

**Version**: 2.3.0 | **Ratified**: 2026-02-04 | **Last Amended**: 2026-02-08

<!--
  Sync Impact Report
  ==================
  Version change: 2.0.0 → 2.1.0

  Modified principles:
  - II. Multi-Repository Orchestration: Updated primary source from chat-client to split repos
  - III. Test-Aligned Development: Updated repo references to split repos

  Added sections:
  - VII. Change Propagation Discipline (new principle)
  - Change Propagation Map (under Multi-Repository Orchestration)

  Removed sections: None

  Templates requiring updates:
  - .specify/templates/plan-template.md: ✅ Compatible (Constitution Check is generic)
  - .specify/templates/spec-template.md: ✅ Compatible (no repo-specific references)
  - .specify/templates/tasks-template.md: ✅ Compatible (task format unchanged)

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

- Specifications and plans live here; implementation happens in split repos
- Primary source repositories: `chat-backend`, `chat-frontend`, `chat-ui`,
  `chat-infra`, `chat-types`, `chat-ci`
- Each spec references target repository paths explicitly
- Cross-repository dependencies MUST be documented in plan.md

**Rationale**: Centralizing specifications enables coordinated feature
development across repositories while maintaining a single source of truth
for requirements.

### III. Test-Aligned Development

Tests MUST align with each repository's established testing culture.

- **Unit tests (backend)**: Vitest in `chat-backend`
- **Unit tests (frontend)**: Vitest + React Testing Library in `chat-frontend`
- **E2E tests**: Playwright in `chat-ui` against deployed environments
- **Coverage thresholds**: Respect existing minimums (25% statements,
  15% branches)
- **Test evidence**: Before/after screenshots stored in `evidence/<task-id>/`
- Tests are OPTIONAL in task generation unless explicitly requested

**Rationale**: Each split repository has its own testing infrastructure.
New features MUST integrate with existing patterns rather than introduce
competing approaches.

### IV. Branch and Integration Discipline

Feature work MUST follow established branch policies.

- Feature branches: `###-feature-name` pattern (auto-numbered)
- Target integration branch: `develop` (not `main`)
- `main` is promotion-only; never commit directly
- All tests MUST pass before merge
- Squash merge for clean history

**Rationale**: All split repositories enforce strict branch protection.
Specifications must align with this workflow to enable smooth handoff
from planning to implementation.

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

### VII. Change Propagation Discipline

Any change made in `chat-client` (monorepo) MUST be propagated to the
corresponding split repository before the change is considered complete.

- Changes MUST be applied to the split repo, not just the monorepo
- The propagation map below defines which monorepo path maps to which repo
- Shared type changes MUST go through `chat-types` first, then consumers
  (`chat-backend`, `chat-frontend`) MUST update their dependency
- CI workflow changes MUST go through `chat-ci` and be tagged before
  consumers pick them up
- If a change spans multiple split repos, plan.md MUST document the
  execution order and inter-repo dependencies
- During parallel operation (Phase 8), both monorepo and split repos
  MUST stay in sync; the split repo is the source of truth going forward

**Rationale**: The monorepo split is a migration, not a fork. Allowing
changes to accumulate in only one side creates drift that becomes
exponentially harder to reconcile. Enforcing immediate propagation keeps
both sides consistent until the monorepo is archived.

## Multi-Repository Orchestration

### Repository Roles

| Repository | Role | Path |
|------------|------|------|
| `client-spec` | Specifications, plans, task orchestration | `D:\src\MHG\client-spec` |
| `chat-types` | Shared TypeScript types (`@mentalhelpglobal/chat-types`) | `D:\src\MHG\chat-types` |
| `chat-backend` | Express.js backend API | `D:\src\MHG\chat-backend` |
| `chat-frontend` | React frontend application | `D:\src\MHG\chat-frontend` |
| `chat-ui` | Playwright E2E tests | `D:\src\MHG\chat-ui` |
| `chat-ci` | Reusable GitHub Actions workflows | `D:\src\MHG\chat-ci` |
| `chat-infra` | GCP infrastructure scripts + Terraform | `D:\src\MHG\chat-infra` |
| `chat-client` | **Archived** monorepo (read-only after cutover) | `D:\src\MHG\chat-client` |

### Change Propagation Map

When a change is made in `chat-client`, propagate to the split repo
using this mapping:

| Monorepo Path | Split Repository | Notes |
|---------------|-----------------|-------|
| `server/` | `chat-backend` | All backend code and configs |
| `src/` | `chat-frontend` | All frontend code and configs |
| `src/types/` (shared) | `chat-types` | Publish new version, update consumers |
| `tests/e2e/` | `chat-ui` | E2E tests and fixtures |
| `playwright.config.ts` | `chat-ui` | Playwright configuration |
| `infra/` | `chat-infra` | Infrastructure scripts |
| `.github/workflows/` | `chat-ci` | CI/CD workflow definitions |
| `package.json` (root) | `chat-frontend` | Frontend deps and scripts |
| `package.json` (`server/`) | `chat-backend` | Backend deps and scripts |

**Propagation procedure**:

1. Identify affected split repo(s) using the map above
2. Apply the change in the split repo on a feature branch off `develop`
3. If shared types changed: bump `chat-types` version, publish, update
   `package.json` in consuming repos
4. Run tests in the split repo to verify the change works in isolation
5. Merge to `develop` in the split repo
6. Optionally backport to `chat-client` if still in parallel operation

### Artifact Flow

1. **Specification** (`client-spec`): `/speckit.specify` creates `specs/###-feature/spec.md`
2. **Planning** (`client-spec`): `/speckit.plan` generates technical design artifacts
3. **Task Breakdown** (`client-spec`): `/speckit.tasks` creates actionable task list
4. **Implementation** (target repos): Execute tasks against `chat-backend`, `chat-frontend`, etc.
5. **Verification** (`client-spec`): Update task status, capture evidence

### Cross-Repository References

- Plan.md MUST specify target repository and paths explicitly
- Use repository name prefixes for clarity (e.g., `chat-backend/src/routes/`)
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
| Implementation | Tests pass; code review complete; evidence captured | Updated source in target split repos |

### Quality Checkpoints

- **Spec Quality**: Technology-agnostic, measurable success criteria, bounded scope
- **Plan Quality**: Explicit tech stack, structure decisions documented, constitution compliance
- **Task Quality**: Checklist format (`- [ ] T### [P?] [US#] description with file path`)
- **Implementation Quality**: Tests green, CLAUDE.md workflow followed, evidence in `evidence/`

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
- Legacy monorepo: `D:\src\MHG\chat-client\AGENTS.md` (archived)

**Version**: 2.1.0 | **Ratified**: 2026-02-04 | **Last Amended**: 2026-02-08

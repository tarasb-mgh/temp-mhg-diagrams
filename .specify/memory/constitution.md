<!--
  Sync Impact Report
  ==================
  Version change: 3.2.0 → 3.3.0

  Modified principles:
  - III. Test-Aligned Development: expanded to require regression evidence
    with console/network verification for UI and API changes
  - VIII. GCP CLI Infrastructure Management: expanded with environment-safe
    deploy wiring and API-subdomain compatibility smoke checks

  Added sections:
  - IX. Responsive UX and PWA Compatibility

  Removed sections:
  - None

  Templates requiring updates:
  - ✅ .specify/templates/plan-template.md
  - ✅ .specify/templates/spec-template.md
  - ✅ .specify/templates/tasks-template.md
  - ✅ .claude/commands/speckit.constitution.md
  - ✅ CLAUDE.md
  - ⚠️ .specify/templates/commands/*.md (directory not present in this repo)

  Follow-up TODOs:
  - None
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
- Primary target repositories: `chat-backend`, `chat-frontend`, `chat-ui`,
  `chat-infra`, `chat-types`, `chat-ci`
- `chat-client` (monorepo) is LEGACY — see Principle VII
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
- **Coverage thresholds**: Respect existing minimums per repo
- **Test evidence**: Before/after screenshots stored in `evidence/<task-id>/`
- **Regression evidence**: For UI/API regressions, capture browser console and
  non-static network status evidence (endpoint + status codes)
- Tests are OPTIONAL in task generation unless explicitly requested

**Rationale**: Split repositories have their own testing infrastructure.
New features MUST integrate with existing patterns in each target rather
than introduce competing approaches.

### IV. Branch and Integration Discipline

Feature work MUST follow established branch policies.

- Feature branches: `###-feature-name` pattern (auto-numbered)
- Bugfix branches MAY use repository policy conventions (for example, `bugfix/*`)
- Target integration branch: `develop` (not `main`)
- `main` is promotion-only; never commit directly
- Integration to `develop` MUST happen only via Pull Request from a feature/bugfix
  branch; direct commits and direct merges to `develop` are prohibited
- Pull Requests to `develop` MUST have required reviewer approvals before merge
- Pull Requests to `develop` MUST have all required CI checks passing before merge
- All tests MUST pass before merge
- A feature/bugfix branch MAY be merged only after relevant unit and UI/E2E
  tests pass according to repository gates
- Squash merge for clean history
- Feature branches MUST be created in all affected split repositories
  using the same branch name
- After PR merge to `develop` with required tests passed:
  - the remote feature/bugfix branch MUST be deleted
  - the local feature/bugfix branch MUST be deleted
  - local `develop` MUST be synced to `origin/develop`

**Rationale**: All repositories enforce strict branch protection. Using
consistent branch names across split repos ensures traceability and
simplifies cross-repo coordination.

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

### VII. Split-Repository First (Legacy Monorepo Archived)

All new features MUST be implemented in the split repositories only.
The `chat-client` monorepo is classified as **LEGACY** and MUST NOT
receive new feature work.

- The split repos are the canonical and sole target for all changes:
  `chat-types`, `chat-backend`, `chat-frontend`, `chat-ui`, `chat-ci`,
  `chat-infra`
- Shared type changes MUST go through `chat-types` first, then consumers
  (`chat-backend`, `chat-frontend`) MUST update their dependency
- CI workflow changes MUST go through `chat-ci` and be tagged before
  consumers pick them up
- If a change spans multiple split repos, plan.md MUST document the
  execution order and inter-repo dependencies
- A task is complete when the change exists in all affected split repos
- `chat-client` (monorepo) is LEGACY:
  - No new features, no mirroring of split-repo changes
  - Existing code remains as-is for historical reference
  - May be archived at the team's discretion

**Rationale**: Maintaining dual-target delivery doubled implementation
effort, increased context-switching, and created recurring drift. The
split repositories have independent CI/CD pipelines and are the active
deployment targets. Retiring dual-target delivery eliminates waste while
preserving the monorepo as a historical reference.

### VIII. GCP CLI Infrastructure Management

All cloud infrastructure changes MUST be performed via the `gcloud` CLI
(or equivalent GCP SDK tooling). Manual changes through the GCP Console
are prohibited for production and staging environments.

- Infrastructure modifications MUST use `gcloud` commands, scripted and
  committed to `chat-infra`
- Deploy wiring MUST be environment-safe: dev/prod Cloud SQL connections and
  DB secrets MUST remain isolated and must not share mutable prod/dev values
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
- API subdomain routing MUST keep `/api/*` canonical paths available. If root
  aliases (for example, `/settings`) are exposed, compatibility MUST be
  validated by smoke checks on both dev and prod.
- Post-deploy smoke checks MUST verify critical routes, deep links, and key
  API endpoints before release completion.

**Rationale**: CLI-driven infrastructure ensures reproducibility,
auditability, and version control. Manual Console changes are
untraceable, error-prone, and impossible to replicate across
environments. Scripted `gcloud` commands serve as living documentation
of the infrastructure state.

### IX. Responsive UX and PWA Compatibility

All user-facing UI MUST be responsive and MUST support installable PWA
behavior on modern mobile devices with maximum practical compatibility.

- Responsive behavior MUST be specified for common mobile/tablet/desktop
  breakpoints with no critical workflow loss on modern devices
- The client MUST remain installable as a PWA where platform/browser supports
  installation
- PWA essentials (manifest integrity, service worker strategy, icons, and
  start URL behavior) MUST be validated during feature and release testing
- Mobile compatibility testing MUST include at least one Android Chromium-based
  browser and one iOS Safari/PWA-capable path where feasible

**Rationale**: A significant share of users access support workflows from
mobile devices. Responsive, installable, and resilient client behavior is a
core product quality requirement.

## Multi-Repository Orchestration

### Repository Roles

| Repository | Role | Status | Path |
|------------|------|--------|------|
| `client-spec` | Specifications, plans, task orchestration | Active | `D:\src\MHG\client-spec` |
| `chat-types` | Shared TypeScript types (`@mentalhelpglobal/chat-types`) | Active | `D:\src\MHG\chat-types` |
| `chat-backend` | Express.js backend API | Active | `D:\src\MHG\chat-backend` |
| `chat-frontend` | React frontend application | Active | `D:\src\MHG\chat-frontend` |
| `chat-ui` | Playwright E2E tests | Active | `D:\src\MHG\chat-ui` |
| `chat-ci` | Reusable GitHub Actions workflows | Active | `D:\src\MHG\chat-ci` |
| `chat-infra` | GCP infrastructure scripts + Terraform | Active | `D:\src\MHG\chat-infra` |
| `chat-client` | Monorepo (historical reference only) | **LEGACY** | `D:\src\MHG\chat-client` |

### Split-Repository Implementation Procedure

1. **Plan**: Identify all affected split repos; plan.md MUST list
   target repository paths for every file change
2. **Types first**: If shared types changed, bump `chat-types` version,
   publish, then update `package.json` in `chat-backend` and `chat-frontend`
3. **Implement**: Build the feature in split repos on feature branches
   off `develop`
4. **Test**: Run tests in all affected split repos
5. **Merge**: Merge to `develop` in all affected repositories
   via Pull Request from feature/bugfix branches only, after required approvals
   and required checks pass
6. **Deploy**: Verify CI/CD pipelines complete successfully
7. **Cleanup**: Delete merged remote and local feature/bugfix branches;
   sync local `develop` with `origin/develop`

### Artifact Flow

1. **Specification** (`client-spec`): `/speckit.specify` creates `specs/###-feature/spec.md`
2. **Planning** (`client-spec`): `/speckit.plan` generates technical design artifacts
3. **Task Breakdown** (`client-spec`): `/speckit.tasks` creates actionable task list
4. **Implementation** (target repos): Execute tasks against split repos
   (`chat-backend`, `chat-frontend`, `chat-ui`, etc.)
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
| Implementation | Tests pass in all affected split repos; PRs to `develop` originate from feature/bugfix branches; required approvals granted; required checks pass; merged remote and local feature/bugfix branches deleted; local `develop` synced to `origin/develop`; evidence captured; responsive/PWA acceptance checks completed for user-facing changes | Updated source in split repos |

### Quality Checkpoints

- **Spec Quality**: Technology-agnostic, measurable success criteria, bounded scope
- **Plan Quality**: Explicit tech stack, structure decisions documented, constitution compliance
- **Task Quality**: Checklist format (`- [ ] T### [P?] [US#] description with file path`)
- **Implementation Quality**: Tests green in all affected split repos, PR-only
  integration policy to `develop` followed, merged branch cleanup completed
  (remote+local), local `develop` synced to remote, CLAUDE.md workflow
  followed, evidence in `evidence/`, and responsive/PWA checks completed for
  user-facing features

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
- Direct pushes or direct merges to `develop` are non-compliant unless explicitly
  approved as an emergency exception by repository owners
- Keeping merged feature/bugfix branches (remote or local) without explicit
  retention rationale is non-compliant
- Leaving local `develop` unsynced after successful merge is non-compliant
- Shipping user-facing UI changes without responsive/PWA verification evidence
  is non-compliant
- Promoting a release without post-deploy smoke evidence for critical routes
  and APIs is non-compliant
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
- Monorepo (LEGACY): `D:\src\MHG\chat-client\AGENTS.md`

**Version**: 3.3.0 | **Ratified**: 2026-02-04 | **Last Amended**: 2026-02-14

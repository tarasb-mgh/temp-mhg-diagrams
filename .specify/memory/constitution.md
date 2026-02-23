<!--
  Sync Impact Report
  ==================
  Version change: 3.6.0 → 3.6.1

  Modified principles:
  - XI. Documentation Standards — Release Notes subsection: clarified
    that entries MUST only be created for production releases (tagged
    main commits). Non-production deployments (dev, staging) MUST NOT
    have Release Notes entries.

  Added sections:
  - None

  Removed sections:
  - None

  Templates requiring updates:
  - ✅ .specify/templates/plan-template.md (no change needed)
  - ✅ .specify/templates/tasks-template.md (updated: Release Notes
    task clarified as production-release-only)
  - ✅ .specify/templates/spec-template.md (no change needed)
  - ✅ .claude/commands/speckit.implement.md (updated: Release Notes
    step clarified as production-release-only, deferred when merging
    to develop)
  - ✅ .claude/commands/speckit.plan.md (no change needed)
  - ✅ .claude/commands/speckit.specify.md (no change needed)
  - ✅ .claude/commands/speckit.tasks.md (no change needed)
  - ✅ .claude/commands/speckit.analyze.md (no change needed)
  - ✅ .claude/commands/speckit.taskstoissues.md (no change needed)
  - ✅ CLAUDE.md (no change needed)

  Follow-up TODOs:
  - Remove the non-production release entry "Release — Responsive
    PWA Support — 2026-02-22" from Confluence Release Notes (created
    for a dev deployment in error)
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

### X. Jira Traceability and Project Tracking

All feature development MUST be tracked in Jira via the Atlassian MCP
alongside speckit file-based artifacts. Speckit artifacts remain the
authoritative source of truth; Jira mirrors them for stakeholder
visibility and project coordination.

- Feature specifications (`spec.md`) MUST be represented as Jira
  **Epics** with the specification content in the Epic description
- User stories from `spec.md` MUST be created as Jira **Stories**
  parented under the corresponding Epic
- Implementation tasks from `tasks.md` MUST be created as Jira
  **Tasks** (or subtasks) under their respective Story
- High-level workflow activity (planning decisions, implementation
  milestones, analysis results) MUST be recorded as **comments** on the
  corresponding Jira issue
- The speckit workflow commands integrate with Jira at these points:
  - `/speckit.specify`: Creates the Jira Epic with spec content as
    description
  - `/speckit.plan`: Adds a comment to the Epic summarizing research
    and design decisions
  - `/speckit.tasks`: Creates Jira Stories and Tasks under the Epic
  - `/speckit.implement`: Transitions each task individually upon
    completion (not batched at the end); transitions each story when
    all its tasks are done; adds progress/result comments throughout
  - `/speckit.analyze`: Adds analysis results as a comment on the Epic
- Each Jira Task MUST be transitioned to Done immediately when the
  corresponding `tasks.md` item is marked `[X]` during implementation
  — batch transitions at the end of implementation are prohibited
- Each Jira Story MUST be transitioned to Done when all tasks in
  the corresponding user story phase are complete
- Jira issue keys MUST be recorded in the speckit artifacts (`spec.md`
  header, `tasks.md` task lines) for bidirectional traceability
- When `tasks.md` is modified after initial creation (tasks added,
  removed, or renumbered), the corresponding Jira issues MUST be
  created, closed, or updated to reflect the change, and a summary
  comment MUST be posted to the Epic documenting the modification
- The Atlassian MCP (`plugin-atlassian-atlassian`) provides the tooling
  interface; manual Jira Console operations SHOULD be avoided when MCP
  tools are available

**Rationale**: Jira provides stakeholder visibility, project management
dashboards, and cross-team coordination that file-based artifacts alone
cannot deliver. Keeping Jira synchronized with speckit artifacts ensures
the specification files remain the single source of truth while
providing accessible tracking for non-technical stakeholders and project
managers.

### XI. Documentation Standards

All product documentation MUST be maintained in Confluence and MUST be
updated on every change deployed to the production environment. Four
documentation types are defined, each targeting a distinct audience and
purpose.

- **User Manual**
  - Audience: end users (clients, therapists, administrators)
  - Scope: comprehensive, step-by-step guidance for both the **chat**
    and **workbench** interfaces
  - MUST include system screenshots reflecting the current dev UI,
    captured automatically via the Playwright MCP
    (`plugin-playwright-playwright`) against the deployed dev
    environment
  - MUST be written in non-technical language accessible to all user
    roles
  - Each guide page MUST cover: purpose of the screen, how to reach
    it, every interactive element and its effect, common workflows
    with numbered steps, and tips or warnings for frequent mistakes
  - Confluence space section: `User Manual`

- **Technical Onboarding**
  - Audience: new developers joining the project
  - Scope: repository structure, local environment setup, CI/CD
    pipelines, coding conventions, architecture overview, and
    debugging guidance
  - MUST reference the split-repository layout (Principle VII) and
    per-repo CLAUDE.md / AGENTS.md files
  - Each topic page MUST be detailed enough for a new developer to
    follow without asking existing team members for clarification
  - MUST include concrete commands, expected outputs, and
    troubleshooting steps for every setup procedure
  - Confluence space section: `Technical Onboarding`

- **Release Notes**
  - Audience: end users and stakeholders
  - Scope: user-friendly summary of changes included in each
    production release
  - MUST be published for every production deployment (tagged `main`
    commit per Principle IV)
  - MUST NOT contain entries for non-production deployments (dev,
    staging, or any environment other than production); Release Notes
    entries are exclusively for changes that have reached production
    via a tagged `main` commit
  - Each entry MUST include: release version/tag, date, list of
    user-visible changes with enough detail for users to understand
    the impact, known issues (if any), and a link to the
    corresponding Jira Epic(s)
  - Confluence space section: `Release Notes`

- **Non-Technical Onboarding**
  - Audience: non-technical team members (project managers, support
    staff, stakeholders)
  - Scope: product overview, user workflows, key terminology, and
    how to navigate the system without developer-level context
  - MUST avoid code references, CLI commands, and implementation
    details
  - Each page MUST provide sufficient detail for a new non-technical
    team member to understand the topic without live walkthrough
  - Confluence space section: `Non-Technical Onboarding`

Screenshot capture process:

- Screenshots for documentation MUST be captured using the Playwright
  MCP (`plugin-playwright-playwright`) against the deployed dev
  environment
- The Playwright MCP MUST navigate to the relevant page, interact
  with the UI to reach the desired state, and take a screenshot
- Screenshots MUST be uploaded to Confluence as page attachments and
  embedded inline in the corresponding documentation page
- Manual screenshot capture from production is NOT required; dev
  environment screenshots are the standard

Documentation update triggers:

- Every production release MUST include corresponding updates to the
  User Manual (if UI changed), Release Notes (always), and
  Non-Technical Onboarding (if workflows changed)
- Technical Onboarding MUST be updated when repository structure,
  tooling, or development workflows change
- Documentation debt (outdated pages) MUST be tracked and resolved
  before the next production release

Documentation detail standard:

- All documentation pages MUST be detailed enough to be self-service
  — a reader MUST be able to accomplish the described task or
  understand the described concept without requiring supplementary
  verbal explanation
- Placeholder or skeleton content is acceptable only as an
  intermediate step; pages MUST be fully fleshed out before the
  feature is considered complete

**Rationale**: Scattered or absent documentation increases onboarding
time, support burden, and knowledge silos. Mandating four distinct
documentation types in Confluence ensures every audience — end users,
developers, and non-technical staff — has a maintained, discoverable
source of truth that stays current with every production change.
Automated Playwright-based screenshot capture eliminates the manual
bottleneck and ensures screenshots are always reproducible and
up-to-date with the latest dev deployment.

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
| Specification | No unresolved [NEEDS CLARIFICATION]; checklist passes; Jira Epic created with spec in description | `spec.md`, `checklists/requirements.md` |
| Planning | Constitution check passes; technical context complete; Jira Epic comment with plan summary | `plan.md`, `research.md`, `data-model.md`, `contracts/` |
| Tasks | All user stories mapped; dependencies documented; Jira Stories and Tasks created under Epic | `tasks.md` |
| Implementation | Tests pass in all affected split repos; PRs to `develop` originate from feature/bugfix branches; required approvals granted; required checks pass; merged remote and local feature/bugfix branches deleted; local `develop` synced to `origin/develop`; evidence captured; responsive/PWA acceptance checks completed for user-facing changes; Jira issues transitioned with result comments; Confluence documentation updated for affected doc types | Updated source in split repos |

### Quality Checkpoints

- **Spec Quality**: Technology-agnostic, measurable success criteria, bounded scope
- **Plan Quality**: Explicit tech stack, structure decisions documented, constitution compliance
- **Task Quality**: Checklist format (`- [ ] T### [P?] [US#] description with file path`)
- **Implementation Quality**: Tests green in all affected split repos, PR-only
  integration policy to `develop` followed, merged branch cleanup completed
  (remote+local), local `develop` synced to remote, CLAUDE.md workflow
  followed, evidence in `evidence/`, responsive/PWA checks completed for
  user-facing features, each Jira Task transitioned to Done individually
  upon completion (not batched), Jira Stories transitioned on phase
  completion, and Confluence documentation updated for affected
  documentation types with Playwright-captured screenshots where
  applicable (User Manual, Release Notes, Technical/Non-Technical
  Onboarding)

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
- Completing a speckit workflow phase without the corresponding Jira
  artifact (Epic, Story, Task) and activity comment is non-compliant
- Modifying `tasks.md` (adding, removing, or renumbering tasks) without
  creating, closing, or updating the corresponding Jira issues and
  posting a summary comment to the Epic is non-compliant
- Deploying to production without updating the corresponding Confluence
  documentation (Release Notes always; User Manual and Non-Technical
  Onboarding when workflows or UI changed; Technical Onboarding when
  dev tooling or repo structure changed) is non-compliant
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

**Version**: 3.6.1 | **Ratified**: 2026-02-04 | **Last Amended**: 2026-02-22

<!--
  Sync Impact Report
  ==================
  Version change: 3.8.0 → 3.9.0

  Modified principles:
  - IV. Branch and Integration Discipline — added explicit CI/pipeline bypass
    prohibition (requires written approval); added requirement to verify CI
    status shows all checks passing (not 0 statuses) before merge.
  - XII. Release Engineering and Production Readiness — added explicit
    "approval required for production release" rule; added automatic deployment
    awareness requirement; added "dev-only validation by default" rule; added
    E2E test gate and explicit owner approval to pre-release checklist (item 5
    and 6).

  Added compliance violations:
  - Creating release branch / merging to main without owner approval
  - Merging PR when CI has 0 statuses or failing checks without approval

  Rationale for change:
  - In March 2026, an AI agent autonomously cut a release branch and merged to
    main without owner approval, triggering an unplanned production deployment
    for the chat-backend. The owner explicitly did not authorize this. These
    additions codify the gates that would have prevented that incident.

  Templates requiring updates:
  - ✅ .specify/templates/plan-template.md (no change needed)
  - ✅ .specify/templates/tasks-template.md (no change needed)
  - ✅ .specify/templates/spec-template.md (no change needed)
  - ✅ .claude/commands/speckit.implement.md (no change needed)
  - ✅ .claude/commands/speckit.plan.md (no change needed)
  - ✅ .claude/commands/speckit.specify.md (no change needed)
  - ✅ .claude/commands/speckit.tasks.md (no change needed)
  - ✅ .claude/commands/speckit.analyze.md (no change needed)
  - ✅ CLAUDE.md (needs update: add prod-approval and CI-gate rules)
  - ✅ AGENTS.md (needs update: mirrors CLAUDE.md)
  - ✅ .cursorrules (needs update: mirrors key rules)

  Follow-up TODOs (carried from 3.8.0):
  - Add workbench-frontend and chat-frontend-common to
    chat-infra/config/github-repos.json and re-run setup-github.sh
  - Delete or document deprecated VPC connector (chat-vpc-connector)
    and associated firewall rule (allow-vpc-connector-to-redis)
  - Delete or mark deprecated redis-host / redis-port secrets in
    Secret Manager (replaced by GitHub environment variables)
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
- Primary target repositories: `chat-backend`, `chat-frontend`,
  `workbench-frontend`, `chat-frontend-common`, `chat-ui`, `chat-infra`,
  `chat-types`, `chat-ci`
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
  (see Environments section for canonical URLs)
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
- **CI/pipeline bypass is PROHIBITED** without explicit written approval from the
  repository owner. If CI checks fail, the issue MUST be fixed — never bypassed
  via `--no-verify`, skip flags, or force-merging a failing PR. If a bypass is
  explicitly approved, the approval and reason MUST be documented in the PR
- A feature/bugfix branch MAY be merged only after relevant unit and UI/E2E
  tests pass according to repository gates
- **Before merging any PR, the CI status for ALL checks MUST be verified as
  passing** (not pending, not skipped, not failed). A PR with 0 status checks
  reported MUST be investigated before merge — it may indicate the CI workflow
  was not triggered
- Squash merge for clean history
- Feature branches MUST be created in all affected split repositories
  using the same branch name
- After PR merge to `develop` with required tests passed:
  - the remote feature/bugfix branch MUST be deleted
  - the local feature/bugfix branch MUST be deleted
  - local `develop` MUST be synced to `origin/develop`
- After every release merge to `main`, a backmerge PR from `main` to
  `develop` MUST be created and merged in each affected repository to
  prevent divergence accumulation between the two branches

**Rationale**: All repositories enforce strict branch protection. Using
consistent branch names across split repos ensures traceability and
simplifies cross-repo coordination. Mandatory post-release backmerge
prevents the main/develop divergence that caused merge conflicts during
the v2026.02.23 release. CI bypass without approval has caused broken
features to reach production and deployed untested code to prod without
owner knowledge.

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
  `chat-types`, `chat-backend`, `chat-frontend`, `workbench-frontend`,
  `chat-frontend-common`, `chat-ui`, `chat-ci`, `chat-infra`
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
- Non-sensitive infrastructure configuration (hostnames, IP addresses,
  ports, feature flags, resource names) MUST be stored as GitHub
  environment variables and injected via `--set-env-vars` in deploy
  workflows. GCP Secret Manager (`--set-secrets`) MUST be reserved
  exclusively for credentials, keys, tokens, and connection strings
  containing passwords. Mixing sensitive and non-sensitive values in
  Secret Manager introduces unnecessary failure modes.
- All deployable repositories MUST be registered in
  `chat-infra/config/github-repos.json` with `has_deployments: true`
  and their target environments listed. The `setup-github.sh`
  provisioning script MUST be re-run whenever a new deployable
  repository is added to ensure GitHub environments, secrets, and
  variables are fully configured for both dev and prod.

**Rationale**: CLI-driven infrastructure ensures reproducibility,
auditability, and version control. Manual Console changes are
untraceable, error-prone, and impossible to replicate across
environments. Scripted `gcloud` commands serve as living documentation
of the infrastructure state. Strict separation of secrets from
non-sensitive config prevents the class of runtime injection failures
encountered during the v2026.02.23 Redis rollout.

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
    environment (`https://dev.mentalhelp.chat` for chat,
    `https://workbench.dev.mentalhelp.chat` for workbench)
  - MUST be written in non-technical language accessible to all user
    roles
  - Each guide page MUST cover: purpose of the screen, how to reach
    it, every interactive element and its effect, common workflows
    with numbered steps, and tips or warnings for frequent mistakes
  - Confluence page:
    [User Manual](https://mentalhelpglobal.atlassian.net/wiki/spaces/UD/pages/8749070/User+Manual)

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
  - Confluence page:
    [Technical Onboarding](https://mentalhelpglobal.atlassian.net/wiki/spaces/UD/pages/8847361/Technical+Onboarding)

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
  - Confluence page:
    [Release Notes](https://mentalhelpglobal.atlassian.net/wiki/spaces/UD/pages/8781825/Release+Notes)

- **Non-Technical Onboarding**
  - Audience: non-technical team members (project managers, support
    staff, stakeholders)
  - Scope: product overview, user workflows, key terminology, and
    how to navigate the system without developer-level context
  - MUST avoid code references, CLI commands, and implementation
    details
  - Each page MUST provide sufficient detail for a new non-technical
    team member to understand the topic without live walkthrough
  - Confluence page:
    [Non-Technical Onboarding](https://mentalhelpglobal.atlassian.net/wiki/spaces/UD/pages/8814593/Non-Technical+Onboarding)

Screenshot capture process:

- Screenshots for documentation MUST be captured using the Playwright
  MCP (`plugin-playwright-playwright`) against the deployed dev
  environment (`https://dev.mentalhelp.chat` for chat,
  `https://workbench.dev.mentalhelp.chat` for workbench)
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

### XII. Release Engineering and Production Readiness

Production releases MUST follow a structured verification process that
prevents the class of deployment failures encountered historically.
Infrastructure changes and feature work MUST be released through
separate release cycles when they affect deployment topology, networking,
or data storage.

- **Explicit approval required for production release**: No release
  branch (`release/*`) MUST be created, and no PR from a release
  branch to `main` MUST be opened or merged, without **explicit written
  instruction or approval** from the repository owner. This applies
  even when a feature is complete and tested. The act of creating a
  release branch or merging to `main` triggers automatic production
  deployment — this is a production event and MUST be owner-controlled.
  "The feature is ready" is NOT a sufficient reason to cut a release
  unilaterally.
- **Automatic deployment awareness**: All team members and AI agents
  MUST understand that merging any PR to `main` in a deployable
  repository triggers the production deploy workflow automatically.
  Creating a release branch, opening a release PR, and merging to
  `main` are all steps in a production deployment and MUST NOT be
  performed without explicit approval.
- **Dev-only validation by default**: All feature validation, smoke
  testing, Playwright E2E tests, and bug investigation MUST target the
  `dev` environment (`https://dev.mentalhelp.chat`,
  `https://api.dev.mentalhelp.chat`). If an issue is not reproducible
  or fixable on `dev`, escalate to the owner before touching production.
- **Release scope separation**: Changes to deployment workflows,
  VPC/networking configuration, database infrastructure, or new service
  provisioning MUST be released and verified in a standalone release
  cycle before bundling with feature work. Feature releases MAY be
  combined when they share the same deployment topology.
- **Deploy workflow completeness**: Every deployable repository MUST
  have a production deploy workflow (`deploy.yml` or equivalent)
  committed and tested before its first production release. The deploy
  workflow MUST be verified as part of the pre-release checklist, not
  discovered missing post-deploy.
- **Pre-release verification checklist**: Before cutting a release
  branch (with owner approval), the following MUST be verified for
  each target repository:
  1. A production deploy workflow exists and is triggered on push to
     `main` (or manual dispatch)
  2. The `prod` GitHub environment has all required secrets and
     variables configured (compare against the `dev` environment as
     baseline)
  3. A structured health endpoint exists for backend services and
     returns per-dependency status (database, cache, external services)
  4. `main` and `develop` are not diverged (if diverged, reconcile
     before cutting the release branch)
  5. All Playwright E2E tests pass on the `dev` environment against the
     feature being released
  6. Explicit written approval from the owner has been received
- **Post-release backmerge**: After every release merge to `main`, a
  PR from `main` → `develop` MUST be created and merged in each
  affected repository (see Principle IV)
- **Post-deploy health verification**: After production deployment,
  smoke checks MUST be run against the canonical production URLs
  (`https://mentalhelp.chat` for chat,
  `https://workbench.mentalhelp.chat` for workbench,
  `https://api.mentalhelp.chat` for the backend API). Every backend
  service health endpoint MUST return `ok` status for all dependencies
  before the release is considered complete. Degraded status MUST
  trigger immediate investigation and hotfix.
- **Fallback documentation**: Critical infrastructure dependencies
  (caches, message queues, external APIs) MUST have documented
  fallback behavior so degraded-mode operation is understood before
  deployment, not discovered during incidents.

**Rationale**: The v2026.02.23 release required 3 hotfix iterations
over 1 hour to reach full production health. Every incident — missing
deploy workflow, unconfigured environment secrets, Redis connectivity
failure — was preventable with pre-release verification. Separating
infrastructure releases from feature releases reduces blast radius and
ensures deployment topology changes are validated independently.
Mandatory health verification catches issues before users do. In March
2026, an AI agent autonomously cut a release branch and merged to `main`
without owner approval, triggering an unplanned production deployment —
this principle codifies the gate that would have prevented that.

## Multi-Repository Orchestration

### Repository Roles

| Repository | Role | Status | Path |
|------------|------|--------|------|
| `client-spec` | Specifications, plans, task orchestration | Active | `D:\src\MHG\client-spec` |
| `chat-types` | Shared TypeScript types (`@mentalhelpglobal/chat-types`) | Active | `D:\src\MHG\chat-types` |
| `chat-backend` | Express.js backend API | Active | `D:\src\MHG\chat-backend` |
| `chat-frontend` | React frontend application (chat) | Active | `D:\src\MHG\chat-frontend` |
| `workbench-frontend` | React frontend application (workbench) | Active | `D:\src\MHG\workbench-frontend` |
| `chat-frontend-common` | Shared frontend library (auth, API, permissions) | Active | `D:\src\MHG\chat-frontend-common` |
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
4. **Implement**: Build the feature in split repos on feature branches
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
   (`chat-backend`, `chat-frontend`, `workbench-frontend`, `chat-ui`, etc.)
5. **Verification** (`client-spec`): Update task status, capture evidence

### Cross-Repository References

- Plan.md MUST specify target repository and paths explicitly
- Use repository name prefixes for clarity (e.g., `chat-backend/src/routes/`)
- Shared types are published via `@mentalhelpglobal/chat-types` npm package
- Shared frontend code is published via `@mentalhelpglobal/chat-frontend-common`
- CI workflows are centralized in `chat-ci` and consumed via `uses:` references
- Document any cross-repository dependencies in plan.md

## Development Workflow

### Environments

Canonical environment URLs for all development, testing, and smoke-check
activities. Do NOT derive or discover these from CI output — use these
values directly.

| Environment | Chat Frontend | Workbench Frontend | Backend API |
|-------------|---------------|--------------------|-------------|
| **Dev** | https://dev.mentalhelp.chat | https://workbench.dev.mentalhelp.chat | https://api.dev.mentalhelp.chat |
| **Prod** | https://mentalhelp.chat | https://workbench.mentalhelp.chat | https://api.mentalhelp.chat |

- All Playwright E2E tests MUST target the **dev** environment URLs above
- All documentation screenshots MUST be captured from the **dev** environment
- Post-deploy smoke checks MUST run against the **prod** environment URLs
- Do NOT use direct Cloud Run service URLs (`*.run.app`) or GCS bucket URLs
  for testing — always use the canonical domain names above

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
- **Release Quality**: Pre-release verification checklist passed
  (Principle XII), deploy workflows verified, GitHub environments
  provisioned, health endpoints operational, post-release backmerge
  completed

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
- Creating a release branch, opening a release PR to `main`, or merging
  to `main` without explicit written owner approval is non-compliant
  (Principle XII)
- Merging any PR (to `develop` or `main`) when CI checks have not
  passed, are pending, or report 0 statuses is non-compliant unless
  explicitly approved in writing (Principle IV)
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
- Releasing a deployable repository to production without a verified
  deploy workflow and fully provisioned prod GitHub environment is
  non-compliant (Principle XII)
- Skipping the post-release backmerge from `main` to `develop` is
  non-compliant (Principle IV / XII)
- Using `--set-secrets` for non-sensitive configuration values
  (hostnames, ports, feature flags) in deploy workflows is
  non-compliant (Principle VIII)
- Using direct Cloud Run or GCS bucket URLs for E2E testing or smoke
  checks instead of canonical environment domain names is non-compliant
- Checklist validation runs automatically via `/speckit.specify`
- Plan.md includes explicit Constitution Check section
- Non-compliance MUST be justified in Complexity Tracking section

### Reference Documents

- Backend conventions: `D:\src\MHG\chat-backend\CLAUDE.md`
- Frontend conventions: `D:\src\MHG\chat-frontend\CLAUDE.md`
- Workbench conventions: `D:\src\MHG\workbench-frontend\CLAUDE.md`
- Shared frontend library: `D:\src\MHG\chat-frontend-common\CLAUDE.md`
- CI workflows: `D:\src\MHG\chat-ci\README.md`
- E2E tests: `D:\src\MHG\chat-ui\CLAUDE.md`
- Infrastructure: `D:\src\MHG\chat-infra\CLAUDE.md`
- Shared types: `D:\src\MHG\chat-types\package.json`
- Monorepo (LEGACY): `D:\src\MHG\chat-client\AGENTS.md`
- Release retrospective: `D:\src\MHG\client-spec\releases\v2026.02.23-retrospective.md`

### Confluence Documentation Pages

| Section | URL |
|---------|-----|
| User Manual | https://mentalhelpglobal.atlassian.net/wiki/spaces/UD/pages/8749070/User+Manual |
| Release Notes | https://mentalhelpglobal.atlassian.net/wiki/spaces/UD/pages/8781825/Release+Notes |
| Non-Technical Onboarding | https://mentalhelpglobal.atlassian.net/wiki/spaces/UD/pages/8814593/Non-Technical+Onboarding |
| Technical Onboarding | https://mentalhelpglobal.atlassian.net/wiki/spaces/UD/pages/8847361/Technical+Onboarding |

**Version**: 3.9.0 | **Ratified**: 2026-02-04 | **Last Amended**: 2026-03-11

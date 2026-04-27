# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Speckit is a specification-driven development framework that enforces spec-first workflows for feature development. It provides a structured pipeline: **Specify → Plan → Tasks → Implement**.

This is a meta-framework containing workflow tools and templates—not application code.

## Commands

### Primary Workflow (execute in order)

```bash
# 1. Create feature specification from natural language
/speckit.specify "user-facing description of the feature"

# 2. Generate technical implementation plan
/speckit.plan

# 3. Break plan into executable tasks
/speckit.tasks

# 4. Execute tasks (phase-by-phase)
/speckit.implement
```

### Supporting Commands

```bash
/speckit.clarify       # Ask targeted questions to resolve [NEEDS CLARIFICATION] markers
/speckit.analyze       # Cross-artifact consistency check (spec, plan, tasks)
/speckit.checklist     # Generate domain-specific quality checklist
/speckit.constitution  # Create/update project principles
/speckit.taskstoissues # Convert tasks.md to Jira issues (Jira only — never GitHub)
```

### PowerShell Scripts

```powershell
# Create feature branch and initialize spec structure
.specify/scripts/powershell/create-new-feature.ps1 -Json "feature description"

# Initialize plan artifacts for current feature
.specify/scripts/powershell/setup-plan.ps1 -Json

# Validate prerequisites before task generation
.specify/scripts/powershell/check-prerequisites.ps1 -Json

# Update AI agent context files from plan.md
.specify/scripts/powershell/update-agent-context.ps1 -AgentType claude
```

## Architecture

### Directory Structure

```
.specify/
├── memory/constitution.md     # Project principles (template)
├── templates/                 # spec, plan, tasks, checklist templates
└── scripts/powershell/        # Workflow automation scripts

.claude/commands/              # Claude Code slash commands (speckit.*)

specs/{NNN-feature-name}/      # Generated per-feature (auto-created)
├── spec.md                    # Feature specification (what/why)
├── plan.md                    # Implementation plan (how)
├── tasks.md                   # Actionable task breakdown
├── research.md                # Technical decisions
├── data-model.md              # Entity definitions
├── quickstart.md              # Setup guide
├── contracts/                 # API specifications (OpenAPI)
└── checklists/                # Quality validation checklists
```

### Workflow Phases

1. **Phase 0 (Research)**: Extract unknowns, resolve clarifications → `research.md`
2. **Phase 1 (Design)**: Generate entities, contracts, quickstart → `data-model.md`, `contracts/`, `quickstart.md`
3. **Phase 2 (Implementation)**: Execute tasks from `tasks.md`

### Jira Integration (Atlassian MCP)

Jira synchronization is handled exclusively by `/speckit.sync`:

- **Audit** (`/speckit.sync audit`) — Read-only report comparing `tasks.md` checkbox states against Jira issue statuses
- **Push** (`/speckit.sync push`) — Transitions locally-complete (`[X]`) tasks to Done in Jira
- **Pull** (`/speckit.sync pull`) — Updates `tasks.md` checkboxes where Jira already shows Done
- Supports `--feature NNN` to scope to a single feature

Jira keys are recorded inline in `tasks.md` task lines (`? MTB-NNN` or `— MTB-NNN`) for
bidirectional traceability. If the Atlassian MCP is unavailable, speckit continues with
file-based tracking and records `PENDING` markers for retroactive Jira sync.

### Branch Naming Convention

Feature branches follow `NNN-short-name` pattern (e.g., `001-user-auth`). The number auto-increments across local branches, remote branches, and `specs/` directories.

### Integration Policy

- `develop` is the integration branch for feature and bugfix work
- Changes MUST reach `develop` only through Pull Requests from feature/bugfix branches
- Pull Requests MUST have required reviews and all required checks passing before merge
- Direct commits or direct merges to `develop` are not allowed under normal workflow
- After successful merge with unit and UI/E2E checks passed:
  - delete the remote feature/bugfix branch
  - delete the local feature/bugfix branch
  - sync local `develop` with `origin/develop`

### PR Cycle Requirements

> **CRITICAL: one feature = one branch = one PR per repo.** Do NOT
> fragment a single feature across multiple PRs against `develop`.
> Do NOT stack PRs that depend on each other's contents in the same
> repo. The owner reviews and merges the complete feature ONCE.

- Start from a dedicated `NNN-feature-name` branch created from `develop`.
- **Hold the branch open for the ENTIRE feature lifecycle.** Commit
  fixes, iterate, refactor — all inside the same branch. Push often
  (the branch is a private workspace until the feature is complete).
- **Deploy the feature branch to dev for iterative testing**:
  `gh workflow run deploy.yml --ref <branch> -f environment=dev`.
  Re-deploy after every material change; validate end-to-end against
  `https://workbench.dev.mentalhelp.chat` (or the chat frontend for
  chat-backend features).
- Validate all relevant unit and UI/E2E tests locally BEFORE opening
  the PR.
- **Open exactly ONE PR per repo when the feature is fully working
  on dev end-to-end.** Include complete scope, risk notes, concrete
  test evidence, and dev-validation screenshots/links.
- Resolve review feedback in follow-up commits on the same branch —
  NEVER by opening a second PR for the same feature.
- Merge only after all required checks are green and the owner
  approves the FULL feature.
- Prefer squash merge for a clean `develop` history.
- Post-merge housekeeping: delete remote branch, delete local branch,
  hard-sync local `develop` to `origin/develop`.

#### Allowed exceptions to one-PR-per-feature

- **Shared library publish** (e.g. `chat-types`, `chat-frontend-common`)
  that another repo's feature branch depends on MAY merge first as a
  prerequisite. The dependency boundary must be real — i.e. the
  consumer can't typecheck against the unreleased lib locally. When
  possible, prefer local file-linking (`local:deps:link` script) to
  avoid a premature publish.
- **Owner-requested split** of a genuinely huge feature into
  independently-testable slices. Each slice is still a single PR.

#### Anti-patterns (do NOT do)

- Opening a PR for "US-1 foundation" and a second PR for "US-1 chip
  bars" against `develop` for the same feature.
- Rebasing a sibling PR on top of a merged sibling PR and asking the
  owner to approve a second merge of the same feature.
- Merging an incomplete slice just to unblock another slice when the
  whole feature could have lived in one branch.

### Release Promotion To Main And Production

> ⚠️ **APPROVAL REQUIRED**: Creating a release branch or merging to `main` triggers automatic production deployment. NEVER do this without explicit written instruction from the repository owner. "The feature is ready" is NOT sufficient authorization.

- **STOP**: Before cutting any release branch, confirm explicit written approval from the owner.
- Cut a short-lived `release/*` branch from `develop` only after owner approval.
- Run full release verification on `release/*` (unit/integration/UI and migration safety checks).
- Verify all Playwright E2E tests pass on `dev` before opening the release PR.
- Open PR from `release/*` to `main` with scope, risks, rollback notes, and test evidence.
- Merge into `main` only after required reviews and all required checks are green.
- Create an immutable release tag on the merged `main` commit.
- Deploy production from that exact tagged `main` commit (never directly from `develop`).
- Run post-deploy smoke checks on critical flows; rollback by redeploying the previous known-good tag when needed.
- After every release merge to `main`, create and merge a backmerge PR from `main` to `develop` in each affected repository to prevent divergence.

### CI Gate Requirements

- Before merging any PR (to `develop` or `main`), verify that CI checks have **run and passed** — not pending, not skipped, not failed.
- A PR with 0 CI status checks reported MUST be investigated before merge; it may indicate the workflow was not triggered.
- Bypassing CI (via `--no-verify`, skip flags, or force-merging a failing PR) requires **explicit written approval** from the repository owner. Document the approval and reason in the PR.

### Environments

| Environment | Chat Frontend | Workbench Frontend | Backend API |
|-------------|---------------|--------------------|-------------|
| **Dev** | https://dev.mentalhelp.chat | https://workbench.dev.mentalhelp.chat | https://api.dev.mentalhelp.chat |
| **Prod** | https://mentalhelp.chat | https://workbench.mentalhelp.chat | https://api.mentalhelp.chat |

| Environment | Delivery Workbench Frontend | Delivery Workbench API |
|-------------|----------------------------|------------------------|
| **Single** | https://delivery.mentalhelp.chat | https://api.delivery.mentalhelp.chat |

Do NOT use direct Cloud Run (`*.run.app`) or GCS bucket URLs for testing — always use the canonical domain names above.

### CX Agent (Dialogflow CX) Deployment

The Dialogflow CX agent (`cx-agent-definition` repo) MUST be deployed via
the REST API, NOT via the console "Restore from Git" feature. The git restore
fails when the agent uses data store tools (Vertex AI Search).

**Deployment commands** (all require `x-goog-user-project: mental-help-global-25` header):

```bash
# Set common variables
TOKEN=$(gcloud auth print-access-token)
AGENT="projects/mental-help-global-25/locations/global/agents/192578e5-f119-436e-9718-abb9d9d1c8b1"
API="https://global-dialogflow.googleapis.com/v3/$AGENT"
HEADERS=(-H "Authorization: Bearer $TOKEN" -H "x-goog-user-project: mental-help-global-25" -H "Content-Type: application/json; charset=utf-8")

# Create intent (write payload to temp file first, then use --data-binary @file)
curl -s -X POST "${HEADERS[@]}" --data-binary @payload.json "$API/intents"

# Create playbook (referencedTools must use full resource paths, not display names)
curl -s -X POST "${HEADERS[@]}" --data-binary @payload.json "$API/playbooks"

# Update flow (add transition routes)
curl -s -X PATCH "${HEADERS[@]}" --data-binary @payload.json "$API/flows/{flow_id}"

# Update playbook (NO updateMask — masked instruction updates are silently ignored)
curl -s -X PATCH "${HEADERS[@]}" --data-binary @payload.json "$API/playbooks/{id}"

# List tools (get full resource paths for referencedTools)
curl -s "${HEADERS[@]}" "$API/tools"
```

**Key rules**:
- JSON files MUST be validated with `json.load()` before commit
- Playbook instruction text MUST be serialized via `json.dump()` — never edit JSON strings manually
- Training phrases go in `intents/{NAME}/trainingPhrases/{lang}.json` (uk, ru, en)
- `referencedTools` uses full paths: `projects/.../agents/.../tools/{tool_id}`
- RAI settings (`generativeSettings/uk.json`) are `BLOCK_NONE` — required for clinical mission
- The `cx-agent-definition` repo pushes directly to `main` (no `develop` branch)
- No CI/CD auto-deploy — deployment is a manual API operation after merge

### Dev UI Testing Prerequisites

- Dev chat frontend: `https://dev.mentalhelp.chat`
- Dev workbench frontend: `https://workbench.dev.mentalhelp.chat`
- Dev backend API: `https://api.dev.mentalhelp.chat`
- Use an approved account with the required workbench/review permissions.
- For OTP login in dev, retrieve the OTP from browser console output.
- Validate that frontend and backend are from the same deployment cycle before debugging API errors.
- Confirm active group/space selection is valid for the authenticated account.
- During review validation, test at least one session with reviewable assistant messages.
- Always capture browser console and network errors (endpoint + HTTP status) as evidence.

### Workbench Regression Test Suite

The `regression-suite/` directory contains a comprehensive, AI-agent-executable regression
test suite for the MHG Workbench application (125 test cases across 16 modules).

```
regression-suite/
├── _config.yaml              # URLs, accounts, timeouts, known acceptable errors
├── _runner-guide.md          # Agent execution protocol
├── 01-auth.yaml              # Authentication & access control (11 tests)
├── 02-navigation.yaml        # Shell, sidebar, breadcrumbs (12 tests)
├── 03-review-queue.yaml      # Queue tabs, filtering, pagination (14 tests)
├── 04-review-session.yaml    # Session detail, rating, submit (10 tests)
├── 05-review-dashboards.yaml # Dashboards, reports, config (6 tests)
├── 06-safety-flags.yaml      # Flags, escalation, deanonymization (6 tests)
├── 07-survey-schemas.yaml    # Schema CRUD, editor, publish (9 tests)
├── 08-survey-instances.yaml  # Instance deployment, responses (7 tests)
├── 09-user-management.yaml   # Users, approvals, tester tags (8 tests)
├── 10-group-management.yaml  # Groups, members, invitations (8 tests)
├── 11-privacy-gdpr.yaml      # PII masking, export, erasure (4 tests)
├── 12-security-admin.yaml    # RBAC, permissions, feature flags (7 tests)
├── 13-settings.yaml          # Preferences, admin settings (3 tests)
├── 14-i18n.yaml              # Locale switching, key completeness (6 tests)
├── 15-responsive.yaml        # Mobile, tablet, desktop layouts (7 tests)
├── 16-cross-cutting.yaml     # PWA, empty states, error monitoring (6 tests)
└── results/                  # Agent writes run results here
```

**Execution modes** (specified at invocation):
- `smoke` — P0 tests only (22 tests, ~10 min)
- `standard` — P0 + P1 (85 tests, ~30 min, recommended post-deploy)
- `full` — all priorities (125 tests, ~60 min)
- `module:XX` — single module (e.g., `module:03-review-queue`)

Tests are defined in YAML with structured steps using Playwright MCP tools
(`browser_navigate`, `browser_snapshot`, `browser_click`, `browser_fill_form`,
`browser_wait_for`, `browser_console_messages`, `browser_network_requests`).
Each test specifies role, priority, dependencies, assertions, and error signatures.
The `_runner-guide.md` documents the full execution protocol for the AI agent.

## Key Patterns

### Task Format in tasks.md

```markdown
- [ ] T001 [P] [US1] Description with file path in src/path/file.ext
```

- `- [ ]`: Markdown checkbox (required)
- `T001`: Sequential task ID
- `[P]`: Parallelizable marker (optional)
- `[US1]`: User story reference (required for story phases)
- File path: Exact location for implementation

### Spec Quality Rules

- Focus on WHAT users need and WHY (business value)
- No implementation details (languages, frameworks, APIs)
- Maximum 3 `[NEEDS CLARIFICATION]` markers per spec
- Success criteria must be measurable and technology-agnostic
- For user-facing work, include explicit responsive behavior requirements
  and PWA installability expectations for modern mobile compatibility

### Non-Git Fallback

Scripts support repositories without git:
- `SPECIFY_FEATURE` environment variable overrides branch detection
- Falls back to latest `specs/NNN-*` directory for current feature
- Branch creation skipped with warning

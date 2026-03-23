# Feature Specification: CI Rate-Limit Hardening

**Feature Branch**: `037-ci-rate-limit-hardening`  
**Created**: 2026-03-23  
**Status**: Draft  
**Input**: User description: "GitHub Actions CI is failing with API rate limit exceeded errors (user ID 243990955). Workflows fail during the `actions/checkout` 'Determining the default branch' step. Need to harden CI across all MHG repositories against GitHub REST API rate limiting."

## Problem Statement

On 2026-03-23, the `workbench-frontend` PR #103 CI run failed because GitHub's REST API rate limit was exhausted during the `actions/checkout` step. The error occurred at the "Determining the default branch" phase, which makes REST API calls to `GET /repos/{owner}/{repo}` before any git operations begin.

**Root Cause Analysis:**

The MentalHelpGlobal GitHub organization has ~13 repositories with ~39 workflow files. The CI pipelines use `PKG_TOKEN` — a Personal Access Token belonging to the org owner `tarasb-mgh` (user ID 243990955) — for all cross-repository operations: checking out shared dependencies (`chat-types`, `chat-frontend-common`), npm package registry authentication, and branch ref resolution. This single PAT has a rate limit of **5,000 requests per hour** shared across **every workflow run in every repository**. When multiple PRs, pushes, or scheduled runs trigger concurrently across the organization, they exhaust this shared budget.

**Confirmed authentication pattern** (from workflow analysis):
- **Step 1**: Primary repo checkout → uses default `GITHUB_TOKEN` (1,000 req/hr per repo, separate budget)
- **Step 2+**: Cross-repo checkouts of `chat-types`, `chat-frontend-common` → uses `PKG_TOKEN` (tarasb-mgh's PAT)
- **npm install**: `NODE_AUTH_TOKEN` and `GITHUB_TOKEN` env vars → both set to `PKG_TOKEN`
- **Branch resolution** (`chat-backend`): `git ls-remote` with `GH_TOKEN` → set to `PKG_TOKEN`

All of these API calls count against the same 5,000 req/hr budget for user ID 243990955.

Contributing factors:
1. **Single shared PAT across all repos** — Every cross-repo operation in every workflow uses `PKG_TOKEN` (tarasb-mgh's PAT), creating a single point of rate-limit exhaustion
2. **No concurrency controls** — Multiple workflow runs for the same PR execute in parallel when rapid pushes occur, with no cancellation of superseded runs
3. **Redundant workflow triggers** — Workflows may trigger on both `push` and `pull_request` events for the same commit, doubling API consumption
4. **No path filters** — Workflows run even when changes are limited to documentation or non-code files
5. **Multiple checkout steps per workflow** — Each workflow performs 2–3 `actions/checkout` calls (primary repo + `chat-types` + `chat-frontend-common`), each consuming API calls against the shared PAT budget
6. **No explicit ref pinning** — Without specifying `ref:` in checkout, an extra API call is made to determine the default branch for each cross-repo checkout

## User Scenarios & Testing *(mandatory)*

### User Story 1 — CI Runs Complete Without Rate-Limit Failures (Priority: P1)

A developer pushes a commit to any MHG repository feature branch. The CI pipeline runs to completion — linting, testing, building, deploying — without encountering GitHub API rate-limit errors at any step.

**Why this priority**: This is the core problem. Rate-limit failures block the entire development workflow: PRs cannot be validated, deployments are delayed, and developers lose trust in CI reliability.

**Independent Test**: Push 3 commits in quick succession to a feature branch on `workbench-frontend`. All triggered workflow runs should either complete successfully or be properly cancelled (superseded), with zero rate-limit errors.

**Acceptance Scenarios**:

1. **Given** a developer pushes to a feature branch, **When** the CI workflow triggers, **Then** the `actions/checkout` step completes without rate-limit errors
2. **Given** 5 PRs are open across different MHG repositories with CI running concurrently, **When** all workflows execute, **Then** no workflow fails due to rate limiting
3. **Given** a developer pushes 3 rapid commits to the same branch, **When** workflows trigger for each push, **Then** only the latest run proceeds while older runs are cancelled

---

### User Story 2 — Unnecessary CI Runs Are Prevented (Priority: P2)

When a developer pushes changes that only affect documentation, configuration files not relevant to builds, or files outside the scope of a given workflow, the workflow does not trigger — conserving API budget for runs that matter.

**Why this priority**: Reducing the total number of workflow runs directly reduces API consumption, making rate-limit exhaustion less likely even without other mitigations.

**Independent Test**: Push a commit that only modifies `README.md` to a repository with path-filtered workflows. Verify no build/test workflows trigger.

**Acceptance Scenarios**:

1. **Given** a commit that only changes `*.md` files, **When** pushed to a feature branch, **Then** build and test workflows do NOT trigger
2. **Given** a commit that changes `src/` files, **When** pushed to a feature branch, **Then** relevant workflows trigger normally
3. **Given** a commit that changes both `docs/` and `src/` files, **When** pushed to a feature branch, **Then** build/test workflows trigger because `src/` paths match their path filter — path filters evaluate per-workflow, not per-commit

---

### User Story 3 — Rate-Limit Status Is Visible and Monitored (Priority: P3)

Platform engineers can see the current GitHub API rate-limit usage and remaining budget. When usage approaches the threshold, they receive an early warning before workflows start failing.

**Why this priority**: Visibility enables proactive management instead of reactive firefighting. It helps catch configuration drift or unexpected spikes before they cause failures.

**Independent Test**: After a CI run completes, check that rate-limit consumption metrics are logged in the workflow output. Verify that the remaining budget is reported.

**Acceptance Scenarios**:

1. **Given** a CI workflow completes, **When** an engineer inspects the workflow logs, **Then** the remaining API rate-limit budget is visible in the output
2. **Given** rate-limit remaining drops below 20% of the hourly budget during a workflow run, **When** the monitoring step detects this, **Then** a warning annotation appears in the workflow summary (per FR-006)

---

### User Story 4 — Reusable Workflows Apply Rate-Limit Protections Uniformly (Priority: P2)

The centralized reusable workflows in `chat-ci` embed rate-limit protections (concurrency groups, path filters, ref pinning) so that consuming repositories inherit these protections without per-repo configuration effort.

**Why this priority**: The `chat-ci` repository is the canonical source for CI workflows (per constitution Principle VII). Centralizing protections ensures consistency and reduces the risk of one misconfigured repo exhausting the shared budget.

**Independent Test**: Modify a reusable workflow in `chat-ci` to include concurrency controls. Verify that a consuming repository (e.g., `workbench-frontend`) inherits those controls without changes to its own workflow files.

**Acceptance Scenarios**:

1. **Given** the reusable CI workflow in `chat-ci` includes a concurrency group, **When** `workbench-frontend` triggers this workflow, **Then** the concurrency group is enforced
2. **Given** a new repository is added to the organization, **When** it references the `chat-ci` reusable workflow, **Then** rate-limit protections are inherited automatically

---

### Edge Cases

- What happens when GitHub experiences a platform-wide rate-limit reduction or outage? Workflows should fail gracefully with clear error messages, not hang indefinitely.
- What happens when a scheduled (cron) workflow coincides with a burst of PR-triggered workflows? Scheduled runs MUST use a separate concurrency group so they do not block PR workflows, and SHOULD be cancellable by PR-triggered runs in the same repo.
- What happens when a reusable workflow caller overrides concurrency settings? Callers MAY override the concurrency group key, but MUST NOT remove the concurrency constraint entirely. The reusable workflow MUST document its default concurrency group and the consequences of overriding it.
- What happens when the GitHub App installation token itself hits its rate limit (5,000–12,500/hr)? The rate-limit monitoring step (FR-006) should detect usage approaching the threshold and surface a warning annotation before exhaustion.
- What happens during release cycles when multiple repos have simultaneous CI activity? Concurrency controls should prevent cascading failures.
- What happens during the migration period when some repos use the new GitHub App token while others still use `PKG_TOKEN`? Both token pools will be active simultaneously. Repos still on `PKG_TOKEN` remain vulnerable to the original rate-limit problem. Migration MUST be tracked per-repo, and all repos should be migrated within a single sprint to minimize the coexistence window.
- What happens when Dependabot or other automated bots open PRs that trigger CI? Bot-initiated workflows share the same authentication budget and MUST be subject to the same concurrency controls.
- What happens when a concurrency-cancelled run was for a required status check? The latest (non-cancelled) run MUST still report the required check; cancelled intermediate runs do not block PR merge.
- What happens when third-party actions within a workflow make additional GitHub API calls? API consumption from third-party steps counts against the same budget. Workflows SHOULD minimize third-party actions that make GitHub REST API calls, and the monitoring step SHOULD capture total usage inclusive of all steps.

## Scope

### In Scope

- All GitHub Actions workflow files across the 13 MentalHelpGlobal repositories
- Reusable workflows in `chat-ci` consumed by other repos
- Authentication migration from `PKG_TOKEN` (PAT) to GitHub App installation token
- Concurrency controls, path filters, ref pinning, and fetch-depth optimization
- Rate-limit monitoring and logging within workflow runs
- Workflows triggered by Dependabot and other automated bots

### Out of Scope

- Non-GitHub CI systems (no other CI is used, but this spec does not cover hypothetical alternatives)
- Runtime application API rate limiting (e.g., rate limiting on the MHG backend API itself)
- Security audit of secrets management beyond the token type migration (PAT → GitHub App)
- Changes to third-party GitHub Actions source code — only selection and configuration of actions is in scope
- GitHub Enterprise Cloud (GHEC) upgrade evaluation — this spec assumes the current GitHub plan
- npm registry rate limits (separate from GitHub REST API limits; `NODE_AUTH_TOKEN` usage is addressed only for its GitHub API impact)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: All CI **validation** workflows across MHG repositories MUST include concurrency groups that cancel superseded runs on the same branch/PR. Deploy workflows MUST also include concurrency groups but with `cancel-in-progress: false` (queuing, not cancelling) to prevent partial deployments
- **FR-002**: All CI **validation** workflows (triggered on `pull_request` or `push` to feature branches) MUST include path filters to skip execution when changes are limited to non-build-relevant files. Exclusion list (`paths-ignore`): `*.md`, `docs/**`, `LICENSE`, `.github/ISSUE_TEMPLATE/**`, `.github/PULL_REQUEST_TEMPLATE/**`. All other files are considered build-relevant by default and trigger workflows when changed. The approach is exclusion-based (`paths-ignore`): only the explicitly listed non-build-relevant paths are excluded; everything else triggers. Deploy workflows (triggered on `push` to `main`/`develop`) are excluded from this requirement because they run on already-validated code and must always execute to maintain deployment consistency
- **FR-003**: The `actions/checkout` step in all workflows MUST pin the `ref` explicitly to avoid the "determine default branch" API call. Use `github.event.pull_request.head.sha` for `pull_request` triggers, `github.sha` for `push`/`workflow_dispatch`/`schedule`/`merge_group` triggers. For cross-repo checkouts, pin `ref` to the target branch (e.g., `develop` or `main`)
- **FR-004**: Workflows MUST use a clear trigger scoping pattern to avoid double-triggering on the same commit. Recommended pattern: use `pull_request` for PR validation workflows and `push` only for the default branch (`main`/`develop`) for deploy/release workflows. If a workflow must support both triggers, it MUST use a concurrency group (FR-001) that deduplicates runs for the same HEAD SHA
- **FR-005**: Reusable workflows in `chat-ci` MUST embed concurrency groups, path filter recommendations, and ref-pinning patterns as part of their interface contract, documented for callers
- **FR-006**: Each workflow run MUST log the remaining API rate-limit budget for the cross-repo token (GitHub App installation token, or `PKG_TOKEN` during migration) at the start of the first job and end of the last job. When the remaining budget drops below 20% of the hourly cap, the workflow MUST emit a warning annotation visible in the workflow summary
- **FR-007**: Matrix builds (if used) MUST set `max-parallel` to limit concurrent jobs and avoid burst API consumption
- **FR-008**: Workflows MUST use `fetch-depth: 1` for checkout unless full history is explicitly required for the build step
- **FR-009**: Authentication for cross-repo CI operations MUST migrate from the shared PAT (`PKG_TOKEN`, org owner `tarasb-mgh`'s personal token, user ID 243990955) to a GitHub App installation token, which provides its own separate rate-limit budget (5,000–12,500 req/hr depending on org size) decoupled from any personal user account
- **FR-010**: Scheduled (cron) workflows MUST use a distinct concurrency group from PR/push-triggered workflows to prevent cron runs from blocking developer feedback loops
- **FR-011**: Workflows triggered by Dependabot or other automated bots MUST be subject to the same concurrency and rate-limit controls as developer-initiated workflows
- **FR-012**: Concurrency groups MUST be scoped so that the latest run for a given branch/PR always executes to completion and reports required status checks. Cancelled intermediate runs MUST NOT block PR merge due to missing required checks

### Key Entities

- **Workflow Configuration**: The set of GitHub Actions YAML files across all MHG repos, centralized through `chat-ci` reusable workflows
- **Rate-Limit Budget**: The GitHub REST API request allocation per hour, scoped by authentication method. Currently: `GITHUB_TOKEN` at 1,000/repo (primary checkout) + `PKG_TOKEN` PAT at 5,000/user shared across all repos (cross-repo operations). Target: GitHub App installation token at 5,000–12,500/installation (separate from any user budget)
- **Concurrency Group**: A GitHub Actions primitive that serializes or cancels workflow runs sharing the same group key
- **Path Filter**: A workflow trigger constraint that limits execution to commits affecting specified file paths

## Success Criteria *(mandatory)*

### Measurable Outcomes

> **Platform-specific exception**: This feature is inherently bound to the CI platform (GitHub Actions) because the problem — REST API rate-limit exhaustion — is a platform-specific constraint with platform-specific mitigations (concurrency groups, path filters, GitHub App tokens). Success criteria below use generic "CI pipeline" terminology where possible, but the measurable verification (log inspection, usage dashboards) necessarily occurs within the GitHub Actions platform. This is an accepted deviation from the technology-agnostic success-criteria guideline.

- **SC-001**: Zero CI pipeline failures caused by provider API rate limiting over a 30-day observation period after implementation
- **SC-002**: At least 30% reduction in total CI pipeline runs per week compared to the 4-week pre-implementation average (measured via the CI provider's usage reporting) through path filtering and concurrency cancellation
- **SC-003**: During normal development activity (up to 5 concurrent CI runs across the organization within a 10-minute window), no CI pipeline run encounters a provider API rate-limit rejection (HTTP 429/403 with rate-limit messaging)
- **SC-004**: Rate-limit remaining budget is logged in 100% of CI pipeline runs, providing auditability
- **SC-005**: Median time from push to CI feedback (measured over 1 week post-implementation) does not regress by more than 10% compared to the 4-week pre-implementation median
- **SC-006**: All MHG repositories with CI pipelines have consistent rate-limit protections applied within 2 weeks of implementation start

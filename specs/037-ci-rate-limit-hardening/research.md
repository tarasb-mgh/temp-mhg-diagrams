# Research: CI Rate-Limit Hardening

**Feature**: 037-ci-rate-limit-hardening  
**Date**: 2026-03-23

## R1: Current Authentication Architecture

**Decision**: The org owner `tarasb-mgh` (user ID 243990955) has a PAT stored as `PKG_TOKEN` across all repos. This PAT is used for cross-repo checkouts, npm registry auth, and `git ls-remote` calls. Its 5,000 req/hr budget is shared across all CI activity organization-wide.

**Rationale**: Confirmed via workflow analysis and GitHub API user lookup. The PAT was the simplest initial approach for cross-repo access but creates a single point of rate-limit failure.

**Alternatives considered**: None were in place — this is the status quo.

## R2: GitHub App vs PAT for Cross-Repo Authentication

**Decision**: Migrate cross-repo checkout and git operations to a GitHub App installation token. Keep a separate mechanism for npm registry auth (GitHub App tokens are NOT supported by GitHub Packages npm registry).

**Rationale**: GitHub App installation tokens provide:
- A **separate** rate-limit pool (5,000 req/hr base, scaling to 12,500 for large orgs) that does not compete with any user's personal API budget
- Short-lived tokens (1 hour) with automatic revocation at job end — better security posture
- Organization-owned identity (no bus-factor risk tied to a personal account)
- Explicit repo scoping via the `repositories:` input — principle of least privilege

**Alternatives considered**:
- **Dedicated bot user with PAT**: Creates a separate rate-limit pool (5,000 req/hr) but remains a long-lived credential tied to a user account. Requires managing a separate GitHub user. Rejected: still has the PAT limitations, no scaling, requires account maintenance.
- **GHEC upgrade**: Would raise `GITHUB_TOKEN` limits to 15,000 req/hr. Rejected: cost/complexity disproportionate to the problem. Not in scope per spec.
- **Fine-grained PAT on a new machine account**: Similar to bot user but with more granular scoping. Rejected: same pool limitation, no scaling, and GitHub recommends Apps over PATs for org use.

## R3: npm Registry Authentication Strategy

**Decision**: Hybrid approach — use `GITHUB_TOKEN` (built-in Actions token) for npm registry auth by granting each consuming repo read access to the packages. If that fails, fall back to a dedicated `NPM_READ_TOKEN` PAT with minimal `read:packages` scope.

**Rationale**: GitHub App installation tokens are explicitly rejected by the GitHub Packages npm registry (documented limitation in github/docs#9547). The `GITHUB_TOKEN` approach eliminates PAT usage entirely for npm if package access grants are configured. The fallback PAT would be scoped to read-only packages and owned by the org (not the org owner's personal account).

**Alternatives considered**:
- **Continue using `PKG_TOKEN` for npm only**: Would reduce PAT API consumption (only npm calls, not checkout/ls-remote) but keeps the org owner's personal token in CI secrets. Rejected: bus-factor risk, still shares rate limit for remaining npm API calls.
- **Publish packages to a private npm registry (e.g., Verdaccio)**: Eliminates GitHub Packages dependency entirely. Rejected: overengineered for the problem; introduces operational complexity.

## R4: Reusable Workflow Adoption

**Decision**: Implement rate-limit hardening directly in each repo's inline workflows (Strategy B) first. Follow up with migration to `chat-ci` reusable workflows (Strategy A) as a consolidation effort.

**Rationale**: Currently, **no consuming repo actually uses `chat-ci` reusable workflows** — all workflows are fully inlined. Migrating to reusable workflows while simultaneously adding rate-limit protections doubles the change surface and risk. Inline hardening delivers immediate value; reusable workflow migration can follow as a separate effort.

**Alternatives considered**:
- **Strategy A first (reusable workflows)**: Refactor all repos to use `chat-ci` reusable workflows, then add protections once. Rejected for this iteration: too large a change surface, risk of cascading failures during workflow refactoring. However, this SHOULD be the eventual target (per constitution Principle VII and FR-005).

## R5: Concurrency Group Strategy

**Decision**: Use `${{ github.workflow }}-${{ github.ref }}` as the concurrency group key with `cancel-in-progress: true` for PR validation workflows. Use `${{ github.workflow }}-deploy-${{ github.ref }}` with `cancel-in-progress: false` for deploy workflows.

**Rationale**: This ensures:
- Rapid pushes to the same branch cancel older CI runs (saves API budget)
- Deploy workflows queue rather than cancel (prevents partial deployments)
- Different workflows on the same branch do not interfere with each other
- The latest run always completes and reports required status checks (FR-012)

**Alternatives considered**:
- **Per-PR concurrency only**: Using `github.event.pull_request.number` — breaks for non-PR triggers (push, schedule).
- **Global per-repo concurrency**: Too restrictive — would serialize all CI for the entire repo.
- **No `cancel-in-progress`**: Would not reduce API consumption from redundant runs.

## R6: Rate-Limit Monitoring Approach

**Decision**: Add a lightweight shell step at the start and end of each workflow's first/last job that calls `GET /rate_limit` (free endpoint — does not count against the primary rate limit) and logs the `core` resource remaining count. Emit a GitHub Actions `::warning` annotation when remaining < 20% of the limit.

**Rationale**: The `/rate_limit` endpoint is free and provides all necessary data. GitHub Actions `::warning` annotations appear in the workflow summary UI without requiring external monitoring infrastructure.

**Alternatives considered**:
- **Third-party monitoring action**: `github-api-usage-monitor` marketplace action. Rejected: adds a third-party dependency with its own maintenance burden.
- **External alerting (Slack, PagerDuty)**: Overengineered for the current team size and CI volume.
- **Response header inspection**: Parsing `x-ratelimit-remaining` from each step's output. Rejected: requires wrapping every API call, impractical.

## R7: Path Filter Strategy

**Decision**: Use `paths-ignore` (exclusion-based) rather than `paths` (inclusion-based) for workflow triggers. Exclude: `*.md`, `docs/**`, `LICENSE`, `.github/ISSUE_TEMPLATE/**`, `.github/PULL_REQUEST_TEMPLATE/**`.

**Rationale**: Exclusion-based is safer — new files are build-relevant by default. The inclusion approach risks silently skipping CI when new directories or file types are introduced. The exclusion list is small and stable.

**Alternatives considered**:
- **`paths` (inclusion-based)**: Requires explicitly listing every build-relevant path. Fragile — adding a new config file type requires updating the filter. Rejected.
- **`dorny/paths-filter` action**: Provides per-path conditional logic within a workflow. Useful for matrix optimization but adds complexity and an API call. Not needed for the basic case.

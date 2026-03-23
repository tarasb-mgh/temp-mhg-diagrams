# Implementation Plan: CI Rate-Limit Hardening

**Branch**: `037-ci-rate-limit-hardening` | **Date**: 2026-03-23 | **Spec**: `specs/037-ci-rate-limit-hardening/spec.md`  
**Input**: Feature specification from `/specs/037-ci-rate-limit-hardening/spec.md`

## Summary

GitHub Actions CI across the MentalHelpGlobal organization is failing due to REST API rate-limit exhaustion. The root cause is a shared Personal Access Token (`PKG_TOKEN`) belonging to the org owner, used for all cross-repo operations across ~13 repositories. This plan migrates cross-repo authentication to a GitHub App installation token (separate rate-limit pool), adds concurrency controls to cancel redundant runs, introduces path filters to skip unnecessary builds, pins checkout refs to eliminate extra API calls, and adds rate-limit monitoring with early warning annotations.

## Technical Context

**Language/Version**: GitHub Actions YAML, Bash (shell steps)  
**Primary Dependencies**: `actions/checkout@v4`, `actions/create-github-app-token@v3`, `actions/setup-node@v4`  
**Storage**: N/A (CI configuration only)  
**Testing**: Manual validation via test pushes; rate-limit monitoring via workflow logs  
**Target Platform**: GitHub Actions runners (ubuntu-latest)  
**Project Type**: CI/CD pipeline configuration  
**Performance Goals**: Zero rate-limit failures under normal development activity (up to 5 concurrent CI runs)  
**Constraints**: GitHub App tokens do NOT work with GitHub Packages npm registry; hybrid auth approach required  
**Scale/Scope**: ~13 repositories, ~39 workflow files, 3 org members

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Spec-First | PASS | Spec `037-ci-rate-limit-hardening/spec.md` completed and clarified |
| II. Multi-Repo Orchestration | PASS | Plan targets all split repos per orchestration model |
| III. Test-Aligned Development | PASS | No application code changes; validation via manual CI runs |
| IV. Branch and Integration | PASS | Changes follow PR workflow to `develop`; CI must pass before merge |
| V. Privacy/Security | PASS | Migration improves security (short-lived tokens vs long-lived PAT) |
| VI. Accessibility/i18n | N/A | No user-facing changes |
| VII. Split-Repo First | PARTIAL | Constitution mandates `chat-ci` for CI changes. Plan applies changes inline first (per R4 decision) due to no existing reusable workflow adoption. `chat-ci` reusable workflows updated with rate-limit protections as documented interface contracts (FR-005). Full migration to reusable workflows deferred. |
| VIII. GCP CLI Infrastructure | N/A | No infrastructure changes |
| IX. Responsive UX/PWA | N/A | No user-facing changes |
| X. Jira Traceability | PASS | Jira Epic to be created during `/speckit.tasks` phase |
| XI. Documentation Standards | PASS | Technical Onboarding to be updated with GitHub App setup instructions |
| XII. Release Engineering | N/A | No production code changes; CI config changes are operational |

### Post-Design Re-Check

| Concern | Status |
|---------|--------|
| VII. `chat-ci` first | Justified deviation: no repos currently consume `chat-ci` reusable workflows. Inline hardening is the practical first step. `chat-ci` is updated with protections as interface contracts for future adoption. See Complexity Tracking. |
| npm registry limitation | Documented: GitHub App tokens rejected by npm registry. Hybrid approach preserves npm auth via `GITHUB_TOKEN` or scoped PAT. |

## Project Structure

### Documentation (this feature)

```text
specs/037-ci-rate-limit-hardening/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Phase 0 research decisions
├── data-model.md        # CI entity definitions
└── tasks.md             # Phase 2 task breakdown (created by /speckit.tasks)
```

### Source Code (target repositories)

Changes are to GitHub Actions workflow YAML files and org-level GitHub settings. No application source code is modified.

```text
# Per-repository changes (chat-backend, chat-frontend, workbench-frontend, etc.)
.github/workflows/
├── ci.yml               # Add concurrency, path-ignore, ref pinning, App token, monitoring
├── deploy.yml           # Add concurrency (no cancel), ref pinning, App token, monitoring
└── backmerge.yml        # Add concurrency, ref pinning (already uses github.token)

# chat-ci (9 reusable workflow updates)
.github/workflows/
├── backmerge.yml                  # Add concurrency documentation
├── build-docker.yml               # Add ref pinning, fetch-depth, concurrency
├── contract-check.yml             # Add concurrency documentation (no checkout)
├── deploy-backend.yml             # Add ref pinning, fetch-depth, concurrency
├── deploy-chat-frontend.yml      # Add ref pinning, fetch-depth, concurrency
├── deploy-workbench-frontend.yml  # Add ref pinning, fetch-depth, concurrency
├── test-backend.yml               # Add ref pinning, fetch-depth, concurrency
├── test-frontend.yml              # Add ref pinning, fetch-depth, concurrency
└── test-e2e.yml                   # Add ref pinning, fetch-depth, concurrency

# GitHub organization settings (manual via GitHub UI)
# - GitHub App: mhg-ci (create, configure permissions, install)
# - Org variable: CI_APP_ID
# - Org secret: CI_APP_PRIVATE_KEY
# - Package access grants: per-package repo read access
```

**Structure Decision**: No new directories or source files. All changes are modifications to existing `.github/workflows/*.yml` files in each target repository and `chat-ci`. GitHub App setup is a one-time org-level configuration via GitHub UI.

## Implementation Phases

### Phase 1: GitHub App Setup and Org Configuration (US1, FR-009)

**Prerequisites**: GitHub org admin access for `tarasb-mgh`

1. Create GitHub App `mhg-ci` under MentalHelpGlobal org settings
   - Permissions: `Contents: Read`, `Metadata: Read`
   - Webhook: disabled
   - Installation scope: "Only on this account"
2. Install the App on all relevant repositories
3. Generate private key, store as org secret `CI_APP_PRIVATE_KEY`
4. Store App ID as org variable `CI_APP_ID`
5. Configure GitHub Packages access grants:
   - For `@mentalhelpglobal/chat-types` package: grant read access to `chat-backend`, `chat-frontend`, `workbench-frontend`, `chat-frontend-common`
   - For `@mentalhelpglobal/chat-frontend-common` package: grant read access to `chat-frontend`, `workbench-frontend`
6. Test: verify `GITHUB_TOKEN` with `packages: read` permission can install cross-repo packages. If not, create `NPM_READ_TOKEN` as fallback.

**Dependencies**: None — this is the foundational setup.

### Phase 2: Rate-Limit Monitoring Step (US3, FR-006)

**Prerequisites**: None — can run in parallel with Phase 1. The monitoring step design is token-agnostic (works with either `PKG_TOKEN` or App token). Phase 1 completion is required only before the monitoring step is deployed to production workflows (Phase 4).

Create a reusable composite action or documented shell step pattern:

```yaml
- name: Check rate limit
  run: |
    RESPONSE=$(curl -s -H "Authorization: Bearer ${{ steps.app-token.outputs.token }}" \
      https://api.github.com/rate_limit)
    REMAINING=$(echo "$RESPONSE" | jq '.resources.core.remaining')
    LIMIT=$(echo "$RESPONSE" | jq '.resources.core.limit')
    echo "::notice::Rate limit: $REMAINING / $LIMIT remaining"
    THRESHOLD=$(( LIMIT * 20 / 100 ))
    if [ "$REMAINING" -lt "$THRESHOLD" ]; then
      echo "::warning::Rate limit below 20%: $REMAINING / $LIMIT remaining"
    fi
```

This step runs at the start of the **first job** and end of the **last job** in each workflow to satisfy FR-006. For multi-job workflows, add the monitoring step to the first step of `job[0]` and last step of the final job. During migration, check the `PKG_TOKEN` budget; post-migration, check the App token budget.

**Dependencies**: Can run in parallel with Phase 1 — the monitoring step design uses whichever token is available (existing `PKG_TOKEN` or new App token). The step template is finalized before Phase 4 applies it to workflows.

### Phase 3: Baseline Capture (SC-002, SC-005)

**Prerequisites**: None — must complete before Phase 4 begins

1. Record the current 4-week average of total CI workflow runs per week (from GitHub Actions usage page for each repo). This is the baseline for SC-002.
2. Record the current median push-to-CI-feedback time across repos. This is the baseline for SC-005.

### Phase 4: Hardening Inline Workflows — Primary Repos (US1, US2, US4, FR-001 through FR-008, FR-010 through FR-012)

**Prerequisites**: Phase 1 (GitHub App installed), Phase 2 (monitoring step defined), Phase 3 (baseline captured)

For each primary repository (`chat-backend`, `chat-frontend`, `workbench-frontend`):

#### 4a. ci.yml Changes

1. **Add concurrency group** (FR-001, FR-012):
   ```yaml
   concurrency:
     group: ${{ github.workflow }}-${{ github.ref }}
     cancel-in-progress: true
   ```

2. **Add path filters** (FR-002):
   ```yaml
   on:
     pull_request:
       paths-ignore:
         - '*.md'
         - 'docs/**'
         - 'LICENSE'
         - '.github/ISSUE_TEMPLATE/**'
         - '.github/PULL_REQUEST_TEMPLATE/**'
   ```

3. **Fix trigger scoping** (FR-004):
   - Use `pull_request` for CI validation (not `push` to feature branches)
   - Keep `push` only for the default branch if needed for deploy triggers

4. **Add GitHub App token generation** (FR-009):
   ```yaml
   - uses: actions/create-github-app-token@v3
     id: app-token
     with:
       app-id: ${{ vars.CI_APP_ID }}
       private-key: ${{ secrets.CI_APP_PRIVATE_KEY }}
       owner: ${{ github.repository_owner }}
       repositories: chat-types,chat-frontend-common
   ```

5. **Pin checkout refs** (FR-003):
   ```yaml
   - uses: actions/checkout@v4
     with:
       ref: ${{ github.event.pull_request.head.sha || github.sha }}
       fetch-depth: 1
   ```

6. **Replace `PKG_TOKEN` in cross-repo checkouts** with App token:
   ```yaml
   - uses: actions/checkout@v4
     with:
       repository: MentalHelpGlobal/chat-types
       token: ${{ steps.app-token.outputs.token }}
       path: chat-types
       ref: develop
       fetch-depth: 1
   ```

7. **Replace `PKG_TOKEN` in npm auth** with `GITHUB_TOKEN`:
   ```yaml
   env:
     NODE_AUTH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
   ```

8. **Add rate-limit monitoring** (FR-006): Insert monitoring step at start and end of job.

9. **Set `max-parallel` on matrix builds** (FR-007): If any matrix strategy exists, add `max-parallel: 3`.

#### 4b. deploy.yml Changes

Same as 4a except:
- Concurrency group: `${{ github.workflow }}-deploy-${{ github.ref }}` with `cancel-in-progress: false` (queue deployments, don't cancel — per R5 decision)
- Path filters: Deploy workflows trigger on `push` to `main`/`develop` only — these branches represent merged/validated code, so `paths-ignore` is not applied (FR-002 carve-out: deploy triggers run on branch push events where all changes are already validated by CI, making path filtering redundant and potentially dangerous for deployment consistency)
- Trigger scoping: `push` to `main`/`develop` only

#### 4c. backmerge.yml Changes

- Add concurrency group
- These typically use `github.token` already (no PAT migration needed)
- Pin refs where applicable

#### 4d. Scheduled Workflow Changes (FR-010)

For any workflows with `schedule` (cron) triggers:
- Add a **distinct** concurrency group: `${{ github.workflow }}-schedule` with `cancel-in-progress: true`
- This prevents cron runs from blocking PR-triggered workflows and allows PR runs to cancel stale cron runs

#### 4e. Trigger Scoping Audit (FR-004)

For each repo, audit all workflows that trigger on both `push` and `pull_request`:
- If both are needed: ensure the concurrency group key includes `github.sha` or `github.event.pull_request.head.sha` to deduplicate runs for the same commit
- If not: refactor to use `pull_request` for validation, `push` only for deploy/default-branch triggers
- Document any workflows that must retain both triggers and the rationale

#### 4f. Graceful Failure Under Platform Stress

The rate-limit monitoring step (Phase 2) provides visibility when limits are approached. For platform-wide outages or rate-limit reductions:
- `actions/checkout` has built-in retry with backoff (3 attempts with 15s/20s delays, as seen in the original failure). No additional retry configuration is needed.
- If all retries fail, the workflow fails with the standard GitHub error message — this is the expected graceful failure mode. The monitoring step's warning annotation provides context for operators investigating the failure.
- No custom timeout or circuit-breaker is added — GitHub Actions' native behavior is sufficient.

#### 4g. Bot-Triggered Workflow Controls (FR-011)

Verify that concurrency groups and path filters apply equally to Dependabot and other bot-initiated `pull_request` events. Since concurrency groups use `github.ref` (which includes the PR branch ref regardless of who opened the PR), bot-initiated runs are automatically covered. Verify by checking that no workflow has conditional logic that bypasses concurrency for `dependabot[bot]` or similar actors.

#### 4h. Non-Checkout PAT Replacement (git ls-remote)

In `chat-backend`, `git ls-remote` calls use `GH_TOKEN: ${{ secrets.PKG_TOKEN }}`. Replace with the GitHub App token:
```yaml
env:
  GH_TOKEN: ${{ steps.app-token.outputs.token }}
```
Identify and replace any other non-checkout `PKG_TOKEN` usages (e.g., `gh api` calls, custom scripts) across all repos.

### Phase 5: Hardening chat-ci Reusable Workflows (US4, FR-005)

**Prerequisites**: Phase 4 validates the pattern

Update all 9 reusable workflows in `chat-ci`:

1. Pin `ref:` in all `actions/checkout@v4` steps (accept caller-passed SHA via input or use `github.sha`)
2. Set `fetch-depth: 1` in all checkout steps
3. Accept App token as a secret input (for workflows needing cross-repo access)
4. Add top-level `concurrency:` block to each reusable workflow using `${{ github.workflow }}-${{ github.ref }}` as the default group key (callers may override via the `concurrency:` block in their caller workflow)
5. Add `paths-ignore` guidance as commented YAML blocks within each workflow to document the recommended exclusion list for callers
6. Document concurrency group patterns, path-filter recommendations, and ref-pinning patterns in `chat-ci` README
7. Verify no matrix strategies exist in reusable workflows; if any do, set `max-parallel` per FR-007
8. Tag as `v3.0.0` and floating `v3`

### Phase 6: Hardening Remaining Repos (US1, FR-001)

**Prerequisites**: Phase 4 pattern validated

Apply the same changes to:
- `chat-ui` — concurrency, path filters, ref pinning
- `chat-infra` — concurrency, path filters (infra changes are build-relevant)
- `chat-types` — concurrency, path filters, ref pinning
- `chat-frontend-common` — concurrency, path filters, ref pinning
- `delivery-workbench-frontend` — if CI exists, apply same pattern
- `delivery-workbench-backend` — if CI exists, apply same pattern

### Phase 7: Validation and Cleanup (SC-001 through SC-006)

**Prerequisites**: All previous phases complete

1. Push test commits to multiple repos concurrently — verify no rate-limit errors (SC-001, SC-003)
2. Push a docs-only commit — verify CI does not trigger (SC-002)
3. Push 3 rapid commits — verify only the latest run completes (SC-001)
4. Inspect workflow logs — verify rate-limit monitoring output (SC-004)
5. Remove `PKG_TOKEN` references from all workflow files
6. If `GITHUB_TOKEN` works for npm: remove `PKG_TOKEN` org secret entirely
7. If `NPM_READ_TOKEN` fallback was needed: document it
8. After 1 week: compare weekly CI runs to the 4-week baseline (SC-002) and median feedback time (SC-005)
9. After 30 days: confirm zero rate-limit failures (SC-001)
10. Verify all repos with CI have consistent protections applied (SC-006)
11. Validate US4 (reusable workflow inheritance): Create a test caller workflow in a sandbox branch of one consuming repo (e.g., `workbench-frontend`) that references `chat-ci`'s updated reusable workflows (`@v3`). Verify concurrency group and ref-pinning protections are inherited. **Note**: This is a synthetic validation because no repo currently consumes `chat-ci` reusable workflows (per R4). The test validates the contract is correct and inheritance works, satisfying US4's acceptance scenarios in principle. Full adoption is deferred to a follow-up effort.
12. Update Technical Onboarding in Confluence with GitHub App setup instructions

## Implementation Order and Dependencies

```text
┌─────────────────────────┐
│ Phase 1: GitHub App     │──┐
│ Phase 2: Monitoring     │  │ (all three run in parallel)
│ Phase 3: Baseline       │──┘
└─────────────────────────┘
            │ all must complete
            ▼
┌──────────────────────────────────────────────┐
│ Phase 4: Primary Repos (backend, frontend,   │
│          workbench-frontend) — parallelizable │
└──────────────────────────────────────────────┘
            │
            ▼
┌──────────────────────────┐  ┌─────────────────────────┐
│ Phase 5: chat-ci reusable│  │ Phase 6: Remaining repos │
│ workflows                │  │ (parallel with Phase 5)  │
└──────────────────────────┘  └─────────────────────────┘
            │                             │
            └──────────┬──────────────────┘
                       ▼
┌──────────────────────────────────────────────┐
│ Phase 7: Validation and Cleanup              │
└──────────────────────────────────────────────┘
```

**Dependency summary**:
- Phases 1, 2, 3 run in parallel; all must complete before Phase 4
- Phase 4 repos are parallelizable (3 primary repos independently)
- Phases 5 and 6 can run in parallel after Phase 4 validates the pattern
- Phase 7 requires all prior phases complete

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| `GITHUB_TOKEN` cannot read cross-repo npm packages | Medium | Medium | Fallback: `NPM_READ_TOKEN` PAT with `read:packages` scope |
| Concurrency `cancel-in-progress` cancels a required check run | Low | High | Concurrency group scoped per-workflow + per-ref ensures latest run always completes (FR-012) |
| GitHub App private key compromise | Low | High | Rotate key immediately; App tokens are short-lived (1hr), limiting blast radius |
| Partial migration leaves some repos on `PKG_TOKEN` | Medium | Medium | Track migration per-repo in data-model.md; complete all repos within one sprint |
| Path filters accidentally skip needed CI runs | Low | Medium | Exclusion-based (`paths-ignore`) is safe — new files trigger by default |
| `chat-ci` reusable workflow changes break consumers | Low | Low | No consumers currently use reusable workflows; changes are additive |

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Inline workflow changes instead of `chat-ci`-first (Principle VII) | No repos currently consume `chat-ci` reusable workflows — migrating to reusable workflows while adding rate-limit protections doubles the change surface | Reusable workflow migration is planned as follow-up; `chat-ci` is updated with protections as documented contracts for future adoption |
| Hybrid auth (App token + `GITHUB_TOKEN`/PAT for npm) | GitHub Packages npm registry rejects GitHub App tokens (documented platform limitation) | A single auth mechanism is not possible given GitHub's npm registry constraints |

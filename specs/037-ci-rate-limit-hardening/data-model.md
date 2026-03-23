# Data Model: CI Rate-Limit Hardening

**Feature**: 037-ci-rate-limit-hardening  
**Date**: 2026-03-23

This feature does not introduce application data entities. The "entities" are CI configuration artifacts that exist as YAML files in GitHub repositories. This document describes their structure and relationships.

## Entity: GitHub App Configuration

**Purpose**: Organization-level GitHub App that provides installation tokens for CI cross-repo operations.

| Attribute | Type | Description |
|-----------|------|-------------|
| App ID | Numeric | Globally unique GitHub App identifier, stored as org variable `CI_APP_ID` |
| Private Key | PEM file | RSA private key for JWT signing, stored as org secret `CI_APP_PRIVATE_KEY` |
| Permissions | Set | `Contents: Read`, `Metadata: Read` |
| Installation scope | Repo list | `chat-types`, `chat-frontend-common`, and all repos needing cross-repo access |

**Relationships**:
- Installed on MentalHelpGlobal organization
- Referenced by every workflow that performs cross-repo checkout or `git ls-remote`

## Entity: Workflow Configuration

**Purpose**: GitHub Actions YAML files defining CI/CD pipelines per repository.

| Attribute | Type | Description |
|-----------|------|-------------|
| Trigger events | YAML mapping | `on:` block — `pull_request`, `push`, `workflow_dispatch`, `schedule`, `workflow_run` |
| Concurrency group | String | `concurrency.group` key — scopes cancellation/serialization |
| Cancel in progress | Boolean | `concurrency.cancel-in-progress` — whether to cancel older runs |
| Path filters | String list | `on.<event>.paths-ignore` — files excluded from triggering |
| Checkout steps | Step list | `actions/checkout@v4` invocations with `ref`, `token`, `fetch-depth` |
| Rate-limit monitor | Step | Shell step calling `GET /rate_limit` and emitting `::warning` if remaining < 20% |

**Relationships**:
- Lives in `.github/workflows/` of each repository
- References GitHub App token via `actions/create-github-app-token@v3` step
- May reference `chat-ci` reusable workflows via `uses:` (future consolidation)

## Entity: Concurrency Group

**Purpose**: Logical grouping that serializes or cancels workflow runs sharing the same key.

| Pattern | Use Case | Cancel In Progress |
|---------|----------|-------------------|
| `${{ github.workflow }}-${{ github.ref }}` | PR validation (ci.yml) | `true` |
| `${{ github.workflow }}-deploy-${{ github.ref }}` | Deployment (deploy.yml) | `false` |
| `${{ github.workflow }}-schedule` | Scheduled/cron workflows | `true` (cancellable by PR runs) |

**Relationships**:
- Defined at the workflow level (top-level `concurrency:` block)
- Scoped per workflow + branch/PR — prevents cross-branch interference

## Entity: Rate-Limit Budget (Runtime)

**Purpose**: The API request allocation being consumed during CI execution.

| Budget Pool | Limit | Scope | Used By |
|-------------|-------|-------|---------|
| `GITHUB_TOKEN` | 1,000/hr | Per repository | Primary repo checkout, same-repo operations |
| `PKG_TOKEN` (PAT) | 5,000/hr | Per user (tarasb-mgh) | **Current**: cross-repo checkout, npm auth, git ls-remote |
| GitHub App token | 5,000–12,500/hr | Per installation | **Target**: cross-repo checkout, git ls-remote |
| `GITHUB_TOKEN` or `NPM_READ_TOKEN` | Separate pool | Per repo or per user | **Target**: npm registry auth |

**State transitions**:
- **Current state**: All cross-repo API calls consume `PKG_TOKEN` budget (single pool)
- **Target state**: Cross-repo checkout/git → App token pool; npm → `GITHUB_TOKEN` pool or dedicated `NPM_READ_TOKEN` pool

## Entity: Path Filter

**Purpose**: Workflow trigger constraint that limits execution to commits affecting build-relevant file paths.

| Attribute | Type | Description |
|-----------|------|-------------|
| Strategy | Enum | `paths-ignore` (exclusion-based) — only listed paths are excluded; all others trigger |
| Exclusion list | String list | `*.md`, `docs/**`, `LICENSE`, `.github/ISSUE_TEMPLATE/**`, `.github/PULL_REQUEST_TEMPLATE/**` |
| Scope | Per-workflow | Each workflow defines its own path filter in the `on:` trigger block |
| Applicability | CI validation only | Deploy workflows (triggered by `push` to `main`/`develop`) do not use path filters |

**Relationships**:
- Defined within Workflow Configuration `on:` block
- Referenced by FR-002 in the spec
- Exclusion-based approach ensures new files are build-relevant by default (safe default)

## Entity: Repository Inventory

**Purpose**: Tracks which repositories need rate-limit hardening and migration status.

| Repository | Has CI Workflows | Cross-Repo Checkout | npm Auth | Migration Status |
|------------|-----------------|---------------------|----------|-----------------|
| `chat-backend` | Yes | `chat-types` | Yes (`PKG_TOKEN`) | Pending |
| `chat-frontend` | Yes | `chat-types`, `chat-frontend-common` | Yes (`PKG_TOKEN`) | Pending |
| `workbench-frontend` | Yes | `chat-types`, `chat-frontend-common` | Yes (`PKG_TOKEN`) | Pending |
| `chat-ci` | Yes (reusable + standalone) | None | No | Pending |
| `chat-ui` | Yes | None | Yes | Pending |
| `chat-infra` | Yes | None | No | Pending |
| `chat-types` | Yes | None | Yes (publish) | Pending |
| `chat-frontend-common` | Yes | `chat-types` | Yes (publish) | Pending |
| `delivery-workbench-frontend` | Yes (if exists) | None expected | Yes (if exists) | Pending — verify during Phase 6; if no CI workflows exist yet, skip and apply protections when CI is added |
| `delivery-workbench-backend` | Yes (if exists) | None expected | Yes (if exists) | Pending — verify during Phase 6; if no CI workflows exist yet, skip and apply protections when CI is added |
| `chat-client` | Legacy | N/A | N/A | Out of scope |

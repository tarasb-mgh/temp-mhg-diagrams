# Delivery Workbench — Design Document

**Date:** 2026-03-19
**Status:** Approved
**Author:** Brainstorming session

## Goal

Build an internal delivery workbench for the MHG tech team that acts as
a high-level orchestrator for the development process — providing
unified visibility into tasks, repositories, deployments, testing,
configuration, and GCP monitoring across all deployable services.

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Execution model | Server-side with service account credentials | Centralized credentials, no per-developer CLI setup |
| Monitoring data | Aggregation + caching, live drill-down | Fast dashboard loads, detailed on-demand queries |
| Authentication | IAP (Identity-Aware Proxy) | Zero auth code, access via GCP IAM, strongest security |
| Local tasks | Speckit tasks.md + Jira sync status | tasks.md is authoritative per constitution |
| Repo/deployment view | Summary (bird's-eye health) | MVP scope, extensible later |
| Feature view | Unified per-feature page | Single pane of glass for feature lifecycle |
| Config management | Read/write non-sensitive vars + app config + feature flags | Aligns with Principle VIII |
| Monitoring scope | Cloud Run + Cloud SQL + Cloud Storage | Covers operational essentials |
| Repo coverage | Deployable repos only | Focused: chat-backend, chat-frontend, workbench-frontend, delivery-workbench-frontend, delivery-workbench-backend |
| Architecture | Backend + Worker split | Clean separation, independent scaling, no always-on requirement for polling |
| Worker schedules | Configurable via UI | Stored in DB, no redeployment to change intervals |

## System Architecture

Four deployable units from two repositories:

```
┌─────────────────────────────────────────────────────┐
│                    IAP (Google Auth)                  │
│         (unauthenticated requests never arrive)      │
└──────────────┬──────────────────────┬────────────────┘
               │                      │
   ┌───────────▼──────────┐  ┌───────▼────────────────┐
   │  delivery-workbench  │  │  delivery-workbench    │
   │      frontend        │  │      backend (API)     │
   │  (React SPA on GCS)  │  │  (Express on Cloud Run)│
   └──────────────────────┘  └───────┬────────────────┘
                                     │ shared DB
                              ┌──────▼────────────┐
                              │   PostgreSQL       │
                              │  (Cloud SQL)       │
                              └──────▲────────────┘
                                     │ shared DB
                    ┌────────────────┴──────────────┐
                    │  delivery-workbench-worker     │
                    │  (Cloud Run Jobs / Scheduler)  │
                    │                                │
                    │  Polls: GCP Monitoring API,    │
                    │  GitHub API, Jira API           │
                    │  Writes: aggregated metrics     │
                    │  to PostgreSQL                  │
                    └────────────────────────────────┘
```

### Repository Mapping

- **`delivery-workbench-frontend`** — React SPA deployed to GCS bucket
  behind GCLB + IAP
- **`delivery-workbench-backend`** — Single codebase containing both
  the API server and worker with separate entry points:
  - `src/server.ts` — Express API server (Cloud Run service)
  - `src/worker.ts` — Polling worker (Cloud Run Job)

The API and worker share models, types, database access, and GCP client
code. One Docker image, two Cloud Run resources.

### Database

Dedicated Cloud SQL PostgreSQL instance (`delivery-db`), not shared
with `chat-db-dev`. Stores cached metrics, application configuration,
feature flags, polling state, and audit logs.

## Dashboard Panels

### Panel 1: Task Tracker

- **Source:** GitHub API (reads `specs/*/tasks.md` from `client-spec`)
  + Jira API
- **Shows:** Active features, task completion percentage, sync status
  (in-sync / drifted / pending)
- **Data flow:** Worker polls GitHub API for tasks.md files and Jira
  API for corresponding issues every 5 minutes (configurable).
  Compares checkbox states vs Jira statuses. Stores sync report in DB.
- **Manual refresh:** Triggers live fetch bypassing cache.

### Panel 2: Repository & Deployment Health

- **Source:** GitHub API (via `octokit`) + Cloud Run Admin API
- **Shows per deployable repo:** Default branch CI status
  (green/red/pending), open PR count with CI status, last deployment
  timestamp, current Cloud Run revision, active instances
- **Deployable repos:** `chat-backend`, `chat-frontend`,
  `workbench-frontend`, `delivery-workbench-frontend`,
  `delivery-workbench-backend`
- **Refresh:** Every 5 minutes (configurable).

### Panel 3: Test Status

- **Source:** GitHub Actions API (workflow run results)
- **Shows per repo:** Last unit test run (pass/fail, coverage %), last
  API test run, last Playwright E2E run (`chat-ui`), test trend
  (last 10 runs as sparkline)
- **Refresh:** Every 5 minutes (configurable).

### Panel 4: Configuration Management

- **GitHub env vars** (per repo, dev + prod environments of the
  managed repositories — not separate delivery workbench deployments):
  name + value, editable for non-sensitive variables only. A variable
  is considered non-sensitive if its value does not grant access to a
  system, does not contain credentials, and its exposure would not
  constitute a security incident. The backend MUST maintain an explicit
  allowlist of editable variable names per repo; all other variables
  are read-only even if they reside in GitHub env vars (not Secret
  Manager).
- **GCP secrets** (per repo): name only (no values), last rotation
  date — read-only
- **App config:** Key-value settings consumed by chat/workbench apps
  at runtime — full read/write
- **Feature flags:** Toggle flags with environment scope (dev/prod/all),
  immediate propagation — full read/write
- **Worker schedules:** Configurable intervals for each polling job
- **No caching** — config panel always queries live data (except app
  config and flags which are in the local DB)
- All writes generate audit log entries.

### Panel 5: Monitoring

- **Summary cards:** Request rate, error rate (4xx/5xx), p50/p95
  latency, active instances — per Cloud Run service
- **Cloud SQL:** Active connections, query latency, storage usage
- **Cloud Storage:** Bucket sizes, request counts
- **Trend charts:** Selectable time range (24h / 7d / 30d)
- **Drill-down:** Click any metric for live GCP API query (logs,
  individual traces)
- **Data flow:** Worker aggregates hourly/daily rollups from Cloud
  Monitoring API every 15 minutes (configurable). Summary cards
  served from cache. Drill-down queries GCP APIs directly.

### Panel 6: Feature View (Per-Feature Unified View)

A single page that aggregates everything about one feature across
all panels — the "single pane of glass" for a feature's lifecycle.

- **Source:** Combines data from all other panels, filtered to one
  feature (identified by spec directory name, e.g., `032-review-queue`)
- **Shows:**
  - **Spec:** Link to `spec.md` in GitHub, feature summary, Jira Epic
    link and status
  - **Tasks:** Full task list from `tasks.md` with checkbox states,
    Jira sync status per task, completion progress bar
  - **PRs & Branches:** Open/merged PRs across all affected repos for
    this feature's branch name (e.g., `032-review-queue-*`), with CI
    status per PR
  - **Deployments:** Which repos have deployed this feature's changes
    (detected by matching branch/PR merges to deployment revisions),
    deployment timestamps
  - **Test Results:** CI test runs on the feature branch across all
    affected repos — unit, API, and E2E results with pass/fail and
    coverage
  - **Evidence:** Links to `evidence/<task-id>/` directories in
    `client-spec` (screenshots, console logs, network captures) —
    rendered inline where possible (images displayed, text files
    shown)
  - **Plan Artifacts:** Links to `plan.md`, `research.md`,
    `data-model.md`, `contracts/` in the feature's spec directory
  - **Timeline:** Chronological view of key events: spec created,
    plan completed, tasks generated, PRs opened/merged, deployments,
    Jira transitions
- **Data flow:** The API aggregates from existing cached data (task
  sync reports, repo health, test results) filtered by feature ID.
  Evidence files and spec artifacts are fetched from GitHub API on
  demand. Timeline events are derived from PR/deployment timestamps
  and Jira transition history.
- **Entry points:** Clickable from Task Tracker feature list, or
  directly via URL.

## Backend API Design

### Endpoint Groups

```
# Task Tracker
GET    /api/tasks/features              # List active features with completion %
GET    /api/tasks/features/:id          # Feature detail with task list + Jira sync
POST   /api/tasks/sync/:id             # Trigger manual sync for a feature

# Feature View (per-feature unified)
GET    /api/features                    # List all features with summary status
GET    /api/features/:id               # Full feature view (spec, tasks, PRs, deploys, tests)
GET    /api/features/:id/timeline      # Chronological events for a feature
GET    /api/features/:id/evidence      # Evidence files for a feature's tasks
GET    /api/features/:id/artifacts     # Spec directory file listing + content

# Repository & Deployment Health
GET    /api/repos                       # All deployable repos with health summary
GET    /api/repos/:name                 # Single repo detail (PRs, CI, deployment)
GET    /api/repos/:name/deployments     # Deployment history for a repo

# Test Status
GET    /api/tests                       # Test summary across all repos
GET    /api/tests/:repo                 # Test detail for a repo (last 10 runs)

# Configuration
GET    /api/config/env-vars/:repo       # GitHub env vars for a repo (dev + prod)
PUT    /api/config/env-vars/:repo       # Update non-sensitive env var
GET    /api/config/secrets/:repo        # Secret names (no values) for a repo
GET    /api/config/app                  # App configuration key-values
PUT    /api/config/app/:key             # Update app config value
GET    /api/config/flags                # All feature flags
PUT    /api/config/flags/:flag          # Toggle a feature flag
GET    /api/config/flags/resolve        # Public: consumer apps fetch active flags

# Monitoring
GET    /api/monitoring/summary          # Dashboard summary cards (cached)
GET    /api/monitoring/cloud-run/:svc   # Cloud Run metrics for a service
GET    /api/monitoring/cloud-sql        # Cloud SQL metrics
GET    /api/monitoring/storage          # Cloud Storage metrics
GET    /api/monitoring/logs             # Live log query (proxies Cloud Logging)
GET    /api/monitoring/traces/:traceId  # Individual trace detail

# System
GET    /api/health                      # Health check (DB, GCP connectivity)
GET    /api/config/schedules            # Worker schedule configuration
PUT    /api/config/schedules/:job       # Update worker schedule interval
```

### Worker Jobs

Cloud Scheduler triggers the worker at a fixed 1-minute interval. The
worker internally decides which jobs are due based on configured
intervals and last-run timestamps stored in the DB.

| Job | Default Interval | Config Key |
|-----|-----------------|------------|
| `sync-tasks` | 5 min | `worker.schedule.sync-tasks` |
| `sync-repos` | 5 min | `worker.schedule.sync-repos` |
| `sync-tests` | 5 min | `worker.schedule.sync-tests` |
| `sync-deployments` | 5 min | `worker.schedule.sync-deployments` |
| `aggregate-metrics` | 15 min | `worker.schedule.aggregate-metrics` |

Each job is idempotent and stores its last-run cursor in the DB.
The cursor is written only after a successful run completes — if a
job fails mid-execution, the cursor retains its previous value so
the next invocation retries the same work window.

### Config Endpoint for Consumer Apps

`GET /api/config/flags/resolve` is excluded from IAP. Consumer apps
(chat-frontend, workbench-frontend) call this endpoint with a
service-to-service OIDC token. Response is minimal: flag name +
boolean + environment scope.

The backend MUST verify the OIDC token signature against Google's
public keys, reject requests where the `aud` claim does not match
`https://api.delivery.mentalhelp.chat`, and return HTTP 401 for any
request with a missing or invalid token. Token verification MUST be
enforced in Express middleware on this route, not left optional.

## Database Schema

### Cached Data (written by worker)

```sql
task_sync_reports     — feature_id, tasks_md_hash, jira_statuses,
                        sync_status, last_synced_at
repo_health           — repo_name, default_branch_ci, open_pr_count,
                        last_deploy_at, cloud_run_revision,
                        active_instances, last_synced_at
test_results          — repo_name, workflow_type (unit/api/e2e),
                        status, coverage_pct, run_url,
                        completed_at, last_synced_at
monitoring_rollups    — service_name, metric_type, period (hourly/daily),
                        timestamp, value_json, last_synced_at
worker_cursors        — job_name, last_run_at, next_run_at, cursor_data
```

### Application State (read/write by API)

```sql
app_config            — key, value, description, updated_at, updated_by
feature_flags         — flag_name, enabled, environment (dev/prod/all),
                        description, updated_at, updated_by
worker_schedules      — job_name, interval_seconds, enabled,
                        updated_at, updated_by
```

### Audit

```sql
audit_log             — action, entity_type, entity_id, old_value,
                        new_value, performed_by (IAP user email),
                        performed_at
```

IAP passes the authenticated user's email via
`X-Goog-Authenticated-User-Email` header — `performed_by` is
populated with zero auth code.

## Frontend Structure

### Tech Stack

- React 18 + TypeScript + Vite + Tailwind CSS + Zustand
- English-only (no i18n — per constitution Delivery Workbench exemption)
- Desktop-only (no responsive/PWA — per constitution Delivery Workbench exemption)
- WCAG AA compliance required (keyboard navigation, colour contrast,
  screen reader compatibility — per constitution Principle VI)
- Follows `workbench-frontend` patterns

### Page Layout

```
┌──────────────────────────────────────────────────┐
│  Top Bar: App title + user email (from IAP) +    │
│           last-refreshed timestamp               │
├────────────┬─────────────────────────────────────┤
│  Sidebar   │         Main Content Area           │
│            │                                     │
│  Dashboard │  (renders active panel)             │
│  Features  │                                     │
│  Tasks     │                                     │
│  Repos     │                                     │
│  Tests     │                                     │
│  Config    │                                     │
│  Monitoring│                                     │
├────────────┴─────────────────────────────────────┤
│  Status Bar: Worker health + job last-run times  │
└──────────────────────────────────────────────────┘
```

### Routes

| Route | Page | Description |
|-------|------|-------------|
| `/` | Dashboard | Summary cards from all panels |
| `/features` | Feature List | All features with lifecycle status summary |
| `/features/:id` | Feature View | Unified per-feature view (spec, tasks, PRs, deploys, tests, evidence) |
| `/features/:id/timeline` | Feature Timeline | Chronological events for a feature |
| `/tasks` | Task Tracker | Feature list with completion bars |
| `/tasks/:featureId` | Task Detail | Individual tasks, Jira links, sync status |
| `/repos` | Repositories | Deployable repo cards with CI/deployment status |
| `/repos/:name` | Repo Detail | PRs, deployment history, branch status |
| `/tests` | Test Status | Test results grid, sparkline trends |
| `/tests/:repo` | Test Detail | Last 10 runs with pass/fail/coverage |
| `/config` | Configuration | Tabs: Env Vars, Secrets, App Config, Feature Flags, Schedules |
| `/monitoring` | Monitoring | Summary cards, time-range selector |
| `/monitoring/:service` | Service Detail | Metrics, log viewer, trace explorer |

### State Management

One Zustand store per domain: `useFeatureStore`, `useTaskStore`,
`useRepoStore`, `useTestStore`, `useConfigStore`,
`useMonitoringStore`. Each store handles API fetching and auto-refresh
based on panel visibility. `useFeatureStore` aggregates data from
other stores for the unified feature view.

## Infrastructure & Deployment

### GCP Resources

| Resource | Type | Name |
|----------|------|------|
| Cloud SQL | PostgreSQL | `delivery-db` |
| Cloud Run Service | API server | `delivery-workbench-api` |
| Cloud Run Job | Worker | `delivery-workbench-worker` |
| Cloud Scheduler | Trigger | `delivery-worker-trigger` (1-min) |
| GCS Bucket | Frontend | `mental-help-global-25-delivery-frontend` |
| IAP | Auth | On GCLB backend services |
| Cloud Load Balancer | Routing | Existing GCLB, new URL map rules |

### DNS

| Subdomain | Target |
|-----------|--------|
| `delivery.mentalhelp.chat` | GCLB (frontend bucket) |
| `api.delivery.mentalhelp.chat` | GCLB (Cloud Run API) |

### IAP Configuration

- Enabled on both GCLB backend services (frontend + API)
- OAuth consent screen: internal (Google Workspace only)
- Access: `roles/iap.httpsResourceAccessUser` granted to team members
- Exception: `/api/config/flags/resolve` excluded from IAP, secured
  via service-to-service OIDC token

### Service Credentials

| Credential | Storage | Purpose |
|------------|---------|---------|
| GitHub PAT | Secret Manager | GitHub API (repos, PRs, Actions, env vars) |
| Atlassian API token | Secret Manager | Jira API (issues, transitions) |
| GCP service account | WIF (built-in) | All GCP APIs (Monitoring, Logging, Trace, SQL, Run) |

No CLI tools in the Docker image — the backend uses GCP client
libraries (`@google-cloud/monitoring`, `@google-cloud/logging`,
`@google-cloud/run`, etc.), `octokit` for GitHub, and `jira.js` for
Atlassian.

### CI/CD Workflows

**`delivery-workbench-frontend`:**
- `ci.yml` — lint, typecheck, unit tests
- `deploy.yml` — build, upload to GCS

**`delivery-workbench-backend`:**
- `ci.yml` — lint, typecheck, unit tests
- `deploy.yml` — build Docker image, deploy Cloud Run service (API) +
  update Cloud Run Job (worker)

### Single Environment Policy

- One GitHub environment (`production`)
- `develop` branch deploys to the single environment
- `main` branch for version tagging only
- Rollback via Cloud Run revision traffic splitting

## Error Handling and Degraded Operation

### Worker Job Failures

- **GCP API unavailable** (Monitoring, Logging, Trace, Cloud Run
  Admin): The worker logs the error, skips the current cycle, and
  retries on the next scheduled invocation. The cursor is NOT
  advanced. The `worker_cursors` table records the error in
  `cursor_data` so the health endpoint can surface it.
- **GitHub API rate limit** (HTTP 429 or `X-RateLimit-Remaining: 0`):
  The worker reads the `X-RateLimit-Reset` header and skips all
  GitHub-dependent jobs until that timestamp. The UI shows a "GitHub
  rate-limited until HH:MM" banner via the status bar.
- **Jira API unavailable** (HTTP 503, timeout): The `sync-tasks` job
  marks sync status as `error` for affected features (not `drifted`
  — the distinction matters). The UI shows "Jira unavailable" next
  to affected features. Previous valid sync data remains in the DB.
- **Job killed mid-write**: Cursors are written only after successful
  completion (see Worker Jobs section). DB writes within a job use
  transactions — partial writes are rolled back on failure.
- **Health endpoint**: `GET /api/health` reports per-job status
  including last successful run, last error (if any), and whether
  the job is within its expected schedule tolerance (2x the configured
  interval).

### Stale Cache UI Behaviour

When cached data is older than 2x the configured polling interval for
that job, the UI MUST show a "stale data" indicator (timestamp +
warning icon) next to the affected panel. Summary cards on the
dashboard degrade to showing the stale timestamp rather than hiding
data entirely.

### Config Write Transactionality

All config writes (env vars, feature flags, app config, schedules)
and their corresponding audit log entries MUST be in a single
database transaction. If the audit log insert fails, the config
change is rolled back. This guarantees no config change exists
without an audit trail.

### DB Connection Loss

If the database is unreachable, the API server returns HTTP 503 for
all endpoints. The health endpoint returns `{ status: "unhealthy",
db: "unreachable" }`. The worker skips all jobs and logs the error.

## Out of Scope

The following are explicitly excluded from this design:

- **Deployment triggering**: The workbench shows deployment status but
  does NOT initiate deploys, merges, or rollbacks. These remain
  manual operations via `gh` CLI or GitHub UI.
- **Alert/notification delivery**: The workbench displays metrics and
  health status but does NOT send alerts (email, Slack, PagerDuty).
  GCP Cloud Alerting handles notifications separately.
- **Chat/workbench source code configuration**: The config panel
  manages delivery workbench internal config, feature flags consumed
  by chat/workbench apps, and GitHub environment variables. It does
  NOT modify application source code or build configurations.
- **Multi-environment support**: The delivery workbench itself operates
  in a single environment per constitution. There is no dev/staging
  instance of the delivery workbench.
- **User management**: Team member access is controlled entirely via
  GCP IAM roles on the IAP resource. The workbench has no user
  management UI.
- **Historical analytics**: Monitoring rollups are retained for
  operational dashboards, not long-term trend analysis. Retention
  policy is configurable but defaults to 30 days.
- **Mobile/tablet access**: Desktop browsers only (no responsive
  layout, no PWA).

## Acceptance Criteria

1. **IAP auth**: Unauthenticated requests to `delivery.mentalhelp.chat`
   and `api.delivery.mentalhelp.chat` receive a Google sign-in
   redirect. Authenticated users with `roles/iap.httpsResourceAccessUser`
   see the frontend. Users without the role receive HTTP 403.
2. **Dashboard**: The `/` page renders one summary card per panel (6
   total: features, tasks, repos, tests, config, monitoring). Each
   card displays at least one numeric metric and links to its full
   panel page.
3. **Task Tracker**: Completion % equals `(checked tasks / total
   tasks) * 100` from the tasks.md file fetched within the last
   polling interval. Sync status shows `drifted` when any task
   checkbox state differs from the corresponding Jira issue status,
   `in-sync` when all match, `error` when Jira is unreachable.
4. **Repo health**: Each of the 5 deployable repos shows: CI badge
   (green/red/pending matching the latest GitHub Actions run), open
   PR count matching GitHub's count, and a deployment timestamp
   within 1 minute of the actual Cloud Run revision deploy time.
5. **Test status**: Each repo shows the result of its latest CI
   workflow run (pass/fail) with coverage percentage matching the
   Vitest coverage output. Sparkline renders the last 10 runs.
6. **Config management**: Non-sensitive env vars on the allowlist are
   editable; vars not on the allowlist and all secrets are read-only.
   Feature flag toggles take effect within 60 seconds for consumer
   apps polling `/api/config/flags/resolve`.
7. **Monitoring**: Summary cards show data no older than 2x the
   `aggregate-metrics` interval. Drill-down returns live GCP data
   (not cached). Time-range selector filters to 24h/7d/30d windows.
8. **Worker schedules**: Changing a job interval via the config panel
   takes effect on the worker's next 1-minute tick without
   redeployment. Jobs execute within 1 minute of their configured
   interval.
9. **Flags endpoint**: `GET /api/config/flags/resolve` with a valid
   OIDC token (audience `https://api.delivery.mentalhelp.chat`)
   returns HTTP 200 with flag data. Missing or invalid token returns
   HTTP 401. The endpoint is reachable without IAP.
10. **Audit trail**: Every config write (env var, flag, app config,
    schedule) produces exactly one `audit_log` row in the same
    transaction. The row includes the IAP user email, old value, and
    new value.
11. **Health endpoint**: `GET /api/health` returns per-dependency
    status (db, gcp) and per-worker-job status (last run, last
    error). Returns HTTP 200 when all healthy, HTTP 503 when any
    dependency is unreachable.
12. **Accessibility**: All interactive elements are keyboard-accessible
    and meet WCAG AA colour-contrast ratios (4.5:1 for normal text,
    3:1 for large text). Focus indicators are visible on all
    focusable elements.
13. **Stale data**: When cached data exceeds 2x the polling interval,
    the UI shows a warning indicator with the last-refreshed
    timestamp next to the affected panel.
14. **Feature view**: The `/features/:id` page shows spec summary
    with GitHub link, task list with Jira sync status, PRs across
    all affected repos matched by feature branch name, deployment
    status per repo, test results on the feature branch, and links
    to evidence files. The timeline view shows events in
    chronological order. Clicking a feature from the Task Tracker
    navigates to this view.

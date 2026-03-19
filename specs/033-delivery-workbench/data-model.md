# Data Model: Delivery Workbench

**Feature Branch**: `033-delivery-workbench`
**Date**: 2026-03-19

## Entity Relationship Overview

```
Feature (spec directory)
  ├── TaskSyncReport (1:1, per feature)
  ├── RepoHealth (1:N, per deployable repo)
  ├── TestResult (1:N, per repo per workflow type)
  └── Timeline events (derived from PRs, deploys, Jira)

WorkerCursor (1 per job)
WorkerSchedule (1 per job)
AppConfig (key-value store)
FeatureFlag (named toggles)
MonitoringRollup (time-series aggregates)
AuditLog (append-only)
```

## Entities

### task_sync_reports

Stores the comparison between tasks.md checkbox states and Jira
issue statuses for each active feature.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | SERIAL | PRIMARY KEY | Auto-increment ID |
| feature_id | VARCHAR(100) | NOT NULL, UNIQUE | Spec directory name (e.g., `032-review-queue`) |
| tasks_md_hash | VARCHAR(64) | NOT NULL | SHA-256 hash of tasks.md content (change detection) |
| total_tasks | INTEGER | NOT NULL | Total task count from tasks.md |
| completed_tasks | INTEGER | NOT NULL | Count of checked tasks `[X]` |
| jira_statuses | JSONB | NOT NULL | Map of task ID → Jira status |
| sync_status | VARCHAR(20) | NOT NULL | `in-sync`, `drifted`, or `error` |
| drift_details | JSONB | | Array of `{ taskId, localState, jiraState }` for mismatches |
| error_message | TEXT | | Error details when sync_status is `error` |
| last_synced_at | TIMESTAMPTZ | NOT NULL | When this report was last updated |
| created_at | TIMESTAMPTZ | NOT NULL DEFAULT NOW() | |

**States**: `sync_status` transitions: `in-sync` ↔ `drifted` ↔ `error`.
`error` occurs when Jira is unreachable or returns non-200 responses.

### repo_health

Stores the latest health snapshot for each deployable repository.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | SERIAL | PRIMARY KEY | |
| repo_name | VARCHAR(100) | NOT NULL, UNIQUE | GitHub repo name |
| default_branch_ci | VARCHAR(20) | NOT NULL | `success`, `failure`, `pending` |
| ci_run_url | TEXT | | URL to the latest CI workflow run |
| open_pr_count | INTEGER | NOT NULL DEFAULT 0 | Count of open PRs |
| open_prs | JSONB | | Array of `{ number, title, ci_status, author, url }` |
| last_deploy_at | TIMESTAMPTZ | | Last deployment timestamp |
| cloud_run_revision | VARCHAR(100) | | Current Cloud Run revision name |
| active_instances | INTEGER | DEFAULT 0 | Current active instance count |
| last_synced_at | TIMESTAMPTZ | NOT NULL | |
| created_at | TIMESTAMPTZ | NOT NULL DEFAULT NOW() | |

### test_results

Stores CI test workflow run results per repo and workflow type.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | SERIAL | PRIMARY KEY | |
| repo_name | VARCHAR(100) | NOT NULL | GitHub repo name |
| workflow_type | VARCHAR(20) | NOT NULL | `unit`, `api`, or `e2e` |
| status | VARCHAR(20) | NOT NULL | `pass` or `fail` |
| coverage_pct | DECIMAL(5,2) | | Coverage percentage (e.g., 85.50) |
| run_url | TEXT | | URL to the GitHub Actions run |
| run_number | INTEGER | NOT NULL | GitHub Actions run number |
| completed_at | TIMESTAMPTZ | NOT NULL | When the workflow completed |
| last_synced_at | TIMESTAMPTZ | NOT NULL | |
| created_at | TIMESTAMPTZ | NOT NULL DEFAULT NOW() | |

**Unique constraint**: `(repo_name, workflow_type, run_number)` —
prevents duplicate entries for the same run.

**Retention**: Last 10 runs per repo per workflow type (older rows
pruned by the sync-tests job).

### monitoring_rollups

Stores time-series aggregated metrics from GCP Cloud Monitoring.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | SERIAL | PRIMARY KEY | |
| service_name | VARCHAR(100) | NOT NULL | Cloud Run service, SQL instance, or bucket name |
| metric_type | VARCHAR(50) | NOT NULL | e.g., `request_count`, `error_rate`, `p95_latency` |
| period | VARCHAR(10) | NOT NULL | `hourly` or `daily` |
| timestamp | TIMESTAMPTZ | NOT NULL | Start of the aggregation period |
| value_json | JSONB | NOT NULL | `{ value, unit, labels }` |
| last_synced_at | TIMESTAMPTZ | NOT NULL | |

**Unique constraint**: `(service_name, metric_type, period, timestamp)`
**Retention**: 30 days default (configurable via app_config key
`monitoring.retention_days`).

### worker_cursors

Tracks the execution state of each worker job.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| job_name | VARCHAR(50) | PRIMARY KEY | e.g., `sync-tasks`, `aggregate-metrics` |
| last_run_at | TIMESTAMPTZ | | When the job last completed successfully |
| last_error_at | TIMESTAMPTZ | | When the job last failed |
| last_error_message | TEXT | | Error message from last failure |
| next_run_at | TIMESTAMPTZ | | Computed: last_run_at + interval |
| cursor_data | JSONB | | Job-specific cursor (e.g., last processed page) |

### app_config

General key-value configuration store consumed by the delivery
workbench and other applications.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| key | VARCHAR(200) | PRIMARY KEY | Dot-notation key (e.g., `monitoring.retention_days`) |
| value | TEXT | NOT NULL | Configuration value (string, parsed by consumer) |
| description | TEXT | | Human-readable description of the setting |
| updated_at | TIMESTAMPTZ | NOT NULL | |
| updated_by | VARCHAR(200) | NOT NULL | IAP user email |

### feature_flags

Named boolean toggles with environment scope.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | SERIAL | PRIMARY KEY | |
| flag_name | VARCHAR(100) | NOT NULL, UNIQUE | Flag identifier |
| enabled | BOOLEAN | NOT NULL DEFAULT FALSE | Whether the flag is active |
| environment | VARCHAR(10) | NOT NULL DEFAULT 'all' | `dev`, `prod`, or `all` |
| description | TEXT | | Human-readable description |
| updated_at | TIMESTAMPTZ | NOT NULL | |
| updated_by | VARCHAR(200) | NOT NULL | IAP user email |

### worker_schedules

Configurable polling intervals for worker jobs.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| job_name | VARCHAR(50) | PRIMARY KEY | Matches worker_cursors.job_name |
| interval_seconds | INTEGER | NOT NULL | Polling interval in seconds |
| enabled | BOOLEAN | NOT NULL DEFAULT TRUE | Whether the job is active |
| updated_at | TIMESTAMPTZ | NOT NULL | |
| updated_by | VARCHAR(200) | NOT NULL | IAP user email |

**Default values** (seeded on first migration):

| job_name | interval_seconds |
|----------|-----------------|
| `sync-tasks` | 300 (5 min) |
| `sync-repos` | 300 (5 min) |
| `sync-tests` | 300 (5 min) |
| `sync-deployments` | 300 (5 min) |
| `aggregate-metrics` | 900 (15 min) |

### audit_log

Append-only log of all configuration changes.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | SERIAL | PRIMARY KEY | |
| action | VARCHAR(20) | NOT NULL | `create`, `update`, `delete` |
| entity_type | VARCHAR(50) | NOT NULL | `app_config`, `feature_flag`, `worker_schedule`, `env_var` |
| entity_id | VARCHAR(200) | NOT NULL | Key or flag name |
| old_value | TEXT | | NULL for create operations |
| new_value | TEXT | | NULL for delete operations |
| performed_by | VARCHAR(200) | NOT NULL | IAP user email from `X-Goog-Authenticated-User-Email` |
| performed_at | TIMESTAMPTZ | NOT NULL DEFAULT NOW() | |

**Note**: `old_value` is NULL for create operations; `new_value` is
NULL for delete operations (per FR-015).

## Migration Strategy

Migrations are sequential SQL files in
`delivery-workbench-backend/src/db/migrations/`:

```
001_create_task_sync_reports.sql
002_create_repo_health.sql
003_create_test_results.sql
004_create_monitoring_rollups.sql
005_create_worker_cursors.sql
006_create_app_config.sql
007_create_feature_flags.sql
008_create_worker_schedules.sql
009_create_audit_log.sql
010_seed_worker_defaults.sql
```

Each migration is idempotent (uses `CREATE TABLE IF NOT EXISTS` and
`INSERT ... ON CONFLICT DO NOTHING` for seed data).

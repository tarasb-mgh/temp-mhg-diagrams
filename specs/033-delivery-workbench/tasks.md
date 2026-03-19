# Tasks: Delivery Workbench

**Input**: Design documents from `/specs/033-delivery-workbench/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/openapi.yaml, quickstart.md

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create repositories, provision GCP resources, initialize project scaffolding

- [X] T001 Create `delivery-workbench-backend` GitHub repository under MentalHelpGlobal org with develop branch protection
- [X] T002 Create `delivery-workbench-frontend` GitHub repository under MentalHelpGlobal org with develop branch protection
- [X] T003 [P] Register both repos in `chat-infra/config/github-repos.json` with `has_deployments: true` and re-run `setup-github.sh`
- [X] T004 [P] Provision Cloud SQL PostgreSQL instance `delivery-db` via gcloud CLI in `chat-infra/scripts/`
- [X] T005 [P] Provision GCS bucket `mental-help-global-25-delivery-frontend` for SPA hosting
- [X] T006 [P] Create Cloud Run service `delivery-workbench-api` placeholder and Cloud Run Job `delivery-workbench-worker` placeholder
- [X] T007 [P] Create Cloud Scheduler job `delivery-worker-trigger` with 1-minute interval targeting the worker Cloud Run Job — POST-DEPLOY
- [X] T008 [P] Store GitHub PAT and Atlassian API token in GCP Secret Manager as `delivery-github-pat` and `delivery-atlassian-token` — VALUES NEED POPULATING
- [X] T009 Configure GCLB URL map rules for `delivery.mentalhelp.chat` (GCS backend) and `api.delivery.mentalhelp.chat` (Cloud Run backend)
- [X] T010 Configure IAP on both GCLB backend services with internal OAuth consent screen
- [X] T011 Provision DNS records for `delivery.mentalhelp.chat` and `api.delivery.mentalhelp.chat` pointing to GCLB IP

## Phase 2: Foundation (Backend + Frontend Scaffolding)

**Purpose**: Initialize both codebases with build tooling, CI/CD, database, and shell UI

### Backend Foundation

- [X] T012 Initialize `delivery-workbench-backend` with package.json, tsconfig.json, vitest.config.ts, and TypeScript 5.x configuration
- [X] T013 [P] Create Express app setup in `delivery-workbench-backend/src/app.ts` with CORS, helmet, JSON parsing, and error handling middleware
- [X] T014 [P] Create API server entry point in `delivery-workbench-backend/src/server.ts` that imports app and starts HTTP server
- [X] T015 [P] Create worker entry point in `delivery-workbench-backend/src/worker.ts` with scheduler loop
- [X] T016 Create database connection pool in `delivery-workbench-backend/src/db/connection.ts` using `pg` with Cloud SQL connection
- [X] T017 Create database migrations 001-010 in `delivery-workbench-backend/src/db/migrations/` per data-model.md schema definitions
- [X] T018 Create migration runner utility in `delivery-workbench-backend/src/db/migrate.ts` that executes sequential SQL files
- [X] T019 [P] Create IAP middleware in `delivery-workbench-backend/src/middleware/iap.ts` to extract user email from `X-Goog-Authenticated-User-Email` header
- [X] T020 [P] Create error handling middleware in `delivery-workbench-backend/src/middleware/error.ts` with structured error responses
- [X] T021 [P] Create audit logging middleware in `delivery-workbench-backend/src/middleware/audit.ts` that wraps config mutations in transactions with audit_log inserts
- [X] T022 Create health endpoint in `delivery-workbench-backend/src/routes/health.ts` reporting DB connectivity and worker job status from worker_cursors table
- [X] T023 [P] Create shared TypeScript types in `delivery-workbench-backend/src/types/` matching OpenAPI schema definitions
- [X] T024 Create Dockerfile in `delivery-workbench-backend/Dockerfile` with multi-target build (server and worker entry points)
- [X] T025 [P] Create CI workflow in `delivery-workbench-backend/.github/workflows/ci.yml` (lint, typecheck, unit tests)
- [X] T026 [P] Create deploy workflow in `delivery-workbench-backend/.github/workflows/deploy.yml` (build image, deploy Cloud Run service + update Cloud Run Job)
- [X] T027 [P] Create CLAUDE.md and AGENTS.md in `delivery-workbench-backend/` with project conventions

### Frontend Foundation

- [X] T028 Initialize `delivery-workbench-frontend` with Vite + React 18 + TypeScript + Tailwind CSS + Zustand scaffold via `npm create vite`
- [X] T029 [P] Configure Tailwind CSS in `delivery-workbench-frontend/tailwind.config.js` with WCAG AA-compliant color palette
- [X] T030 [P] Create API client service in `delivery-workbench-frontend/src/services/api.ts` with base URL configuration and error handling
- [X] T031 Create app shell layout in `delivery-workbench-frontend/src/components/layout/Shell.tsx` with sidebar, top bar, main content area, and status bar
- [X] T032 [P] Create Sidebar component in `delivery-workbench-frontend/src/components/layout/Sidebar.tsx` with navigation links (Dashboard, Features, Tasks, Repos, Tests, Config, Monitoring)
- [X] T033 [P] Create TopBar component in `delivery-workbench-frontend/src/components/layout/TopBar.tsx` displaying IAP user email and last-refreshed timestamp
- [X] T034 [P] Create StatusBar component in `delivery-workbench-frontend/src/components/layout/StatusBar.tsx` displaying worker health and job last-run times
- [X] T035 Create route definitions in `delivery-workbench-frontend/src/routes/index.tsx` with React Router v6 for all pages per plan.md routes table
- [X] T036 [P] Create shared UI components in `delivery-workbench-frontend/src/components/common/`: SummaryCard, StatusBadge, DataTable, SparklineChart, StaleDataWarning
- [X] T037 [P] Create TypeScript types in `delivery-workbench-frontend/src/types/` matching API response schemas from OpenAPI contract
- [X] T038 [P] Create CI workflow in `delivery-workbench-frontend/.github/workflows/ci.yml` (lint, typecheck, unit tests)
- [X] T039 [P] Create deploy workflow in `delivery-workbench-frontend/.github/workflows/deploy.yml` (build, upload to GCS)
- [X] T040 [P] Create CLAUDE.md and AGENTS.md in `delivery-workbench-frontend/` with project conventions

### Worker Foundation

- [X] T041 Create worker scheduler in `delivery-workbench-backend/src/worker/scheduler.ts` that reads intervals from worker_schedules table and dispatches jobs based on worker_cursors last_run_at
- [X] T042 [P] Create parameterized query helpers in `delivery-workbench-backend/src/db/queries/` for each table (task_sync_reports, repo_health, test_results, monitoring_rollups, worker_cursors, app_config, feature_flags, worker_schedules, audit_log)

## Phase 3: Feature View & Task Tracking (US1 + US3 — P1/P2)

**Purpose**: Per-feature unified view and task tracker — the core value proposition
**Independent test**: Navigate to a feature page, verify spec summary, task list with Jira sync, PRs, deploys, tests, evidence, and timeline all render correctly

### Backend — Task Sync

- [X] T043 [US3] Create GitHub API client in `delivery-workbench-backend/src/services/github.ts` using octokit with PAT auth, rate-limit handling, and error classification (401 vs 429 vs 5xx)
- [X] T044 [US3] Create Jira API client in `delivery-workbench-backend/src/services/jira.ts` using jira.js with API token auth and error handling (503, timeout → error status)
- [X] T045 [US3] Create tasks.md parser in `delivery-workbench-backend/src/services/task-parser.ts` that extracts task IDs, checkbox states, Jira keys, and descriptions from markdown
- [X] T046 [US3] Create sync-tasks worker job in `delivery-workbench-backend/src/worker/sync-tasks.ts` that fetches tasks.md files from client-spec repo, parses them, compares with Jira statuses, writes task_sync_reports
- [X] T047 [US3] Create task tracker API routes in `delivery-workbench-backend/src/routes/tasks.ts`: GET /api/tasks/features, GET /api/tasks/features/:id, POST /api/tasks/sync/:id

### Backend — Repo & Deployment Health

- [X] T048 [US2] Create Cloud Run Admin client in `delivery-workbench-backend/src/services/gcp-run.ts` for fetching revision info, instance counts, and deployment timestamps
- [X] T049 [US2] Create sync-repos worker job in `delivery-workbench-backend/src/worker/sync-repos.ts` that fetches branch CI status, open PRs from GitHub API and writes repo_health
- [X] T050 [US2] Create sync-deployments worker job in `delivery-workbench-backend/src/worker/sync-deployments.ts` that fetches Cloud Run revision data and updates repo_health deployment fields
- [X] T051 [US2] Create repo health API routes in `delivery-workbench-backend/src/routes/repos.ts`: GET /api/repos (with ?refresh=true), GET /api/repos/:name, GET /api/repos/:name/deployments

### Backend — Feature Aggregation

- [X] T052 [US1] Create feature aggregator service in `delivery-workbench-backend/src/services/feature-aggregator.ts` that combines task sync, repo health, test results, and evidence data per feature
- [X] T053 [US1] Create feature API routes in `delivery-workbench-backend/src/routes/features.ts`: GET /api/features, GET /api/features/:id, GET /api/features/:id/timeline, GET /api/features/:id/evidence, GET /api/features/:id/artifacts

### Frontend — Task Tracker

- [X] T054 [US3] Create useTaskStore in `delivery-workbench-frontend/src/stores/taskStore.ts` with fetch/refresh actions and polling based on panel visibility
- [X] T055 [US3] Create TaskTrackerPage in `delivery-workbench-frontend/src/features/tasks/TaskTrackerPage.tsx` with feature list, completion bars, and sync status badges
- [X] T056 [US3] Create TaskDetailPage in `delivery-workbench-frontend/src/features/tasks/TaskDetailPage.tsx` with individual task checkboxes, Jira links, drift highlighting, and manual sync button

### Frontend — Repository & Deployment Health

- [X] T057 [US2] Create useRepoStore in `delivery-workbench-frontend/src/stores/repoStore.ts` with fetch/refresh actions
- [X] T058 [US2] Create RepoListPage in `delivery-workbench-frontend/src/features/repos/RepoListPage.tsx` with repo cards showing CI badge, open PR count, deployment timestamp, revision, instances
- [X] T059 [US2] Create RepoDetailPage in `delivery-workbench-frontend/src/features/repos/RepoDetailPage.tsx` with PR list, deployment history, branch status

### Frontend — Feature View

- [X] T060 [US1] Create useFeatureStore in `delivery-workbench-frontend/src/stores/featureStore.ts` aggregating data from other stores
- [X] T061 [US1] Create FeatureListPage in `delivery-workbench-frontend/src/features/features/FeatureListPage.tsx` with feature cards showing lifecycle status summary
- [X] T062 [US1] Create FeatureDetailPage in `delivery-workbench-frontend/src/features/features/FeatureDetailPage.tsx` with spec summary, task list, PRs, deployments, test results, evidence inline rendering
- [X] T063 [US1] Create FeatureTimeline component in `delivery-workbench-frontend/src/features/features/FeatureTimeline.tsx` with chronological event view (spec created, PRs, deploys, Jira transitions)

## Phase 4: Test Status (US4 — P2)

**Purpose**: Test visibility across repos with trend sparklines
**Independent test**: Verify test results match actual GitHub Actions workflow run outcomes per repo

### Backend

- [X] T064 [US4] Create sync-tests worker job in `delivery-workbench-backend/src/worker/sync-tests.ts` that fetches GitHub Actions workflow results, parses coverage from check annotations, writes test_results (retain last 10 per repo per type)
- [X] T065 [US4] Create test status API routes in `delivery-workbench-backend/src/routes/tests.ts`: GET /api/tests (with ?refresh=true), GET /api/tests/:repo

### Frontend

- [X] T066 [US4] Create useTestStore in `delivery-workbench-frontend/src/stores/testStore.ts`
- [X] T067 [US4] Create TestStatusPage in `delivery-workbench-frontend/src/features/tests/TestStatusPage.tsx` with test results grid showing pass/fail/coverage per repo, sparkline trends
- [X] T068 [US4] Create TestDetailPage in `delivery-workbench-frontend/src/features/tests/TestDetailPage.tsx` with last 10 runs table and coverage chart

## Phase 5: Configuration Management (US5 — P2)

**Purpose**: View/edit env vars, manage feature flags, app config, and worker schedules with audit trail
**Independent test**: Toggle a feature flag, verify consumer apps receive the update within 60 seconds and audit log entry is created

### Backend

- [X] T069 [US5] Create GitHub env var service methods in `delivery-workbench-backend/src/services/github.ts` for listing and updating environment variables with allowlist enforcement
- [X] T070 [US5] Create GCP Secret Manager client in `delivery-workbench-backend/src/services/gcp-secrets.ts` for listing secret names and last rotation dates
- [X] T071 [US5] Create OIDC token validation middleware in `delivery-workbench-backend/src/middleware/oidc.ts` using google-auth-library (verify signature, aud claim, return 401 on failure)
- [X] T072 [US5] Create config management API routes in `delivery-workbench-backend/src/routes/config.ts`: env vars (GET/PUT), secrets (GET), app config (GET/POST/PUT/DELETE), feature flags (GET/POST/PUT/DELETE), flags resolve (GET with OIDC), schedules (GET/PUT)

### Frontend

- [X] T073 [US5] Create useConfigStore in `delivery-workbench-frontend/src/stores/configStore.ts` with separate slices for env vars, secrets, app config, flags, schedules
- [X] T074 [US5] Create ConfigPage in `delivery-workbench-frontend/src/features/config/ConfigPage.tsx` with tab layout (Env Vars, Secrets, App Config, Feature Flags, Schedules)
- [X] T075 [US5] Create EnvVarsTab in `delivery-workbench-frontend/src/features/config/EnvVarsTab.tsx` with per-repo expandable sections, dev/prod columns, edit controls for allowlisted vars
- [X] T076 [US5] Create SecretsTab in `delivery-workbench-frontend/src/features/config/SecretsTab.tsx` with read-only secret name list and rotation dates
- [X] T077 [US5] Create AppConfigTab in `delivery-workbench-frontend/src/features/config/AppConfigTab.tsx` with CRUD table for key-value pairs
- [X] T078 [US5] Create FeatureFlagsTab in `delivery-workbench-frontend/src/features/config/FeatureFlagsTab.tsx` with toggle switches, environment scope selector, create/delete controls
- [X] T079 [US5] Create SchedulesTab in `delivery-workbench-frontend/src/features/config/SchedulesTab.tsx` with interval editors per worker job

## Phase 6: Monitoring (US6 — P3)

**Purpose**: GCP metrics dashboards with drill-down to live logs and traces
**Independent test**: Verify summary card values match GCP Cloud Monitoring data within aggregation interval; drill-down returns live data

### Backend

- [X] T080 [US6] Create Cloud Monitoring client in `delivery-workbench-backend/src/services/gcp-monitoring.ts` for querying time-series metrics (Cloud Run, Cloud SQL, Cloud Storage)
- [X] T081 [US6] Create Cloud Logging client in `delivery-workbench-backend/src/services/gcp-logging.ts` for live log queries with severity/service filtering
- [X] T082 [US6] Create aggregate-metrics worker job in `delivery-workbench-backend/src/worker/aggregate-metrics.ts` that queries Cloud Monitoring API and writes hourly/daily rollups to monitoring_rollups table
- [X] T083 [US6] Create monitoring API routes in `delivery-workbench-backend/src/routes/monitoring.ts`: GET /api/monitoring/summary (with ?refresh=true), GET /api/monitoring/cloud-run/:svc, GET /api/monitoring/cloud-sql, GET /api/monitoring/storage, GET /api/monitoring/logs, GET /api/monitoring/traces/:traceId

### Frontend

- [X] T084 [US6] Create useMonitoringStore in `delivery-workbench-frontend/src/stores/monitoringStore.ts` with time-range state and drill-down data
- [X] T085 [US6] Create MonitoringPage in `delivery-workbench-frontend/src/features/monitoring/MonitoringPage.tsx` with summary cards (request rate, error rate, latency, instances), time-range selector (24h/7d/30d), Cloud SQL and Storage cards
- [X] T086 [US6] Create ServiceDetailPage in `delivery-workbench-frontend/src/features/monitoring/ServiceDetailPage.tsx` with trend charts, log viewer with severity filter, and trace explorer

## Phase 7: Dashboard & Status (US7 — P3)

**Purpose**: Landing page overview and status bar with worker health
**Independent test**: Dashboard renders 6 summary cards with metrics; clicking each navigates to correct panel

### Frontend

- [X] T087 [US7] Create DashboardPage in `delivery-workbench-frontend/src/features/dashboard/DashboardPage.tsx` with 6 summary cards (features, tasks, repos, tests, config, monitoring) each showing key metrics and linking to panel pages
- [X] T088 [US7] Wire StatusBar in `delivery-workbench-frontend/src/components/layout/StatusBar.tsx` to health endpoint data showing worker job names, last-run times, and on-schedule status

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Accessibility, error handling, E2E tests, deployment, documentation

- [ ] T089 Create Jira Epic for 033-delivery-workbench via Atlassian MCP and backfill Epic key into spec.md and tasks.md — DEFERRED: Atlassian MCP unavailable
- [X] T090 [P] Implement stale-data warning component in `delivery-workbench-frontend/src/components/common/StaleDataWarning.tsx` and integrate into all panel pages when data exceeds 2x polling interval
- [X] T091 [P] Implement rate-limit banner in `delivery-workbench-frontend/src/components/common/RateLimitBanner.tsx` for GitHub API rate limiting (429 / X-RateLimit-Remaining: 0)
- [X] T092 [P] Implement credential failure banner in `delivery-workbench-frontend/src/components/common/CredentialBanner.tsx` for GitHub PAT expiry (401 from health endpoint)
- [ ] T093 Run WCAG AA accessibility audit on all pages using axe-core and fix violations (contrast ratios 4.5:1/3:1, keyboard navigation, focus indicators, screen reader labels)
- [ ] T094 [P] Create Playwright E2E tests in `chat-ui/tests/delivery-workbench/` for critical flows: login via IAP, dashboard load, feature view navigation, config flag toggle
- [ ] T095 Deploy `delivery-workbench-backend` and `delivery-workbench-frontend` to production (single environment) via develop branch push
- [ ] T096 Run database migrations on Cloud SQL `delivery-db` instance
- [ ] T097 Verify production deployment: health endpoint returns healthy, dashboard loads, all panels render data
- [ ] T098 Update Technical Onboarding in Confluence with delivery workbench section (repo structure, local setup, access control)

## Dependencies

```
Phase 1 (Setup/Infra) ──→ Phase 2 (Foundation)
Phase 2 (Foundation)  ──→ Phase 3 (US1+US2+US3: Feature View, Repos, Tasks)
Phase 2 (Foundation)  ──→ Phase 4 (US4: Test Status) — can parallel with Phase 3
Phase 2 (Foundation)  ──→ Phase 5 (US5: Config) — can parallel with Phase 3
Phase 2 (Foundation)  ──→ Phase 6 (US6: Monitoring) — can parallel with Phase 3
Phase 3 (US1+US2+US3) ──→ Phase 7 (US7: Dashboard) — needs all panel stores
Phase 4 (US4)         ──→ Phase 7 (US7: Dashboard)
Phase 5 (US5)         ──→ Phase 7 (US7: Dashboard)
Phase 6 (US6)         ──→ Phase 7 (US7: Dashboard)
All phases            ──→ Phase 8 (Polish & Deploy)
```

## Parallel Execution Opportunities

- **Phase 1**: T003-T008 are all independent infra provisioning tasks
- **Phase 2**: Backend (T012-T027) and frontend (T028-T040) can be built in parallel
- **Phase 3**: Backend tasks (T043-T053) can start before frontend (T054-T063), but frontend needs API to be available
- **Phases 3-6**: Phases 4, 5, and 6 can run in parallel with Phase 3 (all depend only on Phase 2 foundation)
- **Phase 8**: T090-T092 (error banners) are independent of each other

## Implementation Strategy

1. **MVP**: Phase 1 + Phase 2 + Phase 3 (Feature View + Task Tracker + Repo Health) — delivers the core value proposition
2. **Increment 2**: Phase 4 + Phase 5 (Test Status + Config Management)
3. **Increment 3**: Phase 6 + Phase 7 (Monitoring + Dashboard)
4. **Polish**: Phase 8 (Accessibility, error handling, E2E tests, deploy)

## Summary

- **Total tasks**: 98
- **Phase 1 (Setup)**: 11 tasks
- **Phase 2 (Foundation)**: 31 tasks
- **Phase 3 (US1+US2+US3)**: 21 tasks
- **Phase 4 (US4)**: 5 tasks
- **Phase 5 (US5)**: 11 tasks
- **Phase 6 (US6)**: 7 tasks
- **Phase 7 (US7)**: 2 tasks
- **Phase 8 (Polish)**: 10 tasks

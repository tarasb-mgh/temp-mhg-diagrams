# Implementation Plan: Delivery Workbench

**Branch**: `033-delivery-workbench` | **Date**: 2026-03-19 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/033-delivery-workbench/spec.md`

## Summary

Build an internal delivery workbench for the MHG tech team that provides
unified visibility into feature lifecycle, repository health, test status,
configuration management, and GCP monitoring. The system consists of a
React SPA frontend and an Express.js backend with a separate worker
process for data aggregation, all deployed to GCP with IAP authentication.

## Technical Context

**Language/Version**: TypeScript 5.x (Node.js 20 LTS)
**Primary Dependencies**:
- Frontend: React 18, Vite 5, Tailwind CSS 3, Zustand 5, React Router 6
- Backend: Express.js 5, `@google-cloud/monitoring`, `@google-cloud/logging`,
  `@google-cloud/run`, `octokit`, `jira.js`, `pg`
**Storage**: PostgreSQL via Cloud SQL (`delivery-db`)
**Testing**: Vitest (unit), Playwright (E2E in `chat-ui`)
**Target Platform**: GCP Cloud Run (backend), GCS + GCLB (frontend)
**Project Type**: Web application (SPA + API + Worker)
**Performance Goals**: Dashboard loads < 3s, API responses < 500ms,
flags endpoint < 200ms
**Constraints**: Single environment (no dev/prod split), desktop-only,
English-only, WCAG AA
**Scale/Scope**: 5 deployable repos monitored, ~10 active features,
small tech team (< 10 users)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Spec-First | PASS | Spec at `specs/033-delivery-workbench/spec.md` |
| II. Multi-Repo Orchestration | PASS | Two new repos: `delivery-workbench-frontend`, `delivery-workbench-backend` |
| III. Test-Aligned | PASS | Vitest for unit tests in both repos |
| IV. Branch Discipline | PASS | Feature branch `033-delivery-workbench` in all repos |
| V. Privacy & Security | PASS | IAP auth, OIDC token validation, audit logging, no PII |
| VI. Accessibility & i18n | PASS (reduced) | WCAG AA required; English-only per Delivery Workbench exemption |
| VII. Split-Repo First | PASS | New split repos, no monorepo involvement |
| VIII. GCP CLI Infra | PASS | All infra scripted in `chat-infra`, Secret Manager for credentials |
| IX. Responsive UX / PWA | EXEMPT | Desktop-only per Delivery Workbench exemption |
| X. Jira Traceability | PENDING | Epic creation deferred (Atlassian MCP unavailable) |
| XI. Documentation | PASS | Will update Technical Onboarding post-deployment |
| XII. Release Engineering | PASS (simplified) | Single environment, no release branch needed |

## Project Structure

### Documentation (this feature)

```text
specs/033-delivery-workbench/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (OpenAPI spec)
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (two repositories)

```text
delivery-workbench-frontend/        # D:\src\MHG\delivery-workbench-frontend
├── src/
│   ├── components/                 # Shared UI components
│   │   ├── layout/                 # Shell, Sidebar, TopBar, StatusBar
│   │   ├── common/                 # Cards, badges, tables, charts
│   │   └── panels/                 # Panel-specific components
│   ├── features/                   # Feature modules by panel
│   │   ├── dashboard/              # Dashboard summary page
│   │   ├── features/               # Feature view (per-feature unified)
│   │   ├── tasks/                  # Task tracker panel
│   │   ├── repos/                  # Repository health panel
│   │   ├── tests/                  # Test status panel
│   │   ├── config/                 # Configuration management panel
│   │   └── monitoring/             # Monitoring panel
│   ├── stores/                     # Zustand stores (one per domain)
│   ├── services/                   # API client layer
│   ├── hooks/                      # Custom React hooks
│   ├── types/                      # TypeScript type definitions
│   ├── routes/                     # Route definitions
│   ├── App.tsx                     # Root component
│   └── main.tsx                    # Entry point
├── public/                         # Static assets
├── tests/                          # Unit tests (Vitest)
├── vite.config.ts
├── tailwind.config.js
├── tsconfig.json
├── vitest.config.ts
├── package.json
├── Dockerfile                      # For GCS deploy (build stage only)
├── .github/workflows/
│   ├── ci.yml
│   └── deploy.yml
├── CLAUDE.md
└── AGENTS.md

delivery-workbench-backend/         # D:\src\MHG\delivery-workbench-backend
├── src/
│   ├── server.ts                   # API server entry point
│   ├── worker.ts                   # Worker entry point
│   ├── app.ts                      # Express app setup
│   ├── routes/                     # API route handlers
│   │   ├── features.ts             # /api/features/*
│   │   ├── tasks.ts                # /api/tasks/*
│   │   ├── repos.ts                # /api/repos/*
│   │   ├── tests.ts                # /api/tests/*
│   │   ├── config.ts               # /api/config/*
│   │   ├── monitoring.ts           # /api/monitoring/*
│   │   └── health.ts               # /api/health
│   ├── services/                   # Business logic
│   │   ├── github.ts               # GitHub API client (octokit)
│   │   ├── jira.ts                 # Jira API client (jira.js)
│   │   ├── gcp-monitoring.ts       # Cloud Monitoring client
│   │   ├── gcp-logging.ts          # Cloud Logging client
│   │   ├── gcp-run.ts              # Cloud Run Admin client
│   │   ├── gcp-storage.ts          # Cloud Storage client
│   │   ├── gcp-secrets.ts          # Secret Manager client
│   │   ├── task-parser.ts          # tasks.md parser
│   │   └── feature-aggregator.ts   # Per-feature data aggregation
│   ├── worker/                     # Worker job definitions
│   │   ├── scheduler.ts            # Job scheduler (interval-based)
│   │   ├── sync-tasks.ts           # Task/Jira sync job
│   │   ├── sync-repos.ts           # Repo health sync job
│   │   ├── sync-tests.ts           # Test results sync job
│   │   ├── sync-deployments.ts     # Deployment status sync job
│   │   └── aggregate-metrics.ts    # GCP metrics aggregation job
│   ├── db/                         # Database layer
│   │   ├── connection.ts           # PostgreSQL connection pool
│   │   ├── migrations/             # SQL migration files
│   │   └── queries/                # Parameterized queries per table
│   ├── middleware/                  # Express middleware
│   │   ├── iap.ts                  # IAP user email extraction
│   │   ├── oidc.ts                 # OIDC token validation (flags endpoint)
│   │   ├── error.ts                # Error handling middleware
│   │   └── audit.ts                # Audit logging middleware
│   ├── types/                      # TypeScript type definitions
│   └── utils/                      # Helper functions
├── tests/                          # Unit tests (Vitest)
├── Dockerfile                      # Multi-target: server + worker
├── .github/workflows/
│   ├── ci.yml
│   └── deploy.yml
├── tsconfig.json
├── vitest.config.ts
├── package.json
├── CLAUDE.md
└── AGENTS.md
```

**Structure Decision**: Two separate repositories following the existing
split-repo pattern. The backend repo contains both the API server and
worker as separate entry points sharing the same codebase. The frontend
follows the same Vite + React + Tailwind pattern as `workbench-frontend`.

## Implementation Order

### Phase 1: Infrastructure & Foundation

1. **Create GitHub repositories** (`delivery-workbench-frontend`,
   `delivery-workbench-backend`) under MentalHelpGlobal org
2. **Register repos** in `chat-infra/config/github-repos.json` and
   run `setup-github.sh`
3. **Provision GCP resources**: Cloud SQL instance (`delivery-db`),
   GCS bucket, Cloud Run service, Cloud Run Job, Cloud Scheduler,
   IAP, GCLB URL map rules, DNS records
4. **Store credentials**: GitHub PAT and Atlassian API token in
   Secret Manager
5. **Initialize backend**: Express app, DB connection, migrations,
   health endpoint
6. **Initialize frontend**: Vite + React + Tailwind scaffold, routing,
   layout shell (sidebar, top bar, status bar)
7. **CI/CD workflows**: `ci.yml` and `deploy.yml` for both repos

### Phase 2: Core Panels (P1 User Stories)

8. **Backend: Task sync worker job** + API endpoints (`/api/tasks/*`)
9. **Backend: Repo health worker job** + API endpoints (`/api/repos/*`)
10. **Backend: Deployment sync worker job** (extends repo health)
11. **Frontend: Task Tracker panel** (feature list, completion bars,
    sync status)
12. **Frontend: Repository & Deployment panel** (repo cards, CI badges,
    deployment info)
13. **Backend: Feature aggregation** + API endpoints (`/api/features/*`)
14. **Frontend: Feature View** (per-feature unified page, timeline)

### Phase 3: Supporting Panels (P2 User Stories)

15. **Backend: Test sync worker job** + API endpoints (`/api/tests/*`)
16. **Frontend: Test Status panel** (results grid, sparklines)
17. **Backend: Config management** endpoints (`/api/config/*`)
18. **Backend: OIDC middleware** for flags resolve endpoint
19. **Frontend: Configuration panel** (env vars, flags, app config,
    schedules)

### Phase 4: Monitoring & Dashboard (P3 User Stories)

20. **Backend: Metrics aggregation worker job** + API endpoints
    (`/api/monitoring/*`)
21. **Backend: Log/trace drill-down** proxy endpoints
22. **Frontend: Monitoring panel** (summary cards, trend charts,
    drill-down)
23. **Frontend: Dashboard** (summary cards from all panels)
24. **Frontend: Status bar** (worker health, job last-run times)

### Phase 5: Polish & Deploy

25. **Jira Epic creation**: Create MTB Epic via Atlassian MCP (or
    manually) and backfill the Epic key into `spec.md` and `tasks.md`
26. **WCAG AA audit** and accessibility fixes
27. **Error handling**: stale-data warnings, rate-limit banners,
    credential failure banners
28. **E2E tests** in `chat-ui` for critical flows
29. **Deploy to production** (single environment)
30. **Update Technical Onboarding** in Confluence

## Cross-Repository Dependencies

| Step | Depends On | Target Repo |
|------|-----------|-------------|
| 5-7 | 1-4 (infra) | `delivery-workbench-backend`, `delivery-workbench-frontend` |
| 8-10 | 5 (backend foundation) | `delivery-workbench-backend` |
| 11-12 | 6 + 8-10 (frontend shell + backend APIs) | `delivery-workbench-frontend` |
| 13-14 | 8-10 (underlying panel data) | both repos |
| 15-19 | 5 (backend foundation) | both repos |
| 20-24 | 5 (backend foundation) | both repos |
| 25-27 | All panels complete | both repos + `chat-ui` |
| 28 | 25-27 | `chat-infra` |

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Two new repositories | Constitution requires split repos; backend + frontend have independent deploy cycles | Single repo would violate Principle VII |
| Dedicated Cloud SQL instance | Worker writes conflict with chat-backend queries; isolation prevents cross-impact | Sharing `chat-db-dev` risks performance interference |
| Cloud Run Job (worker) | Polling must continue independently of API request load | In-process intervals require min-instances=1 (cost) |

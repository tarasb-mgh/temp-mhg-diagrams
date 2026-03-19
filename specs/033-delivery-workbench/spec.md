# Feature Specification: Delivery Workbench

**Feature Branch**: `033-delivery-workbench`
**Created**: 2026-03-19
**Status**: Draft
**Jira Epic**: [PENDING: Epic creation — Atlassian MCP unavailable 2026-03-19T00:00:00Z]
**Input**: User description: "Build an internal delivery workbench for the tech team that acts as a high-level orchestrator for the development process — providing unified visibility into tasks, repositories, deployments, testing, configuration, and GCP monitoring across all deployable services."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - View Feature Lifecycle at a Glance (Priority: P1)

A tech team member opens the delivery workbench and navigates to a specific feature to understand its current state. They see the feature's specification summary, task completion progress with Jira sync status, pull requests across all affected repositories, deployment status, test results on the feature branch, and evidence artifacts — all on a single page. They can view a chronological timeline of the feature's lifecycle events.

**Why this priority**: The per-feature unified view is the core value proposition — it eliminates the need to check multiple systems (GitHub, Jira, GCP Console, speckit files) to understand where a feature stands. Without this, the workbench is just a collection of separate dashboards.

**Independent Test**: Can be fully tested by creating a feature with known spec, tasks, PRs, and test results, then verifying the feature view page aggregates all data correctly with accurate completion percentages and sync status.

**Acceptance Scenarios**:

1. **Given** a feature with a spec, tasks, and open PRs, **When** the user navigates to `/features/:id`, **Then** they see the spec summary, task list with completion percentage, PR list with CI status, and deployment state for each affected repo.
2. **Given** a feature where 3 of 5 tasks are checked in tasks.md but only 2 are marked Done in Jira, **When** the user views the feature, **Then** the sync status shows "drifted" and highlights the specific mismatched tasks.
3. **Given** a feature with evidence files (screenshots, logs) in the evidence directory, **When** the user views the feature, **Then** image evidence is rendered inline and text evidence is displayed with syntax highlighting.
4. **Given** a feature with multiple lifecycle events, **When** the user views the timeline, **Then** events appear in chronological order showing spec creation, plan completion, task generation, PR opens/merges, deployments, and Jira transitions.

---

### User Story 2 - Monitor Repository and Deployment Health (Priority: P1)

A tech team member opens the dashboard to quickly assess whether all deployable services are healthy. They see summary cards showing CI status, open PR counts, and deployment info for each deployable repo. They can drill into any repo for more detail.

**Why this priority**: Repository and deployment health is the most time-sensitive information — knowing immediately if a CI pipeline is broken or a deployment failed prevents cascading issues. Co-prioritized with US1 because it provides the real-time operational awareness.

**Independent Test**: Can be fully tested by verifying that each of the five deployable repos shows accurate CI status (matching GitHub Actions), correct open PR count, and deployment timestamps matching Cloud Run revision data.

**Acceptance Scenarios**:

1. **Given** all deployable repos have passing CI, **When** the user views the repos panel, **Then** all repos show green CI badges.
2. **Given** one repo has a failing CI run on its default branch, **When** the user views the repos panel, **Then** that repo shows a red CI badge while others remain green.
3. **Given** a repo was deployed 10 minutes ago, **When** the user views the repo detail, **Then** the deployment timestamp is within 1 minute of the actual Cloud Run revision deploy time, and the revision name and active instance count match the values from the Cloud Run Admin API.

---

### User Story 3 - Track Task Progress and Jira Sync (Priority: P2)

A tech team member views the task tracker to understand progress across all active features. They see each feature's completion percentage and whether tasks.md and Jira are in sync. They can trigger a manual sync for any feature and drill into individual task details.

**Why this priority**: Task tracking provides project management visibility but is less time-sensitive than deployment health. The data is useful for planning and status reporting rather than immediate operational decisions.

**Independent Test**: Can be fully tested by creating features with known task states in tasks.md and corresponding Jira issues, then verifying the tracker shows correct completion percentages and accurately detects sync drift.

**Acceptance Scenarios**:

1. **Given** a feature with 10 tasks where 7 are checked, **When** the user views the task tracker, **Then** it shows 70% completion.
2. **Given** tasks.md and Jira are out of sync for a feature, **When** the user views the tracker, **Then** it shows "drifted" status with specific mismatches listed.
3. **Given** Jira is temporarily unavailable, **When** the worker attempts to sync, **Then** the tracker shows "error" status (not "drifted") and retains the last known valid sync data.
4. **Given** the user triggers a manual sync, **When** the sync completes, **Then** the task data refreshes immediately without waiting for the next polling cycle.

---

### User Story 4 - View Test Results Across Repos (Priority: P2)

A tech team member checks the test status panel to see whether all tests are passing across the deployable repos. They see the last run result (pass/fail), coverage percentage, and a trend of the last 10 runs for each repo.

**Why this priority**: Test visibility supports quality assurance but is typically consumed less frequently than deployment health. The trend view helps identify flaky tests or declining coverage over time.

**Independent Test**: Can be fully tested by verifying that test results match the actual GitHub Actions workflow run outcomes and coverage output for each repo.

**Acceptance Scenarios**:

1. **Given** a repo with its latest CI passing at 85% coverage, **When** the user views the test panel, **Then** it shows "pass" with "85%" coverage.
2. **Given** a repo with 10 recent CI runs (8 pass, 2 fail), **When** the user views the test detail, **Then** a sparkline shows the pass/fail pattern for all 10 runs.
3. **Given** the Playwright E2E suite in chat-ui ran against the dev environment, **When** the user views test status, **Then** the E2E result appears alongside unit and API test results.

---

### User Story 5 - Manage Configuration and Feature Flags (Priority: P2)

A tech team member uses the configuration panel to view and edit environment variables across repos, toggle feature flags, manage application configuration, and adjust worker polling schedules. All changes are audited.

**Why this priority**: Configuration management reduces the friction of using CLI tools for routine config changes. Feature flags enable controlled rollouts. However, this is a convenience feature — the team can still use CLI tools directly.

**Independent Test**: Can be fully tested by toggling a feature flag in the UI and verifying that consumer apps receive the updated flag value within 60 seconds, and that an audit log entry is created.

**Acceptance Scenarios**:

1. **Given** a GitHub environment variable on the allowlist, **When** the user edits its value, **Then** the value is updated in GitHub and an audit log entry records the change with the user's email, old value, and new value.
2. **Given** a GitHub environment variable NOT on the allowlist, **When** the user views it, **Then** it is displayed as read-only with no edit option.
3. **Given** a feature flag set to disabled, **When** the user toggles it to enabled, **Then** consumer apps polling the flags endpoint receive the updated value within 60 seconds.
4. **Given** the user changes a worker schedule interval, **When** the next worker execution cycle occurs (within 1 minute), **Then** the job runs on the new schedule without requiring a redeployment.
5. **Given** any configuration change, **When** the write succeeds, **Then** exactly one audit log entry is created in the same database transaction as the change.

---

### User Story 6 - Monitor GCP Services (Priority: P3)

A tech team member views the monitoring panel to check Cloud Run request rates, error rates, latency, Cloud SQL health, and Cloud Storage usage. Summary cards show cached aggregated data. The user can drill down into any metric for live data from GCP, including log searching and trace inspection.

**Why this priority**: Monitoring is valuable but GCP Console already provides this data. The delivery workbench adds value by aggregating it in one place alongside other panels, but it's not functionality that's otherwise impossible to access.

**Independent Test**: Can be fully tested by verifying that summary card values match the corresponding GCP Cloud Monitoring data points within the aggregation interval, and that drill-down queries return live data consistent with GCP Console views.

**Acceptance Scenarios**:

1. **Given** a Cloud Run service with recent traffic, **When** the user views the monitoring summary, **Then** request rate, error rate (4xx/5xx), and p50/p95 latency are displayed with data no older than 2x the aggregation interval.
2. **Given** the user selects a 7-day time range, **When** the trend chart renders, **Then** it shows daily rollup data points for the selected period.
3. **Given** the user clicks on an error rate metric, **When** the drill-down loads, **Then** it shows live log entries from Cloud Logging filtered to error-level messages for that service.
4. **Given** Cloud SQL is experiencing high connection counts, **When** the user views the monitoring panel, **Then** the Cloud SQL card shows the current active connection count and query latency.
5. **Given** the GCP Monitoring API is temporarily unavailable, **When** the user views the monitoring panel, **Then** cached data is displayed with a stale-data warning indicator showing the last-refreshed timestamp.

---

### User Story 7 - Dashboard Overview (Priority: P3)

A tech team member opens the delivery workbench landing page and sees a single-screen overview with summary cards from all six panels: features, tasks, repos, tests, config, and monitoring. Each card shows key metrics and links to its full panel.

**Why this priority**: The dashboard provides at-a-glance awareness but depends on all other panels being functional. It's a convenience aggregation layer, not standalone functionality.

**Independent Test**: Can be fully tested by verifying that the dashboard renders six summary cards, each displaying at least one numeric metric, and that clicking each card navigates to the correct panel page.

**Acceptance Scenarios**:

1. **Given** the user is authenticated via IAP, **When** they navigate to `/`, **Then** six summary cards are displayed (features, tasks, repos, tests, config, monitoring).
2. **Given** the repos card shows "4/5 repos green", **When** the user clicks it, **Then** they navigate to `/repos` where the same data is shown in detail.
3. **Given** the user's email is passed by IAP, **When** the dashboard loads, **Then** the top bar displays the authenticated user's email.

---

### Edge Cases

- **GitHub API rate limiting**: When GitHub API returns 429 or `X-RateLimit-Remaining: 0`, the system retains last known data and displays a rate-limit banner with the reset time. No data is lost or corrupted.
- **Jira unavailability**: When Jira returns 503 or times out, task sync status shows "error" (distinct from "drifted"). Previous valid sync data is preserved.
- **Worker job failure mid-execution**: Database writes use transactions. Polling cursors advance only after successful completion. Failed jobs retry on the next scheduled tick.
- **Database connection loss**: All API endpoints return 503. Health endpoint returns `{ status: "unhealthy", db: "unreachable" }`. Worker skips all jobs.
- **Stale cached data**: When data is older than 2x the configured polling interval, the UI shows a stale-data warning with the last-refreshed timestamp.
- **Config write with audit failure**: Config changes and audit log entries share a single database transaction. If the audit insert fails, the config change is rolled back — no change without audit trail.
- **IAP-excluded endpoint abuse**: The `/api/config/flags/resolve` endpoint validates OIDC tokens (signature, audience claim). Missing or invalid tokens receive 401. Only service-to-service requests with correct audience are accepted.
- **Evidence files missing**: When a feature's evidence directory does not exist or is empty, the feature view shows "No evidence collected" rather than an error.
- **GitHub PAT expired or revoked**: When GitHub API returns 401, all GitHub-dependent worker jobs (sync-repos, sync-tests, sync-tasks, sync-deployments) mark their status as "error" with a message distinguishing credential failure from rate limiting. The health endpoint surfaces "github-auth: failed" under connectivity status. The UI shows a "GitHub authentication failed — credential rotation required" banner.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST authenticate all users via GCP Identity-Aware Proxy using Google Workspace accounts, with access controlled by the `roles/iap.httpsResourceAccessUser` IAM role.
- **FR-002**: System MUST display a dashboard with six summary cards (features, tasks, repos, tests, config, monitoring), each showing at least one numeric metric and linking to its full panel.
- **FR-003**: System MUST show a per-feature unified view aggregating specification summary, task completion with Jira sync status, pull requests across repos, deployment status, test results, evidence artifacts, plan documents, and a chronological timeline.
- **FR-004**: System MUST track speckit tasks.md completion status and compare against Jira issue statuses, reporting sync state as "in-sync", "drifted", or "error" per feature.
- **FR-005**: System MUST display repository health for the five deployable repos: CI status (green/red/pending), open PR count, last deployment timestamp, Cloud Run revision, and active instance count.
- **FR-006**: System MUST display test results per repo: last run pass/fail status, coverage percentage, and a trend of the last 10 runs.
- **FR-007**: System MUST allow viewing GitHub environment variables (dev and prod) for managed repos, with editing restricted to variables on an explicit allowlist of non-sensitive names.
- **FR-008**: System MUST allow viewing GCP Secret Manager secret names (without values) per repo.
- **FR-009**: System MUST allow creating, reading, updating, and deleting application configuration key-value pairs stored in the delivery workbench database.
- **FR-010**: System MUST allow creating, reading, updating, and toggling feature flags with environment scope (dev/prod/all), with changes propagated to consumer apps within 60 seconds.
- **FR-011**: System MUST expose a flags resolution endpoint that consumer apps can call with service-to-service authentication (OIDC token with audience validation), excluded from IAP.
- **FR-012**: System MUST allow configuring worker polling intervals through the UI, with changes taking effect within 1 minute of the next worker execution cycle without redeployment.
- **FR-013**: System MUST display Cloud Run metrics (request rate, error rate, latency percentiles, instance count), Cloud SQL metrics (connections, query latency, storage), and Cloud Storage metrics (bucket sizes, request counts) from cached aggregated data.
- **FR-014**: System MUST support drill-down from aggregated metrics to live GCP data: log searching via Cloud Logging and trace inspection via Cloud Trace.
- **FR-015**: System MUST record an audit log entry for every configuration change (env var, feature flag, app config, schedule), including the user's email (from IAP header), old value, new value, and timestamp, in the same database transaction as the change. For create operations, old_value is recorded as null. For delete operations, new_value is recorded as null.
- **FR-016**: System MUST expose a health endpoint reporting per-dependency status (database, GCP connectivity) and per-worker-job status (last run timestamp, last error, and whether the job last ran within 2x its configured interval).
- **FR-017**: System MUST display a stale-data warning when cached data is older than 2x the configured polling interval for the relevant job.
- **FR-018**: System MUST support manual refresh for any panel, triggering a live data fetch bypassing the cache.
- **FR-019**: System MUST meet WCAG AA accessibility standards: keyboard navigation, colour contrast ratios (4.5:1 normal text, 3:1 large text), visible focus indicators, and screen reader compatibility.

### Key Entities

- **Feature**: A development initiative identified by its spec directory name (e.g., `032-review-queue`). Has a spec, tasks, PRs, deployments, test results, and evidence. Linked to a Jira Epic.
- **Task Sync Report**: Comparison between tasks.md checkbox states and Jira issue statuses for a feature. States: in-sync, drifted, error.
- **Repository Health**: Snapshot of a deployable repo's CI status, open PRs, and deployment state.
- **Test Result**: A CI workflow run outcome for a repo: pass/fail, coverage, workflow type (unit/API/E2E).
- **Monitoring Rollup**: Aggregated metric data point for a service, metric type, and time period (hourly/daily).
- **App Config Entry**: A key-value pair with description, stored in the delivery workbench database, consumed by other applications at runtime.
- **Feature Flag**: A named boolean toggle with environment scope (dev/prod/all), consumed by chat and workbench applications.
- **Worker Schedule**: Configuration for a polling job's interval, stored in the database, governing how frequently the worker executes that job.
- **Audit Log Entry**: Record of a configuration change: action, entity, old/new values, user email, timestamp.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Team members can assess the health of all deployable services within 30 seconds of opening the workbench (dashboard loads and displays current data without requiring navigation to external tools).
- **SC-002**: A per-feature status check that previously required visiting 4+ systems (GitHub, Jira, GCP Console, local speckit files) can be completed from a single page in under 60 seconds.
- **SC-003**: Configuration changes (feature flag toggles, env var updates) that previously required CLI tool usage can be completed through the UI in under 30 seconds, with full audit trail.
- **SC-004**: Monitoring summary data is available within 2x the configured aggregation interval of the actual GCP metric timestamp — no manual GCP Console navigation required for routine health checks.
- **SC-005**: Task/Jira sync drift is detected and displayed within 10 minutes of the state change occurring (assuming default 5-minute polling interval).
- **SC-006**: All interactive elements are accessible via keyboard and meet WCAG AA contrast ratios, verified by automated accessibility audit.
- **SC-007**: The flags resolution endpoint responds to consumer app requests within 200ms (measured at the application layer, excluding network latency).

## Assumptions

- The tech team has Google Workspace accounts for IAP authentication.
- The five deployable repos (chat-backend, chat-frontend, workbench-frontend, delivery-workbench-frontend, delivery-workbench-backend) use GitHub Actions for CI/CD with standard workflow naming conventions.
- Speckit tasks.md files follow the established format with Jira issue keys inline.
- The GCP project (`mental-help-global-25`) has Cloud Monitoring, Cloud Logging, and Cloud Trace APIs enabled.
- GitHub PAT and Atlassian API token will be provisioned in GCP Secret Manager before deployment.
- Consumer apps (chat-frontend, workbench-frontend) will be updated to poll the flags resolution endpoint — this is a separate feature/task.
- The delivery workbench operates in a single environment (no dev/prod split) per the project constitution.
- Desktop browser usage only — no mobile or tablet optimization required.
- English-only interface — no internationalization required.

## Scope Boundaries

### In Scope

- Six dashboard panels: Feature View, Task Tracker, Repository & Deployment Health, Test Status, Configuration Management, Monitoring
- Per-feature unified lifecycle view with timeline
- Read-only and write operations as specified per panel
- Worker-based data aggregation on configurable schedules
- Audit logging for all configuration changes
- Health endpoint with per-dependency and per-job status

### Out of Scope

- Deployment triggering (workbench shows status, does not initiate deploys)
- Alert/notification delivery (no email, Slack, or PagerDuty integration)
- Source code modifications (config panel manages env vars and flags, not code)
- Multi-environment support for the workbench itself (single environment only)
- User management (access controlled via GCP IAM, no in-app user admin)
- Historical analytics beyond 30-day default retention
- Mobile/tablet interface (desktop only)

# Research: Delivery Workbench

**Feature Branch**: `033-delivery-workbench`
**Date**: 2026-03-19

## Decision Log

### 1. Authentication: IAP vs Firebase Auth vs OAuth 2.0

**Decision**: GCP Identity-Aware Proxy (IAP)

**Rationale**: IAP handles authentication at the infrastructure layer —
unauthenticated requests never reach the application. This means zero
auth code in the app, no session management, no token refresh logic.
Access is controlled via IAM roles (`roles/iap.httpsResourceAccessUser`),
which integrates with Google Workspace accounts the team already has.

**Alternatives considered**:
- **Firebase Auth / Identity Platform**: Requires auth code in the app
  (sign-in UI, token management, middleware). Overkill for an internal
  tool where all users have Google Workspace accounts.
- **OAuth 2.0 consent flow**: More control over scopes but significant
  implementation effort. IAP provides the same Google auth with zero
  code.

**Trade-off**: IAP only works with GCP-hosted services behind a GCLB.
Since both the frontend (GCS + GCLB) and backend (Cloud Run + GCLB)
are already on GCP, this is not a limitation.

### 2. Architecture: Monolith vs Backend + Worker Split

**Decision**: Backend + Worker split (API server as Cloud Run service,
worker as Cloud Run Job triggered by Cloud Scheduler)

**Rationale**: Clean separation between request-serving and periodic
polling. The worker can scale independently (or not run at all during
low-usage periods). Cloud Run Jobs are cost-effective — they only run
when triggered, unlike always-on services.

**Alternatives considered**:
- **Monolith with background intervals**: Simpler but requires
  `min-instances=1` on Cloud Run to keep polling alive (cost).
  Mixing request handling with polling can cause resource contention.
- **Full microservices**: Overkill for the scale. Each worker job
  doesn't need its own service.

### 3. GitHub Integration: CLI vs REST API (octokit)

**Decision**: `octokit` (GitHub REST API client library)

**Rationale**: The backend runs in a Docker container on Cloud Run.
Client libraries provide structured responses, proper error handling,
built-in pagination, and authentication via constructor injection.
No need to install CLI tools in the Docker image or parse stdout.

**Alternatives considered**:
- **`gh` CLI**: Designed for developer workstations, not server-side
  automation. Requires installation in Docker image, stdout parsing,
  and credential management via `gh auth`.
- **GraphQL API**: More efficient for some queries but adds complexity.
  REST API is sufficient for the data we need (repo status, PRs,
  workflow runs, env vars).

### 4. Jira Integration: CLI vs REST API (jira.js)

**Decision**: `jira.js` (Jira REST API client library for Node.js)

**Rationale**: Same reasoning as GitHub — structured responses, proper
error handling, built-in pagination. `jira.js` supports both Cloud
and Server/Data Center Jira with the same API.

**Alternatives considered**:
- **Atlassian CLI**: Not a standard Atlassian product. Various
  third-party CLIs exist but add dependency risk.
- **Direct REST calls via `fetch`**: Works but `jira.js` handles
  authentication, pagination, and type safety.

### 5. GCP Monitoring: Client Libraries vs REST API

**Decision**: `@google-cloud/monitoring` and related client libraries

**Rationale**: Official GCP client libraries use Application Default
Credentials (ADC) automatically on Cloud Run — zero credential
configuration needed. They handle authentication, retries, and
pagination out of the box.

**Libraries selected**:
- `@google-cloud/monitoring` — Cloud Monitoring API
- `@google-cloud/logging` — Cloud Logging API
- `@google-cloud/run` — Cloud Run Admin API (for revision/instance data)
- `@google-cloud/secret-manager` — Secret Manager API

### 6. Database: Dedicated vs Shared Cloud SQL

**Decision**: Dedicated Cloud SQL instance (`delivery-db`)

**Rationale**: The worker writes aggregated data every 5-15 minutes
across multiple tables. Sharing `chat-db-dev` risks write contention
with the chat backend's real-time queries. A dedicated instance
provides isolation and independent scaling.

**Cost consideration**: A `db-f1-micro` instance is sufficient for
the delivery workbench's workload (small team, periodic writes,
lightweight reads). Monthly cost is minimal.

### 7. Worker Scheduling: Cloud Scheduler + Cloud Run Jobs

**Decision**: Cloud Scheduler triggers a Cloud Run Job at 1-minute
intervals. The worker internally decides which jobs are due based
on configured intervals and last-run timestamps in the DB.

**Rationale**: This gives configurable per-job intervals without
requiring Cloud Scheduler reconfiguration. The Cloud Scheduler is
a simple "heartbeat" — the intelligence is in the worker code.

**Alternatives considered**:
- **Separate Cloud Scheduler triggers per job**: More granular but
  requires infra changes to modify intervals. Conflicts with the
  "configurable via UI" requirement.
- **Cloud Tasks**: Designed for one-off async tasks, not periodic
  polling. Not a good fit.

### 8. Flags Endpoint Security: OIDC Token Validation

**Decision**: Validate OIDC token signature against Google's public
keys, require `aud` claim matching `https://api.delivery.mentalhelp.chat`,
return HTTP 401 for missing/invalid tokens.

**Rationale**: Consumer apps (chat-frontend, workbench-frontend) run
on Cloud Run and can request OIDC tokens with the correct audience
via the metadata server. This is service-to-service auth without
shared secrets.

**Implementation**: Use `google-auth-library` to verify tokens.
The library handles key rotation and caching automatically.

### 9. Frontend State Management: Zustand

**Decision**: Zustand (consistent with existing frontends)

**Rationale**: The project already uses Zustand in `chat-frontend`
and `workbench-frontend`. One store per domain (features, tasks,
repos, tests, config, monitoring) keeps state isolated and
predictable. Zustand is lightweight with no boilerplate.

### 10. Env Var Editability: Allowlist Approach

**Decision**: Backend maintains an explicit allowlist of editable
variable names per repo. All other variables are read-only.

**Rationale**: Prevents accidental modification of sensitive values
that happen to be stored as env vars rather than secrets. The
allowlist is maintained in the delivery workbench app config,
editable via the config panel itself.

**Initial allowlist** (to be refined during implementation):
- `FEATURE_FLAGS_*` — feature flag overrides
- `LOG_LEVEL` — logging verbosity
- `CORS_ORIGIN` — CORS allowed origins
- Non-secret URLs and hostnames

# Quickstart: Non-Therapy Technical Backlog (030)

**Branch**: `030-non-therapy-backlog`
**Last updated**: 2026-03-15

---

## Overview

This guide covers local development setup for the 7 engineering domains in this backlog. The implementation spans `chat-backend`, `workbench-frontend`, `chat-types`, `chat-infra`, and `chat-ui`.

---

## Prerequisites

- Node.js 20+ (check with `node -v`)
- PostgreSQL 15 (local or Cloud SQL via proxy)
- Redis (local or existing dev instance)
- `gcloud` CLI authenticated to `mental-help-global-25`
- Access to the `030-non-therapy-backlog` branch in all affected repos

---

## Step 1: Branch Setup (all affected repos)

```bash
# In each affected repo, create the feature branch from develop
git checkout develop && git pull origin develop
git checkout -b 030-non-therapy-backlog
```

Repos requiring the branch: `chat-backend`, `chat-types`, `workbench-frontend`, `chat-infra`, `chat-ui`

---

## Step 2: Infrastructure Provisioning (chat-infra)

Run these scripts before any backend migration. They are idempotent.

```bash
cd chat-infra

# 1. Create separate Cloud SQL instance for identity map
./scripts/030-create-identity-map-instance.sh --env dev

# 2. Set up IAM bindings (auth-identity-map-sa + deny policy for all others)
./scripts/030-iam-identity-map-bindings.sh --env dev

# 3. Create Cloud Tasks queue for assessment scheduler
./scripts/030-cloud-tasks-assessment-queue.sh --env dev

# 4. Set audit log retention to 3 years
./scripts/030-audit-log-retention.sh --env dev
```

Verify:
```bash
gcloud sql instances describe chat-identity-map-dev --project=mental-help-global-25
gcloud tasks queues describe assessment-scheduler --location=europe-central2 --project=mental-help-global-25
```

---

## Step 3: chat-types — New Type Definitions

```bash
cd chat-types
npm install
# Add new type files (see plan.md Project Structure for file list)
# Run type check:
npm run type-check
# Publish new version to GitHub Packages before backend/frontend work begins
npm version patch && git push && git push --tags
```

---

## Step 4: Backend Migrations (chat-backend)

Update `chat-types` dependency first, then run migrations in order:

```bash
cd chat-backend
npm install @mentalhelpglobal/chat-types@latest

# Run migrations in sequence (order is critical — see data-model.md)
npx knex migrate:up 030-001-pseudonymous-users
npx knex migrate:up 030-002-consent-records
npx knex migrate:up 030-003-cohorts
npx knex migrate:up 030-004-assessment-schema
npx knex migrate:up 030-005-score-trajectories
npx knex migrate:up 030-006-assessment-schedule
npx knex migrate:up 030-007-risk-thresholds
npx knex migrate:up 030-008-supervisor-cohorts
npx knex migrate:up 030-009-annotations
```

> ⚠️ Migration 030-001 is a BREAKING CHANGE to the `users` table. Run the data migration script to assign `pseudonymous_user_id` to existing users BEFORE running the schema migration:
> ```bash
> npx ts-node migrations/data/030-001-assign-pseudonymous-ids.ts
> ```

Verify schema:
```bash
npx knex migrate:status
# Confirm all 9 migrations show as completed
```

---

## Step 5: Backend Environment Variables

Add to `.env.local` (dev only — see Constitution Principle VIII for non-sensitive config):

```bash
# Identity map Cloud SQL instance (separate from main)
IDENTITY_MAP_DB_HOST=127.0.0.1
IDENTITY_MAP_DB_PORT=5433   # Different port from main DB proxy
IDENTITY_MAP_DB_NAME=identity_map_db

# Cloud Tasks
CLOUD_TASKS_PROJECT=mental-help-global-25
CLOUD_TASKS_LOCATION=europe-central2
ASSESSMENT_SCHEDULER_QUEUE=assessment-scheduler
INTERNAL_API_URL=https://api.dev.mentalhelp.chat

# AI filter configuration
AI_FILTER_FALLBACK_MESSAGE_KEY=ai_filter_fallback  # Key in config table — value is therapy-gated
SCORE_CONTEXT_CACHE_TTL_SECONDS=3600

# k-anonymity threshold
K_ANONYMITY_MIN_COHORT_SIZE=10
COHORT_ANALYTICS_MIN_USERS=25
```

Credentials and connection strings go to Secret Manager (never `.env`):
```bash
gcloud secrets versions access latest --secret=IDENTITY_MAP_DB_PASS --project=mental-help-global-25
```

---

## Step 6: Run Backend Tests

```bash
cd chat-backend
npm test                          # All Vitest unit + integration tests
npm run test:integration          # Integration tests only (requires live DB)
```

Key test files for this feature:
```
tests/integration/erasure-cascade.test.ts
tests/integration/pii-rejection.test.ts
tests/integration/consent-enforcement.test.ts
tests/integration/cohort-guard.test.ts
tests/integration/assessment-append-only.test.ts
tests/unit/kappa.test.ts
tests/unit/model-metrics.test.ts
tests/unit/ai-filter.test.ts
tests/unit/score-trajectories.test.ts
```

---

## Step 7: Workbench Frontend

```bash
cd workbench-frontend
npm install @mentalhelpglobal/chat-types@latest
npm run dev
```

New feature components (see plan.md Project Structure):
- `src/features/cohort-management/`
- `src/features/assessment-trajectories/`
- `src/features/gdpr-audit/`
- `src/features/annotation/`

i18n: Add translation keys to `uk`, `en`, `ru` locale files for all new UI text.

---

## Step 8: Load Tests (chat-ui)

> ⚠️ Run against staging (dev.mentalhelp.chat), not production.

```bash
cd chat-ui
npx playwright test tests/load/chat-load-1000.spec.ts
npx playwright test tests/load/workbench-load-1000.spec.ts
```

Pass targets (see FR-035):
- p95 chat: < 500ms
- p95 workbench: < 1,000ms
- Error rate: < 0.1%
- Autoscale: capacity available within 30s of threshold crossing

---

## Verification Checklist

Before opening any PR for this feature:

- [ ] All 9 migrations run successfully on a clean schema
- [ ] `users` table has no PII columns (confirmed by `\d users` in psql)
- [ ] Cross-service identity map access denied (run `pii-rejection.test.ts`)
- [ ] Erasure cascade completes and nullifies all FKs (run `erasure-cascade.test.ts`)
- [ ] Consent enforcement returns 403 without valid consent (run `consent-enforcement.test.ts`)
- [ ] Append-only trigger blocks UPDATE on `assessment_scores` (run `assessment-append-only.test.ts`)
- [ ] k=10 suppression fires on cohort with 9 members (run cohort unit tests)
- [ ] AI filter blocks test cases with known prohibited patterns (run `ai-filter.test.ts`)
- [ ] Kappa computation matches reference value within ±0.001 (run `kappa.test.ts`)
- [ ] Load test passes all latency and autoscale targets

---

## API Contracts

OpenAPI contracts for all new endpoints:

- [`contracts/identity-api.yaml`](./contracts/identity-api.yaml) — Identity, consent, cohort, GDPR erasure
- [`contracts/assessment-api.yaml`](./contracts/assessment-api.yaml) — Assessment schema, trajectories, scheduling, thresholds
- [`contracts/analytics-api.yaml`](./contracts/analytics-api.yaml) — Analytics events, RBAC, audit log, CSV export
- [`contracts/annotation-api.yaml`](./contracts/annotation-api.yaml) — Annotation blinding, sampling, kappa, model metrics

---

## Environments

| Environment | URL |
|-------------|-----|
| Dev API | https://api.dev.mentalhelp.chat |
| Dev Workbench | https://workbench.dev.mentalhelp.chat |
| Prod API | https://api.mentalhelp.chat |
| Prod Workbench | https://workbench.mentalhelp.chat |

Do NOT use Cloud Run `*.run.app` URLs or GCS bucket URLs for testing.

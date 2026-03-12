# Audit Scope

## Dev API Base URL

```
https://api.dev.mentalhelp.chat
```

Use this for all Phase 4 live endpoint checks. Do NOT use `*.run.app` or GCS bucket URLs.

## Repositories

| Repo | Local Path | Primary Audit Areas |
|------|-----------|---------------------|
| chat-backend | `D:\src\MHG\chat-backend` | API routes, auth middleware, DB queries, secrets |
| chat-frontend | `D:\src\MHG\chat-frontend` | CSP headers, localStorage usage, npm deps |
| workbench-frontend | `D:\src\MHG\workbench-frontend` | Admin access controls, npm deps |
| chat-types | `D:\src\MHG\chat-types` | Type safety, no secrets expected |
| chat-infra | `D:\src\MHG\chat-infra` | IAM config, GCP scripts, Terraform |

## GitHub Repositories (for CI/CD checks)

| Repo slug | Branch |
|-----------|--------|
| `MentalHelpGlobal/chat-backend` | `develop` |
| `MentalHelpGlobal/chat-frontend` | `develop` |
| `MentalHelpGlobal/workbench-frontend` | `develop` |
| `MentalHelpGlobal/chat-types` | `develop` |

## GCP Project

```
mental-help-global-25
```

Region: `us-central1`

Cloud Run services: `chat-backend-dev`, `chat-backend-prod` (if exists)
Cloud SQL instance: `chat-db-dev`

## Critical Files to Read

### Auth & Middleware
- `chat-backend/src/middleware/` — auth guards (`isAdmin`, `isReviewer`, bearer token validation)
- `chat-backend/src/middleware/auth.ts` — token parsing and verification

### Routes
- `chat-backend/src/routes/` — all route handlers (especially those with `:id` params)
- `chat-backend/src/app.ts` — middleware registration order, CORS config, error handler

### Environment & Secrets
- `chat-backend/.env.example` — secret key names only (never read actual `.env` values)
- `chat-frontend/.env.example` — frontend env vars (check for secrets that should not be here)

### CI/CD
- `.github/workflows/*.yml` in all repos — check permissions, action pins, secret usage

### Infrastructure
- `chat-infra/terraform/` or GCP scripts — IAM policies, service account bindings

## Protected Endpoints to Test (Phase 4)

| Method | Endpoint | Expected (unauthenticated) |
|--------|----------|---------------------------|
| GET | `/api/chat/sessions` | 401 |
| POST | `/api/chat/sessions` | 401 |
| GET | `/api/chat/sessions/:id` | 401 |
| GET | `/api/review/sessions` | 401 |
| POST | `/api/admin/users` | 401 |
| GET | `/api/settings` | 200 (public) |
| GET | `/health` | 200 (public) |

## Public Endpoints (No Auth Required)

- `GET /health` — health check
- `GET /api/settings` — frontend config (must not include secrets)
- `POST /api/auth/login` — OTP request (rate-limited)
- `POST /api/auth/verify` — OTP verification (rate-limited)

## Out of Scope

- Penetration testing / active exploitation
- Social engineering or phishing testing
- Third-party SaaS security (Dialogflow, Atlassian Confluence, Jira)
- Application business logic correctness (separate QA concern)
- Performance/load testing
- Workbench frontend deep code review (dependency scan + header check only)

## Credential Handling Notes

- Never read or log actual `.env` file values
- Never include Bearer tokens, OTPs, or passwords in report
- Truncate curl command outputs if they contain `Authorization` headers
- For GCP commands, authenticate using ADC (Application Default Credentials) — do not embed service account keys

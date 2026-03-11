# MHG Repo Reference

## Repository Inventory

| Repo | Local Path | Remote | Base Branch | PR Target | Phase 1 Action |
|---|---|---|---|---|---|
| `chat-types` | `D:\src\MHG\chat-types` | `MentalHelpGlobal/chat-types` | `main` | `main` | Push direct (no develop) |
| `chat-backend` | `D:\src\MHG\chat-backend` | `MentalHelpGlobal/chat-backend` | `develop` | `develop` | Feature branch → PR |
| `chat-frontend` | `D:\src\MHG\chat-frontend` | `MentalHelpGlobal/chat-frontend` | `develop` | `develop` | Feature branch → PR |
| `workbench-frontend` | `D:\src\MHG\workbench-frontend` | `MentalHelpGlobal/workbench-frontend` | `develop` | `develop` | Feature branch → PR |
| `chat-infra` | `D:\src\MHG\chat-infra` | `MentalHelpGlobal/chat-infra` | `develop` | `develop` | Push direct |
| `cx-agent-definition` | `D:\src\MHG\cx-agent-definition` | `MentalHelpGlobal/cx-agent-definition` | `main` | `main` | Push direct |
| `client-spec` | `D:\src\MHG\client-spec` | `MentalHelpGlobal/client-spec` | `main` | `main` | Push direct (docs only) |

## Branch Policy (per CLAUDE.md)

- **App repos** (`chat-backend`, `chat-frontend`, `workbench-frontend`): Changes MUST reach `develop` via PR from a feature/bugfix branch. Direct commits to `develop` are not allowed.
- **Type/infra repos** (`chat-types`, `chat-infra`, `cx-agent-definition`): Direct push to base branch is acceptable.
- **Feature branch naming**: `feature/<NNN-short-name>` or `bugfix/<short-name>`
- **Post-merge**: Delete remote branch, delete local branch, hard-sync local `develop` to `origin/develop`

## CI/CD Workflow Files

| Repo | Deploy Workflow | Trigger |
|---|---|---|
| `chat-backend` | `deploy.yml` (or check `.github/workflows/`) | Push to `develop` |
| `chat-frontend` | `deploy.yml` | Push to `develop` |
| `workbench-frontend` | `deploy.yml` | Push to `develop` |
| `chat-types` | `publish.yml` | Push to `main` (npm package publish) |

To list workflow files:
```bash
ls D:\src\MHG\<repo>\.github\workflows\
```

To poll deploy status:
```bash
gh -R MentalHelpGlobal/<repo> run list --branch=develop --limit=5
gh -R MentalHelpGlobal/<repo> run watch <run-id>
```

## Deployed Environments

| Service | Dev URL | Health Check |
|---|---|---|
| Backend API | `https://api.dev.mentalhelp.chat` | `GET /health` → 200 |
| Chat Frontend | `https://dev.mentalhelp.chat` | HTTP 200 |
| Workbench Frontend | `https://workbench.dev.mentalhelp.chat` | HTTP 200 |
| Prod Backend | `https://api.mentalhelp.chat` | (do not touch) |
| Prod Chat | `https://mentalhelp.chat` | (do not touch) |
| Prod Workbench | `https://workbench.mentalhelp.chat` | (do not touch) |

**Never use `*.run.app` or GCS bucket URLs — always use the canonical domains above.**

## GCP Project

- **Project**: `mental-help-global-25`
- **Cloud Run services**: `chat-backend-dev` (backend), `chat-frontend-dev`, `workbench-frontend-dev`
- **Cloud SQL**: `chat-db-dev`

### Cloud Run log query
```bash
gcloud logging read \
  'resource.type="cloud_run_revision" AND severity>=ERROR' \
  --project=mental-help-global-25 \
  --limit=50 \
  --format="table(timestamp,severity,textPayload,jsonPayload)"
```

### Check which revision is serving
```bash
gcloud run revisions list \
  --service=chat-backend-dev \
  --region=us-central1 \
  --project=mental-help-global-25 \
  --format="table(name,status.conditions[0].lastTransitionTime,status.observedGeneration)"
```

## Dependency Order for Merges and Reviews

Always process in this order:
1. `chat-types` — shared type definitions; must land first
2. `chat-backend` — consumes chat-types; backend contracts
3. `workbench-frontend` — consumes chat-types; workbench UI
4. `chat-frontend` — consumes chat-types; end-user UI
5. `chat-infra`, `cx-agent-definition` — independent, can go any time

## OTP Login (Dev)

OTP codes for dev login are visible in the **browser console** (not email). Open DevTools before submitting the login form; the OTP will be logged there.

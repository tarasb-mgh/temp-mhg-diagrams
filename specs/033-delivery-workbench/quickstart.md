# Quickstart: Delivery Workbench

**Feature Branch**: `033-delivery-workbench`

## Prerequisites

- Node.js 20 LTS
- npm 10+
- Access to GCP project `mental-help-global-25`
- `gcloud` CLI authenticated with appropriate IAM roles
- GitHub PAT with `repo`, `read:org`, `admin:repo_hook` scopes
- Atlassian API token for Jira Cloud

## Repository Setup

### 1. Clone repositories

```bash
cd D:\src\MHG
git clone git@github.com:MentalHelpGlobal/delivery-workbench-frontend.git
git clone git@github.com:MentalHelpGlobal/delivery-workbench-backend.git
```

### 2. Install dependencies

```bash
cd delivery-workbench-frontend && npm install
cd ../delivery-workbench-backend && npm install
```

### 3. Environment variables

**Backend** (`delivery-workbench-backend/.env`):

```env
DATABASE_URL=postgresql://user:pass@localhost:5432/delivery_db
GITHUB_PAT=ghp_xxx
ATLASSIAN_EMAIL=user@mentalhelpglobal.com
ATLASSIAN_API_TOKEN=xxx
ATLASSIAN_DOMAIN=mentalhelpglobal.atlassian.net
GCP_PROJECT_ID=mental-help-global-25
PORT=3001
```

**Frontend** (`delivery-workbench-frontend/.env`):

```env
VITE_API_URL=http://localhost:3001
```

### 4. Database setup

```bash
# Start local PostgreSQL (or use Cloud SQL proxy)
cd delivery-workbench-backend
npm run db:migrate
```

### 5. Start development servers

```bash
# Terminal 1: Backend API
cd delivery-workbench-backend
npm run dev:server

# Terminal 2: Backend Worker
cd delivery-workbench-backend
npm run dev:worker

# Terminal 3: Frontend
cd delivery-workbench-frontend
npm run dev
```

Frontend: http://localhost:5173
Backend API: http://localhost:3001
Health check: http://localhost:3001/api/health

## Production Deployment

Production is a single environment at:
- Frontend: https://delivery.mentalhelp.chat
- Backend API: https://api.delivery.mentalhelp.chat

Deployment is triggered automatically when code is pushed to the
`develop` branch in either repository. The `main` branch is used
for version tagging only.

### GCP Resources

| Resource | Name | Notes |
|----------|------|-------|
| Cloud SQL | `delivery-db` | PostgreSQL instance |
| Cloud Run Service | `delivery-workbench-api` | API server |
| Cloud Run Job | `delivery-workbench-worker` | Polling worker |
| Cloud Scheduler | `delivery-worker-trigger` | 1-min trigger |
| GCS Bucket | `mental-help-global-25-delivery-frontend` | SPA files |
| IAP | On GCLB | Google Workspace auth |

### Access Control

Access to the delivery workbench is controlled via GCP IAM:

```bash
gcloud projects add-iam-policy-binding mental-help-global-25 \
  --member="user:name@mentalhelpglobal.com" \
  --role="roles/iap.httpsResourceAccessUser"
```

## Key Commands

```bash
# Backend
npm run dev:server       # Start API server in dev mode
npm run dev:worker       # Start worker in dev mode
npm run build            # Build for production
npm run test             # Run unit tests
npm run db:migrate       # Run database migrations
npm run lint             # Run ESLint

# Frontend
npm run dev              # Start Vite dev server
npm run build            # Build for production
npm run test             # Run unit tests
npm run lint             # Run ESLint
```

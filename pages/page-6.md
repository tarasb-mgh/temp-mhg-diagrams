# 6. Component Functional Descriptions

**What this is:** An explanation of each element in the architecture — what it is, what it does, what depends on it, and what it depends on.

---

## Repositories

### chat-backend
**What it is:** Express.js API server.
**What it does:** Handles all business logic for the chat platform and workbench. Integrates with Dialogflow CX for conversational AI, manages authentication (OTP/JWT), serves survey APIs, and persists data to Cloud SQL.
**What depends on it:** chat-frontend, workbench-frontend, Dialogflow CX (webhook), review queue, analytics.
**What it depends on:** Cloud SQL, Secret Manager, Dialogflow CX API, Cloud Storage (for state timeline).
**Key configuration:** `EMAIL_PROVIDER` (must NOT be `console` in prod), `DIALOGFLOW_AGENT_ID`.
**Where to find more:** specs/052-cx-clinical-playbooks, chat-backend repo README.

### chat-frontend
**What it is:** React SPA built with Vite.
**What it does:** User-facing chat interface. Loads from GCS, authenticates via HTTP-only cookies on `.mentalhelp.chat`, renders chat messages, handles survey interactions.
**What depends on it:** End users.
**What it depends on:** chat-backend (API), GCS (hosting), Cloud DNS (resolution).
**Key configuration:** API base URL (`https://api.mentalhelp.chat`), CSP headers.
**Where to find more:** specs/001-split-workbench-app, chat-frontend repo README.

### workbench-frontend
**What it is:** React SPA built with Vite.
**What it does:** Admin and reviewer interface. Review queue, user management, survey schema editor, safety flag review, analytics dashboards.
**What depends on it:** Admins, reviewers, testers.
**What it depends on:** chat-backend (API), GCS (hosting).
**Key configuration:** Same auth domain as chat-frontend (`.mentalhelp.chat`), RBAC permissions.
**Where to find more:** specs/001-split-workbench-app, workbench-frontend repo README.

### chat-types
**What it is:** Shared TypeScript types package (`@mentalhelpglobal/chat-types`).
**What it does:** Defines contracts between chat-backend, chat-frontend, and workbench-frontend. Prevents API contract drift.
**What depends on it:** chat-backend, chat-frontend, workbench-frontend, chat-frontend-common.
**What it depends on:** npm registry (GitHub Packages).
**Key configuration:** Semantic versioning, `package.json` exports.
**Where to find more:** specs/001-monorepo-split.

### chat-frontend-common
**What it is:** Shared UI library and auth logic.
**What it does:** Common React components (buttons, forms, modals), API client, authentication hooks, i18n utilities.
**What depends on it:** chat-frontend, workbench-frontend.
**What it depends on:** chat-types, npm registry.
**Where to find more:** specs/001-monorepo-split.

### chat-ui
**What it is:** Playwright E2E test suite.
**What it does:** Automated end-to-end testing of chat and workbench flows. Runs against dev and prod environments.
**What depends on it:** CI/CD quality gates.
**What it depends on:** Playwright, dev/prod environment URLs.
**Where to find more:** regression-suite/ directory in client-spec repo.

### cx-agent-definition
**What it is:** Dialogflow CX agent configuration as code.
**What it does:** Stores playbooks, intents, flows, tools, and generative settings as JSON files. Deployed manually via Dialogflow CX REST API.
**What depends on it:** Dialogflow CX agent in production.
**What it depends on:** Dialogflow CX API, Vertex AI Search data stores.
**Key configuration:** `BLOCK_NONE` RAI settings, training phrases in uk/ru/en.
**Where to find more:** specs/052-cx-clinical-playbooks, CLAUDE.md §CX Agent Deployment.

### chat-infra
**What it is:** Infrastructure scripts and Terraform scaffolding.
**What it does:** GCP resource provisioning scripts, Terraform modules, environment setup automation.
**What depends on it:** New environment provisioning.
**What it depends on:** GCP APIs, Terraform Cloud / local state.
**Where to find more:** chat-infra repo README.

### chat-ci
**What it is:** Reusable GitHub Actions workflows.
**What it does:** Standardized CI/CD steps (lint, test, build, deploy) called by other repos.
**What depends on it:** chat-backend, chat-frontend, workbench-frontend, chat-types, chat-frontend-common.
**What it depends on:** GitHub Actions runner infrastructure.
**Where to find more:** specs/001-monorepo-split, chat-ci repo.

### mcp-server
**What it is:** MCP SSE server exposing MHG Workbench tools.
**What it does:** Provides Model Context Protocol (MCP) endpoints for AI agents to interact with workbench functionality.
**What depends on it:** AI coding agents, workbench automation.
**What it depends on:** chat-backend API, Cloud Run.
**Where to find more:** mcp-server repo README.

---

## GCP Resources

### Cloud Run (chat-backend-prod)
**What it is:** Managed container runtime.
**What it does:** Runs the chat-backend Express.js application. Scales to zero (min instances configurable). Receives HTTPS requests from GCLB.
**What depends on it:** GCLB, end users, Dialogflow CX (webhook).
**What it depends on:** Artifact Registry (image), Cloud SQL, Secret Manager, Service account.
**Key configuration:** Ingress: `all` or `internal`, min/max instances, CPU/memory limits, runtime SA.

### Cloud Storage (Frontend Buckets)
**What it is:** Object storage for static assets.
**What it does:** Hosts built React SPAs (chat-frontend, workbench-frontend, delivery-workbench-frontend). Served via GCLB backend buckets.
**What depends on it:** GCLB, end users.
**What it depends on:** CI/CD pipeline (upload on deploy).
**Key configuration:** Uniform bucket-level access, lifecycle rules, CORS headers.

### Cloud SQL
**What it is:** Managed PostgreSQL database.
**What it does:** Persists all application data: users, sessions, messages, assessments, surveys, review queue, audit logs.
**What depends on it:** chat-backend, review queue, analytics.
**What it depends on:** GCP networking, backup configuration, IAM database auth.
**Key configuration:** HA mode, backup retention, maintenance window, connection name.

### Secret Manager
**What it is:** Managed secret storage.
**What it does:** Stores sensitive values (DB passwords, JWT secrets, API keys, tokens) outside of code and container images.
**What depends on it:** chat-backend (runtime secret retrieval), GitHub Actions (deploy secrets).
**What it depends on:** IAM permissions on the consuming service account.
**Key configuration:** Replication policy, rotation schedule, version management.

### Artifact Registry
**What it is:** Private Docker image registry.
**What it does:** Stores built container images for Cloud Run deployment.
**What depends on it:** Cloud Run (image pull), CI/CD (image push).
**What it depends on:** IAM permissions on the deployer service account.

### Global HTTPS Load Balancer
**What it is:** Layer 7 load balancer with SSL termination.
**What it does:** Routes HTTPS requests from custom domains (`mentalhelp.chat`, `workbench.mentalhelp.chat`, `api.mentalhelp.chat`) to the appropriate backend (Cloud Run or GCS).
**What depends on it:** Cloud DNS, SSL certificates, backend services.
**What it depends on:** Cloud DNS (for domain resolution), managed SSL certificates.

### Cloud DNS
**What it is:** Managed DNS service.
**What it does:** Resolves `mentalhelp.chat` and subdomains to the GCLB frontend IP.
**What depends on it:** End users, external services.
**What it depends on:** Domain registrar (Google Domains or third-party).

---

## AI / ML Resources

### Dialogflow CX Agent
**What it is:** Conversational AI platform.
**What it does:** Handles natural language understanding, intent matching, playbook execution, and generative response generation for the MentalHelpGlobal chat platform.
**What depends on it:** chat-backend (API calls), end users (chat messages).
**What it depends on:** Vertex AI (LLM), Data Store (knowledge), GCS (state timeline), chat-backend (webhook).
**Key configuration:** Agent ID, default language (uk), generative settings, safety settings (`BLOCK_NONE`), playbook hierarchy.

### Vertex AI (gemini-2.5-flash)
**What it is:** Generative AI model backend.
**What it does:** Powers the Dialogflow CX agent's generative responses. Provides clinical-quality conversation capabilities.
**What depends on it:** Dialogflow CX agent.
**What it depends on:** GCP project quota, RAI configuration.

### Data Store (Vertex AI Search)
**What it is:** Knowledge base for agent tools.
**What it does:** Provides retrieval-augmented generation (RAG) capabilities to the agent. Stores clinical protocols, FAQ, and reference material.
**What depends on it:** Dialogflow CX agent (data store tools).
**What it depends on:** Data ingestion pipeline (manual or automated).

---

**Last Verified:** 2026-05-08 by Taras Bobrovytskyi
**Regeneration:** Code inspection of all repos + GCP console review.

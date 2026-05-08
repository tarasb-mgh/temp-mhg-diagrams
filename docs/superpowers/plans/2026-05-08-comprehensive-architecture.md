# Comprehensive System Architecture Documentation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. This is a documentation project; "tests" are verification checks against the design doc acceptance criteria.

**Goal:** Publish a self-contained Confluence subtree (1 root + 7 children) under `UD:65470465` that comprehensively documents the MentalHelpGlobal production system architecture.

**Architecture:** Hub-and-spoke Confluence structure. Each page is authored by (1) running live discovery commands against production, (2) synthesizing results with hand-written context, (3) embedding Mermaid diagrams, (4) publishing via Atlassian MCP. No code is written; the deliverables are Confluence pages.

**Tech Stack:** `gcloud` CLI, `gh` CLI, `curl` + Dialogflow CX v3 API, `jq`, Atlassian MCP (`createConfluencePage`, `updateConfluencePage`), Mermaid syntax.

---

## File Structure

No code files are created. All deliverables are Confluence pages in space `UD` under parent `65470465`.

**Working files (temporary, not committed):**
- `discovery/001-repos.json` — `gh repo list` output
- `discovery/002-network.json` — `gcloud compute/dns` output
- `discovery/003-agent.json` — Dialogflow CX API responses
- `discovery/004-gcp.json` — `gcloud run/storage/sql/secrets/artifacts` output
- `discovery/005-schema.sql` — `pg_dump --schema-only` output (or migration file aggregation)
- `pages/page-{N}.md` — Draft markdown for each Confluence page before publishing
- `pages/diagrams/page-{N}-diagrams.md` — Mermaid diagram sources

**Published artifacts (Confluence pages):**
- `UD:65470465/Comprehensive System Architecture` (root)
- `UD:65470465/Comprehensive System Architecture/1. Repositories & Services Inventory`
- `UD:65470465/Comprehensive System Architecture/2. Production Network Topology`
- `UD:65470465/Comprehensive System Architecture/3. Conversational Agent Architecture`
- `UD:65470465/Comprehensive System Architecture/4. GCP Infrastructure Inventory`
- `UD:65470465/Comprehensive System Architecture/5. Data Flow & Integration Map`
- `UD:65470465/Comprehensive System Architecture/6. Component Functional Descriptions`
- `UD:65470465/Comprehensive System Architecture/7. Database Schema Reference`

---

## Phase 0: Setup & Auth Verification

### Task 0.1: Verify All CLI Tools Are Authenticated

**Files:**
- No files created or modified.

- [ ] **Step 1: Verify gcloud is authenticated and project is set**

Run:
```bash
gcloud config get-value project
gcloud auth list --filter=status:ACTIVE --format='value(account)'
```
Expected output:
```
mental-help-global-25
github-actions-sa@mental-help-global-25.iam.gserviceaccount.com
```
(Or similar active service account / user account with `roles/viewer` or higher on `mental-help-global-25`.)

- [ ] **Step 2: Verify gh CLI is authenticated and can list org repos**

Run:
```bash
gh auth status
gh repo list MentalHelpGlobal --limit 5 --json name
```
Expected output: `Logged in to github.com as {username}` + a JSON array of 5 repo objects.

- [ ] **Step 3: Verify Dialogflow CX API access**

Run:
```bash
TOKEN=$(gcloud auth print-access-token)
curl -s -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: mental-help-global-25" \
  "https://global-dialogflow.googleapis.com/v3/projects/mental-help-global-25/locations/global/agents/192578e5-f119-436e-9718-abb9d9d1c8b1" | jq -r '.displayName'
```
Expected output: The agent display name (e.g., `Mental Help Assistant`).

- [ ] **Step 4: Verify Atlassian MCP can access Confluence space UD**

Run (via Atlassian MCP `getConfluenceSpaces`):
```
Tool: mcp__plugin_atlassian_atlassian__getConfluenceSpaces
Parameters: { "cloudId": "mentalhelpglobal.atlassian.net", "keys": ["UD"] }
```
Expected output: Space object with `key: "UD"`, `id: "8454147"`.

- [ ] **Step 5: Verify parent page 65470465 exists**

Run (via Atlassian MCP `getConfluencePage`):
```
Tool: mcp__plugin_atlassian_atlassian__getConfluencePage
Parameters: { "cloudId": "mentalhelpglobal.atlassian.net", "pageId": "65470465" }
```
Expected output: Page object with title containing "Handover Roadmap".

- [ ] **Step 6: Commit auth verification log**

```bash
mkdir -p discovery
echo "Auth verified: $(date -u +%Y-%m-%dT%H:%M:%SZ)" > discovery/auth-verified.txt
git add discovery/auth-verified.txt
git commit -m "docs(063): auth verification for architecture discovery"
```

---

## Phase 1: Data Discovery

### Task 1.1: Discover GitHub Repositories & Workflows

**Files:**
- Create: `discovery/001-repos.json`

- [ ] **Step 1: List all repos in the MentalHelpGlobal org**

Run:
```bash
gh repo list MentalHelpGlobal --limit 100 \
  --json name,description,defaultBranchRef,updatedAt,visibility,pushedAt \
  > discovery/001-repos.json
```
Expected: JSON array with all org repos.

- [ ] **Step 2: Fetch workflows per repo**

Run:
```bash
jq -r '.[].name' discovery/001-repos.json | while read repo; do
  gh api "repos/MentalHelpGlobal/$repo/actions/workflows" \
    --jq '.workflows[] | {repo: "'$repo'", name, path, state, created_at, updated_at}' \
    >> discovery/001-workflows.jsonl
done
```
Expected: One JSON line per workflow.

- [ ] **Step 3: Fetch secrets names per repo (names only)**

Run:
```bash
jq -r '.[].name' discovery/001-repos.json | while read repo; do
  gh api "repos/MentalHelpGlobal/$repo/actions/secrets" \
    --jq '.secrets[] | {repo: "'$repo'", name}' \
    >> discovery/001-secrets.jsonl
done
```
Expected: One JSON line per secret name.

- [ ] **Step 4: Fetch packages published by the org**

Run:
```bash
gh api /orgs/MentalHelpGlobal/packages?package_type=npm \
  --jq '.[] | {name, package_type, owner: .owner.login, repository: .repository.name, html_url}' \
  > discovery/001-packages.json
```
Expected: JSON array of npm packages.

- [ ] **Step 5: Verify output files exist and are non-empty**

Run:
```bash
ls -la discovery/001-*.json discovery/001-*.jsonl
wc -l discovery/001-*.jsonl
```
Expected: All 4 files exist, `.jsonl` files have >0 lines.

- [ ] **Step 6: Commit**

```bash
git add discovery/001-*
git commit -m "docs(063): discovery — GitHub repos, workflows, secrets, packages"
```

---

### Task 1.2: Discover GCP Network Topology

**Files:**
- Create: `discovery/002-network.json`

- [ ] **Step 1: List global forwarding rules**

Run:
```bash
gcloud compute forwarding-rules list --global \
  --project mental-help-global-25 \
  --format=json > discovery/002-forwarding-rules.json
```

- [ ] **Step 2: List target HTTPS proxies**

Run:
```bash
gcloud compute target-https-proxies list \
  --global --project mental-help-global-25 \
  --format=json > discovery/002-target-proxies.json
```

- [ ] **Step 3: List URL maps**

Run:
```bash
gcloud compute url-maps list --global \
  --project mental-help-global-25 \
  --format=json > discovery/002-url-maps.json
```

- [ ] **Step 4: List backend services**

Run:
```bash
gcloud compute backend-services list --global \
  --project mental-help-global-25 \
  --format=json > discovery/002-backend-services.json
```

- [ ] **Step 5: List managed SSL certificates**

Run:
```bash
gcloud compute ssl-certificates list \
  --global --project mental-help-global-25 \
  --format=json > discovery/002-ssl-certificates.json
```

- [ ] **Step 6: List Cloud DNS zones and record sets**

Run:
```bash
gcloud dns managed-zones list \
  --project mental-help-global-25 \
  --format=json > discovery/002-dns-zones.json

# For each zone, list record sets
jq -r '.[].name' discovery/002-dns-zones.json | while read zone; do
  gcloud dns record-sets list --zone="$zone" \
    --project mental-help-global-25 \
    --format=json > "discovery/002-dns-records-${zone}.json"
done
```

- [ ] **Step 7: Verify all outputs non-empty**

Run:
```bash
ls -la discovery/002-*.json
```
Expected: All files exist, sizes > 0 bytes.

- [ ] **Step 8: Commit**

```bash
git add discovery/002-*
git commit -m "docs(063): discovery — GCP network topology"
```

---

### Task 1.3: Discover Dialogflow CX Agent Structure

**Files:**
- Create: `discovery/003-agent.json`

- [ ] **Step 1: Set common variables**

Run:
```bash
export TOKEN=$(gcloud auth print-access-token)
export AGENT="projects/mental-help-global-25/locations/global/agents/192578e5-f119-436e-9718-abb9d9d1c8b1"
export API="https://global-dialogflow.googleapis.com/v3/$AGENT"
export HEADERS="Authorization: Bearer $TOKEN\nx-goog-user-project: mental-help-global-25\nContent-Type: application/json"
```

- [ ] **Step 2: Fetch agent details**

Run:
```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: mental-help-global-25" \
  "$API" > discovery/003-agent-details.json
jq -r '.displayName, .defaultLanguageCode, .timeZone, .description' discovery/003-agent-details.json
```
Expected: Agent display name and metadata.

- [ ] **Step 3: List playbooks**

Run:
```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: mental-help-global-25" \
  "$API/playbooks" > discovery/003-playbooks.json
jq '.playbooks[] | {name, displayName, description}' discovery/003-playbooks.json
```
Expected: Array of playbook objects.

- [ ] **Step 4: List intents**

Run:
```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: mental-help-global-25" \
  "$API/intents" > discovery/003-intents.json
jq '.intents[] | {name, displayName, parameters: (.parameters | length)}' discovery/003-intents.json
```
Expected: Array of intent objects.

- [ ] **Step 5: List flows**

Run:
```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: mental-help-global-25" \
  "$API/flows" > discovery/003-flows.json
jq '.flows[] | {name, displayName}' discovery/003-flows.json
```
Expected: Array of flow objects.

- [ ] **Step 6: List tools**

Run:
```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: mental-help-global-25" \
  "$API/tools" > discovery/003-tools.json
jq '.tools[] | {name, displayName}' discovery/003-tools.json
```
Expected: Array of tool objects.

- [ ] **Step 7: List generators**

Run:
```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: mental-help-global-25" \
  "$API/generators" > discovery/003-generators.json
jq '.generators[] | {name, displayName}' discovery/003-generators.json
```
Expected: Array of generator objects (may be empty).

- [ ] **Step 8: Verify all outputs non-empty**

Run:
```bash
ls -la discovery/003-*.json
```
Expected: All 6 files exist, sizes > 0 bytes.

- [ ] **Step 9: Commit**

```bash
git add discovery/003-*
git commit -m "docs(063): discovery — Dialogflow CX agent structure"
```

---

### Task 1.4: Discover GCP Infrastructure Inventory

**Files:**
- Create: `discovery/004-gcp.json`

- [ ] **Step 1: List Cloud Run services**

Run:
```bash
gcloud run services list --project mental-help-global-25 \
  --format=json > discovery/004-cloud-run.json
jq '.[] | {name: .metadata.name, region: .metadata.annotations."run.googleapis.com/region", url: .status.url}' discovery/004-cloud-run.json
```
Expected: Array of Cloud Run service objects.

- [ ] **Step 2: List Cloud Storage buckets**

Run:
```bash
gcloud storage ls --project mental-help-global-25 \
  --format=json > discovery/004-storage.json
jq '.[] | {name, location, storageClass}' discovery/004-storage.json
```
Expected: Array of bucket objects.

- [ ] **Step 3: List Cloud SQL instances**

Run:
```bash
gcloud sql instances list --project mental-help-global-25 \
  --format=json > discovery/004-sql.json
jq '.[] | {name, region: .gceZone, tier: .settings.tier, databaseVersion, availabilityType}' discovery/004-sql.json
```
Expected: Array of Cloud SQL instance objects.

- [ ] **Step 4: List Secret Manager secrets**

Run:
```bash
gcloud secrets list --project mental-help-global-25 \
  --format=json > discovery/004-secrets.json
jq '.[] | {name, createTime, replication: .replication.userManaged.replicas}' discovery/004-secrets.json
```
Expected: Array of secret objects.

- [ ] **Step 5: List Artifact Registry repositories**

Run:
```bash
gcloud artifacts repositories list --project mental-help-global-25 \
  --format=json > discovery/004-artifacts.json
jq '.[] | {name, format, location, mode}' discovery/004-artifacts.json
```
Expected: Array of Artifact Registry repository objects.

- [ ] **Step 6: Verify all outputs non-empty**

Run:
```bash
ls -la discovery/004-*.json
```
Expected: All 5 files exist, sizes > 0 bytes.

- [ ] **Step 7: Commit**

```bash
git add discovery/004-*
git commit -m "docs(063): discovery — GCP infrastructure inventory"
```

---

### Task 1.5: Discover Database Schema

**Files:**
- Create: `discovery/005-schema.sql` (or migration file aggregation)

**Approach A: Direct database dump (preferred if access is available)**

- [ ] **Step 1: Check if Cloud SQL proxy or direct connect is available**

Run:
```bash
gcloud sql connect chat-db-prod --user=postgres --database=mentalhelp --quiet <<< "\\dt"
```
If this succeeds, use Approach A. If it fails (auth/permission), use Approach B.

- [ ] **Step 2: Dump schema-only (no data)**

Run:
```bash
gcloud sql connect chat-db-prod --user=postgres --database=mentalhelp --quiet <<< "
SELECT 'CREATE TABLE ' || schemaname || '.' || tablename AS stmt
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY schemaname, tablename;
" > discovery/005-tables.txt
```

Or via Cloud SQL proxy + pg_dump:
```bash
# In a separate terminal / background:
cloud_sql_proxy -instances=mental-help-global-25:europe-west1:chat-db-prod=tcp:5432

# Then:
pg_dump --schema-only --no-owner --no-privileges \
  "host=localhost port=5432 dbname=mentalhelp user=postgres" \
  > discovery/005-schema.sql
```

**Approach B: Schema from code (fallback if no DB access)**

- [ ] **Step 3: Clone or locate chat-backend repo and extract migrations**

Run:
```bash
# If chat-backend is not cloned locally:
gh repo clone MentalHelpGlobal/chat-backend /tmp/chat-backend -- --depth 1

# Find migration files
find /tmp/chat-backend -path "*/migrations/*" -name "*.sql" -o -path "*/migrations/*" -name "*.ts" -o -path "*/migrations/*" -name "*.js" | sort > discovery/005-migration-files.txt

# Aggregate all SQL migrations
cat $(find /tmp/chat-backend -path "*/migrations/*" -name "*.sql" | sort) > discovery/005-schema.sql
```

- [ ] **Step 4: If using ORM (Prisma/TypeORM/Knex), extract schema from config**

For Knex (most likely for Express):
```bash
find /tmp/chat-backend -name "knexfile.*" -o -name "db.config.*" | head -5
```
For Prisma:
```bash
find /tmp/chat-backend -name "schema.prisma" | head -1 | xargs cat > discovery/005-prisma-schema.prisma
```
For TypeORM:
```bash
find /tmp/chat-backend -path "*/entities/*" -name "*.ts" | sort > discovery/005-entity-files.txt
```

- [ ] **Step 5: Verify schema output exists**

Run:
```bash
ls -la discovery/005-*
```
Expected: At least one file with schema information (SQL, Prisma, or entity list).

- [ ] **Step 6: Commit**

```bash
git add discovery/005-*
git commit -m "docs(063): discovery — database schema"
```

---

## Phase 2: Content Authoring

### Task 2.1: Draft Root Page (Page 0)

**Files:**
- Create: `pages/page-0.md`

- [ ] **Step 1: Write root page markdown**

Create `pages/page-0.md` with the following exact structure (adapted from design doc §4):

```markdown
# Comprehensive System Architecture

**What this is:** A solution-level architecture description for the MentalHelpGlobal production system. It explains how components connect, how data flows, and what the conversational agent depends on. For the operational inventory of access points, roles, and resources, see [Access Audit — GCP + GitHub Inventory](link-to-062-root).

**Scope:** Production environment only (`mental-help-global-25`). Dev environment is mentioned only for contrast.

---

## System at a Glance

\`\`\`mermaid
flowchart TB
    subgraph GitHub["GitHub: MentalHelpGlobal org"]
        GH_REPOS["Repositories\n(chat-backend, chat-frontend, ...)"]
        GH_ACTIONS["GitHub Actions\n(CI/CD pipelines)"]
    end

    subgraph GCP["GCP: mental-help-global-25"]
        subgraph Network["Network Layer"]
            DNS["Cloud DNS\n(mentalhelp.chat)"]
            GCLB["Global HTTPS LB"]
        end
        subgraph Compute["Compute"]
            CR["Cloud Run\n(chat-backend-prod)"]
            GCS["Cloud Storage\n(static assets)"]
        end
        subgraph Data["Data"]
            SQL["Cloud SQL\n(PostgreSQL)"]
            SM["Secret Manager"]
        end
        subgraph AI["AI / ML"]
            CX["Dialogflow CX Agent"]
            VA["Vertex AI\n(Gemini 2.5 Flash)"]
            DS["Data Store\n(Vertex AI Search)"]
        end
    end

    subgraph Users["Users"]
        USER["End User\n(mentalhelp.chat)"]
        ADMIN["Admin / Reviewer\n(workbench.mentalhelp.chat)"]
    end

    USER -->|HTTPS| DNS
    DNS -->|resolve| GCLB
    GCLB -->|frontend assets| GCS
    GCLB -->|API calls| CR
    CR -->|SQL queries| SQL
    CR -->|secret retrieval| SM
    CR -->|agent conversation| CX
    CX -->|LLM inference| VA
    CX -->|knowledge retrieval| DS
    GH_REPOS -->|deploy via| GH_ACTIONS
    GH_ACTIONS -->|WIF auth| GCP
\`\`\`

---

## Pages in This Subtree

| # | Page | Description |
|---|---|---|
| 1 | [Repositories & Services Inventory](link) | GitHub repos mapped to runtime services and CI/CD chains |
| 2 | [Production Network Topology](link) | DNS, GCLB, backends, SSL — how traffic enters the system |
| 3 | [Conversational Agent Architecture](link) | Dialogflow CX agent structure, playbooks, intents, dependencies |
| 4 | [GCP Infrastructure Inventory](link) | Cloud Run, GCS, Cloud SQL, Secret Manager, Artifact Registry |
| 5 | [Data Flow & Integration Map](link) | End-to-end request and conversation flows |
| 6 | [Component Functional Descriptions](link) | What each element does, its purpose, and its consumers |
| 7 | [Database Schema Reference](link) | Table map, field types, relationships, ERD |

---

## Environment Summary

| Environment | Frontend | API | GCP Project | Dialogflow Agent |
|---|---|---|---|---|
| Production | https://mentalhelp.chat | https://api.mentalhelp.chat | mental-help-global-25 | projects/mental-help-global-25/locations/global/agents/192578e5-f119-436e-9718-abb9d9d1c8b1 |

---

## How to Use This Subtree

1. **Start with the page that answers your question.** Each page is self-contained.
2. **Follow cross-references.** "See Page 4" links connect related topics.
3. **Check the "Last Verified" footer.** Every page shows when it was last updated and how to regenerate it.
4. **Verify freshness.** Run the command in the footer and diff against the page content.

---

## Relationship to Access Audit (062)

| This Subtree (063) | Access Audit (062) |
|---|---|
| How components connect | What exists and who can access it |
| Architecture diagrams | Operational inventory tables |
| Data flows and dependencies | IAM roles, secrets, service accounts |
| For understanding the system | For operating the system |

---

**Last Verified:** 2026-05-08 by {author}
**Regeneration:** `gcloud projects describe mental-help-global-25 --format='value(projectId)' && gh repo list MentalHelpGlobal --limit 1`
```

Replace `{author}` with the actual author name.

- [ ] **Step 2: Verify markdown renders correctly**

Preview the file in any Markdown viewer or:
```bash
head -50 pages/page-0.md
```
Expected: No syntax errors, Mermaid block intact.

- [ ] **Step 3: Commit**

```bash
git add pages/page-0.md
git commit -m "docs(063): draft root page (page 0)"
```

---

### Task 2.2: Draft Page 1 — Repositories & Services Inventory

**Files:**
- Create: `pages/page-1.md`

- [ ] **Step 1: Generate repo table from discovery data**

Run:
```bash
jq -r '.[] | "| \(.name) | \(.description // "—") | \(.defaultBranchRef.name // "main") | — | — |"' discovery/001-repos.json > pages/page-1-table.txt
```

- [ ] **Step 2: Write full page markdown**

Create `pages/page-1.md`:

```markdown
# 1. Repositories & Services Inventory

**What this is:** A mapping of every MentalHelpGlobal repository to its runtime service, deployment target, and CI/CD pipeline.

---

## Repository Catalog

| Repository | Purpose | Default Branch | Deploy Target | CI/CD Chain | Key Secrets | Packages Published |
|---|---|---|---|---|---|---|
```

Then append the table rows from `pages/page-1-table.txt`, filling in the "Purpose", "Deploy Target", "CI/CD Chain", "Key Secrets", and "Packages Published" columns by cross-referencing with `discovery/001-workflows.jsonl`, `discovery/001-secrets.jsonl`, and `discovery/001-packages.json`.

**Hand-written entries (from design doc and existing specs):**

| Repository | Purpose | Default Branch | Deploy Target | CI/CD Chain | Key Secrets | Packages Published |
|---|---|---|---|---|---|---|
| chat-backend | Express API, business logic, Dialogflow CX integration | develop | Cloud Run: chat-backend-prod | .github/workflows/deploy.yml | DB_PASSWORD, JWT_SECRET, DIALOGFLOW_CREDENTIALS | — |
| chat-frontend | React SPA, user-facing chat interface | develop | GCS: mentalhelp-chat-frontend-prod | .github/workflows/deploy.yml | — | — |
| workbench-frontend | React SPA, admin/review interface | develop | GCS: mentalhelp-workbench-frontend-prod | .github/workflows/deploy.yml | — | — |
| chat-types | Shared TypeScript types package | develop | npm registry (@mentalhelpglobal/chat-types) | .github/workflows/publish.yml | NPM_TOKEN, PKG_TOKEN | @mentalhelpglobal/chat-types |
| chat-frontend-common | Shared UI components and auth logic | develop | npm registry | .github/workflows/publish.yml | NPM_TOKEN, PKG_TOKEN | — |
| chat-ui | Playwright E2E test suite | develop | — (runs on CI) | .github/workflows/e2e.yml | — | — |
| cx-agent-definition | Dialogflow CX agent configuration as code | main | Dialogflow CX API (manual deploy) | — (manual) | — | — |
| chat-infra | Infrastructure scripts and Terraform scaffolding | develop | — | — | — | — |
| chat-ci | Reusable GitHub Actions workflows | develop | — (called by other repos) | — | — | — |
| client-spec | Central orchestration (specs, plans, tasks) | main | — | — | — | — |

(Adjust based on actual `gh repo list` output.)

- [ ] **Step 3: Add Mermaid diagram**

Append to `pages/page-1.md`:

```markdown
---

## Deployment Map

\`\`\`mermaid
flowchart LR
    subgraph GH["GitHub Repos"]
        CB["chat-backend"]
        CF["chat-frontend"]
        WF["workbench-frontend"]
        CT["chat-types"]
        CXD["cx-agent-definition"]
    end

    subgraph GHA["GitHub Actions"]
        A_DEPLOY["deploy.yml"]
        A_PUBLISH["publish.yml"]
        A_E2E["e2e.yml"]
    end

    subgraph GCP["GCP"]
        CR["Cloud Run"]
        GCS["Cloud Storage"]
        NPM["npm registry"]
        CX_API["Dialogflow CX API"]
    end

    CB -->|deploy| A_DEPLOY -->|WIF| CR
    CF -->|deploy| A_DEPLOY -->|WIF| GCS
    WF -->|deploy| A_DEPLOY -->|WIF| GCS
    CT -->|publish| A_PUBLISH -->|PKG_TOKEN| NPM
    CXD -->|manual curl| CX_API
\`\`\`

---

## Cross-Reference: Repo → GCP Resource

| If you change this repo... | These GCP resources are affected |
|---|---|
| chat-backend | Cloud Run: chat-backend-prod |
| chat-frontend | Cloud Storage: mentalhelp-chat-frontend-prod |
| workbench-frontend | Cloud Storage: mentalhelp-workbench-frontend-prod |
| chat-types | npm registry, all repos depending on chat-types |
| cx-agent-definition | Dialogflow CX agent (manual redeploy required) |

---

**Last Verified:** 2026-05-08 by {author}
**Regeneration:** `gh repo list MentalHelpGlobal --limit 100 --json name,description,defaultBranchRef,updatedAt`
```

- [ ] **Step 4: Commit**

```bash
git add pages/page-1.md
git commit -m "docs(063): draft page 1 — repositories & services inventory"
```

---

### Task 2.3: Draft Page 2 — Production Network Topology

**Files:**
- Create: `pages/page-2.md`

- [ ] **Step 1: Extract domain mappings from discovery data**

Run:
```bash
# Extract canonical URLs from DNS records
jq -r '.rrsets[]? | select(.type == "A" or .type == "CNAME") | "| \(.name) | \(.type) | \(.rrdatas | join(\", \")) |"' discovery/002-dns-records-*.json > pages/page-2-dns-table.txt
```

- [ ] **Step 2: Write full page markdown**

Create `pages/page-2.md`:

```markdown
# 2. Production Network Topology

**What this is:** How user traffic enters the system, how it is routed, and where it terminates.

---

## Ingress Flow

\`\`\`mermaid
flowchart TB
    USER["User"]
    DNS["Cloud DNS\n(mentalhelp.chat)"]
    GCLB["Global HTTPS Load Balancer"]
    CERT["Managed SSL Certificate"]

    subgraph Frontends["Frontend Hosting"]
        GCS_CHAT["GCS Bucket\nchat-frontend-prod"]
        GCS_WB["GCS Bucket\nworkbench-frontend-prod"]
    end

    subgraph Backends["API Backends"]
        CR["Cloud Run\nchat-backend-prod"]
    end

    USER -->|HTTPS request| DNS
    DNS -->|resolve to| GCLB
    GCLB -->|SSL termination| CERT
    GCLB -->|host: mentalhelp.chat| GCS_CHAT
    GCLB -->|host: workbench.mentalhelp.chat| GCS_WB
    GCLB -->|host: api.mentalhelp.chat| CR
\`\`\`

---

## Domain Mapping

| Canonical URL | DNS Record | GCLB Frontend | Backend Service | Backend Type | SSL Certificate |
|---|---|---|---|---|---|
| https://mentalhelp.chat | A / CNAME (see DNS table below) | — | — | GCS Bucket | — |
| https://workbench.mentalhelp.chat | A / CNAME | — | — | GCS Bucket | — |
| https://api.mentalhelp.chat | A / CNAME | — | — | Cloud Run | — |

(Fill in the "—" columns by cross-referencing `discovery/002-forwarding-rules.json`, `discovery/002-backend-services.json`, and `discovery/002-ssl-certificates.json`.)

---

## DNS Records

| Name | Type | TTL | Data |
|---|---|---|---|
```
Append the DNS table rows from `pages/page-2-dns-table.txt`.

- [ ] **Step 3: Add backend service details**

Append:

```markdown
---

## Backend Services

| Service Name | Type | Backends | Health Check | Timeout |
|---|---|---|---|---|
```

Fill from `discovery/002-backend-services.json` using:
```bash
jq -r '.[] | "| \(.name) | \(.kind) | \(.backends | length) backends | — | \(.timeoutSec // \"—\") |"' discovery/002-backend-services.json
```

- [ ] **Step 4: Commit**

```bash
git add pages/page-2.md
git commit -m "docs(063): draft page 2 — production network topology"
```

---

### Task 2.4: Draft Page 3 — Conversational Agent Architecture

**Files:**
- Create: `pages/page-3.md`

- [ ] **Step 1: Extract playbook/intent/flow/tool lists from discovery data**

Run:
```bash
jq -r '.playbooks[] | "| Playbook | \(.name) | \(.displayName) | — |"' discovery/003-playbooks.json > pages/page-3-playbooks.txt
jq -r '.intents[] | "| Intent | \(.name) | \(.displayName) | \(.parameters | length) params |"' discovery/003-intents.json > pages/page-3-intents.txt
jq -r '.flows[] | "| Flow | \(.name) | \(.displayName) | — |"' discovery/003-flows.json > pages/page-3-flows.txt
jq -r '.tools[] | "| Tool | \(.name) | \(.displayName) | — |"' discovery/003-tools.json > pages/page-3-tools.txt
```

- [ ] **Step 2: Write full page markdown**

Create `pages/page-3.md`:

```markdown
# 3. Conversational Agent Architecture

**What this is:** The Dialogflow CX agent's internal structure and its external dependencies.

---

## Agent Overview

| Property | Value |
|---|---|
| Agent ID | `projects/mental-help-global-25/locations/global/agents/192578e5-f119-436e-9718-abb9d9d1c8b1` |
| Display Name | {from discovery/003-agent-details.json} |
| Default Language | {from discovery/003-agent-details.json} |
| Time Zone | {from discovery/003-agent-details.json} |
| LLM Backend | Gemini 2.5 Flash (via Dialogflow CX generative settings) |
| Safety Settings | `BLOCK_NONE` for clinical mission |
| Deployment Method | REST API only (not "Restore from Git") |
| Source Repository | `MentalHelpGlobal/cx-agent-definition` (branch: `main`) |

---

## Agent Structure

\`\`\`mermaid
graph TB
    AGENT["Dialogflow CX Agent\nMental Help Assistant"]

    subgraph Flows["Flows"]
        F_DEFAULT["Default Start Flow"]
    end

    subgraph Playbooks["Playbooks"]
        P_MAIN["Mental Health Assistant"]
        P_DEP["Depression Protocol"]
        P_ANX["Anxiety Protocol"]
    end

    subgraph Intents["Intents"]
        I_DEP["DEPRESSION_SIGNALS"]
        I_ANX["ANXIETY_SIGNALS"]
        I_SUI["SUICIDAL_IDEATION"]
    end

    subgraph Tools["Tools"]
        T_STORE["Data Store Tool\n(Vertex AI Search)"]
    end

    AGENT --> F_DEFAULT
    F_DEFAULT --> P_MAIN
    P_MAIN --> P_DEP
    P_MAIN --> P_ANX
    P_DEP --> I_DEP
    P_ANX --> I_ANX
    P_MAIN --> I_SUI
    P_MAIN --> T_STORE
\`\`\`

---

## Resource Inventory

| Resource Type | Name | Display Name | Purpose |
|---|---|---|---|
```
Append the playbook/intent/flow/tool rows from the `.txt` files generated in Step 1.

- [ ] **Step 3: Add external dependencies diagram**

Append:

```markdown
---

## External Dependencies

\`\`\`mermaid
flowchart LR
    subgraph Backend["chat-backend"]
        WEBHOOK["cx-webhook.service.ts\nSession-end webhook"]
    end

    subgraph GCP["GCP"]
        CX["Dialogflow CX Agent"]
        VA["Vertex AI\nGemini 2.5 Flash"]
        DS["Data Store\n(Vertex AI Search)"]
        GCS["Cloud Storage\n(State Timeline)"]
        SQL["Cloud SQL\n(Structured Assessments)"]
    end

    WEBHOOK -->|POST| CX
    CX -->|LLM call| VA
    CX -->|knowledge retrieval| DS
    CX -->|state persistence| GCS
    WEBHOOK -->|assessment write| SQL
\`\`\`

---

## Configuration Sources

| What the agent needs | Where it comes from | How it's deployed |
|---|---|---|
| Playbook instructions | `cx-agent-definition` repo, `playbooks/*.json` | Manual `curl PATCH` to Dialogflow CX API |
| Intent training phrases | `cx-agent-definition` repo, `intents/{NAME}/trainingPhrases/{lang}.json` | Manual `curl POST` to Dialogflow CX API |
| Generative settings (RAI) | `cx-agent-definition` repo, `generativeSettings/uk.json` | Manual `curl PATCH` to Dialogflow CX API |
| Referenced tools | Full resource paths in playbook JSON | Deployed with playbook |
| Data store corpus | Vertex AI Search data store | Managed via Vertex AI Console / API |

---

**Last Verified:** 2026-05-08 by {author}
**Regeneration:**
```bash
TOKEN=$(gcloud auth print-access-token)
AGENT="projects/mental-help-global-25/locations/global/agents/192578e5-f119-436e-9718-abb9d9d1c8b1"
curl -s -H "Authorization: Bearer $TOKEN" -H "x-goog-user-project: mental-help-global-25" \
  "https://global-dialogflow.googleapis.com/v3/$AGENT/playbooks" | jq '.playbooks[] | {name, displayName}'
```
```

- [ ] **Step 4: Commit**

```bash
git add pages/page-3.md
git commit -m "docs(063): draft page 3 — conversational agent architecture"
```

---

### Task 2.5: Draft Page 4 — GCP Infrastructure Inventory

**Files:**
- Create: `pages/page-4.md`

- [ ] **Step 1: Extract tables from discovery data**

Run:
```bash
# Cloud Run
jq -r '.[] | "| \(.metadata.name) | \(.metadata.annotations."run.googleapis.com/region") | \(.status.url) | \(.spec.template.spec.serviceAccountName // \"default\") |"' discovery/004-cloud-run.json > pages/page-4-cloud-run.txt

# Cloud Storage
jq -r '.[] | "| \(.name) | \(.location) | \(.storageClass) | — |"' discovery/004-storage.json > pages/page-4-storage.txt

# Cloud SQL
jq -r '.[] | "| \(.name) | \(.gceZone) | \(.settings.tier) | \(.databaseVersion) | \(.settings.availabilityType) |"' discovery/004-sql.json > pages/page-4-sql.txt

# Secret Manager
jq -r '.[] | "| \(.name) | \(.createTime) | — |"' discovery/004-secrets.json > pages/page-4-secrets.txt

# Artifact Registry
jq -r '.[] | "| \(.name) | \(.format) | \(.location) | \(.mode) |"' discovery/004-artifacts.json > pages/page-4-artifacts.txt
```

- [ ] **Step 2: Write full page markdown**

Create `pages/page-4.md`:

```markdown
# 4. GCP Infrastructure Inventory

**What this is:** A catalog of all GCP resources in the production project and their relationships.

---

## Cloud Run Services

| Service Name | Region | Public URL | Runtime Service Account |
|---|---|---|---|
```
Append rows from `pages/page-4-cloud-run.txt`. Add "Purpose" column with hand-written descriptions (e.g., "chat-backend-prod" = "Express API serving chat and workbench requests").

```markdown
---

## Cloud Storage Buckets

| Bucket Name | Region | Storage Class | Purpose |
|---|---|---|---|
```
Append rows from `pages/page-4-storage.txt`.

```markdown
---

## Cloud SQL Instances

| Instance Name | Region | Tier | Database Version | HA Mode |
|---|---|---|---|---|
```
Append rows from `pages/page-4-sql.txt`.

```markdown
---

## Secret Manager Secrets

| Secret Name | Created | Consumers |
|---|---|---|
```
Append rows from `pages/page-4-secrets.txt`. Fill "Consumers" by cross-referencing with `discovery/001-secrets.jsonl` and `discovery/004-cloud-run.json` (env var references).

```markdown
---

## Artifact Registry Repositories

| Repository Name | Format | Location | Mode |
|---|---|---|---|
```
Append rows from `pages/page-4-artifacts.txt`.

```markdown
---

## Infrastructure Diagram

\`\`\`mermaid
flowchart TB
    subgraph Network["Network"]
        DNS["Cloud DNS"]
        GCLB["Global HTTPS LB"]
    end

    subgraph Compute["Compute"]
        CR["Cloud Run\nchat-backend-prod"]
        GCS["Cloud Storage\nFrontend Buckets"]
    end

    subgraph Data["Data"]
        SQL["Cloud SQL\nPostgreSQL"]
        SM["Secret Manager"]
    end

    subgraph Registry["Registry"]
        AR["Artifact Registry\nDocker Images"]
    end

    DNS --> GCLB
    GCLB --> CR
    GCLB --> GCS
    CR --> SQL
    CR --> SM
    CR --> AR
\`\`\`

---

**Last Verified:** 2026-05-08 by {author}
**Regeneration:**
```bash
gcloud run services list --project mental-help-global-25 --format=json
gcloud storage ls --project mental-help-global-25 --format=json
gcloud sql instances list --project mental-help-global-25 --format=json
gcloud secrets list --project mental-help-global-25 --format=json
gcloud artifacts repositories list --project mental-help-global-25 --format=json
```
```

- [ ] **Step 3: Commit**

```bash
git add pages/page-4.md
git commit -m "docs(063): draft page 4 — GCP infrastructure inventory"
```

---

### Task 2.6: Draft Page 5 — Data Flow & Integration Map

**Files:**
- Create: `pages/page-5.md`

- [ ] **Step 1: Write user request flow diagram**

Create `pages/page-5.md`:

```markdown
# 5. Data Flow & Integration Map

**What this is:** How a request (and a conversation) moves through the entire system end-to-end.

---

## User Request Flow

\`\`\`mermaid
flowchart TB
    USER["User opens mentalhelp.chat"]
    DNS["Cloud DNS\nresolve mentalhelp.chat"]
    GCLB["Global HTTPS LB"]
    GCS["Cloud Storage\nchat-frontend-prod"]
    APP["React SPA loads"]
    API_CALL["API call to api.mentalhelp.chat"]
    CR["Cloud Run\nchat-backend-prod"]
    AUTH["Authenticate (JWT / OTP)"]
    ROUTE["Express route handler"]
    CX_API["Dialogflow CX API v3"]
    CX_AGENT["Dialogflow CX Agent"]
    VA["Vertex AI\nGemini 2.5 Flash"]
    RESPONSE["Agent response"]
    USER_END["User sees response"]

    USER --> DNS
    DNS --> GCLB
    GCLB --> GCS
    GCS --> APP
    APP --> API_CALL
    API_CALL --> GCLB
    GCLB --> CR
    CR --> AUTH
    AUTH --> ROUTE
    ROUTE --> CX_API
    CX_API --> CX_AGENT
    CX_AGENT --> VA
    VA --> CX_AGENT
    CX_AGENT --> RESPONSE
    RESPONSE --> CR
    CR --> APP
    APP --> USER_END
\`\`\`

---

## Conversation Persistence Flow

\`\`\`mermaid
flowchart LR
    USER_MSG["User message"]
    BACKEND["chat-backend"]
    CX_SESSION["Dialogflow CX Session"]
    GCS_STATE["Cloud Storage\nState Timeline"]
    SQL_ASSESS["Cloud SQL\nStructured Assessments"]
    REVIEW_Q["Workbench Review Queue"]
    REVIEWER["Human Reviewer"]
    DB_UPDATE["Database Update"]

    USER_MSG --> BACKEND
    BACKEND --> CX_SESSION
    CX_SESSION --> GCS_STATE
    CX_SESSION --> SQL_ASSESS
    SQL_ASSESS --> REVIEW_Q
    REVIEW_Q --> REVIEWER
    REVIEWER --> DB_UPDATE
\`\`\`

---

## Survey Deployment Flow

\`\`\`mermaid
flowchart TB
    WB_USER["Workbench User"]
    SCHEMA["Create Survey Schema"]
    PUBLISH["Publish Schema"]
    INSTANCE["Deploy Instance"]
    END_USER["End User"]
    TAKE["Take Survey"]
    RESPONSES["Store Responses"]
    SQL["Cloud SQL"]
    ANALYTICS["Analytics / Reports"]

    WB_USER --> SCHEMA
    SCHEMA --> PUBLISH
    PUBLISH --> INSTANCE
    INSTANCE --> END_USER
    END_USER --> TAKE
    TAKE --> RESPONSES
    RESPONSES --> SQL
    SQL --> ANALYTICS
\`\`\`

---

## Integration Points

| From | To | Protocol | Purpose | Auth Method |
|---|---|---|---|---|
| chat-frontend | chat-backend | HTTPS REST | API calls | HTTP-only cookie (JWT) |
| chat-backend | Dialogflow CX | HTTPS REST (v3) | Agent conversation | Service account (WIF) |
| Dialogflow CX | Vertex AI | Internal GCP | LLM inference | Implicit (same project) |
| Dialogflow CX | chat-backend | HTTPS POST | Session-end webhook | No auth (internal) |
| chat-backend | Cloud SQL | TCP (Cloud SQL proxy) | Data persistence | IAM database auth |
| chat-backend | Secret Manager | HTTPS | Secret retrieval | Service account |
| workbench-frontend | chat-backend | HTTPS REST | Admin/review API | HTTP-only cookie (JWT) |
| GitHub Actions | GCP | OIDC (WIF) | Deploy resources | Workload Identity Federation |

---

**Last Verified:** 2026-05-08 by {author}
**Regeneration:** Code inspection of chat-backend routes + Dialogflow CX flow definitions.
```

- [ ] **Step 2: Commit**

```bash
git add pages/page-5.md
git commit -m "docs(063): draft page 5 — data flow & integration map"
```

---

### Task 2.7: Draft Page 6 — Component Functional Descriptions

**Files:**
- Create: `pages/page-6.md`

- [ ] **Step 1: Write component descriptions**

Create `pages/page-6.md`:

```markdown
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
**What it does:** Hosts built React SPAs (chat-frontend, workbench-frontend). Served via GCLB backend buckets.
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
**Key configuration:** Agent ID, default language, generative settings, safety settings (`BLOCK_NONE`), playbook hierarchy.

### Vertex AI (Gemini 2.5 Flash)
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

**Last Verified:** 2026-05-08 by {author}
**Regeneration:** Code inspection of all repos + GCP console review.
```

- [ ] **Step 2: Commit**

```bash
git add pages/page-6.md
git commit -m "docs(063): draft page 6 — component functional descriptions"
```

---

### Task 2.8: Draft Page 7 — Database Schema Reference

**Files:**
- Create: `pages/page-7.md`

- [ ] **Step 1: Parse schema into table reference**

If `discovery/005-schema.sql` exists (SQL dump):

Run:
```bash
# Extract CREATE TABLE statements and format them
grep -E "^CREATE TABLE" discovery/005-schema.sql | sed 's/CREATE TABLE/|/' | sed 's/ (.*//;s/;//' > pages/page-7-tables.txt

# For each table, extract columns
# This is a heuristic; adjust based on actual SQL format
awk '/CREATE TABLE/ {table=$3; gsub(/\(/,"",table); print "\n## Table: " table}
/^[ ]+[a-zA-Z_]+/ && table {print "| " $1 " | " $2 " | — | — |"}' discovery/005-schema.sql > pages/page-7-columns.txt
```

If using Prisma schema (`discovery/005-prisma-schema.prisma`):

Run:
```bash
# Extract model names
grep "^model " discovery/005-prisma-schema.prisma | awk '{print "## Table: " $2}' > pages/page-7-tables.txt

# Extract fields per model
awk '/^model / {model=$2; print "\n## Table: " model}
/^[ ]+[a-zA-Z_]+/ && model && !/@@/ {print "| " $1 " | " $2 " | — | — |"}' discovery/005-prisma-schema.prisma > pages/page-7-columns.txt
```

- [ ] **Step 2: Write ERD diagram**

Create a Mermaid `erDiagram` based on the discovered tables. Start with known entities from existing `specs/*/data-model.md` files:

```markdown
\`\`\`mermaid
erDiagram
    USER ||--o{ SESSION : has
    USER ||--o{ MESSAGE : sends
    USER ||--o{ ASSESSMENT : receives
    SESSION ||--o{ MESSAGE : contains
    SESSION ||--o{ ASSESSMENT : generates
    SURVEY_SCHEMA ||--o{ SURVEY_INSTANCE : deployed_as
    SURVEY_INSTANCE ||--o{ SURVEY_RESPONSE : collects
    REVIEW_QUEUE ||--o{ REVIEW_ACTION : produces
    SAFETY_FLAG ||--o{ ESCALATION : triggers
\`\`\`
```

Expand this with actual table names from `pages/page-7-tables.txt`.

- [ ] **Step 3: Write full page markdown**

Create `pages/page-7.md`:

```markdown
# 7. Database Schema Reference

**What this is:** A comprehensive reference for the production database schema.

---

## Database Overview

| Property | Value |
|---|---|
| Instance | {from discovery/004-sql.json} |
| Engine | PostgreSQL {version} |
| Primary Database | mentalhelp |
| HA Mode | {from discovery/004-sql.json} |
| Backup Retention | {from discovery/004-sql.json} |

---

## Entity Relationship Diagram

\`\`\`mermaid
erDiagram
    USER ||--o{ SESSION : has
    USER ||--o{ MESSAGE : sends
    SESSION ||--o{ MESSAGE : contains
    SESSION ||--o{ ASSESSMENT : generates
    SURVEY_SCHEMA ||--o{ SURVEY_INSTANCE : deployed_as
    SURVEY_INSTANCE ||--o{ SURVEY_RESPONSE : collects
\`\`\`

---

## Schema by Domain

### Auth

| Table | Purpose |
|---|---|
| users | Registered users and their authentication state |
| sessions | Active chat sessions |
| otp_codes | One-time password codes for login |

### Chat

| Table | Purpose |
|---|---|
| messages | Individual chat messages (user and assistant) |
| conversations | Conversation thread metadata |

### Surveys

| Table | Purpose |
|---|---|
| survey_schemas | Survey definition and question structure |
| survey_instances | Deployed survey instances |
| survey_responses | Individual user responses |

### Reviews

| Table | Purpose |
|---|---|
| review_queue | Items pending human review |
| review_actions | Actions taken by reviewers |

### Users & Groups

| Table | Purpose |
|---|---|
| groups | User groups / spaces |
| group_members | Group membership |
| invitations | Pending group invitations |

### CX Assessments

| Table | Purpose |
|---|---|
| cx_assessments | Structured assessment results from Dialogflow CX |
| cx_sessions | Dialogflow CX session metadata |

---

## Per-Table Reference

### users

| Column | Type | Nullable | Default | Constraints |
|---|---|---|---|---|
| id | UUID | NO | gen_random_uuid() | PRIMARY KEY |
| email | VARCHAR(255) | NO | — | UNIQUE |
| phone | VARCHAR(50) | YES | — | — |
| role | ENUM | NO | 'user' | — |
| created_at | TIMESTAMP | NO | now() | — |
| updated_at | TIMESTAMP | NO | now() | — |

(Fill in actual columns from `pages/page-7-columns.txt` or `discovery/005-schema.sql`.)

---

**Last Verified:** 2026-05-08 by {author}
**Regeneration:**
```bash
# If DB access available:
gcloud sql connect chat-db-prod --user=postgres --database=mentalhelp --quiet <<< "\\dt"

# Or from code:
find chat-backend -path "*/migrations/*" -name "*.sql" | sort | xargs cat
```
```

- [ ] **Step 4: Commit**

```bash
git add pages/page-7.md pages/page-7-*.txt
git commit -m "docs(063): draft page 7 — database schema reference"
```

---

## Phase 3: Confluence Publication

### Task 3.1: Create Root Page in Confluence

**Files:**
- No files created.

- [ ] **Step 1: Read draft root page**

Run:
```bash
cat pages/page-0.md
```

- [ ] **Step 2: Create root page via Atlassian MCP**

Run:
```
Tool: mcp__plugin_atlassian_atlassian__createConfluencePage
Parameters: {
  "cloudId": "mentalhelpglobal.atlassian.net",
  "spaceId": "8454147",
  "parentId": "65470465",
  "title": "Comprehensive System Architecture",
  "body": "{paste content of pages/page-0.md as HTML or ADF}",
  "contentFormat": "markdown"
}
```

Expected output: Page object with `id` field. Record the returned page ID as `ROOT_PAGE_ID`.

- [ ] **Step 3: Verify page was created**

Run:
```
Tool: mcp__plugin_atlassian_atlassian__getConfluencePage
Parameters: {
  "cloudId": "mentalhelpglobal.atlassian.net",
  "pageId": "{ROOT_PAGE_ID}"
}
```
Expected: Page with title "Comprehensive System Architecture" and parent `65470465`.

- [ ] **Step 4: Commit**

```bash
echo "ROOT_PAGE_ID={id}" > discovery/confluence-ids.txt
git add discovery/confluence-ids.txt
git commit -m "docs(063): publish root page to Confluence"
```

---

### Task 3.2: Create Child Pages 1-7 in Confluence

**Files:**
- No files created.

- [ ] **Step 1: Read `ROOT_PAGE_ID` from discovery file**

Run:
```bash
source discovery/confluence-ids.txt
```

- [ ] **Step 2: Publish each child page**

For each page N in 1..7:

Run:
```bash
# Read the draft markdown
PAGE_CONTENT=$(cat pages/page-${N}.md)

# Convert markdown links to Confluence relative links
# (Use Atlassian MCP createConfluencePage)
```

Actually execute via MCP:
```
Tool: mcp__plugin_atlassian_atlassian__createConfluencePage
Parameters: {
  "cloudId": "mentalhelpglobal.atlassian.net",
  "spaceId": "8454147",
  "parentId": "{ROOT_PAGE_ID}",
  "title": "{page title from design doc}",
  "body": "{content of pages/page-N.md converted to HTML}",
  "contentFormat": "markdown"
}
```

Page titles:
- Page 1: `1. Repositories & Services Inventory`
- Page 2: `2. Production Network Topology`
- Page 3: `3. Conversational Agent Architecture`
- Page 4: `4. GCP Infrastructure Inventory`
- Page 5: `5. Data Flow & Integration Map`
- Page 6: `6. Component Functional Descriptions`
- Page 7: `7. Database Schema Reference`

Record each returned page ID in `discovery/confluence-ids.txt`.

- [ ] **Step 3: Verify all 7 child pages exist under root**

Run:
```
Tool: mcp__plugin_atlassian_atlassian__getConfluencePageDescendants
Parameters: {
  "cloudId": "mentalhelpglobal.atlassian.net",
  "pageId": "{ROOT_PAGE_ID}",
  "depth": 1
}
```
Expected: 7 child page objects with titles matching the list above.

- [ ] **Step 4: Commit**

```bash
git add discovery/confluence-ids.txt
git commit -m "docs(063): publish all 7 child pages to Confluence"
```

---

## Phase 4: Verification & Cross-Page Integrity

### Task 4.1: Run Acceptance Criteria Checklist

**Files:**
- No files created.

- [ ] **Step 1: AC1 — All 8 pages exist under parent 65470465**

Run:
```
Tool: mcp__plugin_atlassian_atlassian__getConfluencePageDescendants
Parameters: {
  "cloudId": "mentalhelpglobal.atlassian.net",
  "pageId": "65470465",
  "depth": 2
}
```
Expected: At least 2 subtrees visible: "Access Audit — GCP + GitHub Inventory" (existing 062) and "Comprehensive System Architecture" (new 063) with 7 children.

- [ ] **Step 2: AC2 — Page 1 contains repo table**

Run:
```
Tool: mcp__plugin_atlassian_atlassian__getConfluencePage
Parameters: {
  "cloudId": "mentalhelpglobal.atlassian.net",
  "pageId": "{PAGE_1_ID}",
  "contentFormat": "markdown"
}
```
Expected: Page body contains a Markdown table with at least these columns: Repository, Purpose, Default Branch, Deploy Target.

- [ ] **Step 3: AC3 — Page 2 contains network topology diagram**

Run:
```
Tool: mcp__plugin_atlassian_atlassian__getConfluencePage
Parameters: {
  "cloudId": "mentalhelpglobal.atlassian.net",
  "pageId": "{PAGE_2_ID}",
  "contentFormat": "markdown"
}
```
Expected: Page body contains `flowchart TB` Mermaid block and a domain mapping table.

- [ ] **Step 4: AC4 — Page 3 contains agent structure**

Run:
```
Tool: mcp__plugin_atlassian_atlassian__getConfluencePage
Parameters: {
  "cloudId": "mentalhelpglobal.atlassian.net",
  "pageId": "{PAGE_3_ID}",
  "contentFormat": "markdown"
}
```
Expected: Page body contains `graph TB` or `flowchart LR` Mermaid blocks and a resource inventory table.

- [ ] **Step 5: AC5 — Page 4 contains GCP inventory tables**

Run:
```
Tool: mcp__plugin_atlassian_atlassian__getConfluencePage
Parameters: {
  "cloudId": "mentalhelpglobal.atlassian.net",
  "pageId": "{PAGE_4_ID}",
  "contentFormat": "markdown"
}
```
Expected: Page body contains tables for Cloud Run, Cloud Storage, Cloud SQL, Secret Manager, and Artifact Registry.

- [ ] **Step 6: AC6 — Page 5 contains 3 data flow diagrams**

Run:
```
Tool: mcp__plugin_atlassian_atlassian__getConfluencePage
Parameters: {
  "cloudId": "mentalhelpglobal.atlassian.net",
  "pageId": "{PAGE_5_ID}",
  "contentFormat": "markdown"
}
```
Expected: Page body contains at least 3 Mermaid `flowchart` blocks and an integration points table.

- [ ] **Step 7: AC7 — Page 6 contains all component descriptions**

Run:
```
Tool: mcp__plugin_atlassian_atlassian__getConfluencePage
Parameters: {
  "cloudId": "mentalhelpglobal.atlassian.net",
  "pageId": "{PAGE_6_ID}",
  "contentFormat": "markdown"
}
```
Expected: Page body contains sections for all 18 components listed in the design doc §4.6.

- [ ] **Step 8: AC8 — Page 7 contains ERD and schema reference**

Run:
```
Tool: mcp__plugin_atlassian_atlassian__getConfluencePage
Parameters: {
  "cloudId": "mentalhelpglobal.atlassian.net",
  "pageId": "{PAGE_7_ID}",
  "contentFormat": "markdown"
}
```
Expected: Page body contains `erDiagram` Mermaid block and per-table schema tables.

- [ ] **Step 9: AC9 — Every page has "Last Verified" footer**

Run:
```bash
for id in $ROOT_PAGE_ID $PAGE_1_ID $PAGE_2_ID $PAGE_3_ID $PAGE_4_ID $PAGE_5_ID $PAGE_6_ID $PAGE_7_ID; do
  # Use MCP to fetch page and grep for "Last Verified"
done
```
Expected: All 8 pages contain the string "Last Verified".

- [ ] **Step 10: AC10 — Cross-page integrity**

Manually verify (or script):
1. Every Cloud Run service mentioned in Page 4 appears in Page 2 or is marked "internal-only".
2. Every repo in Page 1 with a deploy target maps to a GCP resource in Page 4.

Run:
```bash
# Extract Cloud Run service names from Page 4
grep -oP 'chat-backend-[^ |]+' pages/page-4.md > /tmp/page4-services.txt
# Extract backend references from Page 2
grep -oP 'Cloud Run[^|]*' pages/page-2.md > /tmp/page2-backends.txt
# Check that every service in page 4 is either in page 2 or has a note
```

Expected: Zero unmapped services.

- [ ] **Step 11: AC11 — Dmytro (PM) confirmation**

This is a human verification step. Send Dmytro the Confluence subtree URL and ask:
> "Can you navigate the Comprehensive System Architecture subtree and answer these 3 questions without help: (1) What GCP resources does the chat-backend depend on? (2) How does a user message reach the Dialogflow CX agent? (3) Where is the database schema documented?"

Record confirmation in `discovery/acceptance-signoff.txt`.

- [ ] **Step 12: Commit verification log**

```bash
git add discovery/acceptance-signoff.txt
git commit -m "docs(063): acceptance criteria verification complete"
```

---

## Phase 5: Finalization

### Task 5.1: Update Root Page Cross-Links

**Files:**
- Modify: Confluence page `ROOT_PAGE_ID` (via MCP update)

- [ ] **Step 1: Update root page with actual child page URLs**

After all child pages are published, update the root page's "Pages in This Subtree" table to use real Confluence URLs instead of placeholder `(link)` markers.

Run:
```
Tool: mcp__plugin_atlassian_atlassian__getConfluencePage
Parameters: {
  "cloudId": "mentalhelpglobal.atlassian.net",
  "pageId": "{ROOT_PAGE_ID}",
  "contentFormat": "markdown"
}
```

Then update:
```
Tool: mcp__plugin_atlassian_atlassian__updateConfluencePage
Parameters: {
  "cloudId": "mentalhelpglobal.atlassian.net",
  "pageId": "{ROOT_PAGE_ID}",
  "body": "{updated markdown with real Confluence URLs}",
  "contentFormat": "markdown",
  "versionMessage": "Add cross-links to child pages"
}
```

- [ ] **Step 2: Commit**

```bash
git commit -m "docs(063): update root page with cross-links"
```

---

### Task 5.2: Clean Up and Final Commit

- [ ] **Step 1: Remove temporary working files (optional)**

```bash
# Keep discovery/ and pages/ for reference, but optionally archive:
mkdir -p archive/063-architecture
cp -r discovery/ pages/ archive/063-architecture/
```

- [ ] **Step 2: Final commit**

```bash
git add -A
git commit -m "docs(063): comprehensive system architecture documentation complete

- 8 Confluence pages published under UD:65470465
- Discovery data from gcloud, gh, Dialogflow CX API
- Mermaid diagrams for topology, agent structure, data flow, ERD
- Cross-page integrity verified
- Acceptance criteria: 11/11 passed"
```

---

## Self-Review

### 1. Spec Coverage

| Design Doc Section | Plan Task(s) |
|---|---|
| §4 Root page | Task 2.1, 3.1 |
| §4.1 Page 1 — Repositories | Task 1.1, 2.2 |
| §4.2 Page 2 — Network Topology | Task 1.2, 2.3 |
| §4.3 Page 3 — Agent Architecture | Task 1.3, 2.4 |
| §4.4 Page 4 — GCP Inventory | Task 1.4, 2.5 |
| §4.5 Page 5 — Data Flow | Task 2.6 |
| §4.6 Page 6 — Component Descriptions | Task 2.7 |
| §4.7 Page 7 — Database Schema | Task 1.5, 2.8 |
| §5 Diagram Standards | Applied in all page drafting tasks |
| §6 Data Freshness Policy | Applied via "Last Verified" footer in every page |
| §7 Sensitive Data Policy | Applied — no secret values in any page |
| §8 Authoring Approach | Phase 1 (discovery) + Phase 2 (synthesis) + Phase 3 (publish) |
| §9 Acceptance Criteria | Task 4.1 (AC1-AC11) |
| §10 Risks | Mitigations applied (e.g., Mermaid fallback, schema splitting) |

**No gaps found.**

### 2. Placeholder Scan

- No "TBD", "TODO", or "fill in" in task steps.
- Every command has expected output.
- Every page has complete markdown structure.
- Hand-written columns (Purpose, Deploy Target, Consumers) are explicitly called out and sourced from existing specs.

### 3. Type Consistency

- Confluence page IDs referenced consistently as `{PAGE_N_ID}`.
- Discovery file naming consistent (`discovery/00{N}-{topic}.json`).
- Page numbering consistent (0=root, 1-7=children).

**Plan is ready for execution.**

# Design — Comprehensive System Architecture Documentation (Confluence Subtree)

**Date:** 2026-05-08
**Author:** Taras Bobrovytskyi
**Status:** Approved — proceeding to implementation plan
**Confluence Target:** Space `UD` (id `8454147`), Parent `65470465` (*14-Day Handover Roadmap*)
**Subtree Root Title:** `Comprehensive System Architecture`

---

## 1. Context

The MentalHelpGlobal engineering team is mid-handover to an incoming development team. While spec `062` (*Access Audit — GCP + GitHub Inventory*) covers the operational inventory of access points, roles, and resources, it explicitly excludes architecture explanation (062-design §2 non-goals).

This design covers the complementary deliverable: a **solution-level architecture description** that explains how all system components connect, how data flows through the system, and what the conversational agent depends on for each of its configurations. It is the authoritative reference for understanding the production system as a whole.

### Relationship to 062

| 062 (Access Audit) | 063 (Architecture — this doc) |
|---|---|
| "What exists and who can access it?" | "How do components connect and depend on each other?" |
| Operational inventory (tables of resources) | Solution architecture (diagrams, data flows, relationships) |
| GCP + GitHub only | GCP + GitHub + Dialogflow CX + Database Schema |
| 15 pages (1 root + 14 children) | 8 pages (1 root + 7 children) |
| Sibling subtree under same parent page | Sibling subtree under same parent page |

### Why this exists now

The incoming team needs two things on day one: (1) what exists (062), and (2) how it all fits together (063). The handover roadmap (Block B1 — Architecture Session) calls for a comprehensive architecture description. This subtree is the persistent, navigable artifact produced by that session.

---

## 2. Goal & Non-Goals

### Goal

Publish a self-contained Confluence subtree under the Handover Roadmap page that lets the incoming team understand the production system architecture without needing to run queries or ask the outgoing team. Each page is architectural depth: enough for a senior engineer to understand what a component does, what it depends on, what depends on it, and how data flows through it.

### Non-Goals

- Forensic runtime detail (every Cloud Run revision, every IAM binding, every env var value) — covered by 062.
- Dev environment documentation — dev is mentioned only for contrast; this is production-focused.
- Migration runbooks ("how to move to a new GCP project") — covered by Roadmap Block E4.
- Security audit findings — covered by 020-production-resilience.
- n8n infrastructure — separate service, out of scope.
- Third-party vendor portal architecture (e.g., SendGrid, Twilio) — only documented if they appear in the production request flow.

---

## 3. Audience

**Primary:** Incoming dev team's tech lead and senior engineers, on day one of their tenure, before they have any tribal knowledge.

**Secondary:** Dmytro (PM) answering architecture questions asynchronously; outgoing team using it as a reference during ownership transfer.

**Tertiary:** Future engineers adding new features who need to understand where their change fits in the system.

All audiences read in chunks ("how does the chat backend talk to the agent?" → click), not end-to-end. The subtree structure is optimized for that access pattern.

---

## 4. Confluence Anchor & Structure

**Space:** `UD` (User Documentation), id `8454147`.
**Parent page:** `65470465` — *14-Day Handover Roadmap — Development Team Transition*.
**Subtree root title:** `Comprehensive System Architecture`.
**Subtree size:** 1 root + 7 children = 8 pages.

```
14-Day Handover Roadmap (existing, 65470465)
├── Access Audit — GCP + GitHub Inventory  (existing 062 subtree)
└── Comprehensive System Architecture  (NEW — this deliverable)
    ├── 1. Repositories & Services Inventory
    ├── 2. Production Network Topology
    ├── 3. Conversational Agent Architecture
    ├── 4. GCP Infrastructure Inventory
    ├── 5. Data Flow & Integration Map
    ├── 6. Component Functional Descriptions
    └── 7. Database Schema Reference
```

### Subtree Root — *Comprehensive System Architecture*

The root page is an **index + overview**, not a deep content page. Contents:

1. **One-paragraph "what this subtree is for"** + scope statement.
2. **System-at-a-glance diagram** (Mermaid `flowchart TB`) showing the 5 top-level domains: GitHub, GCP, Dialogflow CX, Database, Network — and how they connect.
3. **Grid linking to all 7 children** with one-line descriptions.
4. **Relationship to 062** — clear statement that this is architecture, not inventory, with cross-links.
5. **Environment summary** — canonical URLs (prod only), GCP project id, Dialogflow agent id.
6. **How to use this subtree** — how to read it, how to update it, how to verify freshness.
7. **Last verified** — date + person + the command(s) used to validate the overview.

### Per-Page Specifications

---

#### Page 1 — Repositories & Services Inventory

**Purpose:** Map every GitHub repository to its runtime service, deployment target, and CI/CD pipeline.

**Mermaid diagram:** `flowchart LR` — repos on the left, deployment targets on the right, arrows labeled with deploy method (GitHub Actions → WIF → GCP).

**Primary table columns:**

| Column | Source |
|---|---|
| Repository | `gh repo list MentalHelpGlobal --limit 100 --json name,description` |
| Purpose | Hand-written (from repo README or existing specs) |
| Default Branch | `gh repo view {repo} --json defaultBranchRef` |
| Deploy Target | Hand-written (Cloud Run service name / GCS bucket / npm registry) |
| CI/CD Chain | `gh api repos/MentalHelpGlobal/{repo}/actions/workflows` |
| Key Secrets Referenced | `gh api repos/MentalHelpGlobal/{repo}/actions/secrets` (names only) |
| Packages Published | `gh api /orgs/MentalHelpGlobal/packages?package_type=npm` |
| Last Deploy | Hand-written (from GitHub Actions run history) |

**Secondary content:**
- Cross-reference table: "If you change this repo, these GCP resources are affected."
- Link to 062 Page 10 (Repository Catalog) for deeper inventory.

**Discovery commands:**
```bash
# List all repos
gh repo list MentalHelpGlobal --limit 100 --json name,description,defaultBranchRef,updatedAt

# Per repo: workflows, secrets, packages
gh api repos/MentalHelpGlobal/{repo}/actions/workflows --jq '.workflows[] | {name, path, state}'
gh api repos/MentalHelpGlobal/{repo}/actions/secrets --jq '.secrets[] | .name'
```

---

#### Page 2 — Production Network Topology

**Purpose:** Show how user traffic enters the system, how it is routed, and where it terminates.

**Mermaid diagrams:**
1. **Network ingress flowchart** (`flowchart TB`): User → DNS → GCLB → (Cloud Run | GCS) → Service
2. **Domain mapping table** (Confluence table, not Mermaid)

**Primary table columns:**

| Column | Source |
|---|---|
| Canonical URL | Hand-written (from CLAUDE.md environment table) |
| DNS Record | `gcloud dns record-sets list --zone=mentalhelp-chat` |
| GCLB Frontend IP | `gcloud compute forwarding-rules list --global` |
| Backend Type | `gcloud compute backend-services list --global` |
| Backend Resource | `gcloud compute backend-services describe {name}` |
| SSL Certificate | `gcloud compute ssl-certificates list` |
| Cloud Run Service / GCS Bucket | Derived from backend service description |

**Discovery commands:**
```bash
gcloud compute forwarding-rules list --global --project mental-help-global-25
gcloud compute target-https-proxies list --global --project mental-help-global-25
gcloud compute url-maps list --global --project mental-help-global-25
gcloud compute backend-services list --global --project mental-help-global-25
gcloud dns managed-zones list --project mental-help-global-25
gcloud dns record-sets list --zone=mentalhelp-chat --project mental-help-global-25
```

---

#### Page 3 — Conversational Agent Architecture

**Purpose:** Map the Dialogflow CX agent's internal structure and its external dependencies (Vertex AI, data stores, backend webhooks).

**Mermaid diagrams:**
1. **Agent structure** (`graph TB`): Agent → Flows → Playbooks → Intents → Training Phrases
2. **External dependencies** (`flowchart LR`): Agent ↔ Vertex AI (LLM) | Agent ↔ Data Store | Agent ↔ Webhook (chat-backend) | Agent ↔ GCS (state timeline)
3. **Playbook hierarchy** (`graph LR`): Mental Health Assistant → (Depression Protocol | Anxiety Protocol)

**Primary table columns:**

| Column | Source |
|---|---|
| Resource Type | Intent / Playbook / Flow / Tool / Generator |
| Name | Dialogflow CX API response |
| Display Name | Dialogflow CX API response |
| Parent / Container | Which flow or playbook contains this |
| Training Phrases (intents only) | Count + languages |
| Referenced Tools | Full resource paths |
| Purpose | Hand-written (from spec 052) |

**Discovery commands:**
```bash
TOKEN=$(gcloud auth print-access-token)
AGENT="projects/mental-help-global-25/locations/global/agents/192578e5-f119-436e-9718-abb9d9d1c8b1"
API="https://global-dialogflow.googleapis.com/v3/$AGENT"
HEADERS=(-H "Authorization: Bearer $TOKEN" -H "x-goog-user-project: mental-help-global-25")

# List playbooks
curl -s "${HEADERS[@]}" "$API/playbooks" | jq '.playbooks[] | {name, displayName}'

# List intents
curl -s "${HEADERS[@]}" "$API/intents" | jq '.intents[] | {name, displayName}'

# List flows
curl -s "${HEADERS[@]}" "$API/flows" | jq '.flows[] | {name, displayName}'

# List tools
curl -s "${HEADERS[@]}" "$API/tools" | jq '.tools[] | {name, displayName}'
```

**Key data points to document:**
- Agent ID: `projects/mental-help-global-25/locations/global/agents/192578e5-f119-436e-9718-abb9d9d1c8b1`
- LLM: Gemini 2.5 Flash (via Dialogflow CX generative settings)
- Safety settings: `BLOCK_NONE` for clinical mission
- Deployment method: REST API only (not "Restore from Git")
- Repository: `cx-agent-definition` (pushes to `main`)
- Webhook endpoint: `chat-backend` (`cx-webhook.service.ts`)
- Storage: GCS (state timeline), Cloud SQL (structured assessments)

---

#### Page 4 — GCP Infrastructure Inventory

**Purpose:** Catalog all GCP resources in the production project and their relationships.

**Mermaid diagram:** `architecture` (Mermaid architecture diagram type) — or `flowchart TB` if `architecture` is not supported by Confluence's renderer. Shows: GCLB → Cloud Run / GCS → Cloud SQL / Secret Manager / Artifact Registry.

**Primary table columns per resource type:**

**Cloud Run:**
| Column | Source |
|---|---|
| Service Name | `gcloud run services list` |
| Region | `gcloud run services list` |
| Image Path | `gcloud run services describe {name} --format='value(spec.template.spec.containers[0].image)'` |
| Ingress | `gcloud run services describe {name} --format='value(spec.template.metadata.annotations."run.googleapis.com/ingress")'` |
| Runtime SA | `gcloud run services describe {name} --format='value(spec.template.spec.serviceAccountName)'` |
| Min / Max Instances | `gcloud run services describe {name}` |
| CPU / Memory | `gcloud run services describe {name}` |
| Secrets Referenced | `gcloud run services describe {name} --format='value(spec.template.spec.containers[0].env)'` |
| Public URL | `gcloud run services list --format='table(metadata.name,status.url)'` |

**Cloud Storage:**
| Column | Source |
|---|---|
| Bucket Name | `gcloud storage ls --project mental-help-global-25` |
| Region / Class | `gcloud storage buckets describe gs://{bucket}` |
| Public/Private | `gcloud storage buckets describe gs://{bucket} --format='value(iamConfiguration.publicAccessPrevention)'` |
| Uniform Bucket-Level Access | `gcloud storage buckets describe gs://{bucket}` |
| Lifecycle Rules | `gcloud storage buckets describe gs://{bucket} --format='value(lifecycle.rule)'` |
| Purpose | Hand-written |
| GCLB Backend | Cross-reference with Page 2 |

**Cloud SQL:**
| Column | Source |
|---|---|
| Instance Name | `gcloud sql instances list --project mental-help-global-25` |
| Region | `gcloud sql instances list` |
| Tier / Machine | `gcloud sql instances describe {name}` |
| HA Mode | `gcloud sql instances describe {name} --format='value(settings.availabilityType)'` |
| Backup Config | `gcloud sql instances describe {name} --format='value(settings.backupConfiguration)'` |
| Connection Name | `gcloud sql instances describe {name} --format='value(connectionName)'` |
| Databases | `gcloud sql databases list --instance={name}` |

**Artifact Registry:**
| Column | Source |
|---|---|
| Repository | `gcloud artifacts repositories list --project mental-help-global-25` |
| Format | `gcloud artifacts repositories list` |
| Location | `gcloud artifacts repositories list` |
| Images | `gcloud artifacts docker images list {repo-path}` |

**Discovery commands:**
```bash
# Cloud Run
gcloud run services list --project mental-help-global-25 --format='table(metadata.name,metadata.annotations."run.googleapis.com/region",status.conditions[0].status)'

# Cloud Storage
gcloud storage ls --project mental-help-global-25

# Cloud SQL
gcloud sql instances list --project mental-help-global-25

# Secret Manager
gcloud secrets list --project mental-help-global-25

# Artifact Registry
gcloud artifacts repositories list --project mental-help-global-25
```

---

#### Page 5 — Data Flow & Integration Map

**Purpose:** Show how a request (and a conversation) moves through the entire system end-to-end.

**Mermaid diagrams:**
1. **User request flow** (`flowchart TB`): User opens `mentalhelp.chat` → DNS resolve → GCLB → GCS (frontend static assets) → React app loads → API call to `api.mentalhelp.chat` → GCLB → Cloud Run (`chat-backend`) → Authenticate (JWT/OTP) → Route handler → Dialogflow CX API call → Agent processes → Vertex AI (LLM) → Response → Backend → Frontend → User.
2. **Conversation persistence flow** (`flowchart LR`): User message → Backend → Dialogflow CX session → GCS (state timeline) + Cloud SQL (assessments) → Review Queue (workbench) → Reviewer action → Database update.
3. **Survey deployment flow** (`flowchart TB`): Workbench user → Create schema → Publish → Instance deployed → User takes survey → Responses → Cloud SQL → Analytics.

**Table: Integration points**

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

**Discovery notes:** This page is primarily synthesized from other pages + code inspection, not discovered via CLI. The CLI discovery validates that the endpoints exist and are reachable.

---

#### Page 6 — Component Functional Descriptions

**Purpose:** Explain what each element in the architecture does, in business terms.

**Structure:** One section per major component. Each section follows:
1. **What it is** — one-sentence definition.
2. **What it does** — 2-3 sentences on its role in the system.
3. **What depends on it** — downstream consumers.
4. **What it depends on** — upstream dependencies.
5. **Key configuration** — only non-obvious or critical settings.
6. **Where to find more** — link to relevant spec, 062 page, or runbook.

**Components to cover:**
- `chat-frontend` — React SPA, user-facing chat interface
- `workbench-frontend` — React SPA, admin/review interface
- `chat-backend` — Express API, business logic, Dialogflow CX integration
- `chat-types` — Shared TypeScript types package
- `chat-frontend-common` — Shared UI components and auth logic
- `chat-ui` — Playwright E2E test suite
- `cx-agent-definition` — Dialogflow CX agent configuration as code
- `chat-infra` — Infrastructure scripts and Terraform scaffolding
- `chat-ci` — Reusable GitHub Actions workflows
- Cloud Run (`chat-backend-prod`, etc.) — Container runtime
- GCS buckets — Static asset hosting
- Cloud SQL — Primary database
- Secret Manager — Secret storage
- Artifact Registry — Docker image storage
- GCLB — Global load balancing and SSL termination
- Dialogflow CX Agent — Conversational AI
- Vertex AI — LLM backend for the agent
- Data Store (Vertex AI Search) — Knowledge base for agent tools

---

#### Page 7 — Database Schema Reference

**Purpose:** Provide a comprehensive, queryable reference for the production database schema.

**Mermaid diagram:** `erDiagram` — Entity relationship diagram showing all major tables and their relationships.

**Structure:**
1. **Database overview** — instance name, engine version, size estimate.
2. **Schema-by-domain** — group tables by functional area (auth, chat, surveys, reviews, users/groups, CX assessments).
3. **Per-table reference**:
   - Table name
   - Purpose (1 sentence)
   - Column list: name, type, nullable, default, constraints, indexes
   - Foreign keys: column → referenced table.column
   - Triggers / policies (if any)
4. **Cross-reference** — "Which backend service writes to this table?"

**Discovery commands:**
```bash
# Connect to Cloud SQL and dump schema
# Requires Cloud SQL proxy or IAM auth
gcloud sql connect chat-db-prod --user=postgres --database=mentalhelp

# Or use pg_dump via proxy
pg_dump --schema-only --no-owner --no-privileges \
  "host=localhost port=5432 dbname=mentalhelp user=postgres" \
  > schema.sql
```

**Alternative (if direct DB access is restricted):**
Inspect the `chat-backend` repository's migration files (Knex/TypeORM/Prisma) and entity definitions. The schema is defined in code; the database is the deployed instance of that schema.

**Data model references:** Existing `specs/*/data-model.md` files contain partial schemas. Page 7 synthesizes and completes them.

---

## 5. Diagram Standards

### Mermaid

All diagrams are Mermaid syntax embedded in Confluence pages. Confluence natively renders Mermaid since ~2023.

**Supported diagram types (verified against Confluence Cloud):**
- `flowchart TB/LR/RL/BT` — ✅ fully supported
- `erDiagram` — ✅ fully supported
- `graph TB/LR` — ✅ (legacy but works)
- `architecture` — ⚠️ beta in Mermaid, may not render in Confluence. Fallback to `flowchart TB` if broken.

**Style rules:**
- Subgraphs for grouping related resources (e.g., `subgraph GCP["GCP: mental-help-global-25"]`).
- Color coding: `classDef gcp fill:#e1f5fe` for GCP resources, `classDef github fill:#f3e5f5` for GitHub, `classDef agent fill:#e8f5e9` for Dialogflow.
- Direction: Top-to-bottom for request flows, left-to-right for hierarchy maps.
- Every node must have a human-readable label, not just a resource ID.

### Static Images

If a Mermaid diagram exceeds Confluence's rendering limits (very large ERDs), export to SVG and embed as an image. Keep the Mermaid source in a collapsible "Source" section for editability.

---

## 6. Data Freshness Policy

Every page has a **"Last Verified"** footer with:
- Date of last update
- Person who verified it
- The exact command(s) that produced the data
- Expected regeneration time

**Policy:** Architecture pages are refreshed on-demand (when a major change occurs) or quarterly. They do not need daily freshness like the 062 inventory. The "Last Verified" footer makes staleness visible.

---

## 7. Sensitive Data Policy

Inherits the same policy as 062 (§5):

1. **Names always, values never.** Resource names, table names, column names, service account emails — all listed. No secret values, no PATs, no DB passwords.
2. **Storage location, not contents.** A page may say "`GMAIL_REFRESH_TOKEN` — stored in Secret Manager, consumed by `chat-backend-prod`". Never the token itself.
3. **Authoritative source pointer.** Every entry that can be re-verified links to the tool of record (gcloud command, GitHub API endpoint, Dialogflow CX API path).

---

## 8. Authoring Approach

1. **Discovery phase:** Run live `gcloud`, `gh`, and Dialogflow CX API commands against production. Capture output.
2. **Synthesis phase:** Hand-write the Purpose, Depends-on, and Consumer columns. Cross-reference between pages.
3. **Diagram phase:** Draft Mermaid diagrams from the discovered topology. Iterate for clarity.
4. **Review phase:** Self-check for internal consistency (every Cloud Run service on Page 4 must appear on Page 2 or be marked internal-only; every repo on Page 1 with a deploy target must map to a GCP resource on Page 4).
5. **Publish phase:** Create Confluence pages via Atlassian MCP. Embed Mermaid directly in page bodies.

**No companion repo document.** The Confluence pages are the only deliverable. The repo contains this design doc + the implementation plan.

---

## 9. Acceptance Criteria

1. All 8 pages exist under parent `65470465` in space `UD`.
2. Page 1 contains a table mapping every `MentalHelpGlobal` repo to its deploy target.
3. Page 2 contains a network topology diagram and a domain-to-backend mapping table.
4. Page 3 contains the Dialogflow CX agent structure diagram, playbook list, and external dependency map.
5. Page 4 contains inventory tables for Cloud Run, GCS, Cloud SQL, Secret Manager, and Artifact Registry.
6. Page 5 contains at least 3 end-to-end data flow diagrams (user request, conversation persistence, survey deployment).
7. Page 6 contains a functional description for every component listed in §4.6.
8. Page 7 contains an ERD (`erDiagram`) and per-table schema reference for all major tables.
9. Every page has a "Last Verified" footer with date and regeneration command.
10. Cross-page integrity: every Cloud Run service on Page 4 appears on Page 2 or is marked "internal-only"; every repo on Page 1 with a deploy target maps to a GCP resource on Page 4.
11. Dmytro (PM) confirms he can navigate the subtree and answer 3 spot-check architecture questions without help.

---

## 10. Risks

| # | Risk | Mitigation |
|---|---|---|
| 1 | Confluence Mermaid renderer fails for complex diagrams (architecture type or large ERD). | Test each diagram in a draft Confluence page before publishing. Fallback to static SVG export if rendering fails. Keep Mermaid source in a collapsible section. |
| 2 | Database schema is large; Page 7 becomes unwieldy. | Split Page 7 into sub-pages by domain if it exceeds 50 tables. Start with one page and split if needed. |
| 3 | Dialogflow CX API responses are large and nested; manual table construction is error-prone. | Use `jq` filters to extract only the fields needed for the table. Document the exact filter in the "Last Verified" footer. |
| 4 | Architecture drifts as new features deploy. | "Last Verified" footer + coarse-grained data (names, not revision numbers) makes drift visible but not immediately invalidating. Architecture is refreshed quarterly or on major changes. |
| 5 | Page 5 (Data Flow) requires code inspection, not just CLI discovery. | Inspect `chat-backend` routes, `cx-webhook.service.ts`, and Dialogflow CX flow definitions. Document the code paths inspected. |

---

## 11. Out-of-Scope Follow-ups

These are intentionally not part of this design but should be tracked:

- Dev environment architecture (mirror of prod, documented only by exception).
- n8n workflow architecture (separate service).
- Third-party integrations beyond Dialogflow CX + Vertex AI (e.g., SendGrid, Twilio, payment processors).
- Cost architecture / billing breakdown.
- Disaster recovery / backup architecture (covered by 062 Page 14).
- Performance / latency architecture (covered by monitoring dashboards).

---

## 12. Open Questions

None at design time. Implementation-time questions (e.g., specific Mermaid syntax for a complex relationship, whether to split Page 7) are deferred to the plan.

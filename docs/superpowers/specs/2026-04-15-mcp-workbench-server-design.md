# MCP SSE Workbench Server — Design Document

**Date:** 2026-04-15
**Status:** Approved
**Repo:** `mcp-server` (new, MentalHelpGlobal org)

## Goal

Expose MHG Workbench functionality as MCP tools over SSE transport, enabling Claude Code users (administrators, moderators, developers, AI agents) to perform workbench operations from within the Claude environment without opening a browser.

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Users | Both admins/moderators and developers/agents | General-purpose API bridge |
| Auth | OAuth2 device authorization grant (RFC 8628) | Secure, browser-based login for CLI; no new token types needed |
| Repo | New `mcp-server` — thin proxy, no DB access | Single responsibility; backend API is the only data source |
| Scope | Tiers 1+2 (34 tools), no deanonymization | Covers full daily operational surface |
| Transport | Remote SSE only | Zero local setup for end users |
| Deployment | Separate Cloud Run per environment | Mirrors existing dev/prod topology |
| Framework | MCP SDK + Express.js + TypeScript | Standards-compliant, shares `@mentalhelpglobal/chat-types` |
| Permissions | Dynamic tool registration based on effective permissions | Client only sees tools it can use; zero wasted 403 calls |

## Architecture

```
┌─────────────────┐     SSE      ┌──────────────────────┐    HTTPS    ┌─────────────────────┐
│   Claude Code   │◄────────────►│  MCP SSE Server      │───────────►│  Chat Backend API   │
│   (MCP Client)  │  MCP Protocol│  (Cloud Run)         │  REST/JSON │  (Cloud Run)        │
└─────────────────┘              │                      │            └─────────────────────┘
                                 │  - Express.js        │
                                 │  - @modelcontextprotocol│
                                 │    /sdk SSE transport │
                                 │  - OAuth2 device     │
                                 │    flow middleware    │
                                 │  - Tool definitions  │
                                 │    (Tier 1 + 2)      │
                                 └──────────────────────┘
```

**What it does:**
- Translates MCP tool calls into REST API calls to the chat-backend
- Authenticates users via OAuth2 device flow (browser-based login)
- Dynamically registers tools based on user's effective RBAC permissions
- Handles token refresh, error mapping, and pagination transparently

**What it does NOT do:**
- No direct database access — always proxies through backend API
- No business logic — pure protocol translation
- No frontend UI (except the device auth verification page, hosted on workbench frontend)

## Authentication — OAuth2 Device Authorization Grant

### Flow

```
1. User adds MCP server URL to Claude Code config
2. Claude Code connects to MCP SSE endpoint
3. MCP server detects no valid token → initiates device auth flow

┌─────────────┐         ┌──────────────┐         ┌──────────────┐         ┌─────────┐
│ Claude Code  │         │  MCP Server  │         │ Chat Backend │         │ Browser │
└──────┬───────┘         └──────┬───────┘         └──────┬───────┘         └────┬────┘
       │  SSE connect           │                        │                      │
       │───────────────────────►│                        │                      │
       │                        │  POST /api/auth/device │                      │
       │                        │───────────────────────►│                      │
       │                        │  { device_code,        │                      │
       │                        │    user_code,          │                      │
       │                        │    verification_uri }  │                      │
       │                        │◄───────────────────────│                      │
       │  MCP error: auth       │                        │                      │
       │  required, open URL    │                        │                      │
       │◄───────────────────────│                        │                      │
       │                        │                        │       User opens URL │
       │                        │                        │       enters code    │
       │                        │                        │◄─────────────────────│
       │                        │                        │  OTP/Google login    │
       │                        │                        │◄────────────────────►│
       │                        │                        │  Code confirmed      │
       │                        │  POST /api/auth/       │                      │
       │                        │  device/token (poll)   │                      │
       │                        │───────────────────────►│                      │
       │                        │  { access_token,       │                      │
       │                        │    refresh_token }     │                      │
       │                        │◄───────────────────────│                      │
       │  SSE: connected,       │                        │                      │
       │  tools available       │                        │                      │
       │◄───────────────────────│                        │                      │
```

### New Backend Endpoints

| Endpoint | Purpose |
|----------|---------|
| `POST /api/auth/device` | Initiate device flow — returns `device_code`, `user_code`, `verification_uri`, `expires_in`, `interval` |
| `GET /api/auth/device/verify?code=XXXX` | Browser page where user enters `user_code` and authenticates via existing OTP/Google |
| `POST /api/auth/device/token` | Poll endpoint — MCP server polls with `device_code` until user completes auth. Returns JWT access + refresh tokens |

### Token Lifecycle

- Access token: same JWT as current workbench sessions (short-lived, ~15 min)
- Refresh token: longer-lived, stored in-memory by MCP server per session
- MCP server transparently refreshes via existing `POST /api/auth/refresh` when access token expires
- Device codes expire after 15 minutes if unused
- Device codes are single-use; `user_code` is 6-8 chars for easy entry
- Poll interval enforced server-side (429 if too fast)

## Permission-Aware Tool Discovery

After authentication, the MCP server fetches the user's effective permissions (`GET /api/permissions`) and **dynamically registers only the tools the user has access to**.

```
Auth completes → GET /api/permissions → { permissions: ["REVIEW_ACCESS", ...], role: "Moderator" }

Moderator sees:     review tools, user tools, tag tools
Does NOT see:       supervision, escalation tools (not registered)
```

Each tool declares required permissions:
```typescript
{ name: "submit_review", requiredPermissions: ["REVIEW_ACCESS", "REVIEW_SUBMIT"] }
{ name: "approve_review", requiredPermissions: ["REVIEW_SUPERVISE"] }
```

Claude Code's `tools/list` returns only permitted tools. The LLM literally cannot see or call tools outside its role.

A `whoami` meta-tool is always available — returns current user's email, role, active permissions, and available tool categories.

Belt-and-suspenders: execution still checks permissions. If a 403 comes back mid-session (permissions revoked), the error says: "Permission changed since session started. Reconnect to refresh your available tools."

## Tool Inventory (34 Tools)

### Tier 1 — Core Workflows (20 tools)

#### Review Queue (7 tools)

| Tool | Description | Backend Call |
|------|-------------|-------------|
| `list_review_sessions` | List sessions by tab (pending/flagged/in_progress/completed/excluded/supervision/awaiting) with optional filters (risk, language, date range) and pagination | `GET /api/review` |
| `get_review_session` | Get full session detail — messages, metadata, review history | `GET /api/review/{sessionId}` |
| `submit_review` | Submit review with rating (1-10), comments, tags | `POST /api/review/{reviewId}/submission` |
| `list_elevated_sessions` | List safety-flagged elevated sessions | `GET /api/review?elevated=true` |
| `resolve_safety_flag` | Resolve a safety flag with disposition and notes | `POST /api/risk/flags/{sessionId}/resolve` |
| `list_risk_flags` | List all risk flags | `GET /api/risk/flags` |
| `create_risk_flag` | Manually flag a session for risk | `POST /api/risk/flags/{sessionId}` |

#### User Management (4 tools)

| Tool | Description | Backend Call |
|------|-------------|-------------|
| `list_users` | List users with optional search, role/status filter | `GET /api/users` |
| `get_user_profile` | Get user detail — email, role, status, creation date | `GET /api/users/{id}` |
| `approve_user` | Approve a pending user | `POST /api/approvals` |
| `block_unblock_user` | Toggle user blocked status | `PATCH /api/users/{id}` |

#### Survey Schemas (5 tools)

| Tool | Description | Backend Call |
|------|-------------|-------------|
| `list_survey_schemas` | List schemas with status filter (draft/published/archived) | `GET /api/surveys/schemas` |
| `get_survey_schema` | Get schema detail with questions | `GET /api/surveys/schemas/{id}` |
| `create_survey_schema` | Create new draft schema with title, description, questions | `POST /api/surveys/schemas` |
| `publish_survey_schema` | Publish a draft schema (makes immutable) | `POST /api/surveys/schemas/{id}/publish` |
| `clone_survey_schema` | Clone a schema into a new draft | `POST /api/surveys/schemas/{id}/clone` |

#### Survey Instances (4 tools)

| Tool | Description | Backend Call |
|------|-------------|-------------|
| `list_survey_instances` | List instances with completion stats | `GET /api/surveys/instances` |
| `get_survey_instance` | Get instance detail — groups, dates, response counts | `GET /api/surveys/instances/{id}` |
| `deploy_survey_instance` | Deploy instance — select schema, assign groups, set dates | `POST /api/surveys/instances` |
| `invalidate_survey_responses` | Invalidate responses (instance-wide, per-group, or per-user) | `POST /api/surveys/instances/{id}/invalidate` |

### Tier 2 — Power Features (14 tools)

#### Review Dashboards & Stats (4 tools)

| Tool | Description | Backend Call |
|------|-------------|-------------|
| `get_personal_dashboard` | Reviewer's own stats — reviews completed, avg score, pending | `GET /api/review/dashboard` |
| `get_team_dashboard` | Team-level metrics — reviewer names, completion rates | `GET /api/review/team` |
| `get_review_reports` | Generate/view review reports | `GET /api/review/reports` |
| `list_escalations` | List escalated sessions | `GET /api/review/escalations` |

#### Review Tags (3 tools)

| Tool | Description | Backend Call |
|------|-------------|-------------|
| `list_review_tags` | List all tag definitions | `GET /api/admin/tags` |
| `create_review_tag` | Create new tag | `POST /api/admin/tags` |
| `assign_review_tag` | Assign tag to a session | `POST /api/review/{id}/tags` |

#### Group Management (4 tools)

| Tool | Description | Backend Call |
|------|-------------|-------------|
| `list_groups` | List all groups | `GET /api/groups` |
| `get_group_detail` | Group detail with members | `GET /api/groups/{id}` |
| `get_group_chats` | List chats for a group | `GET /api/groups/{id}/chats` |
| `get_group_surveys` | List survey instances for a group | `GET /api/groups/{id}/surveys` |

#### Supervision (3 tools)

| Tool | Description | Backend Call |
|------|-------------|-------------|
| `list_supervision_queue` | List reviews awaiting supervisor approval | `GET /api/review/supervision/queue` |
| `approve_review` | Supervisor approves a review | `POST /api/review/supervision/{id}/decision` |
| `reject_review` | Supervisor rejects a review with reason | `POST /api/review/supervision/{id}/decision` |

## Server Internals

### Project Structure

```
mcp-server/
├── src/
│   ├── index.ts                  # Entry point — Express app + SSE transport
│   ├── auth/
│   │   ├── device-flow.ts        # OAuth2 device flow orchestration
│   │   ├── token-manager.ts      # JWT storage, refresh, expiry tracking per session
│   │   └── middleware.ts         # Express middleware — validates auth before tool execution
│   ├── api/
│   │   └── client.ts            # HTTP client wrapping calls to chat-backend API
│   ├── tools/
│   │   ├── index.ts             # Tool registry — registers all tools with MCP server
│   │   ├── review.ts            # Review queue tools
│   │   ├── safety.ts            # Safety flag tools
│   │   ├── users.ts             # User management tools
│   │   ├── surveys.ts           # Survey tools (schemas + instances)
│   │   ├── dashboards.ts        # Dashboard/stats tools
│   │   ├── tags.ts              # Review tag tools
│   │   ├── groups.ts            # Group management tools
│   │   └── supervision.ts       # Supervision tools
│   └── types/
│       └── index.ts             # Re-exports from @mentalhelpglobal/chat-types
├── package.json
├── tsconfig.json
├── Dockerfile
├── .github/workflows/deploy.yaml
├── CLAUDE.md
└── README.md
```

### API Client

Single `ApiClient` class:
- Takes `BACKEND_API_URL` from env
- Injects JWT `Authorization` header on every request
- Maps HTTP errors to MCP error codes (401 → auto-refresh + retry, 403 → permission error, 404 → contextual "not found", 5xx → `InternalError`)
- Handles token refresh transparently on 401

### Session-Scoped Auth

The MCP SDK creates a session per SSE connection. Each session has its own `TokenManager` instance holding that user's JWT. Multiple concurrent users each get independent sessions and tokens.

### Environment Config

| Env Var | Example | Purpose |
|---------|---------|---------|
| `BACKEND_API_URL` | `https://api.dev.mentalhelp.chat` | Backend to proxy to |
| `PORT` | `3000` | SSE listen port |
| `DEVICE_AUTH_CALLBACK_URL` | `https://workbench.dev.mentalhelp.chat/auth/device` | Where users complete device auth |

## Deployment

### Cloud Run Services

| Environment | Service Name | Domain | Backend Target |
|-------------|-------------|--------|----------------|
| Dev | `mcp-server-dev` | `mcp.dev.mentalhelp.chat` | `api.dev.mentalhelp.chat` |
| Prod | `mcp-server-prod` | `mcp.mentalhelp.chat` | `api.mentalhelp.chat` |

### Container Spec

- Node.js 20 LTS slim image
- Single Express process, stateless
- Cloud Run: min instances 0 (scale to zero), max 5
- Memory: 256MB
- Concurrency: 80 SSE connections per instance
- Health check: `GET /health`

### CI/CD

- GitHub Actions (inlined workflow)
- Push to `develop` → deploy to dev; push to `main` → deploy to prod
- Steps: lint → type-check → build → docker build → push to Artifact Registry → deploy to Cloud Run
- Auth: existing WIF (`github-actions-sa@`, `repository_owner=='MentalHelpGlobal'`)

### DNS

- Add `mcp.dev.mentalhelp.chat` and `mcp.mentalhelp.chat` A records → existing GCLB IP
- Add URL map rules routing these hosts to respective Cloud Run NEGs

### User Setup

One line in Claude Code MCP config:

```json
{
  "mcpServers": {
    "mhg-workbench": {
      "type": "sse",
      "url": "https://mcp.dev.mentalhelp.chat/sse"
    }
  }
}
```

First use triggers browser-based device auth flow. Subsequent sessions re-authenticate only when refresh token expires.

## Error Handling

| Backend Response | MCP Behavior | User Sees |
|-----------------|--------------|-----------|
| 200/201 | Return structured result | Tool output with data |
| 400 Bad Request | `InvalidParams` error | "Invalid input: {backend message}" |
| 401 Unauthorized | Auto-refresh, retry once. If still 401 → re-trigger device flow | "Session expired. Open URL to re-authenticate: ..." |
| 403 Forbidden | `InvalidRequest` error | "You don't have permission to {action}. Required role: {role}" |
| 404 Not Found | Tool-specific error | "Session abc-123 not found" |
| 409 Conflict | `InvalidRequest` error | "Cannot publish: schema is already published" |
| 429 Rate Limited | Retry with backoff (up to 3 attempts) | Only surfaces if all retries fail |
| 5xx Server Error | `InternalError` | "Workbench backend is temporarily unavailable. Try again." |

### Rate Limiting

Per-session rate limit: 60 tool calls/minute. Prevents runaway agent loops from hammering the backend.

### Pagination

- `list_*` tools return max 25 items per page with `cursor` parameter
- `get_review_session` truncates message history to most recent 100 messages with `has_more` flag

## Security

1. **CORS** — restrictive; MCP SSE connections don't need browser origins
2. **Input validation** — JSON Schema enforced by MCP SDK before any API call
3. **No credential leakage** — JWTs never appear in tool outputs or error messages
4. **Audit trail** — backend logs all API calls with authenticated user; MCP calls flow through the same pipeline
5. **RBAC passthrough** — no permission model in MCP server; backend enforces all RBAC; single source of truth

## Out of Scope

| Excluded | Reason |
|----------|--------|
| Deanonymization tools | Too sensitive for CLI — requires full UI audit trail |
| Security admin tools | Tier 3 — high-risk admin operations stay in UI |
| GDPR export/erasure | Tier 3 — regulatory operations need full audit UI |
| Review configuration | Tier 3 — rarely changed, high impact |
| MCP Resources/Prompts | v2 enhancement |
| Local/stdio transport | Remote SSE only |
| Chat frontend functionality | Workbench only |
| Bulk operations | Individual operations only |
| Real-time notifications | Tools are request/response only in v1 |
| Webhook/event subscriptions | Future enhancement |

## Backend Changes Required

Small, well-scoped — 3 new endpoints for device auth flow:
- `POST /api/auth/device`
- `GET /api/auth/device/verify`
- `POST /api/auth/device/token`

Plus a browser page at `workbench.dev.mentalhelp.chat/auth/device` (small React page in workbench frontend).

All other backend endpoints already exist.

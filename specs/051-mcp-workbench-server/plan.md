# Implementation Plan: MCP Workbench Server

**Branch**: `051-mcp-workbench-server` | **Date**: 2026-04-15 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/051-mcp-workbench-server/spec.md`
**Design**: [design doc](../../docs/superpowers/specs/2026-04-15-mcp-workbench-server-design.md)

## Summary

Build and deploy a remote MCP server that exposes 35 MHG Workbench tools over SSE transport. The server is a stateless thin proxy in a new `mcp-server` repository that translates MCP tool calls into REST API calls to the existing chat-backend. Users authenticate via OAuth2 device authorization grant (browser-based login) with permission-aware tool access (all tools registered at startup; handler-level permission gating per session, since the MCP SDK does not yet support per-session dynamic tool registration). Deployed per-environment on Cloud Run (`mcp.dev.mentalhelp.chat`, `mcp.mentalhelp.chat`).

## Technical Context

**Language/Version**: TypeScript 5.6+ / Node.js 20 LTS
**Primary Dependencies**: `@modelcontextprotocol/sdk`, `express` 5.x, `@mentalhelpglobal/chat-types`
**Storage**: N/A — stateless proxy, no database access
**Testing**: Vitest (unit tests for tool handlers, API client, auth flow); manual integration testing against dev backend
**Target Platform**: Cloud Run (Linux container), accessed via SSE from any MCP client
**Project Type**: Web service (MCP SSE server)
**Performance Goals**: Tool responses < 5s under normal load; 80 concurrent SSE connections
**Constraints**: 256MB memory per Cloud Run instance; stateless (no persistent sessions across restarts)
**Scale/Scope**: ~40 users, 35 MCP tools, 2 environments (dev/prod)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Spec-First Development | PASS | Spec created via `/mhg.specify`, reviewed twice, markers resolved |
| II. Multi-Repository Orchestration | PASS | New `mcp-server` repo + changes in `chat-backend`, `workbench-frontend`. Cross-repo deps documented below |
| III. Test-Aligned Development | PASS | Unit tests via Vitest; regression tests via regression-suite YAML; E2E integration tests against dev |
| IV. Branch and Integration Discipline | PASS | Feature branch `051-mcp-workbench-server` in client-spec; same branch name in target repos |
| V. Privacy and Security First | PASS | No direct PII access; JWT passthrough; no credential leakage (FR-022); audit via backend (FR-024) |
| VI. Accessibility and Internationalization | N/A | Server-side only; no user-facing UI (device auth page in workbench-frontend follows its own a11y/i18n) |
| VI-B. Design System Compliance | N/A | No UI components in this repo |
| VII. Split-Repository First | PASS | New standalone repo; no monorepo work |
| VIII. GCP CLI Infrastructure Management | PASS | Cloud Run provisioning via gcloud scripts in chat-infra; DNS via gcloud |
| IX. Responsive UX and PWA | N/A | No frontend |
| X. Jira Traceability | PASS | Epic MTB-1310 created; tasks/stories will be synced |
| XI. Documentation Standards | PASS | Technical onboarding docs for new repo; user manual update for MCP setup |
| XII. Release Engineering | PASS | Separate deploy workflow; pre-release checklist; health endpoint |

**Gate result: PASS** — no violations.

### FR-003 Spec Deviation: Permission-Aware Tool Discovery

**Spec requirement (FR-003)**: "users never see tools they cannot use"
**SDK limitation**: MCP SDK does not support per-session dynamic tool registration (see [issue #836](https://github.com/modelcontextprotocol/typescript-sdk/issues/836))

**Mitigation**: Implement a custom `tools/list` handler that filters the tool list by the calling session's permissions before returning results. The MCP SDK allows overriding the default `tools/list` response. Each tool handler also checks permissions at execution time (belt-and-suspenders). The `whoami` meta-tool explicitly lists which tool categories the user can access.

**Net effect**: Users see only their permitted tools in `tools/list`. Unauthorized tool calls (if somehow attempted) return a clear permission error. FR-003 is satisfied despite the SDK limitation.

## Cross-Repository Dependencies

This feature spans 4 repositories with a strict execution order:

```
1. chat-types          — Add device auth request/response types (shared)
2. chat-backend        — Add 3 device auth endpoints + permissions API verification
3. workbench-frontend  — Add device auth verification page (/auth/device)
4. mcp-server (NEW)    — MCP SSE server with all 35 tools
5. chat-infra          — Cloud Run provisioning, DNS, load balancer rules
6. chat-ui             — Integration test cases (regression-suite YAML)
```

**Dependency chain:**
- `mcp-server` depends on `chat-backend` device auth endpoints being deployed
- `mcp-server` depends on `chat-types` for shared TypeScript types
- `chat-infra` DNS/LB changes must be deployed before `mcp-server` is accessible
- `workbench-frontend` device auth page must be deployed before users can authenticate

## Project Structure

### Documentation (this feature)

```text
specs/051-mcp-workbench-server/
├── plan.md              # This file
├── research.md          # Phase 0: MCP SDK patterns, device auth, Cloud Run SSE
├── data-model.md        # Phase 1: Entity definitions (sessions, tools, auth)
├── quickstart.md        # Phase 1: Setup guide for developers and end users
├── contracts/
│   ├── device-auth.yaml # Device authorization flow OpenAPI spec
│   └── mcp-tools.yaml   # MCP tool definitions (names, schemas, permissions)
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (new `mcp-server` repository)

```text
mcp-server/
├── src/
│   ├── index.ts                  # Express app + MCP SSE transport setup
│   ├── auth/
│   │   ├── device-flow.ts        # OAuth2 device flow orchestration
│   │   ├── token-manager.ts      # Per-session JWT storage + auto-refresh
│   │   └── middleware.ts         # Auth validation middleware
│   ├── api/
│   │   └── client.ts            # HTTP client wrapping chat-backend API calls
│   ├── middleware/
│   │   ├── rate-limiter.ts      # Per-session rate limiting (default 60/min, configurable)
│   │   └── protocol-version.ts  # MCP protocol version validation
│   ├── tools/
│   │   ├── index.ts             # Tool registry + permission-based registration
│   │   ├── meta.ts              # 1 tool: whoami
│   │   ├── review.ts            # 3 review queue tools (list, get, submit)
│   │   ├── safety.ts            # 4 safety flag tools (list elevated, list flags, create, resolve)
│   │   ├── users.ts             # 4 user management tools
│   │   ├── surveys.ts           # 9 survey tools (5 schemas + 4 instances)
│   │   ├── dashboards.ts        # 4 dashboard/stats tools
│   │   ├── tags.ts              # 3 review tag tools
│   │   ├── groups.ts            # 4 group management tools
│   │   └── supervision.ts       # 3 supervision tools
│   └── types/
│       └── index.ts             # Re-exports from chat-types + MCP-specific types
├── tests/
│   ├── unit/
│   │   ├── auth/                # device-flow, token-manager tests
│   │   ├── api/                 # API client tests (mocked HTTP)
│   │   └── tools/               # Tool handler tests (mocked API client)
│   └── integration/
│       └── smoke.test.ts        # Connects to dev, verifies tool list
├── package.json
├── tsconfig.json
├── vitest.config.ts
├── Dockerfile
├── .github/workflows/deploy.yaml
├── CLAUDE.md
└── README.md
```

### Backend Changes (chat-backend)

```text
chat-backend/
├── src/
│   ├── routes/
│   │   └── auth/
│   │       └── device.ts        # NEW: 3 device auth endpoints
│   ├── services/
│   │   └── device-auth.ts       # NEW: Device code generation, storage, polling
│   └── models/
│       └── device-code.ts       # NEW: Device code entity (in-memory or Redis)
└── tests/
    └── unit/
        └── device-auth.test.ts  # NEW: Device auth flow tests
```

### Frontend Changes (workbench-frontend)

```text
workbench-frontend/
├── src/
│   └── pages/
│       └── auth/
│           └── DeviceVerify.tsx  # NEW: Device auth verification page
└── tests/
    └── unit/
        └── DeviceVerify.test.tsx # NEW: Device verify page tests
```

### Infrastructure Changes (chat-infra)

```text
chat-infra/
├── scripts/
│   ├── deploy-mcp-server.sh     # NEW: Cloud Run deploy script
│   └── setup-mcp-dns.sh         # NEW: DNS + LB routing
└── config/
    └── github-repos.json        # UPDATED: Add mcp-server entry
```

**Structure Decision**: New standalone `mcp-server` repository — thin proxy pattern with Express.js + MCP SDK. Backend and frontend receive small additions (device auth). Infrastructure gets new deploy scripts.

## Implementation Phases

### Phase 0: Research

Research tasks:
1. MCP SDK SSE transport patterns — how to configure `SSEServerTransport` with Express middleware
2. OAuth2 device authorization grant — RFC 8628 implementation patterns for Node.js
3. Cloud Run SSE support — long-lived connection behavior, timeouts, cold start impact
4. Permission-aware dynamic tool registration — MCP SDK API for conditional tool registration
5. Chat-backend existing endpoints — verify all 35 tools have corresponding API endpoints
6. MCP protocol version negotiation — how the SDK handles version mismatches (FR-025)
7. Rate limiting patterns — per-session rate limiting middleware for Express/MCP (FR-007)

Output: `research.md`

### Phase 1: Design

Design tasks:
1. Define data model entities (device codes, MCP sessions, tool registrations)
2. Define device auth API contract (OpenAPI)
3. Define MCP tool schemas (names, inputs, outputs, required permissions)
4. Write quickstart guide (developer setup + end user setup)
5. Update agent context files

Output: `data-model.md`, `contracts/`, `quickstart.md`

### Phase 2: Implementation (via /speckit.tasks)

Implementation order:
1. **chat-types**: Add device auth types
2. **chat-backend**: Implement device auth endpoints
3. **workbench-frontend**: Add device verification page
4. **mcp-server**: Scaffold repo, implement auth, API client, all tools
5. **chat-infra**: Provision Cloud Run, DNS, LB
6. **chat-ui**: Add regression test cases
7. **Integration testing**: End-to-end verification against dev

## Complexity Tracking

No constitution violations — no entries needed.

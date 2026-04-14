# Research: MCP Workbench Server

**Date**: 2026-04-15
**Feature**: 051-mcp-workbench-server

## R1: MCP SDK SSE Transport Patterns

### Decision
Use `@modelcontextprotocol/sdk` with `SSEServerTransport` on Express.js. Register all tools at startup; filter access per-session in tool handlers via permission checks.

### Rationale
The MCP TypeScript SDK provides a well-tested SSE transport that handles protocol framing, session management, and input validation. Dynamic per-session tool registration is not yet supported (see [SDK issue #836](https://github.com/modelcontextprotocol/typescript-sdk/issues/836)), so permission-based filtering must happen at the handler level.

### Key Implementation Patterns

**Server setup:**
```typescript
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { SSEServerTransport } from "@modelcontextprotocol/sdk/server/sse.js";

const server = new McpServer({ name: "mhg-workbench", version: "1.0.0" });
const transports: Record<string, SSEServerTransport> = {};

app.get("/sse", async (req, res) => {
  const transport = new SSEServerTransport("/messages", res);
  transports[transport.sessionId] = transport;
  res.on("close", () => delete transports[transport.sessionId]);
  await server.connect(transport);
});

app.post("/messages", async (req, res) => {
  const sessionId = req.query.sessionId as string;
  const transport = transports[sessionId];
  if (transport) await transport.handlePostMessage(req, res);
  else res.status(400).send("No transport found");
});
```

**Tool registration (with Zod schemas):**
```typescript
server.tool("list_review_sessions", {
  description: "List sessions in the review queue",
  inputSchema: z.object({
    tab: z.enum(["pending", "flagged", "in_progress", ...]),
    cursor: z.string().optional(),
    pageSize: z.number().min(1).max(100).default(25),
  })
}, async (params) => {
  // Permission check + API call + response formatting
});
```

**Error handling:**
- Return `{ content: [...], isError: true }` for domain errors (permission denied, not found)
- Throw `McpError(ErrorCode.InvalidRequest, msg)` for protocol violations
- SDK handles input validation automatically from Zod schemas

### Permission-Aware Tool Discovery — Workaround

Since per-session dynamic registration is not supported, two approaches:

**Approach A (Recommended): Handler-level gating**
- Register all 35 tools at startup
- Each handler checks the session's permissions before executing
- Return `isError: true` with "You don't have permission" for unauthorized calls
- Add a `whoami` tool that returns the user's role, permissions, and which tool categories are accessible

**Approach B: Per-role server instances**
- Create separate `McpServer` instances per role (moderator, supervisor, owner)
- Route SSE connections to the appropriate instance after auth
- More complex to manage, but `tools/list` truly reflects available tools

**Decision:** Start with Approach A for simplicity. Migrate to per-session registration when SDK support lands.

### SSE vs Streamable HTTP

The MCP spec is deprecating SSE in favor of Streamable HTTP transport. However:
- SSE is still widely supported and stable
- Claude Code currently uses SSE for remote MCP servers
- Streamable HTTP can be added later as a non-breaking addition
- Decision: Ship with SSE now, add Streamable HTTP in v2

### Alternatives Considered
- Raw SSE without SDK: Rejected — would need to reimplement JSON-RPC framing, session management, and protocol compliance
- Streamable HTTP only: Rejected — SSE has wider current client support

---

## R2: OAuth2 Device Authorization Grant (RFC 8628)

### Decision
Implement device auth flow from scratch (~200 lines) in chat-backend, reusing existing JWT issuance. Store device codes in Redis with TTL auto-expiry.

### Rationale
No existing npm package implements device flow for Express. The flow is simple enough to build in-house, especially since we already have JWT issuance logic. Redis provides TTL-based auto-expiry and scales horizontally.

### Endpoint Specifications

**1. POST /api/auth/device** (Initiate)
```json
Request: { "client_id": "mcp-server" }
Response: {
  "device_code": "hex(32 bytes)",      // 256-bit entropy, server-side only
  "user_code": "ABCD-EFGH",            // 8 chars, base-20, ~34.5-bit entropy
  "verification_uri": "https://workbench.dev.mentalhelp.chat/auth/device",
  "verification_uri_complete": "https://workbench.dev.mentalhelp.chat/auth/device?user_code=ABCD-EFGH",
  "expires_in": 900,                    // 15 minutes
  "interval": 5                         // Minimum poll interval (seconds)
}
```

**2. GET /api/auth/device/verify?user_code=ABCD-EFGH** (Browser page)
- Renders the workbench-frontend device verification page
- User logs in via existing OTP/Google flow
- On success, marks the device code as authorized with the user's ID

**3. POST /api/auth/device/token** (Poll)
```json
Request: { "grant_type": "device_code", "device_code": "hex..." }
Response (pending): { "error": "authorization_pending" }
Response (slow): { "error": "slow_down" }     // interval += 5s
Response (success): { "access_token": "jwt...", "refresh_token": "jwt..." }
Response (expired): { "error": "expired_token" }
Response (denied): { "error": "access_denied" }
```

### Storage Model (Redis)
```
Key: device_code:{device_code}
Value: { user_code, client_id, user_id, authorized, created_at, expires_at, interval }
TTL: 900 seconds (auto-expire)

Key: user_code:{user_code}  →  device_code  (reverse lookup)
TTL: 900 seconds
```

### Security Rules
- Device code: `crypto.randomBytes(32).toString('hex')` — 256-bit entropy
- User code: 8 characters from base-20 alphabet (BCDFGHJKLMNPQRSTVWXZ) — no vowels to avoid forming words
- Rate limit: max 5 failed user_code attempts per device_code; lock on exceed
- Brute force: 34.5-bit user code entropy + rate limiting = adequate for 15-min window
- Single-use: device code is consumed on token issuance; cannot be reused
- Verification_uri_complete: embed user_code in URL for one-click auth (no manual code entry needed)

### Alternatives Considered
- node-oauth2-server: Supports extension grants but doesn't include device flow; adds unnecessary abstraction
- Storing codes in PostgreSQL: Works but Redis TTL is simpler for ephemeral data

---

## R3: Cloud Run SSE Support

### Decision
Deploy on Cloud Run with 60-minute request timeout, concurrency 80, graceful SIGTERM handling. Min instances: 0 for dev, 1 for prod.

### Rationale
Cloud Run fully supports SSE since October 2020. The 60-minute timeout covers typical work sessions. Scale-to-zero minimizes cost when unused.

### Configuration Values

| Setting | Dev | Prod | Notes |
|---------|-----|------|-------|
| Request timeout | 3600s (60 min) | 3600s (60 min) | Max allowed; covers work sessions |
| Min instances | 0 | 1 | Prod stays warm to avoid cold starts |
| Max instances | 3 | 5 | ~40 users, 80 connections/instance |
| Concurrency | 80 | 80 | Each SSE = 1 concurrency slot |
| Memory | 256Mi | 256Mi | Proxy workload, minimal memory |
| CPU | 1 | 1 | Sufficient for request proxying |
| CPU throttling | false | false | Needed for SSE keep-alive and SIGTERM handling |

### Gotchas
1. **SIGTERM handling**: Cloud Run sends SIGTERM on redeploy with 10s grace (configurable to 60s). App must close SSE connections gracefully. Set termination grace period to 30s.
2. **Active connections prevent scale-to-zero**: Expected behavior. Idle connections eventually time out at 60 min.
3. **No sticky sessions**: Each SSE reconnection may hit a different instance. Session state (JWT tokens) must be re-established per connection.
4. **Cold start**: ~2-3s for Node.js container. Acceptable since auth flow takes longer anyway.
5. **CPU throttling**: Must set `--no-cpu-throttling` to keep the event loop running for SSE keep-alive pings between requests.

### Alternatives Considered
- Cloud Run with WebSocket: More complex, SSE is sufficient for request/response tools
- GKE: Overkill for a small stateless service; Cloud Run is simpler and cheaper

---

## R4: Backend API Endpoint Coverage

### Decision
30 of 35 tool endpoints are confirmed in existing API contracts. 5 endpoints need verification against chat-backend source code during implementation.

### Confirmed Endpoints (30/35)

All review queue (7/7), survey schemas (5/5), survey instances (4/4), dashboards (4/4), tags (3/3), and supervision (3/3) endpoints are confirmed via OpenAPI contracts.

### Needs Verification (5/35)

| Tool | Expected Endpoint | Status | Notes |
|------|-------------------|--------|-------|
| `approve_user` | POST /api/approvals | UNCONFIRMED | No contract found; may be POST /api/admin/users/{id}/approve |
| `list_groups` | GET /api/groups | UNCONFIRMED | Only per-group configs found; may be GET /api/admin/groups |
| `get_group_chats` | GET /api/groups/{id}/chats | UNCONFIRMED | Group-based instances referenced but no dedicated endpoint |
| `get_group_surveys` | GET /api/groups/{id}/surveys | UNCONFIRMED | May use survey instance filter by groupId instead |
| `whoami` | GET /api/permissions | UNCONFIRMED | Permission checks exist but no explicit GET contract |

### Mitigation
- **AT RISK**: These 5 endpoints are committed in the MCP tools contract (mcp-tools.yaml) with assumed paths. If the actual backend differs, the contract and API client mappings will need revision.
- **Phase 2, Task 1**: Before implementing tool handlers, verify these 5 endpoints against chat-backend source code. If endpoints don't exist, add them as small additions to chat-backend (same feature branch).
- This is low-risk: these are simple read endpoints; the backend data model already supports the queries.

### Endpoint Naming Discrepancies
Some spec contracts use slightly different paths than assumed:
- Review sessions: `/review/sessions/{sessionId}` not `/review/{sessionId}`
- Survey schemas: `/workbench/survey-schemas` not `/surveys/schemas`
- Risk flags: `/escalations` for listing, `/sessions/{sessionId}/flags` for creation

These will be mapped in the API client layer (the MCP server's `api/client.ts`).

---

## R5: Design Decision Summary

| Decision | Choice | Key Factor |
|----------|--------|------------|
| MCP SDK | @modelcontextprotocol/sdk | Protocol compliance, input validation, session management |
| SSE Transport | SSEServerTransport | Current standard; Streamable HTTP in v2 |
| Permission filtering | Handler-level gating (Approach A) | SDK doesn't support per-session registration yet |
| Device auth storage | Redis with TTL | Auto-expiry, horizontal scaling, existing infra |
| Device auth library | Custom (~200 lines) | No npm package covers device flow for Express |
| Cloud Run timeout | 60 minutes | Covers typical work sessions |
| Cloud Run concurrency | 80 | Matches expected user count |
| Min instances | 0 (dev) / 1 (prod) | Cost optimization vs cold start avoidance |

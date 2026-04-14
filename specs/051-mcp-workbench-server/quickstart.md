# Quickstart: MCP Workbench Server

**Feature**: 051-mcp-workbench-server

## For End Users (Using the MCP Server)

### Prerequisites
- Claude Code (or any MCP-compatible client)
- An active MHG Workbench account with an assigned role
- Browser access (for one-time device authentication)

### Setup (30 seconds)

1. Add the MCP server to your Claude Code config. Edit `~/.claude.json` (or project `.mcp.json`):

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

For production, use `https://mcp.mentalhelp.chat/sse` instead.

2. Start Claude Code. The first time you use a workbench tool, you'll see:

```
MHG Workbench requires authentication.
Open this URL to sign in:
https://workbench.dev.mentalhelp.chat/auth/device?user_code=ABCD-EFGH
```

3. Open the URL in your browser, log in with your normal credentials (OTP or Google), and you're done. Claude Code will confirm:

```
Authenticated as tarasb@mentalhelp.global (Owner)
35 tools available. Type "whoami" to see your permissions.
```

### First Commands to Try

```
"What's in my review queue?"          → calls list_review_sessions
"Show me my review stats"             → calls get_personal_dashboard
"Who am I and what can I do?"         → calls whoami
"List all pending user approvals"     → calls list_users with status=pending
"Show me draft survey schemas"        → calls list_survey_schemas with status=draft
```

### Re-authentication
Your session stays active as long as the SSE connection is open. If your session expires (after extended inactivity), you'll be prompted to re-authenticate — just open the URL again.

---

## For Developers (Building/Modifying the MCP Server)

### Prerequisites
- Node.js 20 LTS
- npm 10+
- Access to the MentalHelpGlobal GitHub org
- Docker (for local container builds)

### Local Development

```bash
# Clone the repository
git clone git@github.com:MentalHelpGlobal/mcp-server.git
cd mcp-server

# Install dependencies
npm install

# Set environment variables
cp .env.example .env
# Edit .env:
#   BACKEND_API_URL=https://api.dev.mentalhelp.chat
#   PORT=3000
#   DEVICE_AUTH_CALLBACK_URL=https://workbench.dev.mentalhelp.chat/auth/device

# Run in development mode
npm run dev

# The SSE endpoint is now at http://localhost:3000/sse
```

### Running Tests

```bash
# Unit tests
npm test

# Unit tests with coverage
npm run test:coverage

# Integration smoke test (requires dev backend access)
npm run test:integration
```

### Project Structure

```
src/
├── index.ts              # Express app + SSE transport
├── auth/                 # Device flow, token management, middleware
├── api/client.ts         # HTTP client for chat-backend
├── tools/                # Tool definitions (one file per domain)
│   ├── index.ts          # Registry — registers all tools
│   ├── review.ts         # list_review_sessions, get_review_session, submit_review
│   ├── safety.ts         # list_elevated_sessions, list_risk_flags, create/resolve
│   ├── users.ts          # list_users, get_user_profile, approve, block/unblock
│   ├── surveys.ts        # schema + instance tools
│   ├── dashboards.ts     # personal, team, reports, escalations
│   ├── tags.ts           # list, create, assign tags
│   ├── groups.ts         # list, detail, chats, surveys
│   └── supervision.ts    # queue, approve, reject
└── types/                # Type re-exports + MCP-specific types
```

### Adding a New Tool

1. Identify the backend API endpoint and required permission(s)
2. Add the tool definition to the appropriate domain file in `src/tools/`
3. Add the tool to `contracts/mcp-tools.yaml` in client-spec
4. Add unit test in `tests/unit/tools/`
5. Test against dev backend

Example tool:
```typescript
// In src/tools/review.ts
server.tool("list_review_sessions", {
  description: "List sessions in the review queue by tab with optional filters",
  inputSchema: z.object({
    tab: z.enum(["pending", "flagged", "in_progress", "completed", "excluded", "supervision", "awaiting"]),
    riskLevel: z.enum(["high", "medium", "low"]).optional(),
    language: z.string().optional(),
    cursor: z.string().optional(),
    pageSize: z.number().min(1).max(100).default(25),
  })
}, async (params, context) => {
  const { session } = getSessionContext(context);
  assertPermissions(session, ["REVIEW_ACCESS"]);
  
  const result = await apiClient.get("/review/sessions", {
    params: { tab: params.tab, riskLevel: params.riskLevel, /* ... */ },
    token: session.accessToken,
  });
  
  return {
    content: [{ type: "text", text: JSON.stringify(result, null, 2) }]
  };
});
```

### Deployment

Deployment is automated via GitHub Actions:
- Push to `develop` → deploys to `mcp-server-dev` (mcp.dev.mentalhelp.chat)
- Push to `main` → deploys to `mcp-server-prod` (mcp.mentalhelp.chat)

Manual deploy (with permission):
```bash
# Build container
docker build -t mcp-server .

# Deploy to dev
gcloud run deploy mcp-server-dev \
  --image gcr.io/mental-help-global-25/mcp-server \
  --region us-central1 \
  --set-env-vars BACKEND_API_URL=https://api.dev.mentalhelp.chat \
  --set-env-vars DEVICE_AUTH_CALLBACK_URL=https://workbench.dev.mentalhelp.chat/auth/device \
  --min-instances 0 \
  --max-instances 3 \
  --concurrency 80 \
  --timeout 3600 \
  --no-cpu-throttling \
  --memory 256Mi
```

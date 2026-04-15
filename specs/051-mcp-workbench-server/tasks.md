# Tasks: MCP Workbench Server

**Input**: Design documents from `/specs/051-mcp-workbench-server/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure) — MTB-1311 / MTB-1324

**Purpose**: Create the new `mcp-server` repository and establish shared types

- [x] T001 Create `mcp-server` GitHub repository under MentalHelpGlobal org with branch protection on `develop` and `main`
- [x] T002 Initialize `mcp-server` Node.js project with TypeScript 5.6+, Express 5.x, `@modelcontextprotocol/sdk`, `vitest`, and `@mentalhelpglobal/chat-types` in mcp-server/package.json
- [x] T003 [P] Configure TypeScript compiler with strict mode in mcp-server/tsconfig.json
- [x] T004 [P] Configure Vitest for unit and integration testing in mcp-server/vitest.config.ts
- [x] T005 [P] Create Dockerfile for Node.js 20 LTS slim image with Express entrypoint in mcp-server/Dockerfile
- [x] T006 [P] Create CLAUDE.md with project-specific guidance in mcp-server/CLAUDE.md
- [x] T007 Add device auth shared types (DeviceAuthorizationResponse, DeviceTokenRequest, DeviceTokenResponse, DeviceTokenError) to chat-types/src/auth/device.ts
- [x] T008 Publish updated `@mentalhelpglobal/chat-types` package with device auth types

**Checkpoint**: Repository created, dependencies installed, shared types published

---

## Phase 2: Foundational (Blocking Prerequisites) — MTB-1312 / MTB-1325..MTB-1327

**Purpose**: Backend device auth endpoints + MCP server core infrastructure. MUST complete before any user story tool implementation.

### Backend Device Auth (chat-backend) — MTB-1325

- [x] T009 Create device code model with Redis storage (device_code, user_code, userId, authorized, expiresAt, pollInterval, failedAttempts) in chat-backend/src/models/device-code.ts
- [x] T010 Implement device auth service with code generation (256-bit device code, 8-char base-20 user code), Redis TTL storage, polling logic, and rate limiting in chat-backend/src/services/device-auth.ts
- [x] T011 Implement POST /api/auth/device endpoint (initiate device flow) per contracts/device-auth.yaml in chat-backend/src/routes/auth/device.ts
- [x] T012 Implement POST /api/auth/device/token endpoint (poll for token) with authorization_pending/slow_down/expired_token/access_denied responses in chat-backend/src/routes/auth/device.ts
- [x] T013 Implement POST /api/auth/device/verify endpoint (submit verification after user authenticates) in chat-backend/src/routes/auth/device.ts
- [x] T014 [P] Write unit tests for device auth service (code generation, expiry, polling, lockout after 5 failed attempts) in chat-backend/tests/unit/device-auth.test.ts
- [x] T015 [P] Write unit tests for device auth routes (initiate, poll, verify endpoints) in chat-backend/tests/unit/device-auth-routes.test.ts

### Frontend Device Verification Page (workbench-frontend) — MTB-1326

- [x] T016 Create DeviceVerify page component at /auth/device route — pre-fills user_code from URL query param, shows login form (OTP/Google), on auth success calls POST /api/auth/device/verify in workbench-frontend/src/pages/auth/DeviceVerify.tsx
- [x] T017 [P] Add /auth/device route to workbench-frontend router configuration
- [x] T018 [P] Write unit test for DeviceVerify page (renders code, submits verification, shows success message) in workbench-frontend/tests/unit/DeviceVerify.test.tsx

### MCP Server Core (mcp-server) — MTB-1327

- [x] T019 Create Express app with health endpoint (GET /health) and environment config loading (BACKEND_API_URL, PORT, DEVICE_AUTH_CALLBACK_URL) in mcp-server/src/index.ts
- [x] T020 Implement MCP SSE transport setup — create McpServer instance, bind SSEServerTransport to GET /sse and POST /messages routes, manage transport session map in mcp-server/src/index.ts
- [x] T021 Implement API client class with JWT injection, auto-refresh on 401, and HTTP-to-MCP error mapping (400→InvalidParams, 403→permission error, 404→contextual, 429→retry, 5xx→InternalError) in mcp-server/src/api/client.ts
- [x] T022 Implement device flow orchestration — initiate flow via backend, return verification URL to client, poll for token, create authenticated session in mcp-server/src/auth/device-flow.ts
- [x] T023 Implement token manager — per-session JWT storage, expiry tracking, transparent refresh via POST /api/auth/refresh, re-auth prompt on refresh failure in mcp-server/src/auth/token-manager.ts
- [x] T024 Implement auth middleware — validate session has active token before tool execution, trigger device flow for unauthenticated sessions in mcp-server/src/auth/middleware.ts
- [x] T025 Implement per-session rate limiter middleware (default 60 invocations/minute, configurable via RATE_LIMIT_PER_MINUTE env var) in mcp-server/src/middleware/rate-limiter.ts
- [x] T026 [P] Implement MCP protocol version validation middleware in mcp-server/src/middleware/protocol-version.ts
- [x] T027 Implement tool registry with permission-based filtering — register all tools at startup, override tools/list to filter by session permissions, provide assertPermissions helper for handler-level gating in mcp-server/src/tools/index.ts
- [x] T028 Create MCP-specific TypeScript types (McpSession, ToolInvocationContext, ToolDefinition) re-exporting from chat-types in mcp-server/src/types/index.ts
- [x] T029 Implement SIGTERM graceful shutdown — close all SSE connections, flush state, exit cleanly within 30s in mcp-server/src/index.ts

**Checkpoint**: Backend device auth deployed, frontend verification page deployed, MCP server connects and authenticates. No tools yet but auth + SSE transport works end-to-end.

---

## Phase 3: User Story 1 — Authenticate and Discover Available Tools (Priority: P1) MVP — MTB-1313 / MTB-1328

**Goal**: Users connect from Claude Code, authenticate via browser, and discover role-scoped tools

**Independent Test**: Configure Claude Code to connect to MCP server, complete device auth, verify `tools/list` returns only permitted tools for the authenticated role

### Implementation for User Story 1

- [x] T030 [US1] Implement `whoami` meta tool — returns email, role, permissions, available tool categories, permissionsLoadedAt in mcp-server/src/tools/meta.ts
- [x] T031 [US1] Implement permission fetching on auth complete — call GET /api/permissions, store effective permissions in McpSession, use for tools/list filtering in mcp-server/src/auth/middleware.ts
- [x] T032 [US1] Write unit tests for whoami tool (returns correct session data) and permission-filtered tools/list (moderator sees only moderator tools, owner sees all) in mcp-server/tests/unit/tools/meta.test.ts
- [x] T033 [US1] Write unit tests for device flow orchestration (initiate, poll pending, poll success, poll expired, re-auth on token expiry) in mcp-server/tests/unit/auth/device-flow.test.ts
- [x] T034 [US1] Write unit tests for token manager (storage, expiry detection, auto-refresh, refresh failure → re-auth) in mcp-server/tests/unit/auth/token-manager.test.ts

**Checkpoint**: US1 complete — user can authenticate and see their role-scoped tool list. This is the MVP gate.

---

## Phase 4: User Story 2 — Review Chat Sessions (Priority: P1) — MTB-1314 / MTB-1329

**Goal**: Reviewers browse pending sessions, read messages, submit reviews, manage safety flags

**Independent Test**: Authenticate as reviewer, list pending sessions, open one, read messages, submit review with rating+comment, verify completion

### Implementation for User Story 2

- [x] T035 [P] [US2] Implement `list_review_sessions` tool — paginated list by tab (pending/flagged/in_progress/completed/excluded/supervision/awaiting) with risk, language, date filters in mcp-server/src/tools/review.ts
- [x] T036 [P] [US2] Implement `get_review_session` tool — full session detail with paginated messages (messageCursor, messagePageSize), metadata, review history in mcp-server/src/tools/review.ts
- [x] T037 [US2] Implement `submit_review` tool — submit rating (1-10), comment, optional tagIds in mcp-server/src/tools/review.ts
- [x] T038 [P] [US2] Implement `list_elevated_sessions` tool — list safety-flagged sessions in mcp-server/src/tools/safety.ts
- [x] T039 [P] [US2] Implement `list_risk_flags` tool — list all risk flags with pagination in mcp-server/src/tools/safety.ts
- [x] T040 [P] [US2] Implement `create_risk_flag` tool — manually flag a session with severity and reason in mcp-server/src/tools/safety.ts
- [x] T041 [US2] Implement `resolve_safety_flag` tool — resolve flag with disposition and notes in mcp-server/src/tools/safety.ts
- [x] T042 [US2] Write unit tests for review tools (list sessions, get session with message pagination, submit review) with mocked API client in mcp-server/tests/unit/tools/review.test.ts
- [x] T043 [P] [US2] Write unit tests for safety tools (list elevated, list flags, create flag, resolve flag) with mocked API client in mcp-server/tests/unit/tools/safety.test.ts

**Checkpoint**: US2 complete — reviewers can do their full daily review workflow from Claude Code

---

## Phase 5: User Story 3 — Manage Users (Priority: P2) — MTB-1315 / MTB-1330

**Goal**: Admins search users, view profiles, approve pending registrations, block/unblock

**Independent Test**: Authenticate as admin, search users by email, view profile, approve a pending user

### Implementation for User Story 3

- [x] T044 [P] [US3] Implement `list_users` tool — paginated list with search (name/email), role filter, status filter in mcp-server/src/tools/users.ts
- [x] T045 [P] [US3] Implement `get_user_profile` tool — user detail (email, role, status, creation date, group memberships) in mcp-server/src/tools/users.ts
- [x] T046 [US3] Implement `approve_user` tool — approve pending user by userId in mcp-server/src/tools/users.ts
- [x] T047 [US3] Implement `block_unblock_user` tool — toggle blocked status by userId in mcp-server/src/tools/users.ts
- [x] T048 [US3] Write unit tests for user tools (list with filters, get profile, approve, block/unblock) with mocked API client in mcp-server/tests/unit/tools/users.test.ts

**Checkpoint**: US3 complete — admins can manage user lifecycle from Claude Code

---

## Phase 6: User Story 4 — Manage Surveys (Priority: P2) — MTB-1316 / MTB-1331

**Goal**: Researchers/admins create schemas, publish, deploy instances, monitor completion, invalidate responses

**Independent Test**: Create draft schema with questions, publish it, deploy instance to group with dates, check completion stats

### Implementation for User Story 4

- [x] T049 [P] [US4] Implement `list_survey_schemas` tool — paginated list with status filter (draft/published/archived) in mcp-server/src/tools/surveys.ts
- [x] T050 [P] [US4] Implement `get_survey_schema` tool — schema detail with all questions in mcp-server/src/tools/surveys.ts
- [x] T051 [US4] Implement `create_survey_schema` tool — create draft with title, description, questions (free_text/single_choice/multi_choice/boolean) in mcp-server/src/tools/surveys.ts
- [x] T052 [US4] Implement `publish_survey_schema` tool — publish draft (makes immutable) in mcp-server/src/tools/surveys.ts
- [x] T053 [P] [US4] Implement `clone_survey_schema` tool — clone into new draft in mcp-server/src/tools/surveys.ts
- [x] T054 [P] [US4] Implement `list_survey_instances` tool — paginated list with completion stats in mcp-server/src/tools/surveys.ts
- [x] T055 [US4] Implement `get_survey_instance` tool — instance detail (groups, dates, response counts) in mcp-server/src/tools/surveys.ts
- [x] T056 [US4] Implement `deploy_survey_instance` tool — deploy with schemaId, groupIds, startDate, expirationDate in mcp-server/src/tools/surveys.ts
- [x] T057 [US4] Implement `invalidate_survey_responses` tool — invalidate by scope (instance/group/user) in mcp-server/src/tools/surveys.ts
- [x] T058 [US4] Write unit tests for survey tools (list/get/create/publish/clone schemas, list/get/deploy/invalidate instances) with mocked API client in mcp-server/tests/unit/tools/surveys.test.ts

**Checkpoint**: US4 complete — full survey lifecycle manageable from Claude Code

---

## Phase 7: User Story 5 — Review Dashboards and Team Stats (Priority: P3) — MTB-1317 / MTB-1332

**Goal**: Reviewers/supervisors check personal stats, team metrics, reports, escalations

**Independent Test**: Authenticate as reviewer, request personal dashboard, verify stats include review count, avg score, pending count

### Implementation for User Story 5

- [x] T059 [P] [US5] Implement `get_personal_dashboard` tool — reviews completed, avg score, pending count in mcp-server/src/tools/dashboards.ts
- [x] T060 [P] [US5] Implement `get_team_dashboard` tool — per-reviewer completion rates (requires REVIEW_SUPERVISE) in mcp-server/src/tools/dashboards.ts
- [x] T061 [P] [US5] Implement `get_review_reports` tool — available reports with summary data in mcp-server/src/tools/dashboards.ts
- [x] T062 [US5] Implement `list_escalations` tool — escalated sessions requiring supervisor attention in mcp-server/src/tools/dashboards.ts
- [x] T063 [US5] Write unit tests for dashboard tools (personal stats, team stats, reports, escalations) with mocked API client in mcp-server/tests/unit/tools/dashboards.test.ts

**Checkpoint**: US5 complete — read-only dashboard access from Claude Code

---

## Phase 8: User Story 6 — Manage Groups (Priority: P3) — MTB-1318 / MTB-1333

**Goal**: Admins browse groups, view members, check group-specific chats and surveys

**Independent Test**: List groups, view a group's member list, check group-specific survey instances

### Implementation for User Story 6

- [x] T064 [P] [US6] Implement `list_groups` tool — all groups with member counts in mcp-server/src/tools/groups.ts
- [x] T065 [P] [US6] Implement `get_group_detail` tool — group detail with member list in mcp-server/src/tools/groups.ts
- [x] T066 [US6] Implement `get_group_chats` tool — paginated chat sessions for a group in mcp-server/src/tools/groups.ts
- [x] T067 [US6] Implement `get_group_surveys` tool — survey instances deployed to a group in mcp-server/src/tools/groups.ts
- [x] T068 [US6] Write unit tests for group tools (list, detail, chats, surveys) with mocked API client in mcp-server/tests/unit/tools/groups.test.ts

**Checkpoint**: US6 complete — group oversight from Claude Code

---

## Phase 9: User Story 7 — Supervise Reviews (Priority: P3) — MTB-1319 / MTB-1334

**Goal**: Supervisors approve/reject completed reviews from their queue

**Independent Test**: Authenticate as supervisor, list supervision queue, approve and reject a review

### Implementation for User Story 7

- [x] T069 [P] [US7] Implement `list_supervision_queue` tool — paginated reviews awaiting supervisor decision in mcp-server/src/tools/supervision.ts
- [x] T070 [US7] Implement `approve_review` tool — supervisor approves with optional comment in mcp-server/src/tools/supervision.ts
- [x] T071 [US7] Implement `reject_review` tool — supervisor rejects with required reason in mcp-server/src/tools/supervision.ts
- [x] T072 [US7] Write unit tests for supervision tools (list queue, approve, reject) with mocked API client in mcp-server/tests/unit/tools/supervision.test.ts

**Checkpoint**: US7 complete — supervision workflow from Claude Code

---

## Phase 10: User Story 8 — Manage Review Tags (Priority: P3) — MTB-1320 / MTB-1335

**Goal**: Admins create tags, reviewers assign tags to sessions

**Independent Test**: Create a tag, list tags, assign tag to a session

### Implementation for User Story 8

- [x] T073 [P] [US8] Implement `list_review_tags` tool — all tag definitions in mcp-server/src/tools/tags.ts
- [x] T074 [US8] Implement `create_review_tag` tool — create tag with name and description in mcp-server/src/tools/tags.ts
- [x] T075 [US8] Implement `assign_review_tag` tool — assign tag to session by sessionId and tagId in mcp-server/src/tools/tags.ts
- [x] T076 [US8] Write unit tests for tag tools (list, create, assign) with mocked API client in mcp-server/tests/unit/tools/tags.test.ts

**Checkpoint**: US8 complete — review tagging from Claude Code

---

## Phase 11: User Story 9 — Session Introspection (Priority: P1) — MTB-1321 / MTB-1336

**Goal**: Any user can query their identity, role, and capabilities

**Note**: The `whoami` tool was already implemented in Phase 3 (T030). This phase adds the integration smoke test that validates it end-to-end.

- [x] T077 [US9] Write integration smoke test — connect to dev MCP server, authenticate, call whoami, verify response includes email/role/permissions/toolCategories in mcp-server/tests/integration/smoke.test.ts

**Checkpoint**: US9 complete — session introspection verified end-to-end

---

## Phase 12: Infrastructure & Deployment — MTB-1322 / MTB-1337, MTB-1338

**Purpose**: Deploy the MCP server and configure networking

### Infrastructure (chat-infra)

- [x] T078 Create Cloud Run deploy script for mcp-server-dev (region, env vars, concurrency 80, timeout 3600s, no-cpu-throttling, memory 256Mi, min-instances 0, max-instances 3) in chat-infra/scripts/deploy-mcp-server.sh
- [x] T079 Create DNS + load balancer setup script — add mcp.dev.mentalhelp.chat and mcp.mentalhelp.chat A records pointing to GCLB IP, add URL map rules in chat-infra/scripts/setup-mcp-dns.sh
- [x] T080 [P] Update github-repos.json to add mcp-server with has_deployments: true and dev/prod environments in chat-infra/config/github-repos.json
- [x] T081 [P] Run setup-github.sh to provision GitHub environments, secrets, and variables for mcp-server repo

### CI/CD (mcp-server)

- [x] T082 Create GitHub Actions deploy workflow — lint → type-check → test → docker build → push to Artifact Registry → deploy to Cloud Run (develop→dev, main→prod) with existing WIF auth in mcp-server/.github/workflows/deploy.yaml

### Deploy & Verify

- [x] T083 Deploy chat-backend with device auth endpoints to dev environment via workflow_dispatch
- [x] T084 Deploy workbench-frontend with device verification page to dev environment via workflow_dispatch
- [x] T085 Deploy mcp-server-dev to Cloud Run and verify SSE endpoint is accessible at https://mcp.dev.mentalhelp.chat/sse
- [x] T086 Run end-to-end verification — connect Claude Code to mcp.dev.mentalhelp.chat, authenticate via device flow, call whoami, list review sessions, submit a test review

**Checkpoint**: MCP server deployed and accessible on dev environment. Full auth + tool execution verified.

---

## Phase 13: Polish & Cross-Cutting Concerns — MTB-1323 / MTB-1339

**Purpose**: Regression tests, documentation, and final hardening

- [x] T087 [P] Add MCP server regression test cases to regression-suite (auth flow, tool discovery, review tools, survey tools, permission gating) in regression-suite/17-mcp-server.yaml
- [x] T088 [P] Update Technical Onboarding docs in Confluence with MCP server architecture, repo setup, and developer guide
- [x] T089 [P] Write unit tests for API client (JWT injection, auto-refresh on 401, error mapping for 400/403/404/429/5xx) in mcp-server/tests/unit/api/client.test.ts
- [x] T090 [P] Write unit tests for rate limiter (60/min default, configurable, per-session isolation) in mcp-server/tests/unit/middleware/rate-limiter.test.ts
- [x] T091 Verify all 5 at-risk backend endpoints against chat-backend source code (approve_user, list_groups, get_group_chats, get_group_surveys, whoami/permissions) — update API client mappings if paths differ
- [x] T092 Run full regression suite (smoke mode) against dev environment to verify no regressions in existing workbench functionality

**Checkpoint**: All tools implemented, tested, deployed, documented. Feature complete.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — can start immediately
- **Phase 2 (Foundational)**: Depends on Phase 1 completion — BLOCKS all user stories
- **Phases 3-11 (User Stories)**: All depend on Phase 2 completion
  - US1 (Phase 3): Must complete first — provides auth + tool discovery
  - US2-US9 (Phases 4-11): Can proceed in parallel after US1, or sequentially
  - US9 (Phase 11): Integration smoke test depends on deployment (Phase 12)
- **Phase 12 (Infrastructure)**: Backend + frontend tasks (T083-T084) depend on Phase 2. MCP server deploy (T085) depends on tool implementation. Can overlap with later user story phases.
- **Phase 13 (Polish)**: Depends on all user stories and deployment being complete

### User Story Dependencies

- **US1** (Auth + Discovery): BLOCKS all other stories — must complete first
- **US2** (Review): Independent after US1
- **US3** (Users): Independent after US1
- **US4** (Surveys): Independent after US1
- **US5** (Dashboards): Independent after US1
- **US6** (Groups): Independent after US1
- **US7** (Supervision): Independent after US1
- **US8** (Tags): Independent after US1
- **US9** (Introspection): `whoami` already in US1; integration test depends on deployment

### Parallel Opportunities

Within Phase 2:
- T014 + T015 (backend tests) can run in parallel
- T016 + T017 + T018 (frontend) can run in parallel with backend work
- T025 + T026 + T028 (middleware, types) can run in parallel

After US1 completes, US2-US8 can all run in parallel:
```
US2 (review+safety)  ──┐
US3 (users)          ──┤
US4 (surveys)        ──┤── all in parallel after US1
US5 (dashboards)     ──┤
US6 (groups)         ──┤
US7 (supervision)    ──┤
US8 (tags)           ──┘
```

Within each user story, [P]-marked tool implementations can run in parallel.

---

## Implementation Strategy

### MVP First (US1 Only)

1. Complete Phase 1: Setup (repo, types)
2. Complete Phase 2: Foundational (device auth, MCP core)
3. Complete Phase 3: US1 — Auth + Tool Discovery
4. **STOP and VALIDATE**: Connect from Claude Code, authenticate, verify `whoami` works
5. Deploy to dev — this is the MVP

### Incremental Delivery

1. Setup + Foundational → MCP server scaffold ready
2. US1 (Auth) → Authenticate and discover tools → **MVP Deploy**
3. US2 (Review) → Most valuable daily workflow → **Deploy**
4. US3+US4 (Users+Surveys) → Admin operations → **Deploy**
5. US5-US8 (Dashboards, Groups, Supervision, Tags) → Power features → **Deploy**
6. Infrastructure + Polish → Full production readiness

### Task Summary

| Phase | Story | Tasks | Parallel |
|-------|-------|-------|----------|
| 1. Setup | — | 8 | 4 |
| 2. Foundational | — | 21 | 6 |
| 3. US1 Auth | P1 | 5 | 0 |
| 4. US2 Review | P1 | 9 | 5 |
| 5. US3 Users | P2 | 5 | 2 |
| 6. US4 Surveys | P2 | 10 | 4 |
| 7. US5 Dashboards | P3 | 5 | 3 |
| 8. US6 Groups | P3 | 5 | 2 |
| 9. US7 Supervision | P3 | 4 | 1 |
| 10. US8 Tags | P3 | 4 | 1 |
| 11. US9 Introspection | P1 | 1 | 0 |
| 12. Infrastructure | — | 9 | 2 |
| 13. Polish | — | 6 | 4 |
| **Total** | | **92** | **34** |

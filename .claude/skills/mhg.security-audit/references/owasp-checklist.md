# OWASP Security Checklist — MHG Solution

## Sources
- OWASP Top 10 2021: https://owasp.org/Top10/
- OWASP API Security Top 10 2023: https://owasp.org/API-Security/
- OWASP ASVS v4.0 Level 1: https://owasp.org/www-project-application-security-verification-standard/

---

## Application Layer (OWASP Top 10, 2021)

### A01:2021 — Broken Access Control

MHG checks:
- [ ] All `/api/review/*` routes require `isReviewer` or `isAdmin` middleware
- [ ] All `/api/admin/*` routes require `isAdmin` middleware
- [ ] `GET /api/chat/sessions/:id` validates `session.userId === req.user.id`
- [ ] `PATCH /api/chat/sessions/:id` validates ownership before update
- [ ] Workbench routes enforce `spaceId` / group ownership
- [ ] No route allows horizontal privilege escalation (user A accessing user B's data)

Code locations to inspect:
- `chat-backend/src/middleware/auth.ts` (or equivalent)
- `chat-backend/src/routes/` — every route handler with `:id` param

### A02:2021 — Cryptographic Failures

MHG checks:
- [ ] JWT signing uses HS256 or RS256 (not algorithm `none`)
- [ ] No plaintext passwords, tokens, or keys in any config or source file
- [ ] HTTPS enforced at GCLB level (HTTP requests redirect to HTTPS)
- [ ] PostgreSQL connection uses SSL (`sslmode=require` or `sslmode=verify-full`)
- [ ] Session tokens are not stored in localStorage (only httpOnly cookies or memory)
- [ ] No sensitive data (PII, tokens) logged at INFO level or below

Code locations to inspect:
- `chat-backend/src/` — grep for `algorithm: 'none'`, `jwt.sign`, `sslmode`
- `.env.example` — verify secret names exist (not values)
- Cloud Run environment config (Phase 5 cross-reference)

### A03:2021 — Injection

MHG checks:
- [ ] No raw SQL string concatenation: `"SELECT * FROM users WHERE id = " + userId`
- [ ] ORM (Prisma) used for all database queries — parameterized by default
- [ ] No unsanitized user input passed to `exec()`, `spawn()`, or `eval()`
- [ ] Email/OTP inputs validated before use (format check, not just type check)
- [ ] No template literal injection in queries

Code locations to inspect:
- `chat-backend/src/` — grep for `${}` inside SQL strings, `exec(`, `eval(`
- `chat-backend/src/` — grep for `prisma.$queryRaw` (raw queries need special review)

### A04:2021 — Insecure Design

MHG checks:
- [ ] Rate limiting on `POST /api/auth/login` (OTP request) — max N requests per email per window
- [ ] Rate limiting on `POST /api/auth/verify` (OTP verification) — max N attempts
- [ ] OTP codes have a defined TTL (e.g., 10 minutes) enforced server-side
- [ ] Session tokens have a defined expiry enforced server-side
- [ ] No business logic bypass: survey gate checked server-side, not just client-side

Code locations to inspect:
- `chat-backend/src/routes/auth.ts` (or equivalent)
- `chat-backend/src/` — grep for rate limit middleware registration on auth routes

### A05:2021 — Security Misconfiguration

MHG checks:
- [ ] CORS `Access-Control-Allow-Origin` is not `*` on the API
- [ ] CORS origin list does not reflect arbitrary origins
- [ ] `Content-Security-Policy` header present on API responses
- [ ] `X-Content-Type-Options: nosniff` header present
- [ ] `X-Frame-Options: DENY` or `SAMEORIGIN` header present
- [ ] `Referrer-Policy` header present
- [ ] `Strict-Transport-Security` header present (HSTS)
- [ ] No debug endpoints (`/debug`, `/test`, `/swagger`) exposed in production
- [ ] Cloud Run environment variables: dev secrets not mixed into prod service

Code locations to inspect:
- `chat-backend/src/app.ts` or main entry — check helmet/cors middleware config
- Cloud Run service config (Phase 5 cross-reference)
- Live header check via Phase 4 curl

### A06:2021 — Vulnerable and Outdated Components

MHG checks:
- [ ] No `critical` npm advisories from Phase 1
- [ ] No `high` npm advisories from Phase 1 (or documented exception with timeline)
- [ ] Security-critical packages (jwt, bcrypt, passport) have pinned versions (not `^` / `~`)
- [ ] Node.js runtime version is current LTS (not EOL)
- [ ] Docker base image is not using a deprecated or EOL tag

Code locations to inspect:
- `package.json` in each repo — check version specifiers on security-critical deps
- Cloud Run service config for runtime version

### A07:2021 — Identification and Authentication Failures

MHG checks:
- [ ] OTP codes are single-use (invalidated after first successful verify)
- [ ] OTP codes expire after TTL (not just single-use)
- [ ] Refresh tokens are rotated on use (old token invalidated)
- [ ] Session invalidated on explicit sign-out (token revocation or blacklisting)
- [ ] Failed OTP attempts are counted and locked after threshold
- [ ] No account enumeration via different error messages for valid vs. invalid email

Code locations to inspect:
- `chat-backend/src/routes/auth.ts` — OTP issue and verify flow
- `chat-backend/src/` — grep for refresh token rotation logic

### A08:2021 — Software and Data Integrity Failures

MHG checks:
- [ ] GHA `actions/checkout` pinned to SHA or tagged version (not `@main` / `@master`)
- [ ] All third-party GHA actions pinned to SHA or tagged version
- [ ] No `--no-verify` in workflow steps or commit hook scripts
- [ ] CI pipeline cannot be modified by a PR without review (no self-approval of workflow changes)
- [ ] npm packages installed with `npm ci` (not `npm install`) in CI for lockfile enforcement

Code locations to inspect:
- `.github/workflows/*.yml` in all repos
- `package-lock.json` presence in each repo

### A09:2021 — Security Logging and Monitoring Failures

MHG checks:
- [ ] Authentication events (login, logout, failed attempts) are logged
- [ ] Admin actions are logged with actor identity
- [ ] Logs do not include plaintext OTPs, JWTs, or passwords
- [ ] Logs do not include PII beyond what's necessary (user ID OK, email in error logs flagged)
- [ ] Cloud Run logging is enabled (not disabled for cost-saving)
- [ ] Log retention policy exists (not indefinite, not < 30 days)

Code locations to inspect:
- `chat-backend/src/` — grep for `console.log`, `logger.info` near auth flows
- Cloud Run service config logging settings

### A10:2021 — Server-Side Request Forgery (SSRF)

MHG checks:
- [ ] No endpoint accepts a user-controlled URL and fetches it server-side
- [ ] Webhook or callback URL configuration is admin-only (not user-controlled)
- [ ] CX agent definition URLs (if user-configurable) are validated against allowlist
- [ ] External API calls (Dialogflow, GCP) use hardcoded or config-managed URLs, not user input

Code locations to inspect:
- `chat-backend/src/` — grep for `fetch(`, `axios.get(`, `http.get(` with variable URLs
- Webhook handler routes

---

## API Layer (OWASP API Security Top 10, 2023)

### API01:2023 — Broken Object Level Authorization

MHG checks:
- [ ] `GET /api/chat/sessions/:id` — verifies `session.userId === req.user.id`
- [ ] `GET /api/chat/sessions/:id/conversation` — verifies session ownership
- [ ] `PATCH /api/chat/survey-responses/:id` — verifies ownership before update
- [ ] `GET /api/review/sessions/:id` — verifies reviewer or admin permission
- [ ] `PATCH /api/review/sessions/:id` — verifies reviewer or admin permission
- [ ] No object IDs are sequential integers (prefer UUIDs to prevent enumeration)

Code locations to inspect:
- `chat-backend/src/routes/chat.ts`
- `chat-backend/src/routes/review.ts`

### API02:2023 — Broken Authentication

MHG checks:
- [ ] Every protected route validates Bearer token in `Authorization` header
- [ ] Missing or malformed `Authorization` header returns 401 (not 500)
- [ ] Expired token returns 401 with `WWW-Authenticate` header (not 500)
- [ ] Token signature validation failure returns 401 (not 200 or 500)
- [ ] No route bypasses auth middleware for convenience

Code locations to inspect:
- `chat-backend/src/middleware/auth.ts` — verify applied to all non-public routers
- `chat-backend/src/app.ts` — check route registration order (middleware before routes)

### API03:2023 — Broken Object Property Level Authorization

MHG checks:
- [ ] `PATCH /api/chat/sessions/:id` only accepts whitelisted fields
- [ ] No mass assignment: `Object.assign(session, req.body)` pattern absent
- [ ] `PATCH /api/review/sessions/:id` only accepts whitelisted review fields
- [ ] Prisma `update` calls use explicit field mapping (not spreading req.body)
- [ ] Response objects don't include internal fields (DB IDs, admin flags, tokens)

Code locations to inspect:
- All PATCH/PUT route handlers in `chat-backend/src/routes/`
- Prisma update call sites — check for `data: req.body` spread

### API04:2023 — Unrestricted Resource Consumption

MHG checks:
- [ ] Chat message creation endpoint has rate limiting
- [ ] All list endpoints (`GET /api/chat/sessions`, `GET /api/review/sessions`) have pagination
- [ ] Pagination has a max `limit` enforced server-side (e.g., max 100)
- [ ] No unbounded `findMany()` without `take` / pagination parameters
- [ ] File upload endpoints (if any) have size limits

Code locations to inspect:
- `chat-backend/src/routes/` — grep for `findMany(` without `take:`
- Chat message route — check rate limit middleware

### API05:2023 — Broken Function Level Authorization

MHG checks:
- [ ] `POST /api/admin/*` routes require `isAdmin` on every handler
- [ ] Survey schema publish requires admin role check
- [ ] Reviewer assignment endpoints require admin role
- [ ] No privilege escalation: user cannot promote themselves to reviewer/admin via API
- [ ] Role checks happen in middleware or at the start of handler (not buried in logic)

Code locations to inspect:
- `chat-backend/src/routes/admin.ts`
- Survey schema management routes

### API06:2023 — Unrestricted Access to Sensitive Business Flows

MHG checks:
- [ ] Survey gate: `POST /api/chat/sessions` enforces survey completion server-side
- [ ] Cannot create a chat session by direct API call without passing survey gate
- [ ] Survey response submission cannot be repeated to manipulate scoring
- [ ] Review flow: reviewer cannot approve their own submitted sessions

Code locations to inspect:
- `chat-backend/src/routes/chat.ts` — session creation handler
- Survey gate middleware or service

### API07:2023 — Server-Side Request Forgery (API-focused)

MHG checks:
- [ ] CX agent definition URLs are not sourced from API request bodies
- [ ] Any URL used in server-side fetch is from config or database (not user request)
- [ ] Dialogflow webhook URLs are hardcoded in config, not user-supplied

(Cross-reference: A10:2021 above)

### API08:2023 — Security Misconfiguration

MHG checks:
- [ ] OPTIONS preflight handled correctly (no CORS errors on legitimate requests)
- [ ] Error responses use generic messages (not stack traces, not internal paths)
- [ ] 500 errors return `{ error: "Internal server error" }`, not full Express error
- [ ] No debug/verbose mode enabled in production Cloud Run environment
- [ ] API versioning present (all routes under `/api/v1/` or at minimum `/api/`)

Code locations to inspect:
- `chat-backend/src/app.ts` — error handler middleware (must be last)
- Live error test via Phase 4

### API09:2023 — Improper Inventory Management

MHG checks:
- [ ] All routes registered in Express are documented in `contracts/api.md` (or equivalent)
- [ ] No test or debug routes remain in production code
- [ ] Workbench API routes do not expose chat-user-only data unexpectedly
- [ ] gcloud run services list shows no unexpected services running

Code locations to inspect:
- `chat-backend/src/app.ts` or router index — list all registered routes
- Cross-reference with OpenAPI/contracts spec if it exists

### API10:2023 — Unsafe Consumption of APIs

MHG checks:
- [ ] Dialogflow API responses are validated before use (not blindly trusted)
- [ ] GCP service responses are checked for expected shape before parsing
- [ ] Third-party API errors are caught and don't propagate raw to client
- [ ] No eval or dynamic code execution on third-party API response data

Code locations to inspect:
- `chat-backend/src/` — grep for Dialogflow client, GCP SDK usage
- Error handling wrappers around external API calls

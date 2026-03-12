# Research: Security Hardening — Audit Findings Remediation

**Date**: 2026-03-12 | **Source**: Security Audit 2026-03-12 + implementation research

---

## Decision 1 — Helmet middleware for Express 5

**Decision**: Use `helmet@^8.1.0` with custom CSP for the API-only backend.

**Rationale**: Helmet 8.1.0 has zero dependencies and no Express version peer constraint — fully compatible with `express@^5.1.0`. Default `helmet()` sets 13 headers including HSTS, X-Frame-Options, X-Content-Type-Options, Referrer-Policy, and removes X-Powered-By automatically. The default CSP (`default-src 'self'`) is designed for browser apps; for an API-only backend use `useDefaults: false` + `defaultSrc: ["'none'"]`.

**Implementation snippet** (insert after `dotenv.config()`, before `cors()`):
```typescript
import helmet from 'helmet';
app.use(helmet({
  contentSecurityPolicy: { useDefaults: false, directives: { defaultSrc: ["'none'"] } },
}));
```

**Install**: `npm install helmet` in `chat-backend` (types bundled in package).

**Alternatives considered**: Manual `res.setHeader()` per route — rejected (fragile, easy to miss).

---

## Decision 2 — npm audit fix strategy

**Decision**: Run `npm audit fix` (non-breaking patches only). Do NOT use `--force` for the vite-plugin-pwa chain.

### chat-backend — `npm audit fix` resolves:
- `fast-xml-parser` CRITICAL → patched to 4.5.4+
- `tar` HIGH → patched to 7.5.10+
- `rollup` HIGH → patched to 4.59.0+
- `@mapbox/node-pre-gyp` HIGH → resolved via tar patch

Do NOT force-downgrade `@google-cloud/dialogflow-cx` or `@google-cloud/storage` — those `--force` fixes are major downgrades that break functionality.

### chat-frontend — `npm audit fix` resolves:
- `@remix-run/router` HIGH (GHSA-2w69-qvjg-hvjx) → 1.23.2+
- `react-router` / `react-router-dom` HIGH → via router bump
- `minimatch` HIGH → patched
- `rollup` HIGH → patched

**vite-plugin-pwa chain** (serialize-javascript, workbox-build, @rollup/plugin-terser): The suggested `--force` fix downgrades v1.2.0 → v0.19.8 (major regression, backwards-incompatible API). Current vite config uses only stable, cross-version features — but the PWA test risk on a major downgrade is unacceptable. **Accept as known risk** pending upstream vite-plugin-pwa v1.3.0+ fix. Track as LOW carry-forward.

### workbench-frontend — same strategy as chat-frontend.

---

## Decision 3 — CORS 500 fix

**Decision**: Change `callback(new Error('Not allowed by CORS'))` → `callback(null, false)` in the CORS origin function (`chat-backend/src/index.ts:100`).

**Rationale**: `callback(null, false)` silently rejects the origin — no CORS headers added, browser blocks request, no 500 thrown. This is the canonical Express cors package pattern for denying origins.

---

## Decision 4 — JSON 404 and error handlers

**Decision**: Add a catch-all 404 JSON handler and global error handler as the last two middleware in `index.ts`, after all route registrations.

```typescript
app.use((_req, res) => {
  res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Endpoint not found' } });
});
app.use((err: Error, _req: Request, res: Response, _next: NextFunction) => {
  console.error('[Error]', err.message);
  res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: 'Internal server error' } });
});
```

---

## Decision 5 — Branch protection

**Decision**: Enable branch protection on `develop` for `chat-backend`, `chat-frontend`, `workbench-frontend` via `gh api PUT`.

```bash
gh api repos/MentalHelpGlobal/<repo>/branches/develop/protection \
  --method PUT \
  --input - <<'EOF'
{
  "required_status_checks": { "strict": false, "contexts": [] },
  "enforce_admins": false,
  "required_pull_request_reviews": { "required_approving_review_count": 1 },
  "restrictions": null
}
EOF
```

---

## Decision 6 — GCP IAM least-privilege

**Decision**: Remove `roles/owner` from both over-permissioned SAs. Confirm scoped roles replace it.

### Default Compute SA (`942889188964-compute@developer.gserviceaccount.com`)
Currently has `roles/owner` PLUS 4 scoped roles (aiplatform.user, cloudsql.client, dialogflow.client, secretmanager.secretAccessor) — used by `devagent1` GCE instance. Action: remove `roles/owner` only; 4 scoped roles remain and cover actual usage.

### ai-devops SA (`ai-devops@mental-help-global-25.iam.gserviceaccount.com`)
Currently has ONLY `roles/owner`. Used via WIF from GitHub Actions for Cloud Run deployments. Minimum required scoped roles: `artifactregistry.writer`, `run.admin`, `storage.objectAdmin`, `secretmanager.secretAccessor`, `iam.serviceAccountUser`, `cloudsql.client`.

**Note**: `ai-devops` and `github-actions-sa` may overlap. Confirm which SA is bound to the GitHub OIDC WIF before the change to avoid breaking CI/CD.

---

## Decision 7 — Prod OTP devCode verification

**Decision**: Read prod Cloud Run service `chat-backend` env vars; confirm `EMAIL_PROVIDER != console`. Dev behaviour is intentional — no code change to the dev Cloud Run service.

---

## Carry-Forward (Out of Scope for this cycle)

| Item | Reason deferred |
|------|----------------|
| vite-plugin-pwa HIGH advisories | Awaiting upstream fix; --force downgrade breaks PWA |
| Cloud SQL private IP | Infrastructure investment, separate cycle |
| GHA SHA pinning | Maintenance task, separate cycle |
| n8n access restriction | Separate service, not chat platform |

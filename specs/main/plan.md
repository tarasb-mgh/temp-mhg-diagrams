# Implementation Plan: Security Hardening — Audit Findings Remediation

**Branch**: `main` | **Date**: 2026-03-12 | **Spec**: `specs/main/spec.md`
**Input**: Security Audit 2026-03-12 ([Confluence](https://mentalhelpglobal.atlassian.net/wiki/spaces/UD/pages/21463041))

## Summary

Address all CRITICAL, HIGH, and MEDIUM findings from the 2026-03-12 security audit across six workstreams:
1. npm dependency CVE patches (`npm audit fix`) in chat-backend, chat-frontend, workbench-frontend
2. Helmet security headers middleware in chat-backend
3. CORS 500→silent-reject fix and JSON 404/error handlers in chat-backend
4. GitHub branch protection on `develop` in 3 repos
5. GCP IAM — remove `roles/owner` from 2 service accounts, add scoped roles
6. Prod Cloud Run — verify `EMAIL_PROVIDER != console`

No new API contracts or data models introduced. All changes are hardening/configuration.

## Technical Context

**Language/Version**: TypeScript (Node.js) — chat-backend (`express@^5.1.0`, `jsonwebtoken@^9.0.2`)
**Primary Dependencies added**: `helmet@^8.1.0` (chat-backend only)
**Storage**: PostgreSQL (unchanged)
**Testing**: Vitest (existing); smoke test via curl after deploy
**Target Platform**: Cloud Run (europe-west1), GitHub Actions CI
**Project Type**: Multi-repo backend security patch + infra config
**Performance Goals**: No new performance requirements; helmet adds <1ms overhead
**Constraints**: Must not break existing auth flow, CORS for valid origins, or PWA behaviour
**Scale/Scope**: 3 frontend repos, 1 backend repo, GCP project-level IAM, 3 GitHub repos

## Constitution Check

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Spec-First | ✅ | spec.md created in specs/main/ |
| II. Multi-Repo | ✅ | Targets chat-backend, chat-frontend, workbench-frontend, chat-infra |
| III. Test-Aligned | ✅ | Existing Vitest; smoke tests via curl in evidence/ |
| IV. Branch Discipline | ✅ | Feature branches in affected repos; PRs to develop |
| V. Privacy/Security | ✅ | This feature IS the security work |
| VI. Accessibility/i18n | N/A | No UI changes |
| VII. Split-Repo First | ✅ | All changes in split repos |
| VIII. GCP CLI | ✅ | IAM changes scripted as gcloud commands in chat-infra |
| IX. Responsive/PWA | ✅ | npm audit fix non-breaking; vite-plugin-pwa chain deferred |
| X. Jira Traceability | ⚠️ | Create Epic + Tasks in Jira before implementing |
| XI. Docs | N/A | Security hardening — no user-facing docs required |
| XII. Release Engineering | ✅ | Dev deploy + smoke checks before release; owner approval for prod |

**Gate**: Passes. No violations requiring justification.

## Project Structure

### Documentation

```
specs/main/
├── plan.md         ← this file
├── research.md     ← Phase 0 complete
├── spec.md         ← requirements
└── tasks.md        ← Phase 2 output (next step: /speckit.tasks)
```

### Source Changes

```
chat-backend/
├── package.json                     ← add helmet; npm audit fix
├── src/index.ts                     ← add helmet middleware, fix CORS callback, add 404/error handlers

chat-frontend/
├── package.json                     ← npm audit fix (non-breaking only)

workbench-frontend/
├── package.json                     ← npm audit fix (non-breaking only)

chat-infra/
└── scripts/
    └── security-hardening-2026-03-12.sh   ← IAM gcloud commands (idempotent)
```

---

## Phase 0 Research — Complete

See `research.md` for all decisions. Summary:
- Helmet: `helmet@^8.1.0`, API-only CSP config, insert before cors()
- npm audit: `npm audit fix` only — no --force; vite-plugin-pwa chain deferred
- CORS: change error callback to `callback(null, false)`
- 404: add catch-all JSON handler + global error handler
- Branch protection: `gh api PUT` with required reviews
- IAM: remove `roles/owner`; add scoped roles; confirm WIF SA binding first
- Prod email: read env vars; no code change if already non-console

---

## Phase 1 Design

### US1 — Dependency CVEs (npm audit fix)

**Affected repos**: chat-backend, chat-frontend, workbench-frontend

**chat-backend** — run in `D:\src\MHG\chat-backend`:
```bash
npm audit fix
# Resolves: fast-xml-parser CRITICAL, tar HIGH, rollup HIGH, @mapbox/node-pre-gyp HIGH
# Does NOT use --force (no @google-cloud/* downgrade)
npm audit --json | node -e "..." # verify 0 critical/high remain (google-cloud LOW residuals acceptable)
```

**chat-frontend** — run in `D:\src\MHG\chat-frontend`:
```bash
npm audit fix
# Resolves: @remix-run/router HIGH, react-router HIGH, react-router-dom HIGH, minimatch HIGH, rollup HIGH
# vite-plugin-pwa chain (serialize-javascript HIGH) — DEFERRED, no --force
```

**workbench-frontend** — run in `D:\src\MHG\workbench-frontend`:
```bash
npm audit fix
# Resolves: minimatch HIGH, rollup HIGH
# vite-plugin-pwa chain — DEFERRED
```

**Verification**: `npm audit` shows 0 critical, 0 high (excluding vite-plugin-pwa residuals, which are documented as deferred).

---

### US2 — Security Headers (helmet)

**Affected repo**: chat-backend

**File**: `chat-backend/src/index.ts`

1. Install: `npm install helmet` in chat-backend
2. Add import: `import helmet from 'helmet';`
3. Insert middleware after `dotenv.config()`, before `cors()`:

```typescript
app.use(helmet({
  contentSecurityPolicy: {
    useDefaults: false,
    directives: { defaultSrc: ["'none'"] },
  },
}));
```

**Expected headers on all responses after change**:
- `Strict-Transport-Security: max-age=31536000; includeSubDomains`
- `X-Frame-Options: SAMEORIGIN`
- `X-Content-Type-Options: nosniff`
- `Referrer-Policy: no-referrer`
- `Content-Security-Policy: default-src 'none'`
- `X-Powered-By` header: **absent**

**Verification**: `curl -si https://api.dev.mentalhelp.chat/api/settings` (after deploy) — all 5 headers present, X-Powered-By absent.

---

### US3 — CORS fix and JSON error handlers

**Affected repo**: chat-backend

**File**: `chat-backend/src/index.ts`

**Change 1 — CORS silent reject** (line ~100):
```typescript
// Before:
callback(new Error('Not allowed by CORS'));
// After:
callback(null, false);
```

**Change 2 — JSON 404 handler** (after all app.use() route registrations, before startServer()):
```typescript
app.use((_req: Request, res: Response) => {
  res.status(404).json({
    success: false,
    error: { code: 'NOT_FOUND', message: 'Endpoint not found' },
  });
});
```

**Change 3 — Global error handler** (after 404 handler):
```typescript
app.use((err: Error, _req: Request, res: Response, _next: NextFunction) => {
  console.error('[Error]', err.message);
  res.status(500).json({
    success: false,
    error: { code: 'INTERNAL_ERROR', message: 'Internal server error' },
  });
});
```

**Verification**:
- `curl -H "Origin: https://evil.example.com" -si https://api.dev.mentalhelp.chat/api/settings` → no 500, no `Access-Control-Allow-Origin` header
- `curl -si https://api.dev.mentalhelp.chat/api/nonexistent` → 404 with `{"success":false,"error":{"code":"NOT_FOUND",...}}`

---

### US4 — Branch Protection

**Affected repos**: chat-backend, chat-frontend, workbench-frontend (GitHub only, no source changes)

For each repo:
```bash
gh api repos/MentalHelpGlobal/chat-backend/branches/develop/protection \
  --method PUT \
  --input - <<'EOF'
{
  "required_status_checks": { "strict": false, "contexts": [] },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": false,
    "require_code_owner_reviews": false
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF
```

(Repeat for chat-frontend and workbench-frontend.)

**Verification**: `gh api repos/MentalHelpGlobal/chat-backend/branches/develop/protection` returns 200 with `required_pull_request_reviews.required_approving_review_count: 1`.

---

### US5 — GCP IAM Least-Privilege

**Affected**: GCP project `mental-help-global-25` IAM (not a source code change — scripted in chat-infra)

**Script**: `chat-infra/scripts/security-hardening-2026-03-12.sh`

```bash
#!/usr/bin/env bash
# Security hardening — IAM least-privilege remediation
# 2026-03-12 — Audit finding A05:2021
set -euo pipefail
PROJECT=mental-help-global-25

# ── Compute SA: remove roles/owner (scoped roles remain) ──
gcloud projects remove-iam-policy-binding $PROJECT \
  --member="serviceAccount:942889188964-compute@developer.gserviceaccount.com" \
  --role="roles/owner" \
  --project=$PROJECT

# ── ai-devops SA: remove roles/owner ──
gcloud projects remove-iam-policy-binding $PROJECT \
  --member="serviceAccount:ai-devops@mental-help-global-25.iam.gserviceaccount.com" \
  --role="roles/owner" \
  --project=$PROJECT

# ── ai-devops SA: add minimum scoped roles ──
DEVOPS_SA="serviceAccount:ai-devops@mental-help-global-25.iam.gserviceaccount.com"
for ROLE in \
  roles/artifactregistry.writer \
  roles/run.admin \
  roles/storage.objectAdmin \
  roles/secretmanager.secretAccessor \
  roles/iam.serviceAccountUser \
  roles/cloudsql.client; do
  gcloud projects add-iam-policy-binding $PROJECT \
    --member="$DEVOPS_SA" \
    --role="$ROLE" \
    --project=$PROJECT
done

echo "IAM hardening complete. Verify with:"
echo "  gcloud projects get-iam-policy $PROJECT | grep -A5 'roles/owner'"
```

**Pre-condition**: Confirm which WIF binding uses `ai-devops` vs `github-actions-sa` before running. Check:
```bash
gcloud iam service-accounts get-iam-policy ai-devops@mental-help-global-25.iam.gserviceaccount.com \
  --project=mental-help-global-25
```
If no `roles/iam.workloadIdentityUser` binding exists, `ai-devops` may not be the active CI/CD SA — use `github-actions-sa` as reference and verify before removing owner.

**Verification**: After running script, `gcloud projects get-iam-policy mental-help-global-25` shows no `roles/owner` for either SA.

---

### US6 — Prod OTP devCode Verification

**Affected**: Cloud Run service `chat-backend` (prod, europe-west1)

**Check**:
```bash
gcloud run services describe chat-backend --region=europe-west1 \
  --project=mental-help-global-25 \
  --format="yaml(spec.template.spec.containers[0].env)"
```

Look for `EMAIL_PROVIDER` env var. If `console` → update to `gmail` or remove:
```bash
gcloud run services update chat-backend --region=europe-west1 \
  --project=mental-help-global-25 \
  --update-env-vars EMAIL_PROVIDER=gmail
```

**Expected**: `EMAIL_PROVIDER` is `gmail` or not set in the prod service.

---

## Cross-Repository Dependencies

| Change | Repos affected | Order |
|--------|---------------|-------|
| npm audit fix | chat-backend, chat-frontend, workbench-frontend | Parallel |
| helmet + CORS + 404 | chat-backend | After npm audit fix in backend |
| Branch protection | GitHub API (3 repos) | Independent, any order |
| IAM hardening | GCP project IAM | Independent |
| Prod email verify | Cloud Run chat-backend | Independent |

All changes can be done in parallel across repos. The helmet/CORS/404 changes should be batched into a single PR for chat-backend.

## Complexity Tracking

No constitution violations.

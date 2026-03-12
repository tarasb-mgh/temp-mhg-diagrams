---
name: mhg.security-audit
description: >
  Use when the user asks to "run the security audit", "audit the solution",
  "check for vulnerabilities", "run a security sweep", "check OWASP compliance",
  "scan for security issues", or "run the security checklist".
  Performs a structured, OWASP-referenced security audit across all MHG repos,
  APIs, and infrastructure. Read-only — reports findings, does not auto-remediate.
version: 1.0.0
---

# mhg.security-audit

## Overview

Structured security audit across the MHG solution. Every finding maps to an authoritative,
versioned security standard (OWASP Top 10 2021, OWASP API Security Top 10 2023, OWASP ASVS Level 1)
so findings are unambiguous, comparable across audit runs, and actionable with industry-standard
remediation guidance.

**Read-only**: no auto-remediation. Produces a severity-ranked report with OWASP category tags.

---

## Key Rules

- **Read-only**: Never modify code, config, or infrastructure during audit
- **OWASP-tagged**: Every finding must cite an OWASP reference (Top 10, API Top 10, or ASVS)
- **Sequential phases**: Do not skip phases; each informs the next
- **Evidence required**: Include command output, code snippets, or config excerpts per finding
- **No false positives**: If a check cannot be verified, mark as INFO (needs manual review)
- **Scope-limited**: Only audit repos and endpoints in `references/audit-scope.md`
- **Idempotent publish**: Search for existing Confluence page before creating; update if exists
- **Secrets never logged**: curl outputs that might include tokens are truncated; no plaintext credentials in report

---

## Pipeline

```
Phase 1: Dependency & Known CVE Scan          (npm audit on all repos)
         ↓
Phase 2: OWASP Top 10 — Application Layer     (A01–A10, 2021 — static code analysis)
         ↓
Phase 3: OWASP API Security Top 10            (API01–API10, 2023 — static code analysis)
         ↓
Phase 4: Live Endpoint Verification           (curl checks against dev API)
         ↓
Phase 5: Infrastructure & Secrets Audit       (GCP IAM, Secret Manager, Cloud Run)
         ↓
Phase 6: Repository & CI/CD Security          (branch protection, secret scanning, workflow perms)
         ↓
Phase 7: Report Generation + Confluence       (severity-ranked report, publish to Confluence)
```

---

## Phase 1 — Dependency & Known CVE Scan

**Before starting**: Load `references/audit-scope.md` for repo paths.

- Run `npm audit --json` in each repo: `chat-backend`, `chat-frontend`, `workbench-frontend`, `chat-types`
- Parse output: flag `critical` / `high` severity advisories; `moderate` noted but not blocking
- Record each finding: CVE ID, affected package, installed version, fix version

**Produces**: CVE finding list with CVE IDs, affected package, fix version

---

## Phase 2 — OWASP Top 10 Application Layer (2021)

**Before starting**: Load `references/owasp-checklist.md` — work through Application Layer section.

Per-category static code analysis on `chat-backend` source:

- **A01 Broken Access Control**: Check auth middleware coverage on all backend routes; verify
  admin-only endpoints require `isAdmin`; check workbench routes have ownership checks
- **A02 Cryptographic Failures**: Check that JWTs use HS256/RS256; check no secrets in
  plaintext in `.env` or config files; verify HTTPS enforced (check GCLB/Cloud Run settings)
- **A03 Injection**: Grep backend for raw SQL string concatenation; verify ORM usage (Prisma/pg);
  check for unsanitized user input passed to shell commands or `eval`
- **A04 Insecure Design**: Review rate limiting on `/api/auth/verify` and `/api/auth/login`
  (OTP brute-force prevention); check session TTL and expiry logic
- **A05 Security Misconfiguration**: Check CORS headers, CSP headers, X-Frame-Options,
  Referrer-Policy in backend responses; check Cloud Run environment variables for dev/prod mixing
- **A06 Vulnerable Components**: Cross-reference npm audit from Phase 1; check for pinned
  dependency versions (no `^` / `~` on security-critical packages)
- **A07 Auth & Identity Failures**: Verify OTP codes expire (TTL check in backend); verify
  refresh token rotation; check session invalidation on sign-out
- **A08 Software & Data Integrity Failures**: Check GHA workflow integrity (pinned action
  versions vs. `@main`/`@master`); check `--no-verify` bypass policies
- **A09 Logging & Monitoring Failures**: Check Cloud Run logging for PII masking; verify error
  logs don't include plaintext tokens; verify audit log exists for admin actions
- **A10 SSRF**: Check backend for user-controlled URL fetch patterns; check any webhook
  or external API call that uses request-provided URLs

---

## Phase 3 — OWASP API Security Top 10 (2023)

**Before starting**: Continue from `references/owasp-checklist.md` — API Layer section.

Per-category static code analysis:

- **API01 Broken Object Level Auth**: Verify all `GET/PATCH /api/chat/sessions/:id` check
  ownership by `userId`; verify `GET /api/review/sessions/:id` checks reviewer permission
- **API02 Broken Authentication**: Check that Bearer token validation is on every protected
  route; check for missing `Authorization` header handling (returns 401 not 500)
- **API03 Broken Object Property Level Auth**: Check PATCH/PUT endpoints only accept
  whitelisted fields (no mass assignment); verify Prisma `select` or explicit DTO mapping
- **API04 Unrestricted Resource Consumption**: Check rate limits on chat message endpoint;
  check pagination enforced on list endpoints (no unbounded `findAll`)
- **API05 Broken Function Level Auth**: Check admin-only operations (`POST /api/admin/*`,
  survey schema publish) have role guard; check no privilege escalation via parameter tampering
- **API06 Unrestricted Access to Sensitive Business Flows**: Check survey gate can't be
  bypassed by direct `POST /api/chat/sessions` without gate-check
- **API07 SSRF** (same as A10 above, API-focused): check CX agent definition fetch URLs
- **API08 Security Misconfiguration**: Check that OPTIONS preflight is handled; check
  error responses don't expose stack traces or internal paths
- **API09 Improper Inventory Management**: Verify no undocumented/shadow endpoints exposed;
  cross-reference `contracts/api.md` against actual routes registered in Express router
- **API10 Unsafe Consumption of APIs**: Check any third-party API (Dialogflow, GCP) call
  validates response schema before using data

---

## Phase 4 — Live Endpoint Verification

**Before starting**: Load `references/audit-scope.md` for dev API base URL.

Run `curl -si` for each check and inspect response code + headers:

```bash
# Auth enforcement — expect 401 on protected routes
curl -s -o /dev/null -w "%{http_code}" https://api.dev.mentalhelp.chat/api/chat/sessions

# Security headers check
curl -si https://api.dev.mentalhelp.chat/api/settings
# Verify: Strict-Transport-Security, X-Content-Type-Options, X-Frame-Options,
#         Referrer-Policy, Content-Security-Policy
# Flag missing headers as MEDIUM

# CORS check — verify NOT wildcard, NOT arbitrary origin reflection
curl -H "Origin: https://evil.example.com" -si https://api.dev.mentalhelp.chat/api/settings

# Rate limiting on auth — send 6 rapid requests, verify 429 on 6th
for i in {1..6}; do
  curl -s -o /dev/null -w "%{http_code}\n" -X POST https://api.dev.mentalhelp.chat/api/auth/verify \
    -H "Content-Type: application/json" -d '{"email":"test@test.com","otp":"000000"}'
done

# Error hygiene — verify no stack trace or internal path in 404 body
curl -si https://api.dev.mentalhelp.chat/api/nonexistent-endpoint
```

**Produces**: List of HTTP header gaps, CORS misconfig, missing rate limiting evidence

---

## Phase 5 — Infrastructure & Secrets Audit

```bash
# List all secrets in Secret Manager
gcloud secrets list --project=mental-help-global-25

# Check IAM bindings — flag overly-broad roles/owner or roles/editor
gcloud projects get-iam-policy mental-help-global-25

# Verify Cloud Run backend is NOT allow-unauthenticated
gcloud run services describe chat-backend-dev --region=us-central1

# Check Cloud SQL authorized networks (should be internal/VPC only)
gcloud sql instances describe chat-db-dev
```

- Verify no secrets in GHA workflow env vars in plaintext: read `.github/workflows/*.yml` in all repos

---

## Phase 6 — Repository & CI/CD Security

```bash
# Branch protection for each repo
gh api repos/MentalHelpGlobal/chat-backend/branches/develop/protection
gh api repos/MentalHelpGlobal/chat-frontend/branches/develop/protection
gh api repos/MentalHelpGlobal/workbench-frontend/branches/develop/protection
# Verify: required_status_checks, required_pull_request_reviews, enforce_admins

# Check for accidentally committed .env files
git -C D:\src\MHG\chat-backend log --all --full-history -- "*.env"
git -C D:\src\MHG\chat-frontend log --all --full-history -- "*.env"
```

Additional checks:
- GHA workflow permissions must NOT use `permissions: write-all`
- Check for `--no-verify` usage in commit hooks or workflow steps
- `actions/checkout` and other GHA actions must be pinned to SHA or version tag (not `@main`/`@master`)

---

## Phase 7 — Report Generation + Confluence

**Before starting**: Load `references/report-template.md` and `references/confluence-config.md`.

1. Compile all findings from phases 1–6
2. Format each finding per `references/report-template.md`
3. Print summary table: counts by severity and category
4. List CRITICAL/HIGH findings at top for immediate visibility
5. **Publish to Confluence**:

```
# Search for existing page to avoid duplicates
searchConfluenceUsingCql(
  cql = 'title = "Security Audit — YYYY-MM-DD" AND space = "UD"'
)

# If not found → create
createConfluencePage(
  parentId = <security-audits-parent from confluence-config.md>,
  title = "Security Audit — YYYY-MM-DD",
  body = <formatted report>
)

# If found → update
updateConfluencePage(
  pageId = <found page id>,
  version = N+1,
  body = <formatted report>
)
```

**Page structure**:
1. Audit metadata header (date, scope, auditor)
2. Executive summary (counts by severity)
3. CRITICAL / HIGH findings
4. MEDIUM findings
5. LOW / INFO findings
6. Dependency CVEs
7. Passed checks

Return the Confluence page URL to the user.

---

## Quick Reference

| Phase | Tool | Output |
|-------|------|--------|
| 1 – CVE | `npm audit --json` | CVE list |
| 2 – App OWASP | File reads + Grep | A01–A10 findings |
| 3 – API OWASP | File reads + Grep | API01–API10 findings |
| 4 – Live | `curl -si` | Header/CORS/rate-limit gaps |
| 5 – Infra | `gcloud` CLI | IAM/secrets findings |
| 6 – CI/CD | `gh api` + file reads | Branch protection gaps |
| 7 – Report | Confluence MCP | Published audit page |

---

## Common Mistakes

| Mistake | Correct Approach |
|---------|-----------------|
| Skipping phases to save time | Sequential — each phase informs the next |
| Creating a new Confluence page every run | Always CQL-search first; update if exists |
| Logging full curl response bodies that may contain tokens | Truncate auth-related outputs |
| Marking a check FAIL when you can't verify it | Mark as INFO (needs manual review) with reason |
| Auto-fixing findings inline | Report only — never modify source files |

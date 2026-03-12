# Feature Specification: Security Hardening — Audit Findings Remediation

**Branch**: `main` | **Date**: 2026-03-12 | **Source**: Security Audit 2026-03-12

## Overview

Address all CRITICAL, HIGH, and MEDIUM findings from the 2026-03-12 security audit
([Confluence](https://mentalhelpglobal.atlassian.net/wiki/spaces/UD/pages/21463041)).
The audit identified 18 findings across dependency CVEs, missing security headers,
IAM over-permissioning, branch protection gaps, and misconfigured error handling.

## User Stories

### US1 — Dependency CVEs resolved

As a maintainer, I want all CRITICAL and HIGH npm advisories removed from all repos,
so that known vulnerabilities in the dependency chain cannot be exploited.

**Acceptance criteria**:
- `npm audit` in `chat-backend`, `chat-frontend`, `workbench-frontend` returns 0 critical and 0 high advisories
- `chat-types` moderate advisories addressed where fix is non-breaking

### US2 — Security headers on all API responses

As a security reviewer, I want every API response to include the standard security
headers (HSTS, X-Frame-Options, X-Content-Type-Options, Referrer-Policy, CSP),
so that browsers enforce transport security, clickjacking protection, and content type safety.

**Acceptance criteria**:
- `curl -si https://api.dev.mentalhelp.chat/api/settings` returns all five headers
- `X-Powered-By: Express` is absent from all responses

### US3 — CORS and error responses return well-formed JSON

As a security reviewer, I want unauthorized CORS origins to receive no CORS headers
(not a 500), and all unmatched routes to return JSON 404 (not HTML),
so that error handling does not leak implementation details.

**Acceptance criteria**:
- Request with `Origin: https://evil.example.com` returns the request silently rejected (no CORS headers, no 500)
- `curl https://api.dev.mentalhelp.chat/api/nonexistent` returns JSON `{"success":false,"error":{"code":"NOT_FOUND",...}}`

### US4 — Branch protection on all develop branches

As a team lead, I want all three main repos to enforce PR-based integration,
so that no code reaches `develop` without review and passing CI.

**Acceptance criteria**:
- `gh api repos/MentalHelpGlobal/chat-backend/branches/develop/protection` returns 200 with `required_pull_request_reviews.required_approving_review_count >= 1`
- Same for `chat-frontend` and `workbench-frontend`

### US5 — GCP IAM least-privilege

As a security reviewer, I want over-broad IAM roles removed from service accounts,
so that a compromised workload cannot escalate to full project owner.

**Acceptance criteria**:
- `942889188964-compute@developer.gserviceaccount.com` no longer holds `roles/owner`
- `ai-devops@mental-help-global-25.iam.gserviceaccount.com` no longer holds `roles/owner`; replaced with minimum required roles

### US6 — OTP devCode not exposed in prod or staging (dev intentional)

As a security reviewer, I want the OTP code never returned in API responses on
any environment where `EMAIL_PROVIDER` is not `console`,
so that the email authentication factor cannot be bypassed.

**Acceptance criteria**:
- Prod Cloud Run service `chat-backend` has `EMAIL_PROVIDER` not set to `console`
- Dev behaviour (devCode in response when EMAIL_PROVIDER=console) is preserved as documented dev feature

## Out of Scope

- Cloud SQL private IP migration (infrastructure investment, separate cycle)
- GHA SHA pinning (LOW risk, separate maintenance cycle)
- n8n access restriction (separate service, not part of chat platform)

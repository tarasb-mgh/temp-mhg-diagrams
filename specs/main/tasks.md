# Tasks: Security Hardening — Audit Findings Remediation

**Input**: `specs/main/plan.md`, `specs/main/spec.md`, `specs/main/research.md`
**Branch**: `main` | **Date**: 2026-03-12

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different repos/files, no blocking dependency)
- **[Story]**: User story reference (US1–US6)
- No tests requested — implementation tasks only

---

## Phase 1: Setup (Feature Branches)

**Purpose**: Create hardening branches in each affected repo before making changes.

- [X] T001 Create feature branch `security/hardening-2026-03-12` in chat-backend (`D:\src\MHG\chat-backend`)
- [X] T002 [P] Create feature branch `security/hardening-2026-03-12` in chat-frontend (`D:\src\MHG\chat-frontend`)
- [X] T003 [P] Create feature branch `security/hardening-2026-03-12` in workbench-frontend (`D:\src\MHG\workbench-frontend`)
- [X] T004 [P] Create feature branch `security/hardening-2026-03-12` in chat-infra (`D:\src\MHG\chat-infra`)

---

## Phase 2: US1 — Dependency CVEs (npm audit fix)

**Goal**: Remove all CRITICAL and HIGH npm advisories from the three frontend/backend repos.

**Independent Test**: `npm audit` in each repo returns 0 critical, 0 high (vite-plugin-pwa HIGH deferred — accepted known risk per research.md Decision 2).

- [X] T005 [P] [US1] Run `npm audit fix` in chat-backend and commit updated `package.json` / `package-lock.json` in `D:\src\MHG\chat-backend`
- [X] T006 [P] [US1] Run `npm audit fix` in chat-frontend and commit updated `package.json` / `package-lock.json` in `D:\src\MHG\chat-frontend`
- [X] T007 [P] [US1] Run `npm audit fix` in workbench-frontend and commit updated `package.json` / `package-lock.json` in `D:\src\MHG\workbench-frontend`
- [X] T008 [US1] Verify residuals: chat-backend 2 HIGH (google-cloud --force deferred + tar via node-pre-gyp unmaintained); frontends 4 HIGH (vite-plugin-pwa chain deferred). 0 CRITICAL across all repos.

**Checkpoint**: All three repos show 0 critical / 0 high in `npm audit`.

---

## Phase 3: US2 — Security Headers (helmet middleware)

**Goal**: Every API response includes HSTS, X-Frame-Options, X-Content-Type-Options, Referrer-Policy, CSP; `X-Powered-By` absent.

**Independent Test**: `curl -si https://api.dev.mentalhelp.chat/api/settings` (after deploy) returns all 5 security headers; `X-Powered-By` absent.

**Note**: T009–T010 build on T005 — commit chat-backend npm audit fix before adding helmet to keep lockfile clean.

- [X] T009 [US2] Install `helmet@^8.1.0` in chat-backend: run `npm install helmet` in `D:\src\MHG\chat-backend`
- [X] T010 [US2] Add helmet middleware to `chat-backend/src/index.ts`: add `import helmet from 'helmet'` and `app.use(helmet({ contentSecurityPolicy: { useDefaults: false, directives: { defaultSrc: ["'none'"] } } }))` after `dotenv.config()`, before `cors()`

**Checkpoint**: Helmet import present in index.ts; middleware in correct position.

---

## Phase 4: US3 — CORS Silent Reject + JSON Error Handlers

**Goal**: Unauthorized CORS origins return no CORS headers (not 500); all unmatched routes return JSON 404; uncaught errors return JSON 500.

**Independent Test**:
- `curl -H "Origin: https://evil.example.com" -si https://api.dev.mentalhelp.chat/api/settings` → no `Access-Control-Allow-Origin` header, no 500
- `curl -si https://api.dev.mentalhelp.chat/api/nonexistent` → `{"success":false,"error":{"code":"NOT_FOUND",...}}`

**Note**: T011–T013 all modify `chat-backend/src/index.ts` — execute sequentially.

- [X] T011 [US3] Fix CORS origin callback in `chat-backend/src/index.ts`: change `callback(new Error('Not allowed by CORS'))` → `callback(null, false)`
- [X] T012 [US3] Add JSON 404 catch-all handler in `chat-backend/src/index.ts` after all `app.use()` route registrations, before `startServer()`
- [X] T013 [US3] Add global JSON error handler `(err: Error, _req: Request, res: Response, _next: NextFunction) => {...}` in `chat-backend/src/index.ts` after the 404 handler

**Checkpoint**: index.ts has CORS fix, 404 handler, and error handler in correct order.

- [X] T014 [US3] Open PR — https://github.com/MentalHelpGlobal/chat-backend/pull/162

---

## Phase 5: US1 (continued) — Frontend CVE PRs

**Goal**: Get npm audit fix branches merged for chat-frontend and workbench-frontend.

- [X] T015 [P] [US1] Open PR — https://github.com/MentalHelpGlobal/chat-frontend/pull/111
- [X] T016 [P] [US1] Open PR — https://github.com/MentalHelpGlobal/workbench-frontend/pull/85

---

## Phase 6: US4 — Branch Protection on develop

**Goal**: `develop` branch in all 3 repos requires at least 1 approving review; force-push and deletion blocked.

**Independent Test**: `gh api repos/MentalHelpGlobal/<repo>/branches/develop/protection` returns 200 with `required_pull_request_reviews.required_approving_review_count >= 1` for each repo.

**Note**: GitHub API calls only — no source code changes. All three can run in parallel.

- [X] T017 [P] [US4] Enable branch protection on `develop` in `MentalHelpGlobal/chat-backend` — confirmed required_approving_review_count:1, allow_force_pushes:false, allow_deletions:false
- [X] T018 [P] [US4] Enable branch protection on `develop` in `MentalHelpGlobal/chat-frontend` — confirmed
- [X] T019 [P] [US4] Enable branch protection on `develop` in `MentalHelpGlobal/workbench-frontend` — confirmed
- [X] T020 [US4] Verify protection active: all 3 repos return required_approving_review_count:1 ✅

**Checkpoint**: All three repos enforce PR review on `develop`.

---

## Phase 7: US5 — GCP IAM Least-Privilege

**Goal**: Neither `942889188964-compute@developer.gserviceaccount.com` nor `ai-devops@mental-help-global-25.iam.gserviceaccount.com` holds `roles/owner`.

**Independent Test**: `gcloud projects get-iam-policy mental-help-global-25` shows neither SA under the `roles/owner` binding.

- [X] T021 [US5] Pre-condition: ai-devops SA confirmed as ACTIVE infra scripts identity (retains roles/owner). Only Default Compute SA (942889188964-compute@) is in scope for owner removal.
- [X] T022 [US5] Create `chat-infra/scripts/security-hardening-2026-03-12.sh` — removes roles/owner from Default Compute SA only; ai-devops@ intentionally out of scope
- [X] T023 [US5] Run script — Default Compute SA roles/owner removed; 4 scoped roles remain
- [X] T024 [US5] Verify: roles/owner = {clara@, tarasb@, ai-devops@}. Compute SA removed. ✅
- [X] T025 [US5] Open PR — https://github.com/MentalHelpGlobal/chat-infra/pull/10 (updated with corrected scope)

**Checkpoint**: Both SAs removed from `roles/owner`; ai-devops has 6 scoped roles; CI/CD deployments still succeed.

---

## Phase 8: US6 — Prod OTP Email Provider Verification

**Goal**: Prod Cloud Run `chat-backend` has `EMAIL_PROVIDER` not set to `console`.

**Independent Test**: `gcloud run services describe chat-backend --region=europe-west1 --project=mental-help-global-25 --format="yaml(spec.template.spec.containers[0].env)"` shows `EMAIL_PROVIDER=gmail` or variable absent.

- [X] T026 [US6] Read prod Cloud Run env vars: EMAIL_PROVIDER=gmail confirmed ✅
- [X] T027 [US6] Already compliant — no update needed

**Checkpoint**: Prod OTP provider confirmed non-console.

---

## Phase 9: Polish & Smoke Tests

**Purpose**: Post-deploy verification that all changes are live and functional on dev.

- [X] T028 [P] Smoke test US2 headers: `curl -si https://api.dev.mentalhelp.chat/api/settings` — verified `Strict-Transport-Security`, `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, `Content-Security-Policy` present; `X-Powered-By` absent (validated 2026-03-30)
- [X] T029 [P] Smoke test US3 CORS: `curl -H "Origin: https://evil.example.com" -si https://api.dev.mentalhelp.chat/api/settings` — verified no `Access-Control-Allow-Origin` header and no HTTP 500 (validated 2026-03-30)
- [X] T030 [P] Smoke test US3 404: `curl -si https://api.dev.mentalhelp.chat/api/nonexistent` — verified HTTP 404 with `{"success":false,"error":{"code":"NOT_FOUND",...}}` (validated 2026-03-30)
- [X] T031 vite-plugin-pwa HIGH advisory documented in commit messages on both frontend PRs (#111, #85) as accepted known risk pending upstream fix

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — start immediately; all 4 branches parallel
- **Phase 2 (US1 npm fix)**: Depends on Phase 1 branches; all 3 repos parallel
- **Phase 3 (US2 helmet)**: Depends on T005 (chat-backend npm fix committed for clean lockfile)
- **Phase 4 (US3 CORS/404)**: Depends on Phase 3 (same file; batch into single chat-backend PR)
- **Phase 5 (US1 PRs)**: Depends on Phase 2; both frontend PRs parallel
- **Phase 6 (US4 branch protection)**: Independent — can run any time after Phase 1
- **Phase 7 (US5 IAM)**: Independent — can run in parallel with Phases 2–6; T021 pre-condition must pass before T023
- **Phase 8 (US6 prod check)**: Independent — can run any time; no code changes unless EMAIL_PROVIDER=console
- **Phase 9 (Polish/smoke)**: Depends on chat-backend T014 PR merged and deployed to dev

### Parallel Workstreams

```
Phase 1 (T001–T004, parallel) ──────────────────────────────────────────────────┐
                                                                                 │
Stream A: T005 → T009 → T010 → T011 → T012 → T013 → T014  (chat-backend)       │
Stream B: T006 → T015  (chat-frontend)                      ├── Phase 9 (T028–T031)
Stream C: T007 → T016  (workbench-frontend)                 │
Stream D: T017, T018, T019 → T020  (branch protection)     │
Stream E: T021 → T022 → T023 → T024 → T025  (IAM)          │
Stream F: T026 → T027  (prod email)                        ─┘
```

### Within-Story Task Order

- US1: npm fix → verify → PR (Streams A/B/C)
- US2: install helmet → add middleware (sequential in index.ts)
- US3: fix CORS callback → add 404 handler → add error handler (sequential in index.ts)
- US4: PUT protection (parallel) → verify (sequential)
- US5: pre-condition check → create script → run script → verify → PR
- US6: describe env → update if needed

---

## Implementation Strategy

### Single-developer sequence

1. Phase 1: Create all 4 branches (parallel — fast)
2. T005, T006, T007: npm audit fix in all 3 repos (parallel)
3. T008: Verify 0 critical/high across repos
4. T009, T010: Install and configure helmet in chat-backend
5. T011–T013: CORS fix + error handlers in chat-backend/src/index.ts
6. T014–T016: Open PRs for all three repos
7. T017–T020: Enable branch protection (API calls — fast)
8. T021–T025: IAM pre-check → script → run → verify → PR
9. T026–T027: Prod env check
10. T028–T031: Smoke tests after chat-backend deploy

### Total: 31 tasks

| Workstream | Tasks | Count |
|------------|-------|-------|
| Setup (branches) | T001–T004 | 4 |
| US1 (npm CVEs) | T005–T008, T015–T016 | 6 |
| US2 (helmet) | T009–T010 | 2 |
| US3 (CORS/404) | T011–T014 | 4 |
| US4 (branch protection) | T017–T020 | 4 |
| US5 (IAM) | T021–T025 | 5 |
| US6 (prod email) | T026–T027 | 2 |
| Polish/smoke | T028–T031 | 4 |
| **Total** | | **31** |

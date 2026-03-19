---
name: mhg.ship
description: >
  This skill should be used when the user asks to "ship the changes", "push and review all PRs",
  "get the changes deployed", "run the full PR and deploy cycle", "ship to dev",
  "push PRs review merge deploy", "deploy to dev and run regression", "run the ship workflow",
  "review PRs and deploy", or "merge and test on dev".
  Executes the full MHG shipping pipeline: discover unpushed changes across repos → open PRs →
  review loop (fix until clean) → merge + deploy to dev → UI regression loop (fix until clean).
version: 2.0.0
---

# mhg.ship — Full Ship Pipeline

Execute the complete MHG shipping pipeline from local commits to verified dev deployment.
The pipeline has four sequential phases; do not skip or reorder them.

```
Phase 1: Push Changes → Open PRs
              ↓ [verification-before-completion gate]
Phase 2: PR Review Loop  (repeat until all PRs pass)
              ↓ [verification-before-completion gate]
Phase 3: Merge + Deploy to Dev
              ↓ [verification-before-completion gate]
Phase 4: UI Regression Loop  (repeat until no issues)
              ↓ [verification-before-completion gate]
         DONE
```

Load `references/repos.md` before Phase 1 for repo paths, branch rules, and CI details.
Load `references/regression-targets.md` before Phase 4 for test flows and error-hunting patterns.

---

## Phase 1 — Discover and Push Changes

For each repo listed in `references/repos.md`, run in sequence:

### 1a. Detect repo state

```bash
git -C <REPO_PATH> status --short          # uncommitted changes
git -C <REPO_PATH> log origin/HEAD..HEAD   # unpushed commits
git -C <REPO_PATH> branch --show-current   # current branch
```

Skip repos with no uncommitted changes and no unpushed commits.

### 1b. Branch routing

| Repo type | Current branch | Action |
|---|---|---|
| App repo (backend, frontend, workbench) | feature branch | Push branch → open PR to `develop` |
| App repo (backend, frontend, workbench) | `develop` directly | **Flag policy violation** — create feature branch from current commits first, then PR |
| `chat-types` | `main` | Push to `main` directly (no develop branch) |
| `cx-agent-definition` | `main` | Push to `main` directly |
| `chat-infra` | `develop` | Push to `develop` directly (infra scripts, no review gate) |

### 1c. Create feature branch if needed (app repos on develop)

```bash
# Cut a feature branch from current HEAD, reset develop to origin
git -C <REPO_PATH> checkout -b feature/<short-name>
git -C <REPO_PATH> push -u origin feature/<short-name>
```

Then repoint local develop:
```bash
git -C <REPO_PATH> checkout develop
git -C <REPO_PATH> reset --hard origin/develop
git -C <REPO_PATH> checkout feature/<short-name>
```

### 1d. Pre-PR verification gate

> **Invoke `superpowers:verification-before-completion` before opening any PRs.**

For each repo with changes, run the local test suite and type-check. Do not open PRs on failing code.

```bash
# Backend
npm --prefix D:\src\MHG\chat-backend test --run

# Frontend / Workbench
npm --prefix D:\src\MHG\chat-frontend run typecheck
npm --prefix D:\src\MHG\workbench-frontend run typecheck

# chat-types
npm --prefix D:\src\MHG\chat-types run build
```

Evidence required: show test output (pass count + 0 failures) and type-check exit code for each repo before proceeding to 1e.

If any repo has failures, fix them in the current branch. Do NOT open PRs until all repos pass.

### 1e. Open PRs (app repos only)

Use `gh pr create` targeting `develop`:

```bash
gh -R MentalHelpGlobal/<repo> pr create \
  --base develop \
  --head feature/<branch> \
  --title "<concise title>" \
  --body "$(cat <<'EOF'
## Summary
- <bullet points>

## Test plan
- [ ] Unit tests pass
- [ ] Regression sweep passes

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Collect all PR numbers and URLs before proceeding to Phase 2.

---

## Phase 2 — PR Review Loop

**Run sequentially. Loop until all PRs are clean.**

```
LOOP:
  For each open PR (in dependency order — see below):
    1. Run the code-review:code-review skill on the PR
    2. If issues found:
       a. Invoke superpowers:receiving-code-review before applying any fix
       b. Evaluate each issue technically (not performative agreement)
       c. Apply fixes in the relevant repo
       d. Commit the fix
       e. Push to the PR branch
    3. Re-run review on the same PR
  Check: are all PRs now issue-free?
  If YES → exit loop
  If NO  → repeat
```

### Invoking the review skill

Use the `code-review:code-review` skill via the Skill tool for each PR, passing the PR number and repo. Alternatively use `pr-review-toolkit:review-pr` for a multi-agent deep review.

### Applying fixes — receiving-code-review discipline

When the review returns issues, invoke `superpowers:receiving-code-review` before touching any code. Follow its response pattern:

1. **Read** — complete feedback without reacting
2. **Understand** — restate each issue in your own words
3. **Verify** — check the flagged code against codebase reality
4. **Evaluate** — is the fix technically sound for this codebase?
5. **Implement** — one item at a time, verify each fix before moving to the next
6. **Confirm** — after fixes, re-run the relevant test/typecheck command to verify no regressions

Push back with technical reasoning if a review issue is incorrect. Never blindly implement suggestions that don't fit the codebase.

### Dependency order

Always review and fix in this order to avoid type-mismatch errors cascading:

1. `chat-types` (shared types — must be correct before backend/frontend)
2. `chat-backend` (depends on chat-types)
3. `workbench-frontend` (depends on chat-types)
4. `chat-frontend` (depends on chat-types)

> **Parallelism opportunity**: Once `chat-types` review is clean and merged, `chat-backend`, `workbench-frontend`, and `chat-frontend` have no inter-dependency and can be reviewed concurrently. Invoke `superpowers:dispatching-parallel-agents` if all three have open PRs.

### Exit condition

All PRs have passed review with no remaining issues. At minimum: no type errors, no logic bugs, no security issues, no missing i18n keys in changed files.

---

## Phase 3 — Merge + Deploy

### 3a. Merge PRs

Merge in dependency order (types → backend → frontends). Use squash merge:

```bash
gh -R MentalHelpGlobal/<repo> pr merge <PR_NUMBER> \
  --squash --delete-branch --auto
```

### 3b. Wait for CI deploy

After each merge, wait for the deploy workflow to complete:

```bash
# Poll until status is 'completed'
gh -R MentalHelpGlobal/<repo> run list \
  --workflow=deploy.yml --branch=develop --limit=1
```

See `references/repos.md` for workflow file names per repo.

### 3c. Deploy verification gate

> **Invoke `superpowers:verification-before-completion` before proceeding to Phase 4.**

Run health checks and capture the actual response output as evidence:

```bash
# Backend health check — must show 200 and healthy JSON
curl -sf https://api.dev.mentalhelp.chat/health

# Frontends — must show 200
curl -sf -o /dev/null -w "chat-frontend: %{http_code}\n" https://dev.mentalhelp.chat
curl -sf -o /dev/null -w "workbench: %{http_code}\n" https://workbench.dev.mentalhelp.chat
```

Evidence required: show the actual curl output (HTTP status + health body) for each service before claiming "deployed successfully". If any service returns non-200, do not proceed to Phase 4 — investigate the deployment failure first.

---

## Phase 4 — UI Regression Loop

**Run sequentially. Loop until no issues found.**

Load `references/regression-targets.md` for the full test flow list and error patterns before starting.

```
LOOP:
  Run the regression sweep (see references/regression-targets.md):
    1. Execute each test flow using Playwright MCP tools
    2. After each flow, check:
       - browser_console_messages → flag JS errors, untranslated keys
       - browser_network_requests → flag 4xx / 5xx responses
    3. After all flows, check server logs (Cloud Run)
  Collect all issues found
  If NO issues → run verification-before-completion exit gate (see below)
  If issues found:
    a. Invoke superpowers:systematic-debugging — root cause BEFORE any fix
    b. Identify the root cause for each issue
    c. Fix the code in the relevant repo
    d. Commit + push to develop (infra/type fixes) or open a follow-up PR (app fixes)
    e. Wait for redeploy (Phase 3b pattern)
    f. Re-run Phase 3c deploy verification gate
    g. Repeat loop
```

### When issues are found — systematic-debugging discipline

> **Invoke `superpowers:systematic-debugging` for every regression issue before proposing a fix.**

Do not patch symptoms. Follow the four phases:
1. **Root cause investigation** — reproduce, isolate, trace the call stack
2. **Hypothesis formation** — form a specific, testable hypothesis
3. **Targeted fix** — fix the root cause, not the symptom
4. **Verification** — prove the fix works and no new issues were introduced

"Quick fixes" that skip root cause investigation are prohibited in the regression loop.

### Playwright MCP tools to use

| Tool | Purpose |
|---|---|
| `browser_navigate` | Open URLs |
| `browser_snapshot` | Capture accessibility tree for structural checks |
| `browser_take_screenshot` | Visual verification |
| `browser_console_messages` | Read JS console output |
| `browser_network_requests` | Inspect HTTP requests and status codes |
| `browser_fill_form` | Fill login / chat input forms |
| `browser_click` | Click buttons, tabs, links |
| `browser_wait_for` | Wait for elements / network idle |

### Server log check

```bash
gcloud logging read \
  'resource.type="cloud_run_revision" AND severity>=ERROR' \
  --project=mental-help-global-25 \
  --limit=50 \
  --format="table(timestamp,severity,textPayload)"
```

### Phase 4 exit verification gate

> **Invoke `superpowers:verification-before-completion` before declaring Phase 4 complete.**

Do not claim "no issues found" without showing fresh evidence. Required evidence before exit:

1. **Console output** — `browser_console_messages` output for the final sweep of each flow showing zero errors
2. **Network output** — `browser_network_requests` output showing all monitored API endpoints returned expected status codes
3. **Server logs** — `gcloud logging read` output showing zero ERROR entries attributable to this deployment
4. **Regression checklist** — every item in `references/regression-targets.md` Regression Sweep Completion Checklist checked

If any evidence is missing or partial, the sweep is not complete.

---

## Superpowers Integration Summary

| Phase | Gate | Superpowers skill |
|---|---|---|
| 1 → exit | Before opening PRs | `superpowers:verification-before-completion` |
| 2 → fix | Applying review feedback | `superpowers:receiving-code-review` |
| 2 → parallel | After types land, review backend+frontends | `superpowers:dispatching-parallel-agents` |
| 3 → exit | After health checks, before regression | `superpowers:verification-before-completion` |
| 4 → issue | When regression finds a bug | `superpowers:systematic-debugging` |
| 4 → exit | Before declaring regression clean | `superpowers:verification-before-completion` |

---

## Key Rules

- **Sequential execution only** — do not run phases in parallel; each phase gates the next
- **No scheduling** — all loops execute synchronously in the current session
- **Dependency order matters** — always process `chat-types` before `chat-backend` before frontends
- **Policy on direct-develop commits** — create a feature branch before opening a PR; never push directly to `develop` on app repos
- **Loop exit requires evidence** — do not claim "no issues" without running a full sweep and invoking verification-before-completion; show the console/network/log output confirming clean state
- **Redeploy confirmation** — after each fix cycle in Phase 4, confirm the new revision is serving before re-running the sweep
- **Root cause before fix** — invoke systematic-debugging for every regression issue; no shotgun patches

## References

- **`references/repos.md`** — All MHG repo paths, branch rules, CI workflow names, deploy URLs
- **`references/regression-targets.md`** — Playwright test flows, i18n key check patterns, error signatures to hunt for

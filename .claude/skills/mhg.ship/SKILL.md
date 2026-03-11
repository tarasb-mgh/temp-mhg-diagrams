---
name: mhg.ship
description: >
  This skill should be used when the user asks to "ship the changes", "push and review all PRs",
  "get the changes deployed", "run the full PR and deploy cycle", "ship to dev",
  "push PRs review merge deploy", "deploy to dev and run regression", "run the ship workflow",
  "review PRs and deploy", or "merge and test on dev".
  Executes the full MHG shipping pipeline: discover unpushed changes across repos → open PRs →
  review loop (fix until clean) → merge + deploy to dev → UI regression loop (fix until clean).
version: 1.0.0
---

# mhg.ship — Full Ship Pipeline

Execute the complete MHG shipping pipeline from local commits to verified dev deployment.
The pipeline has four sequential phases; do not skip or reorder them.

```
Phase 1: Push Changes → Open PRs
         ↓
Phase 2: PR Review Loop  (repeat until all PRs pass)
         ↓
Phase 3: Merge + Deploy to Dev
         ↓
Phase 4: UI Regression Loop  (repeat until no issues)
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

### 1d. Open PRs (app repos only)

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
  For each open PR (in order of dependency — types first, then backend, then frontends):
    1. Run the code-review:code-review skill on the PR
    2. If issues found:
       a. Apply fixes in the relevant repo
       b. Commit the fix
       c. Push to the PR branch
    3. Re-run review on the same PR
  Check: are all PRs now issue-free?
  If YES → exit loop
  If NO  → repeat
```

### Invoking the review skill

Use the `code-review:code-review` skill via the Skill tool for each PR, passing the PR number and repo. Alternatively use `pr-review-toolkit:review-pr` for a multi-agent deep review.

### Dependency order

Always review and fix in this order to avoid type-mismatch errors cascading:

1. `chat-types` (shared types — must be correct before backend/frontend)
2. `chat-backend` (depends on chat-types)
3. `workbench-frontend` (depends on chat-types)
4. `chat-frontend` (depends on chat-types)

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

### 3c. Confirm deployment

Verify each deployed service responds correctly:

```bash
# Backend health check
curl -sf https://api.dev.mentalhelp.chat/health

# Frontend — check for non-error HTTP status
curl -sf -o /dev/null -w "%{http_code}" https://dev.mentalhelp.chat
curl -sf -o /dev/null -w "%{http_code}" https://workbench.dev.mentalhelp.chat
```

Only proceed to Phase 4 after all deployed services return 200.

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
  If NO issues → exit loop
  If issues found:
    a. Identify the root cause for each issue
    b. Fix the code in the relevant repo
    c. Commit + push to develop (infra/type fixes) or open a follow-up PR (app fixes)
    d. Wait for redeploy (Phase 3b pattern)
    e. Repeat loop
```

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

### Exit condition

Full regression sweep completes with:
- Zero JS console errors
- Zero 4xx/5xx network responses on expected flows
- Zero untranslated i18n keys visible in UI
- Zero ERROR-level entries in Cloud Run logs attributable to this deployment

---

## Key Rules

- **Sequential execution only** — do not run phases in parallel; each phase gates the next
- **No scheduling** — all loops execute synchronously in the current session
- **Dependency order matters** — always process `chat-types` before `chat-backend` before frontends
- **Policy on direct-develop commits** — create a feature branch before opening a PR; never push directly to `develop` on app repos
- **Loop exit requires evidence** — do not claim "no issues" without running a full sweep; show the console/network/log output confirming clean state
- **Redeploy confirmation** — after each fix cycle in Phase 4, confirm the new revision is serving before re-running the sweep

## References

- **`references/repos.md`** — All MHG repo paths, branch rules, CI workflow names, deploy URLs
- **`references/regression-targets.md`** — Playwright test flows, i18n key check patterns, error signatures to hunt for

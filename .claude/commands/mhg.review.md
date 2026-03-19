---
allowed-tools: Bash, Read, Edit, Write, Glob, Grep, Agent, Skill
---

## User Input
$ARGUMENTS
Format: `<PR_NUMBER> <repo>` — e.g. `177 chat-backend`

## Prerequisites
- A PR number and repo name must be provided in `$ARGUMENTS`.
- Parse `$ARGUMENTS` to extract `PR_NUMBER` and `REPO`.
- If either is missing: print `"Error: PR number and repo required. Usage: /mhg.review <PR_NUMBER> <repo>"` and stop.
- Verify the PR is open:
  ```bash
  gh -R MentalHelpGlobal/$REPO pr view $PR_NUMBER --json state -q .state
  ```
  If not `OPEN`: print `"Error: PR #$PR_NUMBER is not open."` and stop.

## Step 1: Set Up Review Context
Invoke `superpowers:requesting-code-review` with the PR number and repo.

This skill establishes what the PR does, what tests pass, and what the acceptance criteria are — the mental model needed before receiving the code review results.

## Step 2: Code Review Loop (max 5 cycles)
Run the `code-review:code-review` skill via the Skill tool, passing `$PR_NUMBER $REPO`.

If issues are found:
1. Invoke `superpowers:receiving-code-review` before touching any code.
2. For each issue: evaluate technically (is this actually a problem for this codebase?), implement the fix, verify it does not break other tests.
3. Commit and push the fix to the PR branch.
4. Re-run `code-review:code-review`.

Repeat until:
- Loop exits when `code-review:code-review` returns "No issues found" (termination condition)
- Max 5 review cycles, then surface to human — do not merge

## Step 3: Verify Mergeable State
After the review loop exits cleanly:
```bash
gh -R MentalHelpGlobal/$REPO pr view $PR_NUMBER --json mergeable,reviewDecision
gh -R MentalHelpGlobal/$REPO pr checks $PR_NUMBER
```
Expected: `mergeable: MERGEABLE` and all required CI checks showing `pass`.

## Output
- PR `#$PR_NUMBER` in `MentalHelpGlobal/$REPO` with 0 open review issues; all fixes pushed to the PR branch; PR is in a mergeable state (no review issues, CI checks passing)
- Jira: none at this phase
- Next command: /mhg.ship

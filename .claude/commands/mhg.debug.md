---
allowed-tools: Bash, Read, Edit, Write, Glob, Grep, Agent, Skill
---

## User Input
$ARGUMENTS
Provide: bug description or failing test output.

## Prerequisites
- A bug description or failing test output must be provided in `$ARGUMENTS`.
- If `$ARGUMENTS` is empty: print `"Error: bug description or failing test output required."` and stop.

## Step 1: Systematic Debugging
Invoke `superpowers:systematic-debugging` with the bug description from `$ARGUMENTS`.

The systematic-debugging skill runs four phases:
1. **Root cause investigation** — reproduce the bug, isolate it, trace the call stack
2. **Hypothesis formation** — form a specific, testable hypothesis
3. **Targeted fix** — fix the root cause, not the symptom
4. **Verification** — prove the fix works and no new issues were introduced

Do NOT attempt any fix before completing Phase 1 (root cause investigation).

## Step 2: Verify Fix
After the fix is applied, show verification evidence:
- Run the specific test or command that previously demonstrated the bug.
- Show the output: the test must now pass.
- Run the full test suite for the affected repo.
- Show the pass count and 0 new failures.

If verification fails: return to Step 1 — do not apply additional patches without another root cause investigation.

## Output
- Root cause documented (shown in conversation)
- Fix applied (files modified, committed)
- Verification evidence shown: previously-failing test now passes (show output); full suite passes (show pass count)
- Jira: none
- Next command: none — return to the command that triggered the debug session (e.g. `/mhg.implement` step 4 of the per-task loop — verification gate, or `/mhg.ship` Phase 4 loop)

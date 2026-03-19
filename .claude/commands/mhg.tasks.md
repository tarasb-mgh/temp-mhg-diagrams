---
allowed-tools: Bash, Read, Edit, Write, Glob, Grep, Agent, Skill
---

## User Input
$ARGUMENTS

## Prerequisites
Run `.specify/scripts/powershell/check-prerequisites.ps1 -Json` to obtain `FEATURE_DIR`.

- If `$FEATURE_DIR/plan.md` does not exist: print `"Error: plan.md not found. Run /mhg.plan first."` and stop.

## Step 1: Generate Tasks
Run `/speckit.tasks`.

Speckit generates `specs/NNN-feature/tasks.md` with all implementation tasks grouped by user story.

## Step 2: Consistency Check (loop — max 3 fix rounds)
Run `/speckit.analyze` to check cross-artifact consistency across `spec.md`, `plan.md`, and `tasks.md`.

If inconsistencies are reported:
- Make targeted edits to the specific artifact that contains the inconsistency
- Re-run `/speckit.analyze`
- Loop exits when speckit.analyze reports 0 cross-artifact inconsistencies
- Max 3 targeted fix rounds; if inconsistencies persist after 3 rounds, surface to human — do not proceed to Jira issue creation

## Step 3: Create Jira Issues
Run `/speckit.taskstoissues` to create Jira Stories and Tasks under the Epic.

Verify Jira keys are recorded in `tasks.md`:
```bash
grep -c 'MTB-' "$FEATURE_DIR/tasks.md"
```
Expected: > 0 keys recorded.

If Jira MCP is unavailable, tasks will be marked `[PENDING: ...]` in `tasks.md`. Continue; sync retroactively with `/mhg.sync push`.

## Output
- `tasks.md`: `specs/NNN-feature/tasks.md`
- Jira: Stories + Tasks created under Epic (or PENDING markers if MCP unavailable)
- Next command: /mhg.implement

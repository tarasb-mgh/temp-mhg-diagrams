---
allowed-tools: Bash, Read, Edit, Write, Glob, Grep, Agent, Skill
---

## User Input
$ARGUMENTS
Format: `<mode> [--feature NNN]` where mode is `audit`, `push`, or `pull`.

## Prerequisites
- A valid mode (`audit`, `push`, or `pull`) must be present in `$ARGUMENTS`.
- If no mode provided: print `"Error: mode required. Usage: /mhg.sync <audit|push|pull> [--feature NNN]"` and stop.
- At least one `specs/NNN-feature/tasks.md` must exist.
- If no tasks.md found: print `"Error: No tasks.md found. Run /mhg.tasks first."` and stop.

## Step 1: Sync
Pass `$ARGUMENTS` directly to `/speckit.sync`.

Speckit.sync handles all Jira reconciliation:
- `audit` — read-only report; shows discrepancies without making changes
- `push` — transitions locally-complete (`[X]`) tasks to Done in Jira
- `pull` — updates `tasks.md` checkboxes where Jira already shows Done

## Step 2: Verify
After sync completes, confirm alignment by running audit mode.

Extract any `--feature NNN` scope from `$ARGUMENTS` and pass it through:

- If `$ARGUMENTS` contains `--feature NNN`: run `/speckit.sync audit --feature NNN`
- Otherwise (all features): run `/speckit.sync audit`

The audit report must show:
- `Needs push: 0`
- `Needs pull: 0`

If any discrepancies remain (e.g. due to `[PENDING: ...]` markers from an unavailable MCP), note them and advise the user to retry `/mhg.sync push` when the Jira MCP is available.

## Output
- `tasks.md` and Jira aligned — confirmed by `speckit.sync audit` reporting 0 discrepancies
- Jira: none (or issues transitioned to Done if mode=push)
- Next command: none — pass-through utility

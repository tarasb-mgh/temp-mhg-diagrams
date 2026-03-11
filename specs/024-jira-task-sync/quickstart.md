# Quickstart: Jira Task Status Sync (024)

**Branch**: `024-jira-task-sync`
**Date**: 2026-03-10

## What This Is

`/speckit.sync` is a Claude Code slash command that compares your local `tasks.md` checkbox states against Jira issue statuses and reconciles the two sources.

---

## Prerequisites

- Claude Code CLI with Atlassian MCP configured
- Access to the MHG Jira project (`mentalhelpglobal.atlassian.net`)
- Local `client-spec` repo checked out on a feature branch

---

## Common Workflows

### 1. See what's out of sync (no changes made)

```
/speckit.sync audit
```

Produces a table showing every task where local state and Jira state disagree.

### 2. After completing a feature — push all Done tasks to Jira

```
/speckit.sync push --feature 020
```

Transitions all `[X]` tasks in `specs/020-production-resilience/tasks.md` whose Jira issues are not yet Done.

### 3. Sync from a colleague's Jira transitions back to local

```
/speckit.sync pull --feature 023
```

Updates `[ ]` tasks in `specs/023-user-group-enhancements/tasks.md` to `[X]` where Jira already shows Done.

### 4. Full project cleanup — push all features at once

```
/speckit.sync push
```

Processes all `specs/*/tasks.md` files. Useful after a sprint to clean up the entire board.

---

## Reading the Output

### Audit table

```
  [X] T001 → MTB-559   LOCAL: done   JIRA: To Do    ← push needed
  [ ] T005 → MTB-563   LOCAL: open   JIRA: Done     ← pull needed
  [X] T003 → MTB-561   LOCAL: done   JIRA: Done     ✓ in sync
  [ ] T007              no Jira key                  - skipped
```

- `← push needed`: Run `/speckit.sync push` to fix
- `← pull needed`: Run `/speckit.sync pull` to fix
- `✓ in sync`: Nothing to do
- `- skipped`: Task has no Jira key; use `/speckit.taskstoissues` to add one

### Summary line

```
Scanned: 42 tasks  |  With Jira keys: 38  |  Without keys: 4
In sync: 35  |  Needs push: 2  |  Needs pull: 1  |  Errors: 0
```

---

## Troubleshooting

**`MTB-XXX: not found in Jira`** — The Jira issue was deleted or the key is wrong. Check the tasks.md line and correct the key, or remove it if the issue no longer exists.

**`PENDING` markers in tasks.md** — A Jira API call failed. Re-run `/speckit.sync push` when Jira is available to retry. The PENDING marker is removed automatically on success.

**Command times out** — If running full-project audit and the project has >200 tasks, try scoping with `--feature NNN`.

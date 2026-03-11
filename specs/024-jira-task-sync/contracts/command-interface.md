# Contract: speckit.sync Command Interface

**Feature**: 024-jira-task-sync
**Date**: 2026-03-10
**Type**: Claude Code slash command

---

## Command Signature

```
/speckit.sync [mode] [--feature <NNN>]
```

### Arguments

| Argument | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `mode` | `audit` \| `push` \| `pull` | No | (prompt user) | Operation to perform |
| `--feature <NNN>` | string | No | all features | Limit to one feature spec, e.g., `023` or `023-user-group-enhancements` |

### Mode Definitions

| Mode | Reads tasks.md | Calls Jira read | Modifies Jira | Modifies tasks.md |
|------|---------------|-----------------|---------------|-------------------|
| `audit` | ✅ | ✅ | ❌ | ❌ |
| `push` | ✅ | ✅ | ✅ (Done transitions) | ❌ |
| `pull` | ✅ | ✅ | ❌ | ✅ (`[ ]` → `[X]`) |

---

## Output Format

### Audit Report (text table)

```
Jira Sync Audit — [scope] — [timestamp]
===========================================
Feature: [name]

  [X] T001 → MTB-559   LOCAL: done  JIRA: To Do    ← push needed
  [ ] T005 → MTB-563   LOCAL: open  JIRA: Done     ← pull needed
  [X] T003 → MTB-561   LOCAL: done  JIRA: Done     ✓ in sync
  [ ] T007              no Jira key                  - skipped

Summary:
  Scanned: 42 tasks  |  With Jira keys: 38  |  Without keys: 4
  In sync: 35  |  Needs push: 2  |  Needs pull: 1  |  Errors: 0
```

### Push Report

```
Push Sync Results — [scope] — [timestamp]
==========================================
  ✅ MTB-559  T001  → Done   (was: To Do)
  ✅ MTB-563  T005  → Done   (was: In Progress)
  ⏭️  MTB-561  T003  already Done — skipped
  ⚠️  MTB-600  T030  API error: [message] — PENDING

Summary: 2 transitioned, 1 skipped, 1 PENDING
```

### Pull Report

```
Pull Sync Results — [scope] — [timestamp]
==========================================
  ✅ T005  specs/023-user-group-enhancements/tasks.md:47  [ ] → [X]   (Jira: Done)
  ⏭️  T001  already [X] locally — skipped

Summary: 1 updated, 1 skipped
```

---

## Parsing Rules

### Task line format

A valid task line must match:
```regex
^- \[([ xX])\] (~~)?T(\d+).*([?—]\s*(MTB-\d+))?
```

| Capture | Meaning |
|---------|---------|
| `[ ]` | open |
| `[x]` or `[X]` | done |
| `~~T...~~` | cancelled — skip entirely |
| `? MTB-XXX` | Jira key (020-style) |
| `— MTB-XXX` | Jira key (021-style) |

### Header epic key format

```regex
\*\*Jira Epic\*\*:.*\[MTB-(\d+)\]
```

### Story mapping format

```regex
^- US\d+ -> `MTB-(\d+)`
```

Header keys are used for reporting context only; they are NOT synced by push/pull operations.

---

## Error Handling

| Condition | Behavior |
|-----------|----------|
| Jira issue key not found (404) | Warn `MTB-XXX: not found in Jira` — skip |
| Jira API rate limited (429) | Warn + mark `PENDING` — continue with other tasks |
| Jira MCP unavailable | Warn `Jira MCP unavailable` + mark all unresolved as `PENDING` — do not abort |
| tasks.md not writable (pull mode) | Error `Cannot write to [path]` — abort pull for that file only |
| Feature not found (--feature flag) | Error `No spec directory matching [NNN]` — abort |

---

## PENDING Marker Convention

When a Jira operation cannot be completed due to API failure, append a `PENDING` note to the task line in tasks.md:

```
- [X] T001 Create branches — MTB-559 [PENDING: Jira transition failed 2026-03-10T14:52]
```

This marker is visible in the next audit run and prompts retry.

---

## Scope Resolution (--feature flag)

Given `--feature 023`:
1. Match `specs/023-*/` directories (prefix match)
2. If multiple matches, error and list all matches
3. If one match, use `specs/023-<name>/tasks.md`
4. If no match, error

Given no flag:
1. Walk all `specs/*/tasks.md` files
2. Skip directories without `tasks.md`
3. Skip `specs/README.md`, `specs/main/`

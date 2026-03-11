# Data Model: Jira Task Status Sync (024)

**Branch**: `024-jira-task-sync`
**Date**: 2026-03-10

This feature is a CLI tool with no persistent storage. All entities are in-memory constructs used during a single command execution.

---

## SpecTask

Represents a single parsed task line from a `tasks.md` file.

| Field | Type | Source | Notes |
|-------|------|--------|-------|
| `taskId` | string | tasks.md line | e.g., `T001`, `T042` |
| `checkboxState` | `open` \| `done` \| `cancelled` | checkbox syntax | `[ ]`=open, `[x]`/`[X]`=done, `~~Txxx~~`=cancelled |
| `jiraKey` | string \| null | ` ? MTB-XXX` or ` — MTB-XXX` suffix | null if no key present |
| `description` | string | remainder of line | Full task text without checkbox/Jira key |
| `featureName` | string | parent directory name | e.g., `023-user-group-enhancements` |
| `filePath` | string | absolute path | e.g., `D:/src/MHG/client-spec/specs/023-.../tasks.md` |
| `lineNumber` | number | 1-based | Used for targeted file updates in pull-sync |

**State transitions**:
- `open` → `done`: pull-sync when Jira issue is Done
- No other state changes are made to local files

---

## JiraIssue

Represents a Jira issue retrieved via the Atlassian MCP.

| Field | Type | Source | Notes |
|-------|------|--------|-------|
| `key` | string | MCP response | e.g., `MTB-559` |
| `summary` | string | MCP response | Issue title |
| `statusName` | string | MCP response | e.g., `To Do`, `In Progress`, `Done` |
| `statusCategoryKey` | string | MCP response | `new` / `indeterminate` / `done` |
| `isDone` | boolean | derived | `statusCategoryKey === 'done'` |

---

## SyncDiscrepancy

A mismatch between a SpecTask's local state and the corresponding Jira issue state.

| Field | Type | Notes |
|-------|------|-------|
| `type` | enum | See types below |
| `specTask` | SpecTask | The local task |
| `jiraIssue` | JiraIssue \| null | null for `local-only` type |
| `resolution` | string | Human-readable suggested action |

**Discrepancy types**:

| Type | Meaning | Suggested Resolution |
|------|---------|---------------------|
| `local-done/jira-open` | `[X]` locally but Jira is not Done | Push: transition Jira to Done |
| `jira-done/local-open` | `[ ]` locally but Jira is Done | Pull: update tasks.md to `[X]` |
| `jira-only` | Jira key found in header but no task line has it | Manual review |
| `local-only` | Task has no Jira key at all | Skipped — no action |
| `error` | Jira API call failed for this key | Reported as warning |

---

## SyncReport

The structured output of an audit or sync run.

| Field | Type | Notes |
|-------|------|-------|
| `mode` | `audit` \| `push` \| `pull` | What mode was run |
| `scope` | string | Feature name or `all` |
| `discrepancies` | SyncDiscrepancy[] | All found discrepancies |
| `actionsApplied` | SyncAction[] | Actions taken (empty in audit mode) |
| `skipped` | SkippedTask[] | Tasks without Jira keys |
| `errors` | ErrorEntry[] | Failed Jira API calls |
| `summary` | SyncSummary | Counts and overall status |

**SyncSummary**:
| Field | Type | Notes |
|-------|------|-------|
| `totalTasksScanned` | number | |
| `tasksWithKeys` | number | Had a Jira key |
| `tasksWithoutKeys` | number | No Jira key — skipped |
| `discrepanciesFound` | number | Mismatches before action |
| `actionsApplied` | number | Transitions made / file lines updated |
| `errors` | number | API failures |
| `pendingMarkers` | number | Issues marked PENDING for retry |

---

## SyncAction

Records a single applied change (push or pull).

| Field | Type | Notes |
|-------|------|-------|
| `type` | `jira-transition` \| `file-update` | |
| `jiraKey` | string | MTB-XXX |
| `taskId` | string | T001 |
| `featureName` | string | |
| `previousState` | string | Before state |
| `newState` | string | After state |
| `timestamp` | string | ISO 8601 |
| `pending` | boolean | True if API was unavailable |

---

## File Representation

No persistent schema. All entities exist only during command execution. The only files modified are:

**Read-only**:
- `specs/*/tasks.md` — task definitions

**Write (pull-sync only)**:
- `specs/*/tasks.md` — checkbox state updates (`[ ]` → `[X]`)

---
description: Compare local tasks.md checkbox states against Jira issue statuses and reconcile them. Supports three modes — audit (read-only report), push ([X] → Jira Done), pull (Jira Done → [X] in tasks.md) — with optional --feature scoping.
---

## User Input

```text
$ARGUMENTS
```

You **MUST** parse the arguments above before proceeding. The arguments string may contain:
- A mode keyword: `audit`, `push`, or `pull`
- A scope flag: `--feature <NNN>` or `--feature <NNN-name>`
- Both, e.g.: `push --feature 023` or `audit --feature 020-production-resilience`
- Neither (no arguments = prompt user for mode, then process all features)

---

## Execution Flow

```
[Step 1: Parse arguments]
        ↓
[Step 2: Resolve scope → list of tasks.md file paths]
        ↓
[Step 3: Parse tasks.md files → list of SpecTasks]
        ↓
[Step 4: Collect unique Jira keys → batch JQL query → key→JiraIssue map]
        ↓
[Step 5: Compute SyncDiscrepancies per SpecTask]
        ↓
[Step 6: Print audit table (ALL modes)]
        ↓
[if mode=audit: STOP]
[if mode=push: Step 7A — transitionJiraIssue for local-done/jira-open]
[if mode=pull: Step 7B — Edit tasks.md for jira-done/local-open]
        ↓
[Step 8: Print action summary]
```

---

## Step 1 — Argument Parsing

Parse `$ARGUMENTS` string:

**Mode detection** (case-insensitive):
- Contains `audit` → mode = `audit`
- Contains `push` → mode = `push`
- Contains `pull` → mode = `pull`
- No mode keyword → ask the user: "Which mode? `audit` (read-only report), `push` (mark [X] tasks Done in Jira), or `pull` (update tasks.md from Jira Done)?" — wait for response before continuing

**Scope detection**:
- If `$ARGUMENTS` matches `--feature\s+(\S+)`, capture the value as FEATURE_ARG
- Otherwise FEATURE_ARG = null (all features)

---

## Step 2 — Scope Resolution

**If FEATURE_ARG is set**:

1. Glob `specs/*/` directories
2. Find directories whose name **starts with** FEATURE_ARG (prefix match, e.g., `023` matches `023-user-group-enhancements`)
3. If zero matches → print `Error: No spec directory matching '${FEATURE_ARG}' found` and abort
4. If two or more matches → print `Error: Ambiguous --feature '${FEATURE_ARG}' — matches: [list all matches]` and abort
5. If exactly one match → SCOPE_FILES = [`specs/<matched-dir>/tasks.md`]
6. If the matched `tasks.md` does not exist → print `Warning: No tasks.md in specs/<dir>/` and use empty list

**If FEATURE_ARG is null**:

1. Glob `specs/*/tasks.md`
2. Exclude any path containing `specs/main/` or `specs/README`
3. SCOPE_FILES = all matched paths

**If SCOPE_FILES is empty** → print `No tasks.md files found to process` and stop.

---

## Step 3 — Task Parsing

For each file in SCOPE_FILES:

1. Read the file contents
2. Extract `featureName` from the directory name (e.g., `023-user-group-enhancements`)
3. For each line, apply the following rules in order:

**Line classification rules**:

a. **Skip header/metadata lines** — lines that do NOT start with `- [` (e.g., `##`, `**`, blank, `---`)

b. **Skip story-mapping lines** — lines matching `- US\d+ -> \x60MTB-\d+\x60` (story-to-issue mapping)

c. **Cancelled task** — if the line matches `- \[[ xX]\] ~~T\d+` (task ID is struck through):
   - Set `checkboxState = "cancelled"`
   - Extract `taskId` from the `~~T(\d+)~~` capture
   - Set `jiraKey = null`
   - **Do not include in any sync operations** — skip entirely

d. **Valid task line** — must match the pattern:
   ```
   ^- \[([ xX])\] T(\d+)
   ```
   - Capture group 1 → `checkboxState`: space = `"open"`, `x` or `X` = `"done"`
   - Capture group 2 → `taskId` (e.g., `T001`)

e. **Jira key extraction** — scan the full line for the pattern `[?—]\s*(MTB-\d+)`:
   - `?` = question-mark style (020-style): `? MTB-559`
   - `—` = em-dash style (021-style): `— MTB-559`
   - If found → `jiraKey = "MTB-<number>"` (the captured group)
   - If not found → `jiraKey = null`

f. Record the 1-based `lineNumber` of each parsed task

**Result**: A list of `SpecTask` objects: `{ taskId, checkboxState, jiraKey, featureName, filePath, lineNumber }`

**Important**: Do NOT parse lines from the "Story Mapping" section (lines like `- US1 → \`MTB-667\``). These are epic/story references, not implementation tasks.

---

## Step 4 — Jira Batch Query

1. Collect all unique `jiraKey` values from the parsed SpecTasks where `jiraKey != null`
2. If no keys found → skip Jira query; all tasks will be classified as `local-only`
3. Split keys into batches of **at most 50**

For each batch, call `searchJiraIssuesUsingJql` with:
- `cloudId`: `3aca5c6d-161e-42c2-8945-9c47aeb2966d`
- `jql`: `project = MTB AND key in (MTB-XXX, MTB-YYY, ...) ORDER BY key ASC`
- Request fields: `key`, `summary`, `status` (status.name, status.statusCategory.key)

4. Merge all batch results into a **key → JiraIssue map**:
   ```
   {
     "MTB-559": { key: "MTB-559", statusName: "To Do", statusCategoryKey: "new", isDone: false },
     "MTB-560": { key: "MTB-560", statusName: "Done",  statusCategoryKey: "done", isDone: true },
     ...
   }
   ```
   - `isDone = (statusCategoryKey === "done")`

5. If a batch query fails with a 503/MCP unavailable error:
   - Print `Warning: Jira MCP unavailable — marking all unresolved keys as PENDING`
   - Set all keys from the failed batch as `status = "PENDING"` in the map
   - Continue processing with remaining batches

---

## Step 5 — Discrepancy Computation

For each SpecTask (excluding cancelled):

| Local State | Jira State | Classification |
|-------------|------------|----------------|
| `done` | `isDone = true` | `in-sync` |
| `done` | `isDone = false` | `local-done/jira-open` |
| `open` | `isDone = true` | `jira-done/local-open` |
| `open` | `isDone = false` | `in-sync` |
| `open` or `done` | key not in JiraIssue map (404) | `error` (key not found) |
| `open` or `done` | key status = "PENDING" | `error` (API unavailable) |
| `jiraKey = null` | — | `local-only` |

Build four lists:
- `needsPush` — all `local-done/jira-open` tasks
- `needsPull` — all `jira-done/local-open` tasks
- `inSync` — all `in-sync` tasks with a Jira key
- `errors` — all `error` tasks
- `skipped` — all `local-only` tasks (no Jira key)

---

## Step 6 — Audit Table Output (ALL modes)

Print the following header:
```
Jira Sync Audit — [scope description] — [current date/time]
===========================================================
```

For each feature in SCOPE_FILES, print:
```
Feature: <featureName>
```

Then for each SpecTask in that feature (in order of lineNumber), print one line:

```
  [X] T001 → MTB-559   LOCAL: done  JIRA: To Do    ← push needed
  [ ] T005 → MTB-563   LOCAL: open  JIRA: Done     ← pull needed
  [X] T003 → MTB-561   LOCAL: done  JIRA: Done     ✓ in sync
  [ ] T007             no Jira key                  - skipped
  [X] T009 → MTB-571   LOCAL: done  JIRA: (error)  ⚠ error: MTB-571 not found
```

Format rules:
- Use `[X]` for done, `[ ]` for open
- Use `→` between task ID and Jira key
- Right-align JIRA status with padding
- Suffix: `← push needed`, `← pull needed`, `✓ in sync`, `- skipped`, `⚠ error: <reason>`

Then print the summary line:
```
Summary:
  Scanned: N tasks  |  With Jira keys: N  |  Without keys: N
  In sync: N  |  Needs push: N  |  Needs pull: N  |  Errors: N
```

**If mode = `audit`**: STOP here. Print `Audit complete — no changes made.`

---

## Step 7A — Push Mode

For each SpecTask in `needsPush` (local done, Jira open):

1. Call `transitionJiraIssue`:
   - `cloudId`: `3aca5c6d-161e-42c2-8945-9c47aeb2966d`
   - `issueIdOrKey`: the task's `jiraKey`
   - `transitionId`: `51` (Done)

2. **On success**: record:
   ```
   ✅ MTB-XXX  T001  → Done   (was: To Do)
   ```

3. **On API error** (non-404, e.g., 429 rate limit or 503):
   - Append `[PENDING: Jira transition failed <ISO-8601 timestamp>]` to the task line in tasks.md using the Edit tool
   - Record:
     ```
     ⚠️  MTB-XXX  T001  API error: <error message> — PENDING
     ```
   - **Do not abort** — continue with remaining tasks

4. **If already Done** (classified as `in-sync`): record:
   ```
   ⏭️  MTB-XXX  T003  already Done — skipped
   ```

5. **If key not found** (404 error when fetching status): record:
   ```
   ⚠️  MTB-XXX  T004  not found in Jira — skipped
   ```

After all push operations, proceed to **Step 8**.

---

## Step 7B — Pull Mode

For each SpecTask in `needsPull` (local open, Jira done):

1. Read the full line content at `filePath:lineNumber`
2. Verify the line still starts with `- [ ] T<taskId>` (guard against stale line numbers)
3. Use the Edit tool to replace the checkbox:
   - `old_string`: the full line content (for uniqueness)
   - `new_string`: same line with `[ ]` replaced by `[X]`
4. Record:
   ```
   ✅ T005  specs/023-user-group-enhancements/tasks.md:47  [ ] → [X]   (Jira: Done)
   ```

For each SpecTask in `needsPush` (local done, Jira open) encountered during pull mode:
- **Do NOT modify** — local Done takes precedence; record:
  ```
  ⏭️  T001  already [X] locally — skipped (Jira: To Do — run push to sync)
  ```

After all pull operations, proceed to **Step 8**.

---

## Step 8 — Action Summary

**Push mode summary**:
```
Push Sync Results — [scope] — [timestamp]
==========================================
  [per-task results from Step 7A]

Summary: N transitioned, N skipped, N PENDING
```

**Pull mode summary**:
```
Pull Sync Results — [scope] — [timestamp]
==========================================
  [per-task results from Step 7B]

Summary: N updated, N skipped
```

---

## Error Handling Reference

| Condition | Behavior |
|-----------|----------|
| Jira key 404 (issue not found) | Warn `MTB-XXX: not found in Jira` — classify as error, skip sync, continue |
| Jira rate limit 429 | Warn + append `[PENDING: ...]` to task line — continue with other tasks |
| Jira MCP unavailable (503/connection error) | Warn `Jira MCP unavailable` + mark all unresolved as PENDING — do not abort the entire run |
| tasks.md not writable (pull mode) | Error `Cannot write to <path>` — abort pull for that file only, continue with other files |
| `--feature` not found | Error `No spec directory matching '<value>'` — abort immediately |
| `--feature` ambiguous (multiple matches) | Error `Ambiguous --feature '<value>' — matches: [list]` — abort immediately |
| Two or more keys map to identical line content | Use Edit with enough surrounding context to disambiguate; if still ambiguous, skip and warn |

---

## PENDING Marker Convention

When a Jira push operation fails due to API unavailability, append the following suffix to the affected task line in tasks.md:

```
- [X] T001 Create branches ? MTB-559 [PENDING: Jira transition failed 2026-03-10T14:52Z]
```

On a subsequent successful push run:
- The command will find the task in `needsPush` (since Jira is still "To Do")
- After successful transition, **remove** the `[PENDING: ...]` suffix using the Edit tool
- Record the task as newly transitioned

---

## Jira Constants

- **Cloud ID**: `3aca5c6d-161e-42c2-8945-9c47aeb2966d`
- **Transition ID for Done**: `51`
- **Project key**: `MTB`

---

## Quick Reference: Supported Jira Key Formats

Both formats are valid in tasks.md; both are parsed:

```
- [X] T001 Create branches ? MTB-559        ← question-mark style (020/024)
- [X] T001 Create branches — MTB-559        ← em-dash style (021)
```

The regex `[?—]\s*(MTB-\d+)` captures both. The `?` is a literal question mark; the `—` is an em-dash (U+2014), not a hyphen.

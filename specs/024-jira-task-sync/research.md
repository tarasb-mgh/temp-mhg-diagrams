# Research: Jira Task Status Sync (024)

**Branch**: `024-jira-task-sync`
**Date**: 2026-03-10
**Status**: Complete — all unknowns resolved

---

## Decision 1: Jira Key Formats in tasks.md

**Decision**: The parser MUST support two Jira key suffix formats found across existing spec files:

| Format | Example | Spec |
|--------|---------|------|
| ` ? MTB-XXX` | `- [X] T001 Create branches ? MTB-559` | 020-production-resilience |
| ` — MTB-XXX` | `- [x] T020 Create hook — MTB-588` | 021-survey-schema-tools |

Both formats use a suffix appended at the end of the task line. The regex pattern to extract keys is:
```
[?—]\s*(MTB-\d+)
```

Additional header patterns (not task-level keys):
- Epic: `**Jira Epic**: [MTB-XXX](url)` — in tasks.md header
- Story mapping: `- US1 -> \`MTB-XXX\`` — in the Jira Story Mapping section

**Rationale**: Both formats have been used in production specs. Restricting to one would silently miss existing keys.

**Alternatives considered**:
- Require a single canonical format going forward — rejected because it would make sync non-functional for existing specs without a migration pass

---

## Decision 2: Atlassian MCP as the Jira Interface

**Decision**: Use the `mcp__claude_ai_Atlassian__*` tools (Atlassian MCP) exclusively for all Jira operations. No direct REST API calls.

Key tool inventory:
| Operation | MCP Tool |
|-----------|----------|
| Get issue status | `getJiraIssue` |
| Bulk status query | `searchJiraIssuesUsingJql` |
| Transition to Done | `transitionJiraIssue` (transition ID `51`) |
| Add comment | `addCommentToJiraIssue` |

**Project constants** (to embed in command):
- `cloudId`: `3aca5c6d-161e-42c2-8945-9c47aeb2966d`
- Done transition ID: `51`
- Done status category key: `done`

**Rationale**: MCP tools are already used throughout speckit workflows and provide consistent error handling and authentication.

---

## Decision 3: Command Structure — Audit-First, Action-Optional

**Decision**: A single command `/speckit.sync` with optional mode flags:

| Invocation | Behavior |
|-----------|----------|
| `/speckit.sync` | Full audit + interactive prompt to apply push-sync |
| `/speckit.sync audit` | Audit only, no changes |
| `/speckit.sync push` | Push `[X]` → Done to Jira without prompting |
| `/speckit.sync pull` | Pull Jira Done → `[X]` in tasks.md without prompting |
| `/speckit.sync push --feature 023` | Scoped push for one feature |
| `/speckit.sync audit --feature 023` | Scoped audit |

**Rationale**: Audit is the safest default. Separating push/pull prevents accidental bidirectional sync. Scoping allows single-feature operations without touching unrelated work.

**Alternatives considered**:
- Three separate commands (`/speckit.sync-audit`, `/speckit.sync-push`, `/speckit.sync-pull`) — rejected as fragmenting the command surface
- Auto-sync without confirmation — rejected; constitution Principle X requires intentional transitions

---

## Decision 4: tasks.md Parsing Strategy

**Decision**: The command parses tasks.md files using regex-based line scanning (no external parser library). For each task line:

1. Match checkbox state: `- \[([ xX])\]` → `open`, `done`, or skip
2. Match cancelled state: `~~T\d+~~` → `cancelled`
3. Extract Jira key: `[?—]\s*(MTB-\d+)` → key or `null`
4. Extract task ID: `T\d+` as first token after checkbox

**Scope discovery**: Walk `specs/*/tasks.md` or limit to `specs/<feature>/tasks.md` if `--feature` flag provided.

**Rationale**: The command runs inside Claude Code which executes as a prompt — parsing is done by Claude reading files with Read tool + pattern matching. No npm dependency or compiled script needed.

---

## Decision 5: Feature Scope — client-spec Only

**Decision**: This feature adds one new file to `client-spec`:
- `.claude/commands/speckit.sync.md`

No split repositories (chat-backend, chat-frontend, etc.) are affected. This feature is a workflow tool for developers using speckit — it has no runtime impact on the deployed application.

**Rationale**: The command only reads/writes local spec files and calls Jira via MCP. No application code is modified.

---

## Decision 6: Handling 023-style tasks.md (No Inline Jira Keys)

**Finding**: Not all tasks.md files embed Jira keys on individual task lines. The 023-user-group-enhancements tasks.md uses explicit Jira transition tasks (`T033 Transition Jira Stories MTB-658–MTB-665...`) rather than inline per-task keys.

**Decision**: The sync command only operates on tasks with inline Jira keys (`? MTB-XXX` or `— MTB-XXX` suffix). Tasks without keys are reported in the audit as "no Jira key — skipped" without error. The command should note at the end of the report how many tasks were skipped due to missing keys.

**Rationale**: Forcing keys on all tasks is a constitution change, not a sync tool responsibility. The tool works with what exists.

---

## Jira API Limits

**Finding**: `searchJiraIssuesUsingJql` has a max of 100 results per call. Typical features have 20–70 tasks. No pagination needed for the expected scale (all active features combined: ~200 tasks).

**Decision**: For full project-wide sync, use JQL `project = MTB AND key in (...)` with chunked key lists of 50 if total keys exceed 100.

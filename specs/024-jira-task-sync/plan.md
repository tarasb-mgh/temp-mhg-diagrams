# Implementation Plan: Jira Task Status Sync

**Branch**: `024-jira-task-sync` | **Date**: 2026-03-10 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/024-jira-task-sync/spec.md`

## Summary

Add a `/speckit.sync` Claude Code slash command to `client-spec` that compares local `tasks.md` checkbox states against Jira issue statuses and reconciles them. The command supports three modes — audit (report only), push (`[X]` → Jira Done), and pull (Jira Done → `[X]` in tasks.md) — with optional per-feature scoping. Implementation is a single markdown command file in `.claude/commands/`.

## Technical Context

**Language/Version**: Markdown (Claude Code slash command prompt)
**Primary Dependencies**: Atlassian MCP (`mcp__claude_ai_Atlassian__*`), Claude Code file tools (Read, Edit, Glob, Grep)
**Storage**: N/A — no persistent storage; reads/writes `tasks.md` files in-place
**Testing**: Manual smoke tests against `specs/020-production-resilience/tasks.md` and `specs/021-survey-schema-tools/tasks.md` (known key formats)
**Target Platform**: Claude Code CLI (Windows, macOS, Linux)
**Project Type**: CLI slash command
**Performance Goals**: Full project audit (200 tasks across all specs) completes in under 60 seconds
**Constraints**: Atlassian MCP `searchJiraIssuesUsingJql` max 100 results/call; chunk if >50 keys
**Scale/Scope**: Single `client-spec` repository; ~20 active spec files; ~200 tasks total

## Constitution Check

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Spec-First | ✅ PASS | spec.md created, this plan is Phase 1 |
| II. Multi-Repo Orchestration | ✅ PASS | Feature confined to `client-spec` only |
| III. Test-Aligned Development | ✅ PASS | No split-repo test suites needed; smoke tests against known fixtures |
| IV. Branch and Integration Discipline | ✅ PASS | Branch `024-jira-task-sync` from `main` (spec-only repo); PR to `main` on completion |
| V. Privacy and Security First | ✅ N/A | No user data, no PII; only Jira issue metadata |
| VI. Accessibility and i18n | ✅ N/A | No user-facing UI |
| VII. Split-Repository First | ✅ PASS | No split repos affected |
| VIII. GCP CLI Infrastructure | ✅ N/A | No GCP changes |
| IX. Responsive UX and PWA | ✅ N/A | No UI |
| X. Jira Traceability | ✅ PASS | Epic + Stories + Tasks to be created via `/speckit.taskstoissues` |
| XI. Documentation Standards | ⚠️ PARTIAL | Technical Onboarding update needed for new command; no User Manual needed |
| XII. Release Engineering | ✅ N/A | `client-spec` has no deployment pipeline |

**Constitution violations**: None.

## Project Structure

### Documentation (this feature)

```text
specs/024-jira-task-sync/
├── plan.md              ← this file
├── research.md          ← complete
├── data-model.md        ← complete
├── quickstart.md        ← Phase 1 output
├── contracts/
│   └── command-interface.md   ← complete
└── tasks.md             ← Phase 2 output (/speckit.tasks)
```

### Source Code (this feature)

```text
client-spec/
└── .claude/
    └── commands/
        └── speckit.sync.md    ← NEW: the sync command
```

**Structure Decision**: Single command file. No PowerShell helper needed — Claude Code's native tools (Read, Edit, Glob, Grep) are sufficient for tasks.md parsing. The Atlassian MCP provides Jira integration.

## Phase 0: Research Findings

See [research.md](./research.md) for full decision log. Key findings:

1. **Jira key formats**: Two in production — ` ? MTB-XXX` (020 style) and ` — MTB-XXX` (021 style). Both must be supported.
2. **Atlassian MCP**: Use `searchJiraIssuesUsingJql` for bulk queries; `transitionJiraIssue` with transition ID `51` for Done; cloudId `3aca5c6d-161e-42c2-8945-9c47aeb2966d`.
3. **Command structure**: Single `/speckit.sync` command with mode flags.
4. **No split repos**: Feature entirely in `client-spec`.
5. **Not all tasks.md files have inline Jira keys**: 023-style files handle Jira via explicit tasks; skip tasks without keys silently.

## Phase 1: Design

### Command Architecture

`/speckit.sync` is a Claude Code slash command. When invoked, Claude:

1. **Resolves scope**: Determine which `tasks.md` files to process based on `--feature` flag or all files.
2. **Parses tasks**: Read each tasks.md, extract task lines with checkbox state and optional Jira key.
3. **Batch-queries Jira**: Use `searchJiraIssuesUsingJql` with `key in (MTB-A, MTB-B, ...)` to fetch all issue statuses in minimal API calls.
4. **Computes discrepancies**: Cross-reference local state vs. Jira status for each keyed task.
5. **Produces report**: Print audit table with counts.
6. **Applies actions** (if mode=push or pull): Transition Jira issues or update tasks.md lines.
7. **Summarizes**: Print counts and PENDING markers.

### Execution Flow

```
[parse --feature flag]
       ↓
[glob specs/*/tasks.md]
       ↓
[for each file: read + extract SpecTasks]
       ↓
[collect all unique Jira keys]
       ↓
[searchJiraIssuesUsingJql for keys in batches ≤50]
       ↓
[build key→JiraIssue map]
       ↓
[compute SyncDiscrepancies]
       ↓
[print audit table]
       ↓
[if mode=audit: STOP]
[if mode=push: transitionJiraIssue for local-done/jira-open discrepancies]
[if mode=pull: edit tasks.md lines for jira-done/local-open discrepancies]
       ↓
[print action summary]
```

### tasks.md Parsing Rules

See [contracts/command-interface.md](./contracts/command-interface.md) for full parsing rules.

**Summary**:
- Checkbox: `- [([ xX])]` → open/done
- Cancelled: `~~T\d+~~` → skip
- Jira key: `[?—]\s*(MTB-\d+)` → key or null

### Jira Query Strategy

For ≤50 unique keys:
```jql
project = MTB AND key in (MTB-559, MTB-560, ...) ORDER BY key ASC
```

For >50 keys (full-project audit):
```
Split into chunks of 50, run multiple queries, merge results.
```

### File Edit Strategy (pull-sync)

For each open task where Jira is Done:
- Find the exact line in tasks.md matching `- [ ] T<id>`
- Replace `[ ]` with `[X]`
- Use Claude Code `Edit` tool with the full line as `old_string`

---

## Implementation Tasks (see tasks.md when generated)

### Phase 1: Command File

1. Create `.claude/commands/speckit.sync.md` with:
   - YAML frontmatter with description
   - Full command outline following the speckit command pattern
   - Argument parsing (`audit`, `push`, `pull`, `--feature NNN`)
   - tasks.md parsing logic (regex patterns)
   - Jira batch query logic
   - Discrepancy computation
   - Report formatting
   - Push-sync: `transitionJiraIssue` calls
   - Pull-sync: `Edit` tool calls on tasks.md
   - PENDING marker convention
   - Error handling rules

### Phase 2: Smoke Tests

2. Run `/speckit.sync audit` against `specs/020-production-resilience/` — verify all 35 tasks with `? MTB-XXX` keys are found, Jira statuses retrieved, and report is accurate.
3. Run `/speckit.sync audit` against `specs/021-survey-schema-tools/` — verify all tasks with `— MTB-XXX` keys are found.
4. Run `/speckit.sync audit` (full project) — verify no errors, counts match expected.

### Phase 3: Documentation

5. Update Confluence Technical Onboarding with `/speckit.sync` documentation.
6. Add Jira Epic for this feature.

---

## Cross-Repository Dependencies

None. This feature is entirely within `client-spec`.

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Jira MCP unavailable during sync | Low | PENDING marker convention |
| New tasks.md format introduced in future | Medium | Document two supported formats; update regex when new format seen |
| More than 100 unique Jira keys at once | Medium | Chunk queries at 50; well within realistic feature sizes |
| Pull-sync corrupts tasks.md via incorrect Edit | Low | Use full line as `old_string` for uniqueness; verify after edit |

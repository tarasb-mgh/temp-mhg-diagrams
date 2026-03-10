# Feature Specification: Jira Task Status Sync

**Feature Branch**: `024-jira-task-sync`
**Jira Epic**: [MTB-666](https://mentalhelpglobal.atlassian.net/browse/MTB-666)
**Created**: 2026-03-10
**Status**: Draft
**Input**: User description: "check the status of pending jira tasks and sync spec and task definitions"

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Jira Status Audit Report (Priority: P1)

A developer or team lead wants to see at a glance which Jira issues are out of sync with their local `tasks.md` — specifically tasks marked `[X]` in a spec but still showing "To Do" in Jira, or tasks open in Jira that were never recorded in any spec.

**Why this priority**: This is the core problem being solved: the gap between local speckit tracking and Jira state accumulates silently over time and causes board confusion. Identifying the gaps is a prerequisite for any reconciliation action.

**Independent Test**: Running the audit command against any spec directory produces a machine-readable or human-readable report listing all discrepancies without making any changes to either system.

**Acceptance Scenarios**:

1. **Given** a spec with 10 tasks where 6 are `[X]` but all 10 Jira issues show "To Do", **When** the audit runs, **Then** the report lists exactly 6 discrepancies of type `local-done, jira-open`.
2. **Given** a Jira epic with 5 issues that have no corresponding `tasks.md` entries, **When** the audit runs for that epic, **Then** the report lists 5 discrepancies of type `jira-only`.
3. **Given** all tasks match between local and Jira, **When** the audit runs, **Then** the report confirms "0 discrepancies found" and exits cleanly.

---

### User Story 2 — Sync Local-Done Tasks to Jira (Priority: P1)

After completing implementation work tracked in `tasks.md`, the developer wants to push all `[X]` (checked) task completions to Jira as "Done" transitions, without manually opening each issue.

**Why this priority**: This is the most frequent action needed. Speckit workflow uses local checkboxes as the execution record; Jira transitions are a downstream artifact. Automating this eliminates the repetitive manual step of transitioning dozens of tasks.

**Independent Test**: Mark 5 tasks `[X]` in a feature's `tasks.md`, run the sync command scoped to that feature — all 5 corresponding Jira issues transition to Done; no other issues are affected.

**Acceptance Scenarios**:

1. **Given** a `tasks.md` with 8 `[X]` tasks whose Jira issues are in "To Do", **When** sync is run, **Then** all 8 issues transition to Done and a summary lists each transition.
2. **Given** a task `[X]` whose Jira issue is already "Done", **When** sync runs, **Then** the issue is skipped (idempotent) and the summary marks it as "already done".
3. **Given** a task `[X]` with no Jira issue key recorded in `tasks.md`, **When** sync runs, **Then** that task is reported as "no Jira key — skipped" and the rest proceed normally.
4. **Given** a Jira API error on one issue during bulk sync, **When** sync runs, **Then** other issues are processed and the failed issue is reported with the error message.

---

### User Story 3 — Pull Jira Status into tasks.md (Priority: P2)

A developer picks up a spec mid-flight and wants to update their local `tasks.md` checkboxes to reflect Jira's current state (e.g., issues transitioned to Done by a colleague via Jira directly).

**Why this priority**: Supports team workflows where Jira may be updated outside speckit. Less common than push, but necessary for accuracy when multiple contributors work on the same feature.

**Independent Test**: Manually transition 3 Jira issues to Done via the Jira UI (bypassing speckit), then run pull-sync — the corresponding tasks in `tasks.md` are updated from `[ ]` to `[X]`.

**Acceptance Scenarios**:

1. **Given** 3 Jira issues in "Done" whose corresponding `tasks.md` tasks are `[ ]`, **When** pull-sync runs, **Then** those 3 tasks are updated to `[X]` and a summary lists each update.
2. **Given** a `tasks.md` task with `[X]` whose Jira issue is "To Do", **When** pull-sync runs, **Then** the local file is NOT modified (local Done takes precedence; only pull Jira-Done → local).
3. **Given** no discrepancies exist, **When** pull-sync runs, **Then** `tasks.md` is unchanged and the summary confirms "0 updates applied".

---

### User Story 4 — Scope Sync to a Single Feature (Priority: P2)

The developer wants to run sync for one specific feature spec (e.g., `023-user-group-enhancements`) without affecting other specs.

**Why this priority**: Features are developed in isolation; full-project sync could inadvertently touch unrelated epics and slow down work in progress.

**Independent Test**: Running sync with `--feature 023` processes only `specs/023-user-group-enhancements/tasks.md` and the Jira epic MTB-657. No other spec files or Jira issues are touched.

**Acceptance Scenarios**:

1. **Given** multiple feature specs exist, **When** sync is run with a feature scope flag, **Then** only that feature's tasks and Jira issues are processed.
2. **Given** no scope flag is provided, **When** sync is run, **Then** all specs with Jira Epic keys are processed in sequence.

---

### Edge Cases

- What happens when a task line in `tasks.md` has a `? MTB-XXX` key but the Jira issue has been deleted?
- What happens when a tasks.md has Jira keys from multiple epics mixed in one file?
- How does the system handle tasks marked `~~cancelled~~` (strikethrough) — should they be synced to a cancelled/won't-do state or skipped?
- What happens when the Atlassian MCP is unavailable during sync?
- What happens when two team members run sync simultaneously for the same feature?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST parse all `tasks.md` files in the `specs/` directory tree and extract task lines with embedded Jira keys (format: `? MTB-XXX` or `— MTB-XXX`).
- **FR-002**: The system MUST retrieve the current status of each discovered Jira issue via the Atlassian MCP.
- **FR-003**: The system MUST generate an audit report comparing local task state (`[X]` / `[ ]` / `~~cancelled~~`) to Jira issue status for each mapped task.
- **FR-004**: The system MUST support a push-sync operation that transitions Jira issues to "Done" for all locally-checked `[X]` tasks whose Jira issues are not already "Done".
- **FR-005**: The system MUST support a pull-sync operation that updates `[ ]` tasks to `[X]` in `tasks.md` when the corresponding Jira issue is in "Done" status.
- **FR-006**: Push-sync and pull-sync operations MUST be idempotent — running them multiple times produces the same result as running once.
- **FR-007**: The system MUST accept a feature scope argument to limit processing to a single spec directory.
- **FR-008**: The system MUST report each sync action taken (transition triggered, file updated, issue skipped) in a structured summary.
- **FR-009**: The system MUST handle missing or invalid Jira keys gracefully, reporting them as warnings without aborting the full sync.
- **FR-010**: Cancelled tasks (strikethrough format in `tasks.md`) MUST be skipped during sync — neither pushed nor pulled.
- **FR-011**: The system MUST record a `PENDING` marker for any Jira operation that fails due to API unavailability, to support retroactive sync.

### Key Entities

- **SpecTask**: A single task line in `tasks.md` with a checkbox state (`[X]`, `[ ]`, `~~cancelled~~`), a task ID (e.g., T001), and an optional Jira key (e.g., MTB-559).
- **JiraIssue**: The corresponding Jira issue with a key, current status, and transition history.
- **SyncDiscrepancy**: A pair of (SpecTask, JiraIssue) where the states do not match, classified by type (`local-done/jira-open`, `jira-done/local-open`, `jira-only`, `local-only`).
- **SyncReport**: The output of an audit or sync run — a structured list of discrepancies, actions taken, warnings, and a summary count.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A developer can audit all Jira discrepancies across all active specs in under 30 seconds.
- **SC-002**: Syncing a completed feature (up to 50 tasks) to Jira Done takes under 60 seconds end-to-end.
- **SC-003**: Zero manual Jira transitions are required after completing a feature spec — all `[X]` tasks can be synced in a single command.
- **SC-004**: The audit report correctly identifies 100% of discrepancies between local `tasks.md` state and Jira issue state.
- **SC-005**: Sync operations are idempotent — running twice produces no additional changes and no errors.
- **SC-006**: When the Jira API is unavailable, all operations fail gracefully with `PENDING` markers and no data is corrupted.

## Assumptions

- Jira issue keys are embedded in `tasks.md` using the `? MTB-XXX` suffix format established by speckit conventions.
- The Atlassian MCP (cloudId `3aca5c6d-161e-42c2-8945-9c47aeb2966d`) is the Jira integration layer; no direct REST API calls are made.
- "Done" is the terminal Jira status (transition ID `51` in this project). No other terminal states (e.g., "Won't Fix", "Cancelled") are currently in use.
- Local `tasks.md` checkboxes are the authoritative source for completion tracking; Jira is a downstream reporting tool.
- Pull-sync (Jira → local) is a convenience feature and does not override local `[X]` state with Jira "To Do".
- The scope of this feature is the speckit `client-spec` repository workflows only; it does not sync implementation-repo branches or PRs.

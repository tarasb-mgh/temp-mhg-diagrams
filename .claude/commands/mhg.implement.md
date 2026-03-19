---
allowed-tools: Bash, Read, Edit, Write, Glob, Grep, Agent, Skill
---

## User Input
$ARGUMENTS
(Optional: starting task ID, e.g. `T005`)

## Prerequisites
- `specs/NNN-feature/tasks.md` must exist with at least one open task (`- [ ]`).
- `specs/NNN-feature/spec.md` must exist.
- `specs/NNN-feature/plan.md` must exist.
- If any are missing: print `"Error: <item> not found. Run /mhg.tasks first."` and stop.

Run `.specify/scripts/powershell/check-prerequisites.ps1 -Json -RequireTasks -IncludeTasks` to obtain `FEATURE_DIR` and the task list.

If `$ARGUMENTS` contains a task ID (e.g. `T005`), start from that task. Otherwise process all open tasks in order.

## Step 1: Load Context
Before processing any task, read:
- `specs/NNN-feature/spec.md` — acceptance criteria and functional requirements
- `specs/NNN-feature/plan.md` — architecture, file paths, technical decisions
- `specs/NNN-feature/data-model.md` (if exists) — entity definitions
- `specs/NNN-feature/contracts/` (if exists) — API contracts

## Step 2: Per-Task Loop
For each open task (`- [ ]`) in `tasks.md` (or starting from the provided task ID):

### 2a. Dispatch Implementer Subagent
Dispatch an implementer subagent via the Agent tool (following `superpowers:subagent-driven-development` principles) with:
- The task description and ID
- Exact file paths listed in the task line
- Contents of `spec.md`, `plan.md`, and any relevant contracts
- Instruction: "Implement this task exactly as described. Do not modify files not listed in the task."

Wait for the subagent to return its work summary and a list of modified files.

### 2b. Spec Compliance Review (loop)
Dispatch a spec-reviewer subagent via the Agent tool:

```
You are a spec-reviewer. Task [TASK_ID] has just been implemented.
Spec: [SPEC_PATH]
Implementation summary: [SUMMARY]
Files modified: [FILE LIST]

Check:
1. Does the implementation satisfy the acceptance criteria for this task's user story?
2. Are there spec requirements this task should address that are missing?
3. Does the implementation introduce behavior that contradicts the spec?

Return either:
  APPROVED — implementation matches spec
OR
  ISSUES FOUND:
  1. [specific issue with reference to spec section]
```

If ISSUES FOUND: have the implementer fix the issues and re-dispatch.
- Loop exits when spec-reviewer reports APPROVED
- Max 3 cycles, then surface to human with reviewer output — do not attempt a 4th cycle

### 2c. Code Quality Review (loop)
Dispatch a code-quality-reviewer subagent via the Agent tool:

```
You are a code-quality-reviewer. Review the implementation of task [TASK_ID].
Files modified: [FILE LIST]
Spec: [SPEC_PATH]
Plan: [PLAN_PATH]

Check:
1. No obvious bugs or null-dereference risks
2. Error handling matches what the spec/plan specifies
3. No security issues (injection, XSS, unvalidated external inputs)
4. Code follows existing patterns in the codebase
5. No unnecessary complexity or premature abstractions

Return either:
  APPROVED — no issues found
OR
  ISSUES FOUND:
  1. [specific issue with file:line reference]
```

If ISSUES FOUND: have the implementer fix the issues and re-dispatch.
- Loop exits when quality-reviewer reports APPROVED
- Max 3 cycles, then surface to human with reviewer output — do not attempt a 4th cycle

### 2d. Verification Gate
Invoke `superpowers:verification-before-completion`.

Run the test suite for the affected repo. Show the pass count and 0 failures as evidence.

If tests fail: invoke `superpowers:systematic-debugging` before attempting any fix. Do not patch symptoms.

### 2e. Complete the Task
After all gates pass:
1. Commit all implementation changes: `git add <modified files> && git commit -m "feat([task-id]): <task description>"`
2. Mark `[X]` in `tasks.md` for this task ID.
3. Transition the Jira task to Done via the Atlassian MCP (transition ID 51).
4. Save evidence to `specs/NNN-feature/evidence/[TASK_ID]/` (test output, reviewer confirmations).
5. Post a Jira comment: "Task [TASK_ID] completed. Evidence: [summary]."

If Jira transition fails (API unavailable): append `[PENDING: Jira transition failed <ISO timestamp>]` to the task line and continue.

Repeat Step 2 for the next open task.

## Output
- Code committed per task
- `tasks.md`: all processed tasks marked `[X]`
- Jira: all tasks transitioned to Done (or PENDING markers if MCP unavailable)
- Evidence: `specs/NNN-feature/evidence/T*/`
- Next command: /mhg.review then /mhg.ship

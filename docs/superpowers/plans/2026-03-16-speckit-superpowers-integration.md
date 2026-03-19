# Speckit × Superpowers Integration — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create 9 Claude Code command files (`.claude/commands/mhg.*.md`) that wrap the speckit pipeline with superpowers process gates at every phase transition.

**Architecture:** Each command file is a markdown document following the skeleton in the design doc — `allowed-tools` frontmatter, `## User Input`, `## Prerequisites`, numbered `## Step N:` sections (superpowers gate → speckit action → verify), and `## Output`. There is no application code. Validation is structural: verify required sections exist and loop caps match the spec.

**Tech Stack:** Claude Code command files (markdown); Bash for prerequisite checks and grep verification; Skill tool for superpowers invocations; Agent tool for subagent dispatches.

**Spec:** `docs/superpowers/specs/2026-03-16-speckit-superpowers-integration-design.md`

---

## File Structure

All 9 new files live in `.claude/commands/`. The `mhg.ship` skill was already updated (v2.0.0) and is not touched here.

| File | Gates | Speckit actions |
|---|---|---|
| `mhg.specify.md` | brainstorming, spec-doc-reviewer (×5), clarify (×3) | speckit.specify, speckit.clarify |
| `mhg.plan.md` | plan-doc-reviewer (×5) | speckit.plan |
| `mhg.clarify.md` | spec-doc-reviewer (×5) | speckit.clarify |
| `mhg.tasks.md` | speckit.analyze (×3) | speckit.tasks, speckit.taskstoissues |
| `mhg.implement.md` | spec-reviewer (×3/task), quality-reviewer (×3/task), verification-before-completion | implementer subagent, Jira transition |
| `mhg.analyze.md` | — (single invocation) | speckit.analyze |
| `mhg.review.md` | requesting-code-review, code-review (×5), receiving-code-review | — |
| `mhg.debug.md` | systematic-debugging | — |
| `mhg.sync.md` | — (pass-through) | speckit.sync |

**Structural validation pattern** (used after every file is written):

```bash
# Required sections present
grep -E "^## (User Input|Prerequisites|Step [0-9]+|Output)" .claude/commands/mhg.<name>.md

# Iteration caps present (for files that have loops)
grep -iE "max [35]|at most 3" .claude/commands/mhg.<name>.md

# Frontmatter present
grep "allowed-tools:" .claude/commands/mhg.<name>.md
```

---

## Chunk 1: Spec-Phase Commands

*Commands that gate the early pipeline: specify, plan, clarify.*

### Task 1: mhg.specify.md

**Files:**
- Create: `.claude/commands/mhg.specify.md`

- [ ] **Step 1: Write the file**

```markdown
---
allowed-tools: Bash, Read, Edit, Write, Glob, Grep, Agent, Skill
---

## User Input
$ARGUMENTS

## Prerequisites
- Run from the `client-spec` repo root.
- The superpowers plugin must be accessible via the Skill tool.

## Step 1: Brainstorm
Invoke `superpowers:brainstorming` with the feature description from `$ARGUMENTS`.

Brainstorming saves its design document to `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`.

After brainstorming completes, verify the output file exists:
```bash
ls docs/superpowers/specs/
```
If no new file is found, print:
> `Error: brainstorming design doc not found in docs/superpowers/specs/. Complete the brainstorming step before proceeding.`
and stop — do not call `/speckit.specify` with an empty description.

From the design doc, extract `FEATURE_DESCRIPTION`: the one-sentence goal plus the key acceptance criteria. This becomes the argument for Step 2.

## Step 2: Specify
Run `/speckit.specify` with `FEATURE_DESCRIPTION` as the argument.

Speckit creates:
- `specs/NNN-feature/spec.md`
- `specs/NNN-feature/checklists/requirements.md`

Parse the output to record `SPEC_PATH` (absolute path to `spec.md`) and `FEATURE_DIR`.

## Step 3: Spec Document Review (loop)
Dispatch a spec-document-reviewer subagent via the Agent tool with this context:

```
You are a spec-document-reviewer. Review the specification at [SPEC_PATH].

Evaluate against these criteria:
1. No [NEEDS CLARIFICATION] markers remain
2. All functional requirements are testable and unambiguous
3. Success criteria are measurable and technology-agnostic
4. All acceptance scenarios are defined with clear pass/fail conditions
5. Edge cases covering the most dangerous failure modes are documented
6. Scope is clearly bounded — what is explicitly out of scope is stated

Return either:
  APPROVED — no issues found
OR
  ISSUES FOUND:
  1. [issue with quoted spec text]
  ...
```

If ISSUES FOUND: fix `spec.md` and re-dispatch.
- Loop exits when reviewer reports APPROVED with 0 issues
- Max 5 fix-and-retry iterations, then surface to human

## Step 4: Clarify Loop
Run `/speckit.clarify` to resolve remaining ambiguities.

After `/speckit.clarify` completes, check for unresolved markers:
```bash
grep -c '\[NEEDS CLARIFICATION\]' [SPEC_PATH]
```
If count > 0: run `/speckit.clarify` again.
- Loop exits when grep returns 0
- At most 3 clarify rounds; if 3 rounds complete and markers remain, stop and surface to human: list every unresolved `[NEEDS CLARIFICATION]` marker with the surrounding spec text — do not proceed to `/mhg.plan`

## Step 5: Verify Clean
Confirm 0 markers:
```bash
grep -c '\[NEEDS CLARIFICATION\]' [SPEC_PATH]
```
Expected: 0. If > 0 after 3 rounds, surface to human with markers listed.

## Step 6: Create Jira Epic
Create the Jira Epic for this feature using the Atlassian MCP:
- `cloudId`: `3aca5c6d-161e-42c2-8945-9c47aeb2966d`
- `projectKey`: `MTB`
- `issueType`: `Epic`
- `summary`: Feature name derived from `FEATURE_DIR` (e.g. `031-review-queue-safety-prioritisation`)
- `description`: One-sentence goal extracted from `spec.md` Summary section

Record the returned Epic key (e.g. `MTB-NNN`) for use in subsequent commands.

If Jira MCP is unavailable: record `[PENDING: Epic creation failed <ISO timestamp>]` in `spec.md` front-matter and continue — sync retroactively with `/mhg.sync push` once MCP is available.

## Output
- `spec.md`: `specs/NNN-feature/spec.md` with 0 `[NEEDS CLARIFICATION]` markers (confirmed by `grep`)
- `requirements.md`: `specs/NNN-feature/checklists/requirements.md`
- Jira: Epic created (MTB-NNN)
- Next command: /mhg.plan
```

- [ ] **Step 2: Verify structure**

```bash
grep -E "^## (User Input|Prerequisites|Step [0-9]+|Output)" .claude/commands/mhg.specify.md
```
Expected sections: User Input, Prerequisites, Step 1, Step 2, Step 3, Step 4, Step 5, Step 6, Output.

- [ ] **Step 3: Verify iteration caps**

```bash
grep -iE "max 5|at most 3" .claude/commands/mhg.specify.md | wc -l
```
Expected: 2 matches (one for spec-doc-reviewer, one for clarify rounds).

- [ ] **Step 4: Verify brainstorming error message**

```bash
grep "brainstorming design doc not found" .claude/commands/mhg.specify.md
```
Expected: 1 match.

- [ ] **Step 5: Commit**

```bash
git add .claude/commands/mhg.specify.md
git commit -m "feat(commands): add mhg.specify — brainstorming → speckit.specify → spec-doc-reviewer → clarify"
```

---

### Task 2: mhg.plan.md

**Files:**
- Create: `.claude/commands/mhg.plan.md`

- [ ] **Step 1: Write the file**

```markdown
---
allowed-tools: Bash, Read, Edit, Write, Glob, Grep, Agent, Skill
---

## User Input
$ARGUMENTS

## Prerequisites
Run `.specify/scripts/powershell/check-prerequisites.ps1 -Json -PathsOnly` to obtain `FEATURE_DIR` and `SPEC_PATH`.

- If `spec.md` does not exist at `$FEATURE_DIR/spec.md`: print `"Error: spec.md not found. Run /mhg.specify first."` and stop.
- Verify no unresolved markers: `grep -c '\[NEEDS CLARIFICATION\]' $FEATURE_DIR/spec.md` must return 0.
- If markers remain: print `"Error: spec.md has unresolved [NEEDS CLARIFICATION] markers. Run /mhg.clarify first."` and stop.

## Step 1: Plan
Run `/speckit.plan`.

Speckit generates:
- `specs/NNN-feature/plan.md`
- `specs/NNN-feature/research.md`
- `specs/NNN-feature/data-model.md`
- `specs/NNN-feature/contracts/` (if applicable)

## Step 2: Plan Document Review (loop)
Dispatch a plan-document-reviewer subagent via the Agent tool with this context:

```
You are a plan-document-reviewer. Review the implementation plan at [PLAN_PATH].
The feature spec is at [SPEC_PATH].

Evaluate against these criteria:
1. Every user story from spec.md maps to at least one task group in the plan
2. All data-model entities from spec.md have corresponding definitions in data-model.md
3. No NEEDS CLARIFICATION or TODO markers remain unresolved
4. API contracts (if any) specify request/response shapes and error codes
5. The plan has a clear implementation order with dependencies stated
6. No spec requirements are silently dropped or contradicted

Return either:
  APPROVED — no issues found
OR
  ISSUES FOUND:
  1. [issue with reference to spec/plan section]
  ...
```

If ISSUES FOUND: fix the relevant artifact (`plan.md`, `data-model.md`, or `contracts/`) and re-dispatch.
- Loop exits when plan-document-reviewer reports APPROVED with no unresolved items
- Max 5 fix-and-retry iterations, then surface to human

## Step 3: Verify Artifacts
Confirm all expected artifacts exist:
```bash
ls $FEATURE_DIR/plan.md $FEATURE_DIR/research.md
```
If missing, return to Step 1.

## Output
- `plan.md`: `specs/NNN-feature/plan.md` (plan-doc-reviewer passed with 0 issues; confirmed by reviewer reporting APPROVED with no unresolved items)
- `research.md`: `specs/NNN-feature/research.md`
- `data-model.md`: `specs/NNN-feature/data-model.md`
- `contracts/`: `specs/NNN-feature/contracts/`
- Jira: none at this phase
- Next command: /mhg.tasks
```

- [ ] **Step 2: Verify structure**

```bash
grep -E "^## (User Input|Prerequisites|Step [0-9]+|Output)" .claude/commands/mhg.plan.md
```
Expected: User Input, Prerequisites, Step 1, Step 2, Step 3, Output.

- [ ] **Step 3: Verify iteration cap**

```bash
grep -i "max 5" .claude/commands/mhg.plan.md
```
Expected: 1 match.

- [ ] **Step 4: Commit**

```bash
git add .claude/commands/mhg.plan.md
git commit -m "feat(commands): add mhg.plan — speckit.plan → plan-doc-reviewer"
```

---

### Task 3: mhg.clarify.md

**Files:**
- Create: `.claude/commands/mhg.clarify.md`

- [ ] **Step 1: Write the file**

```markdown
---
allowed-tools: Bash, Read, Edit, Write, Glob, Grep, Agent, Skill
---

## User Input
$ARGUMENTS

## Prerequisites
Run `.specify/scripts/powershell/check-prerequisites.ps1 -Json -PathsOnly` to obtain `FEATURE_DIR` and `SPEC_PATH`.

- If `spec.md` does not exist at `$FEATURE_DIR/spec.md`: print `"Error: spec.md not found. Run /mhg.specify first."` and stop.

## Step 1: Clarify
Run `/speckit.clarify`, passing any user guidance from `$ARGUMENTS` as context.

Speckit applies clarifications to `spec.md`.

## Step 2: Spec Document Review (loop)
Dispatch a spec-document-reviewer subagent via the Agent tool with this context:

```
You are a spec-document-reviewer. Review the updated specification at [SPEC_PATH].

Evaluate against these criteria:
1. No [NEEDS CLARIFICATION] markers remain
2. All clarified decisions are consistently applied throughout the spec
3. No new ambiguities were introduced by the clarification edits
4. Success criteria remain measurable and technology-agnostic
5. Edge cases covering the most dangerous failure modes are documented
6. Scope is clearly bounded — what is explicitly out of scope is stated

Return either:
  APPROVED — no issues found
OR
  ISSUES FOUND:
  1. [issue with quoted spec text]
  ...
```

If ISSUES FOUND: fix `spec.md` and re-dispatch.
- Loop exits when spec-document-reviewer reports APPROVED with 0 issues
- Max 5 fix-and-retry iterations; if reviewer still finds issues after 5 iterations, stop and surface to human with current `spec.md` and reviewer output — do not proceed to `/mhg.plan`

## Step 3: Verify Clean
```bash
grep -c '\[NEEDS CLARIFICATION\]' [SPEC_PATH]
```
Expected: 0. If > 0, return to Step 1.

## Output
- `spec.md`: `specs/NNN-feature/spec.md` with 0 `[NEEDS CLARIFICATION]` markers (confirmed by `grep`)
- Jira: none
- Next command: /mhg.plan
```

- [ ] **Step 2: Verify structure and cap**

```bash
grep -E "^## (User Input|Prerequisites|Step [0-9]+|Output)" .claude/commands/mhg.clarify.md
grep -i "max 5" .claude/commands/mhg.clarify.md
```

- [ ] **Step 3: Commit**

```bash
git add .claude/commands/mhg.clarify.md
git commit -m "feat(commands): add mhg.clarify — speckit.clarify → spec-doc-reviewer"
```

---

## Chunk 2: Implementation-Phase Commands

*Commands that gate task generation and per-task implementation.*

### Task 4: mhg.tasks.md

**Files:**
- Create: `.claude/commands/mhg.tasks.md`

- [ ] **Step 1: Write the file**

```markdown
---
allowed-tools: Bash, Read, Edit, Write, Glob, Grep, Agent, Skill
---

## User Input
$ARGUMENTS

## Prerequisites
- `specs/NNN-feature/plan.md` must exist.
- If not found: print `"Error: plan.md not found. Run /mhg.plan first."` and stop.

Run `.specify/scripts/powershell/check-prerequisites.ps1 -Json` to obtain `FEATURE_DIR`.

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
```

- [ ] **Step 2: Verify structure and cap**

```bash
grep -E "^## (User Input|Prerequisites|Step [0-9]+|Output)" .claude/commands/mhg.tasks.md
grep -i "max 3" .claude/commands/mhg.tasks.md
```

- [ ] **Step 3: Commit**

```bash
git add .claude/commands/mhg.tasks.md
git commit -m "feat(commands): add mhg.tasks — speckit.tasks → speckit.analyze → Jira"
```

---

### Task 5: mhg.implement.md

**Files:**
- Create: `.claude/commands/mhg.implement.md`

- [ ] **Step 1: Write the file**

```markdown
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
```

- [ ] **Step 2: Verify structure**

```bash
grep -E "^## (User Input|Prerequisites|Step [0-9]+|Output)|^### 2[abcde]\." .claude/commands/mhg.implement.md
```
Expected: User Input, Prerequisites, Step 1, Step 2, sub-steps 2a–2e, Output.

- [ ] **Step 3: Verify per-task loop caps (2 caps — both reviewers)**

```bash
grep -i "max 3" .claude/commands/mhg.implement.md | wc -l
```
Expected: at least 2.

- [ ] **Step 4: Verify systematic-debugging is invoked on test failure**

```bash
grep "systematic-debugging" .claude/commands/mhg.implement.md
```
Expected: 1 match (step 2d).

- [ ] **Step 5: Commit**

```bash
git add .claude/commands/mhg.implement.md
git commit -m "feat(commands): add mhg.implement — per-task subagent loop with 4 gates"
```

---

## Chunk 3: Supporting Commands

*Utility and supporting commands: analyze, review, debug, sync.*

### Task 6: mhg.analyze.md

**Files:**
- Create: `.claude/commands/mhg.analyze.md`

- [ ] **Step 1: Write the file**

```markdown
---
allowed-tools: Bash, Read, Edit, Write, Glob, Grep, Agent, Skill
---

## User Input
$ARGUMENTS
(Optional: `NNN` or `NNN-feature-name` to scope to a specific feature)

## Prerequisites
- At least one `specs/NNN-feature/` directory must exist.
- If no specs/ directories found: print `"Error: No spec directories found. Run /mhg.specify first."` and stop.

## Step 1: Analyze
Run `/speckit.analyze` on the feature directory (or all features if no scope given).

Speckit.analyze performs cross-artifact consistency checks across `spec.md`, `plan.md`, and `tasks.md`.

## Step 2: Format Report
Print the constitution compliance report to the terminal in this exact format:

```
PASS  (or FAIL)
══════════════════════════════════════════
Principle │ Status │ Violations
──────────┼────────┼─────────────────────
I         │ PASS   │ —
II        │ PASS   │ —
...
XII       │ FAIL   │ [quoted non-compliant text from artifact]
══════════════════════════════════════════
```

A report is PASS when speckit.analyze reports 0 cross-artifact inconsistencies and no open compliance violations.

A FAIL report lists each violation with:
- Principle number (I–XII)
- The artifact (spec.md / plan.md / tasks.md)
- The specific non-compliant text (quoted)

## Output
- Constitution compliance report: printed to terminal
- Jira: none
- Next command: none — utility command; caller returns to the phase where mhg.analyze was invoked
```

- [ ] **Step 2: Verify structure**

```bash
grep -E "^## (User Input|Prerequisites|Step [0-9]+|Output)" .claude/commands/mhg.analyze.md
```
Expected: User Input, Prerequisites, Step 1, Step 2, Output.

- [ ] **Step 3: Verify Output Next field**

```bash
grep "none — utility command" .claude/commands/mhg.analyze.md
```
Expected: 1 match.

- [ ] **Step 4: Commit**

```bash
git add .claude/commands/mhg.analyze.md
git commit -m "feat(commands): add mhg.analyze — speckit.analyze as constitution compliance report"
```

---

### Task 7: mhg.review.md

**Files:**
- Create: `.claude/commands/mhg.review.md`

- [ ] **Step 1: Write the file**

```markdown
---
allowed-tools: Bash, Read, Edit, Write, Glob, Grep, Agent, Skill
---

## User Input
$ARGUMENTS
Format: `<PR_NUMBER> <repo>` — e.g. `177 chat-backend`

## Prerequisites
- A PR number and repo name must be provided in `$ARGUMENTS`.
- Parse `$ARGUMENTS` to extract `PR_NUMBER` and `REPO`.
- If either is missing: print `"Error: PR number and repo required. Usage: /mhg.review <PR_NUMBER> <repo>"` and stop.
- Verify the PR is open:
  ```bash
  gh -R MentalHelpGlobal/$REPO pr view $PR_NUMBER --json state -q .state
  ```
  If not `OPEN`: print `"Error: PR #$PR_NUMBER is not open."` and stop.

## Step 1: Set Up Review Context
Invoke `superpowers:requesting-code-review` with the PR number and repo.

This skill establishes what the PR does, what tests pass, and what the acceptance criteria are — the mental model needed before receiving the code review results.

## Step 2: Code Review Loop (max 5 cycles)
Run the `code-review:code-review` skill via the Skill tool, passing `$PR_NUMBER $REPO`.

If issues are found:
1. Invoke `superpowers:receiving-code-review` before touching any code.
2. For each issue: evaluate technically (is this actually a problem for this codebase?), implement the fix, verify it does not break other tests.
3. Commit and push the fix to the PR branch.
4. Re-run `code-review:code-review`.

Repeat until:
- Loop exits when `code-review:code-review` returns "No issues found" (termination condition)
- Max 5 review cycles, then surface to human — do not merge

## Step 3: Verify Mergeable State
After the review loop exits cleanly:
```bash
gh -R MentalHelpGlobal/$REPO pr view $PR_NUMBER --json mergeable,reviewDecision
gh -R MentalHelpGlobal/$REPO pr checks $PR_NUMBER
```
Expected: `mergeable: MERGEABLE` and all required CI checks showing `pass`.

## Output
- PR `#$PR_NUMBER` in `MentalHelpGlobal/$REPO` with 0 open review issues; all fixes pushed to the PR branch; PR is in a mergeable state (no review issues, CI checks passing)
- Jira: none at this phase
- Next command: /mhg.ship
```

- [ ] **Step 2: Verify structure and loop cap**

```bash
grep -E "^## (User Input|Prerequisites|Step [0-9]+|Output)" .claude/commands/mhg.review.md
grep -i "max 5" .claude/commands/mhg.review.md
```

- [ ] **Step 3: Verify termination condition**

```bash
grep "No issues found" .claude/commands/mhg.review.md
```
Expected: 1 match.

- [ ] **Step 4: Commit**

```bash
git add .claude/commands/mhg.review.md
git commit -m "feat(commands): add mhg.review — requesting-code-review → code-review loop → receiving-code-review"
```

---

### Task 8: mhg.debug.md

**Files:**
- Create: `.claude/commands/mhg.debug.md`

- [ ] **Step 1: Write the file**

```markdown
---
allowed-tools: Bash, Read, Edit, Write, Glob, Grep, Agent, Skill
---

## User Input
$ARGUMENTS
Provide: bug description or failing test output.

## Prerequisites
- A bug description or failing test output must be provided in `$ARGUMENTS`.
- If `$ARGUMENTS` is empty: print `"Error: bug description or failing test output required."` and stop.

## Step 1: Systematic Debugging
Invoke `superpowers:systematic-debugging` with the bug description from `$ARGUMENTS`.

The systematic-debugging skill runs four phases:
1. **Root cause investigation** — reproduce the bug, isolate it, trace the call stack
2. **Hypothesis formation** — form a specific, testable hypothesis
3. **Targeted fix** — fix the root cause, not the symptom
4. **Verification** — prove the fix works and no new issues were introduced

Do NOT attempt any fix before completing Phase 1 (root cause investigation).

## Step 2: Verify Fix
After the fix is applied, show verification evidence:
- Run the specific test or command that previously demonstrated the bug.
- Show the output: the test must now pass.
- Run the full test suite for the affected repo.
- Show the pass count and 0 new failures.

If verification fails: return to Step 1 — do not apply additional patches without another root cause investigation.

## Output
- Root cause documented (shown in conversation)
- Fix applied (files modified, committed)
- Verification evidence shown: previously-failing test now passes (show output); full suite passes (show pass count)
- Jira: none
- Next command: none — return to the command that triggered the debug session (e.g. `/mhg.implement` step 4 of the per-task loop — verification gate, or `/mhg.ship` Phase 4 loop)
```

- [ ] **Step 2: Verify structure**

```bash
grep -E "^## (User Input|Prerequisites|Step [0-9]+|Output)" .claude/commands/mhg.debug.md
```
Expected: User Input, Prerequisites, Step 1, Step 2, Output.

- [ ] **Step 3: Verify root-cause discipline**

```bash
grep "Phase 1\|root cause" .claude/commands/mhg.debug.md | wc -l
```
Expected: at least 2 (the four-phases description and the "do NOT attempt fix before Phase 1" instruction).

- [ ] **Step 4: Commit**

```bash
git add .claude/commands/mhg.debug.md
git commit -m "feat(commands): add mhg.debug — systematic-debugging with verification evidence"
```

---

### Task 9: mhg.sync.md

**Files:**
- Create: `.claude/commands/mhg.sync.md`

- [ ] **Step 1: Write the file**

```markdown
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
```bash
# If $ARGUMENTS contains "--feature NNN", run:
/speckit.sync audit --feature NNN

# Otherwise (all features):
/speckit.sync audit
```

The audit report must show:
- `Needs push: 0`
- `Needs pull: 0`

If any discrepancies remain (e.g. due to `[PENDING: ...]` markers from an unavailable MCP), note them and advise the user to retry `/mhg.sync push` when the Jira MCP is available.

Note: If Jira MCP was unavailable during `push` mode, tasks will have `[PENDING: ...]` markers. Retry when MCP is available.

## Output
- `tasks.md` and Jira aligned — confirmed by `speckit.sync audit` reporting 0 discrepancies
- Jira: none (or issues transitioned to Done if mode=push)
- Next command: none — pass-through utility
```

- [ ] **Step 2: Verify structure**

```bash
grep -E "^## (User Input|Prerequisites|Step [0-9]+|Output)" .claude/commands/mhg.sync.md
```
Expected: User Input, Prerequisites, Step 1, Step 2, Output.

- [ ] **Step 3: Commit**

```bash
git add .claude/commands/mhg.sync.md
git commit -m "feat(commands): add mhg.sync — speckit.sync pass-through"
```

---

## Task 10: Final Verification

- [ ] **Step 1: All 9 files exist**

```bash
ls -1 .claude/commands/mhg.specify.md \
       .claude/commands/mhg.plan.md \
       .claude/commands/mhg.tasks.md \
       .claude/commands/mhg.implement.md \
       .claude/commands/mhg.clarify.md \
       .claude/commands/mhg.analyze.md \
       .claude/commands/mhg.review.md \
       .claude/commands/mhg.debug.md \
       .claude/commands/mhg.sync.md
```
Expected: all 9 files listed, no errors.

- [ ] **Step 2: All have required sections**

```bash
for f in .claude/commands/mhg.specify.md \
          .claude/commands/mhg.plan.md \
          .claude/commands/mhg.tasks.md \
          .claude/commands/mhg.implement.md \
          .claude/commands/mhg.clarify.md \
          .claude/commands/mhg.analyze.md \
          .claude/commands/mhg.review.md \
          .claude/commands/mhg.debug.md \
          .claude/commands/mhg.sync.md; do
  echo "=== $f ==="
  grep -c "^## User Input\|^## Prerequisites\|^## Output" "$f"
done
```
Expected: `3` for every file (User Input + Prerequisites + Output).

- [ ] **Step 3: All have allowed-tools frontmatter**

```bash
for f in .claude/commands/mhg.*.md; do
  echo "=== $f ==="; grep "allowed-tools:" "$f"
done
```
Expected: `allowed-tools: Bash, Read, Edit, Write, Glob, Grep, Agent, Skill` in every file.

- [ ] **Step 4: Correct Next command pointers**

```bash
for f in .claude/commands/mhg.*.md; do
  echo "=== $f ==="
  grep "Next command:" "$f"
done
```
Verify:
- mhg.specify → `/mhg.plan`
- mhg.plan → `/mhg.tasks`
- mhg.tasks → `/mhg.implement`
- mhg.implement → `/mhg.review then /mhg.ship`
- mhg.clarify → `/mhg.plan`
- mhg.analyze → `none — utility command`
- mhg.review → `/mhg.ship`
- mhg.debug → `none — return to the command that triggered`
- mhg.sync → `none — pass-through utility`

- [ ] **Step 5: Iteration caps in files that have loops**

```bash
# Expect 2 caps: spec-doc-reviewer (max 5) and clarify rounds (at most 3)
echo "mhg.specify:"; grep -iEc "max 5|at most 3" .claude/commands/mhg.specify.md

# Expect 1: plan-doc-reviewer
echo "mhg.plan:"; grep -ic "max 5" .claude/commands/mhg.plan.md

# Expect 1: spec-doc-reviewer
echo "mhg.clarify:"; grep -ic "max 5" .claude/commands/mhg.clarify.md

# Expect 1: speckit.analyze
echo "mhg.tasks:"; grep -ic "max 3" .claude/commands/mhg.tasks.md

# Expect 2: spec-reviewer and quality-reviewer
echo "mhg.implement:"; grep -ic "max 3" .claude/commands/mhg.implement.md

# Expect 1: code-review loop
echo "mhg.review:"; grep -ic "max 5" .claude/commands/mhg.review.md
```

- [ ] **Step 6: Final summary commit**

```bash
git status  # confirm working tree is clean after all per-file commits
```
Expected: `nothing to commit, working tree clean` (all files were committed individually in Tasks 1–9).

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

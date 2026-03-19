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
You are a spec-document-reviewer. Review the updated specification at $SPEC_PATH.

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
grep -c '\[NEEDS CLARIFICATION\]' $SPEC_PATH
```
Expected: 0. If > 0, return to Step 1.

## Output
- `spec.md`: `specs/NNN-feature/spec.md` with 0 `[NEEDS CLARIFICATION]` markers (confirmed by `grep`)
- Jira: none
- Next command: /mhg.plan

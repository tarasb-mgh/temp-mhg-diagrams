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
You are a spec-document-reviewer. Review the specification at $SPEC_PATH.

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
grep -c '\[NEEDS CLARIFICATION\]' $SPEC_PATH
```
If count > 0: run `/speckit.clarify` again.
- Loop exits when grep returns 0
- At most 3 clarify rounds; if 3 rounds complete and markers remain, stop and surface to human: list every unresolved `[NEEDS CLARIFICATION]` marker with the surrounding spec text — do not proceed to `/mhg.plan`

## Step 5: Verify Clean
Confirm 0 markers:
```bash
grep -c '\[NEEDS CLARIFICATION\]' $SPEC_PATH
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

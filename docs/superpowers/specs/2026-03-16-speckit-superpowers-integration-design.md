# Speckit × Superpowers Integration — Design

**Date:** 2026-03-16
**Topic:** Wrapper commands that integrate superpowers discipline into the speckit development pipeline
**Status:** Approved — ready for planning

---

## Problem

The speckit pipeline (`/speckit.specify` → `/speckit.plan` → `/speckit.tasks` → `/speckit.implement`) produces well-structured artifacts and Jira traceability, but has no enforced quality gates at phase transitions. The superpowers plugin provides process discipline (brainstorming, verification, systematic debugging, code review reception) but has no awareness of speckit's artifact locations, Jira requirements, or constitution principles. The two systems run in parallel with no connection.

Concretely:
- Features go straight into `/speckit.specify` without a prior brainstorming/design step
- Implementation tasks execute without per-task spec compliance or quality review
- Phase exits are claimed without evidence (tests, deploy health, regression output)
- Code review feedback is applied without technical evaluation discipline
- Regression bugs are patched without root cause investigation

---

## Solution

Ten new wrapper commands in `.claude/commands/` of `client-spec`. Other developers get them by pulling the repo — no new plugins, no new repos. `mhg.ship` is updated in place (v2.0.0).

**Core principle:** superpowers = process discipline, speckit = artifact production. Wrappers enforce that superpowers gates clear before speckit produces each artifact.

---

## Architecture

```
DEVELOPMENT PIPELINE
────────────────────────────────────────────────────────────────
mhg.specify    brainstorming → speckit.specify → spec-doc-reviewer → speckit.clarify (loop)
mhg.plan       speckit.plan → plan-doc-reviewer
mhg.tasks      speckit.tasks → speckit.analyze → speckit.taskstoissues (Jira)
mhg.implement  [per task] implementer-subagent → spec-reviewer → quality-reviewer
                         → verification-before-completion → speckit [X] + Jira Done
mhg.clarify    speckit.clarify → spec-doc-reviewer (re-validate)
mhg.analyze    speckit.analyze (formatted as constitution compliance report)
mhg.review     requesting-code-review → code-review:code-review → receiving-code-review
mhg.debug      systematic-debugging
mhg.sync       speckit.sync (pass-through)
────────────────────────────────────────────────────────────────
SHIP PIPELINE (updated in place — v2.0.0)
mhg.ship       verification-before-completion (pre-PR) → push PRs →
               receiving-code-review (on fixes) → review loop →
               verification-before-completion (post-deploy) →
               systematic-debugging (on regression issues) →
               verification-before-completion (regression exit)
────────────────────────────────────────────────────────────────
```

---

## Handoff Protocol

Each wrapper has three elements: an input contract, a quality gate (always a superpowers skill), and an output contract. A wrapper only exits successfully if its gate cleared.

### mhg.specify

| | |
|---|---|
| **Input** | Natural-language feature description (from user) |
| **Gate** | (1) `superpowers:brainstorming` — produces `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`; (2) spec-document-reviewer subagent validates `spec.md` — loop exits when reviewer reports APPROVED with 0 issues; max 5 fix-and-retry iterations, then surface to human; (3) `speckit.clarify` loop — repeat until `grep -c '\[NEEDS CLARIFICATION\]' spec.md` returns 0 (at most 3 clarify rounds before surfacing to human) |
| **Output** | `specs/NNN-feature/spec.md` with 0 `[NEEDS CLARIFICATION]` markers (confirmed by `grep`), `checklists/requirements.md`, Jira Epic |
| **Next** | `/mhg.plan` |

Brainstorming saves design context to `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`. The extracted `FEATURE_DESCRIPTION` (one-sentence goal + key acceptance criteria) feeds `/speckit.specify` as its argument.

### mhg.plan

| | |
|---|---|
| **Input** | `specs/NNN-feature/spec.md` (complete, no open markers) |
| **Gate** | `speckit.plan` runs, then plan-document-reviewer subagent validates `plan.md` — loop exits when plan-document-reviewer reports APPROVED with no unresolved items; max 5 fix-and-retry iterations, then surface to human |
| **Output** | `specs/NNN-feature/plan.md` (plan-doc-reviewer passed with 0 issues; confirmed by reviewer reporting APPROVED with no unresolved items), `research.md`, `data-model.md`, `contracts/` |
| **Next** | `/mhg.tasks` |

### mhg.tasks

| | |
|---|---|
| **Input** | `specs/NNN-feature/plan.md` |
| **Gate** | `speckit.analyze` must report 0 cross-artifact inconsistencies before Jira issue creation; if inconsistencies persist after 3 targeted fix rounds, surface to human — do not proceed to Jira issue creation |
| **Output** | `specs/NNN-feature/tasks.md`, Jira Stories + Tasks created under Epic |
| **Next** | `/mhg.implement` |

### mhg.implement

| | |
|---|---|
| **Input** | `tasks.md` with open tasks; optional starting task ID |
| **Gate (per task)** | implementer subagent → spec-reviewer (loop exits when no issues; max 3 cycles, then surface to human) → quality-reviewer (loop exits when no issues; max 3 cycles, then surface to human) → verification-before-completion (tests pass, evidence shown) |
| **Output** | Code committed per task, task `[X]`, Jira task Done, evidence in `evidence/<task-id>/` |
| **Next** | `/mhg.review` then `/mhg.ship` |

Per-task loop:
1. Dispatch implementer subagent (from `superpowers:subagent-driven-development`) with task description, file paths, `spec.md`, `plan.md`, relevant contracts
2. Dispatch spec-reviewer subagent — if issues, implementer fixes, re-review; **max 3 cycles**, then surface to human
3. Dispatch code-quality-reviewer subagent — if issues, implementer fixes, re-review; **max 3 cycles**, then surface to human
4. Invoke `superpowers:verification-before-completion` — run test command for the affected repo, show pass evidence; if fails, invoke `superpowers:systematic-debugging` before any fix attempt
5. Mark `[X]` in `tasks.md`, transition Jira task to Done (transition ID 51), save evidence, post Jira comment

### mhg.clarify

| | |
|---|---|
| **Input** | `specs/NNN-feature/spec.md` with ambiguities |
| **Gate** | `speckit.clarify` → spec-document-reviewer re-validates after answers applied — loop exits when spec-document-reviewer reports APPROVED with 0 issues; max 5 fix-and-retry iterations, then surface to human |
| **Output** | Updated `spec.md` with 0 `[NEEDS CLARIFICATION]` markers (confirmed by `grep`) |
| **Next** | `/mhg.plan` |

### mhg.analyze

| | |
|---|---|
| **Input** | `specs/NNN-feature/` directory |
| **Gate** | `speckit.analyze` |
| **Output** | Constitution compliance report printed to terminal in this format: `PASS` or `FAIL`, followed by a table of checked principles (I–XII) with status and any violations quoted. A report is "passing" when speckit.analyze reports 0 cross-artifact inconsistencies and no open compliance violations. A failing report lists each violation with the principle number, the artifact, and the specific non-compliant text. |
| **Next** | None — utility command; caller returns to the phase where mhg.analyze was invoked |

### mhg.review

| | |
|---|---|
| **Input** | PR number + repo (e.g. `177 chat-backend`) |
| **Gate** | `superpowers:requesting-code-review` sets up review context → `code-review:code-review` runs the review → if issues found: `superpowers:receiving-code-review` disciplines each fix (evaluate technically, implement one at a time, verify) → re-run `code-review:code-review` → repeat until `code-review:code-review` returns "No issues found" (termination condition); max 5 review cycles, then surface to human — do not merge |
| **Output** | PR with 0 open review issues; all fixes pushed to the PR branch; PR is in a mergeable state (no review issues, CI checks passing) |
| **Next** | `/mhg.ship` |

### mhg.debug

| | |
|---|---|
| **Input** | Bug description or failing test output |
| **Gate** | `superpowers:systematic-debugging` phases 1–4 (root cause investigation → hypothesis → targeted fix → verification) |
| **Output** | Root cause documented; fix applied; verification evidence shown — specifically: the test or command that previously demonstrated the bug now passes (show output); no new test failures introduced (run full suite, show pass count) |
| **Next** | None — return to the command that triggered the debug session (e.g. `/mhg.implement` step 4, or `/mhg.ship` Phase 4 loop) |

### mhg.ship (updated in place — v2.0.0)

| | |
|---|---|
| **Input** | Repos with uncommitted changes or unpushed commits |
| **Gate (Phase 1 exit)** | `superpowers:verification-before-completion` — local tests + typecheck pass in all affected repos; evidence shown before any PR is opened |
| **Gate (Phase 2 fix)** | `superpowers:receiving-code-review` — applied to every fix before committing; technical evaluation required; repeat until `code-review:code-review` returns 0 issues; max 5 review cycles, then surface to human — do not merge |
| **Gate (Phase 3 exit)** | `superpowers:verification-before-completion` — curl output showing HTTP 200 + healthy JSON for each deployed service |
| **Gate (Phase 4 issue)** | `superpowers:systematic-debugging` — root cause before any regression fix; loop exits when the regression is no longer reproducible (verified by re-running the failing test or flow); if regression not resolved after 3 debugging cycles, stop and surface to human — do not declare Phase 4 exit |
| **Gate (Phase 4 exit)** | `superpowers:verification-before-completion` — console output, network log, server log evidence; all regression checklist items checked |
| **Output** | All PRs merged, dev environment passing full regression sweep with evidence |
| **Next** | None — terminal command |

### mhg.sync

| | |
|---|---|
| **Input** | Mode (`audit`/`push`/`pull`) + optional `--feature NNN` |
| **Gate** | `speckit.sync` |
| **Output** | `tasks.md` and Jira aligned — confirmed by `speckit.sync audit` reporting 0 discrepancies |
| **Next** | None — pass-through utility |

---

## Command File Structure

All 10 command files use this template as their minimum skeleton. Commands that require multiple gates (e.g. `mhg.implement` with its 5-step per-task loop) add additional numbered `## Step N:` sections — the template is a floor, not a ceiling. Sections may not be removed or renamed.

```markdown
---
allowed-tools: Bash, Read, Edit, Write, Glob, Grep, Agent, Skill
---

## User Input
$ARGUMENTS

## Prerequisites
[Bullet list of files/state that must exist before this command runs.
If any prerequisite is missing, print: "Error: <item> not found. Run /mhg.<prior-command> first." and stop.
If brainstorming output file is required, check docs/superpowers/specs/ for the expected file; if absent, print: "Error: brainstorming design doc not found. Complete /mhg.specify brainstorming step first." and stop.]

## Step 1: [Superpowers gate name]
Invoke superpowers:<skill-name>.
[What to pass in. What constitutes a passing result. Loop/retry condition and max iteration count (e.g. "max 5 fix-and-retry iterations, then surface to human").]

## Step 2: [Speckit action name]
Run /speckit.<command> with [specific argument derived from Step 1 output].
[What file is produced. Where it is saved.]

## Step 3: [Verify]
[Specific check command confirming the artifact is correct — e.g. grep count, test run, curl output.
If check fails: which step to loop back to, or "surface to human after N iterations".]

[Add ## Step 4:, ## Step 5:, etc. as needed for commands with multiple gates]

## Output
- [Artifact 1]: [exact path]
- [Artifact 2]: [exact path]
- Jira: [what was created/updated, or "none" for utility commands with no Jira action]
- Next command: /mhg.<next>  (or "none" for terminal commands)
```

The `allowed-tools` frontmatter ensures every command has access to Bash (for git/verify commands), file tools, and the Skill and Agent tools (for superpowers invocations and subagent dispatch). Note: `Skill` here refers to the Claude Code built-in Skill tool (which invokes plugin skills by name), not a placeholder for MCP tool identifiers.

---

## Error Handling

| Failure | Behaviour |
|---|---|
| `spec-document-reviewer` finds issues | Fix `spec.md`, re-dispatch reviewer — max 5 iterations, then surface to human |
| Clarify loop exhausted (3 rounds without reaching 0 `[NEEDS CLARIFICATION]` markers) | Stop, surface to human with current `spec.md` and the unresolved markers listed — do not proceed to `/mhg.plan` |
| `spec-document-reviewer` in `mhg.clarify` exceeds 5 iterations | Stop, surface to human with current `spec.md` and reviewer output — do not proceed to `/mhg.plan` |
| `plan-document-reviewer` finds issues | Fix `plan.md`, re-dispatch reviewer — max 5 iterations, then surface to human |
| `speckit.analyze` reports inconsistencies | Fix targeted artifacts — max 3 fix rounds; if inconsistencies persist after 3 rounds, surface to human — do not proceed to Jira issue creation |
| Implementer spec-reviewer or quality-reviewer exceeds 3 cycles | Stop the task, surface to human with reviewer output — do not attempt a 4th cycle |
| `code-review:code-review` never returns 0 issues after 5 review rounds | Stop, surface to human with the review output and the list of unresolved issues — do not push or merge |
| Regression fix loop in `mhg.ship` Phase 4 does not converge after 3 `systematic-debugging` cycles | Stop, surface to human with the unresolved regression evidence — do not declare Phase 4 exit |
| `verification-before-completion` finds test failures | Invoke `systematic-debugging` before any fix attempt — no shotgun patches |
| Jira transition fails (API unavailable) | Append `[PENDING: ...]` marker to task line per speckit.sync convention — continue; sync retroactively |
| Missing prerequisites (e.g. no `spec.md`) | Print `"Error: <item> not found. Run /mhg.<prior-command> first."` and stop |
| Brainstorming produces no output file | Print `"Error: brainstorming design doc not found in docs/superpowers/specs/. Complete the brainstorming step before proceeding."` and stop — do not call `/speckit.specify` with an empty description |

---

## Files to Create

| File | Description |
|---|---|
| `.claude/commands/mhg.specify.md` | brainstorming → speckit.specify → spec-doc-reviewer → clarify |
| `.claude/commands/mhg.plan.md` | speckit.plan → plan-doc-reviewer |
| `.claude/commands/mhg.tasks.md` | speckit.tasks → speckit.analyze → Jira |
| `.claude/commands/mhg.implement.md` | per-task subagent loop with 4 gates |
| `.claude/commands/mhg.clarify.md` | speckit.clarify → spec-doc-reviewer |
| `.claude/commands/mhg.analyze.md` | speckit.analyze as constitution report |
| `.claude/commands/mhg.review.md` | requesting-code-review → code-review → receiving-code-review |
| `.claude/commands/mhg.debug.md` | systematic-debugging |
| `.claude/commands/mhg.sync.md` | speckit.sync pass-through |
| `.claude/skills/mhg.ship/SKILL.md` | Updated in place — v2.0.0 (done) |

---

## Constraints and Non-Goals

- `mhg.ship` stays as the shipping phase entry point — the new commands cover the development phase only
- No new plugins, no new repos — all command files live in `.claude/commands/` of `client-spec`
- The original speckit commands (`/speckit.specify`, `/speckit.plan`, etc.) are unchanged — wrappers call them, not replace them
- `mhg.sync` is a thin pass-through — `speckit.sync` already handles Jira reconciliation well
- `superpowers:brainstorming` writes its design doc to `docs/superpowers/specs/` — do not change this path; the wrapper reads from it
- Constitution Principles X (Jira) and XI (Confluence) remain enforced by speckit — the wrappers do not duplicate this logic

---

## Success Criteria

- A developer can run `/mhg.specify "feature description"` and reach a reviewed, Jira-tracked `spec.md` without manually invoking any superpowers skill
- A developer can run `/mhg.implement` and have every task gate-checked (spec compliance + quality + test evidence) before `[X]` is written
- The ship pipeline (`/mhg.ship`) exits each phase gate only after showing command output (curl response body, test pass count, console log, or network log) — no phase gate may be declared cleared with a prose assertion alone
- All 9 command files (`.claude/commands/mhg.*.md`) and the updated `mhg.ship` skill (`.claude/skills/mhg.ship/SKILL.md`) are committed to `client-spec` and available to other developers on pull

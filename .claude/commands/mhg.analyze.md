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

# MHG Activity Report — Markdown Template

## Title Format

```
Activity Report — <Month D, YYYY>
```

Examples: `Activity Report — March 10, 2026`, `Activity Report — March 24, 2026`

The period is always a 2-week window ending on the report date. Start date = report date minus 14 days.

---

## Full Markdown Template

```markdown
# Activity Report — <Month D, YYYY>

**Period:** <Month D> – <Month D, YYYY>
**Generated:** <YYYY-MM-DD>

---

## Part 1 — Non-Technical Summary

This report covers two weeks of product development. [1-2 sentence overview of what happened.]

### <STATUS_EMOJI> <Feature Name> — <STATUS_LABEL> ([<JIRA_KEY>](https://mentalhelpglobal.atlassian.net/browse/<JIRA_KEY>))

[2-3 sentence plain-English description of what the feature does for end users.]

**Business value:** [Why this matters. What manual process it replaces or what risk it mitigates. Be specific.]

---

[Repeat the above block for each feature in the period]

---

## Part 2 — Technical Summary

### <NNN> — <Feature Name> (<task_count> tasks, <STATUS_LABEL>)

[Repo scope: list the repos that changed.]

Key deliverables:
- **`EntityName`** [description] in `repo/src/path/file.ts`
- **`ComponentName`** [description] (`repo/src/path/`)
- **Jira Epic**: [<JIRA_KEY>](https://mentalhelpglobal.atlassian.net/browse/<JIRA_KEY>)

---

[Repeat for each feature]

---

*Report generated from Jira (mentalhelpglobal.atlassian.net) and speckit task tracking files.*
```

---

## Status Emoji and Labels

| Condition | Emoji | Label |
|---|---|---|
| All tasks complete | ✅ | `COMPLETE` |
| Implemented, final steps remain | 🔄 | `IN PROGRESS` |
| Spec/backlog created, no implementation | 📋 | `PLANNED` |

## Non-Technical Summary — Writing Guide

Write **plain English** for a non-engineering audience (clinical coordinators, project managers, executives):

- Lead with what users can now **do** (capabilities unlocked), not what was built
- Name specific roles: "researchers", "officers", "clinical coordinators" — not "users"
- Business value must be **concrete**: state what process it replaces, what risk it eliminates, or what incident it prevents
- For IN PROGRESS features: list the three sub-features as numbered items, note what remains
- For PLANNED features: state what spec/backlog was created and what the trigger was (incident, UX feedback, etc.)

## Technical Summary — Writing Guide

Write for engineers who need to find and understand the code:

- List all repos touched (from tasks.md Phase 2 tasks)
- Each bullet should name the exact **entity, service, component, or hook** and its file path
- For IN PROGRESS: add a "**Remaining (TXXX–TXXX):**" bullet with what's left
- Always end with the **Jira Epic** link

## Period Calculation

| Report date | Period start | Period label |
|---|---|---|
| March 10 | February 24 | February 24 – March 10, 2026 |
| March 24 | March 10 | March 10 – March 24, 2026 |
| April 7 | March 24 | March 24 – April 7, 2026 |

The biweekly cadence follows speckit sprint boundaries. Adjust if a sprint boundary shifted.

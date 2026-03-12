---
name: mhg.activity-report-refresh
description: >
  This skill should be used when the user asks to "refresh the activity report",
  "update the activity report", "update the March report", "re-publish the report",
  "the report needs updating", or "add the new feature to the activity report".
  Finds an existing MHG activity report page in Confluence by title or page ID,
  re-reads the current speckit task completion state and Jira epics, then overwrites
  the page with an updated version while preserving the report date and period.
version: 1.0.0
---

# MHG Activity Report — Refresh Skill

Update an existing MHG activity report Confluence page with the latest task completion
state, new features added since the original publication, and any status changes.
Applicable when a feature status changed, task counts shifted, a new feature appeared,
or content needs correcting after the original report was published.

## Workflow

### Step 1 — Identify the target report page

**If the user provides a date or title**, search for it:

```
searchConfluenceUsingCql(
  cloudId = "3aca5c6d-161e-42c2-8945-9c47aeb2966d",
  cql     = 'title = "Activity Report — March 10, 2026" AND space = "UD"'
)
```

**If the user provides a page ID directly**, skip the search.

**If neither**, list recent reports and ask which one to update:

```
searchConfluenceUsingCql(
  cloudId = "3aca5c6d-161e-42c2-8945-9c47aeb2966d",
  cql     = 'parent = 19267585 AND type = page ORDER BY created DESC'
)
```

Capture the `pageId` and current `version.number` from the result — both are required for the update call.

### Step 2 — Fetch the current page content

```
getConfluencePage(
  cloudId       = "3aca5c6d-161e-42c2-8945-9c47aeb2966d",
  pageId        = "<pageId>",
  contentFormat = "markdown"
)
```

Read the existing content to understand:
- Which features are currently listed
- Current task counts and status labels
- The original report period (do NOT change the period dates)
- Any manually added notes that should be preserved

### Step 3 — Re-read speckit data

Repeat the same data-gathering as the create skill (Steps 2–3):

1. Re-read `specs/*/tasks.md` and recount `[x]` vs total tasks for every feature
2. Re-fetch Jira epics for status confirmation
3. Check for any new `specs/` directories created since the original report date

Identify **what changed** since the original publication:
- Task count increases (e.g., `43/53` → `53/53`)
- Status changes (IN PROGRESS → DONE)
- New features added to speckit/Jira

### Step 4 — Compose the updated report

Produce the full updated markdown (not a diff — the `updateConfluencePage` API replaces the entire body):

- Preserve the original **Period** and **Generated** date in the header
- Update task counts, status labels, and status emojis
- Add any new features that appeared mid-period
- Keep the two-part structure (Non-Technical + Technical)
- Preserve any manually written paragraphs from the current page unless they are factually outdated

**Add a refresh note** at the top (after the header, before Part 1):

```markdown
> **Updated:** <YYYY-MM-DD> — [brief description of what changed, e.g., "021 marked DONE; task count updated to 53/53"]
```

### Step 5 — Update the Confluence page

```
updateConfluencePage(
  cloudId        = "3aca5c6d-161e-42c2-8945-9c47aeb2966d",
  pageId         = "<pageId>",
  version        = <current version.number + 1>,
  title          = "<same title as before — do not change>",
  body           = "<updated markdown>",
  contentFormat  = "markdown",
  versionMessage = "Refreshed <YYYY-MM-DD>: <brief change summary>"
)
```

**Critical**: `version` must be `current version.number + 1`. If the current version is `1`, pass `2`. Confluence will reject the update if the version is wrong.

### Step 6 — Confirm to user

Return:
- The Confluence URL of the updated page
- A bullet list of what changed: feature status changes, task count updates, new additions
- The new version number

## Handling Edge Cases

**Page not found**: If the search returns no results, do not create a new page. Inform the user that no report was found for that date and offer to run the `mhg.activity-report` create skill instead.

**Version conflict** (HTTP 409): Fetch the page again to get the latest version number, then retry the update once.

**No changes detected**: If re-reading speckit and Jira shows no differences from the current page content, tell the user "No changes detected since publication" and skip the update.

**Preserving manual edits**: If the existing page has content not derivable from speckit/Jira (e.g., a note about an incident added manually), carry it forward into the updated version. Do not silently delete paragraphs.

## References

- **`references/confluence-config.md`** — Refresh-specific CQL search patterns; also points to the shared config in `mhg.activity-report/references/confluence-config.md` for Confluence IDs, page hierarchy, and speckit data-source guidance

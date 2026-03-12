---
name: mhg.activity-report
description: >
  This skill should be used when the user asks to "generate the activity report",
  "create the activity report", "publish the biweekly report", "write the report for this period",
  "create the MHG activity report", or "publish the sprint report to Confluence".
  Synthesizes completed/in-progress/planned features from speckit tasks.md files and Jira epics,
  then publishes a formatted two-part (non-technical + technical) report to the MHG Confluence space.
version: 1.0.0
---

# MHG Activity Report — Create Skill

Generate and publish a biweekly MHG development activity report to Confluence.
The report covers a 2-week period, synthesizes data from speckit `tasks.md` files and Jira epics,
and creates two pages: an "Activity Reports" section parent (if missing) and the dated report child page.

## Workflow

Execute these steps in order:

### Step 1 — Confirm the report period

Determine the period from context or ask the user:
- **Report date**: today (`currentDate` from memory, or ask)
- **Period start**: report date minus 14 days
- **Title**: `Activity Report — <Month D, YYYY>` (e.g., `Activity Report — March 10, 2026`)

If the user provides specific feature names to include or exclude, note them before proceeding.

### Step 2 — Gather speckit data

Read the `specs/` directory to identify all features:

```
Glob("specs/*/tasks.md")   # find all task files
Glob("specs/*/spec.md")    # find specs without tasks yet
```

For each `tasks.md`, count:
- Total tasks: count lines matching `- [`
- Completed tasks: count lines matching `- [x]`
- Ratio: `completed/total`

Classify each feature's status using the rules in `references/confluence-config.md` (Status classification table).

For features without `tasks.md` but with `spec.md`, status = PLANNED.

Determine which features fall within the report period:
- DONE or IN PROGRESS features whose work overlapped the period
- PLANNED features whose spec was created during the period

### Step 3 — Gather Jira data

For each active feature, fetch the Jira epic to get:
- Epic key (e.g., `MTB-405`)
- Epic summary/title (for confirmation)
- Linked stories if needed for technical detail

Use:
```
getJiraIssue(cloudId="3aca5c6d-161e-42c2-8945-9c47aeb2966d", issueKey="MTB-XXX")
```

The Jira epic key for each feature is recorded in `specs/<NNN>/spec.md` (look for `MTB-` reference in the header or Jira section).

### Step 4 — Draft the report content

Compose the full report in Markdown following the template in `references/report-template.md`.

**Part 1 (Non-Technical):** one section per feature, plain-English description + business value paragraph.

**Part 2 (Technical):** one section per feature, repo scope + key deliverable bullets with file paths.

Order features as:
1. ✅ DONE features (most recently completed first)
2. 🔄 IN PROGRESS features
3. 📋 PLANNED features

### Step 5 — Verify the "Activity Reports" parent page exists

The parent page should already be at ID `19267585`. Confirm by fetching it:

```
getConfluencePage(
  cloudId = "3aca5c6d-161e-42c2-8945-9c47aeb2966d",
  pageId  = "19267585"
)
```

If the fetch fails (page deleted/not found), create a new parent under `8454317`:

```
createConfluencePage(
  cloudId       = "3aca5c6d-161e-42c2-8945-9c47aeb2966d",
  spaceId       = "8454147",
  parentId      = "8454317",
  title         = "Activity Reports",
  contentFormat = "markdown",
  body          = "This section contains biweekly activity reports summarising completed work, in-progress features, and planned backlog items."
)
```

Capture the returned `id` and use it as `parentId` in Step 6.

### Step 6 — Publish the report page

```
createConfluencePage(
  cloudId       = "3aca5c6d-161e-42c2-8945-9c47aeb2966d",
  spaceId       = "8454147",
  parentId      = "19267585",
  title         = "Activity Report — <Month D, YYYY>",
  contentFormat = "markdown",
  body          = <drafted markdown from Step 4>
)
```

### Step 7 — Return results

Report back to the user with:
- The Confluence URL of the new page (`_links.webui` from the response, prefixed with `https://mentalhelpglobal.atlassian.net/wiki`)
- A one-line summary: features DONE, IN PROGRESS, PLANNED counts
- Any Jira links that were not resolved (so user can verify manually)

## Key Rules

- **Never hardcode feature content** — always read from `tasks.md` and Jira at execution time
- **Non-technical section first** — Part 1 is for stakeholders; avoid code references there
- **File paths in Part 2** — every key deliverable should include the repo-relative file path
- **Period accuracy** — confirm the 14-day window before publishing; get user confirmation if unsure
- **Idempotency** — before creating, search for an existing page with the same title to avoid duplicates:
  ```
  searchConfluenceUsingCql(
    cloudId = "3aca5c6d-161e-42c2-8945-9c47aeb2966d",
    cql     = 'title = "Activity Report — March 10, 2026" AND space = "UD"'
  )
  ```
  If a page already exists for this date, offer to use the refresh skill instead.

## References

- **`references/confluence-config.md`** — Fixed Confluence IDs, page hierarchy, data source guidance
- **`references/report-template.md`** — Full markdown template, writing guide for both parts, period calculation table

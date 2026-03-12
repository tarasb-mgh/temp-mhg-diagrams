# Confluence Configuration — Security Audit

## Fixed IDs

| Field | Value |
|-------|-------|
| Cloud ID | `3aca5c6d-161e-42c2-8945-9c47aeb2966d` |
| Space Key | `UD` |
| Space ID | `8454147` |

## Security Audits Parent Page

On first run:
1. Search for a page titled `"Security Audits"` in space `UD`:
   ```
   searchConfluenceUsingCql(
     cql = 'title = "Security Audits" AND space = "UD"'
   )
   ```
2. If not found: create it under the space root with `title = "Security Audits"` and minimal body.
3. Record the returned `pageId` as the `parentId` for all future audit pages.

Once created, the Security Audits parent page ID should be stored here:
```
parentId: 21430273
```

## Audit Page Title Format

```
Security Audit — YYYY-MM-DD
```

Example: `Security Audit — 2026-03-12`

## CQL Patterns

### Find existing audit page for today
```
title = "Security Audit — 2026-03-12" AND space = "UD"
```

### Find all audit pages
```
title ~ "Security Audit —" AND space = "UD" AND ancestor = "<parentId>"
```

### Find most recent audit page
```
title ~ "Security Audit —" AND space = "UD" ORDER BY lastModified DESC
```

## Workflow for Phase 7 Publish

```
1. Determine today's date → title = "Security Audit — YYYY-MM-DD"

2. Search:
   searchConfluenceUsingCql(cql = 'title = "Security Audit — YYYY-MM-DD" AND space = "UD"')

3a. If results empty → create:
    createConfluencePage(
      spaceId = "8454147",
      parentId = <Security Audits parent page ID>,
      title = "Security Audit — YYYY-MM-DD",
      body = <formatted report>
    )

3b. If results found → update:
    updateConfluencePage(
      pageId = results[0].id,
      version = results[0].version.number + 1,
      title = "Security Audit — YYYY-MM-DD",
      body = <formatted report>
    )

4. Return page URL to user:
   https://mentalhelpglobal.atlassian.net/wiki/spaces/UD/pages/<pageId>
```

## Content Format

Use the Confluence storage format body as provided by the `createConfluencePage` /
`updateConfluencePage` MCP tools. Refer to `report-template.md` for the full
page layout including heading hierarchy and table structures.

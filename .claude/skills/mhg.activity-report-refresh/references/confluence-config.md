# MHG Confluence Configuration (Refresh Skill)

The primary reference for fixed Confluence coordinates, page hierarchy, and speckit data-source guidance lives in the shared file:

```
.claude/skills/mhg.activity-report/references/confluence-config.md
```

Load that file when you need `cloudId`, `spaceId`, page IDs, the hierarchy diagram, status classification rules, or task completion counting patterns.

## Refresh-Specific: CQL Search Patterns

**Find a report by date (exact title match):**
```
cloudId = "3aca5c6d-161e-42c2-8945-9c47aeb2966d"
cql     = 'title = "Activity Report — March 10, 2026" AND space = "UD"'
```

**List all reports, most recent first:**
```
cloudId = "3aca5c6d-161e-42c2-8945-9c47aeb2966d"
cql     = 'parent = 19267585 AND type = page ORDER BY created DESC'
```

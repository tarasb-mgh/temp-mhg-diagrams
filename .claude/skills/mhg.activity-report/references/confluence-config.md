# MHG Confluence Configuration

## Fixed Coordinates

| Parameter | Value |
|---|---|
| `cloudId` | `3aca5c6d-161e-42c2-8945-9c47aeb2966d` |
| `spaceId` | `8454147` (User Documentation space, key `UD`) |
| MHG Documentation root | page ID `8454317` |
| Activity Reports parent | page ID `19267585` |
| Jira base URL | `https://mentalhelpglobal.atlassian.net` |
| Jira project key | `MTB` |

## Page Hierarchy

```
User Documentation (space UD)
└── MHG Documentation [8454317]
    └── Activity Reports [19267585]
        └── Activity Report — <Month D, YYYY>   ← new pages go here
```

## Speckit Data Sources

Activity reports synthesize two sources:

1. **Jira** — epics via `getJiraIssue` or `searchJiraIssuesUsingJql` with `project = MTB`
2. **Speckit tasks.md** — `specs/<NNN-feature-name>/tasks.md` files in `D:\src\MHG\client-spec\specs\`

### Counting task completion from tasks.md

A completed task line looks like: `- [x] T001 ...`
An open task line looks like: `- [ ] T001 ...`

Count `[x]` vs total `- [` lines to get the ratio (e.g., `43/53`).

### Feature status classification

| Condition | Status |
|---|---|
| All tasks `[x]` | ✅ DONE |
| Some tasks `[x]`, remaining are PRs/smoke/docs | 🔄 IN PROGRESS |
| tasks.md exists but no `[x]` yet | 📋 PLANNED |
| Only spec.md exists, no tasks.md | 📋 PLANNED |

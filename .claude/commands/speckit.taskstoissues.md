---
description: Convert existing tasks into actionable, dependency-ordered issues in GitHub and/or Jira for the feature based on available design artifacts.
tools: ['github/github-mcp-server/issue_write']
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Outline

1. Run `.specify/scripts/powershell/check-prerequisites.ps1 -Json -RequireTasks -IncludeTasks` from repo root and parse FEATURE_DIR and AVAILABLE_DOCS list. All paths must be absolute. For single quotes in args like "I'm Groot", use escape syntax: e.g 'I'\''m Groot' (or double-quote if possible: "I'm Groot").
1. From the executed script, extract the path to **tasks**.
1. **Determine target platforms**: Check which issue trackers to use:
   - **GitHub**: Get the Git remote by running `git config --get remote.origin.url`. If the remote is a GitHub URL, GitHub issue creation is available.
   - **Jira**: Check if the spec.md header contains a `**Jira Epic**:` line with a valid key (not `PENDING`). If present, Jira issue creation is available via the Atlassian MCP.
   - If both are available, create issues in **both** platforms by default. If user input specifies a preference (e.g., "jira only", "github only"), respect it.

### GitHub Issue Creation

> [!CAUTION]
> ONLY PROCEED IF THE REMOTE IS A GITHUB URL

4. For each task in the list, use the GitHub MCP server to create a new issue in the repository that is representative of the Git remote.

> [!CAUTION]
> UNDER NO CIRCUMSTANCES EVER CREATE ISSUES IN REPOSITORIES THAT DO NOT MATCH THE REMOTE URL

### Jira Issue Creation (Constitution Principle X)

5. If Jira Epic key is available:

   a. **Extract context**: Read the Jira Epic key from spec.md header. Use
      `getJiraProjectIssueTypesMetadata` to confirm available issue types.

   b. **Create Jira Stories**: For each user story phase (Phase 3+) in
      tasks.md, create a Jira Story parented under the Epic (skip if a Story
      for this user story already exists — check with
      `searchJiraIssuesUsingJql`).

   c. **Create Jira Tasks**: For each implementation task, create a Jira Task
      parented under the corresponding Story.

   d. **Annotate tasks.md**: Append Jira keys to each task line after the
      description (e.g., `— MHG-456`).

   e. **Post summary comment on Epic**: Add a comment listing all created
      issues with keys and summaries.

   f. **Error handling**: If Atlassian MCP is unavailable, warn and skip Jira
      creation. Record `JIRA: PENDING` next to unsynced tasks.

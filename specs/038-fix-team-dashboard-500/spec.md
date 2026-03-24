# Bug Specification: Team Dashboard 500 Internal Server Error

**Feature Branch**: `038-fix-team-dashboard-500`
**Created**: 2026-03-24
**Status**: Draft
**Severity**: High
**Jira Epic**: MTB-944
**Related Feature**: 036-review-dashboard-redesign (MTB-832)
**Affected Endpoint**: `GET /api/review/dashboard/team?period=week`

## Problem Statement

The Team Dashboard page (`/workbench/review/team`) fails to load with a 500 Internal Server Error when fetching team statistics. The backend returns:

```json
{
  "success": false,
  "error": {
    "code": "INTERNAL_ERROR",
    "message": "Failed to fetch team dashboard stats"
  }
}
```

The error is reproducible on the dev environment (`https://api.workbench.dev.mentalhelp.chat`) for **all period values** (`today`, `week`, `month`, `all`) — the response body is identical across all four. This rules out period-specific date range computation as the root cause and points to a systemic issue in the endpoint (e.g., group context resolution, query construction, or null handling).

### Evidence

- **Request URL**: `https://api.workbench.dev.mentalhelp.chat/api/review/dashboard/team?period=week`
- **Request Method**: GET
- **Status Code**: 500 Internal Server Error
- **Response Body**: `{ "success": false, "error": { "code": "INTERNAL_ERROR", "message": "Failed to fetch team dashboard stats" } }`
- **Environment**: Dev (localhost:5174 → api.workbench.dev.mentalhelp.chat)
- **Account**: Owner role (Pavel M., Dev team space)
- **Observed**: Two consecutive 500 responses visible in network tab
- **All periods affected**: `today`, `week`, `month`, `all` — identical 500 response
- **Personal dashboard OK**: `GET /api/review/dashboard/me` returns 200 for the same user — problem isolated to `getTeamStats` logic

## User Scenarios & Testing

### User Story 1 — Senior Reviewer views Team Dashboard (Priority: P1)

A senior reviewer or owner navigates to the Team Dashboard page to view team-wide review statistics for the current week. The page must load successfully and display KPI cards, queue depth, and reviewer workload data.

**Why this priority**: The Team Dashboard is the primary supervisory tool for senior reviewers. A 500 error makes it completely unusable — no data is visible, no fallback is available.

**Independent Test**: Navigate to `/workbench/review/team`, select "This Week" period, and verify the page loads with team stats or an appropriate empty state (if no data exists for the period).

**Acceptance Scenarios**:

1. **Given** a user with `REVIEW_TEAM_DASHBOARD` permission, **When** they navigate to Team Dashboard with `period=week`, **Then** the API returns 200 with `TeamDashboardStats` data (or valid empty stats), and the UI renders KPI cards
2. **Given** the same request, **When** there are no reviews for the selected period, **Then** the API returns 200 with zeroed-out stats (totalReviews=0, averageTeamScore=null, etc.), NOT a 500 error
3. **Given** the same request, **When** the backend encounters a transient database error, **Then** the API returns 500 with a meaningful error message AND the frontend shows a retry-capable error state

---

### User Story 2 — Team Dashboard works across all periods (Priority: P1)

The Team Dashboard must return valid data for all four supported period values: `today`, `week`, `month`, `all`.

**Why this priority**: If the bug is period-specific (e.g., only `week` fails), other periods may also be affected by the same root cause. All periods must be validated.

**Independent Test**: Issue `GET /api/review/dashboard/team?period=<P>` for each of `today`, `week`, `month`, `all` and verify each returns 200.

**Acceptance Scenarios**:

1. **Given** a valid authenticated request, **When** `period=today`, **Then** the API returns 200 with team stats scoped to today
2. **Given** a valid authenticated request, **When** `period=week`, **Then** the API returns 200 with team stats scoped to the current week
3. **Given** a valid authenticated request, **When** `period=month`, **Then** the API returns 200 with team stats scoped to the current month
4. **Given** a valid authenticated request, **When** `period=all`, **Then** the API returns 200 with team stats for all time

---

### Edge Cases

- What happens when the team has zero reviewers assigned? (should return empty `reviewerWorkload` array, not 500)
- What happens when the group/space has no review sessions at all? (should return zeroed stats)
- What happens when `period` query param is missing? (should default to `month` per API contract)
- What happens when `period` has an invalid value? (should return 400 Bad Request, not 500)

## Requirements

### Functional Requirements

- **FR-001**: The `GET /api/review/dashboard/team` endpoint MUST return 200 with valid `TeamDashboardStats` for all supported period values (`today`, `week`, `month`, `all`)
- **FR-002**: When no review data exists for the selected period, the endpoint MUST return 200 with zeroed/null default values — NOT a 500 error
- **FR-003**: The endpoint MUST handle edge cases (empty team, no sessions, null aggregations) without throwing unhandled exceptions
- **FR-004**: *(Deferred to 036)* Frontend retry/error UX — out of scope for this fix
- **FR-005**: Backend error logging MUST include the specific cause of failure (e.g., null pointer, query error, missing data) to aid debugging
- **FR-006**: Unit tests MUST cover `getTeamStats` for: (a) zero reviews / empty group, (b) normal data with multiple reviewers, (c) null aggregation values (e.g., no scores → averageTeamScore=null)

### Key Entities

- **TeamDashboardStats**: The response payload containing `totalReviews`, `averageTeamScore`, `interRaterReliability`, `pendingEscalations`, `pendingDeanonymizations`, `reviewerWorkload[]`, `queueDepth` — as defined in spec 036 data model
- **DashboardPeriod**: Enum `'today' | 'week' | 'month' | 'all'` — the `period` query parameter

## Clarifications

### Session 2026-03-24

- Q: Should frontend improvements (retry button, error handling) be in scope? → A: Backend only. Frontend UX deferred to 036-review-dashboard-redesign (T024).
- Q: Does only `period=week` fail, or all periods? → A: All 4 periods (today, week, month, all) return 500 with identical response body. The issue is not period-specific.
- Q: Does the personal dashboard (`/me`) work? → A: Yes, `/me` returns 200 for the same user. The problem is isolated to `getTeamStats` logic, not shared infrastructure.
- Q: Does the "Dev team" group have any reviews? → A: Unknown — must be verified during investigation. If no reviews exist, the likely cause is unhandled empty-data aggregation.
- Q: Should unit tests be added for `getTeamStats`? → A: Yes. Add unit tests covering empty data and normal data scenarios to prevent regression.

## Likely Root Causes (Investigation Targets)

### Diagnostic Steps (before fix)

1. Check backend logs (Cloud Run / Cloud Logging) for the actual exception stack trace from `/api/review/dashboard/team`
2. Verify whether "Dev team" group has any review sessions / completed reviews — test with a group known to have reviews
3. If empty group → confirm the fix handles zero-review aggregation; if populated group also fails → root cause is elsewhere

### Prioritized Root Causes

All 4 periods fail identically, so period-specific causes (date range math) are ruled out. Prioritized by likelihood:

1. **Missing group/space context**: The endpoint may fail to resolve the team's group context from the authenticated user's session — affects all queries regardless of period
2. **Null aggregation in SQL/query**: If no reviews exist at all, aggregate functions (AVG, COUNT) may return null and the code may not handle it, causing a runtime exception on every period
3. **Division by zero**: `interRaterReliability` or `averageTeamScore` calculation may divide by zero when `totalReviews=0`
4. **reviewerWorkload query failure**: The per-reviewer breakdown query may fail when there are no reviewers with activity
5. ~~**Date range computation**~~: Ruled out — all periods fail identically

## Success Criteria

### Measurable Outcomes

- **SC-001**: `GET /api/review/dashboard/team?period=week` returns 200 on the dev environment for an Owner-role user
- **SC-002**: All four period values (`today`, `week`, `month`, `all`) return 200 with valid response shapes matching the `TeamDashboardStats` contract
- **SC-003**: *(Deferred to 036)* Frontend rendering validation — out of scope for this fix
- **SC-004**: When no data exists for a period, the page shows zeroed KPIs or an empty state — not an error message
- **SC-005**: Backend logs include structured error details for any legitimate failures (no silent swallowing of exceptions)
- **SC-006**: Unit tests for `getTeamStats` pass in CI — covering empty data, normal data, and null aggregation scenarios

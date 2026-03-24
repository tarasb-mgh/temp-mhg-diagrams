# Implementation Plan: Fix Team Dashboard 500

**Branch**: `038-fix-team-dashboard-500` | **Date**: 2026-03-24 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/038-fix-team-dashboard-500/spec.md`

## Summary

The `GET /api/review/dashboard/team` endpoint returns 500 Internal Server Error for all period values. The root cause is in `chat-backend/src/services/reviewDashboard.service.ts` — the `getTeamStats` function. After code analysis, three bugs have been identified: (1) the IRR query can produce `NULL` values that become `NaN` in JavaScript, (2) the workload query uses `$1` parameter placeholder in a FILTER clause but the parameter may not exist when `period=all`, and (3) the function lacks defensive null handling for edge cases. The fix involves hardening `getTeamStats` with proper null/NaN guards and adding unit tests.

## Technical Context

**Language/Version**: TypeScript (Node.js) on Express.js
**Primary Dependencies**: `pg` (PostgreSQL client), `@mentalhelpglobal/chat-types`
**Storage**: PostgreSQL (Cloud SQL)
**Testing**: Vitest (unit tests pattern: `tests/unit/*.test.ts`)
**Target Platform**: Cloud Run (GCP)
**Project Type**: Web service (backend API)
**Constraints**: Backend-only fix; no frontend changes (deferred to 036)

## Constitution Check

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Spec-First | PASS | Spec created before plan |
| II. Multi-Repo | PASS | Single repo affected (`chat-backend`) |
| III. Test-Aligned | PASS | Vitest unit tests will be added |
| IV. Branch Discipline | PASS | Feature branch `038-fix-team-dashboard-500` from `develop` |
| V. Privacy/Security | N/A | No user data changes |
| VI. Accessibility/i18n | N/A | Backend-only |
| VI-B. Design System | N/A | Backend-only |
| VII. Split-Repo First | PASS | Work in `chat-backend` split repo |
| VIII. GCP CLI | N/A | No infra changes |
| IX. Responsive/PWA | N/A | Backend-only |
| X. Jira Traceability | PASS | Will create Jira tasks |
| XI. Documentation | N/A | No user-facing changes requiring doc updates |
| XII. Release Engineering | PASS | Standard PR → develop flow |

## Root Cause Analysis

### Code under investigation

**File**: `chat-backend/src/services/reviewDashboard.service.ts` — `getTeamStats()` (lines 191–307)
**Route**: `chat-backend/src/routes/review.dashboard.ts` — `/team` handler (lines 53–69)

### Identified bugs

#### Bug 1: IRR NaN propagation (HIGH — likely crash cause)

The inter-rater reliability query (lines 220–228) groups by `session_id` and computes `AVG(1.0 - (VARIANCE(sr.average_score) / 81.0))`. When a session has exactly 2 identical scores, `VARIANCE()` returns `0` (valid). But if a session has only 1 completed review after the `HAVING COUNT(*) >= 2` filter with mixed statuses, PostgreSQL's `VARIANCE()` of a single value returns `NULL`.

The JavaScript code (lines 233–236):
```typescript
const irrValues = irrResult.rows.map((r: any) => Number(r.irr));
```

`Number(null)` → `0`, which is actually handled. However, if the SQL `AVG()` itself returns `NULL` for a row (which happens when `VARIANCE()` is `NULL`), then `1.0 - (NULL / 81.0)` = `NULL` in SQL, and `AVG(NULL)` = `NULL`. `Number(null)` = `0` in JS. So this path may not be the direct crash.

**Real issue**: The workload query (Bug 2) or a database connection/table issue is the more likely crash cause. Need Cloud Logging to confirm.

#### Bug 2: Workload query FILTER with conditional parameter (HIGH)

Lines 256–270: The workload query uses `$1` in a `FILTER` clause:
```sql
COUNT(*) FILTER (WHERE sr.status = 'completed' AND sr.completed_at >= $1)::int AS reviews_completed
```

When `period=all`, `dateFilter` is `null`, `workloadParams` is `[]` (empty), and `workloadCompletedCondition` is `''`. The SQL becomes:
```sql
COUNT(*) FILTER (WHERE sr.status = 'completed' )::int AS reviews_completed
```
This is syntactically valid — the extra space is harmless. So this is not the crash cause either.

However, when `period` is NOT `all`, the query passes `[dateFilter]` as params, and the SQL correctly uses `$1`. This also appears correct.

#### Bug 3: Missing table or column on dev database

If any of the tables (`risk_flags`, `deanonymization_requests`, `sessions.review_status`) haven't had their migrations run on the dev database, the queries will throw a PostgreSQL error caught by the try/catch and returned as the generic 500.

**This is the most likely cause**: The error is identical across all periods, which means it fails on the first query or a table-level issue. The `getReviewerStats` (`/me`) works because it only queries `session_reviews`, `message_ratings`, and `criteria_feedback` — never `risk_flags` or `deanonymization_requests`.

#### Bug 4: NaN safety gap (MEDIUM — defensive)

Even if the IRR path doesn't crash today, `Number(r.irr)` when `r.irr` is `null` produces `0`, but `Math.round(NaN * 100)` would produce `NaN` if the avg calculation ever encounters `NaN`. This is a latent bug that should be hardened.

### Investigation & Fix Strategy

1. **Diagnose**: Check Cloud Run logs for the actual exception stack trace to confirm which query fails
2. **Fix**: Add defensive error handling around each individual query in `getTeamStats` so one failing query doesn't crash the entire endpoint
3. **Harden**: Add null/NaN guards on all computed values
4. **Test**: Add unit tests mocking `getPool` to verify behavior with empty data, normal data, and null aggregations

## Project Structure

### Documentation (this feature)

```text
specs/038-fix-team-dashboard-500/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Root cause analysis findings
└── tasks.md             # Task breakdown (via /speckit.tasks)
```

### Source Code (chat-backend)

```text
chat-backend/
├── src/
│   ├── services/
│   │   └── reviewDashboard.service.ts  # FIX: getTeamStats null/error handling
│   └── routes/
│       └── review.dashboard.ts         # FIX: improved error logging
└── tests/
    └── unit/
        └── reviewDashboard.team.test.ts # NEW: unit tests for getTeamStats
```

## Implementation Approach

### Phase 1: Diagnose (before code changes)

1. Check Cloud Run logs for the actual exception from `getTeamStats`
2. Verify all required tables exist on dev database (`risk_flags`, `deanonymization_requests`, `sessions.review_status`)
3. Test the endpoint with curl against dev API to confirm reproducibility

### Phase 2: Fix `getTeamStats`

The fix strategy depends on the diagnosed root cause, but regardless, the following hardening applies:

**In `reviewDashboard.service.ts`**:

1. Wrap each of the 6 query blocks in individual try/catch with fallback defaults:
   - Summary (totalReviews, averageTeamScore) → defaults: `0`, `null`
   - IRR → default: `0`
   - Pending escalations → default: `0`
   - Pending deanonymizations → default: `0`
   - Reviewer workload → default: `[]`
   - Queue depth → default: all `0`

2. Add NaN guard on IRR calculation:
   ```typescript
   const irrValues = irrResult.rows
     .map((r: any) => Number(r.irr))
     .filter((v: number) => !isNaN(v));
   ```

3. Add structured error logging with query identification:
   ```typescript
   console.error('[getTeamStats] Query N failed:', error);
   ```

**In `review.dashboard.ts`**:

4. Enhance error logging to include period and any available context:
   ```typescript
   console.error('[Review Dashboard] Error fetching team stats:', { period, error });
   ```

### Phase 3: Unit Tests

**New file**: `tests/unit/reviewDashboard.team.test.ts`

Following the pattern from `reviewQueue.scope.test.ts`:
- Mock `getPool` with `vi.mock`
- Test scenarios:
  - **Empty data**: All queries return empty/zero rows → verify valid response with defaults
  - **Normal data**: Queries return realistic data → verify correct aggregation
  - **Null aggregations**: AVG returns null, VARIANCE returns null → verify no NaN in response
  - **Partial failure**: One query throws → verify endpoint still returns (degraded) response or structured error

### Phase 4: Verify on Dev

1. Deploy to dev via standard PR → develop flow
2. Test all 4 periods: `today`, `week`, `month`, `all`
3. Verify response shape matches `TeamDashboardStats` contract
4. Verify Team Dashboard page loads in workbench frontend

## Cross-Repository Dependencies

None. This fix is entirely within `chat-backend`. No `chat-types` changes needed (response shape unchanged). No frontend changes (deferred to 036).

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Root cause is a missing migration, not code | Fix would be DB-level, not code | Diagnose first; run migrations if needed |
| Individual query try/catch masks real errors | Degraded data shown without user awareness | Log each failure; frontend will show data gaps |
| IRR calculation produces unexpected values | Misleading team metrics | Add bounds check (0–100 range) and NaN filter |

## Complexity Tracking

No constitution violations. Single-repo, single-service fix with unit tests.

# Research: Fix Team Dashboard 500

**Feature**: 038-fix-team-dashboard-500
**Date**: 2026-03-24

## Code Analysis

### Endpoint Flow

```
Request → reviewAuth → requireReviewTeamDashboard → handler → getTeamStats(period) → 6 SQL queries → response
```

The handler at `chat-backend/src/routes/review.dashboard.ts:53-69` has a single try/catch around `getTeamStats()`. Any unhandled exception in any of the 6 queries causes the entire endpoint to return 500.

### getTeamStats Query Breakdown

| # | Query | Tables | Period-filtered | Null risk |
|---|-------|--------|-----------------|-----------|
| 1 | Summary (total reviews, avg score) | `session_reviews` | Yes | Low — `COUNT` returns 0, `AVG` returns null (handled) |
| 2 | Inter-rater reliability | `session_reviews` | Yes | Medium — `VARIANCE` can return null; JS `Number(null)` = 0 |
| 3 | Pending escalations | `risk_flags` | No | **High** — table may not exist on dev |
| 4 | Pending deanonymizations | `deanonymization_requests` | No | **High** — table may not exist on dev |
| 5 | Reviewer workload | `session_reviews`, `users` | Yes (FILTER) | Low — COALESCE used |
| 6 | Queue depth | `sessions` | No | Medium — depends on `review_status` column |

### Key Observation: `/me` works but `/team` doesn't

`getReviewerStats` (the `/me` handler) queries:
- `session_reviews` ✓
- `message_ratings` ✓
- `criteria_feedback` ✓

`getTeamStats` (the `/team` handler) queries all of the above PLUS:
- `risk_flags` — only used in `/team`
- `deanonymization_requests` — only used in `/team`
- `sessions.review_status` — only used in `/team`

The fact that `/me` works but `/team` fails for all periods strongly suggests the error occurs in one of the three tables exclusive to `/team`.

### Migration Verification

The tables are created in migration `013_add_review_system.sql`:
- `risk_flags` — line 101
- `deanonymization_requests` — line 146

These tables exist in the migration files. If migrations have been run on dev, the tables should exist. If not, every query to these tables would throw `relation "risk_flags" does not exist`.

### Alternative Hypothesis: FILTER Clause Syntax

The workload query (Query 5) uses PostgreSQL `FILTER (WHERE ...)` syntax with string interpolation:

```sql
COUNT(*) FILTER (WHERE sr.status = 'completed' AND sr.completed_at >= $1)::int
```

When `period=all`, `workloadCompletedCondition` is empty string `''`, producing:

```sql
COUNT(*) FILTER (WHERE sr.status = 'completed' )::int
```

This is syntactically valid in PostgreSQL. Not the cause.

### NaN Propagation Path

The IRR calculation:
1. SQL: `AVG(1.0 - (VARIANCE(score) / 81.0))` per session
2. If VARIANCE is NULL (single-value group after HAVING filter edge case): `1.0 - NULL = NULL`, `AVG(NULL) = NULL`
3. JS: `Number(null) = 0`, then `0 / irrValues.length` — safe, produces 0
4. But if `Number()` receives `undefined` or non-numeric: `NaN`
5. `NaN` propagates through reduce, Math.round, Math.max/min

This is a latent bug but unlikely to cause the current 500 since the SQL result structure is stable.

## Recommended Fix

### Priority 1: Diagnose via Cloud Logging

Before any code changes, check Cloud Run logs for the actual stack trace. The error message "Failed to fetch team dashboard stats" is the generic catch-all — the real exception is logged by `console.error` on the line above.

### Priority 2: Defensive query isolation

Wrap each query block in its own try/catch with sensible defaults. This ensures partial data is returned even if one query fails:

```typescript
let pendingEscalations = 0;
try {
  const result = await pool.query(`SELECT COUNT(*)::int AS cnt FROM risk_flags WHERE status IN ('open', 'acknowledged')`);
  pendingEscalations = result.rows[0]?.cnt ?? 0;
} catch (err) {
  console.error('[getTeamStats] escalations query failed:', err);
}
```

### Priority 3: NaN guard on IRR

```typescript
const irrValues = irrResult.rows
  .map((r: any) => Number(r.irr))
  .filter((v: number) => Number.isFinite(v));
```

### Priority 4: Structured logging

Replace `console.error('[Review Dashboard] Error fetching team stats:', error)` with structured output including `period`, query stage, and error details.

## Technology Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Error isolation | Per-query try/catch | Prevents single query failure from crashing entire endpoint |
| Default values | Zeroed stats on failure | Better UX than 500; frontend can render empty state |
| Test framework | Vitest with `vi.mock` | Matches existing `reviewQueue.scope.test.ts` pattern |
| Logging | `console.error` with context | Matches existing backend logging pattern |

## Out of Scope

- Group/tenant scoping for team stats (functional gap, not a bug — requires product decision)
- Period filtering for escalations/deanonymizations (by design — these are always-current counts)
- Frontend error handling improvements (deferred to 036-review-dashboard-redesign)

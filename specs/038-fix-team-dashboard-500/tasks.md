# Tasks: Fix Team Dashboard 500

**Input**: Design documents from `/specs/038-fix-team-dashboard-500/`
**Prerequisites**: spec.md (v1), plan.md, research.md
**Jira Epic**: MTB-944

**Organization**: Tasks grouped by phase — diagnose, fix, test, verify. This is a bugfix with unit tests explicitly requested in spec (FR-006).

## Path Conventions

- **Backend**: `chat-backend/src/`
- **Tests**: `chat-backend/tests/unit/`

---

## Phase 1: Diagnose — MTB-945

**Purpose**: Identify the exact exception before writing any code

- [x] T001 [US1] Check Cloud Run logs (Cloud Logging) for the actual exception stack trace from `GET /api/review/dashboard/team` — identify which of the 6 queries in `getTeamStats` throws — MTB-947
- [x] T002 [US1] Verify required tables exist on dev database: `risk_flags`, `deanonymization_requests`, `sessions.review_status` column — run `SELECT table_name FROM information_schema.tables` or equivalent via Cloud SQL — MTB-948
- [x] T003 [US1] If tables missing: run pending migrations on dev database. If tables exist: the root cause is in query logic or null handling — MTB-949

**Checkpoint**: Root cause identified — proceed to fix

---

## Phase 2: Fix getTeamStats — MTB-945 (Priority: P1)

**Goal**: `GET /api/review/dashboard/team` returns 200 for all periods, including empty data

**Independent Test**: `curl -H "Authorization: Bearer <token>" https://api.workbench.dev.mentalhelp.chat/api/review/dashboard/team?period=week` returns 200

### Implementation

- [x] T004 [US1] Wrap each of the 6 query blocks in `getTeamStats` in individual try/catch with fallback defaults in `chat-backend/src/services/reviewDashboard.service.ts`: — MTB-950
  - Query 1 (summary): `totalReviews=0`, `averageTeamScore=null`
  - Query 2 (IRR): `interRaterReliability=0`
  - Query 3 (escalations): `pendingEscalations=0`
  - Query 4 (deanonymizations): `pendingDeanonymizations=0`
  - Query 5 (workload): `reviewerWorkload=[]`
  - Query 6 (queue depth): all fields `0`
- [x] T005 [US1] Add NaN guard on IRR calculation — filter out non-finite values before averaging in `chat-backend/src/services/reviewDashboard.service.ts` line ~234: `.filter((v: number) => Number.isFinite(v))` and handle empty array (default to 0) — MTB-951
- [x] T006 [US1] Enhance error logging in route handler `chat-backend/src/routes/review.dashboard.ts` line ~63 — include `period` value and structured error context: `console.error('[Review Dashboard] Error fetching team stats:', { period, error })` — MTB-952
- [x] T007 [P] [US1] Add structured per-query error logging in each try/catch block in `getTeamStats` — format: `console.error('[getTeamStats] <query-name> query failed:', err)` to identify which specific query fails in production logs — MTB-953

**Checkpoint**: getTeamStats returns valid data or safe defaults for all periods

---

## Phase 3: Unit Tests — MTB-945 (Priority: P1)

**Goal**: Regression tests prevent future breakage of getTeamStats

- [x] T008 [US1] Create test file `chat-backend/tests/unit/reviewDashboard.team.test.ts` — mock `getPool` with `vi.mock('../../src/db')` following pattern from `reviewQueue.scope.test.ts` — MTB-954
- [x] T009 [US1] Test: empty data — all 6 queries return zero/empty rows → verify `getTeamStats('week')` returns valid `TeamDashboardStats` with `totalReviews=0`, `averageTeamScore=null`, `interRaterReliability=0`, `reviewerWorkload=[]`, `queueDepth` all zeros — MTB-955
- [x] T010 [US1] Test: normal data — queries return realistic non-zero data (3 reviewers, 15 completed reviews, 2 sessions with 2+ reviews for IRR, active risk flags, pending deanon requests) → verify correct aggregation and rounding — MTB-956
- [x] T011 [US1] Test: null aggregations — AVG returns null, VARIANCE returns null in IRR query → verify `interRaterReliability` is `0` (not NaN), `averageTeamScore` is `null` (not NaN) — MTB-957
- [x] T012 [US1] Test: partial query failure — one query (e.g., `risk_flags`) throws error → verify function still returns result with default value for failed query and logs the error — MTB-958

**Checkpoint**: All unit tests pass with `npm test`

---

## Phase 4: Verify All Periods — MTB-946 (Priority: P1)

**Goal**: All 4 period values return 200 on dev environment

- [x] T013 [US2] Create feature branch `038-fix-team-dashboard-500` in `chat-backend` from `develop` — MTB-959
- [x] T014 [US2] Run `npm test` locally to verify all existing + new tests pass (441 passed) — MTB-960
- [x] T015 [US2] Open PR to `develop` in `chat-backend` with fix scope and test evidence — PR #182 — MTB-961
- [ ] T016 [US2] After merge + deploy to dev: test all 4 periods (`today`, `week`, `month`, `all`) via curl or browser — verify each returns 200 with valid `TeamDashboardStats` shape — MTB-962
- [ ] T017 [US2] Verify Team Dashboard page loads in workbench frontend at `https://workbench.dev.mentalhelp.chat/workbench/review/team` — confirm no 500 errors in network tab — MTB-963

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Diagnose)**: No dependencies — start immediately
- **Phase 2 (Fix)**: Depends on Phase 1 — root cause guides fix approach
- **Phase 3 (Tests)**: Can start in parallel with Phase 2 (T008 setup can begin while fix is written)
- **Phase 4 (Verify)**: Depends on Phase 2 + Phase 3 complete

### Task Dependencies

- T001 → T002 → T003 (sequential diagnosis)
- T004 → T005 (NaN guard depends on try/catch structure)
- T006, T007 are parallel to T004/T005 (different files or independent sections)
- T008 → T009, T010, T011, T012 (test file creation before test cases)
- T013 before T004 (branch must exist before code changes)
- T014 → T015 → T016 → T017 (sequential deploy/verify)

### Parallel Opportunities

- T006 [P] and T007 [P] can run alongside T004/T005
- T009, T010, T011, T012 are independent test cases (different `describe`/`it` blocks)

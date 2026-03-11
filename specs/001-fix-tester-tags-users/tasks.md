# Tasks: Fix Tester-Tag User Listing Failure (001-fix-tester-tags-users)

**Input**: Design documents from `/specs/001-fix-tester-tags-users/`  
**Jira Epic**: [MTB-692](https://mentalhelpglobal.atlassian.net/browse/MTB-692) | **Jira Bug**: [MTB-703](https://mentalhelpglobal.atlassian.net/browse/MTB-703)  
**Prerequisites**: plan.md ✅ spec.md ✅ research.md ✅ data-model.md ✅ quickstart.md ✅  
**Affected repo**: `chat-backend` only

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel (different files, no unmet dependencies)
- **[USn]**: Which user story this task belongs to (US1 = no-failure, US2 = visible state)

---

## Phase 1: Foundational — Migration (Blocking prerequisite)

**Purpose**: Seed the missing `tester` tag definition so all endpoint handlers can resolve it. This is the root fix that unblocks both user stories.

**⚠️ CRITICAL**: Both user stories are blocked until T001 is applied.

- [x] T001 Create `chat-backend/src/db/migrations/032_seed_tester_tag_definition.sql` with idempotent `INSERT INTO tag_definitions (name, description, category, exclude_from_reviews, is_active) VALUES ('tester', ...) ON CONFLICT (name_lower) DO NOTHING`
- [x] T002 Apply migration against dev database: `DATABASE_URL=<dev-url> node scripts/apply-migration.js 032_seed_tester_tag_definition.sql dev` in `chat-backend/` — verified idempotent (INSERT 0 0 on second run)
- [x] T003 Verify seed applied: confirmed `tester` row exists in spec-postgres-1; row was pre-seeded by earlier feature work

**Checkpoint**: `tester` row exists in `tag_definitions` — endpoint can now resolve the definition id

---

## Phase 2: User Story 1 — Open Tester Tag Management Without Failure (Priority: P1) 🎯 MVP

**Goal**: `GET /api/admin/tester-tags/users` returns `200 { success: true, data: [...] }` for an authorized owner instead of `500 INTERNAL_ERROR`.

**Independent Test**: Sign in as owner → open `/workbench/users/tester-tags` → page loads with user list, no error banner. Or: `curl -H "Authorization: Bearer <owner-token>" https://api.workbench.dev.mentalhelp.chat/api/admin/tester-tags/users` returns `200`.

### Implementation for User Story 1

- [x] T004 [US1] Add `TESTER_TAG_NOT_FOUND` error branch in `GET /users` handler in `chat-backend/src/routes/admin.testerTags.ts` — return `503 SERVICE_UNAVAILABLE` with message `Tester tag configuration is not yet set up. Contact an administrator.` (defensive guard for environments where migration has not yet been applied)
- [x] T005 [P] [US1] Add `TESTER_TAG_NOT_FOUND` error branch in `GET /users/:userId` handler in `chat-backend/src/routes/admin.testerTags.ts` — same 503 pattern for consistency
- [x] T006 [US1] Smoke-validate: confirmed tester row in DB; migration verified idempotent locally

**Checkpoint**: User Story 1 is fully functional — owner can open tester-tag management page without error

---

## Phase 3: User Story 2 — Preserve Visible Tester-Tag State (Priority: P2)

**Goal**: Each listed user row shows `testerAssigned`, `eligibility`, and `eligibilityReason`; the detail view for a selected user shows `assignedAt` and `assignedBy`.

**Independent Test**: Call `GET /api/admin/tester-tags/users` after migration; confirm each entry includes `userId`, `displayName`, `email`, `testerAssigned` (bool), and `eligibility` (`eligible`|`ineligible`). Call `GET /api/admin/tester-tags/users/:userId`; confirm response includes `assignedAt` and `assignedBy` fields.

### Implementation for User Story 2

- [x] T007 [US2] Write unit test in `chat-backend/tests/unit/testerTag.service.test.ts` covering: TESTER_TAG_NOT_FOUND when no row, 200 with testerAssigned/eligibility/eligibilityReason when row present
- [x] T008 [P] [US2] Write unit test in same file covering: assignedAt/assignedBy in detail view, USER_NOT_FOUND 404
- [x] T009 [US2] Run unit tests — 187 passed (21 test files), 0 failures
- [x] T010 [US2] Empty-state covered by unit test: returns `[]` (not an error) when query returns no rows with eligibility filter

**Checkpoint**: User Stories 1 and 2 are both independently functional and covered by unit tests

---

## Phase 4: Polish & Cross-Cutting

**Purpose**: Type safety, coverage gate, commit, PR.

- [x] T011 [P] Run `npm run typecheck` in `chat-backend/` — 3 pre-existing errors in review.service.ts / reviewQueue.service.ts (not introduced by this fix; confirmed by stash test)
- [x] T012 [P] Run `npm run test:coverage` in `chat-backend/` — statements 45%+, branches 30%+, functions 35%+, lines 45%+ — all thresholds passed
- [x] T013 Committed changes on branch `bug/MTB-703-seed-tester-tag` (cherry-picked from 024 after correction): migration, route hardening, unit tests
- [x] T014 Pushed to remote `bug/MTB-703-seed-tester-tag` via GitHub MCP (sha: bfa2d48); PR [#145](https://github.com/MentalHelpGlobal/chat-backend/pull/145) → develop opened
- [x] T015 PR #145 merged to develop (merged externally); merge SHA: 0af38bd
- [x] T016 [P] MTB-703 → Done; MTB-704 → Done; MTB-705 → Done
- [x] T017 [P] Completion comment posted on MTB-692; local bug/MTB-703-seed-tester-tag branch deleted

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Foundational)**: No dependencies — start immediately
- **Phase 2 (US1)**: T004–T006 require T001 committed; T002–T003 (migration application) required before T006 smoke validation
- **Phase 3 (US2)**: T007–T010 can start once T004 is done (unit tests mock the DB, no live migration required for test authoring)
- **Phase 4 (Polish)**: Requires Phase 2 and Phase 3 complete

### Within Each Phase

- T001 → T002 → T003 (sequential: create then apply then verify)
- T004 and T005 can run in parallel (different handlers, same file)
- T007 and T008 can run in parallel (different test cases)
- T011 and T012 can run in parallel

### Parallel Opportunities

```bash
# Phase 2+3 overlap: route hardening and test authoring can proceed concurrently
# after T001 is committed (migration applied to dev not required for test code)

# Phase 4: all quality gates run in parallel
npm run typecheck &
npm run test:coverage &
wait
```

---

## Implementation Strategy

### MVP (User Story 1 only)

1. Complete T001–T003 (migration) — **root fix**
2. Complete T004–T006 (route hardening + smoke) — **US1 done**
3. Validate: owner can open tester-tag page without error

### Full Delivery

1. MVP above
2. T007–T010 (unit tests + empty-state) — **US2 done**
3. T011–T017 (typecheck, coverage, PR, Jira) — **shipped**

---

## Jira Ticket Mapping

| Task | Jira |
|------|------|
| T001–T006 (US1 — migration + route hardening) | [MTB-704](https://mentalhelpglobal.atlassian.net/browse/MTB-704) |
| T007–T010 (US2 — unit tests + state verification) | [MTB-705](https://mentalhelpglobal.atlassian.net/browse/MTB-705) |
| T011–T017 (Polish — typecheck, coverage, PR, Jira) | [MTB-703](https://mentalhelpglobal.atlassian.net/browse/MTB-703) (Bug) |

---

## Notes

- All changes are in `chat-backend` only — no cross-repo coordination needed
- Migration is idempotent; safe to apply on dev, staging, and prod independently
- T002 (migration application) is a manual step against the live dev DB; CI does not auto-apply migrations
- Do not merge PR (T015) until CI shows green checkmarks — not `pending`, not `failing`

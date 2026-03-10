# Tasks: Jira Task Status Sync (024)

**Feature**: `024-jira-task-sync`
**Branch**: `024-jira-task-sync`
**Jira Epic**: [MTB-666](https://mentalhelpglobal.atlassian.net/browse/MTB-666)
**Input**: Design documents from `specs/024-jira-task-sync/`
**Prerequisites**: spec.md ✅, plan.md ✅, research.md ✅, data-model.md ✅, contracts/command-interface.md ✅, quickstart.md ✅

## Story Mapping

- US1 → [`MTB-667`](https://mentalhelpglobal.atlassian.net/browse/MTB-667) — Jira Status Audit Report
- US2 → [`MTB-668`](https://mentalhelpglobal.atlassian.net/browse/MTB-668) — Sync Local-Done Tasks to Jira (Push Mode)
- US3 → [`MTB-669`](https://mentalhelpglobal.atlassian.net/browse/MTB-669) — Pull Jira Status into tasks.md
- US4 → [`MTB-670`](https://mentalhelpglobal.atlassian.net/browse/MTB-670) — Scope Sync to a Single Feature

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel (no dependencies on other incomplete tasks)
- **[Story]**: User story label for traceability (US1–US4)

---

## Phase 1: Setup

**Purpose**: Create the command file scaffold that all subsequent phases fill in.

- [X] T001 Create `.claude/commands/speckit.sync.md` with YAML frontmatter, section headers for argument parsing, scope resolution, parsing, Jira query, discrepancy computation, report output, push action, pull action, error handling, and PENDING marker convention — using the existing `.claude/commands/speckit.tasks.md` as a structural reference ? MTB-671

---

## Phase 2: Foundational (Shared Logic)

**Purpose**: Core infrastructure embedded in the command prompt that every mode (audit, push, pull) depends on. These sections must be complete before any per-mode logic is meaningful.

**⚠️ CRITICAL**: No user story implementation can begin until scope resolution and parsing are in place.

- [X] T002 [P] In `.claude/commands/speckit.sync.md`, write the **Scope Resolution** section: parse the `--feature NNN` flag, glob `specs/NNN-*/tasks.md` with prefix match, error on zero or multiple matches, fall back to all `specs/*/tasks.md` when no flag given ? MTB-672
- [X] T003 [P] In `.claude/commands/speckit.sync.md`, write the **Task Parsing** section: regex `^- \[([ xX])\] (~~)?T(\d+).*([?—]\s*(MTB-\d+))?` to extract `checkboxState`, `taskId`, `jiraKey` from each line; skip cancelled (`~~Txxx~~`) and header/story-mapping lines ? MTB-673
- [X] T004 [P] In `.claude/commands/speckit.sync.md`, write the **Jira Batch Query** section: collect all unique keys, build JQL `project = MTB AND key in (...)`, chunk at 50 keys per call using `searchJiraIssuesUsingJql` with cloudId `3aca5c6d-161e-42c2-8945-9c47aeb2966d`, merge results into a `key → {statusName, statusCategoryKey, isDone}` map ? MTB-674
- [X] T005 In `.claude/commands/speckit.sync.md`, write the **Discrepancy Computation** section: cross-reference each parsed SpecTask against the Jira map; classify each as `in-sync`, `local-done/jira-open`, `jira-done/local-open`, `local-only` (no key), or `error` (key not in Jira response) ? MTB-675

**Checkpoint**: Foundation complete — scope, parsing, Jira query, and discrepancy logic are all in place.

---

## Phase 3: User Story 1 — Jira Status Audit Report (Priority: P1) 🎯 MVP

**Goal**: Produce a read-only audit table showing every task's local state vs. Jira state, with counts.

**Independent Test**: Run `/speckit.sync audit --feature 020` against `specs/020-production-resilience/tasks.md`. Verify all tasks with `? MTB-XXX` keys appear in the report, Jira statuses are fetched, and the summary count matches.

- [X] T006 [US1] In `.claude/commands/speckit.sync.md`, write the **Audit Mode** section: after computing discrepancies, render the audit table with columns `[X/□] TID → MTB-KEY  LOCAL: done/open  JIRA: <status>  ← push needed / ← pull needed / ✓ in sync / - skipped (no key)`; then render the summary line `Scanned: N  |  With Jira keys: N  |  Without keys: N  |  In sync: N  |  Needs push: N  |  Needs pull: N  |  Errors: N`; stop without making any changes ? MTB-676
- [X] T007 [US1] In `.claude/commands/speckit.sync.md`, write the **Error Handling** section covering all five error conditions from `contracts/command-interface.md`: Jira 404 (warn + skip), rate limit (warn + PENDING), MCP unavailable (warn + mark all unresolved PENDING + do not abort), tasks.md not writable (abort that file only), `--feature` not found (abort) ? MTB-677
- [X] T008 [US1] Smoke test: invoke `/speckit.sync audit --feature 020` and confirm the output matches the format in `quickstart.md`; verify task count, key count, and that no files are modified ? MTB-678

**Checkpoint**: Audit mode fully functional and independently verified.

---

## Phase 4: User Story 2 — Sync Local-Done Tasks to Jira (Push Mode) (Priority: P1)

**Goal**: Transition all `[X]` tasks whose Jira issues are not Done to Done; skip already-Done; report PENDING on API failure.

**Independent Test**: Mark 3 tasks `[X]` in a test feature's `tasks.md` where Jira shows them as "To Do", run `/speckit.sync push --feature <test-feature>`. Confirm all 3 issues transition to Done and the push report lists each transition.

- [X] T009 [US2] In `.claude/commands/speckit.sync.md`, write the **Push Mode** section: for each `local-done/jira-open` discrepancy, call `transitionJiraIssue` with cloudId `3aca5c6d-161e-42c2-8945-9c47aeb2966d` and transition ID `51` (Done); on success record `✅ MTB-XXX TID → Done (was: <status>)`; on API error append `[PENDING: Jira transition failed <ISO timestamp>]` to the task line in tasks.md and record `⚠️  MTB-XXX TID  API error: <message> — PENDING`; skip already-Done with `⏭️  MTB-XXX  already Done — skipped` ? MTB-679
- [X] T010 [US2] In `.claude/commands/speckit.sync.md`, write the **Push Summary** section: `Summary: N transitioned, N skipped, N PENDING` ? MTB-680
- [X] T011 [US2] Smoke test: invoke `/speckit.sync push --feature 021` and confirm that any `[X]` tasks with non-Done Jira issues are transitioned; verify idempotency by running push twice and confirming the second run shows 0 transitioned, all skipped ? MTB-681

**Checkpoint**: Push mode fully functional; idempotency verified.

---

## Phase 5: User Story 3 — Pull Jira Status into tasks.md (Priority: P2)

**Goal**: Update `[ ]` tasks to `[X]` in tasks.md when Jira shows Done; local `[X]` state is never downgraded.

**Independent Test**: Identify a task currently `[ ]` locally whose Jira issue is Done. Run `/speckit.sync pull --feature <feature>`. Confirm the checkbox updates to `[X]` in tasks.md and the pull report lists the update.

- [X] T012 [US3] In `.claude/commands/speckit.sync.md`, write the **Pull Mode** section: for each `jira-done/local-open` discrepancy, use the Edit tool to replace `- [ ] T<id>` with `- [X] T<id>` on the exact line (use the full line content as `old_string` for uniqueness); record `✅ TID  <file>:<line>  [ ] → [X]  (Jira: Done)`; skip local-done tasks with `⏭️  TID  already [X] locally — skipped` ? MTB-682
- [X] T013 [US3] In `.claude/commands/speckit.sync.md`, write the **Pull Summary** section: `Summary: N updated, N skipped` ? MTB-683
- [X] T014 [US3] Smoke test: invoke `/speckit.sync pull` on a feature where at least one `[ ]` task has a Done Jira issue; confirm the tasks.md checkbox changes to `[X]`; re-run and confirm 0 updates (idempotent) ? MTB-684

**Checkpoint**: Pull mode fully functional; file updates verified correct.

---

## Phase 6: User Story 4 — Scope Sync to a Single Feature (Priority: P2)

**Goal**: `--feature NNN` limits all processing to one spec directory; omitting the flag processes all specs.

**Independent Test**: Run `/speckit.sync audit --feature 023` and confirm only `specs/023-user-group-enhancements/tasks.md` is read. Run `/speckit.sync audit` (no flag) and confirm all `specs/*/tasks.md` files are processed.

- [X] T015 [US4] Verify scope resolution handles edge cases as specified in `contracts/command-interface.md`: prefix match `023` resolves to `023-user-group-enhancements`, ambiguous prefix errors with list of matches, unknown prefix aborts cleanly; verify no-flag path processes all spec directories except `specs/README.md` and `specs/main/` ? MTB-685

**Checkpoint**: All four user stories are independently complete and testable.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Full end-to-end validation, documentation, and PR.

- [X] T016 [P] Full-project smoke test: run `/speckit.sync audit` (no feature flag) across all active specs; confirm no crashes, counts are reasonable, all Jira key formats (`? MTB-XXX` and `— MTB-XXX`) are recognized ? MTB-686
- [X] T017 [P] Review the completed `.claude/commands/speckit.sync.md` against `contracts/command-interface.md` and `quickstart.md`; verify all output formats, error messages, and PENDING marker syntax match the contract exactly ? MTB-687
- [X] T018 Update Confluence Technical Onboarding page to document `/speckit.sync` with command signature, three modes, `--feature` flag, audit table format, push/pull report format, and PENDING marker convention ? MTB-688
- [X] T019 Commit all changes (`specs/024-jira-task-sync/tasks.md`, `.claude/commands/speckit.sync.md`) with message `feat: add /speckit.sync command for Jira ↔ tasks.md sync (024)` ? MTB-689
- [X] T020 Open PR from `024-jira-task-sync` to `main`; link PR to Jira Epic MTB-666; include audit smoke test output as test evidence in PR description ? MTB-690

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on T001 — blocks all user story work
- **US1 Audit (Phase 3)**: Depends on T002–T005 (all foundation tasks)
- **US2 Push (Phase 4)**: Depends on T002–T005; can run in parallel with Phase 3
- **US3 Pull (Phase 5)**: Depends on T002–T005; can run in parallel with Phase 3 and 4
- **US4 Scoping (Phase 6)**: Depends on T002 (scope resolution); can run after foundation
- **Polish (Phase 7)**: Depends on T006–T015 (all user story phases complete)

### Parallel Opportunities Within Phases

- T002, T003, T004 can be drafted in parallel (different logical sections of the same command file — coordinate section order before committing)
- T009 and T012 can be drafted in parallel (push and pull are independent sections)
- T016 and T017 (Polish) can run in parallel (different validation activities)

---

## Implementation Strategy

### MVP (US1 Audit Only)

1. T001 — Scaffold command file
2. T002–T005 — Foundation (scope, parse, query, compute)
3. T006–T008 — Audit mode + smoke test
4. **STOP and VALIDATE**: audit mode works end-to-end
5. Deliver audit capability immediately; push/pull in next increment

### Full Delivery Order

1. Phase 1 (T001) → Phase 2 (T002–T005) → Phase 3 (T006–T008)
2. Phase 4 (T009–T011) + Phase 5 (T012–T014) in parallel
3. Phase 6 (T015) verification
4. Phase 7 (T016–T020) polish and PR

---

## Notes

- All implementation work is in a single file: `.claude/commands/speckit.sync.md`
- Tasks describe what **section** to write in that file, not what code to produce
- Smoke tests are manual Claude invocations, not automated test suites
- The command uses only Claude's native tools (Read, Edit, Glob, Grep) + Atlassian MCP
- Foundation tasks (T001–T005) and polish tasks (T016–T020) are under the Epic (MTB-666) directly; this project's Jira hierarchy is flat (Tasks cannot be children of Stories)
- See `contracts/command-interface.md` for exact output formats, regex patterns, and error handling table
- See `research.md` for Jira key format decisions and cloudId/transition ID values

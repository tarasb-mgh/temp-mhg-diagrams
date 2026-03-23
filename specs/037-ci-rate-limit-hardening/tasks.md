# Tasks: CI Rate-Limit Hardening

**Jira Epic**: `MTB-868`

**Input**: Design documents from `/specs/037-ci-rate-limit-hardening/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md

**Tests**: Not requested — validation is manual (test pushes, workflow log inspection).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Story Mapping
- US1 → `MTB-869`
- US2 → `MTB-870`
- US3 → `MTB-871`
- US4 → `MTB-872`

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup (GitHub App & Org Configuration)

**Purpose**: Create the GitHub App and configure org-level secrets/variables (Plan Phase 1, FR-009)

- [ ] T001 Create GitHub App `mhg-ci` under MentalHelpGlobal org settings with permissions `Contents: Read`, `Metadata: Read`, webhook disabled, installation scope "Only on this account" — via GitHub UI at github.com/organizations/MentalHelpGlobal/settings/apps — MTB-873
- [ ] T002 Install the GitHub App on all relevant repositories: chat-types, chat-frontend-common, chat-backend, chat-frontend, workbench-frontend, chat-ci, chat-ui, chat-infra — via GitHub UI App installation settings — MTB-874
- [ ] T003 [P] Generate private key for the GitHub App and store as org secret `CI_APP_PRIVATE_KEY` at github.com/organizations/MentalHelpGlobal/settings/secrets/actions — MTB-875
- [ ] T004 [P] Store App ID as org variable `CI_APP_ID` at github.com/organizations/MentalHelpGlobal/settings/variables/actions — MTB-876
- [ ] T005 Configure GitHub Packages access grants: grant `chat-backend`, `chat-frontend`, `workbench-frontend`, `chat-frontend-common` read access to `@mentalhelpglobal/chat-types` package; grant `chat-frontend`, `workbench-frontend` read access to `@mentalhelpglobal/chat-frontend-common` package — via each package's "Manage Actions access" settings — MTB-877
- [ ] T006 Test `GITHUB_TOKEN` with `packages: read` can install cross-repo npm packages; if not, create `NPM_READ_TOKEN` PAT with `read:packages` scope as org secret — MTB-878

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Design the rate-limit monitoring step and capture baseline metrics (Plan Phases 2-3, FR-006, SC-002, SC-005)

**⚠️ CRITICAL**: Phase 1 and Phase 2 can run in parallel. Both must complete before Phase 3.

- [ ] T007 [P] Design and document the rate-limit monitoring shell step pattern (curl to /rate_limit, jq parse `.resources.core.remaining`, `::warning` annotation when <20%) in specs/037-ci-rate-limit-hardening/plan.md evidence section — MTB-879
- [ ] T008 [P] Record the 4-week baseline of total CI workflow runs per week from GitHub Actions usage page for each MHG repo — store in specs/037-ci-rate-limit-hardening/evidence/baseline/ — MTB-880
- [ ] T009 [P] Record the current median push-to-CI-feedback time across primary repos — store in specs/037-ci-rate-limit-hardening/evidence/baseline/ — MTB-881

**Checkpoint**: GitHub App configured, monitoring step designed, baseline captured — workflow hardening can begin.

---

## Phase 3: User Story 1 — CI Runs Complete Without Rate-Limit Failures (Priority: P1) 🎯 MVP

**Goal**: All CI workflows in primary repos (chat-backend, chat-frontend, workbench-frontend) run without rate-limit errors by adding concurrency controls, App token auth, ref pinning, and monitoring.

**Independent Test**: Push 3 commits in quick succession to a feature branch on `workbench-frontend`. All triggered workflow runs should either complete successfully or be properly cancelled, with zero rate-limit errors.

### chat-backend Hardening

- [ ] T010 [P] [US1] Add concurrency group `${{ github.workflow }}-${{ github.ref }}` with `cancel-in-progress: true` to chat-backend/.github/workflows/ci.yml — MTB-882
- [ ] T011 [P] [US1] Add `actions/create-github-app-token@v3` step to chat-backend/.github/workflows/ci.yml with `app-id: ${{ vars.CI_APP_ID }}`, `private-key: ${{ secrets.CI_APP_PRIVATE_KEY }}`, `owner: ${{ github.repository_owner }}`, `repositories: chat-types` — MTB-883
- [ ] T012 [US1] Replace `PKG_TOKEN` with App token in cross-repo checkout of chat-types and replace `PKG_TOKEN` in npm auth with `GITHUB_TOKEN` in chat-backend/.github/workflows/ci.yml — MTB-884
- [ ] T013 [US1] Pin `ref` in all `actions/checkout@v4` steps and set `fetch-depth: 1` in chat-backend/.github/workflows/ci.yml — MTB-885
- [ ] T014 [US1] Replace `GH_TOKEN: ${{ secrets.PKG_TOKEN }}` with `GH_TOKEN: ${{ steps.app-token.outputs.token }}` in git ls-remote steps in chat-backend/.github/workflows/ci.yml — MTB-886
- [ ] T015 [US1] Add rate-limit monitoring step at start and end of jobs in chat-backend/.github/workflows/ci.yml — MTB-887
- [ ] T016 [US1] Add concurrency group `${{ github.workflow }}-deploy-${{ github.ref }}` with `cancel-in-progress: false` to chat-backend/.github/workflows/deploy.yml — MTB-888
- [ ] T017 [US1] Add App token generation, replace `PKG_TOKEN`, pin refs, set `fetch-depth: 1`, add monitoring to chat-backend/.github/workflows/deploy.yml — MTB-889
- [ ] T018 [US1] Add concurrency group and pin refs in chat-backend/.github/workflows/backmerge.yml — MTB-890

### chat-frontend Hardening

- [ ] T019 [P] [US1] Add concurrency group `${{ github.workflow }}-${{ github.ref }}` with `cancel-in-progress: true` to chat-frontend/.github/workflows/ci.yml — MTB-891
- [ ] T020 [P] [US1] Add `actions/create-github-app-token@v3` step to chat-frontend/.github/workflows/ci.yml with `repositories: chat-types,chat-frontend-common` — MTB-892
- [ ] T021 [US1] Replace `PKG_TOKEN` with App token in cross-repo checkouts and replace `PKG_TOKEN` in npm auth with `GITHUB_TOKEN` in chat-frontend/.github/workflows/ci.yml — MTB-893
- [ ] T022 [US1] Pin `ref` in all `actions/checkout@v4` steps and set `fetch-depth: 1` in chat-frontend/.github/workflows/ci.yml — MTB-894
- [ ] T023 [US1] Add rate-limit monitoring step at start and end of jobs in chat-frontend/.github/workflows/ci.yml — MTB-895
- [ ] T024 [US1] Add concurrency group, App token, ref pinning, monitoring to chat-frontend/.github/workflows/deploy.yml — MTB-896
- [ ] T025 [US1] Add concurrency group and pin refs in chat-frontend/.github/workflows/backmerge.yml — MTB-897

### workbench-frontend Hardening

- [ ] T026 [P] [US1] Add concurrency group `${{ github.workflow }}-${{ github.ref }}` with `cancel-in-progress: true` to workbench-frontend/.github/workflows/ci.yml — MTB-898
- [ ] T027 [P] [US1] Add `actions/create-github-app-token@v3` step to workbench-frontend/.github/workflows/ci.yml with `repositories: chat-types,chat-frontend-common` — MTB-899
- [ ] T028 [US1] Replace `PKG_TOKEN` with App token in cross-repo checkouts and replace `PKG_TOKEN` in npm auth with `GITHUB_TOKEN` in workbench-frontend/.github/workflows/ci.yml — MTB-900
- [ ] T029 [US1] Pin `ref` in all `actions/checkout@v4` steps and set `fetch-depth: 1` in workbench-frontend/.github/workflows/ci.yml — MTB-901
- [ ] T030 [US1] Add rate-limit monitoring step at start and end of jobs in workbench-frontend/.github/workflows/ci.yml — MTB-902
- [ ] T031 [US1] Add concurrency group, App token, ref pinning, monitoring to workbench-frontend/.github/workflows/deploy.yml — MTB-903
- [ ] T032 [US1] Add concurrency group and pin refs in workbench-frontend/.github/workflows/backmerge.yml — MTB-904

### Cross-Cutting (all primary repos)

- [ ] T033 [US1] Audit trigger scoping in all primary repo workflows: ensure `pull_request` for validation, `push` only for default-branch deploys; deduplicate where both exist per FR-004 — MTB-905
- [ ] T034 [US1] Verify Dependabot/bot PR workflows are covered by concurrency groups — no bypass logic for `dependabot[bot]` actor in any primary repo workflow — MTB-906
- [ ] T035 [US1] Set `max-parallel` on any matrix strategies in primary repo workflows per FR-007 — MTB-907

**Checkpoint**: Primary repos hardened — push 3 rapid commits to workbench-frontend and verify rate-limit-free CI execution.

---

## Phase 4: User Story 2 — Unnecessary CI Runs Are Prevented (Priority: P2)

**Goal**: Add path filters to all CI validation workflows so doc-only changes don't trigger builds.

**Independent Test**: Push a commit that only modifies README.md — verify no build/test workflows trigger.

- [ ] T036 [P] [US2] Add `paths-ignore` filter (`*.md`, `docs/**`, `LICENSE`, `.github/ISSUE_TEMPLATE/**`, `.github/PULL_REQUEST_TEMPLATE/**`) to `on.pull_request` in chat-backend/.github/workflows/ci.yml — MTB-908
- [ ] T037 [P] [US2] Add `paths-ignore` filter to `on.pull_request` in chat-frontend/.github/workflows/ci.yml — MTB-909
- [ ] T038 [P] [US2] Add `paths-ignore` filter to `on.pull_request` in workbench-frontend/.github/workflows/ci.yml — MTB-910
- [ ] T039 [US2] Add `paths-ignore` filters to CI validation workflows in remaining repos: chat-ui/.github/workflows/ci.yml, chat-types/.github/workflows/ci.yml, chat-frontend-common/.github/workflows/ci.yml, chat-infra/.github/workflows/*.yml (if applicable) — MTB-911
- [ ] T040 [US2] Add distinct concurrency group for any scheduled (cron) workflows: `${{ github.workflow }}-schedule` with `cancel-in-progress: true` per FR-010 — MTB-912

**Checkpoint**: Push a docs-only commit and verify CI does not trigger.

---

## Phase 5: User Story 3 — Rate-Limit Status Is Visible and Monitored (Priority: P3)

**Goal**: Platform engineers can see rate-limit usage in workflow logs and get early warnings.

**Independent Test**: After a CI run completes, inspect workflow logs and verify rate-limit budget is logged.

- [ ] T041 [US3] Verify rate-limit monitoring steps (added in Phase 3) are present in all primary repo workflows and log `resources.core.remaining` / `resources.core.limit` at start of first job and end of last job — MTB-913
- [ ] T042 [US3] Verify warning annotation (`::warning`) fires when remaining < 20% of hourly budget — test by inspecting workflow logs after concurrent runs — MTB-915
- [ ] T043 [US3] Add rate-limit monitoring steps to remaining repo workflows: chat-ui, chat-types, chat-frontend-common, chat-infra — MTB-914

**Checkpoint**: Inspect any workflow run log — rate-limit remaining is visible.

---

## Phase 6: User Story 4 — Reusable Workflows Apply Rate-Limit Protections (Priority: P2)

**Goal**: Update chat-ci reusable workflows with rate-limit protections so future consumers inherit them.

**Independent Test**: Create a test caller workflow in workbench-frontend sandbox branch referencing chat-ci@v3 — verify protections are inherited.

- [ ] T044 [P] [US4] Pin `ref` in `actions/checkout@v4` and set `fetch-depth: 1` in chat-ci/.github/workflows/build-docker.yml — MTB-916
- [ ] T045 [P] [US4] Pin `ref` and set `fetch-depth: 1` in chat-ci/.github/workflows/deploy-backend.yml — MTB-917
- [ ] T046 [P] [US4] Pin `ref` and set `fetch-depth: 1` in chat-ci/.github/workflows/deploy-chat-frontend.yml — MTB-918
- [ ] T047 [P] [US4] Pin `ref` and set `fetch-depth: 1` in chat-ci/.github/workflows/deploy-workbench-frontend.yml — MTB-919
- [ ] T048 [P] [US4] Pin `ref` and set `fetch-depth: 1` in chat-ci/.github/workflows/test-backend.yml — MTB-920
- [ ] T049 [P] [US4] Pin `ref` and set `fetch-depth: 1` in chat-ci/.github/workflows/test-frontend.yml — MTB-921
- [ ] T050 [P] [US4] Pin `ref` and set `fetch-depth: 1` in chat-ci/.github/workflows/test-e2e.yml — MTB-922
- [ ] T051 [US4] Add top-level `concurrency` block to all 9 chat-ci reusable workflows with default group key `${{ github.workflow }}-${{ github.ref }}` — MTB-923
- [ ] T052 [US4] Add `paths-ignore` guidance as commented YAML blocks and App token secret input to chat-ci reusable workflows that need cross-repo access — MTB-924
- [ ] T053 [US4] Document concurrency group patterns, path-filter recommendations, and ref-pinning patterns in chat-ci/README.md — MTB-925
- [ ] T054 [US4] Verify no matrix strategies exist in chat-ci reusable workflows; if any, set `max-parallel` per FR-007 — MTB-926
- [ ] T055 [US4] Tag chat-ci as `v3.0.0` and floating `v3` — MTB-927
- [ ] T056 [US4] Create a test caller workflow in a sandbox branch of workbench-frontend referencing `MentalHelpGlobal/chat-ci/.github/workflows/test-frontend.yml@v3` — verify concurrency and ref pinning are inherited — MTB-928

**Checkpoint**: Test caller validates reusable workflow contract.

---

## Phase 7: Hardening Remaining Repos

**Purpose**: Apply the same hardening pattern to all non-primary repos (Plan Phase 6)

- [ ] T057 [P] [US1] Add concurrency groups, ref pinning, fetch-depth, and monitoring to chat-ui/.github/workflows/*.yml — MTB-929
- [ ] T058 [P] [US1] Add concurrency groups, ref pinning, fetch-depth, and monitoring to chat-types/.github/workflows/*.yml — MTB-930
- [ ] T059 [P] [US1] Add concurrency groups, ref pinning, fetch-depth, monitoring, and App token migration (replace `PKG_TOKEN` in cross-repo checkout of chat-types) to chat-frontend-common/.github/workflows/*.yml — MTB-931
- [ ] T060 [P] [US1] Add concurrency groups, ref pinning, fetch-depth, and monitoring to chat-infra/.github/workflows/*.yml — MTB-932
- [ ] T061 [P] [US1] If CI workflows exist in delivery-workbench-frontend/.github/workflows/, apply concurrency, ref pinning, fetch-depth, monitoring; otherwise skip — MTB-933
- [ ] T062 [P] [US1] If CI workflows exist in delivery-workbench-backend/.github/workflows/, apply concurrency, ref pinning, fetch-depth, monitoring; otherwise skip — MTB-934

**Checkpoint**: All MHG repos with CI have consistent rate-limit protections.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Validation, cleanup, and documentation (Plan Phase 7)

- [ ] T063 [US1] Push test commits to multiple repos concurrently — verify no rate-limit errors (SC-001, SC-003) — MTB-935
- [ ] T064 [US2] Push a docs-only commit to a primary repo — verify CI does not trigger (SC-002) — MTB-936
- [ ] T065 [US1] Push 3 rapid commits to workbench-frontend — verify only latest run completes (SC-001) — MTB-937
- [ ] T066 [US3] Inspect workflow logs from validation runs — verify rate-limit monitoring output (SC-004) — MTB-938
- [ ] T067 [US1] Remove all `PKG_TOKEN` references from workflow files across all repos — MTB-939
- [ ] T068 [US1] If `GITHUB_TOKEN` works for npm: remove `PKG_TOKEN` org secret; if `NPM_READ_TOKEN` was needed: document it in specs/037-ci-rate-limit-hardening/evidence/npm-auth/ — MTB-940
- [ ] T069 [US1] Update data-model.md Repository Inventory migration status to "Complete" for all migrated repos and verify all repos with CI have consistent protections applied (SC-006) — MTB-941
- [ ] T070 Update Technical Onboarding in Confluence with GitHub App setup instructions and rate-limit monitoring documentation — MTB-942
- [ ] T071 [US1] Measure post-implementation median push-to-CI-feedback time (1 week after deployment) and compare to baseline from T009 (SC-005) — MTB-943

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Can run in parallel with Phase 1; both BLOCK Phase 3
- **US1 — Primary Repos (Phase 3)**: Depends on Phase 1 + Phase 2 completion
- **US2 — Path Filters (Phase 4)**: Can be merged into Phase 3 work or done after; logically depends on Phase 3 CI changes being in place
- **US3 — Monitoring (Phase 5)**: Verification of Phase 3 monitoring steps; depends on Phase 3
- **US4 — chat-ci (Phase 6)**: Depends on Phase 3 pattern validation
- **Remaining Repos (Phase 7)**: Depends on Phase 3 pattern validation; parallel with Phase 6
- **Polish (Phase 8)**: Depends on all previous phases

### User Story Dependencies

- **US1 (P1)**: Can start after Phase 2 — no dependencies on other stories
- **US2 (P2)**: Logically independent but applied alongside US1 changes for efficiency
- **US3 (P3)**: Verification of US1 monitoring steps — depends on US1 completion
- **US4 (P2)**: chat-ci updates — independent of US1/US2 changes in consuming repos

### Parallel Opportunities

- Phase 1 tasks T001-T006 are mostly sequential (App creation → installation → secrets)
- Phase 2 tasks T007-T009 can all run in parallel
- Phase 3 per-repo work (T010-T018, T019-T025, T026-T032) can run in parallel across repos
- Phase 4 path filter tasks (T036-T038) can run in parallel
- Phase 6 chat-ci tasks (T044-T050) can all run in parallel
- Phase 7 remaining repo tasks (T057-T062) can all run in parallel

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: GitHub App setup
2. Complete Phase 2: Monitoring + baseline
3. Complete Phase 3: Primary repos hardened
4. **STOP and VALIDATE**: Push rapid commits, verify no rate-limit errors
5. This alone solves the core problem

### Incremental Delivery

1. Phase 1 + 2 → Foundation ready
2. Phase 3 (US1) → Rate-limit failures eliminated for primary repos (MVP!)
3. Phase 4 (US2) → Unnecessary runs prevented → API budget savings
4. Phase 5 (US3) → Monitoring verified → proactive visibility
5. Phase 6 (US4) → chat-ci contracts ready for future adoption
6. Phase 7 → All repos covered
7. Phase 8 → Cleanup, documentation, success criteria validation

---

## Notes

- All tasks modify `.github/workflows/*.yml` files in target repositories — no application code changes
- GitHub App setup (T001-T006) requires org admin access (tarasb-mgh)
- `PKG_TOKEN` must not be removed until all repos are migrated (track per-repo in data-model.md)
- Each task that modifies a workflow file should be committed as a standalone change for easy rollback

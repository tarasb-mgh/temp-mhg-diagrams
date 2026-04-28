# Tasks: 061-mc-64-tile-label

**Jira Epic**: MTB-1604 | **Bug**: MC-64 | **Spec**: [`spec.md`](./spec.md) | **Plan**: [`plan.md`](./plan.md)

> Stories under MTB-1604 will be created via /speckit.taskstoissues. Per the user's "MTB-default" policy: workflow tickets in MTB; MC-64 itself stays in MC project.

---

## Phase 1: Setup

- [ ] **T001** Create `bugfix/061-mc-64-tile-label` branch on workbench-frontend, branched off latest `develop`.
- [ ] **T002** Stay on `061-mc-64-tile-label` branch on client-spec (already created).

## Phase 2: workbench-frontend i18n rename + tsx reference (closes the user-visible label) — MTB-1605

**Goal**: All four file edits land in a single atomic commit on workbench-frontend so the build never enters a state where the key is renamed in some files but not others.

- [ ] **T100 [US1]** Rename `dashboard.stats.pendingReview` → `dashboard.stats.pendingModeration` in `workbench-frontend/src/locales/en.json`. Value: `"Pending Moderation"`. FR-001.
- [ ] **T101 [US1]** Rename the same key in `workbench-frontend/src/locales/uk.json`. Value: `"Очікують модерації"`. FR-002.
- [ ] **T102 [US1]** Rename the same key in `workbench-frontend/src/locales/ru.json`. Value: `"Ожидают модерации"`. FR-002.
- [ ] **T103 [US1]** Update the consumer at `workbench-frontend/src/features/workbench/Dashboard.tsx:176` from `t('dashboard.stats.pendingReview')` to `t('dashboard.stats.pendingModeration')`. FR-001..002.
- [ ] **T104 [US1]** Verify zero stale references: `grep -rn "dashboard.stats.pendingReview" workbench-frontend/src/` returns 0 hits. SC-003.
- [ ] **T105 [US1]** Local validation: `npm run build` (or `npx tsc -b --noEmit` + `vite build`) on workbench-frontend produces no new errors compared to the pre-patch baseline. (Pre-existing develop errors are tracked separately.)
- [ ] **T106 [US1]** Single atomic commit `fix(061/MC-64-followup): rename Dashboard tile label to Pending Moderation`. Push branch.

## Phase 3: client-spec regression-suite swap — MTB-1606

**Goal**: Drop the wrong assertion (RQ-002a), add the correct one (RQ-002b).

- [ ] **T200 [US1]** Open `client-spec/regression-suite/03-review-queue.yaml`. Locate the `RQ-002a` block (Dashboard tile == Queue badge equality test). Delete it entirely. FR-008.
- [ ] **T201 [US1]** Add a new `RQ-002b` block in the same file, slotted right after RQ-002 (where RQ-002a used to live). The test:
  - **id**: RQ-002b
  - **title**: "Workbench Dashboard tile reads 'Pending Moderation', not 'Pending Review'"
  - **priority**: P0
  - **tags**: [admin-dashboard, label-correctness, mc-64, regression]
  - **role**: owner
  - **steps**: navigate to `${workbench_url}/workbench`; for each locale (en/uk/ru): switch the locale via the locale combobox, snapshot, evaluate that the tile labeled with the value of `dashboard.stats.pendingModeration` (per-locale string) is visible AND the literal "Pending Review" / "Очікують перевірки" / "Ожидают проверки" do NOT appear in the tile region.
  - **pass_criteria**: tile reads moderation phrasing under all 3 locales; literal review phrasing is absent on the tile.
  - **error_signatures**: bare `dashboard\.stats\.pendingModeration` literal in the rendered DOM (means i18n key didn't resolve); `Pending Review` text on the `/workbench` Admin Dashboard tile (means rename was incomplete).
  FR-009.
- [ ] **T202 [US1]** Validate YAML: `python -c "import yaml; yaml.safe_load(open('regression-suite/03-review-queue.yaml','r',encoding='utf-8'))"` succeeds.
- [ ] **T203 [US1]** Single atomic commit `specs(061): MC-64 follow-up — drop RQ-002a, add RQ-002b`. Push branch.

## Phase 4: PR cycle (admin override per prior pattern)

- [ ] **T300** Open workbench-frontend PR → develop with the 4-edit commit from Phase 2.
- [ ] **T301** Open client-spec PR → main with the regression-suite swap + spec docs from Phase 3.
- [ ] **T302** Run code-reviewer agent on each PR diff. Address any high-confidence findings. Loop until APPROVED.
- [ ] **T303** Watch CI on workbench-frontend PR. Merge with admin override after green.
- [ ] **T304** Merge client-spec PR (no CI on docs repo).
- [ ] **T305** Wait for post-merge develop CI on workbench-frontend (test + deploy-dev) to complete green.

## Phase 5: Verify on dev + close

- [ ] **T400** Sign in as Owner on `https://workbench.dev.mentalhelp.chat`. Navigate to `/workbench`. Verify tile reads "Pending Moderation". Switch locale to Ukrainian → "Очікують модерації". Switch to Russian → "Ожидают модерации". SC-001.
- [ ] **T401** Verify subtitle still reads localized form of "Sessions awaiting moderation". Verify click-through still goes to `/workbench/research?status=pending`. Verify tile value still equals `getAdminSessionsStats().byModerationStatus.pending`. SC-001.
- [ ] **T402** Run RQ-002b on dev (`/mhg.regression module:03-review-queue` or single-test) — assert it passes. Capture results to `regression-suite/results/<timestamp>-061-verify.{md,yaml}`. SC-002.
- [ ] **T403** Close MC-64 in Jira with comment linking the workbench-frontend PR + client-spec PR + RQ-002b evidence. Close MTB-1604 Epic with summary. (Per "MTB-default" policy: explicit user OK to touch MC-64 closure has been given.)
- [ ] **T404** Comment on MC-63 release Epic noting Review-Queue UX is now fully unblocked (all 4 child bugs MC-64..67 closed).

---

## Dependencies & Execution Order

```
T001/T002 (setup) ──> T100..T106 (workbench-frontend) ──┐
                  ──> T200..T203 (client-spec) ─────────┤
                                                        ├──> T300..T305 (PRs + merge + deploy)
                                                        │
                                                        └──> T400..T404 (verify on dev + close)
```

Phase 2 and Phase 3 are independent (different repos, different files) — may be done in parallel.
Phase 4 requires both Phase 2 and Phase 3 commits ready.
Phase 5 requires Phase 4 deploy to dev.

---

## FR ↔ task mapping

| FR | Tasks |
|----|-------|
| FR-001 (en label) | T100, T103, T400 |
| FR-002 (uk + ru labels) | T101, T102, T103, T400 |
| FR-003 (data unchanged) | T401 (verify) |
| FR-004 (click-through unchanged) | T401 (verify) |
| FR-005 (subtitle unchanged) | T401 (verify) |
| FR-006 (other namespaces untouched) | T104 (zero stale refs check, indirect proxy) |
| FR-007 (chat-backend unchanged) | n/a — no chat-backend tasks |
| FR-008 (drop RQ-002a) | T200 |
| FR-009 (add RQ-002b) | T201 |

| SC | Tasks |
|----|-------|
| SC-001 (tile label honest under all 3 locales) | T100, T101, T102, T103, T400 |
| SC-002 (RQ-002b passes) | T201, T402 |
| SC-003 (zero stale refs to old key) | T104 |
| SC-004 (MC-64 closeable) | T403 |

---

**Total tasks**: 18 (2 setup, 7 frontend, 4 regression, 6 PR/merge/verify/close).
**Estimated effort**: ~30 minutes engineer-time for the code edits; another ~30 minutes for PR cycle + verification.

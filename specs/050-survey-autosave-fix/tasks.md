# Tasks: Survey Schema Autosave Fix + Regression Coverage

**Input**: Design documents from `/specs/050-survey-autosave-fix/`
**Prerequisites**: plan.md (required), spec.md (required for user stories)

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

## Path Conventions

- **workbench-frontend**: `D:\src\MHG\workbench-frontend\src\`
- **client-spec**: `D:\src\MHG\client-spec\`
- **chat-types**: `D:\src\MHG\chat-types\src\`

---

## Phase 1: Setup

**Purpose**: Create feature branch in workbench-frontend and verify current state

- [x] T001 Create feature branch `050-survey-autosave-fix` from develop in workbench-frontend repo at `D:\src\MHG\workbench-frontend`
- [x] T002 Read current source files to capture baseline: `useDebouncedSave.ts`, `SaveStatusIndicator.tsx`, `SurveySchemaEditorView.tsx` in workbench-frontend/src/features/workbench/surveys/
- [x] T003 [P] Read current regression test file at client-spec/regression-suite/07-survey-schemas.yaml to capture baseline test count and last test ID

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Extend the SaveStatus type — all US1/US2/US3 changes depend on this

**⚠️ CRITICAL**: US1, US2, US3 all modify useDebouncedSave.ts and share the SaveStatus type — this must be done first

- [x] T004 Extend the `SaveStatus` type union from `'idle' | 'saving' | 'saved' | 'error'` to add `'validation_blocked'` in workbench-frontend/src/features/workbench/surveys/hooks/useDebouncedSave.ts (line 5)
- [x] T005 Extend `UseDebouncedSaveOptions` interface to accept an `onSaveSuccess` callback `(data: SurveySchema) => void` in workbench-frontend/src/features/workbench/surveys/hooks/useDebouncedSave.ts (lines 7-15)

**Checkpoint**: SaveStatus type and hook interface extended — user story work can begin

---

## Phase 3: User Story 1 — Race Condition Fix: Edits During In-Flight Save (Priority: P1) 🎯 MVP

**Goal**: Eliminate silent data loss when the user edits while autosave is in-flight

**Independent Test**: Edit title, wait for save to start, edit title again, verify server has the latest value

### Implementation for User Story 1

- [x] T006 [US1] Add `pendingSaveRef = useRef(false)` to track blocked saves in `useDebouncedSave` hook at workbench-frontend/src/features/workbench/surveys/hooks/useDebouncedSave.ts (near line 45)
- [x] T007 [US1] Replace early return `if (savingRef.current) return` with `if (savingRef.current) { pendingSaveRef.current = true; return; }` in doSave() at workbench-frontend/src/features/workbench/surveys/hooks/useDebouncedSave.ts (line 54)
- [x] T008 [US1] After the in-flight save completes (line 78, after `savingRef.current = false`), check `pendingSaveRef.current` — if true, reset it and schedule immediate `doSave()` call via `setTimeout(doSave, 0)` in workbench-frontend/src/features/workbench/surveys/hooks/useDebouncedSave.ts
- [x] T009 [US1] Add `editCountRef = useRef(0)` — increment it in the debounce useEffect on every edit; add `savedEditCountRef = useRef(0)` — capture `editCountRef.current` at save-start in doSave() at workbench-frontend/src/features/workbench/surveys/hooks/useDebouncedSave.ts
- [x] T010 [US1] Change `setHasUnsavedChanges(false)` to only run when `editCountRef.current === savedEditCountRef.current` (no edits occurred during the save) — otherwise keep `hasUnsavedChanges = true` in workbench-frontend/src/features/workbench/surveys/hooks/useDebouncedSave.ts (line 84)

### Unit Tests for User Story 1

- [x] T034 [US1] Add Vitest unit test: when `savingRef.current` is true, calling `doSave()` sets `pendingSaveRef.current = true` and does NOT fire an API request — in workbench-frontend/src/features/workbench/surveys/hooks/__tests__/useDebouncedSave.test.ts
- [x] T035 [US1] Add Vitest unit test: after in-flight save completes with `pendingSaveRef.current = true`, a retry save is scheduled with the latest state — in workbench-frontend/src/features/workbench/surveys/hooks/__tests__/useDebouncedSave.test.ts

**Checkpoint**: Race condition eliminated — edits during in-flight saves are queued and retried automatically

---

## Phase 4: User Story 2 — Silent Validation Gate Feedback (Priority: P1)

**Goal**: Show users a clear indicator when autosave is blocked by incomplete questions

**Independent Test**: Add question with empty text, wait 3s, verify save status shows validation message instead of stale "Saved" time

### Implementation for User Story 2

- [x] T011 [US2] Replace silent `return` statements in the validation gate section (lines 57-66) of doSave() with `setSaveStatus('validation_blocked'); return;` in workbench-frontend/src/features/workbench/surveys/hooks/useDebouncedSave.ts
- [x] T012 [US2] Add `'validation_blocked'` rendering branch to SaveStatusIndicator: amber `AlertCircle` icon + text using i18n key `survey.autosave.validationBlocked` with defaultValue "Complete all questions to save" in workbench-frontend/src/features/workbench/surveys/components/SaveStatusIndicator.tsx
- [x] T013 [P] [US2] Add i18n key `survey.autosave.validationBlocked` = "Complete all questions to save" to workbench-frontend/src/locales/en.json
- [x] T014 [P] [US2] Add i18n key `survey.autosave.validationBlocked` = "Заповніть усі питання для збереження" to workbench-frontend/src/locales/uk.json
- [x] T015 [P] [US2] Add i18n key `survey.autosave.validationBlocked` = "Заполните все вопросы для сохранения" to workbench-frontend/src/locales/ru.json

### Unit Tests for User Story 2

- [x] T036 [US2] Add Vitest unit test (positive): when question text is empty, `doSave()` sets `saveStatus` to `'validation_blocked'` — in workbench-frontend/src/features/workbench/surveys/hooks/__tests__/useDebouncedSave.test.ts
- [x] T037 [US2] Add Vitest unit test (negative): when all questions are complete, `doSave()` does NOT set `'validation_blocked'` and proceeds to API call — in workbench-frontend/src/features/workbench/surveys/hooks/__tests__/useDebouncedSave.test.ts

**Checkpoint**: Validation gate provides visible feedback — no more silent autosave blocking

---

## Phase 5: User Story 3 — Sync Server-Assigned Question IDs After Autosave (Priority: P2)

**Goal**: After each successful autosave, merge server-assigned question UUIDs back into local state to prevent ID churn

**Independent Test**: Add question, wait for autosave, edit question, verify second PATCH includes server-assigned UUID

### Implementation for User Story 3

- [x] T016 [US3] Add `skipNextEffectRef = useRef(false)` to prevent the ID sync from triggering a new debounce cycle in useDebouncedSave at workbench-frontend/src/features/workbench/surveys/hooks/useDebouncedSave.ts
- [x] T017 [US3] Call `onSaveSuccess(result.data)` callback inside the `if (result.success && result.data)` block (after line 83) of doSave() in workbench-frontend/src/features/workbench/surveys/hooks/useDebouncedSave.ts
- [x] T018 [US3] Set `skipNextEffectRef.current = true` before calling `onSaveSuccess` in doSave(), and check/reset it at the top of the debounce useEffect to skip one trigger cycle in workbench-frontend/src/features/workbench/surveys/hooks/useDebouncedSave.ts (line 91)
- [x] T019 [US3] Define `handleSaveSuccess` callback in SurveySchemaEditorView that merges server question IDs: `setQuestions(prev => prev.map((q, i) => result.questions[i] ? { ...q, id: result.questions[i].id } : q))` at workbench-frontend/src/features/workbench/surveys/SurveySchemaEditorView.tsx
- [x] T020 [US3] Pass `onSaveSuccess: handleSaveSuccess` to the `useDebouncedSave` options object in SurveySchemaEditorView at workbench-frontend/src/features/workbench/surveys/SurveySchemaEditorView.tsx (line 42-50)

### Unit Tests for User Story 3

- [x] T038 [US3] Add Vitest unit test: after successful save, `onSaveSuccess` callback is invoked with `result.data` containing server-assigned question IDs — in workbench-frontend/src/features/workbench/surveys/hooks/__tests__/useDebouncedSave.test.ts
- [x] T039 [US3] Add Vitest unit test: when `skipNextEffectRef.current` is true, the debounce useEffect skips one cycle and resets the flag — in workbench-frontend/src/features/workbench/surveys/hooks/__tests__/useDebouncedSave.test.ts

**Checkpoint**: Question IDs are stable across saves — eliminates root cause of historical 422-fix cycle

---

## Phase 6: User Story 4 — Regression Test Suite: Survey Schema Autosave Coverage (Priority: P1)

**Goal**: Add 8 new autosave-specific regression tests to 07-survey-schemas.yaml

**Independent Test**: Run `module:07-survey-schemas` and verify SS-010 through SS-017 pass on dev environment

### Implementation for User Story 4

- [x] T021 [P] [US4] Add test SS-010 "Autosave triggers after title edit" (P1, smoke) to regression-suite/07-survey-schemas.yaml: create schema, edit title, wait 3s, verify PATCH request with 200 status via browser_network_requests
- [x] T022 [P] [US4] Add test SS-011 "Autosave with all 16 question types" (P1) to regression-suite/07-survey-schemas.yaml: create schema, add one question of each type (free_text, integer_signed, integer_unsigned, decimal, date, time, datetime, rating_scale, email, phone, url, postal_code, alphanumeric_code, single_choice, multi_choice, boolean) with text and type-specific config, wait 4s, verify PATCH returns 200 with all 16 questions
- [x] T023 [P] [US4] Add test SS-012 "Save status shows Saved after successful save" (P1) to regression-suite/07-survey-schemas.yaml: create schema, edit title, wait 3s, verify snapshot contains status element with "Saved" text and checkmark
- [x] T024 [P] [US4] Add test SS-013 "Validation gate blocks save for empty question text" (P1) to regression-suite/07-survey-schemas.yaml: create schema with title, add question with empty text, wait 4s, verify NO new PATCH request was sent, verify save status does NOT show "Saved"
- [x] T025 [P] [US4] Add test SS-014 "Validation gate shows feedback indicator" (P1) to regression-suite/07-survey-schemas.yaml: after SS-013 scenario, verify save status element shows validation-blocked message (not stale "Saved" timestamp)
- [x] T026 [P] [US4] Add test SS-015 "Autosave resumes after completing question" (P1) to regression-suite/07-survey-schemas.yaml: after SS-013 scenario, fill in question text, wait 3s, verify new PATCH request fires with 200 status and save status returns to "Saved"
- [x] T027 [P] [US4] Add test SS-016 "Choice question options saved correctly" (P2) to regression-suite/07-survey-schemas.yaml: create schema, add single_choice question with 3 options + multi_choice question with 4 options, verify PATCH payload includes correct options arrays

- [x] T040 [P] [US4] Add test SS-017 "Save error shows retry button" (P1, negative) to regression-suite/07-survey-schemas.yaml: use browser_evaluate to intercept PATCH with a 500 response, trigger autosave, verify save status shows "Save failed" with "Retry" button, click Retry, verify new PATCH request fires

**Checkpoint**: 8 new regression tests added (7 positive + 1 negative), all executable by AI agent via Playwright MCP

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Verification, cleanup, and documentation

- [x] T028 Run `npm run build` in workbench-frontend to verify TypeScript compiles without errors
- [ ] T029 Run existing regression suite `module:07-survey-schemas` (SS-001 through SS-009) to verify no regressions in existing tests
- [ ] T030 Run new regression tests (SS-010 through SS-017) on dev environment to verify all pass
- [ ] T031 Manual browser verification: open schema editor, add a question with empty text, confirm validation-blocked indicator appears, fill text, confirm autosave resumes with "Saved" status
- [x] T032 Update regression-suite module header comment in 07-survey-schemas.yaml to reflect new test count (was 9, now 17)
- [x] T033 Commit all changes in workbench-frontend with descriptive message referencing bug fix

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Setup — BLOCKS all user stories
- **US1 Race Condition (Phase 3)**: Depends on Phase 2 — modifies useDebouncedSave.ts
- **US2 Validation Gate (Phase 4)**: Depends on Phase 2 — modifies useDebouncedSave.ts + SaveStatusIndicator.tsx
- **US3 ID Sync (Phase 5)**: Depends on Phase 2 — modifies useDebouncedSave.ts + SurveySchemaEditorView.tsx
- **US4 Regression Tests (Phase 6)**: Can start after Phase 2 (parallel with US1-3) — separate file in client-spec
- **Polish (Phase 7)**: Depends on ALL previous phases

### User Story Dependencies

- **US1 (P1)**: Depends on Phase 2 only — independent of US2/US3
- **US2 (P1)**: Depends on Phase 2 only — independent of US1/US3 (but shares useDebouncedSave.ts)
- **US3 (P2)**: Depends on Phase 2 only — independent of US1/US2 (but shares useDebouncedSave.ts)
- **US4 (P1)**: Depends on Phase 2 only — completely independent (different repo, different file)

**⚠️ NOTE**: US1, US2, US3 all modify `useDebouncedSave.ts` — they CANNOT be parallelized in practice. Recommended execution order: US1 → US2 → US3 (or US1 + US2 together since they modify different sections of the file).

### Within Each User Story

- Core hook logic before UI changes
- UI changes before i18n
- All implementation before regression tests
- Regression tests before verification

### Parallel Opportunities

- T013, T014, T015 (i18n files) can run in parallel — different files, no dependencies
- T021-T027 (regression test definitions) can all run in parallel — appending to same YAML but independent test blocks
- US4 (regression tests in client-spec) can run in parallel with US1-3 (code changes in workbench-frontend) — different repositories

---

## Parallel Example: User Story 4

```bash
# All regression test definitions can be authored in parallel:
Task T021: "SS-010 - Autosave triggers after title edit"
Task T022: "SS-011 - Autosave with all 16 question types"
Task T023: "SS-012 - Save status shows Saved"
Task T024: "SS-013 - Validation gate blocks save"
Task T025: "SS-014 - Validation gate shows feedback"
Task T026: "SS-015 - Autosave resumes after completing question"
Task T027: "SS-016 - Choice question options saved correctly"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T003)
2. Complete Phase 2: Foundational (T004-T005)
3. Complete Phase 3: US1 Race Condition (T006-T010)
4. **STOP and VALIDATE**: Manually test that edits during in-flight saves are queued
5. Deploy and verify — this alone fixes the most critical user complaint

### Incremental Delivery

1. Setup + Foundational → Type and interface ready
2. Add US1 (Race Condition) → Test → Deploy (MVP!)
3. Add US2 (Validation Gate) → Test → Deploy — users now see clear feedback
4. Add US3 (ID Sync) → Test → Deploy — root cause of historical 422 cycle eliminated
5. Add US4 (Regression Tests) → Run suite → Commit — safety net for future changes
6. Polish → Final verification → PR

---

## Notes

- All US1-US3 changes are in `workbench-frontend` — a single PR
- US4 changes are in `client-spec` — can be a separate PR or same if combined commit
- The `chat-backend` requires NO changes — backend validation is already correct
- The `chat-types` package requires NO changes — SaveStatus is local to the hook
- Test regression tests (SS-010 through SS-017) should be run AFTER US1+US2 fixes are deployed to dev, since SS-014 validates the new validation-blocked indicator

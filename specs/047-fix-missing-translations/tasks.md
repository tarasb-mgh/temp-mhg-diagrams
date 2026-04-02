# Tasks: Fix Missing Translations

**Input**: Design documents from `/specs/047-fix-missing-translations/`
**Prerequisites**: plan.md (required), spec.md (required)

## Phase 1: Fix Missing Translations (workbench-frontend) — US1 🎯 MVP

**Goal**: Add all 56 missing `agents.*` translation keys to UK and RU locale files

**Independent Test**: Run `node -e` key comparison script — 0 missing keys reported

- [x] T001 [US1] Add 56 missing `agents.*` keys with Ukrainian translations to `workbench-frontend/src/locales/uk.json`
- [x] T002 [US1] Add 56 missing `agents.*` keys with Russian translations to `workbench-frontend/src/locales/ru.json`
- [x] T003 [US1] Verify key counts match: EN=1491, UK=1491, RU=1491

**Checkpoint**: All three locale files in workbench-frontend have identical key sets

---

## Phase 2: CI Validation Scripts — US2

**Goal**: Every frontend repo has a `check-locale-keys.ts` script and `i18n:check` npm script

**Independent Test**: Run `npm run i18n:check` in each repo — exits 0 when complete, exits 1 when key is removed

### workbench-frontend

- [x] T004 [P] [US2] Copy `chat-frontend/scripts/check-locale-keys.ts` to `workbench-frontend/scripts/check-locale-keys.ts`
- [x] T005 [P] [US2] Add `"i18n:check": "npx tsx scripts/check-locale-keys.ts"` to `workbench-frontend/package.json` scripts
- [x] T006 [US2] Run `npm run i18n:check` in workbench-frontend — verify exit 0

### chat-frontend

- [x] T007 [P] [US2] Add `"i18n:check": "npx tsx scripts/check-locale-keys.ts"` to `chat-frontend/package.json` scripts
- [x] T008 [US2] Run `npm run i18n:check` in chat-frontend — verify exit 0

### chat-frontend-common

- [x] T009 [US2] Create `chat-frontend-common/scripts/check-locale-keys.ts` adapted for `src/locales/{lang}/common.json` directory structure
- [x] T010 [US2] Add `"i18n:check": "npx tsx scripts/check-locale-keys.ts"` to `chat-frontend-common/package.json` scripts
- [x] T011 [US2] Run `npm run i18n:check` in chat-frontend-common — verify exit 0

**Checkpoint**: All three repos pass `npm run i18n:check`

---

## Phase 3: Wire into CI Workflows — US2

**Goal**: Translation completeness check runs on every PR and blocks merge if keys are missing

- [x] T012 [P] [US2] Add `check-locale-keys` step to `workbench-frontend/.github/workflows/ci.yml` after npm install, before build
- [x] T013 [P] [US2] Add `check-locale-keys` step to `chat-frontend/.github/workflows/ci.yml` after npm install, before build
- [x] T014 [P] [US2] Add `check-locale-keys` step to `chat-frontend-common/.github/workflows/publish.yml` after npm install, before build

**Checkpoint**: CI pipelines include translation validation

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1**: No dependencies — can start immediately
- **Phase 2**: T004–T006 depend on Phase 1 completion (workbench-frontend must have all keys before script can pass)
- **Phase 2**: T007–T011 are independent of Phase 1 (chat-frontend and common already have complete keys)
- **Phase 3**: Depends on Phase 2 (scripts must exist before CI can reference them)

### Parallel Opportunities

- T001 and T002 can run in parallel (different files)
- T004, T005, T007 can run in parallel (different repos)
- T012, T013, T014 can run in parallel (different repos)

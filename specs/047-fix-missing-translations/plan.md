# Implementation Plan: Fix Missing Translations

**Branch**: `047-fix-missing-translations` | **Date**: 2026-04-02 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/047-fix-missing-translations/spec.md`

## Summary

56 translation keys in workbench-frontend (all in `agents.*` namespace) are present in `en.json` but missing from `uk.json` and `ru.json`. No CI check prevents this from recurring. The fix adds the missing translations, copies the existing `check-locale-keys.ts` validation script to workbench-frontend and chat-frontend-common, wires it into CI for all three frontend repositories, and adds an npm script for local use.

## Technical Context

**Language/Version**: TypeScript 5.x, Node.js 20+
**Primary Dependencies**: react-i18next, i18next, tsx (script runner)
**Storage**: N/A (JSON locale files only)
**Testing**: Script-based validation (exit code 0/1), CI workflow step
**Target Platform**: GitHub Actions CI
**Project Type**: Cross-repo tooling + data fix
**Constraints**: Must not break existing CI pipelines; script must run in < 5 seconds

## Constitution Check

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Spec-first | PASS | This spec created before implementation |
| II. Single responsibility | PASS | One concern: translation completeness |
| III. Simplicity | PASS | Reuses existing proven script from chat-frontend |
| IV. Security & privacy | N/A | No sensitive data involved |
| V. Testing | PASS | The deliverable IS a test/validation tool |
| VI. Accessibility & i18n | PASS | Directly enforces i18n completeness |
| VI-B. Design system | N/A | No UI changes |

## Project Structure

### Documentation (this feature)

```text
specs/047-fix-missing-translations/
├── plan.md              # This file
├── spec.md              # Feature specification
└── tasks.md             # Task breakdown
```

### Source Code (affected repositories)

```text
workbench-frontend/
├── src/locales/
│   ├── en.json          # Reference locale (1491 keys)
│   ├── uk.json          # ADD 56 missing agents.* keys
│   └── ru.json          # ADD 56 missing agents.* keys
├── scripts/
│   └── check-locale-keys.ts   # NEW — copy from chat-frontend, adapt paths
├── package.json         # ADD "i18n:check" script
└── .github/workflows/
    └── ci.yml           # ADD locale check step

chat-frontend/
├── scripts/
│   └── check-locale-keys.ts   # EXISTS — already working
├── package.json         # ADD "i18n:check" script
└── .github/workflows/
    └── ci.yml           # ADD locale check step

chat-frontend-common/
├── scripts/
│   └── check-locale-keys.ts   # NEW — adapted for src/locales/{lang}/common.json structure
├── package.json         # ADD "i18n:check" script
└── .github/workflows/
    └── publish.yml      # ADD locale check step
```

## Implementation Approach

### Phase 1: Fix missing translations (workbench-frontend)

Add 56 missing `agents.*` keys to `uk.json` and `ru.json` with proper Ukrainian and Russian translations. All keys are UI labels (statuses, buttons, column headers, empty states) — most are short strings suitable for direct translation.

### Phase 2: Add CI validation to all three repos

1. **chat-frontend**: Wire existing `check-locale-keys.ts` into `package.json` as `"i18n:check"` script, add step to `ci.yml`
2. **workbench-frontend**: Copy and adapt `check-locale-keys.ts`, add to `package.json` and `ci.yml`
3. **chat-frontend-common**: Create adapted version for `src/locales/{lang}/common.json` directory structure, add to `package.json` and `publish.yml`

### Script Design

The `check-locale-keys.ts` script from chat-frontend is already well-designed:
- Uses `en` as reference locale
- Extracts leaf keys from nested JSON
- Reports missing keys as errors (exit 1)
- Reports extra keys as warnings (exit 0)
- Supports namespace subdirectories

For **workbench-frontend**: Copy as-is (same `src/locales/*.json` structure).
For **chat-frontend-common**: Adapt to handle `src/locales/{lang}/common.json` directory layout where locale is the directory and `common.json` is the file.

### CI Integration

Add a step before the build step in each repo's CI workflow:

```yaml
- name: Check translation completeness
  run: npx tsx scripts/check-locale-keys.ts
```

This runs after `npm install` (tsx is already available) and before build/test, so translation issues are caught early and clearly.

## Complexity Tracking

No constitution violations. The approach reuses an existing, proven script pattern.

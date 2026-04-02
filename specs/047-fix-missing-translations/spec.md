# Bug Specification: Missing Translation Keys Across Frontends

**Feature Branch**: `047-fix-missing-translations`
**Created**: 2026-04-02
**Status**: Draft
**Severity**: Medium
**Affected Repositories**: `workbench-frontend`, `chat-frontend`, `chat-frontend-common`

## Problem Statement

Multiple translation keys across the MHG frontend applications have missing or empty values in one or more supported locales (en, uk, ru). When a key is referenced in code via `react-i18next` but has no value in the corresponding locale JSON file, the UI renders the raw key string (e.g., `review.sessionCard.myStatus.in_progress`) instead of a human-readable label.

This is a systemic quality issue — each new feature adds translation keys, but there is no automated check to ensure all three locales remain complete and consistent.

### Audit Results (2026-04-02)

| Repository | EN keys | UK keys | RU keys | Missing in UK | Missing in RU |
|---|---|---|---|---|---|
| workbench-frontend | 1491 | 1435 | 1435 | **56** | **56** |
| chat-frontend | 488 | 488 | 488 | 0 | 0 |
| chat-frontend-common | 82 | 82 | 82 | 0 | 0 |

All 56 missing keys in workbench-frontend are in the `agents.*` namespace (runs, schedules, statuses, trigger types) — added with the Synthetic Agents feature but translations were never provided for UK/RU.

**chat-frontend** already has a validation script (`scripts/check-locale-keys.ts`) but it is not wired into CI or `package.json` scripts.

### Root Cause

No CI-level validation exists to catch:
1. Keys present in one locale file but absent in another
2. Keys with empty string values (`""`)
3. Keys referenced in source code but missing from all locale files
4. Stale keys present in locale files but no longer referenced in code

## User Scenarios & Testing

### User Story 1 — Fix all existing missing translation values (Priority: P1)

A user navigating the workbench or chat frontend in any supported locale (en, uk, ru) sees fully translated UI text for every visible element. No raw translation keys are displayed anywhere.

**Why this priority**: Raw key strings in the UI break the user experience and make the product look unfinished. This is the immediate fix.

**Independent Test**: Run a script that compares all keys across en.json, uk.json, and ru.json for each frontend repository and reports any key present in one file but missing or empty in another.

**Acceptance Scenarios**:

1. **Given** the workbench-frontend locale files (en, uk, ru), **When** a full key comparison is run, **Then** every key present in any locale file exists with a non-empty value in all three locale files
2. **Given** the chat-frontend locale files, **When** the same comparison is run, **Then** every key present in any locale file exists with a non-empty value in all three locale files
3. **Given** the chat-frontend-common locale files, **When** the same comparison is run, **Then** every key present in any locale file exists with a non-empty value in all three locale files

---

### User Story 2 — Add CI check to prevent future missing translations (Priority: P1)

A developer adds a new feature with translation keys. Before the PR can be merged, a CI check automatically verifies that all translation keys are present and non-empty across all three locales. If any key is missing or empty, the CI check fails with a clear error message listing the offending keys.

**Why this priority**: Without this gate, the same problem will recur with every new feature. The preventive check is as important as the fix itself.

**Independent Test**: Create a PR that intentionally adds a key to en.json but not uk.json, and verify the CI check fails with a clear message.

**Acceptance Scenarios**:

1. **Given** a PR that adds a new key to en.json but not uk.json, **When** CI runs, **Then** the translation completeness check fails and reports the missing key and locale
2. **Given** a PR where all three locale files have identical key sets with non-empty values, **When** CI runs, **Then** the translation completeness check passes
3. **Given** a PR that adds a key with an empty string value (`""`), **When** CI runs, **Then** the check fails and reports the empty value

---

### User Story 3 — Detect unused/stale translation keys (Priority: P2)

Over time, translation keys accumulate that are no longer referenced in source code. A CI check or manual script identifies these stale keys so they can be cleaned up.

**Why this priority**: Stale keys increase maintenance burden and locale file size but don't cause visible bugs. Lower priority than missing keys.

**Independent Test**: Run a script that cross-references all keys in locale files against `useTranslation`/`t()` calls in source code and reports unreferenced keys.

**Acceptance Scenarios**:

1. **Given** locale files with keys that are not referenced anywhere in source code, **When** the stale-key check runs, **Then** it reports those keys as potentially unused
2. **Given** all locale keys are referenced in source code, **When** the check runs, **Then** it reports zero stale keys

---

### Edge Cases

- What happens when locale files use nested JSON structures vs flat dot-notation keys? (script must handle both)
- What happens when a key is referenced dynamically (e.g., `t(\`status.${variable}\`)`)? (stale-key check should have an allowlist mechanism)
- What happens when chat-frontend-common provides shared keys used by both frontends? (cross-repo key resolution)
- What happens with namespace-scoped translations (e.g., `useTranslation('tags')`)? (script must handle namespaced files)

## Requirements

### Functional Requirements

- **FR-001**: A translation completeness script MUST compare all keys across en, uk, and ru locale files and report any key that is missing or has an empty value in any locale
- **FR-002**: The script MUST support both flat and nested JSON locale file structures
- **FR-003**: The script MUST support namespaced locale files (e.g., `en/translation.json`, `en/tags.json`)
- **FR-004**: A CI workflow step MUST run the completeness check on every PR and fail if missing/empty keys are found
- **FR-005**: The CI check output MUST clearly list each missing key, the locale(s) where it's missing, and the file path
- **FR-006**: All currently missing translation values MUST be filled in with appropriate translations (uk, ru) or English fallback placeholders clearly marked for human review
- **FR-007**: The stale-key detection script SHOULD identify keys not referenced in source code (warning-only, not blocking CI)
- **FR-008**: Dynamic key patterns (template literals in `t()` calls) MUST be documentable via an allowlist to prevent false positives in stale-key detection

## Success Criteria

### Measurable Outcomes

- **SC-001**: Zero raw translation keys visible in the workbench-frontend UI across all three locales
- **SC-002**: Zero raw translation keys visible in the chat-frontend UI across all three locales
- **SC-003**: CI translation completeness check runs on every PR in workbench-frontend, chat-frontend, and chat-frontend-common
- **SC-004**: A PR intentionally missing a translation key is blocked by CI with a clear error message
- **SC-005**: All locale files across all three repositories have identical key sets with non-empty values

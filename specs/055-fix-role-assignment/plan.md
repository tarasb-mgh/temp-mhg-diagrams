# Implementation Plan: 055-fix-role-assignment

**Branch**: `055-fix-role-assignment` | **Date**: 2026-04-16 | **Spec**: [spec.md](spec.md)  
**Jira Epic**: [MTB-1351](https://mentalhelpglobal.atlassian.net/browse/MTB-1351)

## Summary

Fix 500 Internal Server Error when assigning new roles (`expert`, `admin`, `master`) to users via the Workbench. The root cause is a PostgreSQL CHECK constraint on `users.role` that was never updated when the `UserRole` enum was extended in MVP 048. The fix is a single database migration that extends the constraint to include all 10 roles.

## Technical Context

**Language/Version**: TypeScript 5.x (Node.js backend)  
**Primary Dependencies**: Express.js, pg (PostgreSQL client), @mentalhelpglobal/chat-types  
**Storage**: PostgreSQL (Cloud SQL)  
**Testing**: Vitest (unit tests with mocked DB)  
**Target Platform**: Linux server (GCP Cloud Run)  
**Project Type**: Web service (backend API)  
**Performance Goals**: N/A (no performance impact — single ALTER TABLE)  
**Constraints**: Migration must be backward-compatible and idempotent  
**Scale/Scope**: Single migration file, single schema reference update, one test file

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Spec-First Development | PASS | Spec created before implementation via `/speckit.specify` |
| II. Multi-Repository Orchestration | PASS | Only `chat-backend` affected; no cross-repo dependencies |
| III. Test-Aligned Development | PASS | 13 regression tests in `changeUserRole.test.ts` covering all 10 roles (positive + negative) |
| IV. Branch and Integration Discipline | PASS | Feature branch `055-fix-role-assignment` created; PR workflow to follow |
| V. Privacy and Security First | PASS | Audit logging for role changes already exists; no new PII exposure |
| VI. Accessibility and i18n | N/A | Backend-only change; no UI modifications |
| VI-B. Design System Compliance | N/A | No UI changes |
| VII. Split-Repository First | PASS | Implementing in `chat-backend` split repo |
| VIII. GCP CLI Infrastructure | N/A | No infrastructure changes |
| IX. Responsive UX / PWA | N/A | No frontend changes |
| X. Jira Traceability | PASS | Epic MTB-1351 created |
| XI. Documentation Standards | DEFERRED | Confluence updates after production deploy |
| XII. Release Engineering | PENDING | Owner approval required before release |
| XIII. CX Agent Management | N/A | No Dialogflow CX changes |

## Project Structure

### Documentation (this feature)

```text
specs/055-fix-role-assignment/
├── spec.md
├── plan.md                  # This file
├── research.md              # Root cause analysis and fix decisions
├── data-model.md            # users.role constraint change details
├── quickstart.md            # How to apply and verify the fix
├── checklists/
│   └── requirements.md      # Spec quality checklist
└── tasks.md                 # Task breakdown (created by /speckit.tasks)
```

### Source Code (chat-backend)

```text
chat-backend/
├── src/
│   └── db/
│       ├── migrations/
│       │   └── 063_055-extend-user-role-constraint.sql  # NEW — extends CHECK constraint
│       └── schema.sql                                    # MODIFIED — updated valid_role
└── tests/
    └── unit/
        └── changeUserRole.test.ts                        # NEW — 13 regression tests
```

**Structure Decision**: All changes are within `chat-backend`. No cross-repo changes needed — `chat-types` already has the correct enum, and the frontend already renders all roles correctly.

## Implementation Approach

### Phase 0: Research (Complete)

Root cause fully identified and documented in [research.md](research.md):
- CHECK constraint mismatch between DB and application-layer enum
- Fix follows the established pattern from migration 016

### Phase 1: Design (Complete)

Data model change documented in [data-model.md](data-model.md):
- Single constraint replacement on `users.role`
- No new tables, columns, or relationships

### Phase 2: Implementation

| Step | Repository | File | Description |
|------|-----------|------|-------------|
| 1 | chat-backend | `src/db/migrations/063_055-extend-user-role-constraint.sql` | New migration: drop old constraint, add new one with all 10 roles |
| 2 | chat-backend | `src/db/schema.sql` | Update `valid_role` constraint to match migration |
| 3 | chat-backend | `tests/unit/changeUserRole.test.ts` | Regression tests: parameterized across all UserRole values |
| 4 | chat-backend | — | Run full test suite to verify no regressions |
| 5 | chat-backend | — | Deploy to dev via workflow_dispatch, verify role assignment works |

### Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Migration fails on dev DB | Low | Low | Pattern proven by migration 016; `DO $$` block handles missing constraint |
| Existing user roles broken | Very Low | High | Migration only expands allowed values; existing data untouched |
| Other tables have role constraints | Very Low | Medium | Verified: no other tables reference `users.role` via FK or CHECK |

## Complexity Tracking

No constitution violations to justify. This is a minimal, single-repo bug fix.

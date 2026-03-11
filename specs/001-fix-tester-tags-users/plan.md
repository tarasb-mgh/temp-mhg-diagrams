# Implementation Plan: Fix Tester-Tag User Listing Failure

**Branch**: `001-fix-tester-tags-users` | **Date**: 2026-03-11 | **Spec**: [spec.md](./spec.md)  
**Jira Epic**: [MTB-692](https://mentalhelpglobal.atlassian.net/browse/MTB-692) | **Jira Bug**: [MTB-703](https://mentalhelpglobal.atlassian.net/browse/MTB-703)  
**Input**: Feature specification from `/specs/001-fix-tester-tags-users/spec.md`

## Summary

The `GET /api/admin/tester-tags/users` endpoint returns `500 INTERNAL_ERROR` for all authorized callers, including owners, because `testerTag.service.ts` requires a `tag_definitions` row named `tester` that has never been seeded. The fix is a single new idempotent migration (`032_seed_tester_tag_definition.sql`) in `chat-backend` plus a hardened error-mapping improvement in the same route so that a missing tag definition surfaces as a clear operational error rather than a generic 500.

No shared-type changes, no frontend changes, and no cross-repo dependency changes are needed.

## Technical Context

**Language/Version**: Node.js 20 / TypeScript 5.6  
**Primary Dependencies**: Express 5.x, `pg` (PostgreSQL client), Vitest  
**Storage**: PostgreSQL 15 — `tag_definitions` and `user_tags` tables  
**Testing**: Vitest (unit) in `chat-backend`; `npm run typecheck` gate  
**Target Platform**: GCP Cloud Run (Linux server)  
**Performance Goals**: p95 latency for the user-list endpoint ≤ 500 ms (unchanged from existing backend SLA)  
**Constraints**: Migration MUST be idempotent (`ON CONFLICT DO NOTHING`); MUST NOT drop or alter existing rows  
**Scale/Scope**: Single-repo fix touching one migration file and one route handler

## Constitution Check

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Spec-First | ✅ Pass | spec.md exists and is clarified |
| II. Multi-Repo | ✅ Pass | Only `chat-backend` is affected; no cross-repo changes |
| III. Test-Aligned | ✅ Pass | Unit test added for missing-tag-definition edge case in Vitest |
| IV. Branch Discipline | ✅ Pass | Feature branch `001-fix-tester-tags-users` off `develop` |
| V. Privacy & Security | ✅ Pass | No new PII surface; existing audit logging unchanged |
| VI. Accessibility / i18n | ✅ Pass | Backend-only; no UI or translation strings changed |
| VII. Split-Repo First | ✅ Pass | `chat-backend` only; no monorepo changes |
| VIII. GCP CLI Infra | ✅ Pass | Migration applied via existing `apply-migration.js` script |
| IX. Responsive/PWA | N/A | Backend fix only |
| X. Jira Traceability | ✅ Required | Jira Epic + comment needed after plan |
| XI. Documentation | ✅ Required | Technical Onboarding update for migration step |
| XII. Release Engineering | ✅ Pass | Migration is idempotent; safe for dev → prod promotion |

## Project Structure

### Documentation (this feature)

```text
specs/001-fix-tester-tags-users/
├── spec.md                 ✅ Done
├── plan.md                 ← This file
├── research.md             ← Phase 0 output
├── data-model.md           ← Phase 1 output
├── quickstart.md           ← Phase 1 output
└── checklists/
    └── requirements.md     ✅ Done
```

### Source Code (affected files)

```text
chat-backend/
├── src/
│   ├── db/
│   │   └── migrations/
│   │       └── 032_seed_tester_tag_definition.sql   ← NEW
│   └── routes/
│       └── admin.testerTags.ts                      ← MODIFY (error mapping)
└── tests/
    └── unit/
        └── testerTag.route.test.ts                  ← NEW (or extend existing)
```

## Implementation Phases

### Phase 0 — Root Cause Research (complete)

Confirmed via code inspection:

1. `testerTag.service.ts` calls `getTesterTagDefinitionId()` on every request.
2. That function queries `tag_definitions` for `name = 'tester'`.
3. Migration `015_add_tagging_system.sql` created the table but only seeded `functional QA` and `short`.
4. No later migration seeds `tester`.
5. When the query returns zero rows, the service throws `TESTER_TAG_NOT_FOUND` (statusCode 404).
6. The `GET /users` route handler has no special handling for that error code — it catches all errors and returns `500 INTERNAL_ERROR`.

Two changes fix the issue:

| Change | File | Impact |
|--------|------|--------|
| Add `tester` row to `tag_definitions` | `032_seed_tester_tag_definition.sql` | Removes 500 for all environments after migration runs |
| Map `TESTER_TAG_NOT_FOUND` to 503 in route | `admin.testerTags.ts` | Defensive: if migration not yet applied, callers get a clear operational error |

### Phase 1 — Migration (P1, blocking)

Create `chat-backend/src/db/migrations/032_seed_tester_tag_definition.sql`:

```sql
BEGIN;
INSERT INTO tag_definitions (name, description, category, exclude_from_reviews, is_active)
VALUES (
  'tester',
  'Grants tester-only access to internal diagnostic UI features such as RAG detail panels. Assigned by Admin, Supervisor, or Owner roles.',
  'user',
  false,
  true
)
ON CONFLICT (name_lower) DO NOTHING;
COMMIT;
```

Apply via:
```bash
DATABASE_URL=<dev-url> node scripts/apply-migration.js 032_seed_tester_tag_definition.sql dev
```

### Phase 2 — Route Error Hardening (P1, parallel with Phase 1)

In `admin.testerTags.ts`, add a `TESTER_TAG_NOT_FOUND` branch in the `GET /users` handler:

```typescript
} catch (error: any) {
  if (error?.code === 'TESTER_TAG_NOT_FOUND') {
    return res.status(503).json({
      success: false,
      error: {
        code: 'SERVICE_UNAVAILABLE',
        message: 'Tester tag configuration is not yet set up. Contact an administrator.',
      },
    });
  }
  console.error('[Admin TesterTags] Error listing users:', error);
  res.status(500).json({ ... });
}
```

This ensures that if the migration has not yet been applied on a given environment, operators receive a clear 503 with an actionable message rather than a cryptic 500.

### Phase 3 — Unit Test Coverage (P2)

Add or extend a unit test in `chat-backend` that:
- Mocks the database pool to return zero rows for `tag_definitions` lookup.
- Asserts that `GET /api/admin/tester-tags/users` returns `503 SERVICE_UNAVAILABLE` (not 500).
- Mocks the normal flow (pool returns a valid `tester` row) and asserts `200 { success: true }`.

### Phase 4 — Local Validation

1. Apply migration `032` against dev DB.
2. Call `GET /api/admin/tester-tags/users` with an owner-role JWT.
3. Confirm `200 { success: true, data: [...] }`.
4. Run `npm run typecheck && npm run test:coverage`.
5. Confirm coverage threshold (≥ 45%) still passes.

## Cross-Repository Dependencies

None. This fix is entirely within `chat-backend`. No `chat-types`, `workbench-frontend`, or `chat-frontend-common` changes are needed.

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Duplicate `tester` row if migration applied twice | Low | `ON CONFLICT (name_lower) DO NOTHING` makes migration fully idempotent |
| Migration applied to prod before dev is validated | Low | CI workflow applies dev migration on `develop` push only; prod requires release branch |
| Route error change breaks existing tests | Low | Existing unit tests mock the DB pool and pass through; new branch is additive |

## Delivery Order

1. `032_seed_tester_tag_definition.sql` — create and apply in dev
2. `admin.testerTags.ts` — add `TESTER_TAG_NOT_FOUND` error branch
3. Unit test — cover both missing-tag and normal-tag paths
4. Local validation — `typecheck` + `test:coverage`
5. PR to `develop` — wait for green CI
6. Merge and clean up branch

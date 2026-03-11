# Research: Fix Tester-Tag User Listing Failure

**Branch**: `001-fix-tester-tags-users` | **Date**: 2026-03-11

## Root Cause Analysis

### Failure Chain

```
GET /api/admin/tester-tags/users
  → admin.testerTags.ts: GET /users handler
    → listTesterTagUsers({ query, eligibility })
      → testerTag.service.ts: getTesterTagDefinitionId()
        → SELECT id FROM tag_definitions WHERE name_lower = 'tester'
          → returns 0 rows
            → throws { code: 'TESTER_TAG_NOT_FOUND', statusCode: 404 }
  ← catch (error) → 500 INTERNAL_ERROR   ← NOT caught specifically
```

### Database State

Migration history (confirmed via `chat-backend/src/db/migrations/`):

| Migration | Creates/Seeds |
|-----------|--------------|
| `015_add_tagging_system.sql` | `tag_definitions` table, `user_tags` table; seeds `functional QA` and `short` |
| `016` – `031` | Unrelated to tagging |
| *(missing)* | `tester` row never seeded |

The `tag_definitions` table has a `name_lower` unique constraint (LOWER(name)) generated column or explicit unique index — the `ON CONFLICT (name_lower)` clause in the migration must match this.

### Service Code Path

`testerTag.service.ts` — key excerpt:

```typescript
async function getTesterTagDefinitionId(): Promise<string> {
  const result = await pool.query(
    `SELECT id FROM tag_definitions WHERE name_lower = $1`,
    ['tester']
  );
  if (result.rows.length === 0) {
    throw { code: 'TESTER_TAG_NOT_FOUND', statusCode: 404,
            message: 'Tester tag definition not found in database' };
  }
  return result.rows[0].id;
}
```

`listTesterTagUsers` calls this helper unconditionally, so the list endpoint fails even before any user query is executed.

### Route Error Mapping Gap

`admin.testerTags.ts` `GET /users` catch block (current):

```typescript
} catch (error) {
  console.error('[Admin TesterTags] Error listing users:', error);
  res.status(500).json({
    success: false,
    error: { code: 'INTERNAL_ERROR', message: 'Failed to list tester-tag users' },
  });
}
```

No branch for `error.code === 'TESTER_TAG_NOT_FOUND'`.

## Alternatives Considered

| Alternative | Verdict | Reason rejected |
|-------------|---------|-----------------|
| Re-run migration `015` with the `tester` row added | Rejected | `015` is already applied on all environments; re-running would be a no-op or require a version bump; violates standard migration practice |
| Remove the `getTesterTagDefinitionId` lookup and hard-code the category | Rejected | Breaks data integrity; future tag additions would not flow through the same code path |
| Lazy-create the tag definition if missing | Rejected | DDL inside application code; violates migration discipline; would silently hide missing seeds in other environments |
| Return a 200 with empty array if definition missing | Rejected | Masks a real configuration error; operators would not know migration is missing |

## Decision: New Idempotent Migration

**Migration `032_seed_tester_tag_definition.sql`** — rationale:

- All previous migrations are already applied in all environments.
- A new numbered migration is the standard incremental approach.
- `INSERT ... ON CONFLICT (name_lower) DO NOTHING` ensures safe re-application.
- The migration is self-contained and requires no schema changes.

## Tag Definition Attributes

Based on existing `functional QA` and `short` rows in `015`:

| Column | Value |
|--------|-------|
| `name` | `tester` |
| `description` | `Grants tester-only access to internal diagnostic UI features such as RAG detail panels. Assigned by Admin, Supervisor, or Owner roles.` |
| `category` | `user` |
| `exclude_from_reviews` | `false` |
| `is_active` | `true` |

## `tag_definitions` Schema Reference

From `015_add_tagging_system.sql`:

```sql
CREATE TABLE tag_definitions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL UNIQUE,
  name_lower VARCHAR(100) GENERATED ALWAYS AS (LOWER(name)) STORED UNIQUE,
  description TEXT,
  category VARCHAR(50) NOT NULL DEFAULT 'general',
  exclude_from_reviews BOOLEAN NOT NULL DEFAULT false,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

The `ON CONFLICT (name_lower)` clause targets the generated unique index, which is the same mechanism the service uses for lookups — ensuring true idempotency even if `name` casing differs.

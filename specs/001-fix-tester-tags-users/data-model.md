# Data Model: Fix Tester-Tag User Listing Failure

**Branch**: `001-fix-tester-tags-users` | **Date**: 2026-03-11

## Scope

No schema changes. The `tag_definitions` table already has the correct structure. This fix only seeds one missing row using the existing schema.

## Affected Tables

### `tag_definitions` (existing)

| Column | Type | Notes |
|--------|------|-------|
| `id` | `UUID` | PK, `gen_random_uuid()` |
| `name` | `VARCHAR(100)` | UNIQUE |
| `name_lower` | `VARCHAR(100)` | GENERATED ALWAYS AS `LOWER(name)` STORED, UNIQUE |
| `description` | `TEXT` | Human-readable purpose |
| `category` | `VARCHAR(50)` | Default `'general'`; for this row: `'user'` |
| `exclude_from_reviews` | `BOOLEAN` | Whether tagged users are excluded from review pools |
| `is_active` | `BOOLEAN` | Soft-disable flag |
| `created_at` | `TIMESTAMPTZ` | Auto-set on insert |

### `user_tags` (existing, unchanged)

| Column | Type | Notes |
|--------|------|-------|
| `id` | `UUID` | PK |
| `user_id` | `UUID` | FK → users |
| `tag_definition_id` | `UUID` | FK → tag_definitions |
| `assigned_by` | `UUID` | FK → users (actor) |
| `ip_address` | `INET` | Audit: caller IP |
| `created_at` | `TIMESTAMPTZ` | Assignment timestamp |

## New Data Row

Migration `032_seed_tester_tag_definition.sql` inserts:

```
name              = 'tester'
name_lower        = 'tester'   (generated)
description       = 'Grants tester-only access to internal diagnostic UI features
                     such as RAG detail panels. Assigned by Admin, Supervisor, or Owner roles.'
category          = 'user'
exclude_from_reviews = false
is_active         = true
```

## No Migration for `user_tags`

Existing `user_tags` rows for the `tester` tag definition (if any were inserted after the feature PRs were merged but before rollback) are already correctly linked to whichever `tag_definitions.id` was assigned at that time. After the migration inserts the canonical `tester` row, all future lookups resolve correctly.

## Idempotency Guarantee

The `INSERT ... ON CONFLICT (name_lower) DO NOTHING` ensures:

1. If `tester` already exists (rare, e.g., manually inserted) → no duplicate, no error.
2. If `tester` does not exist → row is inserted with a fresh UUID.
3. Safe to run more than once.

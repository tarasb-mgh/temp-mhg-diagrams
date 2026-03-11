# Quickstart: Fix Tester-Tag User Listing Failure

**Branch**: `001-fix-tester-tags-users` | **Date**: 2026-03-11

## Prerequisites

- `chat-backend` dependencies installed (`npm install`)
- `DATABASE_URL` set to a running PostgreSQL 15 instance
- Migration `015_add_tagging_system.sql` has already been applied (contains `tag_definitions` table)

## 1. Create the migration file

```bash
# In chat-backend/
cat > src/db/migrations/032_seed_tester_tag_definition.sql << 'SQL'
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
SQL
```

## 2. Apply the migration

```bash
# Against dev database
DATABASE_URL=<dev-postgres-url> node scripts/apply-migration.js 032_seed_tester_tag_definition.sql dev
```

Expected output:
```
Applying migration 032_seed_tester_tag_definition.sql to dev environment...
Database: postgresql://...
Migration applied successfully.
```

## 3. Patch the route error handling

Edit `src/routes/admin.testerTags.ts` — in the `GET /users` handler's catch block, add before the generic 500 fallback:

```typescript
if (error?.code === 'TESTER_TAG_NOT_FOUND') {
  return res.status(503).json({
    success: false,
    error: {
      code: 'SERVICE_UNAVAILABLE',
      message: 'Tester tag configuration is not yet set up. Contact an administrator.',
    },
  });
}
```

## 4. Validate locally

```bash
# Typecheck
npm run typecheck

# Tests
npm run test

# Smoke call (replace <TOKEN> with a valid owner JWT)
curl -H "Authorization: Bearer <TOKEN>" \
     https://api.workbench.dev.mentalhelp.chat/api/admin/tester-tags/users
```

Expected response:
```json
{ "success": true, "data": [ ... ] }
```

## 5. Run full test suite

```bash
npm run test:coverage
```

Ensure coverage remains at or above the repo threshold (≥ 45%).

## 6. Open PR

- Branch: `001-fix-tester-tags-users` → `develop`
- Title: `fix: seed tester tag definition and harden route error mapping`
- Wait for CI (typecheck + test) to go green before merging.

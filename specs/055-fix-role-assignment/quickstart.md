# Quickstart: 055-fix-role-assignment

**Date**: 2026-04-16

## Prerequisites

- Access to `chat-backend` repository
- PostgreSQL database access (dev environment)
- Node.js runtime for running tests

## Steps to Apply Fix

### 1. Run the Migration

Apply migration `063_055-extend-user-role-constraint.sql` to the dev database. This extends the `users_role_check` constraint to include `expert`, `admin`, and `master`.

The migration is automatically applied by the backend's startup migration runner.

### 2. Verify the Fix

After the migration runs, test role assignment:
- Log in as Owner at `https://workbench.dev.mentalhelp.chat`
- Navigate to any user's profile page
- Click "Change Role" and select "Expert"
- Confirm the role change succeeds (no 500 error)

### 3. Run Tests

```bash
cd chat-backend
npm test
```

The `changeUserRole.test.ts` file covers all 10 roles with parameterized tests.

## Files Changed

| Repository | File | Change |
|------------|------|--------|
| chat-backend | `src/db/migrations/063_055-extend-user-role-constraint.sql` | New migration |
| chat-backend | `src/db/schema.sql` | Updated `valid_role` constraint |
| chat-backend | `tests/unit/changeUserRole.test.ts` | New test file (13 tests) |

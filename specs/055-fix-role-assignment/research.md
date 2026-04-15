# Research: 055-fix-role-assignment

**Date**: 2026-04-16  
**Feature**: Fix 500 error on role assignment for new roles (expert, admin, master)

## Decision 1: Root Cause Identification

**Decision**: The 500 error is caused by a PostgreSQL CHECK constraint (`users_role_check`) that does not include the three new roles (`expert`, `admin`, `master`) added in MVP 048.

**Rationale**: 
- The `UserRole` enum in `chat-types/src/rbac.ts` includes `EXPERT = 'expert'`, `ADMIN = 'admin'`, `MASTER = 'master'` (added for MVP 048).
- The backend route `POST /api/admin/users/:id/role` validates against `Object.values(UserRole)`, so `"expert"` passes application-layer validation.
- The `changeUserRole` service function executes `UPDATE users SET role = $1 WHERE id = $2`.
- PostgreSQL rejects the UPDATE because the `users_role_check` constraint (set in migration `016_add_supervisor_role.sql`) only allows: `('user', 'qa_specialist', 'researcher', 'supervisor', 'moderator', 'group_admin', 'owner')`.
- The constraint violation throws an exception caught by the route's generic error handler, producing the 500 response.
- No migration in the `048-*` series updated this constraint.

**Alternatives Considered**:
- Backend service bug — ruled out; the SQL is correct, the constraint is the blocker.
- Frontend sending wrong payload — ruled out; `"expert"` is a valid enum value.
- Permission/auth issue — ruled out; Owner has the correct permissions; the 500 happens inside the DB transaction.

## Decision 2: Fix Approach

**Decision**: Create a new database migration (`063_055-extend-user-role-constraint.sql`) that drops the existing `users_role_check` constraint and recreates it with all 10 roles.

**Rationale**: This follows the exact pattern established by migration `016_add_supervisor_role.sql`, which did the same constraint drop-and-recreate when adding the `supervisor` role. The pattern is proven and idempotent.

**Alternatives Considered**:
- Removing the CHECK constraint entirely — rejected; the constraint provides defense-in-depth against invalid role values at the database level.
- Using a PostgreSQL ENUM type instead of CHECK — rejected; the project already uses CHECK constraints for roles, changing the approach would be a larger migration with no benefit.
- Modifying the existing migration 016 — rejected; migrations are immutable once applied.

## Decision 3: Schema.sql Update

**Decision**: Also update `schema.sql` to match the new constraint values.

**Rationale**: `schema.sql` serves as a reference schema. While migrations are the authoritative DDL source, keeping `schema.sql` in sync prevents confusion. The existing `valid_role` constraint in `schema.sql` was also missing `supervisor` (added in migration 016), confirming it has been out of sync.

## Decision 4: Test Coverage

**Decision**: Add a dedicated `changeUserRole.test.ts` with parameterized tests covering all 10 roles.

**Rationale**: Constitution Principle III (Mandatory Test Coverage) requires bug fixes to include regression tests. The `changeUserRole` function had zero test coverage. Parameterized `it.each` over all `UserRole` values ensures any future enum extension without corresponding DB constraint update will be caught by verifying the test expectations match the enum.

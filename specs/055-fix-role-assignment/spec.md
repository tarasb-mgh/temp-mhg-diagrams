# Bug Fix: Role Assignment 500 Error

**Feature Branch**: `055-fix-role-assignment`  
**Created**: 2026-04-16  
**Status**: Draft  
**Input**: User description: "Bug — cannot assign role. POST /api/admin/users/:id/role returns 500 Internal Server Error when assigning 'expert' role"

## Summary

Owners cannot assign the new roles (`expert`, `admin`, `master`) to users via the Workbench user management page. The operation fails with a 500 Internal Server Error because the PostgreSQL `users_role_check` constraint was never updated to include the roles added in MVP 048.

**Root Cause**: The `UserRole` enum in `chat-types` was extended with `EXPERT`, `ADMIN`, and `MASTER` as part of feature 048, but the corresponding database migration to update the `users_role_check` CHECK constraint on the `users` table was omitted. The last migration that touched this constraint (`016_add_supervisor_role.sql`) only allows `('user', 'qa_specialist', 'researcher', 'supervisor', 'moderator', 'group_admin', 'owner')`.

**Impact**: Any attempt to set a user's role to `expert`, `admin`, or `master` — whether through the role-change UI or user creation — fails at the database level. The constraint violation is caught by the generic error handler and returned as a 500 with `"Failed to change user role"`.

## User Scenarios & Testing

### User Story 1 — Owner Assigns Expert Role (Priority: P1)

An Owner navigates to a user's profile page in Workbench, clicks "Change Role", and selects "Expert" from the role menu. The role is saved and the user profile immediately reflects the new role.

**Why this priority**: This is the exact scenario reported as broken. Expert role assignment is a core capability of MVP 048's clinical tag specialization feature.

**Independent Test**: Can be fully tested by logging in as Owner, navigating to any non-Owner user's profile, changing their role to Expert, and confirming the role persists on page reload.

**Acceptance Scenarios**:

1. **Given** an Owner is viewing a user's profile page, **When** they click "Change Role" and select "Expert", **Then** the role is saved successfully (200 response) and the profile displays "Expert" as the user's role.
2. **Given** an Owner changes a user's role to "Expert", **When** the Owner refreshes the page, **Then** the user's role still shows "Expert".
3. **Given** an Owner changes a user's role from "Expert" back to "User", **When** the change is submitted, **Then** the role reverts to "User" successfully.

---

### User Story 2 — Owner Assigns Admin and Master Roles (Priority: P1)

An Owner assigns the `admin` or `master` role to a user. Both roles are part of the same MVP 048 enum extension and are equally broken by the same constraint issue.

**Why this priority**: Same root cause as US1; all three new roles must work for MVP 048 to function correctly.

**Independent Test**: Test by assigning `admin` and `master` roles to different users and confirming each succeeds.

**Acceptance Scenarios**:

1. **Given** an Owner views a user's profile, **When** they assign "Admin" role, **Then** the role is saved successfully and reflected in the UI.
2. **Given** an Owner views a user's profile, **When** they assign "Master" role, **Then** the role is saved successfully and reflected in the UI.

---

### User Story 3 — Owner Creates User with New Role (Priority: P2)

An Owner creates a new user via the "Create User" modal and selects one of the new roles (`expert`, `admin`, `master`). The user is created with the selected role.

**Why this priority**: User creation with new roles is a secondary path; role assignment on existing users is the primary reported issue.

**Independent Test**: Test by opening the Create User modal, selecting "Expert" as the role, filling in email and name, and submitting. Verify the created user appears with the Expert role.

**Acceptance Scenarios**:

1. **Given** an Owner opens the Create User modal, **When** they select "Expert" as the role and submit the form, **Then** the user is created with the Expert role.
2. **Given** an Owner opens the Create User modal, **When** they select "Admin" as the role and submit the form, **Then** the user is created with the Admin role.

---

### User Story 4 — Existing Roles Continue to Work (Priority: P1)

All previously valid roles (`user`, `qa_specialist`, `researcher`, `supervisor`, `moderator`, `group_admin`, `owner`) continue to be assignable without regression.

**Why this priority**: The constraint update must not break existing functionality.

**Independent Test**: Assign each legacy role to a user and confirm success.

**Acceptance Scenarios**:

1. **Given** an Owner views a user's profile, **When** they assign any of the seven original roles, **Then** the role change succeeds as before.

---

### Edge Cases

- What happens when a non-Owner user (e.g., moderator) attempts to change a role via the API directly? Expected: 403 Forbidden (existing behavior, unaffected by this fix).
- What happens when the role payload is an invalid string not in the enum? Expected: 400 Invalid Role (existing validation, unaffected by this fix).
- What happens if two Owners simultaneously change the same user's role? Expected: last-write-wins semantics at the database level.
- What happens to users already assigned a legacy role when the constraint is updated? Expected: no impact — only the allowed values set expands, existing data is unaffected.

## Requirements

### Functional Requirements

- **FR-001**: System MUST accept all roles defined in the `UserRole` enum (`user`, `qa_specialist`, `researcher`, `supervisor`, `moderator`, `group_admin`, `owner`, `expert`, `admin`, `master`) when setting a user's role in the database.
- **FR-002**: The database migration MUST be backward-compatible — existing user roles MUST remain valid and unchanged.
- **FR-003**: The migration MUST be idempotent — running it multiple times MUST NOT produce errors or duplicate constraints.
- **FR-004**: System MUST return appropriate error responses (400, 403, 404) for invalid inputs, unauthorized callers, and missing users — not 500.

### Key Entities

- **User**: The `role` column on the `users` table — currently constrained by a CHECK constraint that must be extended.
- **UserRole Enum**: Canonical role list defined in `chat-types/src/rbac.ts` — must match the database constraint.

## Success Criteria

### Measurable Outcomes

- **SC-001**: An Owner can assign the `expert` role to a user via the Workbench UI and the operation completes with a 200 response (currently 500).
- **SC-002**: An Owner can assign `admin` and `master` roles to users via the Workbench UI without errors.
- **SC-003**: All seven previously valid roles remain assignable without any change in behavior.
- **SC-004**: The migration runs without error on the dev database and can be re-run safely.
- **SC-005**: Automated tests cover role assignment for all ten roles in the enum.

## Assumptions

- The `UserRole` enum in `chat-types` is the canonical source of truth for valid roles.
- No other tables reference `users.role` with a foreign key or separate constraint that would also need updating.
- The `schema.sql` reference file should also be updated to match the new constraint for consistency, though migrations are the authoritative DDL source.

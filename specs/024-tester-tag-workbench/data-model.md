# Data Model: Workbench Tester Tag Assignment UI

## Overview

This feature reuses the existing user-tagging domain and introduces feature-specific views and commands for managing the `tester` tag through a dedicated workbench page.

## Entities

### Tester Tag Definition

Represents the existing predefined `tester` user tag within the broader tagging system.

**Fields**
- `tagName`: canonical string identifier, fixed as `tester`
- `category`: user tag
- `isActive`: whether the tag definition is available for assignment
- `audienceRule`: limited to internal staff and dedicated test accounts

**Rules**
- Must already exist in the tagging system before assignment workflows are used
- Must not be duplicated under a second tester-specific identifier
- Must remain user-level, not group-scoped or session-scoped

### Tester Tag Status

Represents the current tester-tag state for a specific user as shown on the dedicated management page and on the user profile.

**Fields**
- `userId`: unique user identifier
- `testerAssigned`: boolean current state
- `eligibility`: one of `eligible`, `ineligible`, `unknown`
- `eligibilityReason`: optional human-readable explanation when not assignable
- `assignedAt`: optional timestamp of current tester assignment
- `assignedBy`: optional actor reference for the latest assignment change

**Rules**
- `testerAssigned = true` is valid only when `eligibility = eligible`
- `eligibilityReason` is required when `eligibility = ineligible`
- A user can have at most one active tester-tag assignment at a time

### Tester Tag Assignment Command

Represents the requested state change from the dedicated management page.

**Fields**
- `userId`: target user identifier
- `desiredState`: one of `assign`, `remove`
- `requestedBy`: actor identifier
- `requestedAt`: timestamp of the request

**Rules**
- Only `Admin`, `Supervisor`, and `Owner` can issue the command
- `assign` must be rejected for ineligible users
- `remove` is idempotent for users who are already not tagged

### User Profile Tester Status

Represents the read-only tester status projection shown on the user profile page.

**Fields**
- `userId`: unique user identifier
- `testerAssigned`: boolean current state
- `visibleToViewer`: boolean indicating the profile viewer can see profile content
- `displayLabel`: localized status label such as assigned / not assigned

**Rules**
- This projection is read-only in the user profile context
- It must reflect the latest persisted tester state after refresh

## Relationships

- `Tester Tag Definition` is applied to many users through the existing user-tag assignment model
- Each user has one current `Tester Tag Status` projection
- Each `Tester Tag Assignment Command` targets exactly one user and produces an updated `Tester Tag Status`
- Each user profile renders one `User Profile Tester Status` projection

## State Transitions

### Tester Tag Status Lifecycle

1. `not_assigned + eligible`
2. `assigned + eligible`
3. `not_assigned + eligible` after removal

### Invalid Transition

- `not_assigned + ineligible` → `assigned + ineligible`
  Result: rejected with validation error; no persisted change

## Validation Rules

- The target user must exist
- The acting user must have one of the allowed roles
- The target user must satisfy internal/test-account eligibility for assignment
- Duplicate assignment attempts must not create duplicate tag records
- Failed updates must leave the previously visible tester state unchanged

## Derived Views

### Dedicated Management Page Row / Detail View

Derived from:
- user identity
- current tester-tag assignment state
- eligibility status
- last assignment metadata when available

### User Profile Badge / Status Display

Derived from:
- current tester-tag assignment state only
- no edit affordance
- localized label visible to profile viewers

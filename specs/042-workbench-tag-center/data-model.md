# Data Model: Unified Workbench Tag Center

## Overview

This feature unifies user-tag and review-tag operations under one management surface while keeping domain behavior explicit. The model reuses existing tag entities and standardizes projections used by Tag Center and user profile views.

## Entities

### Tag Definition

Represents a manageable tag in either `user` or `review` domain.

**Fields**
- `tagId`: unique identifier
- `name`: display name (human-readable)
- `nameLower`: normalized name for uniqueness checks
- `scope`: enum `user | review`
- `status`: enum `active | archived`
- `createdAt`: timestamp
- `createdBy`: actor identifier
- `updatedAt`: timestamp
- `updatedBy`: actor identifier

**Rules**
- `nameLower` is unique within `scope`
- `status` transitions only through `archive` and `unarchive`
- `tester` exists as a normal `user`-scope definition

### User Tag Assignment

Represents assignment of a user-scope tag to a user.

**Fields**
- `assignmentId`: unique identifier
- `userId`: target user identifier
- `tagId`: `Tag Definition` reference where `scope = user`
- `assignedAt`: timestamp
- `assignedBy`: actor identifier
- `unassignedAt`: nullable timestamp
- `unassignedBy`: nullable actor identifier
- `state`: enum `assigned | unassigned`

**Rules**
- Assignment can target any user (no capability gate on assignment action)
- One active assignment per (`userId`, `tagId`) pair
- Repeated assign or unassign commands are idempotent

### Review Tag Reference

Represents usage of review-scope tags by review records.

**Fields**
- `referenceId`: unique identifier
- `reviewRecordId`: review/session record identifier
- `tagId`: `Tag Definition` reference where `scope = review`
- `referenceState`: enum `active | historical`
- `createdAt`: timestamp

**Rules**
- Review-tag deletion is allowed only when no `Review Tag Reference` exists
- Archive/unarchive remains available regardless of references

### Rights Grant

Represents rights-management permissions for definition lifecycle and rights actions.

**Fields**
- `grantId`: unique identifier
- `subjectId`: user/role/group principal
- `rightName`: enum-like canonical right identifier
- `granted`: boolean
- `updatedAt`: timestamp
- `updatedBy`: actor identifier

**Rules**
- Rights-management actions are restricted to moderator-or-higher actors
- Changes are auditable through actor/timestamp metadata

### User Profile Tag Projection

Read model for displaying all assigned user tags on user profile.

**Fields**
- `userId`: profile owner
- `assignedTags`: ordered list of active user-scope `Tag Definition` records
- `computedAt`: timestamp of projection generation

**Rules**
- Projection includes all currently assigned user tags
- Projection is read-only in profile context

## Relationships

- `Tag Definition (scope=user)` -> many `User Tag Assignment`
- `Tag Definition (scope=review)` -> many `Review Tag Reference`
- `Rights Grant` controls access to rights-management and tag-definition lifecycle actions
- `User Profile Tag Projection` derives from active `User Tag Assignment` + `Tag Definition`

## State Transitions

### Tag Definition Lifecycle

1. `active` -> `archived` (archive)
2. `archived` -> `active` (unarchive)
3. Delete allowed only when preconditions are met:
   - user scope: no active assignments
   - review scope: no active or historical references

### User Tag Assignment Lifecycle

1. `unassigned` -> `assigned` (assign)
2. `assigned` -> `unassigned` (unassign)
3. Repeating same transition keeps state unchanged (idempotent)

## Validation Rules

- Tag names are compared case-insensitively within scope
- Search uses case-insensitive partial matching across user name, user email, tag name
- Combined filters apply using AND semantics
- Delete-block responses must include reason + next required action
- Equivalent failure conditions in both domains map to same failure meaning:
  - invalid input
  - insufficient permission
  - missing target
  - conflicting state

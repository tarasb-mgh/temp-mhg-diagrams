# Data Model: Cross-Group Review Access and Group Filter Scoping

**Feature**: 028-cross-group-reviews
**Date**: 2026-03-12

## Summary

No schema changes. This feature fixes application logic only — access control guards are updated to honour an existing permission. All entities and their relationships already exist.

---

## Affected Entities

### Session (existing, read-only for this feature)

Represents a chat conversation between a user and the AI assistant.

| Field | Type | Notes |
|-------|------|-------|
| `id` | UUID | Primary key |
| `group_id` | UUID \| null | Foreign key to Group; null = unassigned session |
| `user_id` | UUID | Owner of the session |
| `created_at` | timestamp | Session start |
| `ended_at` | timestamp \| null | Session end; null if active |

**Relevance**: `group_id` is used by the review queue and session detail endpoints to scope results. The filter behaviour is already implemented — only the access guard needs fixing.

---

### Group / Space (existing, read-only for this feature)

Organisational unit that scopes sessions and reviewer memberships.

| Field | Type | Notes |
|-------|------|-------|
| `id` | UUID | Primary key |
| `name` | string | Human-readable group name |
| `created_at` | timestamp | |

**Relevance**: Groups are the filter unit. The frontend group filter sends a group `id` (UUID) as the `groupId` query parameter. No group schema changes needed.

---

### UserRole + Permission (existing, no change)

Defined in `chat-types/src/rbac.ts`.

| Constant | Value | Grants REVIEW_CROSS_GROUP |
|----------|-------|--------------------------|
| `UserRole.OWNER` | `'OWNER'` | N/A — OWNER bypasses via role check |
| `UserRole.RESEARCHER` | `'RESEARCHER'` | Yes |
| `UserRole.SUPERVISOR` | `'SUPERVISOR'` | Yes |
| `UserRole.REVIEWER` | `'REVIEWER'` | No |

`Permission.REVIEW_CROSS_GROUP` already exists and is already assigned to RESEARCHER and SUPERVISOR. No change to `chat-types`.

---

## State Transitions

No new state transitions. The fix changes which users can trigger existing read operations (`GET /api/review/queue`, `GET /api/review/sessions/:id`) when a `groupId` filter is applied.

---

## Validation Rules (unchanged)

- Unassigned sessions (`group_id = null`) MUST NOT appear in filtered results when a specific `groupId` is selected (FR-006 — already implemented by service layer WHERE clause).
- Reviewer role users MUST continue to be limited to their own group (FR-003 — no change to `REVIEW_CROSS_GROUP` permission assignment for REVIEWER).

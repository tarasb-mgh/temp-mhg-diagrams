# API Contract: Review Endpoints — Cross-Group Access Behaviour

**Feature**: 028-cross-group-reviews
**Date**: 2026-03-12
**Affected endpoints**: `GET /api/review/queue`, `GET /api/review/sessions/:id`

No new endpoints. This document captures the **behavioural change** to two existing endpoints.

---

## GET /api/review/queue

### Purpose
Returns the paginated list of reviewable sessions visible to the authenticated user.

### Query Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `groupId` | UUID string | No | Filter results to sessions belonging to this group. When absent, returns all sessions visible to the user. |
| `page` | integer | No | Pagination — page number (default 1) |
| `limit` | integer | No | Pagination — page size (default 20) |

### Authorization Behaviour (CHANGED)

| Role | `groupId` absent | `groupId` present (own group) | `groupId` present (other group) |
|------|-----------------|-------------------------------|----------------------------------|
| OWNER | All sessions | Sessions for that group | Sessions for that group |
| RESEARCHER | All sessions | Sessions for that group | **Sessions for that group** ← fixed |
| SUPERVISOR | All sessions | Sessions for that group | **Sessions for that group** ← fixed |
| REVIEWER | Own group sessions | Sessions for that group (if member) | 403 Forbidden |

**Before fix**: RESEARCHER and SUPERVISOR with a `groupId` they are not a member of received `403 Forbidden`.

**After fix**: RESEARCHER and SUPERVISOR with any `groupId` receive the filtered results (permission `REVIEW_CROSS_GROUP` bypasses membership check).

### Response (unchanged)

```json
{
  "success": true,
  "data": {
    "sessions": [
      {
        "id": "uuid",
        "group_id": "uuid",
        "created_at": "ISO8601",
        "status": "string"
      }
    ],
    "total": 42,
    "page": 1,
    "limit": 20
  }
}
```

### Error Responses (unchanged for fixed cases)

| Status | Code | When |
|--------|------|------|
| 401 | `UNAUTHORIZED` | No valid auth token |
| 403 | `FORBIDDEN` | REVIEWER requesting a group they are not a member of |
| 403 | `FORBIDDEN` | Any role without WORKBENCH_ACCESS |

---

## GET /api/review/sessions/:id

### Purpose
Returns the full session detail including conversation and review panel for the authenticated reviewer.

### Path Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | UUID | Yes | Session identifier |

### Query Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `groupId` | UUID string | No | Hint for access check — same group the user is viewing from. |

### Authorization Behaviour (CHANGED)

| Role | Session in own group | Session in another group |
|------|---------------------|--------------------------|
| OWNER | Allowed | Allowed |
| RESEARCHER | Allowed | **Allowed** ← fixed |
| SUPERVISOR | Allowed | **Allowed** ← fixed |
| REVIEWER | Allowed | 403 Forbidden |

**Before fix**: RESEARCHER and SUPERVISOR requesting a session from a group they are not a member of received `403 Forbidden`.

**After fix**: RESEARCHER and SUPERVISOR can open any session regardless of group (permission `REVIEW_CROSS_GROUP` bypasses membership check).

### Response (unchanged)

```json
{
  "success": true,
  "data": {
    "session": {
      "id": "uuid",
      "group_id": "uuid",
      "messages": [],
      "review": {}
    }
  }
}
```

### Error Responses (unchanged for fixed cases)

| Status | Code | When |
|--------|------|------|
| 401 | `UNAUTHORIZED` | No valid auth token |
| 403 | `FORBIDDEN` | REVIEWER requesting a session from another group |
| 404 | `NOT_FOUND` | Session does not exist |

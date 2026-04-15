# Data Model: Clinical Tags Tab in Tag Center

**Feature**: 054-clinical-tags-tab  
**Date**: 2026-04-15

## Existing Entities (No Schema Changes)

### tag_definitions

Already exists. Clinical tags use `category = 'clinical'`.

| Field | Type | Notes |
|-------|------|-------|
| id | UUID | Primary key |
| name | VARCHAR | Tag name, unique per category (case-insensitive) |
| description | TEXT | Optional, used by clinical tags |
| category | ENUM('user', 'chat', 'clinical') | Discriminator |
| is_active | BOOLEAN | Lifecycle state |
| created_at | TIMESTAMP | Auto |
| updated_at | TIMESTAMP | Auto |

### review_clinical_tags

Junction table for clinical tag assignments to review messages.

| Field | Type | Notes |
|-------|------|-------|
| id | UUID | Primary key |
| review_id | UUID | FK → reviews |
| message_id | VARCHAR | Chat message ID |
| tag_definition_id | UUID | FK → tag_definitions (clinical) |
| created_at | TIMESTAMP | Auto |

### review_clinical_tag_comments

One comment per review for clinical tags.

| Field | Type | Notes |
|-------|------|-------|
| id | UUID | Primary key |
| review_id | UUID | FK → reviews, unique |
| comment | TEXT | Minimum 10 characters |
| created_at | TIMESTAMP | Auto |
| updated_at | TIMESTAMP | Auto |

### expert_tag_assignments

Links expert users to clinical tag definitions.

| Field | Type | Notes |
|-------|------|-------|
| id | UUID | Primary key |
| user_id | UUID | FK → users (expert role) |
| tag_definition_id | UUID | FK → tag_definitions (clinical) |
| created_at | TIMESTAMP | Auto |

### users

Relevant fields only.

| Field | Type | Notes |
|-------|------|-------|
| id | UUID | Primary key |
| display_name | VARCHAR | Used in expert list |
| email | VARCHAR | Used in expert search |
| role | VARCHAR | Filter by 'expert' for assignment panel |

## Computed/Derived Data

### Session Count (per clinical tag)

Derived at query time:
```sql
SELECT COUNT(DISTINCT rct.review_id)::int AS session_count
FROM review_clinical_tags rct
WHERE rct.tag_definition_id = $1
```

### Expert Count (for landing page)

Derived from users API:
```
GET /api/admin/users?role=expert&limit=1 → meta.total
```

## Data Flow

```
Admin creates clinical tag
  → POST /api/admin/clinical-tags { name }
  → INSERT INTO tag_definitions (category='clinical')

Admin edits description
  → PATCH /api/admin/clinical-tags/:tagId { description }
  → UPDATE tag_definitions SET description = ...

Admin assigns tag to expert
  → POST /api/admin/users/:userId/expert-tags { tagDefinitionId }
  → INSERT INTO expert_tag_assignments

Reviewer tags message in session
  → POST /api/admin/clinical-tags/reviews/:reviewId/tags { messageId, tagDefinitionId }
  → INSERT INTO review_clinical_tags

Expert sees tagged sessions
  → GET /api/expertise/sessions (filtered by expert_tag_assignments ∩ review_clinical_tags)
```

## Bug Fix: Draft Table Name

| Location | Current (wrong) | Correct |
|----------|-----------------|---------|
| `review.draft.ts` line 143 | `clinical_tag_comments` | `review_clinical_tag_comments` |

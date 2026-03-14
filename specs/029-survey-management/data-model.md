# Data Model: Survey Instance Management (029)

**Branch**: `029-survey-management` | **Date**: 2026-03-14

## Existing Entities (No Schema Changes)

All changes are service-layer and API-layer only. No new migrations are needed.

---

### survey_instances (existing — key fields)

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID PK | |
| `group_ids` | UUID[] | Array of assigned groups — updated by PATCH endpoint |
| `expiration_date` | TIMESTAMPTZ | Updated by PATCH endpoint; constraint: > start_date |
| `status` | VARCHAR(20) | `draft \| active \| expired \| closed` — may be reset to `active` when expiration extended past `expired` state |
| `updated_at` | TIMESTAMPTZ | Set to `now()` on every update |

**Update rules**:
- `expiration_date` MUST be > `now()` (validated in service before write)
- If `status = 'expired'` AND new `expiration_date > now()`: service resets `status = 'active'` in same UPDATE
- `group_ids` update replaces the array; responses referencing old groups are not touched

---

### group_survey_order (existing — sync on group_ids change)

| Column | Type | Notes |
|--------|------|-------|
| `group_id` | UUID | Part of unique constraint with `instance_id` |
| `instance_id` | UUID FK | |
| `display_order` | INTEGER | |

**Sync logic on group_ids change**:
- For each `groupId` in new `group_ids` NOT in old `group_ids`: INSERT row with `display_order = (SELECT COALESCE(MAX(display_order), 0) + 1 FROM group_survey_order WHERE group_id = $groupId)`
- For each `groupId` in old `group_ids` NOT in new `group_ids`: DELETE row WHERE `group_id = $groupId AND instance_id = $instanceId`

---

### survey_responses (existing — read-only for this feature)

| Column | Type | Notes |
|--------|------|-------|
| `instance_id` | UUID FK | |
| `pseudonymous_id` | UUID | Equals `user.id` in practice |
| `group_id` | UUID | Group context at time of submission |
| `is_complete` | BOOLEAN | True = submitted |
| `completed_at` | TIMESTAMPTZ | Null if not complete |
| `invalidated_at` | TIMESTAMPTZ | Null = valid response |

**Used in statistics query**: JOIN to identify which group members have submitted (is_complete = true AND invalidated_at IS NULL).

---

## New Types (chat-types — no DB migration)

### SurveyInstanceUpdateInput

```typescript
interface SurveyInstanceUpdateInput {
  expirationDate?: string;   // ISO 8601 datetime; must be future date
  groupIds?: string[];       // Non-empty array of group UUIDs; replaces existing
}
```

Validation rules (enforced in service):
- At least one field must be provided
- `expirationDate`, if present: must parse as valid ISO datetime AND be after `now()`
- `groupIds`, if present: must be non-empty array; each UUID must resolve to a valid group

---

### SurveyMemberCompletion

```typescript
interface SurveyMemberCompletion {
  userId: string;           // UUID
  displayName: string;      // From users.display_name
  email: string;            // From users.email (workbench-only)
  isComplete: boolean;      // True if is_complete=true AND invalidated_at IS NULL
  completedAt: string | null;  // ISO timestamp or null
}
```

---

### SurveyGroupStatistics

```typescript
interface SurveyGroupStatistics {
  groupId: string;
  groupName: string;
  totalMembers: number;      // Active members in group
  completedCount: number;    // Members with valid complete response
  pendingCount: number;      // totalMembers - completedCount
  completionRate: number;    // completedCount / totalMembers (0–1), NaN-safe (0 if totalMembers=0)
  members: SurveyMemberCompletion[];  // All members with isComplete flag
}
```

---

### SurveyInstanceStatistics

```typescript
interface SurveyInstanceStatistics {
  instanceId: string;
  groups: SurveyGroupStatistics[];   // One entry per group in instance.group_ids
}
```

---

## Statistics Query Design

The statistics endpoint executes a query that:

1. Fetches all `active` group members for each group in `instance.group_ids`:
```sql
SELECT
  u.id         AS user_id,
  u.display_name,
  u.email,
  gm.group_id
FROM group_memberships gm
JOIN users u ON u.id = gm.user_id
WHERE gm.group_id = ANY($groupIds::uuid[])
  AND gm.status = 'active'
  AND u.status = 'active'
```

2. Fetches all valid complete responses for the instance:
```sql
SELECT
  pseudonymous_id,
  group_id,
  completed_at
FROM survey_responses
WHERE instance_id = $instanceId
  AND is_complete = true
  AND invalidated_at IS NULL
```

3. Left-joins the member list against responses by `user_id = pseudonymous_id`.

4. Aggregates per group.

**Group name** is resolved from a JOIN or a secondary query against the `groups` table (existing table in the schema).

---

## State Transition Diagram (instance status)

```
draft ──[start_date reached, inline]──► active
                                          │
                              ┌───────────┤
                              ▼           │
                           expired        │ [PATCH expirationDate > now()]
                              │           │       resets status → active ◄──────┘
                              │
                   [PATCH expirationDate > now()]
                              │
                       ──► active (revived)
                              │
                    [POST /close, manual]
                              │
                           closed (terminal)
```

`expired` → `active` transition: only valid when `expirationDate` updated to future value via PATCH.
`closed` is terminal — no transitions out of closed.

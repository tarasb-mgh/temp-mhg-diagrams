# Data Model: Review Queue Safety Prioritisation

**Feature**: 032-review-queue-safety-priority
**Date**: 2026-03-18

## Entity Definitions

### Session (extended)

Existing entity in `sessions` table. Extended by migration 034.

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| safety_priority | VARCHAR(16) | CHECK ('normal', 'elevated'), DEFAULT 'normal' | Priority tier set by AI filter or supervisor reopen |

**Index**: `idx_sessions_safety_priority` — filtered partial index WHERE `safety_priority = 'elevated'`

**State transitions**:
- `normal → elevated`: AI filter sets when `flag_source = 'ai_filter_low'` (low-confidence crisis detection), or supervisor reopens a dismissed flag
- `elevated → normal`: Reviewer submits with disposition `resolve` or `false_positive`
- `elevated → elevated` (unchanged): Reviewer submits with disposition `escalate` (session stays elevated for supervisor attention)

### RiskFlag (extended) — implements spec entity "SafetyFlag"

The spec defines a `SafetyFlag` entity. This is implemented as an extension of the pre-existing `RiskFlag` entity (`risk_flags` table) rather than a new table — the fields map as follows: spec `SafetyFlag.disposition` → `risk_flags.status`, spec `SafetyFlag.confidence_score` → `risk_flags.confidence`, spec `SafetyFlag.created_by` → `risk_flags.flagged_by`.

Existing entity in `risk_flags` table. Extended by migration 034.

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| confidence | DECIMAL | nullable | AI filter confidence score |
| flag_source | VARCHAR(32) | 'manual' \| 'ai_filter_high' \| 'ai_filter_low' | Origin of the flag |

**Relationship**: `risk_flags.session_id → sessions.id`

### SafetyFlagAuditEvent (new)

Append-only audit log for safety flag lifecycle events. Created by migration 034.

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | UUID | PK, DEFAULT gen_random_uuid() | Unique event ID |
| flag_id | UUID | FK → risk_flags.id, NOT NULL | Associated flag |
| event_type | VARCHAR(32) | NOT NULL | Event: created, resolved, escalated, false_positive, reopened |
| actor_id | UUID | FK → users.id, nullable | Who performed the action (null for system) |
| notes | TEXT | nullable | Free-text notes from reviewer/supervisor |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | Event timestamp |

**Relationship**: `safety_flag_audit_events.flag_id → risk_flags.id`

### SafetyFlagDisposition (type)

Defined in `chat-types/src/review.ts`:

```typescript
type SafetyFlagDisposition = 'resolve' | 'escalate' | 'false_positive'
```

Used in `SubmitReviewInput`:
```typescript
interface SubmitReviewInput {
  overallComment?: string
  safetyFlagDisposition?: SafetyFlagDisposition  // required when session.safetyPriority === 'elevated'
  safetyFlagNotes?: string
}
```

### QueueSession (type)

Defined in `chat-types/src/review.ts`. Relevant fields:

```typescript
interface QueueSession {
  // ... existing fields ...
  safetyPriority: 'normal' | 'elevated'
  // ...
}
```

### QueueCounts (type)

Defined in `chat-types/src/review.ts`:

```typescript
interface QueueCounts {
  pending: number
  flagged: number
  inProgress: number
  completed: number
  elevated: number  // sessions with safety_priority = 'elevated' in pending/in-review
}
```

## Entity Relationship Diagram

```
sessions
  ├── safety_priority: 'normal' | 'elevated'
  ├── review_status: pending_review | in_review | complete | ...
  │
  ├──< risk_flags (session_id)
  │     ├── confidence, flag_source
  │     ├── status: open | acknowledged | resolved | escalated
  │     │
  │     └──< safety_flag_audit_events (flag_id)
  │           ├── event_type: created | resolved | escalated | false_positive | reopened
  │           ├── actor_id → users
  │           └── notes
  │
  └──< session_reviews (session_id)
        ├── supervision_status → supervisor decisions
        │
        Note: safetyFlagDisposition and safetyFlagNotes are NOT stored as
        columns on session_reviews. They are passed in the submit request
        and persisted on the associated risk_flag (status transition) and
        safety_flag_audit_events (event_type + notes). The supervisor view
        retrieves disposition data by joining:
          session_reviews.session_id → risk_flags.session_id
          risk_flags.id → safety_flag_audit_events.flag_id
```

## Validation Rules

1. `safety_priority` must be one of `'normal'` or `'elevated'` (database CHECK constraint)
2. When submitting a review for a session with `safety_priority = 'elevated'`, `safetyFlagDisposition` is **required** — API returns 400 if missing
3. `SafetyFlagAuditEvent.event_type` must match the disposition being recorded
4. `SafetyFlagAuditEvent` rows are append-only — no UPDATE or DELETE permitted
5. A supervisor reopen (`event_type = 'reopened'`) must set `safety_priority` back to `'elevated'`
6. Queue sorting: elevated sessions always above normal, recency secondary sort within tiers
7. **FR-017 queryability**: The full flag lifecycle (flag created → reviewed → disposed) is queryable by session ID via the join path: `sessions.id → risk_flags.session_id → safety_flag_audit_events.flag_id`. No denormalized `session_id` on the audit event table is needed — the two-hop join through `risk_flags` is the intended query path

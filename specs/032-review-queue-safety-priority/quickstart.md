# Quickstart: Review Queue Safety Prioritisation

**Branch**: `032-review-queue-safety-priority`
**Date**: 2026-03-15

---

## Integration Test Scenarios

### Scenario 1: Elevated session surfaces at top of queue

**Precondition**: Two sessions exist — one `safety_priority = 'elevated'`, one `safety_priority = 'normal'`. Both have `review_status = 'pending_review'`.

**Steps**:
1. Call `GET /api/review/queue?tab=pending&sortBy=priority`
2. Inspect response `data` array

**Expected**: The elevated session is at index 0. The normal session is at index 1 regardless of its `started_at` value.

---

### Scenario 2: Reviewer submits review with disposition on elevated session

**Precondition**: An elevated session exists. Reviewer has completed all message ratings.

**Steps**:
1. Call `POST /api/review/sessions/:id/submit` with body `{ "safetyFlagDisposition": "resolve", "safetyFlagNotes": "No actual crisis" }`
2. Inspect response
3. Call `GET /api/review/queue?tab=pending` and check the session is gone from elevated tier
4. Inspect `risk_flags` row for the session — status should be `'resolved'`
5. Inspect `safety_flag_audit_events` — one row with `event_type='resolved'`

**Expected**: Review submitted 200, session no longer elevated, flag resolved, audit row created.

---

### Scenario 3: Disposition required — submit blocked

**Precondition**: An elevated session exists. Reviewer has completed ratings.

**Steps**:
1. Call `POST /api/review/sessions/:id/submit` with body `{}` (no disposition)
2. Inspect response

**Expected**: 400 response with `"error": "SAFETY_FLAG_DISPOSITION_REQUIRED"`.

---

### Scenario 4: Normal session — no disposition required

**Precondition**: A normal (`safety_priority = 'normal'`) session exists.

**Steps**:
1. Call `POST /api/review/sessions/:id/submit` with body `{}` (no disposition)
2. Inspect response

**Expected**: 200 success. `safetyFlagDisposition` field is silently ignored/not required.

---

### Scenario 5: Escalate disposition — supervisor queue

**Precondition**: An elevated session. Reviewer submits with `"safetyFlagDisposition": "escalate"`.

**Steps**:
1. Submit review as reviewer with escalate disposition
2. Call `GET /api/review/queue?tab=supervision` as supervisor

**Expected**: Session appears in supervisor queue, still marked elevated. `risk_flags.status = 'escalated'`.

---

### Scenario 6: Supervisor reopens a false-positive flag

**Precondition**: Session was reviewed with `false_positive` disposition. `safety_priority = 'normal'`.

**Steps**:
1. Call `PATCH /api/review/sessions/:id/safety-flag/reopen` with `{ "notes": "Disagree with dismissal" }`
2. Verify session `safety_priority = 'elevated'` again
3. Verify `risk_flags.status = 'open'`
4. Verify `safety_flag_audit_events` has a `'reopened'` row

**Expected**: Session re-enters elevated tier. Audit trail complete.

---

## Dev Environment Setup

For testing elevated sessions in staging before spec 030 ships:
```sql
-- Seed an elevated test session
UPDATE sessions
SET safety_priority = 'elevated'
WHERE id = '<test-session-uuid>';

-- Seed the corresponding risk_flag
INSERT INTO risk_flags (
  session_id, severity, reason_category, details, status,
  is_auto_detected, matched_keywords, flag_source, confidence
) VALUES (
  '<test-session-uuid>', 'medium', 'crisis_indicators',
  'AI filter detected potential crisis language with low confidence',
  'open', true, ARRAY['keyword1'], 'ai_filter_low', 0.35
);
```

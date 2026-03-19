# Research: Review Queue Safety Prioritisation

**Feature**: 032-review-queue-safety-priority
**Date**: 2026-03-18

## Research Tasks

### R1: How does the AI post-generation filter emit the elevated priority signal?

**Decision**: The AI filter (spec 030 FR-022, `chat-backend/src/ai-filter/post-generation-filter.ts`) blocks responses containing clinical urgency language, diagnostic language, and numeric scores near instruments. When a response is blocked, the session is flagged. Migration 034 (`chat-backend/src/db/migrations/034_add_safety_priority.sql`) adds a `safety_priority` column to `sessions` with values `'normal'` (default) or `'elevated'`. A `confidence` field and `flag_source` (`manual` | `ai_filter_high` | `ai_filter_low`) are added to `risk_flags`.

**Rationale**: The filter runs synchronously before message write. When `flag_source = 'ai_filter_low'` (low-confidence crisis detection), the session's `safety_priority` is set to `'elevated'` to surface it for human review.

**Alternatives considered**:
- Separate priority queue table — rejected: unnecessary complexity, a column on sessions is sufficient
- Enum with multiple tiers (normal/elevated/critical) — rejected for this spec: binary is sufficient per spec assumptions; future tiers are out of scope

### R2: How should the queue sort elevated sessions?

**Decision**: SQL sorting uses `CASE s.safety_priority WHEN 'elevated' THEN 0 ELSE 1 END ASC` as the primary sort, with recency (`s.started_at DESC`) as secondary within each tier. Implemented in `reviewQueue.service.ts` line 302.

**Rationale**: Simple, index-friendly sort that keeps elevated sessions at top regardless of age. The filtered index `idx_sessions_safety_priority` (WHERE safety_priority = 'elevated') keeps the sort efficient.

**Alternatives considered**:
- Application-level sort (fetch all, sort in JS) — rejected: doesn't scale, loses pagination correctness
- Separate API endpoint for elevated sessions — rejected: adds complexity, reviewers want one unified queue

### R3: How should the safety flag resolution step integrate with the existing review form?

**Decision**: The review form renders a "Safety Flag Resolution" section conditionally when `session.safetyPriority === 'elevated'`. Three radio options (Resolve, Escalate, False Positive) plus optional notes. The `reviewStore` tracks `safetyFlagDisposition` and `safetyFlagNotes`. On submission, `SubmitReviewInput` includes these fields. The backend validates that disposition is present when the session is elevated and rejects submission otherwise.

**Rationale**: Additive approach — the existing review form is unchanged for normal sessions. The resolution section is a new component rendered conditionally, not a modification of existing form fields.

**Alternatives considered**:
- Separate "Safety Review" tab — rejected per spec: replaces the earlier separate-tab concept
- Modal popup for disposition — rejected: breaks form flow and could be dismissed accidentally

### R4: How should flag lifecycle state transitions work?

**Decision**: Flag disposition drives `safety_priority` transitions:
- **Resolve**: `safety_priority → 'normal'`, flag status → `'resolved'`
- **Escalate**: `safety_priority` stays `'elevated'`, flag status → `'escalated'`, session enters supervisor queue at elevated urgency
- **False Positive**: `safety_priority → 'normal'`, flag status → `'false_positive'`, event logged for AI filter feedback
- **Supervisor Reopen**: `safety_priority → 'elevated'`, creates new audit event

All transitions are recorded in `safety_flag_audit_events` with actor, timestamp, and notes.

**Rationale**: Matches the append-only audit pattern already used for review events. Each disposition creates a traceable event.

**Alternatives considered**:
- Soft-delete flags on resolve — rejected: loses audit trail
- Separate escalation entity — rejected: the flag entity itself tracks status transitions

### R5: What existing permission guards apply?

**Decision**: Existing permission middleware in `reviewAuth.ts` covers all required operations:
- `REVIEW_ACCESS` — view queue and session details
- `REVIEW_SUBMIT` — rate messages and submit reviews (including disposition)
- `REVIEW_ESCALATION` — resolve flags (used when disposition is 'resolve' or 'false_positive')
- `REVIEW_SUPERVISE` — view supervision queue, submit supervisor decisions, reopen flags
- No new permissions needed.

**Rationale**: The safety flag resolution is part of the review submission flow, so `REVIEW_SUBMIT` covers it. Supervisory flag reopen requires `REVIEW_SUPERVISE`, which already gates the supervision endpoints.

**Alternatives considered**:
- New `REVIEW_SAFETY_FLAG` permission — rejected: over-segmentation; any reviewer who can submit reviews should be able to resolve safety flags on their assigned sessions

### R6: What i18n keys are needed?

**Decision**: Keys under `review.safetyFlag.*` namespace:
- `review.safetyFlag.priorityBadge` — Badge label on SessionCard
- `review.safetyFlag.elevatedCount` — Count indicator on queue
- `review.safetyFlag.resolutionTitle` — Section heading in review form
- `review.safetyFlag.resolve` / `escalate` / `falsePositive` — Option labels
- `review.safetyFlag.notesPlaceholder` — Free-text field hint
- `review.safetyFlag.required` — Validation message
- All keys required in en.json, uk.json, ru.json

**Rationale**: Follows existing i18n namespace pattern. Keys are specific enough to avoid collision with existing `review.*` keys.

### R7: Edge case — session flagged while reviewer is mid-review

**Decision**: The priority indicator is a read-at-load property. If a session's `safety_priority` changes to `'elevated'` while a reviewer has the session open, the change is visible on next page load. The in-progress review is not disrupted — no WebSocket push or forced refresh for this field. The auto-refresh (60s) on the queue page will surface the change there.

**Rationale**: Disrupting an in-progress review with a priority change is worse than a 60s delay in visibility. The reviewer will see the flag when they return to the queue or reload.

### R8: Edge case — draft review persistence including disposition

**Decision**: The `reviewStore` already persists `safetyFlagDisposition` and `safetyFlagNotes` in Zustand state. If the reviewer loses connection, the Zustand state survives page reload if persist middleware is configured. If not, the disposition selection is lost on hard refresh but the review draft (scores, comments) follows the same persistence behavior — this is consistent.

**Rationale**: Disposition persistence should match existing draft review persistence behavior. A verification task is included in the plan to confirm that `reviewStore` has Zustand `persist` middleware configured. If not, it must be added to satisfy EC2.

### R9: Edge case — closed session receives elevated flag

**Decision**: If the AI filter flags a session that has already been fully reviewed and closed (`review_status = 'complete'`), the `safety_priority` may be set to `'elevated'` in the database but the session should not re-enter the active queue. The queue query filters by `review_status IN ('pending_review', 'in_review')`, so completed sessions are excluded regardless of priority. The flag event is still logged in `safety_flag_audit_events` for audit purposes.

**Rationale**: Re-opening completed sessions would create confusion and duplicate work. The audit trail captures the flag for compliance purposes.

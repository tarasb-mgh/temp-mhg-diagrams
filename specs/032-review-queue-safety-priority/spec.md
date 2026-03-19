# Feature Specification: Review Queue Safety Prioritisation

**Feature Branch**: `032-review-queue-safety-priority`
**Created**: 2026-03-15
**Status**: Draft
**Input**: User description: "Review queue safety prioritisation — integrate crisis_low_confidence sessions from the AI post-generation filter into the main workbench review queue as elevated-priority items. Sessions flagged with low-confidence crisis signals appear at the top of the queue with a visual priority indicator. The standard review form gains a mandatory Safety flag resolution step (resolve / escalate / false positive) that only renders for elevated sessions. This replaces the earlier concept of a separate Safety Review tab. The feature depends on the AI filter (spec 030 FR-022) emitting a priority field alongside flagged sessions."

**Related Specs**:
- `011-chat-review-supervision` — Base review queue, supervisor second-level review, review form
- `030-non-therapy-backlog` — FR-022: AI post-generation filter that emits the `priority = elevated` signal

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Elevated Sessions Visible at the Top of the Review Queue (Priority: P1)

A reviewer opens the workbench review queue and immediately sees any sessions flagged as elevated priority at the top of the list, visually distinguished from routine sessions by a priority badge. The reviewer does not need to switch tabs or navigate to a separate surface — elevated sessions are surfaced in the same place they do all their review work. They can see at a glance how many elevated sessions are waiting and process them in order.

**Why this priority**: This is the foundational visibility requirement. Without it, safety-flagged sessions are invisible in the queue and may be reviewed out of order — or not at all. The rest of the feature (flag resolution) is meaningless if reviewers cannot find the sessions.

**Independent Test**: With at least one session tagged `priority = elevated` by the AI filter, a reviewer logs into the workbench and opens the review queue. The elevated session must appear above all `normal` sessions, with a visible priority indicator. A second check confirms the indicator is correctly translated in all three supported locales (English, Ukrainian, Russian).

**Acceptance Scenarios**:

1. **Given** the review queue contains a mix of `normal` and `elevated` sessions, **When** a reviewer opens the queue, **Then** all `elevated` sessions appear above all `normal` sessions in the list, regardless of their chronological order.
2. **Given** an elevated session in the queue, **When** the reviewer views the session row, **Then** a visible priority indicator (badge or colour signal) is displayed on that row, clearly distinguishing it from routine sessions.
3. **Given** no elevated sessions exist, **When** the reviewer opens the queue, **Then** the queue renders normally with no priority indicators — there is no empty "elevated" section or placeholder.
4. **Given** the workbench is set to Ukrainian or Russian locale, **When** the reviewer views an elevated session's priority indicator, **Then** the indicator label renders in the correct locale — no raw i18n key strings appear.
5. **Given** new sessions are added to the queue in real time, **When** an elevated session arrives, **Then** the queue re-sorts to keep elevated sessions at the top without requiring a manual page refresh.

---

### User Story 2 — Safety Flag Resolution Step in the Review Form (Priority: P1)

When a reviewer opens an elevated-priority session to submit a review, the review form includes a mandatory "Safety flag resolution" step that does not appear for normal sessions. The reviewer must select one of three dispositions before they can submit: **Resolve** (the session was reviewed and the concern does not warrant escalation), **Escalate** (the session requires immediate clinical attention), or **False Positive** (the AI filter misfired — no safety concern exists). The reviewer can optionally add a free-text note. Once submitted, the disposition is recorded alongside the review and the elevated flag is updated accordingly.

**Why this priority**: The safety flag is actionable data. If a reviewer completes a normal quality review but never records whether the crisis signal was real, the organisation has no audit trail and no escalation path. This step closes the loop between the AI filter's signal and a clinician's judgment.

**Independent Test**: A reviewer opens an elevated session, completes the standard quality review, and attempts to submit. Submission is blocked until a flag disposition is selected. After selecting "Escalate" and submitting, the session is marked as escalated and visible to supervisors. A separate test confirms that opening a normal (non-elevated) session shows no safety flag step in the review form.

**Acceptance Scenarios**:

1. **Given** a reviewer opens an elevated session in the review form, **When** the form renders, **Then** a "Safety flag resolution" section appears with three options: Resolve, Escalate, False Positive — and an optional free-text notes field.
2. **Given** a reviewer has completed the quality scoring but has not selected a flag disposition, **When** they attempt to submit the review, **Then** submission is blocked and a message indicates the safety flag resolution is required.
3. **Given** a reviewer selects "Escalate" and submits the review, **When** the review is saved, **Then** the session is marked as escalated, the disposition and notes are persisted, and the session surfaces in the supervisor queue with escalated status.
4. **Given** a reviewer selects "Resolve" and submits the review, **When** the review is saved, **Then** the elevated flag is marked as resolved, the session no longer appears at the top of the queue on subsequent loads, and the disposition and notes are persisted.
5. **Given** a reviewer selects "False Positive" and submits the review, **When** the review is saved, **Then** the flag is dismissed, the session is removed from the elevated tier, and the false-positive event is logged for AI filter feedback purposes.
6. **Given** a reviewer opens a normal (non-elevated) session, **When** the review form renders, **Then** no safety flag resolution section appears — the form is identical to the existing review form.
7. **Given** a supervisor reviews a submitted review that included an "Escalate" disposition, **When** they open the review in the second-level review view, **Then** the escalation disposition and the reviewer's notes are visible alongside the standard review scores.

---

### User Story 3 — Supervisor Visibility of Unresolved Escalations (Priority: P2)

A supervisor opening the review queue can see which escalated sessions are waiting for their attention. Escalated sessions are visually distinct from sessions awaiting standard second-level review, and the supervisor can filter or sort by escalation status. Sessions escalated from the safety flag step are treated as higher urgency than routine supervisor review items.

**Why this priority**: Escalation without visibility at the supervisory level defeats the purpose. This story completes the loop — but it depends on US-2 shipping first, making it P2.

**Independent Test**: A session reviewed with "Escalate" disposition appears in the supervisor's queue with an escalation indicator, above sessions awaiting standard second-level review.

**Acceptance Scenarios**:

1. **Given** a session was reviewed and escalated via the safety flag step, **When** a supervisor opens their review queue, **Then** the escalated session appears at the top, above sessions awaiting routine second-level review.
2. **Given** multiple escalated sessions, **When** a supervisor views the queue, **Then** all escalated sessions are grouped together with a clear visual distinction from second-level review items.
3. **Given** a supervisor resolves an escalated session (by recording their own clinical judgment), **When** they submit, **Then** the session is marked as supervisor-resolved and removed from the escalated tier.

---

### Edge Cases

- A session is tagged `priority = elevated` by the AI filter while a reviewer is already mid-review on that session in a different tab — the priority indicator must be visible on next load but the in-progress review is not disrupted.
- A reviewer selects "Escalate" but loses connection before submitting — the draft review (including the disposition selection) should survive a page reload.
- The AI filter emits `priority = elevated` for a session that has already been fully reviewed and closed — the session should not re-enter the active queue; the flag should be logged but suppressed from the active review surface.
- The queue contains a very large number of elevated sessions (e.g., due to a filter misconfiguration) — the queue must not degrade in performance and should display a count indicator so reviewers understand the scale.
- A false-positive disposition is submitted for a session later reviewed by a supervisor who disagrees with the dismissal — the supervisor must be able to reopen the flag.

---

## Requirements *(mandatory)*

### Functional Requirements

#### Queue Prioritisation

- **FR-001**: The review queue MUST sort sessions such that all `priority = elevated` sessions appear above all `priority = normal` sessions, with recency as the secondary sort within each tier.
- **FR-002**: Each `elevated` session row in the queue MUST display a priority indicator (badge, colour, or icon) that is visually distinct from normal sessions and is accessible (meets WCAG 2.1 AA colour contrast requirements).
- **FR-003**: The priority indicator MUST render correctly in all three supported locales: English, Ukrainian, and Russian — no raw i18n key strings may appear in any locale.
- **FR-004**: When no elevated sessions exist, the queue MUST render without an empty elevated section, placeholder text, or layout shift.
- **FR-005**: The queue MUST reflect newly elevated sessions without requiring a manual page refresh (polling or push-based update within 60 seconds of the flag being set).

#### Safety Flag Resolution

- **FR-006**: When a reviewer opens a session where `priority = elevated`, the review form MUST render a "Safety flag resolution" section with three mutually exclusive options: Resolve, Escalate, False Positive.
- **FR-007**: The "Safety flag resolution" section MUST include an optional free-text notes field (no character limit enforced, but soft hint at 500 characters).
- **FR-008**: Form submission MUST be blocked if the reviewer has not selected a flag disposition for an elevated session; a clear validation message MUST explain the requirement.
- **FR-009**: Submitting with "Escalate" disposition MUST mark the session as escalated and make it visible in the supervisor queue at elevated urgency.
- **FR-010**: Submitting with "Resolve" disposition MUST mark the flag as resolved; the session MUST no longer appear in the elevated tier on subsequent queue loads.
- **FR-011**: Submitting with "False Positive" disposition MUST dismiss the flag, remove the session from the elevated tier, and log the false-positive event for AI filter feedback.
- **FR-012**: The safety flag resolution section MUST NOT render for sessions where `priority = normal` — the review form for normal sessions MUST be identical to its current state.

#### Supervisor Escalation Visibility

- **FR-013**: Escalated sessions MUST appear in the supervisor review queue above sessions awaiting routine second-level review.
- **FR-014**: A supervisor MUST be able to record a clinical judgment on an escalated session (approve escalation, dismiss escalation) with an optional note; both dispositions MUST be persisted with actor and timestamp.
- **FR-015**: A supervisor MUST be able to reopen a flag that was dismissed as "False Positive" by a reviewer, if the supervisor disagrees with the dismissal.

#### Audit & Traceability

- **FR-016**: Every flag disposition event (Resolve, Escalate, False Positive, Supervisor reopen) MUST be recorded in the audit log with: session ID, actor (reviewer or supervisor), disposition, timestamp, and free-text note (if provided).
- **FR-017**: The AI filter's original flag event (spec 030 FR-022) and the reviewer's disposition MUST be linked by session ID so the full lifecycle — flag created → reviewed → disposed — is queryable.

### Key Entities

- **ReviewSession** — existing entity; gains `priority` field (`normal` | `elevated`) populated by the AI post-generation filter
- **SafetyFlag** — new entity: session_id, created_at, created_by (system), confidence_score, disposition (`pending` | `resolved` | `escalated` | `false_positive`), disposed_by, disposed_at, notes
- **SafetyFlagAuditEvent** — append-only log: flag_id, event_type, actor, timestamp, notes

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All elevated sessions appear above normal sessions in every reviewer's queue — zero instances of an unresolved elevated session below a normal session at the same load time.
- **SC-002**: A reviewer can identify, open, and submit a complete review with flag disposition for an elevated session in under 3 minutes (median across test users).
- **SC-003**: 100% of flag disposition events are recorded in the audit log — verified by integration test that fires all disposition types and confirms log entries.
- **SC-004**: Zero instances of the safety flag resolution step rendering on normal sessions — verified by automated test across a sample of 50 non-elevated sessions.
- **SC-005**: Priority indicator correctly translated in all three supported locales — verified by i18n completeness check with zero missing keys.
- **SC-006**: Supervisors can view all unresolved escalations within one navigation action from their queue landing page — no more than one click to reach the escalated session list.

---

## Dependencies

- **spec 030 FR-022 (Blocking)**: The AI post-generation filter must emit a `priority` field (`normal` | `elevated`) on flagged sessions before this feature can surface elevated sessions in the queue. This spec can be developed and tested in staging with synthetic elevated sessions, but production value requires spec 030 to ship first.
- **spec 011 Review Form**: This feature extends the existing review form from spec 011. The safety flag resolution section is additive — it does not alter the existing scoring fields.

## Assumptions

- "Elevated" priority is binary (elevated vs. normal) for this spec; future tiers (e.g., "critical") are out of scope.
- The AI filter's confidence threshold for `elevated` (vs. auto-blocking) is configured by spec 030 and is not controlled by this spec.
- Supervisor queue visibility reuses the existing supervisor role defined in spec 011.
- The free-text notes field in the flag resolution step does not require separate moderation.

## Out of Scope

- Configuring the AI filter's confidence threshold (spec 030's responsibility)
- Notifications or paging for escalated sessions (separate feature)
- Bulk flag resolution actions on multiple sessions at once
- Reviewer performance metrics based on false-positive rate (analytics / reporting feature)

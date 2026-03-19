# Implementation Plan: Review Queue Safety Prioritisation

**Branch**: `032-review-queue-safety-priority` | **Date**: 2026-03-18 | **Spec**: `specs/032-review-queue-safety-priority/spec.md`
**Input**: Feature specification from `/specs/032-review-queue-safety-priority/spec.md`

## Summary

Integrate crisis_low_confidence sessions from the AI post-generation filter into the workbench review queue as elevated-priority items. Elevated sessions appear at the top of the queue with a visual priority badge. The review form gains a mandatory Safety Flag Resolution step (Resolve / Escalate / False Positive) that only renders for elevated sessions. Supervisors see escalated sessions above routine second-level review items. The feature depends on the AI filter (spec 030 FR-022) emitting a `priority = elevated` field alongside flagged sessions.

## Technical Context

**Language/Version**: TypeScript 5.6 (shared types), TypeScript 5.x / Node.js (backend Express), TypeScript 5.x / React 19 (workbench frontend)
**Primary Dependencies**: Express.js (backend), React 19 + Zustand (workbench frontend), @mentalhelpglobal/chat-types (shared types), react-i18next (i18n), Tailwind CSS (styling), Lucide React (icons)
**Storage**: PostgreSQL via Cloud SQL (`chat-db-dev`) — existing `sessions`, `risk_flags`, `safety_flag_audit_events` tables
**Testing**: Vitest (backend unit), Vitest + React Testing Library (frontend unit), Playwright (E2E in chat-ui)
**Target Platform**: Web (workbench at `https://workbench.dev.mentalhelp.chat`)
**Project Type**: Multi-repo web application feature (chat-types → chat-backend → workbench-frontend → chat-ui)
**Performance Goals**: Queue renders in <2s with elevated sessions sorted to top; review submission with disposition completes in <1s
**Constraints**: Must not alter existing review form for normal sessions; must support 3 locales (en, uk, ru); WCAG 2.1 AA compliance for priority indicators
**Scale/Scope**: Hundreds of sessions per day; elevated sessions are a small fraction (~1-5%)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Spec-First Development | PASS | Spec exists at `specs/032-review-queue-safety-priority/spec.md` |
| II. Multi-Repository Orchestration | PASS | Changes span chat-types, chat-backend, workbench-frontend, chat-ui |
| III. Test-Aligned Development | PASS | Backend: Vitest, Frontend: Vitest + RTL, E2E: Playwright in chat-ui |
| IV. Branch and Integration Discipline | PASS | Feature branch `032-review-queue-safety-priority` in all repos → `develop` via PR |
| V. Privacy and Security First | PASS | Safety flag dispositions recorded in audit log; no new PII exposure |
| VI. Accessibility and Internationalization | PASS | Priority badge WCAG AA compliant; i18n keys for en/uk/ru |
| VII. Split-Repository First | PASS | All work in split repos (no chat-client changes) |
| VIII. GCP CLI Infrastructure Management | N/A | No infrastructure changes — uses existing Cloud SQL |
| IX. Responsive UX and PWA Compatibility | PASS | Queue and form components use existing responsive grid patterns |
| X. Jira Traceability | PASS | Epic created; tasks will map to Jira issues |
| XI. Documentation Standards | PASS | User Manual, Release Notes updates required at production deploy |
| XII. Release Engineering | PASS | No infrastructure topology changes; standard feature release path |

## Project Structure

### Documentation (this feature)

```text
specs/032-review-queue-safety-priority/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (API contracts)
│   └── review-queue-api.md
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (split repositories)

```text
chat-types/src/
├── review.ts            # QueueSession.safetyPriority, SafetyFlagDisposition, SubmitReviewInput, QueueCounts
└── reviewConfig.ts      # FlagStatus, Severity, ReasonCategory enums

chat-backend/src/
├── db/migrations/
│   └── 034_add_safety_priority.sql    # sessions.safety_priority column + safety_flag_audit_events table
├── routes/
│   ├── review.queue.ts                # Queue listing with elevated count
│   ├── review.sessions.ts            # Review submission with disposition validation
│   ├── review.flags.ts               # Flag management
│   └── review.supervision.ts         # Supervision queue with elevated-first sorting
├── services/
│   ├── review.service.ts             # Disposition recording, flag lifecycle, audit events
│   ├── reviewQueue.service.ts        # Queue sorting (CASE safety_priority WHEN 'elevated' THEN 0)
│   ├── riskFlag.service.ts           # Flag creation/resolution
│   └── supervision.service.ts        # Supervisor queue ordering
└── middleware/
    └── reviewAuth.ts                  # Permission middlewares (REVIEW_ESCALATION, REVIEW_SUPERVISE)

workbench-frontend/src/
├── features/workbench/review/
│   ├── ReviewQueueView.tsx            # Main queue — elevated badge count, auto-refresh
│   ├── ReviewSessionView.tsx          # Review detail — safety flag resolution section
│   ├── ReviewRatingPanel.tsx          # Rating form — score + criteria + disposition
│   ├── SupervisorReviewView.tsx       # 3-column supervisor layout
│   └── components/
│       ├── SessionCard.tsx            # Priority badge (amber AlertTriangle for elevated)
│       ├── SupervisorQueueTab.tsx     # Elevated sessions with amber left border
│       ├── SupervisorCommentPanel.tsx # Approve/disapprove decisions
│       └── SafetyFlagResolution.tsx   # Disposition radio group + notes (new or existing)
├── stores/
│   ├── reviewStore.ts                # safetyFlagDisposition, safetyFlagNotes state
│   └── supervisionStore.ts           # Supervision queue with elevated sorting
├── services/
│   └── reviewApi.ts                  # API client — submitReview, reopenSafetyFlag
└── locales/
    ├── en.json                       # review.safetyFlag.* keys
    ├── uk.json                       # Ukrainian translations
    └── ru.json                       # Russian translations

chat-ui/tests/e2e/
└── workbench/
    └── safety-priority.spec.ts       # E2E tests for elevated queue + flag resolution
```

**Structure Decision**: Multi-repository feature extending existing review system across chat-types (shared types), chat-backend (API + database), workbench-frontend (UI), and chat-ui (E2E tests). All patterns follow established conventions in each repo.

## Implementation Approach

### Phase 1: Shared Types (chat-types)

Types already defined in `chat-types@1.13.1`:
- `QueueSession.safetyPriority: 'normal' | 'elevated'`
- `SafetyFlagDisposition = 'resolve' | 'escalate' | 'false_positive'`
- `SubmitReviewInput.safetyFlagDisposition?: SafetyFlagDisposition`
- `SubmitReviewInput.safetyFlagNotes?: string`
- `QueueCounts.elevated: number`

**Gap check**: Verify no additional types needed for supervisor escalation visibility (US3). The `SupervisionQueueItem` type may need an `escalationDisposition` field if not already present.

### Phase 2: Backend (chat-backend)

Database schema already in place (migration 034):
- `sessions.safety_priority VARCHAR(16)` with CHECK constraint
- `safety_flag_audit_events` append-only table
- Filtered index on `safety_priority = 'elevated'`

Service logic already implemented:
- Queue sorting: `CASE s.safety_priority WHEN 'elevated' THEN 0 ELSE 1 END ASC`
- Disposition validation on review submission (requires disposition when elevated)
- Flag lifecycle: resolve → normal, escalate → supervisor queue, false_positive → normal + logged
- Supervisor flag reopen: `PATCH /sessions/:sessionId/safety-flag/reopen`
- Audit events written for all disposition types

**Gap check**: Verify edge cases from spec:
- EC1: Mid-review priority change (indicator on next load, no disruption)
- EC2: Draft review persistence including disposition selection
- EC3: Closed session receiving elevated flag (suppress from active queue)
- EC4: Large volume of elevated sessions — covered by (a) partial filtered index `idx_sessions_safety_priority` WHERE `safety_priority = 'elevated'` in migration 034, and (b) `QueueCounts.elevated` count displayed in the queue header badge. No additional task needed.
- EC5: Supervisor reopening a false-positive flag

### Phase 3: Frontend (workbench-frontend)

UI already implemented:
- `SessionCard`: Shows amber `AlertTriangle` badge when `safetyPriority === 'elevated'`
- `ReviewQueueView`: Displays elevated count badge, 60s auto-refresh
- `reviewStore`: Tracks `safetyFlagDisposition` and `safetyFlagNotes`
- `SupervisorQueueTab`: Elevated sessions with amber left border
- `reviewApi.ts`: `reopenSafetyFlag()`, `submitReview()` with disposition

**Gap check**: Verify:
- Safety Flag Resolution UI component exists and renders only for elevated sessions
- Form submission blocking when disposition not selected
- Validation message for missing disposition
- All i18n keys present in en/uk/ru for safety flag resolution section
- Supervisor can see escalation disposition + reviewer notes in second-level review
- FR-015: Supervisor reopen of false-positive flags
- EC2: Verify that `reviewStore` has Zustand `persist` middleware configured so that `safetyFlagDisposition` and `safetyFlagNotes` survive page reload. If persist is not configured, add it as a task.
- FR-014 vocabulary: The existing supervisor decision endpoint uses `approved | disapproved`. For escalated sessions, the UI must render context-sensitive labels: "Confirm Escalation" (maps to `approved`) and "Dismiss Escalation" (maps to `disapproved`). The `SupervisorCommentPanel` component needs conditional rendering when the review being supervised has an `escalate` disposition. Add i18n keys: `supervision.confirmEscalation`, `supervision.dismissEscalation`.

### Phase 4: E2E Tests (chat-ui)

New E2E tests needed:
- US1: Elevated session appears above normal sessions in queue
- US1: Priority badge visible and correctly translated (en, uk, ru)
- US1: No empty elevated section when none exist
- US2: Safety flag resolution renders for elevated, not for normal sessions
- US2: Submission blocked without disposition selected
- US2: Escalate → session appears in supervisor queue
- US2: Resolve → session leaves elevated tier
- US2: False Positive → flag dismissed, logged
- US3: Escalated sessions visible to supervisor above routine items
- US3: Supervisor can resolve escalated session
- US3: Supervisor can reopen false-positive flag

### Cross-Repository Dependency Order

```
1. chat-types     — Verify types sufficient (bump version if changes needed)
2. chat-backend   — Verify API completeness, add missing edge case handling
3. workbench-frontend — Verify UI completeness, add missing components/i18n
4. chat-ui        — Write E2E tests against deployed dev environment
```

Each repo: feature branch `032-review-queue-safety-priority` off `develop`, PR back to `develop`.

### Explicit Out of Scope (plan-level)

- **AI filter feedback loop**: FR-011 requires false-positive events be "logged for AI filter feedback purposes." This spec logs the event in `safety_flag_audit_events`. The active feedback pipeline (exporting false-positive data to retrain or tune the AI filter in spec 030) is out of scope for this feature. The audit data is queryable for future feedback integration.

## Complexity Tracking

> No constitution violations identified. No complexity tracking needed.

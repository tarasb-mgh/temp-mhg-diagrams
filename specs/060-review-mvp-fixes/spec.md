# Feature Specification: Review MVP Defect Bundle (REVISED 2026-04-27)

**Feature Branch**: `060-review-mvp-fixes`
**Created**: 2026-04-27 | **Revised**: 2026-04-27 (post-investigation)
**Status**: Draft (revised after codebase inspection)
**Input**: Fix four user-facing defects (MC-64/65/66/67) discovered in the 2026-04-27 dev regression.

> **Revision note (2026-04-27, post-codebase-inspection):** Original draft (v1) assumed missing infrastructure (queue service, broken-reason DB column, etc.) that turned out to already exist in chat-backend `develop` (058 Reviewer Queue work, PR #221+). After inspecting `reviewQueue.service.ts` and `reviewDashboard.service.ts`, the real root causes are far narrower than the v1 spec implied. Total scope reduced from ~2 engineer-days / 53 tasks to ~0.5-1 engineer-day / ~12 tasks. The Jira artifacts (MTB-1546..MTB-1603) created against the v1 plan are now mostly obsolete — see `tasks.md` for which to keep and which to close.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Reviewer's queue contains only actionable sessions (Priority: P1)

A Reviewer opens the Workbench Review Queue. Today, sessions with zero ratable AI responses appear in the **In Progress** and **Flagged** tabs, tagged with a "Broken" badge whose tooltip explains *"This session has no assistant replies to rate — it was surfaced by mistake."* This wastes the Reviewer's time. The system already filters such sessions from the **Pending** and **Completed** tabs (the count/list parity guard added in 058 PR#221 / 2026-04-21), but the same filter was not applied to In Progress and Flagged tabs. After this fix, all reviewer-facing tabs apply the parity guard consistently.

**Why this priority**: High-severity defect (MC-65). The fix is a ~5-line patch in one file (`chat-backend/src/services/reviewQueue.service.ts`).

**Independent Test**: Sign in as Owner on dev. Iterate every reviewer-facing tab in `/workbench/review`. Verify zero session cards display the "Broken" badge under any Space scope.

**Acceptance Scenarios**:

1. **Given** a session that has `messageCount > 0` AND `assistantMessageCount === 0` exists in the database, **When** a Reviewer views any reviewer-facing tab (Pending / Flagged / In Progress / Completed) under any Space scope, **Then** the session does NOT appear in the visible list.
2. **Given** the existing 2 broken sessions on dev (`CHAT-8611`, `CHAT-EC17`), **When** a Reviewer signs in and navigates to the In Progress tab under the "Dev team" Space, **Then** neither session appears.
3. **Given** the count query and list query for the same tab + scope, **When** both are executed, **Then** the count badge equals the list `total`, with no rows excluded by the list that are still counted in the badge.

---

### User Story 2 — Dashboard counters tell the truth about the queue (Priority: P1)

A Reviewer opens the Workbench Dashboard and sees a "Pending Review" tile claiming there are N sessions awaiting review. Today, the tile uses a bespoke query in `reviewDashboard.service.ts:378` that lacks the queue's filters (no parity guard, no `review_count < reviews_required` check, no `session_exclusions` guard). The result: tile says 91 while the queue Pending tab shows 0 (or 31). After this fix, the tile uses the same filtering logic as the queue Pending tab.

**Why this priority**: High-severity (MC-64). Direct user-trust defect. Fix is replacing a bespoke SQL query with a call to (or replication of) the queue service's count logic.

**Independent Test**: Sign in as Owner on dev. Note Dashboard "Pending Review" tile count + Space combobox value. Navigate to Review Queue. Verify Pending tab badge equals tile count for the same Space scope, including All Spaces.

**Acceptance Scenarios**:

1. **Given** the user has a specific Space selected, **When** they view the Dashboard Pending Review tile, **Then** the tile equals the count of sessions visible in the Pending tab under that same Space scope.
2. **Given** the user clicks the Pending Review tile, **When** they land on the Review Queue, **Then** the Pending tab badge displays the exact same number as the tile reported.
3. **Given** the Space combobox is set to "All Spaces", **When** both surfaces are queried, **Then** they return the same number with no scope-mismatch.

---

### User Story 3 — Team Dashboard renders for actual team members (Priority: P2)

An Owner-role user opens the Team Dashboard expecting to see team-level review statistics for the Spaces they belong to. Today the page reports *"No active team membership"* even when the user is a member of multiple Spaces (visible in the Space combobox). After this fix, the membership check uses the same source as the Space combobox so the page renders content for any user with at least one Space membership.

**Why this priority**: Medium (MC-67). Blocks Owner from accessing team statistics. Fix is reconciling two membership data sources.

**Independent Test**: Sign in as Owner on dev (has 9 Space memberships). Navigate to Team Dashboard. Pass = page renders content (statistics, charts), not the generic empty state.

**Acceptance Scenarios**:

1. **Given** the user is a member of at least one Space, **When** they open Team Dashboard, **Then** team statistics render.
2. **Given** the user has zero Space memberships, **When** they open Team Dashboard, **Then** the empty-state copy correctly indicates the absence of memberships.
3. **Given** the Team Dashboard membership endpoint and the Space-combobox endpoint are queried for the same user, **When** their `spaces` arrays are compared, **Then** they are identical.

---

### User Story 4 — Broken-session tooltip stays accurate (Priority: P3)

After US1 lands, broken sessions no longer appear in the queue. The frontend "Broken" badge tooltip on `SessionCard.tsx` remains as a defensive safety-net for any session that still slips through (e.g., due to data races during ingest). The tooltip wording must match the actual criterion the badge uses (`assistantMessageCount === 0 && messageCount > 0`).

**Why this priority**: Low/cosmetic (MC-66). Once US1 lands, this tooltip is rarely seen by users. Verifying the wording matches the criterion is a 1-line review of the EN locale.

**Independent Test**: Read `workbench-frontend/src/locales/en.json:1459` and verify the tooltip describes the exact `isBroken` criterion at `SessionCard.tsx:104`. Currently the tooltip says *"This session has no assistant replies to rate — it was surfaced by mistake."* — which IS accurate. **No code change required**; this story is a verification task.

**Acceptance Scenarios**:

1. **Given** the existing tooltip text, **When** compared to the `isBroken` criterion, **Then** the wording correctly describes "no assistant replies" (matches the `assistantMessageCount === 0` part of the formula).
2. **Given** US1 has shipped, **When** a Reviewer browses the queue normally, **Then** the tooltip is essentially never seen because broken sessions are filtered out.

---

### Edge Cases

- **Race during ingest**: A session is in the process of receiving its first assistant message at query time. The parity guard correctly excludes it; once the message is committed, subsequent queries include it.
- **Sessions with non-standard role values**: `session_messages.role` is normalized via `LOWER(TRIM(...))` and matched against `('assistant', 'ai', 'bot', 'model', 'agent')`. Any role not in that set is treated as non-assistant. If new role values are introduced, the allow-list must be extended (separate ticket).
- **All Spaces vs single-Space scope**: Both the queue and the dashboard tile must respect the same scope; switching one but not the other (current bug) creates the user-visible mismatch.
- **Tab badge vs page count**: The list query's `total` and the tab badge from `getQueueCounts` must always agree. The 058 parity guard codified this for Pending/Completed; this fix extends it to In Progress/Flagged.

## Requirements *(mandatory)*

### Functional Requirements

**Queue parity guard extension (closes MC-65)**

- **FR-001**: `getQueueCounts` MUST apply the `reviewerTabHasAssistantMessage` EXISTS guard to the `flagged` and `in_progress` COUNT FILTER clauses (currently only on `pending` and `completed`).
- **FR-002**: `listQueueSessions` MUST apply the same parity guard to the `flagged` and `in_progress` tab branches (currently only on `pending` and `completed` per the `if (tab === 'pending' || tab === 'completed')` check at line 308).

**Dashboard counter reconciliation (closes MC-64)**

- **FR-003**: The Dashboard `pending_review` count in `reviewDashboard.service.ts` MUST apply the same filters used by the queue Pending tab: parity guard + `review_count < reviews_required` + `session_exclusions` guard.
- **FR-004**: The Dashboard tile MUST scope to the user's selected Space when one is provided.

**Team Dashboard membership (closes MC-67)**

- **FR-005**: The Team Dashboard membership endpoint MUST use the same `getSpacesForUser(userId)` data source as the Space-combobox endpoint.
- **FR-006**: The Team Dashboard MUST render team statistics for any user with at least one Space membership and Owner role.

**Tooltip verification (closes MC-66)**

- **FR-007**: The frontend `SessionCard` "Broken" badge tooltip text MUST accurately describe the `isBroken` criterion (`assistantMessageCount === 0 && messageCount > 0`). Verification only — no code change required if current text matches.

**Tests**

- **FR-008**: Extend `reviewQueue.countListParity.test.ts` (or add a new test file) with cases asserting parity for `in_progress` and `flagged` tabs.
- **FR-009**: Add a regression-suite YAML test case (RQ-100; renumbered from drafted "RQ-014" because the latter was already taken by "Awaiting feedback tab loads", and from interim "RQ-015" because module 19 also defined an RQ-015) asserting no `Broken` badge appears in any reviewer-facing tab.
- **FR-010**: Add a regression-suite YAML test case (RQ-002a) asserting Dashboard tile == Queue Pending tab count under matching Space scope.
- **FR-011**: Add a regression-suite YAML test case (RD-007; renumbered from drafted "RD-005" which was already taken by "Review Tags page loads") asserting Team Dashboard renders content for an Owner with ≥1 Space membership.

### Key Entities

No new entities. All work uses existing `sessions`, `session_messages`, `session_reviews`, `session_exclusions`, and `groups` tables. The `BrokenReason` enum and `broken_reason` column proposed in v1 are NOT needed.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: After deployment, zero `Broken`-badged session cards appear in any reviewer-facing Review Queue tab during the next regression run, across both single-Space and All-Spaces scopes.
- **SC-002**: After deployment, the Dashboard "Pending Review" tile and the Review Queue Pending tab badge display the same number 100% of the time when scoped to the same Space.
- **SC-003**: After deployment, an Owner test account with ≥1 Space membership sees the Team Dashboard render content (not the empty state) — verified across all 9 dev Spaces.
- **SC-004**: After deployment, the existing tooltip text on the `Broken` badge accurately describes the criterion that triggered it (verified by reading the locale string + SessionCard.tsx).
- **SC-005**: Re-running the four review-related regression modules (03-review-queue, 04-review-session, 05-review-dashboards, 06-safety-flags) yields 15/15 passes (12 prior passes + RQ-002a + RQ-100 + RD-007).
- **SC-006**: MC-63 chat-backend release unblocked from a Review-Queue UX standpoint; all 4 child bugs (MC-64, MC-65, MC-66, MC-67) closed with linked PRs.

## Assumptions

- The 058 Reviewer Queue work (PR #221, landed in chat-backend `develop`) is the canonical implementation. This fix bundle extends it, doesn't replace it.
- The existing parity guard (`reviewerTabHasAssistantMessage`) is the correct logic; the bug is purely that it wasn't applied uniformly.
- The Owner role meeting "team membership" requirement is acceptable for MC-67; a stricter role gate would need a separate spec story.
- The data discrepancy between session-list `assistantMessageCount: 0` and session-detail showing 8 assistant messages (observed during 2026-04-27 regression) MAY be due to differences in role-value normalization between session ingest and queue query. Implementation should verify by reading `session_messages` directly for `CHAT-8611` and `CHAT-EC17`. If a count-side bug is confirmed, add it as a follow-up FR.

## Out of scope (explicit)

- New `broken_reason` DB column, `BrokenReason` enum, dynamic tooltip refactor — all unnecessary given the actual bug shape.
- The 10 deferred regression tests from the 2026-04-27 run (RQ-010..013, RS-005..007/009, SF-005/006).
- Stray "Anxiety" tooltip leak across pages.
- Review MVP role-account provisioning (MC-58).
- Admin diagnostics page for broken sessions.

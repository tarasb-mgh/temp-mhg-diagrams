# Research: 061-mc-64-tile-label

**Date**: 2026-04-28

## Decisions

### D-001: Rename label vs. replace data vs. remove tile

**Decision**: Rename the i18n key (Approach A from design doc).

**Rationale**: The data the tile shows (count of `moderation_status='pending'` sessions) is correct for the `WORKBENCH_RESEARCH`-permission audience the tile serves. Only the label was misaligned with that data. Renaming is minimal-blast-radius and honest.

**Alternatives considered**:
- B (replace data): would introduce a new admin-stats field with ambiguous scope (per-reviewer vs team-wide). Team-wide variant would still diverge from the per-reviewer queue badge — same scope problem, papered over.
- C (remove tile): drops a real admin signal. The tile shows admin-relevant moderation queue depth; admins benefit from seeing it.

### D-002: Russian translation form

**Decision**: "Ожидают модерации" (Russian feminine genitive, "и" ending).

**Rationale**: Mirrors the existing Russian subtitle in `ru.json`: "Сессии ожидают модерации". An earlier draft of the spec contained "Ожидают модерації" — that's a Ukrainian-Russian hybrid (Ukrainian uses "ції" ending) and was caught in self-review and corrected.

### D-003: Drop RQ-002a vs. retarget RQ-002a

**Decision**: Drop RQ-002a entirely and add a new RQ-002b that asserts label correctness.

**Rationale**: RQ-002a's assertion (`tile == queue badge equality`) is intrinsically wrong now that we know the surfaces query different DB columns. Retaining it under the same ID would create ID-vs-purpose drift and confuse future readers. RQ-002b is a clean new test focused on the actual user-visible MC-64 fix.

**Alternative considered**: Repurpose RQ-002a by editing its assertion. Rejected because the test name and intent would be inconsistent with the new assertion; cleaner to start fresh.

### D-004: i18n key path

**Decision**: New key path is `dashboard.stats.pendingModeration` (parallel structure to `dashboard.stats.pendingReview`).

**Rationale**: Maintains the existing namespace organization. The other `pendingReview` keys in different namespaces (Reports / Review Queue / Messages) stay untouched and continue to be correct in their own contexts.

## Inputs

- Design doc: `docs/superpowers/specs/2026-04-28-mc-64-followup-design.md`
- Predecessor spec: `specs/060-review-mvp-fixes/spec.md`
- Verification regression that surfaced the issue: `regression-suite/results/2026-04-28-00-10-060-verify.md`
- Source code traced:
  - `chat-backend/src/services/sessionModeration.service.ts:34-64` (`getAdminSessionsStats`) — confirms data field is `byModerationStatus.pending`.
  - `chat-backend/src/routes/admin.sessions.ts:108-115` — confirms the route is `/api/admin/sessions/stats`.
  - `workbench-frontend/src/features/workbench/Dashboard.tsx:165-186` — confirms tile structure (label, value, subtitle, click-through).
  - `workbench-frontend/src/locales/{en,uk,ru}.json` (`dashboard.stats.pendingReview` and `dashboard.stats.awaitingModeration` keys).
  - `chat-backend/src/db/migrations/005_add_session_moderation.sql` and `013_add_review_system.sql` — confirms `moderation_status` and `review_status` are independent columns.

## Open questions

None at plan time. All 0 NEEDS CLARIFICATION markers in the spec; checklist passed first iteration.

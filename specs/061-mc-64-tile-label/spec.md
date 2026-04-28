# Feature Specification: MC-64 Follow-up — Honest Dashboard Tile Label

**Feature Branch**: `061-mc-64-tile-label`
**Created**: 2026-04-28
**Status**: Draft
**Jira Epic**: MTB-1604 | **Bug**: MC-64 (stays open until verified live on dev)
**Predecessor**: Feature 060 (`specs/060-review-mvp-fixes/`) — partial fix shipped; this addresses the user-visible surface that the original spec misidentified.
**Design doc**: `docs/superpowers/specs/2026-04-28-mc-64-followup-design.md`
**Input**: Rename the mis-labeled `/workbench` Admin Dashboard "Pending Review" tile to "Pending Moderation" so the label honestly reflects the underlying data (`moderation_status='pending'`), not the unrelated `review_status='pending_review'` workflow.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Workbench admin sees an honest tile label (Priority: P1)

A workbench admin opens the `/workbench` Admin Dashboard. Today, a tile labeled "Pending Review" shows a number (e.g. 91) that visually invites comparison with the Review Queue Pending tab badge (e.g. 31), yet the two will never match because they query different database columns governing different workflows. After this fix, the tile is relabeled "Pending Moderation" — the data was correct all along; only the label was lying. The admin no longer sees a false equivalence.

**Why this priority**: P1 — closes the user-visible side of bug MC-64 that the prior fix-bundle (Feature 060) didn't address. The data flow and click-through behavior are already correct; only the label is wrong.

**Independent Test**: Sign in as Owner on dev. Navigate to `/workbench`. Verify the tile that was previously "Pending Review" now reads "Pending Moderation" in English (and "Очікують модерації" / "Ожидают модерации" under uk / ru locales). Verify the tile's value, click-through, and subtitle are unchanged.

**Acceptance Scenarios**:

1. **Given** the user is signed in as an admin with WORKBENCH_RESEARCH permission and the active locale is English, **When** they open `/workbench`, **Then** the tile reads "Pending Moderation" with subtitle "Sessions awaiting moderation".
2. **Given** the active locale is Ukrainian, **When** they open `/workbench`, **Then** the tile reads "Очікують модерації".
3. **Given** the active locale is Russian, **When** they open `/workbench`, **Then** the tile reads "Ожидают модерации".
4. **Given** the user clicks the tile, **When** the navigation completes, **Then** they land on `/workbench/research?status=pending` (unchanged behavior).
5. **Given** the value displayed on the tile, **When** compared to `getAdminSessionsStats().byModerationStatus.pending` returned from the backend, **Then** they are equal (unchanged data behavior).

---

### Edge Cases

- **Mid-deploy locale fallback**: if a stale workbench-frontend bundle still references the old i18n key after deploy, the user could briefly see the literal key string `dashboard.stats.pendingReview` rendered in the UI. Mitigation: rename the key cleanly with no transitional alias, and rely on aggressive cache-busting on the workbench-frontend deploy (existing behavior). Acceptable risk; the window is minutes during a normal deploy rollout.
- **Other consumers of `dashboard.stats.pendingReview`**: a code search confirms `Dashboard.tsx:176` is the sole consumer of that exact key path under `dashboard.stats`. Other locale files contain `pendingReview` keys under different namespaces (Reports / Review Queue / Messages); those are correct in their own contexts and must NOT be renamed.
- **Subtitle drift**: the tile's subtitle already reads `dashboard.stats.awaitingModeration` ("Sessions awaiting moderation"). It must remain unchanged so the tile reads coherently after the title rename.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The `/workbench` Admin Dashboard tile that today reads "Pending Review" MUST instead read "Pending Moderation" under the English locale.
- **FR-002**: The same tile MUST read "Очікують модерації" under the Ukrainian locale and "Ожидают модерации" under the Russian locale.
- **FR-003**: The tile's data source MUST remain `getAdminSessionsStats().byModerationStatus.pending` (no backend change; no scope change to the count).
- **FR-004**: The tile's click-through MUST continue to navigate to `/workbench/research?status=pending`.
- **FR-005**: The tile's subtitle MUST continue to read the localized form of "Sessions awaiting moderation" (i18n key `dashboard.stats.awaitingModeration`, unchanged).
- **FR-006**: Other i18n keys named `pendingReview` in non-`dashboard.stats` namespaces (Reports / Review Queue / Messages) MUST NOT be renamed. They remain "Pending Review" / "Очікують перевірки" / "Ожидают проверки" in their own contexts.
- **FR-007**: The chat-backend `getTeamStats` patch from Feature 060 (`chat-backend@c7648ac`) MUST remain in place. It is independently valid for the Team Dashboard surface and is not affected by this fix.
- **FR-008**: The regression-suite test that asserted tile == queue badge equality (RQ-002a) MUST be removed. Its assertion is intrinsically wrong now that we know the surfaces query different DB columns; leaving it active would always fail and pollute standard-mode verdicts.
- **FR-009**: A new regression-suite test (RQ-002b) MUST assert the tile label reads "Pending Moderation" / "Очікують модерації" / "Ожидают модерации" under the active locale, and explicitly does NOT contain "Pending Review" or its localized equivalents.

### Key Entities

No new entities. This is a label-only change. Existing entities (`sessions.moderation_status` column, the `getAdminSessionsStats` aggregator) are unchanged.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: After deployment to dev, 100% of admin users opening `/workbench` under any of the three supported locales (en / uk / ru) see the tile labeled with the moderation phrasing, not the review phrasing.
- **SC-002**: Re-running `/mhg.regression module:03-review-queue` on dev: RQ-002b passes; no other test regresses; the previously-failing RQ-002a is no longer present in the suite.
- **SC-003**: After this fix lands, `grep -rn "dashboard.stats.pendingReview" workbench-frontend/src/` returns zero results (key fully removed; no stale references).
- **SC-004**: Bug MC-64 closes in Jira with linked PRs (workbench-frontend + client-spec) and RQ-002b regression-evidence.

## Assumptions

- The existing `dashboard.stats.awaitingModeration` translations correctly express "Sessions awaiting moderation" in en/uk/ru. Confirmed via locale file inspection: en="Sessions awaiting moderation", uk="Сесії очікують модерації", ru="Сессии ожидают модерации".
- The Russian and Ukrainian translations chosen ("Ожидают модерации" / "Очікують модерації") will pass review by a native speaker. They mirror the existing subtitle phrasing and are direct translations of the English. If a native-speaker reviewer has a stronger preference, the change is trivial.
- The `WORKBENCH_RESEARCH` permission gating the tile's render block in `Dashboard.tsx` is unchanged. No permission redesign.

## Out of scope (explicit)

- chat-backend changes — the existing `getTeamStats` patch (`c7648ac`) is independently valid for the Team Dashboard surface; do not revert.
- Removing the tile entirely (rejected approach C from the design doc).
- Adding a new "review-eligible pending count" admin endpoint (rejected approach B).
- Database migration changes.
- Any change to the tile's data source, click-through, or subtitle.
- Renaming `pendingReview` keys in other namespaces.
- Adding additional regression-suite coverage beyond RQ-002b.

# Review MVP Defect Bundle — Design

**Date:** 2026-04-27
**Source incident:** Regression run on dev `https://workbench.dev.mentalhelp.chat`, results at `regression-suite/results/2026-04-27-09-15-review-only.{md,yaml}`
**Bugs filed:** MC-64 (Medium), MC-65 (High), MC-66 (Medium), MC-67 (Medium)
**Blocks release:** MC-63 (chat-backend develop→main bundle release containing 058 Reviewer Queue + 059 Reports)

---

## Goal

Fix the four user-facing defects discovered in the 2026-04-27 dev regression so that the chat-backend release (MC-63) can ship the 058 Reviewer Queue + 059 Reports work to production without regressing the existing Reviewer queue UX, the existing Dashboard counter, or the existing Team Dashboard surface.

## Why this matters

- **MC-63 is gated by these defects.** Day-1 of prod cutover would face immediate user complaints if Reviewers find broken sessions in their queue (MC-65) or click "91 pending" tiles that lead to empty queues (MC-64).
- **MC-65 directly contradicts US-03 (MC-18, currently IN TESTING).** Until MC-65 is fixed, US-03 should not move to Done.
- **The Review MVP user-trust narrative depends on the queue showing real, actionable sessions.** Foundational fix.

## Scope (in)

### Backend changes (chat-backend)

1. **Queue API broken-session filter.** `/api/review/queue` defaults to `WHERE is_broken = false`. Opt-in `?include_broken=true` (admin-only) for future diagnostics. *Closes MC-65.*
2. **Dashboard counter unification.** `/api/dashboard/summary`'s `pendingReview` field stops using a bespoke query and calls into the queue service's count helper, so the same `WHERE` clause governs both surfaces. The tile sum scopes to the active Space. *Closes MC-64.*
3. **Broken-session detection refactor.** Introduce `BrokenReason` enum (`NO_ASSISTANT_REPLIES`, `EMPTY_TRANSCRIPT`, `MALFORMED`, …). Store the reason on each session row. Expose via session DTO. *Closes MC-66.*
4. **Team Dashboard membership reconciliation.** `/api/team-dashboard/membership` uses the same `getSpacesForUser()` source as the Space-combobox endpoint. Returns `{ spaces, hasTeamMembership, missingRole | null }`. *Closes MC-67.*

### Frontend changes (workbench-frontend)

5. **Defensive broken-session filter** in `Queue.tsx` (safety net even after backend filter).
6. **Dynamic broken-badge tooltip** rendered from `session.brokenReason` via a localized string map.
7. **Team Dashboard empty-state copy** consumes the new discriminator; renders either the page or a clearer "Team membership requires <role>" copy when `missingRole != null`.
8. **Dashboard tile** respects active Space; labels its scope ("Pending Review (Dev team)" or "(All Spaces)").

### Test changes (regression-suite)

9. **RQ-002a** — Pending tab badge equals Dashboard tile count under matching Space scope.
10. **RQ-014** — No card with the `Broken` badge appears in any reviewer-facing tab.
11. **RD-005** — Team Dashboard renders content (not empty state) for an Owner who is a member of ≥1 Space.

## Scope (out)

- **The 10 deferred regression tests** (RQ-010..013, RS-005..007/009, SF-005/006). Follow-up regression cycle.
- **Cosmetic stray "Anxiety" tooltip leak** observed across pages — separate ticket if pursued.
- **Review MVP role-account provisioning** (modules 19/20/21, e2e-reviewer/supervisor/expert) — covered by MC-58.
- **The new Review MVP user stories themselves** (US-06..US-16, MC-21..MC-31). These defect fixes target *existing* surfaces.
- **Admin diagnostics page for broken sessions.** Deferred (see decision 2 below).

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  chat-backend                                                │
│                                                              │
│  routes/review.queue.ts   ──── adds: WHERE is_broken=false  │
│  services/review.count.ts ◄──── shared helper                │
│  routes/dashboard.ts      ──── uses count helper             │
│                                                              │
│  routes/team-dashboard.ts ──── uses getSpacesForUser()       │
│  services/broken-detection.ts ─── adds: BrokenReason enum    │
│  db/migrations/NNN_broken_reason.sql ─── adds column         │
└─────────────────────────────────────────────────────────────┘
            │                                    │
            │ /api/review/queue                  │ /api/team-dashboard/membership
            │ /api/dashboard/summary             │
            ▼                                    ▼
┌─────────────────────────────────────────────────────────────┐
│  workbench-frontend                                          │
│                                                              │
│  features/review/Queue.tsx          ── defensive filter     │
│  features/review/BrokenBadge.tsx    ── dynamic tooltip      │
│  features/review/TeamDashboard.tsx  ── new empty-state      │
│  features/dashboard/PendingReviewTile.tsx ── scope label    │
└─────────────────────────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────────────────────────┐
│  regression-suite (client-spec repo)                         │
│                                                              │
│  03-review-queue.yaml      ── adds RQ-002a, RQ-014           │
│  05-review-dashboards.yaml ── adds RD-005                    │
└─────────────────────────────────────────────────────────────┘
```

## Components (detailed)

### B1 — Queue API broken filter

- File: `chat-backend/src/routes/review.queue.ts` (or wherever the queue list endpoint lives — verify on branch).
- Change: query builder gains a default `WHERE is_broken = false`. New optional query param `include_broken=true` removes the filter, but is gated by an admin permission check.
- Rationale: Backend-side filter is the load-bearing fix; frontend defensive filter is belt-and-suspenders for cache cases.

### B2 — Dashboard counter unification

- File: `chat-backend/src/routes/dashboard.ts` (verify).
- Change: replace bespoke `SELECT COUNT(*)` with a call to `reviewQueueService.countBy({ groupId, statuses: ['pending', 'flagged', 'in_progress'] })`. The service's count and list both share the same `WHERE` clause builder.
- Rationale: One source of truth eliminates the layer-B mismatch (91 vs 55) by construction.

### B3 — BrokenReason enum + session DTO

- New file: `chat-backend/src/services/broken-detection.ts` (or similar).
- New migration: adds a `broken_reason` column to the relevant session/review table (nullable, enum-constrained).
- Detection logic: every existing rule that marks a session broken now also writes the typed reason.
- DTO: session DTO gains `brokenReason?: 'NO_ASSISTANT_REPLIES' | 'EMPTY_TRANSCRIPT' | 'MALFORMED' | …`.
- Rationale: Tooltip mismatch (MC-66) is fundamentally an i18n problem — UI strings must derive from typed data, not from a hardcoded copy that doesn't match the actual reason.

### B4 — Team Dashboard membership reconciliation

- File: `chat-backend/src/routes/team-dashboard.ts` (verify).
- Change: stop computing membership ad-hoc; call `getSpacesForUser(userId)` (the same source as `/api/admin/groups` per the network log from the regression run). Return `{ spaces, hasTeamMembership, missingRole | null }`.
- `missingRole` is non-null when the user has Spaces but lacks the specific role required for Team Dashboard (if that role gating is intended). Frontend uses it to render a clearer empty state.
- Rationale: The regression run showed the Space combobox lists 8 Spaces while Team Dashboard says zero — clearly two different sources. Single source eliminates that.

### F1 — Frontend defensive filter & dynamic tooltip

- Files: `workbench-frontend/src/features/review/Queue.tsx`, `BrokenBadge.tsx`.
- Change: `.filter(s => !s.isBroken)` after fetch (in addition to backend filter). `BrokenBadge` receives `reason: BrokenReason` and renders via a localized `t(`brokenReason.${reason}`)` lookup.
- New i18n keys (en/uk/ru):
  - `brokenReason.NO_ASSISTANT_REPLIES` — "This session has no assistant replies to rate."
  - `brokenReason.EMPTY_TRANSCRIPT` — "This session's transcript is empty."
  - `brokenReason.MALFORMED` — "This session's data is malformed."
  - `brokenReason.UNKNOWN` — "This session was flagged as not reviewable. See diagnostics for details." (fallback)

### F2 — Team Dashboard empty state

- File: `workbench-frontend/src/features/review/TeamDashboard.tsx`.
- Renders content when `hasTeamMembership && spaces.length > 0`. Otherwise renders a copy that explicitly references `missingRole` if present (e.g., "Team Dashboard requires the Reviewer team-member role. Ask your admin to grant access.").

### F3 — Dashboard tile scope label

- File: `workbench-frontend/src/features/dashboard/PendingReviewTile.tsx`.
- Renders count followed by scope: `"91 — All Spaces"` or `"31 — Dev team"`.
- Click handler navigates to `/workbench/review` preserving the Space query param so the queue scope matches the tile.

### T1 — Regression-suite YAML additions

- Three new test cases in two files. Each follows the existing pattern (id, priority P0/P1, role, steps, pass_criteria, error_signatures).

## Four design decisions (baked in)

1. **MC-64 Layer B "Pending Review" semantics** = sum of Pending + Flagged + In Progress (excludes Completed). *Rationale: matches user mental model of "things still to do".*
2. **MC-65 admin diagnostics for broken sessions** = NOT NOW. Hide them in queue; opt-in API param exists; no admin UI this cycle. *Rationale: scope creep risk; broken-session count is small (2 in dev); existing items inspectable via DB.*
3. **MC-66 broken-session diagnostics page** = NOT NOW. Audit + typed reason + dynamic tooltip only. *Rationale: typed-reason refactor is the load-bearing fix; tooling can come later.*
4. **MC-67 Team Dashboard for Owner** = Owner sees content. *Rationale: Owner has broadest visibility role; if a different team-membership role was intended, the spec story for that hasn't been written. Treat as bug.*

## Data flow

```
Reviewer hits Dashboard
  → GET /api/dashboard/summary?groupId=<active>
  → uses queue service count helper
  → tile shows {Pending+Flagged+InProgress count} for the active Space
  → click → /workbench/review?space=<active>
  → GET /api/review/queue?tab=pending&groupId=<active>
  → returns sessions WHERE is_broken=false (default)
  → frontend defensively re-filters
  → cards render; broken-badge tooltip data-driven from brokenReason

Reviewer hits Team Dashboard
  → GET /api/team-dashboard/membership
  → uses getSpacesForUser() — same source as Space combobox
  → returns { spaces, hasTeamMembership, missingRole|null }
  → if hasTeamMembership && spaces.length > 0 → render content
  → else → render specific empty-state copy referencing missingRole
```

## Error handling / edge cases

- Legacy rows with NULL `is_broken` → treat as `false` (safe default).
- Legacy rows with NULL `broken_reason` → frontend tooltip falls back to `brokenReason.UNKNOWN`.
- Dashboard tile request times out → tile shows "—" with retry tooltip; does not show stale "0".
- User has zero Spaces → Team Dashboard correctly shows membership empty state (this case becomes legitimate — copy adjusted).
- Race: Space switch + tile load — tile must reflect the latest Space; in-flight requests are aborted.

## Testing strategy

- **Unit (chat-backend):** queue service's count helper has tests for the 4 broken×status combinations; broken-detection writes the correct reason for each known criterion.
- **Integration (chat-backend):** new tests around `/api/dashboard/summary` and `/api/review/queue` parity; `/api/team-dashboard/membership` returns the right shape for Owner with N Spaces.
- **Component (workbench-frontend):** Queue defensive filter; BrokenBadge dynamic tooltip; TeamDashboard empty-state branches.
- **E2E (regression-suite):** RQ-002a, RQ-014, RD-005 added; suite re-runs the 12 already-passing 2026-04-27 cases to confirm no regression.
- **Manual smoke:** Owner opens Dashboard → click tile → non-empty queue. Open Team Dashboard → content. Open In Progress → no Broken badges.

## Phasing

| Phase | Repo | Deliverable | Effort |
|-------|------|-------------|--------|
| 1 | chat-backend | B1, B2, B3, B4 + service tests | ~1 day |
| 2 | workbench-frontend | F1, F2, F3 + component tests | ~0.5 day |
| 3 | client-spec / regression-suite | T1 (RQ-002a, RQ-014, RD-005) | ~0.5 day |
| 4 | Verify | re-run 2026-04-27 scenarios; close MC-64..67 | ~0.5 day |

**Total: ~2 engineer-days.** Coordinated release window with chat-backend's MC-63 bundle (or as a precursor PR to it).

## Acceptance for the bundle

- [ ] All four bugs (MC-64, MC-65, MC-66, MC-67) closed with linked PRs.
- [ ] Re-run of the 2026-04-27 regression scenarios shows: Dashboard tile == Queue Pending count under matching scope; In Progress tab shows zero `Broken` cards; Team Dashboard renders content for the Owner test account; broken-session tooltip (where shown) matches the actual flag reason.
- [ ] No regression in the 12 already-passing tests from the 2026-04-27 run.
- [ ] MC-63 (chat-backend release) unblocked from a Review-Queue user-experience standpoint.

## Users

- Reviewers, Supervisors, Experts (Workbench's primary audience).
- Release managers preparing the chat-backend → prod cutover.
- The QA agent running the regression suite.

## Constraints

- Fix must land in chat-backend's develop and workbench-frontend's develop in coordinated PRs, ideally before the MC-63 release branch is cut.
- Keep changes scoped — no incidental refactors to unrelated review code paths.

## Open follow-ups (deliberately deferred)

- Admin diagnostics view for broken sessions (would surface them with full reason metadata).
- The 10 deferred P1 regression tests — pick up in next regression cycle.
- Cosmetic "Anxiety" tooltip leak — minor, separate ticket.

## References

- Regression results: `regression-suite/results/2026-04-27-09-15-review-only.{md,yaml}`
- Bugs: `MC-64`, `MC-65`, `MC-66`, `MC-67` (all assigned to tarasb@mentalhelp.global, all created 2026-04-27)
- Blocks: `MC-63` (chat-backend release)
- Related: `MC-18` (US-03 Reviewer Session List, currently IN TESTING)
- Related: `MC-58` (Review MVP role-account provisioning, separate)

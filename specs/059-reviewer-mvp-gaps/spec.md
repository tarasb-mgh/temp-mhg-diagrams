# Feature Specification: Reviewer MVP Gap Closure

**Feature Branch**: `059-reviewer-mvp-gaps`
**Created**: 2026-04-22
**Status**: Draft
**Jira Epic**: [MTB-1458](https://mentalhelpglobal.atlassian.net/browse/MTB-1458)
**Input**: User description: "Close the remaining MVP implementation gaps for the Reviewer/Researcher flow documented in feature 058"

## Clarifications

### Session 2026-04-22 (Round 1)

Auto-answered (obvious / low-risk) by AI agent per owner standing
instruction:

- Q: Who can edit the inactivity-timeout value (FR-015)? → A: The
  same role surface that already owns the admin-settings block
  (Owner + Admin). No new RBAC scope is introduced; the edit is
  gated by the existing admin-settings permission.
- Q: What is the maximum propagation latency for a
  `space.membership_change` notification (FR-020 / SC-007)? → A: 60
  seconds end-to-end — matches the 058 in-app notification
  delivery model (notification write → next bell-poll cycle).

- Q: Canonical term for soft-deleted tags — `(retired)` vs
  `(deleted)` vs `(archived)`? → A: `(retired)` is the single
  canonical term used EVERYWHERE (chip prefix, tooltip, locale key,
  E2E assertion). 058 FR-021b `(deleted)` wording will be amended
  to `(retired)` in the spec-amendment PR.

- Q: Canonical Toggle component scope (FR-019) — settings-only or
  full Workbench sweep? → A: Settings-only. The new Toggle component
  replaces ONLY the toggles this feature introduces
  (`verbose_autosave_failures`, `inactivity_timeout_minutes`) PLUS
  the existing toggles on the Administrator and Reviewer Settings
  pages. Other Workbench surfaces are out of scope; they adopt the
  component organically in future features.

- Q: Cold-tier Audit Log restore affordance (FR-026) — stub
  button, real async endpoint, or defer entirely? → A: Defer
  entirely. This feature covers only hot (0–12 months) and warm
  (12–36 months) tiers plus the >60-month purge. The cold archive
  tier (36–60 months) and its restore-request affordance are
  deferred to the infra track.

All clarification questions resolved — ready for `/speckit.plan`.

## Context and Background

Feature 058 (Reviewer / Review Queue MVP) shipped the core rating / tagging
/ flagging / reports flow. A post-deployment audit against
`specs/058-reviewer-review-queue/spec.md` identified a set of
requirements that are partially implemented or missing entirely. A small
subset of 058 requirements has been deliberately superseded by explicit
owner decisions ("spec deviations") and those are NOT in scope for this
feature — they are tracked separately for a spec-wording update.

This feature closes the real gaps so every 058 FR either has a
shipping implementation or a documented owner-approved deviation.

### Out-of-scope owner deviations (tracked separately)

These four items intentionally diverge from 058 wording because the
owner reaffirmed the deviation on dev after seeing the implementation:

1. **058 FR-009b (page size 25)** — shipping with page size 12 (matches
   the responsive 1/2/3/4-col grid evenly).
2. **058 FR-009a (badge always unfiltered)** — active-tab badge now
   reflects the filtered list total (matches the paginator footer
   "Показано X of Y").
3. **058 FR-002 (Settings only in avatar dropdown)** — Settings is
   also reachable from the sidebar on dev.
4. **058 FR-046f (mobile = read-only)** — mobile rating / tagging /
   Red Flag / Submit remain usable (owner explicitly rejected the
   read-only gate on dev).

These four will be captured in a spec-amendment PR on 058; no
implementation work is done for them in this feature.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Submit never races an offline queue flush (Priority: P1)

As a Reviewer who loses connectivity mid-review, I want the Submit
button to clearly tell me that the queue is still draining and to stay
locked until the very last queued save has acked, so I never Submit on
top of a stale server state.

**Why this priority**: This is a correctness gate. Without it a
Reviewer can click Submit during the replay window and the server
commits the review with the OLD last-known values; the post-replay
writes then land as isolated audit events with no user-visible effect.
058 SC-013d demands a dedicated E2E test for this path, and 058 FR-018a
already describes the exact pattern (`⟳ Submit (3)` with a live count).
The current build shows a static "Submit Review" label and defers the
gating to a separate sentence below the button.

**Independent Test**: Simulate offline while typing a score + comment +
criterion, reconnect, observe the Submit label count down from `⟳
Submit (3)` → `⟳ Submit (1)` → `Submit` (enabled), confirm the
finalised row matches the last locally-typed values, not the
pre-offline snapshot.

**Acceptance Scenarios**:

1. **Given** the offline queue has 3 pending writes and all FR-018
   gating conditions are otherwise satisfied, **When** the ping
   endpoint recovers and replay starts, **Then** the Submit button
   stays disabled and its label reads `⟳ Submit (3)`.
2. **Given** the replay is in progress, **When** each queued request
   acknowledges, **Then** the parenthesised count decrements in real
   time (3 → 2 → 1).
3. **Given** the queue reaches zero AND all FR-018(a..d) conditions
   still hold, **When** the last ack lands, **Then** the spinner
   disappears, the label reverts to plain `Submit`, and the button
   becomes enabled.
4. **Given** the queue is currently empty and the button is enabled,
   **When** a new ping failure enqueues another write, **Then** the
   button flips back to disabled with the `⟳ Submit (N)` label.

---

### User Story 2 - Soft-deleted tags show a clear "retired" marker (Priority: P1)

As a Reviewer revisiting a Completed session, I need to see at a glance
which tags were retired by an administrator after I attached them —
otherwise I cannot tell a currently-valid tag from a grandfathered one.

**Why this priority**: This is an audit / legibility invariant the
spec (058 FR-021b) pins explicitly, and it is currently missing on the
Tag chip components. Supervisors and Master users rely on the same
rendering on the read-only session view; without it they may mistake a
retired tag for an active signal and route incorrectly.

**Independent Test**: Soft-delete a tag that is already attached to a
session, open the session as the Reviewer who attached it, confirm the
chip renders a `(retired)` prefix and hovering shows the administrator
+ retirement date tooltip.

**Acceptance Scenarios**:

1. **Given** the tag `Anxiety` is attached to a message by the current
   Reviewer, **When** the administrator soft-deletes `Anxiety`,
   **Then** the chip on the message MUST render `(retired) Anxiety`
   within the next fetch cycle (≤ 60 seconds per FR-008a).
2. **Given** a soft-deleted tag chip is rendered, **When** the
   Reviewer hovers the chip, **Then** the tooltip MUST read "This tag
   was retired by an administrator on [date]" localised to the active
   UI locale.
3. **Given** an existing soft-deleted attachment, **When** the
   Reviewer opens the selector, **Then** the tag MUST NOT appear as a
   selectable option (only existing attachments are preserved).

---

### User Story 3 - Loading / empty / error states are coordinated and localised (Priority: P1)

As a Reviewer looking at an empty Completed tab or a backend-down
Reports page, I want a clear, localised, consistent state with a
relevant vector illustration, a machine-readable error code, and an
explicit Retry or "clear filters" action, so I can either self-recover
or paste an error code into a support ticket.

**Why this priority**: Every Reviewer surface hits these three states
routinely; inconsistent treatment has been the #1 source of owner
feedback ("пусто без объяснения", "ошибка на английском"). 058
FR-046a..e are very specific about the composition. The current build
uses ad-hoc "empty"/"error" banners that vary per surface.

**Independent Test**: Clear every filter on a non-empty Pending tab so
the list goes empty → confirm the illustration + headline + CTA;
force a 503 on the Reports analytics endpoint → confirm error code
+ Retry + support link + console echo.

**Acceptance Scenarios**:

1. **Given** a fetch is in flight, **When** 200 ms elapse without a
   response, **Then** the area MUST render skeleton placeholders
   mimicking the final layout (no full-screen blocking spinner).
2. **Given** a filter combination that matches zero sessions, **When**
   the list resolves empty, **Then** the surface MUST show a
   centred vector illustration + localised headline + a "Clear
   filters" CTA that resets the active filters.
3. **Given** an analytics request fails with HTTP 503, **When** the
   error settles, **Then** the surface MUST show the error code
   (e.g., `REQ-503`), a localised description, a Retry button that
   re-runs the failed request, a support link, and the code MUST also
   be echoed to `console.error` for triage.
4. **Given** a state transition (loading → empty, empty → populated,
   loading → error), **When** the transition happens, **Then** the
   headline text region MUST be announced by screen readers via an
   `aria-live=polite` region (error state may upgrade to `assertive`).

---

### User Story 4 - Multi-tab edits don't silently overwrite (Priority: P1)

As a Reviewer who opened the same session in a second tab by accident,
I need the tab that just regained focus to gate its editor with a
brief skeleton while it reconciles with the server, so the other tab's
saves don't silently replace what I'm typing.

**Why this priority**: The current focus-refresh hook is intentionally
non-blocking; it refetches but never gates input. In practice the
Reviewer can type into a field after focus return, the refetch then
arrives, and per-field reconciliation silently overwrites their
untouched fields while leaving touched fields alone — the visible
"jump" is confusing and the overwrite goes un-announced. 058 FR-034a
specifies a full gate-snapshot-reconcile loop.

**Independent Test**: Open session A in two tabs, type in tab 1, blur;
switch to tab 2 and back to tab 1; observe tab 1 briefly shows a
skeleton overlay on the editor, refetches, and either preserves the
local buffer (if the Reviewer started typing after focus return) or
rewrites the field silently (if they did not) — visibly indicated on
each affected field.

**Acceptance Scenarios**:

1. **Given** a Reviewer returns focus to a tab that has the session
   open, **When** the tab regains focus (`visibilitychange`/`focus`/
   `pageshow`), **Then** the editor area MUST gate behind a skeleton
   or spinner overlay and fire a fresh full-session fetch
   immediately.
2. **Given** the fetch resolves with a server value that differs from
   the pre-focus snapshot AND the user has NOT typed in that field
   since focus return, **When** reconciliation runs, **Then** the
   field MUST be updated to the server value and render a small
   "Updated by another tab" inline indicator for a brief moment.
3. **Given** the fetch resolves with a server value that differs AND
   the user HAS typed in that field since focus return, **When**
   reconciliation runs, **Then** the local edit MUST be preserved and
   the field MUST render a small conflict indicator that surfaces the
   competing server value on hover.
4. **Given** the fetch resolves with identical values, **When**
   reconciliation runs, **Then** the DOM MUST be left untouched (no
   rewrite, no cursor jump).

---

### User Story 5 - Beforeunload confirmation is an explicit in-app modal (Priority: P2)

As a Reviewer about to press Back / close the tab while I still have
unsaved edits, I want an explicit in-app "Close and lose unsaved data
/ Stay on page" modal with localised copy, not the native browser
beforeunload dialog which cannot be localised or styled.

**Why this priority**: 058 FR-033 calls for the in-app modal. Today
only the native `beforeunload` (unstyled, browser-default text in
English) fires. This is a UX polish gap (lower than the correctness
gaps above) but lines up with the rest of the localised surface.

**Independent Test**: Start a rating with unsaved changes, press
`Cmd+W` / browser Back / refresh; confirm the custom modal with two
localised actions appears. Choosing "Stay on page" cancels the
navigation; choosing "Close and lose unsaved data" proceeds.

**Acceptance Scenarios**:

1. **Given** the Reviewer has unsaved autosave-pending edits, **When**
   they trigger navigation (back / refresh / tab close via the
   in-app Back button), **Then** a localised in-app modal with two
   actions MUST intercept the action before the native dialog.
2. **Given** the modal is visible, **When** the Reviewer chooses
   "Stay on page", **Then** the navigation MUST be cancelled and the
   editor MUST remain interactive.
3. **Given** the modal is visible, **When** the Reviewer chooses
   "Close and lose unsaved data", **Then** the navigation MUST
   proceed and any queued writes MUST still be flushed via the
   page-lifecycle `beforeunload` handler.

---

### User Story 6 - Inactivity timeout matches the spec (Priority: P2)

As a Reviewer left alone at my workstation, I want my session to end
after the administrator-configured inactivity timeout (default 30
minutes), with any unfinished draft still preserved on the server, so
a stolen-laptop scenario doesn't leak session access.

**Why this priority**: 058 FR-005 sets the default to 30 minutes and
requires admin configurability. The current default is 480 minutes (8
hours) and is only configurable via an environment variable, not via
the admin settings UI.

**Independent Test**: Sign in, wait out the timeout without any user
action, confirm the client redirects to login and that a freshly-typed
draft rating is still present after a fresh sign-in.

**Acceptance Scenarios**:

1. **Given** an administrator has not overridden the value, **When**
   a freshly-signed-in Reviewer leaves the UI idle, **Then** the
   session MUST terminate after 30 minutes and the UI MUST redirect
   to login.
2. **Given** a draft rating existed before the timeout, **When** the
   Reviewer re-authenticates and reopens the session, **Then** every
   previously-entered score / comment / criterion / validated answer
   MUST be restored.
3. **Given** an administrator changes the timeout in the admin
   settings UI, **When** a subsequent session starts, **Then** the
   new value MUST take effect without any code deploy.

---

### User Story 7 - Admin toggle controls autosave-failure toast verbosity (Priority: P2)

As an administrator debugging an autosave-flaky deployment, I want a
single Toggle in the admin settings UI that makes the Reviewer client
surface every transient save failure as a toast (OFF by default so
the Reviewer sees only persistent failures).

**Why this priority**: 058 FR-031c mandates exactly this toggle as
"the only piece of admin functionality in scope for 058 beyond the
parallel Tag Center dependency". It is missing today.

**Independent Test**: Toggle `verbose_autosave_failures` in admin
settings; induce a single 500 on a save; confirm that with the toggle
ON the Reviewer sees a toast after the first failure and with the
toggle OFF they see a toast only after the third (persistent)
failure.

**Acceptance Scenarios**:

1. **Given** `verbose_autosave_failures` is OFF, **When** a save
   request fails once with a transient 5xx and then succeeds on
   retry, **Then** the Reviewer MUST NOT see a toast.
2. **Given** the toggle is ON, **When** the same transient 5xx
   occurs, **Then** the Reviewer MUST see a toast announcing the
   retry.
3. **Given** the toggle is OFF, **When** the save fails three times
   in a row, **Then** the Reviewer MUST see a persistent-failure
   toast with the canonical Retry affordance.
4. **Given** the toggle control itself, **When** the administrator
   renders the setting, **Then** the Toggle MUST use the canonical
   design-system Toggle component (FR-031d) with its default OFF
   state in the system neutral-gray colour.

---

### User Story 8 - Notification system emits Space-membership events (Priority: P2)

As a Reviewer whose Space membership changed because a Master added or
removed me, I want to receive an in-app notification through the same
bell-and-banner surface that carries change-request decisions, so I
know my queue visibility just changed.

**Why this priority**: 058 FR-039b names three notification categories
that the system MUST support. Two (`change_request.decision`,
`red_flag.supervisor_followup`) are wired end-to-end; the third
(`space.membership_change`) is typed but not emitted. Without it, the
Reviewer only learns from the queue going quiet or filling up.

**Independent Test**: As a Master user, add the Reviewer to a new
Space; confirm the Reviewer's bell badge increments, the persistent
banner reads "You were added to Space X", and dismissing the banner
emits a `notification.read` audit entry.

**Acceptance Scenarios**:

1. **Given** a Master user adds the Reviewer to Space `X`, **When**
   the server processes the membership event, **Then** the Reviewer
   MUST receive an in-app notification with text "You were added to
   Space X" via both the banner and the bell list.
2. **Given** a Master user removes the Reviewer from Space `Y`,
   **When** the server processes the removal, **Then** the Reviewer
   MUST receive a matching "You were removed from Space Y"
   notification.
3. **Given** any notification from any of the three categories is
   dismissed, **When** the Reviewer clicks Dismiss, **Then** the
   action MUST write a single `notification.read` entry to the
   Audit Log with event-type, timestamp, Reviewer ID, and the
   notification payload reference.

---

### User Story 9 - Browser-prerequisite guard is explicit (Priority: P3)

As a Reviewer opening the Workbench from an ancient browser that lacks
IndexedDB or the page-lifecycle events the offline queue depends on, I
want a friendly full-page "Your browser is not supported" notice,
rather than a half-broken interface that silently drops my work.

**Why this priority**: 058 FR-046i is a low-traffic but high-cost path
(data loss on unsupported hardware). Implementation is a single
capability probe on app start.

**Independent Test**: Mock `window.indexedDB = undefined` before
mount, confirm the app renders the guard page instead of the normal
shell.

**Acceptance Scenarios**:

1. **Given** the browser is missing IndexedDB OR ServiceWorker OR
   `visibilitychange` support, **When** the Workbench loads, **Then**
   the UI MUST render a full-page localised notice naming the
   unsupported capability and recommending supported browsers
   (Chrome / Edge / Firefox / Safari, latest 2 major versions).
2. **Given** a soft-missing capability (e.g., the Notifications API
   on a tablet), **When** the Workbench loads, **Then** the UI MUST
   downgrade gracefully with an inline notice on the affected
   control and keep the rest of the surface functional.

---

### User Story 10 - Automated accessibility gate catches regressions (Priority: P3)

As a platform maintainer, I want automated axe-core validation on
every Reviewer-facing route inside the E2E suite, with a merge-block
on critical / serious violations, so accessibility doesn't quietly
regress.

**Why this priority**: 058 FR-047b ships WCAG AA as a hard gate. The
current E2E suite does not include axe-core; manual audits are
lossy.

**Independent Test**: Introduce a deliberate ARIA violation (missing
label on a score radio), run the E2E suite, confirm the suite fails
with the exact axe-core rule identifier and offending selector.

**Acceptance Scenarios**:

1. **Given** the E2E suite runs, **When** it visits any
   Reviewer-facing route (queue, session, reports, my-stats,
   settings), **Then** it MUST call axe-core and record every rule
   result.
2. **Given** the axe-core run reports a "critical" or "serious"
   violation, **When** the suite completes, **Then** the overall run
   MUST exit non-zero and the CI check MUST block the merge.
3. **Given** moderate / minor violations, **When** the suite
   completes, **Then** they MUST be surfaced as warnings in the CI
   report but MUST NOT block the merge.

---

### User Story 11 - Audit Log retention tiers and purge exist (Priority: P3)

As a security / compliance reviewer, I want the Audit Log to be
tiered (hot / warm) with an automated 5-year purge that honours
`legal_hold`, so the system meets the retention policy referenced in
058 FR-050a/b.

**Why this priority**: Infra-level change; necessary for release to
production but not a blocker for dev E2E. Ships the contract and the
purge job skeleton; the cold-archive tier is deferred to infra.

**Independent Test**: Seed synthetic audit rows spanning 0 / 15 / 48 /
66 months old; run the purge job; confirm rows > 60 months are
removed, a single purge-batch row is appended, and any row with
`legal_hold=true` is preserved.

**Acceptance Scenarios**:

1. **Given** a mix of audit rows with ages 0, 15, 48, 66 months,
   **When** the daily purge job runs, **Then** only rows older than
   60 months MUST be removed; rows in warm / hot tiers below
   60 months MUST be retained.
2. **Given** a purge run removes N rows, **When** the job finishes,
   **Then** exactly one new audit row of type `audit.purge` MUST be
   appended capturing the run sequence ID, the count N, and the time
   window covered.
3. **Given** any row carries `legal_hold = true`, **When** the purge
   runs, **Then** that row MUST be retained regardless of age.
4. **Given** the Audit Log UI is queried for a row in the warm tier,
   **When** the query resolves, **Then** the row MUST return with an
   elevated latency budget but through the same endpoint as hot-tier
   rows.

---

### Edge Cases

- **Submit gating flips mid-replay**: A new save is enqueued after the
  Submit button briefly became enabled — the UI must revert to
  `⟳ Submit (N)` without double-firing the submit handler.
- **Multi-tab reconciliation during offline mode**: Focus return
  while the ping is still failing — the snapshot / fetch / gate
  sequence MUST defer until ping recovers; the editor stays usable
  with the local buffer.
- **Soft-deleted tag restored**: After restore, the `(retired)`
  prefix MUST disappear on the next fetch cycle; the tag becomes a
  selectable option again.
- **Inactivity timeout during an active autosave**: The pending save
  MUST complete (or be requeued to IndexedDB) before the logout
  redirect.
- **Browser lacks IndexedDB but has ServiceWorker**: Guard page MUST
  appear (IndexedDB is required for the offline queue).
- **Axe-core run times out**: E2E MUST treat the timeout as a
  "serious" violation so CI still blocks.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The Submit button label MUST render as `⟳ Submit (N)`
  whenever the offline queue is non-empty, where `N` is the live count
  of unsynced requests; the label MUST revert to `Submit` when the
  queue reaches zero and all other gating conditions are met.
- **FR-002**: The Submit button MUST stay disabled any time `N > 0`,
  irrespective of the other FR-018(a..d) gating conditions.
- **FR-003**: The live count in the Submit label MUST expose its
  decrementing value through an `aria-live=polite` region for screen
  reader users.
- **FR-004**: A tag chip whose underlying tag definition has
  `deleted_at` set MUST render a localised `(retired)` prefix (or
  equivalent locale affordance) before the tag name.
- **FR-005**: Hovering a retired-tag chip MUST show a tooltip
  "This tag was retired by an administrator on [date]" in the active
  UI locale; the date MUST be rendered in the locale's standard
  short-date format.
- **FR-006**: Retired tags MUST NOT appear in any tag selector
  (Clinical or Review); existing attachments are preserved as
  read-only audit artefacts.
- **FR-007**: Every data area on every Reviewer-facing surface
  (Pending, Completed, individual session, Reports, My Stats,
  Notification bell list, Settings) MUST render the loading state as
  skeleton placeholders within 200 ms of a fetch starting; no
  full-screen blocking spinner is permitted.
- **FR-008**: Every empty state MUST render a centred composition
  containing a flat vector illustration (`aria-hidden=true`), a
  localised headline (the accessible name), an optional supporting
  paragraph, and an optional contextual CTA (e.g., "Clear filters"
  when an active filter is the cause).
- **FR-009**: Every error state MUST render a centred composition
  containing a flat error illustration, a machine-readable error code
  (e.g., `REQ-503`), a localised description, a Retry button that
  re-runs the failed request, and a link to support; the error code
  MUST also be written to `console.error` for triage.
- **FR-010**: Every loading / empty / error state transition MUST be
  announced via `aria-live=polite` on the headline region; the error
  state MAY upgrade to `aria-live=assertive`.
- **FR-011**: On every tab-focus event (`visibilitychange`, `focus`,
  `pageshow`) on a Reviewer session view, the client MUST:
  (a) capture an in-memory snapshot of every editable field value at
  focus return; (b) fire a full session fetch; (c) gate the editor
  with a skeleton / spinner overlay that blocks input until the
  response arrives; (d) reconcile per field (preserve local edits if
  the user started typing, silently rewrite otherwise); (e) lift the
  overlay.
- **FR-012**: Multi-tab reconciliation MUST NOT introduce any backend
  lock; the authoritative state remains the backend store.
- **FR-013**: When the Reviewer triggers navigation (close, refresh,
  back, internal route change) with unsaved autosave-pending edits,
  the client MUST present an in-app localised modal with two
  actions ("Close and lose unsaved data" / "Stay on page") before
  the native `beforeunload` dialog.
- **FR-014**: Choosing "Stay on page" MUST cancel the navigation;
  choosing "Close and lose unsaved data" MUST proceed with the
  navigation after flushing all pending writes via the
  page-lifecycle handler.
- **FR-015**: The inactivity timeout default MUST be 30 minutes and
  MUST be exposed in the admin settings UI as an editable value
  (reuse of the canonical Toggle / number-input primitives).
- **FR-016**: Administrator changes to the inactivity timeout MUST
  take effect for every subsequent session without a code deploy
  and MUST be recorded as an Audit Log entry with old and new
  values.
- **FR-017**: The Reviewer UI MUST redirect to the login page when
  the inactivity timeout elapses; every in-memory draft MUST be
  flushed or queued before the redirect.
- **FR-018**: A boolean admin setting `verbose_autosave_failures`
  (default OFF) MUST be added to the admin settings UI as a
  canonical Toggle control. When OFF, only persistent save failures
  (after the third retry) surface a toast. When ON, every failed
  save attempt surfaces a toast.
- **FR-019**: A canonical design-system Toggle component MUST be
  introduced (or formalised if a suitable component already exists)
  and adopted by the toggles this feature introduces
  (`verbose_autosave_failures`, `inactivity_timeout_minutes`) PLUS
  every existing Toggle on the Administrator and Reviewer Settings
  pages. Other Workbench surfaces are out of scope for this feature.
  The default OFF state MUST render in the system neutral-gray
  colour.
- **FR-020**: The backend notification service MUST emit a
  `space.membership_change` event whenever a Master user adds a
  Reviewer to a Space or removes them from one; the payload MUST
  carry the Space name, the change direction ("added"/"removed"),
  and the timestamp.
- **FR-021**: The Reviewer client MUST render every
  `space.membership_change` notification through both the
  persistent top banner and the bell-icon list, with
  locale-localised copy.
- **FR-022**: Every Dismiss action on any notification (from any of
  the three canonical categories) MUST write a single audit entry
  of type `notification.read` carrying the Reviewer ID, timestamp,
  notification category, and notification payload reference.
- **FR-023**: On Workbench first load, the client MUST probe
  capability support for IndexedDB, ServiceWorker,
  `addEventListener('visibilitychange')`, and
  `addEventListener('pageshow')`. Missing any of these capabilities
  MUST present a full-page localised "Your browser is not
  supported" notice.
- **FR-024**: Soft-missing capabilities (e.g., the Notifications
  API on a tablet) MUST NOT trigger the full-page notice; instead
  the affected control MUST render an inline localised downgrade
  notice and the rest of the surface MUST remain fully functional.
- **FR-025**: The Playwright E2E suite MUST call axe-core on every
  Reviewer-facing route on every run; the suite MUST exit non-zero
  whenever axe-core reports a `critical` or `serious` violation;
  `moderate` / `minor` violations MUST be logged as warnings but
  MUST NOT block the merge.
- **FR-026**: The Audit Log MUST expose two storage tiers — hot
  (0–12 months) and warm (12–36 months) — with a single
  consumer-facing query endpoint that transparently routes to the
  appropriate tier. The cold archive tier (36–60 months) and its
  restore-request affordance are deferred to the infra track and
  are out of scope for this feature.
- **FR-027**: An automated purge job MUST remove audit rows older
  than 60 months on a daily schedule; every purge run MUST append
  exactly one audit row of type `audit.purge` capturing the run
  sequence ID, the removed-row count, and the time window.
- **FR-028**: The purge job MUST honour a per-row `legal_hold`
  boolean flag and exclude flagged rows regardless of age; the
  `legal_hold` column MUST exist as a pass-through field in the
  schema (no UI required in this feature).
- **FR-029**: The Reviewer's Pending tab MUST refresh the X / Y
  counter on tab-focus return (the same `visibilitychange` trigger
  already used on the session view).
- **FR-030**: When the administrator decreases the required reviewer
  count in the admin settings, the backend MUST re-evaluate every
  in-flight Pending session where X >= Y_new and auto-complete the
  ones that satisfy the new threshold on the next refresh cycle; the
  change event MUST be emitted to the existing refresh-on-action
  model (not only on submit).
- **FR-031**: The Supervisor notification email that fires on submit
  of a Red Flag-containing session MUST include a per-reply link
  (deep-link to the specific message) in addition to the session
  link.

### Key Entities

- **Offline op row (IndexedDB-backed)**: the existing per-request
  queue row gains no new columns in this feature; it already carries
  `attempts` and `lastError` from feature 058.
- **Admin setting `verbose_autosave_failures`**: boolean, default
  `false`, persisted in the existing admin-settings row.
- **Admin setting `inactivity_timeout_minutes`**: integer, default
  `30`, bounded `[5, 480]`, persisted in the existing admin-settings
  row.
- **Notification category `space.membership_change`**: new event
  type reusing the existing `review_notifications` table columns (no
  schema migration required beyond adding a new enum value).
- **Audit row `legal_hold` column**: boolean, default `false`, added
  to the existing `audit_log` table as a pass-through field.
- **Audit row storage tier**: a logical classification (hot / warm)
  computed from `created_at`, not a separate column. Cold tier is
  deferred to the infra track.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of Reviewer E2E tests that exercise the
  offline-queue drain land a Submit whose finalised row equals the
  post-replay local buffer (no "saved old snapshot" race).
- **SC-002**: 0 cases in a 50-session synthetic run where a
  Reviewer's tag chip renders without the `(retired)` marker after
  the tag is soft-deleted (propagation latency ≤ 60 seconds).
- **SC-003**: 100% of Reviewer surfaces render a skeleton within
  200 ms of the first fetch; 0 surfaces render a full-screen
  blocking spinner.
- **SC-004**: 100% of error states expose a machine-readable code
  and a Retry action; 0 surfaces expose a bare error message with
  no recovery affordance.
- **SC-005**: 0 silent overwrites of Reviewer-typed values during a
  multi-tab reconciliation E2E sweep; every rewrite or conflict is
  visibly indicated.
- **SC-006**: The inactivity timeout admin setting round-trips
  (UI edit → persisted → next session enforces new value) in ≤ 1
  minute.
- **SC-007**: A membership change on any Space the Reviewer
  belongs to surfaces a notification through both banner and bell
  within 60 seconds.
- **SC-008**: Every Dismiss event on every notification category
  writes exactly one matching audit row (0 missing, 0 duplicates)
  in a 100-dismissal synthetic run.
- **SC-009**: The CI run blocks on every critical / serious
  axe-core violation on every Reviewer-facing route; a deliberate
  ARIA regression introduced to the score radio fails the build.
- **SC-010**: The purge job removes 100% of eligible audit rows
  older than 60 months, preserves 100% of rows marked
  `legal_hold=true`, and writes exactly one `audit.purge` audit row
  per run.
- **SC-011**: 0 Reviewer surfaces silently crash on a browser that
  lacks IndexedDB; 100% of affected loads render the capability
  guard page.
- **SC-012**: The Submit button has an `aria-live=polite` region
  that announces the decrementing count at least once per
  acknowledged queued request during a replay E2E.

## Assumptions

- The canonical design-system Toggle component does not exist yet;
  this feature introduces it rather than adopting an external
  library.
- The admin settings UI already hosts an "Administrator" section
  (058 / dev shows this today); this feature adds two new entries
  (`verbose_autosave_failures` and `inactivity_timeout_minutes`)
  without restructuring the section.
- The existing `useFocusRefresh` hook on the session view is the
  right scaffold to extend for FR-011; no new hook is introduced.
- The cold-archive tier (36–60 months) and its restore-request
  affordance are deferred entirely to the infra track. This feature
  covers only hot (0–12 months) and warm (12–36 months) tiers plus
  the >60-month purge job.
- axe-core 4.x is compatible with the existing Playwright E2E
  harness; introduction is a pure dev-dependency addition plus a
  helper function.
- The `space.membership_change` event does NOT require a new
  endpoint; it reuses the existing `review_notifications` write path
  with a new category string.
- The per-reply deep link for the Red Flag email (FR-031) reuses
  the existing session-detail fragment anchor convention already
  generated by the frontend router.

## Out of Scope

- Any change to 058 FR-009b (page size), 058 FR-009a (badge
  semantics), 058 FR-002 (Settings location), or 058 FR-046f
  (mobile read-only) — these four deviations are captured in a
  separate spec-amendment PR on the 058 feature folder, not here.
- Cold-archive tier (36–60 months), its object-storage backend, and
  its restore-request affordance (infra track).
- Reveal-on-demand PII workflows for Supervisor / Master roles
  (explicitly reserved by 058 FR-047e as a separate feature).
- Mobile editing surfaces (session editing on < 768 px remains per
  the owner's post-spec deviation on 058 FR-046f).
- Any new RBAC role introduction; all changes stay within the
  existing Researcher / Supervisor / Master / Owner / Admin matrix.
- Translations to new locales beyond the existing uk / ru / en set.

## Dependencies

- Feature 058 (Reviewer / Review Queue) must be on `develop` — all
  gaps in this feature assume the 058 baseline is live.
- The parallel Tag Center extension (for soft-delete rendering on
  chips) must expose a `deleted_at` attribute on tag definition
  payloads.
- Playwright E2E harness must be upgraded to include axe-core 4.x
  (dev-dependency only).
- The canonical Toggle component introduced by this feature is a
  prerequisite for any new Toggle in future features.

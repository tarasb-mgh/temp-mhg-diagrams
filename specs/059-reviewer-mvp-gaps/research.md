# Research: Reviewer MVP Gap Closure

**Feature**: `059-reviewer-mvp-gaps`
**Date**: 2026-04-22
**Phase**: Phase 0 — Outline & Research

This document records the technical decisions taken during Phase 0 for the
059 gap-closure feature. Inputs: `spec.md` (with all clarifications resolved),
058 `plan.md` + `data-model.md` + `research.md`, the MHG constitution v3.15.0,
and a live codebase audit across `workbench-frontend`, `chat-backend`,
`chat-frontend-common`, and `chat-ui` (2026-04-22).

---

## Decision 1 — Submit button countdown UX

- **Decision**: Modify the existing inline Submit button in
  `ReviewSessionView.tsx` to render `⟳ Submit (N)` with a live
  decrementing count when `pendingOfflineCount > 0`. The count is sourced
  from the existing `offlineQueue` store. The button stays disabled any
  time `N > 0` (FR-001, FR-002). An `aria-live=polite` region wraps the
  label for screen reader announcements (FR-003).
- **Rationale**: The Submit button already disables on
  `pendingOfflineCount > 0` with a separate amber line. Converting this
  to the `⟳ Submit (N)` label pattern is a localised change with no new
  component — the existing disabled/enabled toggle remains, only the
  label rendering changes.
- **Alternatives considered**:
  - Extracting a `<SubmitButton>` component — deferred; the inline
    approach matches the current codebase pattern and avoids a
    refactor scope creep.

## Decision 2 — Soft-deleted tag rendering

- **Decision**: Extend the existing `TagChip` and `ClinicalTagPicker`
  components to check `tag.deleted_at`. When set, render a localised
  `(retired)` prefix on the chip and show a tooltip with the retirement
  date. The tag selector filters `WHERE deleted_at IS NULL`. The
  canonical term is `(retired)` everywhere (per clarification Q1).
- **Rationale**: The `deleted_at` column already exists in both
  `clinical_tag_defs` and `review_tag_defs` (058 migration). The
  backend already returns it in the tag definition payload. Only
  frontend rendering logic is missing.
- **Alternatives considered**: None — straightforward rendering gap.

## Decision 3 — Canonical loading / empty / error state components

- **Decision**: Create three shared components under
  `workbench-frontend/src/components/states/`:
  `LoadingSkeleton.tsx`, `EmptyState.tsx`, `ErrorState.tsx`. Each follows
  the composition rules in FR-007..010 (skeleton within 200ms, vector
  illustration + headline + CTA, error code + Retry + support link,
  `aria-live` announcements). Adopt them across all Reviewer surfaces:
  ReviewQueueView, ReviewSessionView, ReportView, ReviewDashboard,
  NotificationBellList, SettingsView.
- **Rationale**: The codebase audit found only feature-local partial
  implementations (`DashboardEmptyState`, inline skeleton in
  `ReviewQueueView`). A shared set eliminates inconsistency and
  satisfies FR-007..010 + SC-003/004 in one pass.
- **Alternatives considered**:
  - Per-surface custom states — rejected (spec explicitly demands
    consistency; owner feedback cited "пусто без объяснения" as #1
    issue).

## Decision 4 — Multi-tab reconciliation gate

- **Decision**: Extend the existing `useFocusRefresh` hook to implement
  the full gate-snapshot-reconcile loop (FR-011). On
  `visibilitychange`/`focus`/`pageshow`: (a) capture a snapshot of
  every editable field, (b) show a skeleton overlay blocking input,
  (c) fire a fresh full-session fetch, (d) per-field reconciliation
  (preserve local if user typed after focus return, rewrite with
  indicator if not, conflict indicator if both differ), (e) lift
  overlay. No new hook — extend `useFocusRefresh`.
- **Rationale**: The hook already fires on the right events and
  refetches. It currently never gates input; adding the overlay + snapshot
  + reconciliation is an extension, not a rewrite.
- **Alternatives considered**:
  - New `useMultiTabReconciliation` hook — rejected (unnecessary
    duplication; the existing hook is the right scaffold per spec
    assumption).

## Decision 5 — In-app beforeunload modal

- **Decision**: Create an `UnsavedChangesModal` component that intercepts
  in-app navigation (React Router `useBlocker`) with a localised
  two-action dialog ("Close and lose unsaved data" / "Stay on page").
  Keep the native `beforeunload` as a fallback for actual tab close /
  refresh (cannot be replaced by a custom modal per browser security).
  The modal fires for in-app Back button, sidebar navigation, and
  `react-router` route changes. FR-013/014.
- **Rationale**: The codebase has two `beforeunload` handlers
  (`useBeforeUnloadGuard` + inline effect). The in-app modal supplements
  them for in-app navigation only — browser close/refresh still uses the
  native dialog. React Router v6 `useBlocker` is the standard mechanism.
- **Alternatives considered**:
  - Replacing all `beforeunload` with the modal — impossible for
    browser-initiated close/refresh.

## Decision 6 — Inactivity timeout admin configurability

- **Decision**: Add `inactivity_timeout_minutes` (integer, default 30,
  bounded [5, 480]) to the admin settings table and expose it via the
  existing `GET/PATCH /api/admin/settings` endpoints. The backend
  `sessionTimeoutCheck` middleware currently reads
  `SESSION_TIMEOUT_MINUTES` env var (default 480); change it to read the
  DB setting first, falling back to the env var. The frontend Settings
  admin section gains a number input for this value. Audit log entry on
  change (FR-016).
- **Rationale**: The middleware and the settings infrastructure both
  exist. The change is: (1) add the DB column/key, (2) read from DB in
  middleware, (3) add UI input. No new middleware or architecture.
- **Alternatives considered**: None — direct gap closure.

## Decision 7 — Verbose autosave failures admin toggle

- **Decision**: Add `verbose_autosave_failures` (boolean, default
  `false`) to the admin settings table via the existing
  `GET/PATCH /api/admin/settings` endpoints. The frontend reads this
  setting and controls toast display logic: OFF = toast only after 3rd
  consecutive failure; ON = toast on every failure (FR-018). The toggle
  in the admin Settings UI uses the canonical `Toggle` component from
  `chat-frontend-common` (FR-019).
- **Rationale**: The `Toggle` component already exists in
  `chat-frontend-common` (confirmed in audit). The Settings page
  currently uses custom `<button>` sliders — FR-019 requires replacing
  these with the canonical `Toggle` on both Admin and Reviewer Settings
  sections.
- **Alternatives considered**: None — direct gap closure with existing
  component.

## Decision 8 — Canonical Toggle adoption scope

- **Decision**: Replace the custom toggle buttons on the Settings page
  (Admin section: guest mode, OTP disable; Reviewer section:
  notification preferences) with the `<Toggle>` from
  `chat-frontend-common`. Add the two new toggles
  (`verbose_autosave_failures`, and potentially a toggle presentation
  for `inactivity_timeout_minutes` enable/disable if useful). Per
  clarification Q2: scope is Settings pages only, not full Workbench.
- **Rationale**: The `Toggle` exists, is exported, and has tests. The
  Settings page is the only surface with toggle-like controls for the
  Reviewer flow.

## Decision 9 — Space membership change notifications

- **Decision**: Extend `reviewNotification.service.ts` to emit a
  `space.membership_change` notification when a Master user
  adds/removes a Reviewer from a Space. The event is triggered from
  the existing Space membership CRUD endpoints (which already exist for
  group management). The payload carries `{spaceName, direction, timestamp}` per FR-020. Frontend renders via the existing bell +
  banner surface.
- **Rationale**: The notification table and the bell/banner rendering
  already exist from 058. Only the backend emission and the new
  notification category string are missing.
- **Alternatives considered**: None — straightforward wiring.

## Decision 10 — Browser capability guard

- **Decision**: Create a `BrowserCapabilityGuard` component that probes
  `window.indexedDB`, `navigator.serviceWorker`,
  `document.addEventListener('visibilitychange')`, and
  `document.addEventListener('pageshow')` on first render. If any are
  missing, render a full-page localised notice. Soft-missing
  capabilities (e.g., Notifications API) get inline downgrade notices
  on affected controls only (FR-023, FR-024).
- **Rationale**: No such guard exists today. IndexedDB failures are
  caught at the offline queue layer but not surfaced to the user
  proactively. A single guard component at the app shell level is the
  simplest approach.
- **Alternatives considered**:
  - Per-feature capability checks — rejected (fragmented, easy to
    miss a surface).

## Decision 11 — axe-core E2E integration

- **Decision**: Add `@axe-core/playwright` as a dev dependency to
  `chat-ui`. Create a shared `checkAccessibility(page)` helper that
  calls `injectAxe` + `checkA11y` with WCAG 2.1 AA rules. Each
  Reviewer-facing route test ends with this helper. Critical/serious
  violations fail the test (exit non-zero). Moderate/minor are logged
  as warnings. FR-025, SC-009.
- **Rationale**: `chat-ui` has no axe-core today. The Playwright
  integration is standard and adds ~50 KB to dev dependencies only.
- **Alternatives considered**:
  - axe-core in Vitest (jsdom) — rejected (DOM fidelity too low for
    real accessibility testing).

## Decision 12 — Audit log retention tiers and purge

- **Decision**: This feature covers hot (0–12 months) and warm (12–36
  months) tiers only. Cold tier is deferred to infra (per
  clarification Q3). The tier is a logical classification computed from
  `created_at`, not a separate column — query-time `CASE` expression.
  The warm tier uses the same Postgres table with an elevated latency
  budget (acceptable for dev). A daily purge job (Node.js scheduled
  task in `chat-backend`, not a Cloud Run Job for MVP) removes rows
  older than 60 months, respects `legal_hold`, and appends an
  `audit.purge` row. FR-026..028, SC-010.
- **Rationale**: 058 `data-model.md` specifies a `tier` column but the
  migration already has `legal_hold`. For MVP, a logical tier
  computation + a simple cron job is sufficient without GCS Parquet
  infrastructure. The purge job runs as a `setInterval` in the backend
  process (same pattern as `expireOldSessions`).
- **Alternatives considered**:
  - Cloud Run Job — deferred to infra track (over-engineered for dev
    tier).
  - Postgres partitioning by month — valuable but not required for
    the logical tier model; can be added later.

## Decision 13 — Pending tab focus refresh

- **Decision**: Extend `ReviewQueueView` to call `useFocusRefresh` so
  the X/Y counter and queue list refresh on tab focus return (FR-029).
  Same hook used by the session view, now also on the queue view.
- **Rationale**: The hook exists and is wired in the session view. Adding
  it to the queue view is a single line.

## Decision 14 — Auto-completion on reviewer count decrease

- **Decision**: Extend the existing `recomputeCompletion` pattern from
  058 (triggered on settings change) to re-evaluate all in-flight
  Pending sessions when the admin decreases `required_reviewer_count`
  (FR-030). Sessions where `completed_reviewer_count >= new_required`
  are auto-completed. The event emits to the existing refresh-on-action
  model.
- **Rationale**: 058 `research.md` Decision 11 already describes this
  hook. The gap is that it's not fully wired — the admin settings
  PATCH endpoint doesn't call it.

## Decision 15 — Red Flag email deep link

- **Decision**: The Supervisor notification email for Red Flag sessions
  gains a per-message deep link using the existing fragment anchor
  convention `#message-{messageId}` (FR-031). The email template
  already exists; add the anchor URL alongside the session URL.
- **Rationale**: The frontend router already supports fragment anchors on
  the session detail page. The email template just needs the extra link.

---

## Open items deferred to implementation

- Vector illustrations for empty/error states: use a minimal inline SVG
  set (3–4 illustrations) committed to
  `workbench-frontend/src/assets/illustrations/`. Design system tokens
  for illustration colours.
- Exact `useBlocker` API shape depends on React Router version in
  `workbench-frontend` (v6.4+ required for `useBlocker`); if older,
  use `unstable_useBlocker` or `<Prompt>` shim.
- Notification email template modification (FR-031) requires access to
  the email service template directory — verify path during
  implementation.

---

All `[NEEDS CLARIFICATION]` markers from spec.md have been resolved through
the 2 prior `/speckit.clarify` rounds and Phase 0 decisions above. No
outstanding clarifications block Phase 1.

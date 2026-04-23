# Quickstart: Reviewer MVP Gap Closure (059) — Validation Guide

**Feature**: `059-reviewer-mvp-gaps`
**Date**: 2026-04-22
**Phase**: Phase 1 — Design & Contracts

This guide walks an engineer or AI agent through verifying every gap
closure introduced by 059. Prerequisite: feature 058 is fully deployed
on dev.

---

## Prerequisites

- Access to `https://workbench.dev.mentalhelp.chat` (Workbench dev).
- Access to `https://api.dev.mentalhelp.chat` (Backend dev API).
- Test accounts:
  - `e2e-researcher@test.local` (canonical Reviewer).
  - A second Reviewer account in the same Space.
  - A Master account (for Space membership change tests).
  - An Administrator account (for admin settings tests).
- Playwright MCP registered in `regression-suite/_config.yaml`.
- The `chat-types`, `chat-backend`, `workbench-frontend`, and
  `chat-frontend-common` repos on branch `059-reviewer-mvp-gaps`.

---

## 1. Submit button countdown (US-1, FR-001..003)

1. Sign in as the Reviewer. Open a session and start rating.
2. In DevTools → Network, throttle to **Offline**.
3. Make 3 changes (score + comment + criterion). Observe the Submit
   button label changes to `⟳ Submit (3)` and stays disabled.
4. Restore network. Watch the count decrement: `(3)` → `(2)` → `(1)` →
   plain `Submit` (enabled).
5. **Screen reader check**: enable VoiceOver / NVDA; confirm the
   decrementing count is announced via `aria-live=polite`.
6. Confirm the finalised review row on the server matches the
   post-replay local buffer (not the pre-offline snapshot).

---

## 2. Soft-deleted tag "retired" marker (US-2, FR-004..006)

1. As an Administrator, navigate to Tag Center → Clinical Tags.
2. Soft-delete a tag (e.g., `Anxiety`) that is already attached to a
   session by the Reviewer.
3. As the Reviewer, open the session. Confirm the chip renders
   `(retired) Anxiety`.
4. Hover the chip. Confirm the tooltip reads "This tag was retired by
   an administrator on [date]" in the active UI locale.
5. Open the tag selector. Confirm `Anxiety` does NOT appear as a
   selectable option.
6. Restore the tag (un-delete). Confirm the `(retired)` prefix
   disappears on the next fetch cycle and the tag is selectable again.

---

## 3. Loading / empty / error states (US-3, FR-007..010)

### Loading (skeleton)
1. Throttle network to Slow 3G. Navigate to Review Queue.
2. Confirm skeleton placeholders appear within ~200ms (no full-screen
   spinner).
3. Repeat for: session detail, Reports, My Stats, Settings.

### Empty state
1. Apply a date range filter that matches zero sessions.
2. Confirm: centred vector illustration + localised headline + "Clear
   filters" CTA.
3. Click "Clear filters" — filters reset, list repopulates.

### Error state
1. In DevTools → Network, block `*/api/review/reports/analytics*`.
2. Navigate to Reports.
3. Confirm: error illustration + error code (e.g., `REQ-0`) + localised
   description + Retry button + support link.
4. Confirm the error code appears in `console.error`.
5. Unblock the endpoint, click Retry — data loads.

### Accessibility
1. Enable VoiceOver / NVDA. Navigate to an empty state.
2. Confirm the headline region is announced via `aria-live=polite`.
3. Force an error. Confirm the announcement (may be `assertive`).

---

## 4. Multi-tab reconciliation gate (US-4, FR-011..012)

1. Open session A in tab 1 and tab 2.
2. In tab 1, type a comment on message M1 and blur (autosave fires).
3. Switch to tab 2. Observe:
   - Brief skeleton overlay gates the editor.
   - After fetch resolves, M1 field updates to the server value with
     a small "Updated by another tab" indicator.
4. In tab 2, focus M2 and start typing `local edit`.
5. In tab 1, type a different value for M2 and blur.
6. Re-focus tab 2. Observe:
   - Skeleton overlay appears.
   - M2 field preserves the local edit and shows a conflict indicator
     (hover to see the server value).
7. Identical values: confirm no DOM rewrite, no cursor jump.

---

## 5. In-app beforeunload modal (US-5, FR-013..014)

1. Start rating a session with unsaved changes.
2. Click the in-app Back button (or sidebar link to Review Queue).
3. Confirm a localised modal appears: "Close and lose unsaved data" /
   "Stay on page".
4. Click "Stay on page" — navigation cancelled, editor stays.
5. Click Back again → "Close and lose unsaved data" — navigation
   proceeds.
6. For actual tab close / `Cmd+W` / refresh: confirm the native
   `beforeunload` dialog still fires (cannot be replaced).

---

## 6. Inactivity timeout (US-6, FR-015..017)

1. As Administrator, navigate to Settings → Admin.
2. Find the "Inactivity timeout" number input. Confirm default is 30
   (minutes).
3. Change to 5 minutes. Save. Confirm audit log entry with old/new
   values.
4. As the Reviewer, sign in. Wait 5+ minutes without interaction.
5. Confirm redirect to login page.
6. Sign in again, reopen the session. Confirm all draft values are
   preserved.
7. Reset timeout to 30 minutes.

---

## 7. Verbose autosave failures toggle (US-7, FR-018..019)

1. As Administrator, navigate to Settings → Admin.
2. Find the `verbose_autosave_failures` toggle. Confirm it uses the
   canonical `Toggle` component (neutral-gray OFF state).
3. Toggle ON. In DevTools → Network, block one autosave request to
   simulate a single 500.
4. As the Reviewer, blur a field (autosave fires). Confirm a toast
   appears immediately (first failure).
5. Toggle OFF. Repeat. Confirm NO toast on first failure. Confirm toast
   appears only after 3rd consecutive failure.
6. Confirm ALL toggles on the Settings page (Admin + Reviewer sections)
   use the canonical `Toggle` from `chat-frontend-common`.

---

## 8. Space membership notifications (US-8, FR-020..022)

1. As Master, add the Reviewer to a new Space.
2. As the Reviewer, check the bell badge — should increment.
3. Check the persistent banner — should read "You were added to
   Space X" (localised).
4. Click Dismiss on the banner.
5. Verify the audit log contains a `notification.read` entry with
   the correct category and payload.
6. As Master, remove the Reviewer from the Space.
7. Verify "You were removed from Space X" notification appears.

---

## 9. Browser capability guard (US-9, FR-023..024)

1. In DevTools → Console, run `delete window.indexedDB` then reload.
2. Confirm a full-page localised "Your browser is not supported" notice.
3. Restore (remove override, reload). Confirm normal UI.
4. For soft-missing (e.g., Notifications API on a tablet): confirm an
   inline notice on the bell control, rest of UI functional.

---

## 10. axe-core E2E gate (US-10, FR-025)

1. In `chat-ui`, run the Reviewer E2E suite.
2. Confirm each Reviewer-facing route (queue, session, reports,
   my-stats, settings) calls axe-core.
3. Introduce a deliberate ARIA violation (e.g., remove a label from a
   score radio).
4. Run the suite. Confirm it exits non-zero with the exact axe-core
   rule identifier.
5. Remove the violation. Confirm the suite passes.

---

## 11. Audit log retention tiers and purge (US-11, FR-026..028)

1. Seed synthetic audit rows spanning 0, 15, 48, 66 months old (via
   a test endpoint or direct DB insert in dev).
2. Trigger the purge job (or wait for the daily schedule).
3. Confirm:
   - Rows > 60 months are removed.
   - Rows with `legal_hold = true` are preserved regardless of age.
   - Exactly one `audit.purge` row is appended with `runSequenceId`,
     `removedCount`, and time window.
4. Query a warm-tier row (12–36 months old). Confirm it returns through
   the same endpoint (may have elevated latency).

---

## Validation completion criteria

- 100% of the 12 checks above pass on dev.
- 0 `console.error` messages unrelated to the test (e.g., no 404s, no
  unhandled rejections).
- 0 axe-core critical/serious violations on any Reviewer route.
- Audit log contains entries for all new event types introduced.
- All toggles on Settings use the canonical `Toggle` component.
- The canonical term `(retired)` appears correctly on soft-deleted tags.

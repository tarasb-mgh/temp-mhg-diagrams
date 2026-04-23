# Quickstart: Reviewer Review Queue (058) — Local & Dev Validation

**Feature**: `058-reviewer-review-queue`
**Date**: 2026-04-16
**Phase**: Phase 1 — Design & Contracts

This guide walks an engineer or AI agent through reproducing the Reviewer happy path end-to-end against the dev environment, plus all isolation and edge-case checks. It is the single canonical "how do I verify the feature works" entrypoint.

---

## Prerequisites

- Access to `https://workbench.dev.mentalhelp.chat` (Workbench dev frontend).
- Access to `https://api.dev.mentalhelp.chat` (chat-backend dev API).
- Two test Reviewer accounts:
  - `e2e-researcher@test.local` (canonical Reviewer fixture, listed in `regression-suite/_config.yaml` as `researcher`).
  - A second Reviewer account in the same Space (used for cross-Reviewer isolation and X / Y counter freshness tests).
- A Supervisor / `moderator` test account for end-to-end change-request and Red Flag follow-up tests.
- An Expert test account for clinical-tag fan-out tests.
- Local dev tooling:
  - Node 20+ with pnpm 9+.
  - The `chat-types`, `chat-backend`, and `workbench-frontend` repositories cloned at sibling paths.
  - `chat-frontend-common` cloned (for the canonical `<Toggle>` and design-system tokens).
  - Playwright MCP server registered in this repository (already provisioned per `regression-suite/_config.yaml`).

---

## Bring-up sequence (first-time)

1. Pull the latest `chat-types` `develop` branch and run `pnpm install && pnpm build` so workbench-frontend and chat-backend pick up the new entity shapes (Section 3+ of `data-model.md`).
2. Apply the chat-backend migration that adds `language_group`, `description`, and `deleted_at` to `clinical_tag_defs` and `review_tag_defs`; adds `legal_hold` and `tier` to `audit_log_entries`; and creates the new tables `clinical_tag_attachments`, `review_tag_attachments`, `message_tag_comments`, `red_flags`, `reviews`, `ratings`, `change_requests`, and `notifications`.
3. Confirm the Tag Center UI renders the new language-group control (parallel feature dependency); existing tags now display `language_group = ["uk"]` by default.
4. Toggle the `feature.reviewer_review_queue_v2` flag ON in the dev backend AND frontend env (Decision 20 in `research.md`). Default OFF in dev until end-to-end smoke passes.
5. Trigger a workbench-frontend dev deploy via `gh workflow dispatch deploy.yml --field environment=dev --field branch=058-reviewer-review-queue` (constitution Principle IV requires dev validation from feature branches).
6. Verify the deploy completes green; navigate to `https://workbench.dev.mentalhelp.chat` in an incognito window and sign in as `e2e-researcher@test.local`.

---

## Manual happy path — single Reviewer (US-1, US-2, US-3)

Mirrors `spec.md` US-1, US-2, US-3 acceptance scenarios.

1. **Sign-in**: enter email + password; obtain the OTP from browser console (`Code: NNNNNN` per `regression-suite/_config.yaml`); enter the OTP; arrive on `/workbench/review`.
2. **Sidebar check (US-7 AC2)**: confirm only `Review Queue` and `Reports` are present; no other module entries.
3. **Pending tab (US-1 AC0, US-3 AC0)**:
   - Confirm chip filter bar above the list with `NEW`, `REPEAT`, `UNFINISHED` chips (FR-009a).
   - Confirm paginator with `Prev / Next + numbered pages` (FR-009b).
   - Confirm language filter renders as checkbox group with per-language counts (FR-009c).
4. **Open a NEW session**: click any session card labelled `NEW`. The session detail loads with masked transcript (FR-047c). Verify NO PII leaks in the rendered DOM, the network response payload, or the browser console (privacy CHK020).
5. **Rate every assistant reply ≥ 8 (US-1 AC1)**: pick score 9 on each, type a short free-text comment, leave the criterion empty. Submit becomes enabled. Click `Submit`; confirm the session moves to `Completed`.
6. **Rate one reply with score < 8 (US-1 AC2)**: open another NEW session, set one assistant reply to score 5 with NO criterion. Submit MUST stay disabled. Pick a criterion (e.g., `empathy`), type the criterion comment, type a validated answer. Submit becomes enabled.
7. **Tooltip check (US-1 AC4)**: hover over each of the 10 score dots; tooltip text appears and is in the user's UI locale, not the chat language (FR-002a + i18n CHK008).
8. **Add a Clinical Tag (US-3 AC1, AC2, AC3)**: add `Anxiety` to one user reply. The per-message tag comment field appears below the reply (FR-022). Add `Depression` to a DIFFERENT reply — a new tag comment field appears below THAT reply (independent). Add `PTSD` on the SAME reply as `Anxiety` — no second comment field appears (FR-022 message + Reviewer scope).
9. **Add a Red Flag (US-3 AC3, AC4, AC5)**: click Red Flag on an assistant reply. Modal opens with a mandatory description field. Submit-modal-only confirm fires; Red Flag chip appears on the reply. Try to leave the page without finalising — the FR-027 obligation prevents leaving with the flag standing alone (autosave preserves it but no email is sent yet per EC-01).
10. **Submit the full session (US-1 AC1, US-3 AC5)**: confirm the URGENT label appears on the card in `Completed`, and a Supervisor email is dispatched (verifiable via the Supervisor inbox or via the test inbox endpoint).

---

## Manual happy path — change request flow (US-4)

1. From `Completed`, open the session you finalised in step 6 above. Confirm read-only state (US-4 AC1).
2. Click `Request changes` → modal with mandatory reason (US-4 AC2). Submit.
3. Status indicator updates to `Awaiting supervisor decision` (US-4 AC3).
4. Sign in as the Supervisor; navigate to the change-request inbox; click Approve.
5. Sign back in as the Reviewer. Confirm the persistent banner + bell-badge unread (FR-039a). Click Dismiss; banner clears; the Audit Log gains a `notification.read` entry.
6. Confirm the session is back in `Pending` with the `REPEAT` label (US-4 AC4).
7. Re-rate the session and submit again. Confirm the previous canonical Review is now `superseded` and the repeat is canonical (US-4 AC6).

---

## Manual happy path — autosave + offline mode (US-2)

1. Start rating a session; type a comment; tab away from the field (blur fires autosave per FR-031).
2. In DevTools → Network, set throttling to `Offline`. Type more text; observe the warning banner appears within seconds: `Working offline — your changes will sync when the connection returns` (FR-031b). Submit becomes disabled and renders `⟳ Submit (N)` with the count incrementing as you make changes (FR-018a).
3. Restore network. Confirm the queue replays in original order, the banner clears, the success toast `All offline changes synced` appears, and `Submit` returns to plain enabled state once the queue reaches zero (EC-12, SC-013d).

---

## Manual happy path — multi-tab reconciliation (US-2 + EC-19, EC-20)

1. Open the same session in tab A and tab B.
2. In tab A, type a comment on assistant reply M1 and blur to autosave.
3. Focus tab B; observe the brief gating overlay; the M1 field updates to the server value with the inline `Updated by another tab` indicator (EC-19).
4. In tab B, focus the comment field on assistant reply M2 and start typing `preserved here`.
5. In tab A, save a different value `saved earlier` for M2 (blur).
6. Re-focus tab B; the gating overlay appears; the focus-fetch returns the server value, but because tab B is actively editing M2, the local value is preserved with a small inline conflict indicator surfacing the competing value on hover (EC-20).
7. Blur M2 in tab B; the local value wins on the server (last-write-wins for that field).

---

## Manual cross-Reviewer isolation (US-6 + SC-013a)

1. Sign in as Reviewer A; rate a session with a Clinical Tag and a Red Flag.
2. Sign in as Reviewer B (different account, same Space); open the same session.
3. Confirm Reviewer B does NOT see Reviewer A's rating, tag (Clinical Tags are per-Reviewer per FR-023), or Red Flag (FR-030).
4. Confirm a direct API call as Reviewer B with the URL pointing at Reviewer A's data returns 403 (US-6 AC2, AC3).

---

## Reports validation (US-5)

1. Sign in as Reviewer A; navigate to `Reports`.
2. Confirm only the period filter is rendered — no performer filter is in the DOM (US-5 AC2 + Round-3 Q5 clarification).
3. Pick a 30-day period; confirm 6 KPI cards are shown (Total Sessions, Reviewed, Pending, Comments Written, Tags Applied, Red Flags Raised) and values match Reviewer A's actual activity in that window (US-5 AC1, AC3).
4. Confirm Throughput Trend chart is present (bar chart, sessions completed per week or per day).
5. Confirm Sessions by Status visual breakdown is present with all 4 statuses (Pending / Unfinished / Completed / Red Flag).
6. Confirm NO quality metrics appear (no score distribution, no average score trend, no criteria breakdown — these live on My Stats).
7. Confirm there is NO export / download control in this section (US-5 AC4 + FR-046).

---

## Responsive validation (FR-046f, SC-013l)

1. Resize browser to 1280 px → desktop layout with full sidebar; happy path completes.
2. Resize to 768 px (tablet portrait) → collapsible sidebar, single-column cards; happy path completes; touch targets ≥ 44 × 44 px.
3. Resize to 360 px (mobile portrait) → Pending and Completed lists render in stacked card mode; opening a session shows the centred prompt `Best used on a tablet or desktop — switch to a wider device to rate this session` instead of the editor (FR-046f).

---

## Accessibility validation (FR-047a/b, SC-013g)

1. Run `npx @axe-core/cli https://workbench.dev.mentalhelp.chat/workbench/review` after sign-in (or use the Playwright MCP injected axe). Confirm zero `critical` and zero `serious` violations on every Reviewer-facing route.
2. Verify keyboard-only navigation completes the full happy path (Tab, Shift+Tab, Enter, Space, Esc).

---

## Audit Log validation (NF-03, SC-013q)

1. As `Master` or `Administrator`, navigate to `Security → Audit Log`. Confirm entries appear within ~1 minute of the actions performed above:
   - `login.success`, `login.failed` (verify by entering a wrong OTP in a fresh sign-in attempt)
   - `rating.created`, `rating.updated`
   - `clinical_tag.attached`, `clinical_tag.detached`
   - `red_flag.raised`, `red_flag.cleared`
   - `change_request.sent`, `change_request.approved`
   - `notification.read`
   - `review_settings.required_count_changed` (after toggling Required reviewer count from 2 to 3 then back)
   - `tag.soft_deleted`, `tag.restored`
2. Confirm no UI / API path allows editing or deleting entries (FR-050).

---

## E2E suite execution

The canonical machine-runnable validation lives in `regression-suite/19-reviewer-review-queue.yaml` and is generated as part of the Implementation phase. To run:

```bash
# Smoke (P0, ≤ 10 min):
mhg.regression module:19-reviewer-review-queue level:smoke

# Standard (P0+P1, ≤ 30 min):
mhg.regression module:19-reviewer-review-queue level:standard

# Full (P0+P1+P2, ≤ 60 min):
mhg.regression module:19-reviewer-review-queue level:full
```

The runner uses Playwright MCP, captures console / network errors per the suite-wide `error_signatures` rules in `_config.yaml`, and writes results to `regression-suite/results/`.

---

## Validation completion criteria (gates this quickstart against the spec)

- 100% of acceptance scenarios across US-1..US-8 pass manually (SC-001).
- 0 cross-Reviewer leak observations (SC-004).
- E2E module passes 3 consecutive runs immediately before merge (SC-005).
- Audit Log contains entries for every category listed above (SC-006).
- 0 axe-core critical / serious violations across the smoke run (SC-013g).
- 0 PII leaks observed in DOM / network / console / Playwright traces (SC-013p).
- Reports volume KPIs match the Reviewer's own activity; no quality charts present (SC-004 reinforcement).

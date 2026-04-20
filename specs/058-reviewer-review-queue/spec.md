# Feature Specification: Reviewer Review Queue — Full Implementation and E2E Validation

**Feature Branch**: `058-reviewer-review-queue`
**Created**: 2026-04-16
**Status**: Draft
**Jira Epic**: [MTB-1449](https://mentalhelpglobal.atlassian.net/browse/MTB-1449)
**Jira Stories**: US-1 [MTB-1450](https://mentalhelpglobal.atlassian.net/browse/MTB-1450) · US-2 [MTB-1451](https://mentalhelpglobal.atlassian.net/browse/MTB-1451) · US-3 [MTB-1452](https://mentalhelpglobal.atlassian.net/browse/MTB-1452) · US-4 [MTB-1453](https://mentalhelpglobal.atlassian.net/browse/MTB-1453) · US-5 [MTB-1454](https://mentalhelpglobal.atlassian.net/browse/MTB-1454) · US-6 [MTB-1455](https://mentalhelpglobal.atlassian.net/browse/MTB-1455) · US-7 [MTB-1456](https://mentalhelpglobal.atlassian.net/browse/MTB-1456) · US-8 [MTB-1457](https://mentalhelpglobal.atlassian.net/browse/MTB-1457)
**Input**: User description: "Full implementation and E2E validation of the Review Queue functionality for the Reviewer (Researcher) role per MHG Workbench MVP Requirements v0.1-draft (section 3.3 — US-03..US-08, US-16, NF-01..NF-05 in the part applicable to the Reviewer). Context: the 2026-04-16 audit on workbench.dev.mentalhelp.chat found that the Reviewer Review Queue is only partially implemented — critical UI elements are missing, tab labels do not match the spec, data isolation is not enforced, and there is no E2E coverage."

## Clarifications

### Session 2026-04-16

- Q: 2FA strategy across environments (and impact on E2E coverage) → A: Dev/staging uses email OTP delivered via browser console (existing infrastructure, including the dedicated E2E account `e2e-researcher@test.local`); Prod uses TOTP authenticator app. The E2E suite consumes the console OTP path on dev only.
- Q: Are the 8 evaluation criteria hard-coded or admin-configurable? → A: Hard-coded set of 8 criteria with stable, immutable IDs; labels are i18n-localized; no admin CRUD in this feature (configurability remains explicitly out of scope).
- Q: How are primary and repeat ratings represented after an approved change request? → A: The repeat rating is canonical for analytics and the current Supervisor view; the primary rating is marked `superseded` and remains available in a per-session "version history" panel for the Supervisor (read-only, audit only).
- Q: How does the Reviewer filter Pending sessions by sub-label (NEW / REPEAT / UNFINISHED)? → A: Single Pending list with a horizontal chip-bar filter supporting multi-select over NEW / REPEAT / UNFINISHED; the Pending tab badge keeps showing the total count. No nested sub-tabs.
- Q: How is the performer filter rendered on Reports for the Reviewer role? → A: Hidden completely from the DOM (least-information principle); the server always fixes performer = current user. The Reviewer sees only the period filter and never any indication that other performers exist.

### Session 2026-04-16 (Round 2)

- Q: How does the Review Queue behave at scale (large Pending lists)? → A: Server-side pagination with a fixed page size of 25; UI renders Prev/Next plus numbered pages; chip-filter and date-filter are applied server-side; Pending tab badge keeps showing the total unfiltered count across all pages.
- Q: Can the Reviewer edit or delete tags and Red Flags before submit? → A: Yes — before submit the Reviewer may delete their own tag or Red Flag and may edit the description/comment of either. Each create / update / delete is recorded in the Audit Log as a separate event. After submit, both tags and flags become read-only along with the rest of the review.
- Q: How are in-app notifications to the Reviewer (change-request decisions, etc.) presented? → A: Persistent top-of-page banner that stays visible until explicit acknowledge (Dismiss button); a bell icon in the header carries an unread badge; every acknowledge is recorded in the Audit Log as a notification-read event.
- Q: How is localization handled for Reviewer's tag-selection and queue browsing? → A: Each Chat Session carries a `language` attribute matching the language of the underlying conversation (uk/ru/en, with a dynamically extensible locale list). Each Clinical Tag carries a `language_group` attribute (one or more locale codes); when a Reviewer opens a session, only tags whose `language_group` covers the session's `language` are offered. Review Queue exposes a multi-select language filter sourced live from the backend (only locales currently present in the Reviewer's queue, each with a session count); empty selection means "all languages"; filter changes always trigger a server fetch (no client caching); the filter persists for the browser session only. The same language-group model applies to Expert tags. Tag Center (admin CRUD) MUST be extended via a parallel feature to add the `language_group` attribute on every clinical tag (existing tags default to `uk`), with admin UI rendering two-letter locale badges next to each tag's edit controls and opening a small dropdown over the dynamic locale list — that parallel feature is a hard dependency for 058.
- Q: How does the system handle autosave failures and what triggers a save? → A: Maximum state lives on the backend. Saves are event-driven, fired on every input `blur` (including the page-unload / app-close lifecycle event so the last in-progress field is flushed). On every save attempt the client distinguishes two failure modes via a backend `ping` endpoint:
  (1) Full backend outage (ping fails): the UI enters offline mode — a persistent warning-coloured top banner reads "Working offline — your changes will sync when the connection returns"; pending changes are queued in IndexedDB and replayed once ping succeeds; final Submit is blocked while offline.
  (2) Transient single-request failure (ping OK, individual save returned 4xx/5xx): the client retries with exponential backoff (2 s / 4 s / 8 s); if `verbose autosave failures` admin setting is ON, every failure fires a toast notification; if OFF (default), only persistent failures after the third retry surface a toast.
  Verbose autosave failures is a single Administrator-managed boolean setting (default OFF, gray Toggle) that ships with this feature. The toggle MUST use the canonical design-system Toggle component; if no canonical Toggle exists yet, this feature creates one and all future toggles MUST reuse it (no proliferation of one-off toggle components).
- Q: Is the clinical-tag comment per-session or per-tagged-message? → A: Per-tagged-message. Every message that carries one or more clinical tags from the same Reviewer MUST have its own dedicated tag comment; Submit MUST stay disabled until every tagged message has a non-empty tag comment alongside every other required field (this overrides the earlier "single session-level shared tag comment" model that came from the original MVP draft).

### Session 2026-04-16 (Round 3)

- Q: How are chat sessions assigned to Reviewers? → A: Assignment is Space-driven, not per-Reviewer push. Every Reviewer is a member of one or more Spaces; every chat user (and therefore every chat session) belongs to exactly one Space. When a chat session ends it is automatically routed into the Review Queue of that user's Space; every Reviewer who is a member of that Space sees it in their queue (subject to the language and status filters and the Space dropdown selection). The Space dropdown in the header lists ONLY the Spaces the current Reviewer is a member of, plus an "All Spaces" pseudo-option that means "union of all my Spaces" (never the system-wide set). Reviewers cannot view, request, or join other Spaces from the Workbench. No Administrator or Supervisor intervention is required to populate a Reviewer's queue.
- Q: What language does the Reviewer UI itself use, and how do Review Tags relate to Clinical Tags? → A: The Reviewer UI (sidebar, criteria labels, score tooltips, paginator, banners, errors) follows the user-selected locale chosen in the header locale switcher (mirrored in Settings); default = browser locale, fallback = en. Tag selectors are the only exception: BOTH Clinical Tags and Review Tags are filtered and displayed in the chat session's language for clinical/organisational consistency. Review Tags are organisational labels attached at session level, also managed in Tag Center, and also carry a `language_group` attribute — the Tag Center extension (parallel feature dependency) MUST use the SAME canonical two-letter-badge + dropdown component for Clinical Tag and Review Tag language assignment (no separate implementations). Differences between the two tag families are kept minimal: Review Tags have NO expert-assignment property (so the expert-assignment UI MUST be hidden for them); both families have a `description` field surfaced as a hover tooltip on every tag chip in the Reviewer UI.
- Q: How does Submit behave during the recovery window between ping success and full offline-queue replay? → A: Submit stays disabled until the offline queue is fully drained. During the replay window the button label shows a spinner glyph plus the live count of unsynced requests in parentheses, e.g., "⟳ Submit (3)" → "⟳ Submit (1)" → "Submit" (enabled) once the queue reaches zero. This pattern gives the Reviewer immediate visual feedback that sync is in progress, makes the count of pending writes inspectable, and prevents any race between Submit and a still-pending save.
- Q: Which notification categories are in scope for the Reviewer in 058? → A: Three categories — (a) change-request decisions (approve/reject) authored by the Supervisor (FR-038/FR-039); (b) Supervisor commentary or follow-up on a Red Flag the Reviewer raised; (c) Space membership change events ("You were added to Space X" / "You were removed from Space Y"). All three flow through the canonical banner + bell-badge surface (FR-039a) and emit a `notification.read` Audit Log entry on Dismiss. UNFINISHED reminders, system maintenance announcements, and any other categories are out of scope for 058 and may be picked up by later features without changing the notification subsystem contract.
- Q: How fresh must the X / Y review-progress counter on session cards be when multiple Reviewers in the same Space rate concurrently? → A: Refresh-on-action with a 60-second background polling safety net. The counter is refetched every time the Reviewer performs an action that materially changes context (open queue, switch tab, switch Space, paginate, apply or clear any filter, focus the browser tab after blur) AND every 60 seconds as a background safety net. When the Reviewer opens an individual session for rating, the counter is refetched fresh as part of the session-detail load. Real-time push (WebSocket / SSE) is explicitly out of scope for 058 and may be revisited later if concurrency intensifies; client-side optimistic increment is also out of scope to keep the value authoritative.

### Session 2026-04-16 (Round 4)

- Q: What accessibility conformance level must the Reviewer UI meet? → A: WCAG 2.1 Level AA across every user-facing UI element introduced or modified by 058 (sidebar, locale switcher, Space dropdown, queue tabs, chip filters, language filter, paginator, session cards, transcript, score selector, criterion selector, validated answer field, tag selectors and chips, Red Flag modal, autosave/offline banners, bell-icon notification list, persistent banner, Submit button with countdown). Automated checks via axe-core / lighthouse run as part of the E2E suite; any critical or serious violation reported by axe-core blocks merge.
- Q: What pattern do empty / loading / error states use across the Reviewer UI? → A: For every list / data area (Pending tab, Completed tab, Reports charts, Expert Assessments queue surface) the Reviewer UI MUST render the following coordinated states. Loading: skeleton placeholders mimicking the final layout, appearing within 200 ms of fetch start; no full-screen blocking spinner. Empty: a centred state composed of a simple flat vector illustration matching the situation (e.g., empty inbox, all-caught-up checkmark, sad-cloud for errors), a contextual headline ("No sessions to review yet — new chats from your Spaces will appear here automatically", "All caught up! No pending sessions in [Space]", etc.), an optional supporting paragraph, and a CTA when applicable. Error: a centred state with an error-themed flat vector illustration, the specific error code, a human-readable description, a "Retry" CTA, and a link to support. All three states use `aria-live=polite` so screen readers announce transitions; illustrations are decorative (`aria-hidden=true`) so they do not duplicate the message.
- Q: What happens to existing tag attachments when the Administrator deletes a tag from Tag Center? → A: Soft-delete model. The tag is marked `deleted_at` in Tag Center but never physically removed. New attachments become impossible (the tag disappears from Reviewer-facing selectors immediately on the next fetch). Existing attachments (in drafts and completed reviews) are preserved untouched for audit; in the Reviewer UI they render with a visible prefix "(deleted)" on the chip, and the hover tooltip reads "This tag was retired by an administrator on [date]". For Clinical Tags, soft-deletion stops expert-routing for any session that becomes tagged AFTER the deletion timestamp; sessions tagged before deletion continue routing as before. Soft-delete and any subsequent restore (clearing `deleted_at`) MUST emit Audit Log entries.
- Q: How does a change to the Required reviewer count in Review Settings apply to in-flight sessions? → A: Forward-only for non-completed sessions. Sessions that have already met the OLD completion threshold and are in supervision / Completed remain unaffected. Sessions still in Pending (X strictly less than the OLD threshold) immediately switch to using the NEW threshold for completion: if the count is increased (Y_new > Y_old), sessions with X already at Y_old keep waiting until X reaches Y_new; if decreased (Y_new < Y_old), sessions with X >= Y_new are auto-completed on the next refresh and routed to supervision per the normal flow. There is no retroactive reopening of completed reviews and no cohort-based snapshot — the rule applies live to the open queue.
- Q: What happens when the Reviewer opens the same session in two browser tabs? → A: Multi-tab is allowed for the same Reviewer on the same session — neither tab becomes hard read-only — but the tabs reconcile via a focus-fetch + smart field-level merge. On every tab-focus event (the tab regains focus after losing it), the tab fires a fresh server fetch for the session state and briefly blocks the editing surface (skeleton / spinner overlay) until the response arrives. On response, the client compares each field against a local snapshot taken at the very moment the user returned to the tab: (a) if the server value differs from the snapshot AND the user has not typed in that field since focus, the field is updated to the server value; (b) if the user has already started editing a field since focus, the local edit is preserved untouched (no overwrite); (c) if the server value equals the snapshot, the DOM is left untouched (no cursor jump from no-op rewrite). Fields are never permanently locked — only briefly gated during the focus-fetch round-trip.

### Session 2026-04-16 (Round 5)

- Q: What is the responsive / PWA scope for the Reviewer Review Queue? → A: Desktop and tablet (viewport width ≥ 768 px) MUST be fully supported — every Reviewer-facing function works at full fidelity. Mobile (viewport < 768 px, down to 360 px portrait) is best-effort: the Pending and Completed lists, Reports charts, and notification bell render in a read-only mobile layout suitable for triage and monitoring; the rating editor, tag selectors, Red Flag modal, and Submit flow surface a "Best used on a tablet or desktop — switch device to rate" notice instead of the editable surface. The Workbench shell remains PWA-installable (web app manifest, service worker for offline shell cache) reused from the existing workbench-pwa feature. Min supported viewport is 360 px wide (modern phone portrait).
- Q: Which browsers are officially supported? → A: Evergreen Chromium (Chrome, Edge), latest stable Firefox, latest stable Safari including Safari on iPadOS — for each browser the support window is the latest 2 major versions. IE11, legacy (non-Chromium) Edge, and any browser released more than 18 months ago are explicitly NOT supported. E2E coverage runs on Chromium and WebKit projects in Playwright; Firefox is covered by manual smoke + Lighthouse audits. Polyfills are minimised; modern APIs (IndexedDB, ServiceWorker, page-lifecycle events, `aria-live`, BroadcastChannel where used) are assumed available — feature-detection guards add a graceful "browser not supported, please update" message only when a hard prerequisite is absent.
- Q: What is the explicit performance budget for the Reviewer surfaces? → A: Extended budget covering all critical paths: (a) session-detail TTI ≤ 2.0 s desktop / ≤ 3.0 s tablet for a session of 16 messages; (b) autosave round-trip P95 ≤ 500 ms (request fire to server-ack); (c) focus-fetch reconciliation P95 ≤ 800 ms (multi-tab focus fetch from gating overlay show to dismiss); (d) chat transcript scroll sustains 60 FPS; (e) initial bundle (JS+CSS gzipped) for the Reviewer route ≤ 350 KB; (f) Core Web Vitals on the queue page LCP ≤ 2.5 s, CLS ≤ 0.1, FID ≤ 100 ms. Targets measured at the dev tier on representative hardware (desktop = standard developer laptop, tablet = iPad Air or equivalent). All numbers are P95 unless stated otherwise.
- Q: How is PII handled in the chat transcript shown to the Reviewer? → A: PII is always masked for the Reviewer role — non-negotiable, no toggle, no reveal-on-demand. The server-side PII detector (regex + NER) runs on every transcript fetch and replaces detected PII (names, emails, phone numbers, addresses, medical identifiers, dates of birth, geo-locations, employer / school references, etc.) with `[REDACTED:type]` placeholders BEFORE the payload reaches the Reviewer client. The Reviewer UI MUST NOT expose any "PII Masking" toggle, any "Click to reveal" affordance, any tooltip showing the original text, any deanonymisation control, or any console output of the unmasked payload. The PII Masking control visible in the dev Settings page is hidden / removed for the Reviewer role. Reveal-on-demand is reserved for higher-privilege roles outside the scope of 058 (Supervisor / Master) and is not built into the Reviewer surface in any form.
- Q: What is the retention policy for Audit Log entries? → A: 5 years total, tiered by storage temperature: hot (online, full-query latency) for the first 12 months; warm (online, slower-query) from 12 to 36 months; cold (archive tier, restore-on-request) from 36 to 60 months; automated purge after 60 months. Deletion is automated by an offline retention job that emits a single audit-log entry per purge batch (sequence ID + count + window) so the chain of custody remains verifiable. The 5-year window applies uniformly to every event category recorded by 058 (login success / fail, logout, rating create / update / delete, tag attach / detach, Red Flag raise / clear, change-request send, notification.read, settings change, tag soft-delete / restore, required-count change). Legal-hold flags can extend retention beyond 60 months on a per-record basis (out of scope for 058 but supported as a no-op pass-through field).

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Reviewer rates a brand-new session end-to-end (Priority: P1)

The Reviewer signs in to the Workbench, opens Review Queue, picks a NEW
session from the Pending tab, sequentially rates every assistant reply on the
1–10 scale, fills the mandatory criterion / comment / validated answer fields
when applicable, adds a clinical-tag-level session comment if any tag is
applied, and submits the review.

**Why this priority**: This is the core value flow of the product. Without a
structured way to rate a session, the platform delivers no value. All other
stories (tags, flags, re-review, reports) sit on top of this flow.

**Independent Test**: A Reviewer can complete the path "log in → open Review
Queue → pick a NEW session → rate every assistant reply → submit → see the
session in Completed" and receive a save confirmation, without using any of
the advanced features (tags, red flags, change requests).

**Acceptance Scenarios**:

0. **Given** the Reviewer is on the Pending tab with mixed-label sessions
   (NEW, REPEAT, UNFINISHED), **When** they tick the REPEAT chip in the
   filter bar, **Then** the list narrows to REPEAT sessions only while the
   Pending tab badge keeps showing the total unfiltered count; unchecking
   the chip restores the full list.
1. **Given** the Reviewer is logged in and the Pending tab shows at least one
   session labelled NEW, **When** the Reviewer opens it, rates every
   assistant reply with a score ≥ 8 without selecting a criterion, and
   submits, **Then** the session disappears from Pending, appears in
   Completed with the COMPLETED label, and every rated reply is marked
   "Rated".
2. **Given** the Reviewer rates a reply with a score < 8, **When** they
   leave the criterion blank, the criterion comment empty, or the "Validated
   answer" field empty, **Then** the "Submit Review" button stays disabled
   and the unfilled mandatory fields are visually flagged under the reply.
3. **Given** the Reviewer opened a session, **When** they have not rated
   every assistant reply yet, **Then** the "Submit Review" button stays
   disabled with the hint "Rate all messages".
4. **Given** the Reviewer rated a reply with score 7 and selected the
   "Empathy" criterion, **When** they hover or focus any of the 10 score
   dots, **Then** a tooltip with the matching score-level description is
   shown.

---

### User Story 2 — Reviewer resumes an unfinished review (Priority: P1)

The Reviewer started rating a session, partially filled scores, then exited
(closed the tab, lost connectivity, or was logged out by inactivity). On the
next sign-in the session is labelled UNFINISHED and the Reviewer continues
from the exact point they stopped, with no data loss.

**Why this priority**: Sessions can be long (up to 18 messages). The Reviewer
must not lose work. Without reliable autosave the product is unsuitable for
daily use.

**Independent Test**: Open a session, enter some scores, close the tab, come
back five minutes later — every score, tag, and red flag is still present
and the session is in Pending with the UNFINISHED label.

**Acceptance Scenarios**:

1. **Given** the Reviewer rated 2 of 4 replies in a session, **When** they
   close the browser tab and reopen it after one minute, **Then** the
   session is in Pending with the UNFINISHED label, and on reopening both
   scores are restored while the submit button stays disabled.
2. **Given** the Reviewer is actively rating a session and just typed a
   comment without leaving the field, **When** they refresh the page
   (F5), **Then** the page-unload flush (FR-031) sends the pending
   change to the backend AND a modal with two buttons "Close and lose
   unsaved data" and "Stay on page" is shown; choosing "Stay" returns
   to the same page with all entered data preserved (including the
   most-recent typed comment).
3. **Given** the Reviewer rated one reply, **When** the backend `ping`
   endpoint starts failing, **Then** within seconds a warning-coloured
   top banner reads "Working offline — your changes will sync when the
   connection returns", the Submit button becomes disabled, and the
   Reviewer can keep typing/clicking; once the backend recovers all
   queued changes replay in original order, a success toast confirms
   "All offline changes synced", and Submit becomes available again.
4. **Given** the Reviewer was auto-logged out by the inactivity timeout,
   **When** they sign in again, **Then** all their unfinished sessions are
   available in Pending with the UNFINISHED label, and on reopening the full
   draft (scores, criteria, comments, tags, flags) is restored.

---

### User Story 3 — Reviewer adds clinical tags and raises a Red Flag (Priority: P1)

While reviewing, the Reviewer notices clinical signals (e.g., anxiety,
depression) or a critical situation (e.g., suicidal ideation) and must mark
the session with the matching clinical tags and/or a Red Flag for downstream
expert review and supervision.

**Why this priority**: This is the safety and clinical-routing mechanism.
Without tags and flags, sessions don't reach the right expert and critical
situations don't reach the supervisor.

**Independent Test**: Open a session, add an "Anxiety" tag on one reply with
the mandatory session-level comment, raise a Red Flag on another reply with
a description, finalise the rating — verify that the tagged session shows up
in the matching Expert's queue and the flagged session shows up in the
Supervisor's Red Flag tab.

**Acceptance Scenarios**:

1. **Given** the Reviewer opened a session with no tags, **When** they click
   "Clinical tag" on a user reply and pick "Anxiety", **Then** a mandatory
   per-message "Tag comment" field appears directly under that reply;
   while it stays empty the Submit button is disabled (FR-018c); once
   filled, the tag attaches to the reply with a visible highlight.
2. **Given** the Reviewer added "Anxiety" on reply M1 with comment C1
   and wants to add "Depression" on a different reply M2, **When** they
   add the second tag, **Then** a NEW dedicated "Tag comment" field
   appears under M2 (independent of C1); Submit stays disabled until
   the M2 comment is also filled.
3. **Given** the Reviewer added "Anxiety" and "PTSD" on the SAME reply
   M1, **When** they fill comment C1 once, **Then** that one comment
   covers both tags on M1 (per-message, per-Reviewer scope); no second
   comment field appears for the second tag on M1.
4. **Given** the Reviewer is rating a session, **When** they click Red
   Flag on an assistant reply, **Then** a modal opens with a mandatory
   "Situation description" field; an empty description blocks
   confirmation; after confirmation the reply is marked with a red
   flag.
5. **Given** the Reviewer raised a Red Flag but did NOT submit the
   review, **When** one hour passes, **Then** Supervisors receive NO
   email notification and the session stays in this Reviewer's Pending
   (with the UNFINISHED label).
6. **Given** the Reviewer raised a Red Flag and submitted the full
   review, **When** they submit, **Then** the session receives the
   URGENT label and an email is sent to all Supervisors (Reviewer name,
   raise time, link to the session and to the specific reply).
7. **Given** Reviewer A raised a Red Flag in a session, **When**
   Reviewer B opens the same session, **Then** Reviewer B does not see
   A's flag and reviews the session as usual.
8. **Given** the Reviewer submitted a session with the "Anxiety" tag,
   **When** the session is closed, **Then** it appears in the queue of
   an Expert assigned to the "Anxiety" tag (verified via the
   corresponding role in E2E).

---

### User Story 4 — Reviewer requests changes after finalising a review (Priority: P2)

The Reviewer finalised a review but later realised they made a mistake. The
finalised review is read-only, but the Reviewer can send a change request to
the Supervisor for permission to edit. After the Supervisor decides, the
Reviewer is notified, and on approval re-rates the session; both ratings
are stored separately, with the repeat rating becoming the canonical version
and the primary rating marked `superseded`.

**Why this priority**: Quality-correction mechanism. Not blocking for first
launch but mandatory for long-term operation since errors are inevitable.

**Independent Test**: Finalise a review, open it from Completed, click
"Request changes", give a reason, send. Verify the request was sent (visible
in action log or email outbox). After Supervisor approval (via test
account), verify the session returns to Pending with the REPEAT label.

**Acceptance Scenarios**:

1. **Given** the Reviewer opened their own completed session from Completed,
   **When** they view it, **Then** all their ratings/criteria/comments/tags/
   flags are displayed but read-only (no edit controls).
2. **Given** the Reviewer is in a read-only session, **When** they click
   "Request changes", **Then** a form opens with a mandatory "Request
   reason" field and a "Send" button.
3. **Given** the Reviewer sent a change request, **When** they look at the
   session in Completed, **Then** they see a status indicator (e.g.,
   "Awaiting supervisor decision") on the card / page until a response.
4. **Given** the Supervisor approved the request, **When** the Reviewer
   signs in, **Then** they see a persistent top-of-page banner with the
   approval message plus a +1 unread badge on the header bell icon, and
   receive an email with the decision; clicking Dismiss on the banner
   removes it and emits a `notification.read` Audit Log entry; the
   session returns to Pending with the REPEAT label.
5. **Given** the Supervisor rejected the request, **When** the Reviewer
   signs in, **Then** they see the same persistent banner + bell-badge
   pair carrying the rejection reason and receive an email; the session
   stays in Completed with the COMPLETED label.
6. **Given** a session is back in Pending with the REPEAT label, **When**
   the Reviewer re-rates it and submits, **Then** the system stores the
   repeat rating as the canonical version (used for analytics and the
   current Supervisor view) and marks the primary rating `superseded` (kept
   only in the per-session version history available to the Supervisor for
   audit).

---

### User Story 5 — Reviewer reviews their own analytics in Reports (Priority: P2)

The Reviewer opens the Reports page and sees metrics for their own work
only (sessions, ratings, flags, average scores) over a chosen period. No
data of other Reviewers is visible; the performer filter is either absent
or locked to their own ID.

**Why this priority**: Helps the Reviewer track their own performance and
quality. Doesn't block the core rating flow but matters for self-management
and 1-on-1 meetings with the Supervisor.

**Independent Test**: Sign in as Reviewer, open Reports, pick a period,
verify the metrics shown match only this Reviewer's activity (e.g., the
session count matches Completed for the same period).

**Acceptance Scenarios**:

1. **Given** the Reviewer opened Reports, **When** they pick the last 30
   days, **Then** they see: session counts by status (Pending/UNFINISHED/
   Completed/RED FLAG), number of rated sessions, average score, number of
   comments, Score Distribution (1–10 bar chart), Average Score Trend
   (daily/weekly), and the count of Red Flags they raised.
2. **Given** the Reviewer is on Reports, **When** they look at filters,
   **Then** only the period (From/To) filter is rendered. No performer
   filter exists in the DOM (not disabled, not hidden via display:none —
   simply not emitted). No tooltip, placeholder, or hint mentions other
   performers or other roles.
3. **Given** the Reviewer rated 5 sessions in the chosen period, **When**
   they look at "Rated sessions", **Then** the value is exactly 5; no other
   Reviewer's sessions are counted.
4. **Given** the Reviewer is on Reports, **When** they view the page,
   **Then** there are no export/download controls in this section.

---

### User Story 6 — Cross-Reviewer data isolation (Priority: P1)

Reviewer A must not see any data of Reviewer B: no sessions from another
queue, no ratings/tags/flags/comments authored by another Reviewer in shared
sessions, no analytics, no reports. This must hold not only in the UI but
also at the API level — direct requests to another Reviewer's data must be
blocked.

**Why this priority**: Foundational requirement for security and
confidentiality of clinical assessments. Without it, the principle of
independent rating is broken and personal/clinical information may leak.

**Independent Test**: Sign in as Reviewer A, rate a session with a tag and a
comment. Then sign in as Reviewer B, open the same session (if in their
queue) — verify A's rating/tag/comment are invisible. Also issue a direct
API request as Reviewer B for resources owned by Reviewer A — receive an
access error.

**Acceptance Scenarios**:

1. **Given** Reviewer A rated session X, **When** Reviewer B opens session X
   from their queue, **Then** they see it as "empty" (no A's ratings/tags/
   flags) and can rate it from scratch.
2. **Given** Reviewer A is signed in, **When** they manually change the
   session ID in the URL to a session not assigned to them, **Then** they
   get an access-denied page (403 / Not Found) and no data leak.
3. **Given** Reviewer A is signed in, **When** an API client or direct
   request reaches a resource holding Reviewer B's data (their rating, flag,
   tag), **Then** the server returns an access error regardless of UI state.
4. **Given** Reviewer A opens Reports, **When** they view the data, **Then**
   no sessions/ratings/flags of Reviewer B are present in the totals
   (counters match A's activity only).

---

### User Story 7 — Minimal interface with 2FA (Priority: P2)

The Reviewer signs in via 2FA on every new session and sees a sidebar with
only two navigation entries: Review Queue and Reports. No other modules
(Surveys, People & Access, Security, Group resources, Expertise, Agents,
Review Dashboard, Team Dashboard, Review Settings) are visible. The user
profile sits in the account-icon dropdown.

**Why this priority**: UX cleanliness and least-privilege. The Reviewer
should not see entries they cannot use — it lowers cognitive load and
shrinks the attack surface.

**Independent Test**: Sign in as Reviewer and screenshot the sidebar —
verify it contains only Review Queue and Reports; the account-icon
dropdown shows Settings and Sign Out.

**Acceptance Scenarios**:

1. **Given** the Reviewer is on the login page, **When** they enter email
   and password, **Then** they are forwarded to the 2FA step. On dev/staging
   the OTP is delivered via browser console; on prod a TOTP authenticator
   code is required. Without a valid code login is impossible.
2. **Given** the Reviewer signed in, **When** they look at the sidebar,
   **Then** only Review Queue and Reports are present. None of the other
   modules (Surveys, People & Access, Security, Group resources, Expertise,
   Agents, Review Dashboard, Team Dashboard, Review Settings) is rendered.
3. **Given** the Reviewer clicks the account icon in the top-right corner,
   **When** the dropdown opens, **Then** they see Settings and Sign Out;
   the user profile is reachable from here, not from the main navigation.
4. **Given** the Reviewer was inactive for N minutes (configured by the
   Administrator, default 30 minutes), **When** the timeout fires, **Then**
   they are auto-logged out and redirected to login; on next sign-in any
   unfinished review draft is preserved.

---

### User Story 8 — Audit logging of every Reviewer action (Priority: P3)

Every Reviewer action (creating/changing a rating, adding/removing a tag,
raising/clearing a Red Flag, sending a change request, successful and
failed sign-ins, sign-outs) is recorded in the Audit Log with timestamp,
user, role, IP, target. The log is available only to Administrators and
Masters and is not editable (append-only).

**Why this priority**: Compliance and incident investigation. Doesn't block
Reviewer functionality, but is mandatory for production release and
GDPR/internal-policy compliance.

**Independent Test**: The Reviewer performs five distinct actions (rate,
tag, flag, change request, sign-out). The Administrator opens Audit Log
and sees at least 5 corresponding entries within the time window.

**Acceptance Scenarios**:

1. **Given** the Reviewer performed an action (e.g., rated a reply),
   **When** the Administrator opens Audit Log within a minute, **Then**
   they see an entry with event type, user ID, role, timestamp and IP.
2. **Given** an Audit Log entry exists, **When** the Administrator tries to
   edit or delete it, **Then** the operation is blocked (no UI/API for
   modification or deletion).
3. **Given** the Reviewer entered the wrong password or OTP, **When** the
   sign-in attempt fails, **Then** an entry is added to the Audit Log for
   the failed login attempt.

---

### Edge Cases

- **EC-01 (Red Flag without finalize)**: The Reviewer raises a Red Flag but
  does not finalise the review — no email is sent to Supervisors until the
  Reviewer submits the whole session.
- **EC-02 (Two independent Red Flags)**: Reviewer A and Reviewer B
  independently raise Red Flags in the same session; both flags are kept as
  separate events with their own authors, timestamps and descriptions.
- **EC-03 (Multiple tags across messages)**: The Reviewer adds several
  different clinical tags spread over multiple messages in one session
  — every tagged message gets its OWN dedicated tag comment (per
  FR-022); the session appears in the queue of every Expert whose
  assigned tags overlap with any of the applied ones AND whose
  language_group covers the session's chat language (per FR-021a).
- **EC-04 (Browser back/refresh)**: When the Reviewer presses Back or
  Refresh during an active review, a confirm modal with "Close and lose
  data" / "Stay on page" is shown.
- **EC-05 (Min reviewers count = 1 + tag)**: If the configuration requires
  only 1 reviewer per session and the Reviewer added a tag, the session
  goes both to "Ready for supervision" (for the Supervisor) and to "Awaiting
  expertise" (for the Expert) at the same time. (corresponds to MVP EC-07)
- **EC-06 (Approve change request after supervision)**: If the Supervisor
  has already finished supervising the session and then approves the
  Reviewer's old change request, the system shows the error "Session is no
  longer editable after supervision" and does not open the editor.
  (MVP EC-08)
- **EC-07 (Repeat Red Flag in repeat review)**: The Reviewer re-rates a
  session (REPEAT label) and raises another Red Flag — the new flag is
  stored as a separate event and does not conflict with the previous one.
  (MVP EC-10)
- **EC-08 (Expired 2FA session with a draft)**: The Reviewer was in the
  middle of a review and their session expired by inactivity — after
  signing in again (with OTP/TOTP per environment) they return to Pending,
  the unfinished session keeps the UNFINISHED label, and on reopening the
  full draft is restored.
- **EC-09 (Deactivated user)**: If a Reviewer's account is deactivated,
  their past ratings and flags remain stored and visible to the Supervisor;
  no new actions may be performed. Their unfinished drafts persist as
  audit artefacts but the deactivated user can no longer sign in to
  finalise them.
- **EC-09a (Reviewer removed from a Space)**: If the Reviewer is removed
  from a Space they were a member of, sessions belonging to that Space
  immediately disappear from their Pending and Completed views and from
  Reports aggregates. Any draft (UNFINISHED) ratings the Reviewer had
  on those sessions are preserved server-side as historical records but
  are no longer accessible through the Reviewer UI; on re-add to the
  same Space, the drafts reappear and can be resumed.
- **EC-09b (Reviewer added to a new Space mid-flight)**: If the Reviewer
  is added to a new Space, sessions already in that Space's queue
  immediately appear in the Reviewer's Pending list (subject to filters)
  with the NEW label and a normal review-progress counter; the Reviewer
  may rate them just like any other session.
- **EC-10 (Network error on submit)**: If the final-submit fails due to a
  network error, scores are kept locally, the Reviewer sees a friendly
  error message and can retry without re-entering data.
- **EC-11 (Repeat-review canonical-version takeover)**: After the Reviewer
  finalises a REPEAT rating, the new rating becomes canonical for analytics
  and the current Supervisor view; the previous primary rating is marked
  `superseded`, hidden from default Supervisor view, and only accessible
  via the per-session "version history" panel for audit.
- **EC-12 (Backend full outage during review)**: The backend `ping`
  endpoint starts failing while the Reviewer is mid-session — the UI
  flips to offline mode (warning banner + queued IndexedDB writes); the
  Reviewer can keep editing scores, criteria, comments, tags and Red
  Flags; Submit is disabled. When the backend recovers, queued writes
  replay in order; during the replay window the Submit button shows
  `⟳ Submit (N)` with N decrementing in real time (FR-018a); once the
  queue reaches zero, the banner disappears, a one-shot success toast
  confirms sync, the Submit label reverts to plain `Submit`, and the
  button becomes enabled.
- **EC-13 (Transient single-request failure with verbose OFF)**: A
  single save request returns 500 while ping still succeeds; the client
  silently retries 3 times with backoff; if `verbose_autosave_failures`
  is OFF (default) and the third retry also fails, a single toast
  surfaces; if it is ON, every failed attempt fires a toast.
- **EC-14 (Submit blocked by missing per-message tag comment)**: The
  Reviewer rated all assistant replies and added a clinical tag on
  message M1 but left M1's tag comment empty; Submit stays disabled
  until M1's tag comment is filled (FR-018c).
- **EC-15 (Concurrent rating completes the session)**: Reviewer A is
  on the Review Queue with a session showing "1 / 2"; in the same
  Space, Reviewer B submits their finalised review, taking the count
  to "2 / 2" and removing the session from the Pending pool. Reviewer
  A's card MUST refresh to "2 / 2" no later than the next
  refresh-on-action trigger or 60-second background poll (FR-008a),
  whichever comes first. If Reviewer A opens the session AFTER it has
  reached 2 / 2 and is no longer in their Pending queue, the session
  detail view MUST surface a clear "This session has reached its
  required reviewer count and is no longer available for rating"
  state instead of a partially-rendered editor.
- **EC-16 (Tag soft-deleted while attached)**: The Reviewer attached
  Clinical Tag T to message M in session S (in either a draft or a
  completed review). Later the Administrator soft-deletes T in Tag
  Center. On the Reviewer's next list refresh, T disappears from the
  Clinical Tag selector but the existing attachment on M remains
  visible — rendered as a "(deleted) T" chip with the tooltip "This
  tag was retired by an administrator on [date]". For Clinical Tags,
  any session tagged after T's deletion timestamp does NOT route to
  the Experts that were assigned to T; sessions tagged before the
  deletion (including S) continue to route as before. The same chip
  rendering applies to Review Tags. Soft-delete and any restore are
  recorded in the Audit Log.
- **EC-17 (Required reviewer count decreased mid-flight)**: Y is
  changed from 3 to 2 by the Administrator. A Pending session with
  X = 2 / 3 transitions to "completed by the new threshold" on the
  next refresh: it disappears from the Reviewer Pending tab and is
  routed into supervision. Reviewers who hadn't started rating it see
  it vanish; Reviewers with an UNFINISHED draft on it lose the ability
  to submit (the draft is preserved server-side as historical record
  but the session is no longer in their queue). The change is logged
  in Audit Log.
- **EC-18 (Required reviewer count increased mid-flight)**: Y is
  changed from 2 to 4. A Pending session previously at X = 2 / 2 (was
  about to be completed) now displays X = 2 / 4 and stays in Pending
  awaiting two more reviewers; sessions already routed to supervision
  before the change remain in supervision unchanged.
- **EC-19 (Same session in two tabs — non-conflicting edits)**: The
  Reviewer opens session S in tab A and tab B. In tab A they type a
  comment on reply M1; tab A autosaves on blur. The Reviewer focuses
  tab B; tab B fires a focus-fetch, captures the snapshot, receives
  fresh state including the new M1 comment, and (since the user
  hadn't typed in M1 in tab B since focus return) updates the M1
  field to the server value with a brief "Updated by another tab"
  indicator; all other fields remain untouched; no cursor jump.
- **EC-20 (Same session in two tabs — conflicting edits)**: The
  Reviewer opens session S in tab A and tab B. In tab B the cursor
  is in the M2 comment field and the Reviewer starts typing
  "preserved here". In tab A the M2 comment was previously saved
  with "saved earlier" (different text). The Reviewer focuses tab B;
  the focus-fetch returns "saved earlier" for M2, but because the
  user is actively typing in M2 in tab B, the local "preserved here"
  is preserved untouched; tab B surfaces a small inline conflict
  indicator on M2 surfacing "saved earlier" on hover for manual
  reconciliation; on the user's next blur of M2, the autosave POSTs
  the local value and overwrites the server value (last-write-wins
  for that single field).

## Requirements *(mandatory)*

### Functional Requirements

#### Access and navigation

- **FR-001**: The system MUST show users with the Reviewer/Researcher role
  only "Review Queue" and "Reports" in the main navigation; all other
  modules MUST be hidden in the UI.
- **FR-002**: The user profile (settings) MUST be reachable only from the
  account-icon dropdown in the top-right area (with Settings and Sign Out
  entries).
- **FR-002a**: The header MUST expose a locale switcher (the existing
  flag/locale dropdown) that drives the language of the entire Reviewer
  UI: sidebar labels, breadcrumbs, criteria labels (FR-014), score-level
  tooltips (FR-012), paginator controls, banner notifications (FR-039a),
  toast notifications (FR-031c), modal dialogs, and error messages.
  Default value is the user's browser locale; if the browser locale is
  not in the supported set the locale falls back to `en`. The same
  locale value MUST also be editable from the Settings page; the two
  controls are bound to the same per-user preference. The Reviewer UI
  locale is INDEPENDENT of the chat session language: switching the
  header locale does NOT change the language of Clinical Tag and Review
  Tag selectors inside an open session — those continue to follow the
  session's `language` attribute (FR-021a, FR-024c).
- **FR-003**: Every server-side request from the Reviewer (sessions,
  ratings, tags, flags, reports) MUST be validated by role-based access
  control on the server; bypassing the UI MUST NOT grant access to data
  belonging to other Reviewers.

#### Authentication and sessions

- **FR-004**: The Reviewer MUST pass two-factor authentication on every new
  sign-in. The 2FA method depends on environment: production — TOTP
  (Time-based One-Time Password) via an authenticator app
  (Google Authenticator/Authy); dev and staging — email OTP delivered via
  the browser console (used by dev tooling and the E2E suite).
- **FR-005**: An active Reviewer session MUST end automatically after a
  configurable inactivity timeout (set by the Administrator, default 30
  minutes). After timeout the user is redirected to login while every
  unfinished review draft is preserved.

#### Review Queue — tabs and cards

- **FR-006**: Review Queue MUST contain at least two tabs visible to the
  Reviewer: "Pending" and "Completed".
- **FR-007**: In the Pending tab, every session card MUST show one of the
  sub-labels: NEW (no draft and no past completed review), REPEAT (returned
  after an approved change request), UNFINISHED (a saved draft exists).
- **FR-008**: A session card MUST show: anonymised session ID, anonymised
  user ID, risk level, message count, age (since session date), review
  progress in X/Y reviewers form (X = number of Reviewers from the
  session's Space who have already submitted a finalised review; Y =
  the configured Required reviewer count from Review Settings, applied
  per FR-008b for in-flight sessions), and my labels (any tags or
  flags raised by the current Reviewer). The card MUST also visually
  indicate the session's owning Space (e.g., Space name pill) when
  the active selection is "All Spaces".
- **FR-008b**: When the Administrator changes the Required reviewer
  count value in Review Settings, the new value MUST apply
  forward-only to sessions that have NOT yet met the old completion
  threshold (i.e., sessions still in Pending whose X is strictly less
  than the old Y). Sessions already in supervision or Completed are
  unaffected and remain immutable in their previously-frozen state.
  For Pending sessions:
  (a) If Y is increased (Y_new > Y_old) — sessions sitting at X = Y_old
  remain in Pending and continue collecting reviews until X reaches
  Y_new; sessions with X < Y_old simply use the new Y for the X/Y
  display.
  (b) If Y is decreased (Y_new < Y_old) — sessions whose X already
  satisfies X >= Y_new are auto-completed on the next refresh
  (refresh-on-action or 60-s polling per FR-008a) and routed into
  supervision through the normal flow; their cards leave the Reviewer
  Pending tab accordingly. Sessions with X < Y_new simply use the new
  Y for the X/Y display.
  No cohort-based snapshot is taken; no retroactive reopening of
  Completed sessions occurs. Every Required reviewer count change MUST
  emit an Audit Log entry (FR-049) with the old and new values.
- **FR-008a**: The X / Y review-progress counter on every visible
  session card MUST be refreshed using a refresh-on-action +
  background-polling model:
  (a) refresh-on-action triggers — opening Review Queue, switching the
  Pending / Completed tab, switching the header Space dropdown,
  paginating to a different page, applying or clearing any filter
  (chip / date / language), and the browser tab regaining focus after
  a blur;
  (b) background polling — every 60 seconds while the Reviewer is on
  the Review Queue page, the visible page slice is refetched so that
  counters never drift more than ~60 seconds out of date even with no
  user action;
  (c) on opening an individual session for rating, the counter on the
  session detail view MUST be refetched as part of that initial
  request (no reuse of the cached card value).
  Real-time push (WebSocket / SSE) and client-side optimistic
  increment are explicitly out of scope for 058. The counter MUST
  always reflect the server's authoritative count on the most recent
  fetch.
- **FR-009**: Default sort order MUST be from oldest to newest (decreasing
  age). The Reviewer MUST be able to filter by date range.
- **FR-009a**: The Pending tab MUST render a single session list (no
  nested sub-tabs) with a horizontal chip-bar filter above the list. The
  chips are NEW, REPEAT, UNFINISHED with multi-select semantics: with no
  chip selected, all matching sessions are shown; selecting one or more
  chips narrows the list to sessions that carry at least one of the
  selected sub-labels. The Pending tab badge MUST always reflect the total
  unfiltered count (chip-filter state does not change the badge).
- **FR-009b**: Both Pending and Completed tabs MUST use server-side
  pagination with a fixed page size of 25 sessions per page. The UI
  MUST render a paginator with Prev / Next controls and explicit numbered
  pages. The chip-filter (FR-009a), date-range filter (FR-009), language
  filter (FR-009c) and any other filters MUST be applied server-side; the
  server response MUST include both the page slice and the total count.
  Pending and Completed tab badges MUST always show the total unfiltered
  count across all pages (page navigation does not change the badge).
- **FR-009c**: Both Pending and Completed tabs MUST expose a language
  filter rendered as a checkbox group. The list of available language
  options and their per-language session counts MUST be fetched from a
  backend endpoint that returns ONLY the locales currently present in
  the Reviewer's queue (e.g., `[{code: "uk", count: 18}, {code: "en",
  count: 4}]`); locales with zero matching sessions MUST NOT appear.
  Multi-select semantics: nothing checked = sessions of all languages;
  one or more checked = sessions whose `language` is in the selected
  set. Every change of the language filter MUST trigger a fresh server
  fetch with no client-side caching of filtered result sets. The filter
  state MUST persist within the browser session (in-memory) but MUST NOT
  persist across sign-ins; on each new sign-in the filter starts empty
  ("all languages"). The available-locales list itself MUST be dynamic
  (today UK / RU / EN; future additions appear automatically with no
  client code change).
- **FR-010**: The Reviewer MUST see only chat sessions whose user belongs
  to a Space the Reviewer is a member of. Sessions belonging to any
  other Space (including Spaces the Reviewer was once a member of but
  has been removed from) MUST NOT appear in the queue. There is no
  per-Reviewer assignment artefact — visibility is derived purely from
  Space membership at query time.
- **FR-010a**: The header Space dropdown MUST list ONLY Spaces the
  current Reviewer is a member of, sorted alphabetically, plus an
  "All Spaces" pseudo-option that resolves to the union of those Spaces.
  The dropdown MUST NOT expose Spaces the Reviewer is not a member of,
  any "join" / "request access" affordance, or any administrative Space
  management. The selected Space scopes every Review Queue list, the
  Pending tab badge counts, the Completed tab badge counts, the
  language-filter source endpoint (FR-009c), and the Reports metrics
  (FR-043). When "All Spaces" is selected, the queries union across all
  member Spaces.
- **FR-010b**: When a chat session ends, it MUST be routed automatically
  into the Review Queue of the Space the chat user belongs to, with no
  Administrator or Supervisor action. Every Reviewer currently a member
  of that Space sees the session as NEW (subject to filters); no
  per-Reviewer push, claim, or lock takes place.

#### Rating an assistant reply

- **FR-011**: For every assistant reply in a session the Reviewer MUST be
  able to set a 1–10 score (radio choice).
- **FR-012**: Every score level (1–10) MUST have a tooltip description
  available on hover/focus on an info icon.
- **FR-013**: For every rating a free-text comment field MUST be available.
- **FR-014**: For every rating a criterion selector MUST be available with 8
  fixed values that have stable, immutable IDs and i18n-localised labels:
  Relevance (`relevance`), Empathy (`empathy`), Psychological safety
  (`psychological_safety`), Ethical integrity (`ethical_integrity`),
  Clarity and tone (`clarity_tone`), Request match (`request_match`),
  Autonomy support (`autonomy`), Artificiality (`artificiality`). The set
  is hard-coded in the system and is NOT managed by the Administrator
  within this feature.
- **FR-015**: For every rating a "Validated answer" textarea MUST be
  available.
- **FR-016**: For score ≥ 8: criterion is optional; if a criterion is
  picked, its comment is mandatory; "Validated answer" is optional.
- **FR-017**: For score < 8: criterion is MANDATORY, criterion comment is
  MANDATORY, "Validated answer" is MANDATORY.
- **FR-018**: The "Submit Review" button MUST stay disabled until ALL of
  the following hold:
  (a) every assistant reply in the session is rated;
  (b) all mandatory fields for ratings < 8 are filled (criterion,
  criterion comment, validated answer);
  (c) every message that carries one or more clinical tags from the
  current Reviewer has a non-empty tag comment (FR-022);
  (d) every Red Flag raised by the current Reviewer has a non-empty
  description (FR-026);
  (e) the client is online (i.e., not in offline mode per FR-031b)
  AND the offline queue is empty (per FR-018a below);
  Submit performs the state transition that finalises the review
  (Pending → Completed for primary submit, Pending REPEAT → Completed
  for repeat submit). The set of enablement conditions is a hard gate —
  the button MUST NOT become active while any condition is unmet.
- **FR-018a**: Submit-during-replay UX. While the client transitions
  out of offline mode (i.e., the `ping` endpoint has recovered but
  queued offline writes are still being replayed), the Submit button
  MUST stay disabled and MUST render its label as a spinner glyph
  followed by the verb and a parenthesised live count of unsynced
  requests, e.g., `⟳ Submit (3)`; the count MUST decrement in real
  time as each queued request acks. When the queue reaches zero AND
  all FR-018(a..d) gating conditions are still satisfied, the spinner
  and count disappear, the label reverts to plain `Submit`, and the
  button becomes enabled. If the queue grows again (renewed ping
  failure) the button MUST flip back to disabled with the
  spinner-and-count label. This gating pattern prevents any race
  between Submit and a still-pending offline write.
- **FR-019**: After submit every rated reply MUST receive a visible "Rated"
  marker.

#### Clinical tags

- **FR-020**: Every user reply and every assistant reply MUST expose a
  "Clinical tag" control letting the Reviewer attach one or more clinical
  tags.
- **FR-021**: The list of available clinical tags MUST come from the Tag
  Center (minimum: Anxiety, Burnout, Depression, PTSD; the Administrator
  can add or soft-delete others — soft-delete semantics per FR-021b).
- **FR-021b**: When the Administrator soft-deletes a tag in Tag Center
  (Clinical Tag or Review Tag), the tag MUST disappear from every
  Reviewer-facing selector by the next list fetch (refresh-on-action
  triggers per FR-008a guarantee propagation within ≤ 60 seconds).
  Existing attachments to messages and sessions MUST be preserved
  unchanged for audit. Soft-deleted tag attachments MUST render with a
  visible "(deleted)" prefix on the chip, retain hover tooltip behavior
  (FR-024d) but with the tooltip text replaced by "This tag was retired
  by an administrator on [date]" in the active locale. For Clinical
  Tags specifically, soft-deletion HALTS expert-routing for any session
  that gets tagged AFTER the deletion timestamp; sessions already
  tagged before deletion continue to route to assigned Experts as
  before. Both soft-delete and subsequent restore (clearing
  `deleted_at`) MUST emit Audit Log entries (FR-049). The Tag Center
  itself MUST NOT offer a hard-delete control for tags that have ever
  been attached.
- **FR-021a**: When a Reviewer opens a session for rating, the clinical
  tag selector MUST display ONLY tags from the Tag Center whose
  `language_group` attribute covers the session's `language` (e.g., a
  session with `language = "en"` shows only tags whose language_group
  includes `en`; a tag with `language_group = ["uk", "ru"]` is hidden in
  English sessions). Tag labels themselves MUST be presented in the
  session's chat language. The same language-group filtering MUST apply
  to expert-tag assignments (Experts only receive sessions whose chat
  language matches one of the language_groups they are assigned to).
- **FR-022**: For every message on which the current Reviewer attaches
  one or more clinical tags, a mandatory per-message "Tag comment" field
  MUST appear directly under that message. The comment scope is the
  message + Reviewer pair: tags from the same Reviewer on the same
  message share that one comment; tags on a different message require a
  separate comment for that message. Each tag comment MUST be non-empty
  for Submit to enable (FR-018c).
- **FR-023**: Tags added by one Reviewer MUST NOT be visible to other
  Reviewers in the same session.
- **FR-023a**: Before the review is submitted the Reviewer MUST be able
  to delete a tag they themselves added and edit the shared session-level
  tag comment. Each such create / update / delete operation MUST emit a
  separate Audit Log event (FR-049). After submit, tags and the tag
  comment become read-only as part of the read-only review (FR-035).
- **FR-024**: Once a clinically-tagged session is finalised, it MUST be
  routed to the expert queue automatically; only Experts whose assigned
  tags overlap with the session's clinical tags AND whose
  `language_group` covers the session's `language` see it (per FR-021a).

#### Review Tags

- **FR-024a**: The Reviewer MUST be able to attach one or more Review
  Tags at the session level (not at the message level) using a
  dedicated "Tags:" control above the transcript. Review Tags are
  organisational labels (e.g., `loop-regression`, `compat-tag3`) and
  do NOT trigger expert routing.
- **FR-024b**: The list of available Review Tags MUST come from the
  Tag Center "Review Tags" CRUD; their lifecycle (create, edit,
  delete, language assignment) is managed by the Administrator outside
  this feature, mirroring Clinical Tag management.
- **FR-024c**: Review Tags carry the same `language_group` attribute
  as Clinical Tags. When a Reviewer opens a session, the Review Tag
  selector MUST display ONLY tags whose `language_group` covers the
  session's `language`. Tag labels are presented in the session's
  chat language, NOT in the Reviewer's UI locale (FR-002a). This rule
  is identical to FR-021a for Clinical Tags.
- **FR-024d**: Every Review Tag and every Clinical Tag MUST carry a
  free-text `description` field. In the Reviewer UI, hovering over
  any tag chip (in the selector, on the transcript, on a session
  card) MUST show the description as a tooltip. An empty description
  is allowed; in that case no tooltip appears.
- **FR-024e**: Review Tags MUST NOT have any expert-assignment
  property; the Tag Center constructor MUST hide the expert-assignment
  UI for the Review Tags entity. The same canonical two-letter-badge +
  language-dropdown component used for Clinical Tag language
  assignment (parallel Tag Center extension dependency) MUST also be
  used for Review Tag language assignment — no parallel
  implementations.
- **FR-024f**: Review Tags attached by one Reviewer ARE visible to
  other Reviewers reviewing the same session (this differs from
  Clinical Tags per FR-023, because Review Tags are organisational and
  not part of the independent-rating principle). Removing a Review Tag
  before submit is allowed for the Reviewer who attached it; each
  attach / detach event MUST emit an Audit Log entry (FR-049).

#### Red Flag

- **FR-025**: Every user reply and every assistant reply MUST expose a "Red
  Flag" control to mark a critical situation.
- **FR-026**: Pressing Red Flag MUST open a modal with a mandatory
  "Situation description"; an empty description blocks confirmation.
- **FR-027**: A raised Red Flag prevents leaving the session unfinished:
  the Reviewer is required to submit this session (after raising a flag,
  submit becomes the only durable way to leave the review).
- **FR-027a**: Before the review is submitted the Reviewer MUST be able
  to delete a Red Flag they themselves raised and edit its description.
  Each such create / update / delete operation MUST emit a separate Audit
  Log event (FR-049). After submit, Red Flags become read-only as part of
  the read-only review (FR-035). If the Reviewer deletes the only Red
  Flag in the session before submit, the FR-027 obligation is lifted (the
  session may then be left unfinished as usual).
- **FR-028**: Email notification to Supervisors MUST be sent ONLY after
  submit of a session that contains a Red Flag; the email includes the
  Reviewer's name, the time the flag was raised, a link to the session and
  to the specific reply.
- **FR-029**: A submitted flagged session MUST receive the URGENT label
  and appear in the Supervisor's Red Flag tab.
- **FR-030**: A Red Flag raised by one Reviewer MUST NOT be visible to
  other Reviewers in the same session (other Reviewers continue rating as
  if no flag existed).

#### Unfinished reviews and autosave

- **FR-031**: All Reviewer-entered state (scores, criteria, comments,
  validated answers, tags, tag comments, Red Flags, Red Flag
  descriptions) MUST be authoritative on the backend. Client autosave is
  event-driven, not interval-driven: every input MUST emit a save
  request to the backend on `blur`, and the application MUST flush all
  pending unsaved changes on the page-lifecycle `beforeunload` /
  `pagehide` events (covering tab close, browser close, route navigation
  away). No in-memory-only state is allowed beyond the brief window
  between an input event and its `blur`.
- **FR-031a**: A backend `ping` endpoint MUST be available and used by
  the client to distinguish two failure modes for any save request:
  (a) backend-down (ping fails) → enter offline mode (FR-031b);
  (b) transient single-request failure (ping succeeds, individual save
  returned 4xx/5xx) → retry that single request with exponential
  backoff (2 s / 4 s / 8 s; up to 3 attempts); on persistent failure
  surface a toast notification.
- **FR-031b**: Offline mode behaviour: while ping is failing the UI MUST
  display a persistent warning-coloured banner pinned to the top of
  every page reading "Working offline — your changes will sync when the
  connection returns"; pending save payloads MUST be queued in a local
  durable store (browser IndexedDB) and replayed against the backend in
  original order once ping recovers; the Submit button (FR-018e) MUST
  stay disabled while in offline mode; on successful sync the offline
  banner MUST disappear and a one-shot success toast MUST confirm
  "All offline changes synced".
- **FR-031c**: Toast notifications for transient single-request save
  failures MUST be gated by an Administrator-managed boolean setting
  `verbose_autosave_failures` (default OFF). When OFF, only persistent
  failures (after the third retry) surface a toast. When ON, every
  failed save attempt surfaces a toast. The setting MUST be exposed in
  the Administrator settings UI as a single Toggle control. This
  setting is the only piece of admin functionality in scope for 058
  beyond the parallel Tag Center dependency.
- **FR-031d**: All Toggle controls introduced or modified by this
  feature (including the `verbose_autosave_failures` admin toggle and
  any future Reviewer/admin toggles) MUST use the canonical design-
  system Toggle component. If no canonical Toggle component exists in
  the design system at the time of implementation, this feature MUST
  introduce one and document it as the single canonical Toggle for all
  future work; redundant one-off toggle implementations are
  prohibited. The default OFF state MUST render in the system's neutral
  gray colour.
- **FR-032**: A session with any queued or persisted unsaved changes
  MUST be marked UNFINISHED in Pending; on reopening, the full
  authoritative state (scores, criteria, comments, validated answers,
  tags, tag comments, Red Flags, descriptions) MUST be restored from
  the backend; any IndexedDB-queued offline changes pending sync MUST
  be replayed before the restored state is shown.
- **FR-033**: When the Reviewer tries to close/refresh the page or press
  the browser Back button during an active review with unsynced
  changes, the page-unload flush (FR-031) MUST attempt to send all
  pending changes synchronously; in addition, a modal with two actions
  ("Close and lose unsaved data" and "Stay on page") MUST appear before
  unload to give the Reviewer a chance to abort the navigation if any
  saves are still pending.
- **FR-034**: Reserved (merged into FR-031..FR-033 above).
- **FR-034a**: Multi-tab reconciliation. The Reviewer MAY have the
  same session open in more than one browser tab; no tab becomes hard
  read-only. On every tab-focus event (the page regains focus after
  losing it — `visibilitychange` / `focus` / `pageshow`), the focused
  tab MUST:
  (a) capture an immutable in-memory snapshot of the current local
  state of every editable field at the moment of focus return;
  (b) immediately fire a fresh server fetch for the full session
  state and gate the editing surface with a skeleton or spinner
  overlay so no user input is accepted until the response arrives;
  (c) on response, perform per-field reconciliation against the
  snapshot:
  - if `server_value != snapshot_value` AND the user has NOT typed
    in that field since focus return, the field MUST be updated to
    `server_value` (a small inline indicator like "Updated by another
    tab" MAY be shown briefly on the affected field for transparency);
  - if `server_value != snapshot_value` AND the user HAS started
    typing in that field since focus return, the local edit MUST be
    preserved (the server value is discarded for that field, and the
    field receives a small inline conflict indicator surfacing the
    competing value on hover so the Reviewer can manually reconcile);
  - if `server_value == snapshot_value`, the DOM MUST be left
    untouched (no rewrite, no cursor jump);
  (d) once reconciliation is complete, lift the gating overlay and
  resume normal editing.
  Multi-tab reconciliation MUST NOT introduce any backend lock; the
  authoritative state remains the backend store, and the autosave
  model from FR-031 is unchanged. The tab-focus reconciliation is
  independent of (and complements) the X / Y counter refresh model
  in FR-008a.

#### Finalization and change requests

- **FR-035**: After a successful submit the session MUST move to Completed
  with the COMPLETED label and become read-only for the Reviewer.
- **FR-036**: The read-only view of a completed session MUST expose a
  "Request changes" button that opens a form with a mandatory "Request
  reason" field.
- **FR-037**: After sending a change request the Reviewer MUST see a
  status indicator ("Awaiting supervisor decision") on the session card /
  page until a response.
- **FR-038**: On approve the Reviewer MUST receive an in-app notification
  (per FR-039a) plus an email; the session returns to Pending with the
  REPEAT label.
- **FR-039**: On reject the Reviewer MUST receive an in-app notification
  (per FR-039a) and an email with the rejection reason; the session
  stays in Completed with the COMPLETED label.
- **FR-039a**: In-app notifications addressed to the Reviewer MUST be
  delivered via two coordinated surfaces:
  (a) a persistent banner pinned to the top of every page that contains
  the notification text and a "Dismiss" control; the banner stays
  visible until the Reviewer explicitly clicks Dismiss (no auto-hide,
  no time-out);
  (b) a bell icon in the header bar that carries an unread-count badge
  and, on click, opens a list of unacknowledged notifications with
  per-item Dismiss controls.
  Every Dismiss / mark-read action MUST emit a separate Audit Log entry
  (FR-049) with event type `notification.read`. Notifications already
  delivered to a Reviewer MUST NOT be re-shown after acknowledge, even
  on a fresh sign-in.
- **FR-039b**: The notification subsystem in 058 MUST support exactly
  three Reviewer-targeted notification categories:
  (1) `change_request.decision` — Supervisor approved or rejected a
  change request the Reviewer sent (FR-038, FR-039); the notification
  payload carries the session reference, the decision, and (on reject)
  the reason text; on approve the matching session also returns to
  Pending with the REPEAT label.
  (2) `red_flag.supervisor_followup` — Supervisor posted commentary or
  a follow-up action on a Red Flag the Reviewer raised; the payload
  carries the session reference, the specific message reference, and
  the Supervisor's commentary text.
  (3) `space.membership_change` — the Reviewer was added to a new
  Space ("You were added to Space X") or removed from one ("You were
  removed from Space Y"); the payload carries the Space name and the
  change direction; this is the user-facing companion of EC-09a /
  EC-09b.
  No other notification categories are in scope for 058. The bell-icon
  and banner surfaces remain extensible (other categories can be
  introduced later without UI changes), but emitting any non-listed
  category from 058 backend code is prohibited.
- **FR-040**: After a repeat submit (REPEAT label) the system MUST store
  both ratings as separate records. The repeat rating becomes the canonical
  version used by analytics (Reports, Supervisor view, Score Distribution,
  Average Score Trend) and by the current Supervisor view; the primary
  rating is marked `superseded` and is excluded from default Supervisor
  view and from analytics aggregates.
- **FR-041**: A `superseded` primary rating MUST remain accessible to the
  Supervisor through a per-session "version history" panel as a read-only
  audit artefact, including the original score, criterion, comment,
  validated answer, author and timestamp.
- **FR-042**: If the Supervisor approves a change request for a session
  that has already passed supervision, the system MUST show the error
  "Session is no longer editable after supervision" and MUST NOT open the
  editor.

#### Reports and analytics (Reviewer scope)

- **FR-043**: On the Reports page the Reviewer MUST see only their own
  data; the performer filter MUST be completely hidden from the DOM (no
  disabled control, no placeholder, no tooltip mentioning other roles).
  The server MUST always fix performer = current user for any Reports
  query originating from a Reviewer role, regardless of any client-side
  parameter. The Reports scope is also bounded by the active header
  Space dropdown selection (FR-010a): metrics for a single Space cover
  only that Space; "All Spaces" unions across the Reviewer's member
  Spaces.
- **FR-044**: Reports MUST include at least the following metrics for the
  selected period: session counts by status (Pending/UNFINISHED/Completed/
  RED FLAG), number of rated sessions, average score, number of comments,
  Score Distribution (1–10 bar chart), Average Score Trend (over time), and
  the count of Red Flags raised by the Reviewer.
- **FR-045**: A period filter (From/To dates) MUST be available on Reports.
- **FR-046**: The Reports page for the Reviewer MUST NOT contain any
  export/download controls (per US-01: raw data export is available only
  in the surveys module).
- **FR-047**: Reports analytics MUST consume only canonical ratings (i.e.
  primary ratings that are NOT `superseded` plus repeat ratings). The
  `superseded` primary records MUST NOT contribute to averages, counters
  or distributions.

#### Empty / loading / error states

- **FR-046a**: Every list or data area in the Reviewer UI (Pending
  tab, Completed tab, individual session view, Reports charts,
  notification bell-list, language filter, Space dropdown contents)
  MUST render coordinated empty / loading / error states using the
  patterns below; ad-hoc one-off states are prohibited.
- **FR-046b**: Loading state. Within 200 ms of a fetch starting, the
  area MUST render skeleton placeholders that mimic the final layout
  (e.g., grey card-shaped blocks for session cards, grey lines for
  text). No full-screen blocking spinner. Skeletons MUST NOT animate
  in a way that violates WCAG 2.1 SC 2.3.1 (no flashes more than 3
  per second).
- **FR-046c**: Empty state. A centred composition consisting of:
  (a) a simple flat vector illustration appropriate to the situation
  (empty inbox for "no sessions yet", all-caught-up checkmark for
  "all reviewed", filter-funnel-with-zero for "filter returns
  nothing", calendar with magnifier for empty Reports period, etc.);
  (b) a contextual headline ("No sessions to review yet — new chats
  from your Spaces will appear here automatically", "All caught up!
  No pending sessions in [Space]", "No sessions match the current
  filters", etc.) — actual wording is i18n-localised (FR-002a);
  (c) an optional supporting paragraph; (d) a CTA where applicable
  (e.g., "Clear filters" when an active filter is the cause).
  Illustrations MUST carry `aria-hidden=true`; the headline is the
  accessible name.
- **FR-046d**: Error state. A centred composition consisting of:
  (a) a flat vector illustration in the error theme (sad cloud,
  broken plug, etc.); (b) the specific machine-readable error code
  (e.g., `REQ-503`); (c) a human-readable description in the active
  locale; (d) a "Retry" CTA that re-runs the failed request; (e) a
  link to support (`mailto:` or workbench help URL). The error state
  MUST be announced via `aria-live=assertive`. The error code MUST
  also be written to the browser console for triage.
- **FR-046e**: All three states (loading, empty, error) MUST use
  `aria-live=polite` regions for the headline / description text so
  that screen readers announce transitions between states without
  interrupting other speech (the error state may upgrade to
  `assertive` per FR-046d).

#### Browser support

- **FR-046h**: The Reviewer Review Queue MUST be officially supported
  on the following browsers, on each of the latest 2 major versions:
  evergreen Chromium-based browsers (Chrome, Microsoft Edge), latest
  stable Mozilla Firefox, latest stable Apple Safari (including
  Safari on iPadOS for the tablet tier per FR-046f). IE11, legacy
  (non-Chromium) Edge, and any browser version released more than
  18 months before the current build are explicitly NOT supported.
- **FR-046i**: When a hard browser prerequisite is missing (no
  IndexedDB, no ServiceWorker support, no `addEventListener`
  visibilitychange / pageshow, etc.) the Reviewer UI MUST detect it
  on first load and present a friendly full-page "Your browser is
  not supported — please update or switch to Chrome / Edge / Firefox
  / Safari" notice, rather than rendering a half-broken interface.
  Soft-missing capabilities (e.g., notification API absent on a
  tablet) downgrade gracefully to in-page-only equivalents and a
  smaller inline notice on the affected control.

#### Responsive and PWA

- **FR-046f**: The Reviewer Review Queue MUST be fully usable across
  three viewport tiers, with min supported width 360 px:
  (a) Desktop (≥ 1024 px) — full fidelity, the layout from the dev
  baseline (sidebar, header, multi-column session cards, paginator);
  (b) Tablet (768 px – 1023 px) — full fidelity for every Reviewer
  function with a collapsible sidebar (icon-rail by default,
  expandable on tap), single-column session card list, full rating
  editor with all controls reachable via touch (≥ 44×44 px touch
  targets), tap-friendly chip filters and language filter, full Red
  Flag modal, full notification banner and bell list;
  (c) Mobile (360 px – 767 px) — best-effort read-only mode: Pending
  and Completed lists render as a stacked card feed; Reports surfaces
  with horizontally-scrollable charts; the notification bell and
  banner remain functional with their Dismiss controls; the rating
  editor, tag selectors, Red Flag modal, and Submit flow are NOT
  exposed and instead a centred prompt reads "Best used on a tablet
  or desktop — switch to a wider device to rate this session"
  (i18n-localised per FR-002a).
- **FR-046g**: The Workbench shell hosting the Reviewer surfaces
  MUST remain PWA-installable: a valid web app manifest is served
  with name, short_name, theme_color, background_color, display
  `standalone`, start_url, and icons covering ≥ 192×192 and ≥ 512×512
  PNG. A service worker MUST cache the shell and static assets so
  that signed-in Reviewers can launch the installed PWA and reach a
  meaningful "offline" empty-state if no connectivity is available
  on launch. Reuse the existing workbench-pwa shell rather than
  introducing a parallel implementation.

#### Accessibility

- **FR-047a**: Every user-facing UI element introduced or modified by
  058 (including the sidebar, locale switcher, Space dropdown, queue
  tabs, chip filters, language filter, paginator, session cards,
  transcript, score selector, criterion selector, validated-answer
  field, tag selectors and chips, Red Flag modal, autosave / offline
  banners, bell-icon notification list, persistent banner, and the
  Submit button with its countdown label) MUST conform to WCAG 2.1
  Level AA. Specifically, this means at minimum: text contrast ratio
  ≥ 4.5:1 for normal text and ≥ 3:1 for large text; non-text contrast
  ≥ 3:1 for UI components and graphical objects; full keyboard
  reachability and operability with a visible focus indicator on every
  interactive control; semantic ARIA roles and accessible names on
  every interactive control; live regions (`aria-live=polite`) used
  for the offline banner and notification banner so screen readers
  announce them on appearance; the Submit countdown label
  (`⟳ Submit (N)`) MUST also expose its decrementing value through an
  `aria-live=polite` region.
- **FR-047b**: Automated accessibility validation via axe-core (or an
  equivalent open-source rule engine) MUST run inside the E2E suite on
  every Reviewer-facing route. Any critical or serious violation MUST
  fail the build. Moderate / minor violations are recorded as warnings
  and tracked but do not block merge.

#### Privacy and PII protection

- **FR-047c**: Every chat-transcript payload delivered to a Reviewer
  client MUST be processed by the server-side PII detector before
  transmission. The detector MUST identify and replace at minimum:
  personal names, email addresses, phone numbers, postal addresses,
  medical record numbers and other clinical identifiers, dates of
  birth, geographic locations, employer / school references, and any
  inline numeric ID matching a known PII format. Replacements MUST
  use the canonical placeholder pattern `[REDACTED:type]` (e.g.,
  `[REDACTED:name]`, `[REDACTED:phone]`) so the Reviewer retains
  enough semantic context to understand the conversation flow.
- **FR-047d**: The Reviewer client MUST NOT receive, cache, log,
  store, or render any unmasked PII. There MUST NOT be:
  (a) a "PII Masking" toggle visible to the Reviewer (the existing
  dev-Settings toggle is hidden / disabled for this role);
  (b) a "Click to reveal" affordance, hover tooltip, or any other UI
  control that reveals the underlying text on any masked element;
  (c) any deanonymisation API call, console log, or developer-tool
  inspection path that surfaces the original PII;
  (d) any export, download, copy-to-clipboard, or screen-capture
  helper that bypasses the masking layer (the Reviewer can still use
  native browser copy on the masked text — the masked placeholder
  IS the canonical content).
- **FR-047e**: PII reveal-on-demand and any deanonymisation workflow
  is reserved for higher-privilege roles (Supervisor, Master) and
  is OUT OF SCOPE for 058. Building such a control into the Reviewer
  surface is prohibited even behind a feature flag.
- **FR-047f**: The PII detector failing to mask known PII patterns
  MUST be treated as a critical bug and tracked through the security
  channel; no Reviewer-side fallback "show raw" mode exists.

#### Data isolation and audit

- **FR-048**: Reviewer A MUST NOT be able (via UI or via direct request)
  to see ratings/tags/flags/comments authored by Reviewer B in any session.
- **FR-049**: Every Reviewer action (create/change rating, tag, flag, send
  change request, successful/failed login, logout) MUST be written to the
  Audit Log with fields: timestamp, user ID, role, IP, target (object of
  the action), event type.
- **FR-050**: The Audit Log MUST be append-only (no UI or API for editing
  or deleting entries) and accessible only to Administrators and Masters.
- **FR-050a**: Audit Log retention MUST be 5 years (60 months) total,
  organised in three tiers:
  (a) Hot tier — online, full-query latency, for entries 0–12 months
  old; queryable by the Audit Log UI without restore.
  (b) Warm tier — online, higher-query latency acceptable, for
  entries 12–36 months old; queryable through the same UI but with
  a documented degraded SLA.
  (c) Cold archive tier — restore-on-request, for entries 36–60
  months old; not directly queryable in the live UI; restore
  requests are themselves recorded as Audit Log entries.
  The 5-year window applies uniformly to every event category
  emitted by 058 (login success / fail, logout, rating CRUD, tag
  attach / detach / soft-delete / restore, Red Flag raise / clear,
  change-request send, notification.read, settings change including
  required-count change, and any other event added by this
  feature).
- **FR-050b**: Automated purge of entries older than 60 months MUST
  be performed by an offline retention job. Each purge run MUST
  itself emit exactly one Audit Log entry capturing the run sequence
  ID, the count of removed records, and the time window covered, so
  the chain of custody remains verifiable forever. Purge MUST honour
  a per-record `legal_hold` boolean flag — entries with the flag
  set are excluded from purge regardless of age. The flag itself is
  out of scope for 058 (no UI to set it within this feature) but
  the data model MUST support it as a no-op pass-through field so
  upstream features can introduce its lifecycle later.

### Key Entities

- **Reviewer (Researcher)**: An account holding the Reviewer role; is a
  member of one or more Spaces; sees chat sessions whose user belongs
  to any of those Spaces; has their own draft and completed-review
  streams isolated from other Reviewers.
- **Space**: An organisational scope grouping chat users and Reviewers.
  Every chat user (and therefore every chat session) belongs to exactly
  one Space; every Reviewer is a member of zero or more Spaces. A
  Reviewer's Review Queue is the union of finalised chat sessions
  across the Spaces they are currently a member of, scoped further by
  the header Space dropdown selection. Membership is managed upstream
  (admin/Supervisor surface — out of scope for 058) but is read by 058
  via the existing Spaces API.
- **Chat Session**: An anonymised record of a conversation between an
  end-user and the AI assistant; consists of a sequence of user/assistant
  messages; has a unique ID, a timestamp, a `space_id` attribute
  identifying the owning Space (inherited from the chat user), a
  `language` attribute (locale code such as `uk`/`ru`/`en` from a
  dynamic supported-locales set matching the language of the underlying
  conversation), and aggregated indicators (message count, risk level).
  Once a chat session ends, it is automatically routed into the Review
  Queue of its `space_id` Space and becomes visible to every Reviewer
  who is a member of that Space.
- **Message**: A single message in a session (from the user or the
  assistant); a message can carry clinical tags and/or a Red Flag.
- **Rating**: A Reviewer's record about the quality of a specific
  assistant reply; carries a 1–10 score, an optional/mandatory criterion
  with a stable ID from the hard-coded set (`relevance`, `empathy`,
  `psychological_safety`, `ethical_integrity`, `clarity_tone`,
  `request_match`, `autonomy`, `artificiality`), a comment, a "Validated
  answer", an author (Reviewer), a timestamp, and a `version_status`
  attribute (`canonical` or `superseded`).
- **Clinical Tag**: A clinical-signal label (Anxiety, Burnout, Depression,
  PTSD, etc.) attached to a specific message in a session; has an author
  (Reviewer), a `language_group` attribute holding one or more locale
  codes (controls in which chat languages the tag is offered), a
  `description` free-text field surfaced as a hover tooltip on every
  tag chip, an `expert_assignments` set linking it to one or more
  Experts for routing (Tag Center managed), and a nullable `deleted_at`
  timestamp for the soft-delete lifecycle (FR-021b). Each attachment
  is linked to the corresponding Message Tag Comment for the (message,
  Reviewer) pair. Existing clinical tags default to `language_group =
  ["uk"]` until updated through the Tag Center language-attribute UI
  (parallel feature dependency).
- **Review Tag**: An organisational session-level label (e.g.,
  `loop-regression`, `compat-tag3`) attached by Reviewers to categorise
  sessions; has a `language_group` attribute (same shape and same
  canonical Tag Center UI component as Clinical Tag), a `description`
  free-text field surfaced as a hover tooltip, NO expert-assignment
  property, and a nullable `deleted_at` timestamp for the soft-delete
  lifecycle (FR-021b). Review Tags are visible across Reviewers in the
  same Space (unlike Clinical Tags, which are private per-Reviewer).
  Existing review tags default to `language_group = ["uk"]` until
  updated.
- **Message Tag Comment**: A per-message comment authored by the
  Reviewer that explains the clinical tags they attached to that
  specific message. Scope is the (message, Reviewer) pair: tags from
  the same Reviewer on the same message share that one comment; tags
  on a different message require their own comment. Submit requires
  every tagged message to have a non-empty Message Tag Comment.
- **Red Flag**: A critical-situation marker on a specific message; has a
  mandatory description, an author (Reviewer), a timestamp.
- **Review**: The full bundle of one Reviewer's ratings for all assistant
  replies in a session, plus their tags, flags, session-level comment, and
  state (draft/completed/repeat). Drafts are autosaved; completed reviews
  are read-only.
- **Change Request**: The Reviewer's request to the Supervisor to allow
  editing of a completed review; has a reason, an author, a timestamp, a
  status (pending/approved/rejected) and the Supervisor's decision.
- **Status Label**: A session-card sub-label: NEW, UNFINISHED, REPEAT,
  COMPLETED, URGENT — describes the session's current position in the
  Reviewer flow.
- **Rating Version History**: An audit-only per-session collection
  containing every `superseded` rating with its full payload (score,
  criterion, comment, validated answer, author, timestamp); accessible
  only to the Supervisor and Administrator/Master in a "version history"
  panel.
- **Audit Log Entry**: An append-only record of an action in the system
  with fields timestamp, user, role, IP, target, event type. The data
  model MUST also carry a nullable `legal_hold` boolean (default
  false) used by the upstream retention job to exempt the entry from
  the 5-year purge (FR-050b); 058 itself never sets this flag, but
  the field MUST exist and pass through unchanged.
- **Administrator Setting `verbose_autosave_failures`**: A single
  Administrator-managed boolean (default OFF) controlling whether the
  Reviewer client surfaces a toast on every transient save failure
  (ON) or only after persistent failure across all retries (OFF).
  Rendered as a canonical design-system Toggle.
- **Canonical Toggle Component**: The single design-system Toggle used
  by every boolean control introduced or modified in this feature
  (today: `verbose_autosave_failures`). If absent at implementation
  time, this feature MUST introduce it; all future toggles MUST reuse
  the same component (no parallel implementations).
- **Offline Queue Entry**: A persisted (browser IndexedDB) save payload
  awaiting backend availability; replayed in original order once the
  `ping` endpoint recovers; cleared on successful sync.
- **E2E Suite Module**: A YAML set of automated test cases for dev runs
  covering every Reviewer scenario; uses test IDs RQ-001..RQ-NNN, P0/P1/P2
  priorities, and explicit links to the acceptance criteria above.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of acceptance scenarios across all 8 user stories pass
  manually and in E2E on dev (workbench.dev.mentalhelp.chat) before the
  feature branch is merged.
- **SC-002**: Every edge case (EC-01..EC-11) has at least one automated
  test in the new E2E module.
- **SC-003**: A Reviewer can fully complete a review of an average session
  (4–8 messages) in ≤ 5 minutes, from opening the card to confirming
  submit, with no blocking UX issues (no page reloads, no draft loss, no
  unexplained disabled buttons).
- **SC-004**: Data isolation: 0 cross-Reviewer leak cases (verified by a
  dedicated E2E test using two distinct Reviewer accounts and probing both
  the UI and direct server requests).
- **SC-005**: The new E2E module for Reviewer Review Queue runs green on
  dev for at least 3 consecutive runs immediately before merge.
- **SC-006**: The Audit Log contains an entry for every one of the
  following Reviewer action types: rating, tag, Red Flag, change request,
  successful login, failed login, logout — verified in a dedicated E2E test
  for FR-049/FR-050.
- **SC-007**: Event-driven autosave: every input `blur` and every
  page-unload event flushes the corresponding change to the backend;
  after forced tab close and reopen within an hour the authoritative
  state is restored at 100% (every previously-entered field is
  present), with no field lost due to missed flushes.
- **SC-008**: Offline-mode recovery: while in offline mode the UI
  remains responsive (input latency < 100 ms, no spinners on every
  keystroke); after the `ping` endpoint recovers, queued offline
  changes finish replaying within ≤ 5 seconds for queues up to 50
  pending entries, and the offline banner disappears within 1 second
  of the final successful sync.
- **SC-009**: Smoke E2E (P0, at least 5 tests) runs in ≤ 10 minutes;
  standard (P0+P1) in ≤ 30 minutes; full (P0+P1+P2) in ≤ 60 minutes.
- **SC-010**: 0 console errors and 0 unacceptable network errors (HTTP
  ≥ 400 against endpoints not covered by `known_acceptable_network`)
  during the smoke run.
- **SC-011**: Repeat-rating canonicality: in 100% of REPEAT-flow E2E
  scenarios the new rating shows up in Reports/Score Distribution/Average
  Score Trend within 60 seconds of submit, while the `superseded` primary
  rating is excluded from all analytics aggregates and is reachable only
  via the version-history panel.
- **SC-012**: At scale Pending and Completed tabs deliver Time-To-
  Interactive (TTI) ≤ 1.5 seconds for the first page (25 sessions) and
  ≤ 1.0 second for subsequent page navigations, on dev hardware against a
  queue of at least 250 sessions; chip-filter, date-filter and language-
  filter changes trigger a server fetch that returns within 1.0 second
  (P95).
- **SC-013**: Submit gating correctness: in 100% of E2E scenarios that
  attempt Submit with one or more required fields unfilled (per
  FR-018a..e), the Submit button is observed disabled and the
  outstanding requirement is surfaced inline near the relevant
  message/field.
- **SC-013a**: Space-based isolation: a dedicated E2E test confirms
  that with two Reviewers (one in Space A only, one in Space B only)
  neither sees the other's Space sessions in queue or Reports; a third
  Reviewer in both Spaces sees the union; on removal of a Reviewer
  from a Space, the corresponding sessions disappear from the UI within
  one Space-dropdown reload.
- **SC-013b**: UI-locale vs session-language separation: a dedicated
  E2E test switches the Reviewer header locale to each supported
  locale in turn and confirms that (a) sidebar / criteria / score
  tooltips / paginator / banners switch language accordingly, and
  (b) Clinical Tag and Review Tag selectors inside an open session
  remain in the session's chat language regardless of the header
  locale change.
- **SC-013c**: Tag tooltip parity: a dedicated E2E test confirms that
  hovering any Clinical Tag chip and any Review Tag chip — in the
  selector, on the transcript, and on the session card — shows the
  tag's `description` as a tooltip; tags with empty description show
  no tooltip (no empty-tooltip artefact).
- **SC-013d**: Submit-during-replay correctness: a dedicated E2E test
  forces the backend `ping` endpoint into a 5-second outage while the
  Reviewer queues 5 changes, then restores ping; the test asserts that
  during the replay window the Submit button label transitions through
  `⟳ Submit (5)` → `⟳ Submit (4)` → … → `⟳ Submit (1)` → `Submit`
  (enabled), that the button is observed disabled until the queue
  reaches zero, and that no Submit POST is fired before the queue is
  fully drained.
- **SC-013e**: Notification category coverage: a dedicated E2E test
  triggers each of the three in-scope categories
  (`change_request.decision`, `red_flag.supervisor_followup`,
  `space.membership_change`) and asserts that each surfaces through
  both the persistent banner and the bell-icon list with the correct
  payload, that explicit Dismiss removes the banner / increments the
  read count, and that a corresponding `notification.read` Audit Log
  entry is recorded (linking back to FR-049 / FR-050).
- **SC-013f**: Counter freshness: a dedicated E2E test runs two
  Reviewer accounts in the same Space against a single session;
  Reviewer A keeps the Pending tab open while Reviewer B opens the
  session and submits a finalised review; the test asserts that
  Reviewer A's session card updates from "X / Y" to "X+1 / Y" within
  60 seconds with no manual page reload, and within ≤ 2 seconds when
  Reviewer A performs any refresh-on-action trigger from FR-008a.
- **SC-013g**: Accessibility: 0 axe-core critical violations and 0
  axe-core serious violations across every Reviewer-facing route
  during the smoke E2E run; static contrast / focus / keyboard
  navigation checks pass for every interactive control listed in
  FR-047a; the Submit countdown label and the offline / notification
  banners are observed announcing changes via `aria-live=polite`
  regions in screen-reader emulation mode.
- **SC-013h**: State coverage: a dedicated E2E test sweep visits each
  Reviewer-facing list / data area in turn (Pending empty, Pending
  with filters returning zero, Completed empty, Reports period with
  no data, notification bell empty, queue fetch failure simulated
  with a network intercept) and asserts that each renders the
  prescribed loading / empty / error state per FR-046a..e: skeleton
  visible within 200 ms; the right empty illustration + headline
  combination per situation; on simulated failure, an error state
  with code, description, Retry CTA, support link, and a console
  error log line.
- **SC-013i**: Soft-delete behavior: a dedicated E2E test attaches a
  clinical and a review tag to a message, then triggers Tag Center
  soft-delete of both via test fixture; on the next refresh the test
  asserts that the tags vanish from the Reviewer-facing selector but
  their existing chips render with the "(deleted)" prefix and the
  retirement-date tooltip; for the Clinical Tag, a freshly-tagged
  session created AFTER deletion does not route to the previously
  assigned Expert, while the original session continues routing. A
  soft-delete + restore round-trip leaves exactly two corresponding
  Audit Log entries.
- **SC-013j**: Required reviewer count change correctness: a dedicated
  E2E test seeds a session at X = 2 / 3 in Pending and triggers a
  Required reviewer count decrease from 3 to 2; the test asserts the
  session disappears from the Pending tab on the next refresh, the
  Audit Log gains a `review_settings.required_count_changed` entry
  with old=3 and new=2, and a separate seeded session at X = 2 / 2
  awaiting completion under a 2-to-4 increase shifts to X = 2 / 4 and
  remains Pending — and previously Completed sessions stay Completed
  in both directions.
- **SC-013k**: Multi-tab reconciliation correctness: a dedicated E2E
  test opens the same session in two browser contexts simulating two
  tabs of the same Reviewer. Scenario A (non-conflicting): edits in
  tab A propagate to tab B on focus-fetch with the inline "Updated by
  another tab" indicator and zero cursor jumps in fields the user
  hadn't touched. Scenario B (conflicting): a field actively being
  typed in tab B is NOT overwritten by the server value, an inline
  conflict indicator appears with the competing value visible on
  hover, and on next blur the local value wins on the server. In
  both scenarios the editing surface is observed gated for the
  duration of the focus-fetch round-trip and unblocked once
  reconciliation completes.
- **SC-013l**: Responsive parity: a dedicated E2E test sweep runs
  the Reviewer happy path (login → open queue → open session →
  rate → submit) at three viewport widths — 1280 px (desktop),
  768 px (tablet portrait), 360 px (mobile portrait). Desktop and
  tablet runs MUST complete the full happy path including submit;
  mobile MUST render the Pending list, the Completed list, the
  Reports surface, the notification bell, and the "switch to wider
  device to rate" prompt instead of the editor. Touch targets on
  tablet are observed ≥ 44×44 px; no horizontal scroll on Pending
  / Completed feeds at 360 px.
- **SC-013m**: PWA installability: a dedicated check confirms the
  Workbench shell exposes a valid manifest with all required keys,
  a service worker registers successfully on a clean profile, and
  Lighthouse PWA category score ≥ 90 on the Reviewer-facing
  routes.
- **SC-013n**: Browser parity: the Playwright E2E suite runs the
  smoke set on both Chromium and WebKit project configurations and
  passes green on both; a documented manual smoke run on the latest
  stable Firefox passes for the same set; a Lighthouse audit at
  the Chromium baseline reports 0 critical browser-compat warnings
  for any officially-supported browser.
- **SC-013p**: PII protection: a dedicated E2E test seeds a chat
  session containing every PII category enumerated in FR-047c
  (synthetic but realistic name, email, phone, address, medical
  record number, DOB, geo, employer reference); the test asserts
  that every value is replaced with the matching `[REDACTED:type]`
  placeholder in (a) the rendered transcript DOM, (b) the underlying
  network response payload, (c) any session-detail API response, and
  (d) the browser console output. The test also asserts that the
  Reviewer UI exposes no PII Masking toggle, no reveal control, no
  hover-to-reveal tooltip on any masked element, and no
  deanonymisation API endpoint reachable with the Reviewer's token.
- **SC-013q**: Audit Log retention: a verification check on the
  retention job confirms that (a) entries between 12 and 36 months
  old remain online-queryable through the Audit Log UI; (b) entries
  between 36 and 60 months old are reachable only via a restore
  request that itself appears in the live Audit Log; (c) the most
  recent automated-purge entry is present with a sequence ID, a
  removed-record count, and a time-window field; (d) seeded
  `legal_hold = true` records older than 60 months are NOT purged.

- **SC-013o**: Performance budget enforcement on the dev tier:
  (a) session-detail TTI ≤ 2.0 s desktop / ≤ 3.0 s tablet for a
  16-message session;
  (b) autosave request P95 round-trip ≤ 500 ms (measured from
  request fire to server ack);
  (c) focus-fetch reconciliation P95 ≤ 800 ms (measured from
  gating overlay show to dismiss);
  (d) chat transcript sustained ≥ 60 FPS scrolling on the desktop
  baseline;
  (e) initial bundle (gzipped JS + CSS) for the Reviewer route
  ≤ 350 KB;
  (f) queue-page Core Web Vitals: LCP ≤ 2.5 s, CLS ≤ 0.1, FID
  ≤ 100 ms.
  Each metric is captured by a dedicated Lighthouse / Playwright
  trace check; any regression beyond budget fails CI for the
  feature branch.
- **SC-014**: Toggle reuse: a static check (lint / inventory) confirms
  this feature introduces zero new toggle component implementations
  beyond the canonical design-system Toggle; the
  `verbose_autosave_failures` admin setting renders through the
  canonical Toggle; default state is OFF (gray).

## Assumptions

- The dedicated test account `e2e-researcher@test.local` (matching the
  `researcher` key in `regression-suite/_config.yaml`) is used as the
  Reviewer fixture; the "Researcher" role label is semantically equivalent
  to the MVP "Reviewer" role.
- 2FA is delivered via two paths: production — TOTP (Google Authenticator/
  Authy) per OQ-06 of the MVP; dev and staging — email OTP via browser
  console (current dev-infrastructure behaviour). E2E runs on dev extract
  the OTP from console logs using the existing pattern `Code:\s+(\d{6})`.
- The default inactivity timeout is 30 minutes (OQ-07), configurable by the
  Administrator. This feature does not implement a UI for setting the
  timeout; it consumes the existing server value.
- The email infrastructure (SMTP and templates) already exists or is
  delivered by a separate feature; this feature only triggers the events
  and verifies that send happened (e.g., via test inbox or metadata).
- The Tag Center (admin CRUD over Clinical Tags AND Review Tags) exists
  or is delivered by an adjacent feature; this feature only consumes
  the resulting tag lists via API. A separate parallel feature MUST
  extend the Tag Center to add a `language_group` attribute (set of
  locale codes) to BOTH Clinical Tags AND Review Tags, plus to every
  Expert tag-assignment, using a SINGLE canonical UI component (two-
  letter locale badges next to each tag's edit controls + dropdown
  over the dynamic supported-locales list — today UK / RU / EN). The
  same canonical component MUST also render the `description` field
  inline on the tag editor for both families. The expert-assignment UI
  MUST be present for Clinical Tags only; it MUST be hidden for Review
  Tags. Existing tags (both families) MUST be migrated to
  `language_group = ["uk"]` by default. Without that parallel feature,
  FR-021a, FR-024c, FR-024d, FR-024e and the language model on the
  Review Queue cannot ship — it is a hard dependency for 058.
- The roles & permissions infrastructure (RBAC) is present at the server
  layer; this feature only exercises existing rules for the Reviewer role
  and does not implement the engine itself.
- The Spaces subsystem (Space entity, Reviewer-to-Space membership,
  chat-user-to-Space association, and the Spaces API) is delivered
  upstream and is consumed read-only by 058. Space membership management
  (creating Spaces, adding/removing members, assigning chat users to
  Spaces) is out of scope for this feature.
- Expert and Supervisor are separate roles; for scenarios that require
  their participation (e.g., visibility of a tagged session in the expert
  queue) test accounts `expert` and `moderator` (or equivalent) are used in
  E2E.
- Reports for the Reviewer reuse the existing Reports component with
  additional filtering by data ownership; no separate page is created.
- The 8 evaluation criteria are hard-coded in the system with stable IDs
  and i18n-localised labels; admin CRUD of the criteria list is out of
  scope and may be picked up by a later feature if needed.
- Repeat ratings supersede primary ratings: the canonical version drives
  all analytics and the current Supervisor view; primary records persist
  for audit purposes only.

## Dependencies

- The existing authentication infrastructure with email-OTP support on dev
  (delivered via browser console) and TOTP support in production (or its
  delivery via an adjacent 2FA-TOTP feature if not yet ready in
  production).
- The existing Tag Center with CRUD of clinical tags.
- The existing Audit Log mechanism (the 2026-04-16 audit confirmed the
  page is reachable but server queries return an error — this dependency
  must be repaired separately or as part of this feature's NF-03 test
  bring-up).
- The existing email infrastructure for sending notifications to
  Supervisors and Reviewers.
- The existing RBAC infrastructure (Principal Groups, Permissions,
  Assignments, Effective Permissions) with rules for the Reviewer role.
- The Playwright-MCP regression suite under `regression-suite/` with
  support for `execution_order` and the three levels (smoke/standard/
  full).

## Out of Scope

- Functional behaviour of the Supervisor, Expert, Admin and Master roles
  (test accounts for these roles are used only to verify visibility in
  E2E).
- Expertise UI (Expert Assessments page) and Supervision UI (Supervision
  Queue page) implementation details.
- Email templates and SMTP configuration — only triggers and a
  send-happened verification, not template editing.
- Admin CRUD of tags / rules / settings (clinical-tag CRUD, review-
  tag CRUD, required-reviewers count configuration, etc.) — except for
  two additions IN scope here: (a) the `language_group` and
  `description` attributes UI for BOTH Clinical Tags and Review Tags,
  delivered as the parallel Tag Center extension documented under
  Dependencies (using one canonical component with the expert-
  assignment slot hidden for Review Tags); and (b) the
  `verbose_autosave_failures` Administrator boolean setting with its
  canonical Toggle (FR-031c, FR-031d).
- The Audit Log `legal_hold` lifecycle — the boolean field is
  defined and respected by the retention job (FR-050a / FR-050b),
  but the UI / API for setting or clearing it lives in a separate
  upstream feature.
- PII reveal-on-demand for any role (Supervisor, Master, etc.) —
  058 only specifies the Reviewer-side mask-everything behaviour
  (FR-047c..f). Higher-privilege deanonymisation flows are owned
  by a separate feature.
- Building the two-factor authentication subsystem from scratch — only
  consumption of the existing OTP and TOTP paths.
- Implementing the server-side RBAC engine — only consumption of existing
  rules.
- Repairing the Audit Log backend API (if the "Failed to query audit log"
  bug persists after this feature's verification it will be tracked as a
  separate bugfix feature; this spec only owns the NF-03 test).
- Database schema changes or migrations — those belong to the target
  repository; this spec does not prescribe backend storage.
- Admin CRUD over the criterion list (`relevance`, `empathy`, etc.) — the
  set is hard-coded in this feature; configurability may be picked up by a
  later feature if needed.

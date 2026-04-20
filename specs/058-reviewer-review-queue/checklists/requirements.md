# Specification Quality Checklist: Reviewer Review Queue — Full Implementation and E2E Validation

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-04-16
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed
- [x] Document language is English (per Constitution principle on Markdown language)

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic (no implementation details)
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## Validation Notes

### Iteration 1 (2026-04-16) — initial draft + clarification round 1

- Original draft authored in mixed Russian/English; rewritten to
  English-only after a constitution reminder from the owner (principle
  requiring all repository Markdown to be English-only).
- Five Round-1 clarifications integrated:
  1. 2FA strategy split (dev: email OTP via console; prod: TOTP).
  2. Criteria list hard-coded with stable IDs and i18n labels.
  3. Repeat-rating canonicality (`canonical` vs `superseded`).
  4. Pending sub-label filtering via single-list chip bar (no sub-tabs).
  5. Performer filter on Reports is hidden completely (DOM-absent).

### Iteration 2 (2026-04-16) — clarification round 2

- Five Round-2 clarifications integrated:
  1. Server-side pagination, page size 25, with numbered pages; chip /
     date / language filters all server-side; tab badges keep total
     unfiltered counts.
  2. Tags and Red Flags are editable / deletable before submit; each
     create / update / delete writes a separate Audit Log entry; after
     submit everything becomes read-only.
  3. In-app notifications use a persistent top banner plus a header
     bell-icon unread badge; explicit Dismiss is required and emits a
     `notification.read` Audit Log entry; no auto-hide.
  4. Language model: each Chat Session carries a `language` attribute;
     each Clinical Tag carries a `language_group` attribute (multi-
     locale set); Reviewer-side tag selector and the Review Queue
     language filter both honour that model; Tag Center extension
     (admin language-group constructor with two-letter badges and
     dropdown over the dynamic locale list) is a hard parallel
     dependency.
  5. Composite autosave + UX answer:
     (a) State is authoritative on the backend; saves are event-driven
     on every input `blur` plus a `beforeunload`/`pagehide` flush.
     (b) Backend `ping` endpoint distinguishes full outage (offline
     mode + warning banner + IndexedDB queue + Submit disabled) from
     transient single-request failure (3 retries with exponential
     backoff).
     (c) Toast verbosity gated by Administrator setting
     `verbose_autosave_failures` (default OFF), rendered through the
     canonical design-system Toggle (introduce one if missing; no
     parallel implementations).
     (d) Clinical-tag comment is per-tagged-message, not per-session
     shared (overrides the original MVP wording); Submit stays
     disabled until every tagged message has its own non-empty tag
     comment alongside every other required field.
- The spec now contains:
  - 60+ functional requirements (FR-001..FR-050 plus inserted
    FR-009a, FR-009b, FR-009c, FR-021a, FR-022 (rewritten), FR-023a,
    FR-027a, FR-031a..d, FR-039a) covering access, auth, queue tabs
    with pagination/chip/language filters, rating workflow, clinical
    tags with per-message comments, Red Flag editability, autosave
    event-driven model with offline mode and admin verbosity setting,
    canonical Toggle reuse, finalisation / change requests with
    persistent banner notifications, Reports with hidden performer
    filter, data isolation and audit logging.
  - 14 edge cases (EC-01..EC-14) including new EC-12 (full backend
    outage), EC-13 (transient single-request failure with verbose
    OFF), and EC-14 (Submit blocked by missing per-message tag
    comment).
  - 14 measurable success criteria (SC-001..SC-014), including
    SC-007 / SC-008 (event-driven autosave + offline recovery
    timings), SC-012 (paginated tab TTI at scale), SC-013 (Submit
    gating correctness), and SC-014 (Toggle reuse static check).
  - 8 user stories with priorities P1..P3.
- 0 [NEEDS CLARIFICATION] markers remain after Round 2.

### Iteration 3 (2026-04-16) — clarification round 3

- Five Round-3 clarifications integrated:
  1. Space-driven session assignment (no per-Reviewer push, no admin
     intervention): every chat user belongs to one Space; Reviewer is a
     member of one or more Spaces; finished chats land in the Review
     Queue of the chat user's Space; the header Space dropdown lists
     only the Reviewer's member Spaces plus "All Spaces" (union of
     those). New entity Space, FR-010 / FR-010a / FR-010b, EC-09a /
     EC-09b for membership churn, SC-013a for isolation.
  2. Reviewer UI locale follows a per-user preference (header switcher
     mirrored in Settings; default browser-locale, fallback en) while
     Clinical Tag and Review Tag selectors continue to follow the chat
     session's language. New FR-002a, SC-013b. Review Tags brought
     into the spec as a first-class concept symmetrical to Clinical
     Tags (FR-024a..f, new entity Review Tag) reusing the same
     canonical Tag Center constructor component for language
     assignment; review tags carry a `description` shown as hover
     tooltip; expert-assignment UI hidden for them. SC-013c covers
     tag-tooltip parity.
  3. Submit-during-replay UX: button stays disabled with label
     `⟳ Submit (N)` until the offline queue is fully drained
     (FR-018a, EC-12 update, SC-013d).
  4. Notification scope locked to three categories
     (`change_request.decision`, `red_flag.supervisor_followup`,
     `space.membership_change`): FR-039b, SC-013e.
  5. X / Y counter freshness uses refresh-on-action plus 60-second
     background polling (no real-time push, no optimistic increment):
     FR-008a, EC-15, SC-013f.
- The spec now contains 70+ functional requirements (latest additions:
  FR-002a, FR-008a, FR-010, FR-010a, FR-010b, FR-018a, FR-024a..f,
  FR-039b), 16 edge cases (EC-01..EC-15 plus EC-09a / EC-09b), and
  19 success criteria (latest additions SC-013a..f).
- Three Clarifications sessions logged (Round 1 + Round 2 + Round 3);
  15 distinct clarification questions answered total.
- 0 [NEEDS CLARIFICATION] markers remain after Round 3.

### Iteration 4 (2026-04-16) — clarification round 4

- Five Round-4 clarifications integrated:
  1. WCAG 2.1 Level AA conformance for every user-facing UI element
     introduced or modified by 058; axe-core / lighthouse run inside
     E2E; critical / serious violations block merge. New section
     Accessibility (FR-047a, FR-047b), SC-013g.
  2. Coordinated empty / loading / error states with skeleton
     placeholders, contextual flat vector illustrations + headlines
     + CTA, and `aria-live` announcements. New section Empty /
     loading / error states (FR-046a..e), SC-013h.
  3. Tag-soft-delete model: tags marked `deleted_at` rather than
     hard-removed; new attachments impossible; existing chips render
     "(deleted)" with retirement-date tooltip; Clinical Tag routing
     halts post-deletion timestamp; Audit Log entries on delete /
     restore. FR-021 update + new FR-021b, EC-16, SC-013i; Clinical
     Tag and Review Tag entities gain `deleted_at`.
  4. Required reviewer count changes apply forward-only to non-
     completed sessions; no retroactive reopening; auto-completion on
     decrease, continued waiting on increase. FR-008 update + new
     FR-008b, EC-17, EC-18, SC-013j.
  5. Multi-tab reconciliation: same session may be opened in
     multiple tabs of the same Reviewer; on every tab-focus the tab
     fetches fresh state and reconciles per-field against a snapshot
     captured at focus return — non-edited fields update silently,
     fields the user is typing in are preserved with a conflict
     indicator, equal fields cause no DOM rewrite. New FR-034a,
     EC-19, EC-20, SC-013k.
- The spec now contains 80+ functional requirements (latest additions
  FR-008b, FR-021b, FR-034a, FR-046a..e, FR-047a, FR-047b), 20 edge
  cases (EC-01..EC-20 plus EC-09a/EC-09b), and 24 success criteria
  (SC-001..SC-013k plus SC-014).
- Four Clarifications sessions logged (Round 1 + Round 2 + Round 3 +
  Round 4); 20 distinct clarification questions answered total.
- 0 [NEEDS CLARIFICATION] markers remain after Round 4.

### Iteration 5 (2026-04-16) — clarification round 5

- Five Round-5 clarifications integrated:
  1. Responsive scope: desktop and tablet (≥ 768 px) full fidelity;
     mobile (360–767 px) read-only triage with a "switch to wider
     device to rate" prompt; PWA installability via reuse of the
     existing workbench-pwa shell. New section Responsive and PWA
     (FR-046f, FR-046g), SC-013l, SC-013m.
  2. Browser support matrix locked to evergreen Chromium / latest
     stable Firefox / latest stable Safari (incl. Safari iPadOS),
     latest 2 majors each; legacy browsers explicitly out;
     graceful "browser not supported" page on hard prerequisite
     misses. New section Browser support (FR-046h, FR-046i),
     SC-013n.
  3. Explicit performance budget: session-detail TTI ≤ 2.0 s
     desktop / ≤ 3.0 s tablet (16 messages); autosave round-trip
     P95 ≤ 500 ms; focus-fetch reconciliation P95 ≤ 800 ms;
     transcript scroll ≥ 60 FPS; initial bundle ≤ 350 KB gzipped;
     queue page LCP ≤ 2.5 s, CLS ≤ 0.1, FID ≤ 100 ms. New SC-013o.
  4. PII handling: mandatory server-side masking before the
     Reviewer payload; no toggle, no reveal-on-demand, no
     hover-reveal, no deanonymisation control on the Reviewer
     surface — reveal flows reserved for higher-privilege roles
     outside 058. New section Privacy and PII protection
     (FR-047c..f), SC-013p; Out of Scope updated.
  5. Audit Log retention: 5 years total, tiered hot (0–12 mo) /
     warm (12–36 mo) / cold archive (36–60 mo); automated purge
     after 60 mo with its own audit entry per batch; `legal_hold`
     pass-through field. FR-050 update + new FR-050a / FR-050b,
     Audit Log Entry entity update, SC-013q; Out of Scope updated
     to mention `legal_hold` lifecycle.
- The spec now contains 90+ functional requirements (latest additions
  FR-046f, FR-046g, FR-046h, FR-046i, FR-047c..f, FR-050a, FR-050b),
  still 20 edge cases (EC-01..EC-20 + EC-09a/EC-09b), and 30 success
  criteria (SC-001..SC-013q + SC-014).
- Five Clarifications sessions logged (Rounds 1–5); 25 distinct
  clarification questions answered total.
- 0 [NEEDS CLARIFICATION] markers remain.

### Notes

- Items marked incomplete require spec updates before `/speckit.clarify` or `/speckit.plan`.
- Spec is ready to advance to `/speckit.clarify` (optional, for any
  remaining clarification rounds) or directly to `/speckit.plan`.

# Tasks: Reviewer MVP Gap Closure

**Input**: Design documents from `specs/059-reviewer-mvp-gaps/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md
**Jira Epic**: [MTB-1458](https://mentalhelpglobal.atlassian.net/browse/MTB-1458)

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1–US11)
- Include exact file paths in descriptions

## Path Conventions

- `chat-types/src/` — shared TypeScript types
- `chat-backend/src/` — Express.js backend
- `workbench-frontend/src/` — React frontend (Reviewer surface)
- `chat-ui/tests/` — Playwright E2E
- `regression-suite/` — AI-runnable YAML harness

---

## Phase 1: Setup (Shared Infrastructure) — MTB-1459

**Purpose**: Feature branches, type updates, DB migration, shared assets

- [x] T001 Create branch `059-reviewer-mvp-gaps` from `develop` in `chat-types`, `chat-backend`, `workbench-frontend`, `chat-ui`, and `regression-suite` (this repo) — MTB-1473
- [x] T002 [P] Add `verbose_autosave_failures: boolean` and `inactivity_timeout_minutes: number` to admin settings type in `chat-types/src/adminSettings.ts` (or the file exporting `AppSettingsDto`) — MTB-1474
- [x] T003 [P] Add `'space.membership_change'` to notification category union type in `chat-types/src/notification.ts` (or relevant notification type file) — MTB-1475
- [x] T004 Publish `chat-types` minor release (bump `package.json` version, build, push tag) — MTB-1476
- [x] T005 Create DB migration `chat-backend/src/db/migrations/067_059-reviewer-mvp-gaps.sql` adding `verbose_autosave_failures BOOLEAN NOT NULL DEFAULT false` and `inactivity_timeout_minutes INTEGER NOT NULL DEFAULT 30` to admin settings table — MTB-1477
- [x] T006 Update `chat-backend/package.json` to consume the new `chat-types` version — MTB-1478
- [x] T007 Update `workbench-frontend/package.json` to consume the new `chat-types` version — MTB-1479
- [x] T008 [P] Create SVG illustration assets for empty/error states in `workbench-frontend/src/assets/illustrations/` (empty-inbox.svg, error-cloud.svg, no-results.svg, browser-unsupported.svg) — MTB-1480
- [x] T009 [P] Add i18n keys for all 059 components in `workbench-frontend/src/locales/en.json`, `uk.json`, `ru.json` — keys for retired tags, state components, unsaved modal, browser guard, submit countdown, inactivity timeout, verbose toggle, space notifications — MTB-1481

**Checkpoint**: All repos on feature branches, types published, migration ready, i18n keys and illustrations staged.

---

## Phase 2: Foundational (Blocking Prerequisites) — MTB-1460

**Purpose**: Shared frontend components that multiple user stories depend on

**CRITICAL**: US3 state components are used by almost every other surface; build them first.

- [x] T010 Create `LoadingSkeleton` component in `workbench-frontend/src/components/states/LoadingSkeleton.tsx` — accepts `variant` prop (list, detail, chart, settings) to render layout-mimicking skeletons; uses design-system neutral tokens; renders within 200ms of mount (FR-007) — MTB-1482
- [x] T011 [P] Create `EmptyState` component in `workbench-frontend/src/components/states/EmptyState.tsx` — accepts `illustration`, `headline`, `description`, `ctaLabel`, `onCta` props; centres composition; illustration is `aria-hidden=true`; headline is the accessible name (FR-008) — MTB-1483
- [x] T012 [P] Create `ErrorState` component in `workbench-frontend/src/components/states/ErrorState.tsx` — accepts `errorCode`, `description`, `onRetry`, `supportUrl` props; renders machine-readable code, localised description, Retry button, support link; echoes code to `console.error` on mount (FR-009) — MTB-1484
- [x] T013 Create `aria-live` announcement wrapper in `workbench-frontend/src/components/states/StateAnnouncer.tsx` — wraps headline region with `aria-live=polite` (error state upgrades to `assertive`); announces on state transitions (FR-010) — MTB-1485
- [x] T014 Write positive + negative tests for `LoadingSkeleton` in `workbench-frontend/src/components/states/__tests__/LoadingSkeleton.test.tsx` — positive: renders skeleton for each variant; negative: does not render a full-screen spinner — MTB-1486
- [x] T015 [P] Write positive + negative tests for `EmptyState` in `workbench-frontend/src/components/states/__tests__/EmptyState.test.tsx` — positive: renders illustration + headline + CTA; negative: CTA fires callback, illustration has `aria-hidden` — MTB-1487
- [x] T016 [P] Write positive + negative tests for `ErrorState` in `workbench-frontend/src/components/states/__tests__/ErrorState.test.tsx` — positive: renders error code + Retry + support link + calls console.error; negative: Retry fires onRetry callback, no bare message without code — MTB-1488

**Checkpoint**: Shared state components ready. All user story surfaces can import them.

---

## Phase 3: User Story 1 — Submit never races an offline queue flush (Priority: P1) MVP — MTB-1461

**Goal**: Submit button shows `⟳ Submit (N)` with live count during offline queue replay, stays disabled until queue drains.

**Independent Test**: Simulate offline → enqueue 3 ops → restore network → observe countdown → confirm Submit enables at zero.

- [x] T017 [US1] Modify Submit button rendering in `workbench-frontend/src/features/workbench/review/ReviewSessionView.tsx` — when `pendingOfflineCount > 0`, label becomes `⟳ Submit (N)` with live count; button stays disabled regardless of other gating conditions (FR-001, FR-002) — MTB-1489
- [x] T018 [US1] Wrap Submit label region with `aria-live=polite` in `workbench-frontend/src/features/workbench/review/ReviewSessionView.tsx` so screen readers announce the decrementing count (FR-003) — MTB-1490
- [x] T019 [US1] Write positive + negative tests in `workbench-frontend/src/features/workbench/review/__tests__/SubmitCountdown.test.tsx` — positive: label shows `⟳ Submit (3)` when count=3, decrements on ack, reverts to `Submit` at zero; negative: button disabled even when all other gating conditions pass if count > 0; edge: re-enqueue after brief enable flips back to disabled (EC: submit gating flips mid-replay) — MTB-1491

**Checkpoint**: Submit button countdown fully functional and tested.

---

## Phase 4: User Story 2 — Soft-deleted tags show "retired" marker (Priority: P1) — MTB-1462

**Goal**: Tag chips for soft-deleted tags render `(retired)` prefix with retirement date tooltip; retired tags excluded from selectors.

**Independent Test**: Soft-delete a tag attached to a session → open session → confirm `(retired)` chip + tooltip + tag hidden from selector.

- [x] T020 [P] [US2] Extend `TagChip` in `workbench-frontend/src/features/workbench/review/components/TagChip.tsx` — when `tag.deleted_at` is set, prepend localised `(retired)` prefix; on hover show tooltip "This tag was retired by an administrator on [date]" in active locale (FR-004, FR-005) — MTB-1492
- [x] T021 [US2] Filter retired tags from selectors in `workbench-frontend/src/features/workbench/review/ClinicalTagPicker.tsx` — exclude tags with `deleted_at` from the selectable options list; preserve existing attachments as read-only (FR-006) — MTB-1493
- [x] T022 [P] [US2] Apply same retired-tag filtering to session-level tag selector in `workbench-frontend/src/features/workbench/review/ReviewSessionView.tsx` — ReviewTagSelector also filters `deleted_at IS NOT NULL` from options — MTB-1494
- [x] T023 [US2] Write positive + negative tests in `workbench-frontend/src/features/workbench/review/__tests__/RetiredTagChip.test.tsx` — positive: chip renders `(retired) Anxiety` when deleted_at set, tooltip shows date in locale format; negative: retired tag absent from selector options; edge: restoring a tag removes the prefix on next render cycle — MTB-1495

**Checkpoint**: Retired tag rendering complete; no confusion between active and grandfathered tags.

---

## Phase 5: User Story 3 — Loading/empty/error states adopted everywhere (Priority: P1) — MTB-1463

**Goal**: Every Reviewer surface uses the shared state components consistently.

**Independent Test**: Force empty filters → illustration + CTA; force 503 → error code + Retry; slow network → skeleton.

- [x] T024 [P] [US3] Adopt `LoadingSkeleton`, `EmptyState`, `ErrorState` in `workbench-frontend/src/features/workbench/review/ReviewQueueView.tsx` — replace existing inline skeleton and ad-hoc empty/error rendering — MTB-1496
- [x] T025 [P] [US3] Adopt shared state components in `workbench-frontend/src/features/workbench/review/ReviewSessionView.tsx` — loading skeleton for session fetch, error state for session load failure — MTB-1497
- [x] T026 [P] [US3] Adopt shared state components in `workbench-frontend/src/features/workbench/review/ReportView.tsx` — replace existing error rendering with `ErrorState` — MTB-1498
- [x] T027 [P] [US3] Adopt shared state components in `workbench-frontend/src/features/workbench/review/ReviewDashboard.tsx` — replace `DashboardEmptyState` with shared `EmptyState`, add `LoadingSkeleton` and `ErrorState` — MTB-1499
- [x] T028 [P] [US3] Adopt shared state components in notification bell list rendering in `workbench-frontend/src/features/workbench/review/components/NotificationBell.tsx` — MTB-1500
- [x] T029 [US3] Write integration tests in `workbench-frontend/src/features/workbench/review/__tests__/SharedStatesAdoption.test.tsx` — positive: each surface renders skeleton on fetch, empty state on zero results, error state on failure; negative: no full-screen spinner on any surface; accessibility: `aria-live` region announces transitions — MTB-1501

**Checkpoint**: All Reviewer surfaces use consistent, localised state components. SC-003, SC-004 satisfied.

---

## Phase 6: User Story 4 — Multi-tab edits don't silently overwrite (Priority: P1) — MTB-1464

**Goal**: Tab focus return gates the editor, snapshots fields, reconciles per-field with visible indicators.

**Independent Test**: Open session in 2 tabs → edit in tab 1 → focus tab 2 and back → observe overlay, field update indicator, and conflict indicator.

- [x] T030 [US4] Extend `useFocusRefresh` hook in `workbench-frontend/src/features/workbench/review/offline/useFocusRefresh.ts` — on focus return: (a) capture snapshot of all editable field values, (b) set `isReconciling=true` to trigger overlay, (c) fire full session fetch, (d) on resolve run per-field reconciliation, (e) set `isReconciling=false` (FR-011) — MTB-1502
- [x] T031 [US4] Add reconciliation overlay to `workbench-frontend/src/features/workbench/review/ReviewSessionView.tsx` — when `isReconciling` is true, render a skeleton/spinner overlay over the editor area that blocks pointer events and keyboard input — MTB-1503
- [x] T032 [US4] Implement per-field reconciliation logic — in the session view state management: compare snapshot vs server values; if server differs and user has NOT typed since focus return → update field + show "Updated by another tab" indicator; if user HAS typed → preserve local + show conflict indicator with server value on hover (FR-011d) — MTB-1504
- [x] T033 [US4] Handle edge case: focus return while offline — if ping is failing, defer the gate/fetch sequence until ping recovers; editor stays usable with local buffer (EC: multi-tab reconciliation during offline) — MTB-1505
- [x] T034 [US4] Write positive + negative tests in `workbench-frontend/src/features/workbench/review/__tests__/MultiTabReconciliation.test.tsx` — positive: overlay appears on focus, field updated with indicator when server differs; negative: local edit preserved when user typed after focus, no DOM rewrite on identical values; edge: deferred reconciliation during offline — MTB-1506

**Checkpoint**: Multi-tab data integrity guaranteed. SC-005 satisfied.

---

## Phase 7: User Story 5 — Beforeunload is in-app modal (Priority: P2) — MTB-1465

**Goal**: In-app navigation with unsaved edits shows a localised confirmation modal instead of native browser dialog.

**Independent Test**: Start rating → click sidebar link → modal appears → "Stay" cancels → "Close" proceeds.

- [x] T035 [P] [US5] Create `UnsavedChangesModal` component in `workbench-frontend/src/components/UnsavedChangesModal.tsx` — two localised actions ("Close and lose unsaved data" / "Stay on page"); renders as a centered modal overlay with design-system tokens (FR-013) — MTB-1507
- [x] T036 [US5] Wire `UnsavedChangesModal` into `workbench-frontend/src/features/workbench/review/ReviewSessionView.tsx` using React Router `useBlocker` (or `unstable_useBlocker` depending on RR version) — modal fires on in-app navigation when unsaved edits exist; "Stay" cancels blocker; "Close" proceeds and flushes pending writes via beforeunload handler (FR-014) — MTB-1508
- [x] T037 [US5] Write positive + negative tests in `workbench-frontend/src/components/__tests__/UnsavedChangesModal.test.tsx` — positive: modal renders on blocked navigation, "Stay" cancels, "Close" proceeds; negative: modal does not appear when no unsaved edits; verify native beforeunload still fires for browser close/refresh — MTB-1510

**Checkpoint**: In-app navigation guard complete. Native beforeunload preserved as fallback.

---

## Phase 8: User Story 6 — Inactivity timeout matches spec (Priority: P2) — MTB-1466

**Goal**: Inactivity timeout default is 30 min, admin-configurable via Settings UI, backend enforces.

**Independent Test**: Set timeout to 5 min in admin UI → idle for 5 min → redirected to login → re-login → draft preserved.

- [x] T038 [US6] Extend `chat-backend/src/services/settings.service.ts` — add `getInactivityTimeout()` that reads `inactivity_timeout_minutes` from DB with 60s in-process cache, falls back to `SESSION_TIMEOUT_MINUTES` env var — MTB-1509
- [x] T039 [US6] Modify `chat-backend/src/middleware/sessionTimeout.middleware.ts` — call `getInactivityTimeout()` instead of reading env var directly; invalidate cache on PATCH — MTB-1511
- [x] T040 [US6] Extend `chat-backend/src/routes/admin.settings.ts` PATCH handler — accept `inactivity_timeout_minutes` with validation [5, 480]; emit `admin_settings.updated` audit entry with old/new values (FR-015, FR-016) — MTB-1512
- [x] T041 [P] [US6] Add inactivity timeout number input to admin section in `workbench-frontend/src/features/workbench/settings/SettingsView.tsx` — bounded [5, 480], reads from and writes to admin settings API — MTB-1513
- [x] T042 [US6] Ensure frontend redirects to login on timeout and flushes/queues in-memory drafts before redirect in `workbench-frontend/src/features/workbench/review/ReviewSessionView.tsx` (FR-017) — MTB-1514
- [x] T043 [US6] Write positive + negative backend tests in `chat-backend/tests/unit/adminSettings.059.test.ts` — positive: GET returns 30 default, PATCH updates value, middleware enforces new timeout, audit entry emitted; negative: PATCH rejects values outside [5, 480] with 400 — MTB-1515

**Checkpoint**: Inactivity timeout admin-configurable and enforced. SC-006 satisfied.

---

## Phase 9: User Story 7 — Admin toggle controls autosave-failure toast verbosity (Priority: P2) — MTB-1467

**Goal**: `verbose_autosave_failures` toggle in admin Settings controls whether transient save failures surface toasts.

**Independent Test**: Toggle ON → induce single 500 → toast on first failure; Toggle OFF → no toast until 3rd failure.

- [x] T044 [US7] Extend `chat-backend/src/routes/admin.settings.ts` PATCH handler — accept `verbose_autosave_failures` boolean; emit `admin_settings.updated` audit entry — MTB-1516
- [x] T045 [US7] Extend `chat-backend/src/services/settings.service.ts` — add `getVerboseAutosaveFailures()` with 60s cache — MTB-1517
- [x] T046 [US7] Add `verbose_autosave_failures` toggle to admin section in `workbench-frontend/src/features/workbench/settings/SettingsView.tsx` using canonical `Toggle` from `chat-frontend-common` (FR-018, FR-019) — MTB-1518
- [x] T047 [US7] Modify autosave toast logic in `workbench-frontend/src/features/workbench/review/ReviewSessionView.tsx` (or the autosave hook) — read `verbose_autosave_failures` from admin settings; when OFF, show toast only after 3rd consecutive failure; when ON, show toast on every failure — MTB-1519
- [x] T048 [US7] Replace ALL existing custom toggle buttons on Settings page with canonical `Toggle` from `chat-frontend-common` in `workbench-frontend/src/features/workbench/settings/SettingsView.tsx` — Admin section (guest mode, OTP disable) + Reviewer section (notification preferences) (FR-019) — MTB-1520
- [x] T049 [US7] Write positive + negative tests in `workbench-frontend/src/features/workbench/review/__tests__/VerboseAutosaveToggle.test.tsx` — positive: verbose ON shows toast on first failure, OFF shows toast on 3rd; negative: successful retry after transient failure shows no toast when OFF; verify Toggle component renders with neutral-gray OFF state — MTB-1521

**Checkpoint**: Autosave verbosity admin-controllable; all Settings toggles use canonical component.

---

## Phase 10: User Story 8 — Space-membership notifications (Priority: P2) — MTB-1468

**Goal**: Reviewer receives bell + banner notification when added to or removed from a Space.

**Independent Test**: Master adds Reviewer to Space → bell badge increments → banner shows "You were added to Space X" → Dismiss writes audit entry.

- [x] T050 [US8] Extend `chat-backend/src/services/reviewNotification.service.ts` — add `emitSpaceMembershipChange(userId, spaceName, direction)` that inserts a `space.membership_change` notification row (FR-020) — MTB-1522
- [x] T051 [US8] Wire membership change notification emission into `chat-backend/src/routes/group.members.ts` (or equivalent Space membership CRUD endpoint) — call `emitSpaceMembershipChange` on add/remove operations — MTB-1523
- [x] T052 [US8] Ensure `notification.read` audit entry is written on Dismiss for ALL three notification categories in `chat-backend/src/services/reviewNotification.service.ts` (FR-022) — MTB-1524
- [x] T053 [P] [US8] Update notification bell/banner rendering in `workbench-frontend/src/features/workbench/review/components/NotificationBell.tsx` — handle `space.membership_change` category with localised copy "You were added to / removed from Space X" (FR-021) — MTB-1525
- [x] T054 [US8] Write positive + negative backend tests in `chat-backend/tests/unit/notificationMembership.test.ts` — positive: notification row created on add/remove, payload contains spaceName + direction; negative: no duplicate notification on idempotent add; audit entry written on dismiss — MTB-1526

**Checkpoint**: All three notification categories wired end-to-end. SC-007, SC-008 satisfied.

---

## Phase 11: User Story 9 — Browser-prerequisite guard (Priority: P3) — MTB-1469

**Goal**: Full-page "browser not supported" notice when critical capabilities are missing.

**Independent Test**: Mock `window.indexedDB = undefined` → reload → guard page renders.

- [x] T055 [P] [US9] Create `BrowserCapabilityGuard` component in `workbench-frontend/src/components/BrowserCapabilityGuard.tsx` — probes IndexedDB, ServiceWorker, visibilitychange, pageshow; if any missing, renders full-page localised notice with supported browser list; soft-missing capabilities get inline downgrade notice only (FR-023, FR-024) — MTB-1527
- [x] T056 [US9] Wire `BrowserCapabilityGuard` into app shell in `workbench-frontend/src/App.tsx` (or `WorkbenchShell.tsx`) — renders before the main router so unsupported browsers never reach the Reviewer surface — MTB-1528
- [x] T057 [US9] Write positive + negative tests in `workbench-frontend/src/components/__tests__/BrowserCapabilityGuard.test.tsx` — positive: guard renders when IndexedDB missing; negative: guard does not render on modern browser; edge: soft-missing (Notifications API) shows inline notice only, rest of UI functional — MTB-1529

**Checkpoint**: Unsupported browsers get explicit notice; no silent data loss. SC-011 satisfied.

---

## Phase 12: User Story 10 — Automated accessibility gate (Priority: P3) — MTB-1470

**Goal**: axe-core runs on every Reviewer route in E2E; critical/serious violations block merge.

**Independent Test**: Introduce deliberate ARIA violation → run E2E → suite fails with exact rule ID.

- [x] T058 [US10] Add `@axe-core/playwright` as dev dependency in `chat-ui/package.json` — MTB-1530
- [x] T059 [US10] Create accessibility helper `checkAccessibility(page)` in `chat-ui/tests/helpers/accessibility.ts` — injects axe-core, runs WCAG 2.1 AA rules, critical/serious fail the test, moderate/minor logged as warnings (FR-025) — MTB-1531
- [x] T060 [US10] Create `chat-ui/tests/reviewer/a11y.spec.ts` — navigates to each Reviewer route (queue, session, reports, my-stats, settings) and calls `checkAccessibility(page)` after page load — MTB-1532
- [x] T061 [US10] Verify CI integration — confirm `a11y.spec.ts` runs in the existing Playwright CI pipeline and exits non-zero on critical/serious violations (SC-009) — MTB-1533

**Checkpoint**: axe-core gate active on every Reviewer route in CI.

---

## Phase 13: User Story 11 — Audit Log retention tiers and purge (Priority: P3) — MTB-1471

**Goal**: Logical hot/warm tiers, daily purge job for >60 months, legal_hold honoured.

**Independent Test**: Seed rows at 0/15/48/66 months → run purge → 66-month rows removed, legal_hold preserved, purge batch row appended.

- [x] T062 [US11] Create audit purge service in `chat-backend/src/services/auditPurge.service.ts` — `runPurge()` deletes rows where `created_at < NOW() - INTERVAL '60 months' AND legal_hold = false`, appends one `audit.purge` row with `{runSequenceId, removedCount, windowStart, windowEnd}` (FR-027, FR-028) — MTB-1534
- [x] T063 [US11] Register daily purge schedule in `chat-backend/src/index.ts` — `setInterval` at 24h, same pattern as `expireOldSessions`; runs at startup then every 24h — MTB-1535
- [x] T064 [US11] Add logical tier computation to audit log query endpoint in `chat-backend/src/routes/audit.ts` (or equivalent) — `CASE WHEN age < 12 months THEN 'hot' WHEN age < 36 months THEN 'warm' END`; add `X-Audit-Tier` response header for warm rows (FR-026) — MTB-1536
- [x] T065 [US11] Write positive + negative tests in `chat-backend/tests/unit/auditPurge.test.ts` — positive: rows > 60 months deleted, batch row appended with correct counts, warm-tier rows retained; negative: legal_hold rows preserved regardless of age; edge: empty purge run still appends batch row with count=0 — MTB-1537

**Checkpoint**: Audit log retention operational. SC-010 satisfied.

---

## Phase 14: Polish & Cross-Cutting Concerns — MTB-1472

**Purpose**: Remaining FRs that span stories, Toggle sweep, regression suite, deploy.

- [x] T066 [P] Wire `useFocusRefresh` on the Pending tab in `workbench-frontend/src/features/workbench/review/ReviewQueueView.tsx` — X/Y counter and queue list refresh on tab-focus return (FR-029) — MTB-1538
- [x] T067 Extend `chat-backend/src/services/reviewQueue.service.ts` — `recomputeCompletion()` re-evaluates all Pending sessions when admin decreases `required_reviewer_count`; auto-completes sessions where `completed >= new_required`; emits refresh event (FR-030) — MTB-1539
- [x] T068 Write positive + negative test for recomputeCompletion in `chat-backend/tests/unit/recomputeCompletion.059.test.ts` — positive: sessions auto-complete on count decrease; negative: sessions unchanged on count increase — MTB-1540
- [x] T069 [P] Add per-message deep link `#message-{messageId}` to Red Flag Supervisor email template in `chat-backend/src/services/redFlagEmail.service.ts` (FR-031) — MTB-1541
- [x] T070 [P] Update regression suite in `regression-suite/19-reviewer-review-queue.yaml` — add test cases for Submit countdown, retired tags, state components, multi-tab gate, unsaved modal, inactivity timeout, verbose toggle, space notifications, browser guard — MTB-1542
- [x] T071 Deploy all repos to dev via `workflow_dispatch` from `059-reviewer-mvp-gaps` branches; run `mhg.regression module:19-reviewer-review-queue level:standard` — MTB-1543
- [x] T072 Run quickstart.md validation (all 11 checks) against dev environment; capture evidence — MTB-1544
- [x] T073 Fix any regressions found during validation; re-run regression suite until clean — MTB-1545

**Checkpoint**: All 31 FRs, 12 SCs, and 6 edge cases covered. Feature ready for owner review.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — start immediately
- **Phase 2 (Foundational)**: Depends on T008/T009 from Phase 1 (illustrations + i18n)
- **Phase 3–13 (User Stories)**: All depend on Phase 2 completion (shared state components)
  - US6, US7, US8, US11 also depend on T004–T006 (chat-types + migration)
- **Phase 14 (Polish)**: Depends on all user stories being complete

### User Story Dependencies

- **US1 (P1)**: Frontend-only; can start after Phase 2
- **US2 (P1)**: Frontend-only; can start after Phase 2; independent of US1
- **US3 (P1)**: Frontend-only; core work done in Phase 2; Phase 5 is adoption pass
- **US4 (P1)**: Frontend-only; can start after Phase 2; independent of US1–3
- **US5 (P2)**: Frontend-only; can start after Phase 2; independent of US1–4
- **US6 (P2)**: Backend + Frontend; depends on T005 (migration) + T004 (chat-types)
- **US7 (P2)**: Backend + Frontend; depends on T005 (migration) + T004 (chat-types); benefits from US6 being done first (shared settings surface)
- **US8 (P2)**: Backend + Frontend; depends on T003–T004 (chat-types notification category)
- **US9 (P3)**: Frontend-only; can start after Phase 2; independent
- **US10 (P3)**: chat-ui only; can start after Phase 1 (T001); independent of frontend work
- **US11 (P3)**: Backend-only; can start after Phase 1 (T001); independent of frontend work

### Parallel Opportunities

**After Phase 2 completes, these can run simultaneously:**

Frontend-only stories (single developer):
- US1 + US2 + US4 (all [P]-compatible — different files)
- US5 (new component — different file)
- US9 (new component — different file)

Backend stories (single developer):
- US6 + US7 (shared settings — sequential)
- US8 (notification service — parallel with US6/7)
- US11 (purge service — parallel with all)

E2E (single developer):
- US10 (chat-ui only — fully independent)

---

## Parallel Example: P1 Frontend Stories

```
# These three can run simultaneously (different files):
T017 [US1] Submit countdown in ReviewSessionView.tsx
T020 [US2] Retired tag in TagChip.tsx
T030 [US4] Multi-tab gate in useFocusRefresh.ts
```

## Parallel Example: Backend Stories

```
# These can run simultaneously (different service files):
T038 [US6] Inactivity timeout in settings.service.ts
T050 [US8] Space notification in reviewNotification.service.ts
T062 [US11] Audit purge in auditPurge.service.ts
```

---

## Implementation Strategy

### MVP First (P1 Stories Only)

1. Phase 1: Setup (T001–T009)
2. Phase 2: Foundational (T010–T016) — shared state components
3. Phase 3: US1 — Submit countdown (T017–T019)
4. Phase 4: US2 — Retired tags (T020–T023)
5. Phase 5: US3 — State adoption (T024–T029)
6. Phase 6: US4 — Multi-tab gate (T030–T034)
7. **STOP AND VALIDATE**: All P1 stories pass independently
8. Deploy to dev, run regression

### Full Delivery (All Stories)

1. Complete MVP (above)
2. Phase 7–10: P2 stories (US5–US8) — can run in parallel
3. Phase 11–13: P3 stories (US9–US11) — can run in parallel
4. Phase 14: Polish + regression
5. Owner review + merge approval

---

## Summary

| Metric | Value |
|--------|-------|
| Total tasks | 73 |
| Phase 1 (Setup) | 9 |
| Phase 2 (Foundational) | 7 |
| US1 (Submit countdown) | 3 |
| US2 (Retired tags) | 4 |
| US3 (State adoption) | 6 |
| US4 (Multi-tab gate) | 5 |
| US5 (Unsaved modal) | 3 |
| US6 (Inactivity timeout) | 6 |
| US7 (Verbose toggle) | 6 |
| US8 (Space notifications) | 5 |
| US9 (Browser guard) | 3 |
| US10 (axe-core E2E) | 4 |
| US11 (Audit purge) | 4 |
| Phase 14 (Polish) | 8 |
| Parallel opportunities | 28 tasks marked [P] |

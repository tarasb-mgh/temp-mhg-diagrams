# Tasks: Review Dashboard Redesign

**Input**: Design documents from `/specs/036-review-dashboard-redesign/`
**Prerequisites**: spec.md (v3), plan.md, research.md, data-model.md
**Jira Epic**: MTB-832

**Organization**: Tasks grouped by user story. Setup/foundational work (T001-T013) is complete. Remaining tasks organized by functional area to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to

## Path Conventions

- **Workbench frontend**: `workbench-frontend/src/`

## User Stories (from spec)

| ID | Story | Priority | Page |
|----|-------|----------|------|
| US1 | Review Dashboard — data accuracy & design system fixes | P1 (MVP) | ReviewDashboard |
| US2 | Review Dashboard — interactive charts (legend↔chart linking, tooltips) | P2 | ReviewDashboard |
| US3 | Review Dashboard — Daily Goal & Activity Trend polish | P3 | ReviewDashboard |
| US4 | Team Dashboard — design system rewrite | P4 | TeamDashboard |
| US5 | Visual QA — cross-cutting verification | P5 | Both |

---

## Phase 1: Setup (Shared Infrastructure) ✅ COMPLETE

- [x] T001 Create feature branch `036-review-dashboard-redesign` in workbench-frontend
- [x] T002 Add recharts dependency to workbench-frontend/package.json
- [x] T003 [P] Add 21 i18n keys to workbench-frontend/src/locales/en.json — MTB-845
- [x] T004 [P] Add Ukrainian translations to workbench-frontend/src/locales/uk.json — MTB-846
- [x] T005 [P] Add Russian translations to workbench-frontend/src/locales/ru.json — MTB-847
- [x] T006 [P] Create DashboardEmptyState component in workbench-frontend/src/features/workbench/review/components/DashboardEmptyState.tsx — MTB-854
- [x] T007 Add auto-login for localhost dev mode in workbench-frontend/src/main.tsx
- [x] T008 [P] Add dev-setup.sh script in workbench-frontend/scripts/dev-setup.sh
- [x] T009 Fix configureApi to pass workbenchApiUrl in workbench-frontend/src/main.tsx
- [x] T010 Optimize CI pipeline (artifact-based deploy, typecheck step) in workbench-frontend/.github/workflows/ci.yml
- [x] T011 Revert chat-frontend-common to 0.5.0 (remove broken custom SVG charts)
- [x] T012 Remove embedded report generator from workbench-frontend/src/features/workbench/review/TeamDashboard.tsx
- [x] T013 [P] Add CSS to suppress recharts SVG focus outlines in workbench-frontend/src/index.css

**Checkpoint**: Infrastructure ready — dashboard renders with recharts, i18n, auto-login, and design system .card class.

---

## Phase 1b: Missing i18n Keys (Constitution VI compliance)

**Purpose**: Add 5 translation keys that were missed in the original 21-key set. Three hardcoded English strings violate Constitution VI ("All user-visible text MUST support translation").

- [x] T013a [P] Add 5 missing i18n keys to workbench-frontend/src/locales/en.json, uk.json, ru.json — keys: `review.dashboard.agreementRate.excellent` ("Excellent" / "Відмінно" / "Отлично"), `review.dashboard.agreementRate.moderate` ("Moderate" / "Помірно" / "Умеренно"), `review.dashboard.agreementRate.needsAttention` ("Needs attention" / "Потребує уваги" / "Требует внимания"), `review.dashboard.dailyGoal` ("Daily Goal" / "Денна ціль" / "Дневная цель"), `review.dashboard.noCriteriaFeedback` ("No criteria feedback yet" / "Ще немає відгуків за критеріями" / "Пока нет отзывов по критериям") — MTB-964
- [x] T013b [P] Replace hardcoded strings in workbench-frontend/src/features/workbench/review/ReviewDashboard.tsx — replace `'Excellent'` / `'Moderate'` / `'Needs attention'` (lines 108-110) with `t('review.dashboard.agreementRate.excellent')` etc. Replace `"Daily Goal"` (line 306) with `t('review.dashboard.dailyGoal')`. Replace `"No criteria feedback yet"` (line 295) with `t('review.dashboard.noCriteriaFeedback')` — MTB-965

**Checkpoint**: All user-visible strings use i18n keys. No hardcoded English text remains.

---

## Phase 2: US1 — Review Dashboard Data Accuracy & Design System Fixes (Priority: P1) 🎯 MVP

**Goal**: Fix data display correctness and typography consistency so the Review Dashboard shows accurate, spec-compliant information.

**Independent Test**: Navigate to `/workbench/review/dashboard`, select "All Time" period. Score Distribution bars show widths proportional to totalReviews (not normalized to max). All data numbers across Score Distribution and Criteria Breakdown use identical text-sm font-semibold text-neutral-700 styling. Activity Trend bar chart appears for all non-Today periods even with 1 data point. No blue focus outlines appear when clicking chart elements.

- [x] T014 [US1] Fix Score Distribution bar proportions in workbench-frontend/src/features/workbench/review/ReviewDashboard.tsx — bars must use `(count / totalReviews) * 100` for width percentage. Currently correct in code (`pct = (count / totalReviews) * 100`) but verify: when Outstanding=8 and total=8 bar shows 100%; when Outstanding=8 and total=15 bar shows ~53%. Remove `Math.max(pct, count > 0 ? 4 : 0)` minimum width hack if it distorts proportions at scale — replace with a CSS `min-width: 2px` on the bar element instead — MTB-966
- [x] T015 [P] [US1] Fix typography inconsistency in workbench-frontend/src/features/workbench/review/ReviewDashboard.tsx — Criteria Breakdown legend count currently uses `text-lg font-bold text-neutral-800` (line 289) but spec requires Data number token: `text-sm font-semibold text-neutral-700`. Score Distribution count (line 243) already uses `text-sm font-semibold text-neutral-700` which is correct. Change Criteria Breakdown count `<span>` to match — MTB-967
- [x] T016 [P] [US1] Show Activity Trend for all non-Today periods in workbench-frontend/src/features/workbench/review/ReviewDashboard.tsx — change `trendData.length >= 2` guard (line 328) to `trendData.length > 0`. Currently hides bar chart when only 1 week of data exists, creating an empty page feel. Spec: always show for non-Today when data exists — MTB-968
- [x] T017 [P] [US1] Fix recharts focus/click outlines in workbench-frontend/src/index.css and workbench-frontend/src/features/workbench/review/ReviewDashboard.tsx — existing CSS in index.css partially suppresses outlines. Test by clicking donut segments, radar chart, and bar chart elements. If blue outlines remain, add more specific selectors: `.recharts-surface:focus, .recharts-wrapper *:focus { outline: none !important; }`. On Pie/Radar/Bar components, ensure `tabIndex={-1}` and `style={{ outline: 'none' }}` are set — MTB-969

**Checkpoint**: Review Dashboard displays accurate data with consistent typography. Activity Trend visible for all periods. No focus outlines on charts.

---

## Phase 3: US2 — Interactive Charts (Priority: P2)

**Goal**: Add legend↔chart bidirectional hover interactions and verify tooltip formatting, making charts feel alive and interactive.

**Independent Test**: Hover over a Score Distribution legend row → corresponding donut segment expands outward. Hover over a Criteria Breakdown legend row → corresponding radar dot enlarges. Hover donut segment → dark tooltip shows "Outstanding: 8 reviews · 53%". Hover radar dot → dark tooltip shows "Empathy: 6 feedbacks · 75% of reviews".

- [x] T018 [US2] Add legend↔donut hover linking in workbench-frontend/src/features/workbench/review/ReviewDashboard.tsx — add state `const [activeScoreIndex, setActiveScoreIndex] = useState<number | undefined>(undefined)`. On each Score Distribution legend row: `onMouseEnter={() => setActiveScoreIndex(i)}` and `onMouseLeave={() => setActiveScoreIndex(undefined)}`. On Pie component: set `activeIndex={activeScoreIndex}` and render `activeShape` with outerRadius increased by 5px. Note: legend iterates all 5 SCORE_RANGES (including 0-count) but donutData filters to non-zero — index mapping must account for this mismatch by using the donutData index, not SCORE_RANGES index — MTB-970
- [x] T019 [US2] Add legend↔radar hover linking in workbench-frontend/src/features/workbench/review/ReviewDashboard.tsx — add state `const [activeCriteriaIndex, setActiveCriteriaIndex] = useState<number | undefined>(undefined)`. On each Criteria Breakdown legend row: `onMouseEnter={() => setActiveCriteriaIndex(i)}` and `onMouseLeave={() => setActiveCriteriaIndex(undefined)}`. On Radar component: use `activeDot` prop to enlarge the dot at activeCriteriaIndex (r: 7, strokeWidth: 2). Legend rows and radarData share the same CRITERIA_KEYS ordering so indices align directly — MTB-971
- [x] T020 [P] [US2] Verify donut segment hover tooltip in workbench-frontend/src/features/workbench/review/ReviewDashboard.tsx — tooltip already partially implemented (lines 212-222). Verify format is "Outstanding: 8 reviews · 53%" with dark compact style (bg-neutral-800, text-white, rounded-lg, text-xs, shadow-soft-lg). Fix label resolution: currently uses numeric score key mapping (`review.score.labels.10`), verify these i18n keys exist and produce correct range names in en/uk/ru — MTB-972
- [x] T021 [P] [US2] Verify radar dot hover tooltip in workbench-frontend/src/features/workbench/review/ReviewDashboard.tsx — tooltip already implemented (lines 267-275). Verify format is "Empathy: 6 feedbacks · 75% of reviews" with dark compact style. Confirm `d.fullName` resolves correctly from `t('review.criteria.${key}.name')` in all 3 locales — MTB-973

**Checkpoint**: Both charts respond to legend hover with visual highlighting. Tooltips display correctly formatted information in dark compact style.

---

## Phase 4: US3 — Daily Goal & Activity Trend Polish (Priority: P3)

**Goal**: Ensure Daily Goal progress bar and Activity Trend bar chart are visually polished with correct data calculations, color transitions, and design system compliance.

**Independent Test**: Select "Today" → progress bar shows with correct percentage, color transitions at 50%/100% thresholds, and text like "3 of ~6 reviews (52%)". Select "This Week" → bar chart shows with primary-500 bars, last bar full opacity, previous bars 50% opacity, custom dark tooltip on hover.

- [x] T022 [US3] Verify Daily Goal progress bar on Today period in workbench-frontend/src/features/workbench/review/ReviewDashboard.tsx — test with various data: 0 reviews (0%, neutral color, encouraging message), 1 review (~17%, neutral), 3 reviews (~50%, warning color threshold), 8 reviews (~133%, success with "above average!" text). Verify daily average formula: `sum(weeklyTrend.reviewsCompleted) / weeks / 5`. Verify color classes: <50% `bg-neutral-300`, 50-99% `bg-warning`, ≥100% `bg-secondary-600`. Current code uses `bg-secondary-600` for ≥100% which matches the spec (`secondary-600`) — MTB-974
- [x] T023 [US3] Style Activity Trend bar chart in workbench-frontend/src/features/workbench/review/ReviewDashboard.tsx — verify bar fill uses `#7c8db0` (primary-500 from design system). Verify Cell opacity pattern: last bar `opacity={1}`, previous bars `opacity={0.5}`. Verify dark tooltip uses DarkTooltip component with bg-neutral-800 style. Verify CartesianGrid uses `stroke="#f5f2ef"` (neutral-100 equivalent). Check bar radius, XAxis/YAxis font sizes match Chart label token (text-xs font-medium text-neutral-500) — MTB-975

**Checkpoint**: Daily Goal and Activity Trend sections are visually polished, data-correct, and design-system-compliant.

---

## Phase 5: US4 — Team Dashboard Design System Rewrite (Priority: P4)

**Goal**: Rewrite TeamDashboard to use the same design system patterns as ReviewDashboard — .card class, typography hierarchy, design system colors (no raw Tailwind colors), consistent interactions.

**Independent Test**: Navigate to `/workbench/review/team`, select "All Time". All cards use `.card` class (not ad-hoc `rounded-xl border border-neutral-200 bg-white shadow-sm`). KPI values use `text-2xl font-bold` (not `text-3xl`). Status colors use design system tokens (success/warning/error, not `text-emerald-600`/`text-amber-600`/`text-rose-600`). Queue Depth donut uses design system colors. Period selector matches ReviewDashboard styling.

- [x] T024 [US4] Rewrite TeamDashboard KPI cards and layout in workbench-frontend/src/features/workbench/review/TeamDashboard.tsx — replace all ad-hoc card styling (`rounded-xl border border-neutral-200 bg-white p-5 shadow-sm`) with `.card` class. Replace `text-3xl font-bold` with `text-2xl font-bold text-neutral-900` per KPI value token. Replace `text-2xl font-bold` page title with `text-lg font-semibold text-neutral-800`. Replace period selector `shadow-sm` with `shadow-soft` and `rounded-lg` with `rounded-xl`. Replace error box `border-red-200 bg-red-50 text-red-700` with `card text-error` pattern matching ReviewDashboard. Replace skeleton `rounded-xl bg-neutral-200` with `card bg-neutral-100 animate-pulse` — MTB-976
- [x] T025 [US4] Fix Queue Depth donut chart colors and tooltip in workbench-frontend/src/features/workbench/review/TeamDashboard.tsx — replace raw Tailwind hex colors in QUEUE_COLORS: `pending_review: '#fbbf24'` → warning token `'#c9a86c'`, `in_review: '#38bdf8'` → primary-500 `'#7c8db0'`, `disputed: '#f43f5e'` → error token `'#c98686'`, `complete: '#34d399'` → success token `'#7a9f86'`. Replace default `<Tooltip />` with custom dark tooltip component (bg-neutral-800, text-white, rounded-lg, text-xs). Add `tabIndex={-1}` and `style={{ outline: 'none' }}` to PieChart. Replace section header `text-lg font-semibold` with `text-sm font-semibold uppercase tracking-wider text-neutral-500` — MTB-977
- [x] T026 [P] [US4] Fix TeamDashboard status colors in workbench-frontend/src/features/workbench/review/TeamDashboard.tsx — replace reliability color classes: `text-emerald-600` → `text-secondary-700`, `text-amber-600` → `text-warning`, `text-red-600` → `text-error`. Replace escalation color `text-rose-600` → `text-error`. Replace deanonymization color `text-amber-600` → `text-warning`. Replace in-progress dot `bg-sky-400` → `bg-primary-400`. Add reliability rate label (Excellent/Moderate/Needs attention) matching ReviewDashboard agreement rate pattern — MTB-978
- [x] T027 [US4] Verify Team Dashboard translations and responsive layout in workbench-frontend/src/features/workbench/review/TeamDashboard.tsx — test all 3 locales (en/uk/ru): verify queue status labels (`review.common.status.*`), workload headers, KPI labels all render correctly and fit. Test responsive: 1440px (5 KPI cols, 2-col layout), 1024px (2-3 KPI cols), 375px (single column, table scrollable). Verify "Go to Reports" button uses design system button styling — MTB-979

**Checkpoint**: TeamDashboard uses identical design system patterns as ReviewDashboard. No raw Tailwind colors, no ad-hoc shadows, consistent typography.

---

## Phase 6: US5 — Visual QA (Priority: P5)

**Purpose**: Cross-cutting verification across both dashboards, all periods, locales, viewports, and interactions.

- [ ] T028 [US5] Playwright screenshot test — all 4 periods on Review Dashboard: capture Today (KPI + Score Distribution + Criteria + Daily Goal), This Week (+ Activity Trend bar chart), This Month (+ Activity Trend), All Time (+ Activity Trend). Verify each period renders all expected sections and no sections are missing or broken — MTB-980
- [ ] T029 [P] [US5] Playwright locale test — switch to Ukrainian (uk), screenshot Review Dashboard and Team Dashboard. Switch to Russian (ru), screenshot both. Verify all labels fit without overflow or truncation. Verify radar 3-letter codes (REL, EMP, SAF, ETH, CLR) render identically in all locales — MTB-981
- [ ] T030 [P] [US5] Playwright responsive test — capture Review Dashboard at 1440px, 1024px, 768px, 375px viewports. At 1024px: verify 2-col grid (Score Distribution + Criteria side by side). At 375px: verify single column, charts readable, period selector doesn't overflow. Repeat for Team Dashboard — MTB-982
- [ ] T031 [US5] Playwright interaction test — hover donut segment → verify dark tooltip appears with range name + count + percentage. Hover radar dot → verify tooltip with full criterion name + count + percentage of reviews. Hover legend row → verify corresponding chart element highlights (donut segment expands or radar dot enlarges). Click donut/radar/bar → verify NO blue focus outlines appear — MTB-983

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: ✅ Complete
- **Phase 2 (US1 — Data Accuracy)**: No dependencies on other stories — start immediately
- **Phase 3 (US2 — Interactive Charts)**: Can start after Phase 2 (same file, needs accurate data first)
- **Phase 4 (US3 — Polish)**: Can start in parallel with Phase 3 (different sections of same file, minimal conflict)
- **Phase 5 (US4 — Team Dashboard)**: Independent — can start in parallel with Phases 2-4 (different file: TeamDashboard.tsx)
- **Phase 6 (US5 — Visual QA)**: Depends on ALL previous phases completing

### Parallel Opportunities

```
Phase 2 (ReviewDashboard fixes):
  T014 ──┐
  T015 ──┤ T015, T016, T017 are [P] — different code sections
  T016 ──┤
  T017 ──┘

Phase 3 (Interactive charts):
  T018 → T019 (sequential, same hover pattern)
  T020 ──┐ [P] — tooltip verification only
  T021 ──┘

Phase 5 (Team Dashboard):
  T024 → T025 → T026 [P] → T027
  Can run ENTIRELY in parallel with Phases 2-4

Phase 6 (Visual QA):
  T028 ──┐
  T029 ──┤ T029, T030 are [P]
  T030 ──┘
  T031 (interaction test — sequential after screenshots)
```

---

## Implementation Strategy

### MVP First (US1 Only)

1. Complete Phase 2: Fix data accuracy + typography + trend visibility + focus outlines
2. **STOP and VALIDATE**: Playwright screenshot of all 4 periods — data correct, no visual regressions
3. All subsequent phases build on a visually correct baseline

### Recommended Execution Order

1. **Phase 1b** (i18n): T013a+T013b (parallel) — 10 min
2. **Phase 2** (US1): T014 → T015+T016+T017 (parallel) — 30 min
3. **Phase 5** (US4): T024 → T025 → T026+T027 — can run in parallel with steps 4-5 below
4. **Phase 3** (US2): T018 → T019 → T020+T021 (parallel) — 20 min
5. **Phase 4** (US3): T022 → T023 — 15 min
6. **Phase 6** (US5): T028 → T029+T030 (parallel) → T031 — 20 min

### Key Context for Implementation

#### Design system tokens

```
Colors: primary-500 (#7c8db0), secondary-700 (#658a72), secondary-500 (#8fb39a),
        neutral-* (warm grays), warning (#c9a86c), error (#c98686), success (#7a9f86)
Cards: .card class (bg-white rounded-2xl shadow-soft border border-neutral-200/60)
Shadows: shadow-soft, shadow-soft-md, shadow-soft-lg
```

#### Typography hierarchy (from spec)

```
Page title:     text-lg font-semibold text-neutral-800
Section header: text-sm font-semibold uppercase tracking-wider text-neutral-500
KPI value:      text-2xl font-bold text-neutral-900
KPI label:      text-xs font-medium uppercase tracking-wider text-neutral-400
Data number:    text-sm font-semibold text-neutral-700
Chart label:    text-xs font-medium text-neutral-500
Body text:      text-sm text-neutral-600
Caption:        text-xs text-neutral-400
```

#### Files to edit

```
workbench-frontend/src/features/workbench/review/ReviewDashboard.tsx — US1, US2, US3
workbench-frontend/src/features/workbench/review/TeamDashboard.tsx   — US4
workbench-frontend/src/index.css                                     — US1 (focus overrides)
```

#### Local dev setup

```bash
cd workbench-frontend
git checkout 036-review-dashboard-redesign
git pull origin 036-review-dashboard-redesign
./scripts/dev-setup.sh pavelm@mentalhelp.global
npx vite --port 5174
# Auto-login on localhost, navigate to /workbench/review/dashboard
```

#### API URLs

```
Dev backend: https://api.dev.mentalhelp.chat
Dashboard:   GET /api/review/dashboard/me?period=<today|week|month|all>
Team:        GET /api/review/dashboard/team?period=<today|week|month|all>
```

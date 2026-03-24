# Quickstart: 036 Review Dashboard Redesign — Next Session

**Read this file first. Do NOT start coding without completing all preparation steps.**

## 1. Read Context (mandatory, in order)

```
Read specs/036-review-dashboard-redesign/spec.md        — full spec v3 (layout, interactions, design system)
Read specs/036-review-dashboard-redesign/plan.md        — technical context, constitution check, current state
Read specs/036-review-dashboard-redesign/tasks.md       — tasks + "Key Context" section at bottom
Read specs/036-review-dashboard-redesign/research.md    — decisions (R1-R7) + backend data gaps
Read specs/036-review-dashboard-redesign/data-model.md  — API entities + recharts component mapping
Read chat-frontend-common/tailwind-preset.js            — design system tokens (colors, shadows, fonts)
Read workbench-frontend/src/index.css                   — component classes (.card, .btn-*, recharts CSS overrides)
```

## 2. Start Local Dev

```bash
cd /Users/malyarevich/dev/workbench-frontend
git checkout 036-review-dashboard-redesign
git pull origin 036-review-dashboard-redesign

# If .env.development.local missing:
./scripts/dev-setup.sh pavelm@mentalhelp.global

# Start dev server (MUST restart if env changed):
npx vite --port 5174

# Auto-login happens automatically on localhost (dev mode)
# Navigate to: http://localhost:5174/workbench/review/dashboard
```

## 3. Verify Current State via Playwright

Take screenshot of current dashboard on all 4 periods:
- Today, This Week, This Month, All Time
- Identify what renders, what's broken

## 4. Implementation Order

Tasks are organized by user story in `tasks.md`. Recommended execution:

### Phase 1b — Missing i18n Keys (T013a-T013b)
Constitution VI compliance. Two parallelizable tasks:

1. **T013a** [P]: Add 5 i18n keys to en/uk/ru locale files (agreement labels, daily goal, no-criteria text)
2. **T013b** [P]: Replace hardcoded English strings in ReviewDashboard.tsx with `t()` calls

### Phase 2 — US1: Data Accuracy Fixes (T014-T017)
All in `ReviewDashboard.tsx` (+ `index.css` for T017). T015/T016/T017 are parallelizable.

1. **T014**: Score Distribution bar proportions — verify `(count/totalReviews)*100`, remove `Math.max` hack
2. **T015** [P]: Typography — change Criteria count from `text-lg font-bold` → `text-sm font-semibold text-neutral-700`
3. **T016** [P]: Activity Trend — change `trendData.length >= 2` → `trendData.length > 0`
4. **T017** [P]: Focus outlines — test click on all charts, add CSS selectors if needed

### Phase 3 — US2: Interactive Charts (T018-T021)

1. **T018**: Legend↔donut hover — `activeScoreIndex` state + `activeIndex` prop on Pie
2. **T019**: Legend↔radar hover — `activeCriteriaIndex` state + enlarged activeDot
3. **T020** [P]: Verify donut tooltip format
4. **T021** [P]: Verify radar tooltip format

### Phase 4 — US3: Daily Goal & Trend Polish (T022-T023)

1. **T022**: Daily Goal — test color transitions, verify daily average formula
2. **T023**: Activity Trend — verify primary-500 bars, opacity pattern, dark tooltip

### Phase 5 — US4: Team Dashboard (T024-T027) — can run in parallel with Phases 3-4

1. **T024**: Replace ad-hoc cards with `.card` class, fix typography tokens
2. **T025**: Queue Depth donut — design system colors + dark tooltip
3. **T026** [P]: Status colors — replace `text-emerald-600` etc. with design system tokens
4. **T027**: Translations + responsive verification

### Phase 6 — US5: Visual QA (T028-T031)

1. **T028**: Playwright screenshots — all 4 periods
2. **T029** [P]: Locale test — uk + ru labels fit
3. **T030** [P]: Responsive test — 1440/1024/768/375px
4. **T031**: Interaction test — tooltips + hover linking + no outlines

## 5. Visual QA Checklist (Phase 6)

Run through Playwright after all implementation:
- [ ] Today: KPI cards + Score Distribution + Criteria Breakdown + Daily Goal
- [ ] This Week: same + Activity Trend (bar chart)
- [ ] This Month: same + Activity Trend
- [ ] All Time: same + Activity Trend
- [ ] Switch locale to Ukrainian → all labels fit
- [ ] Switch locale to Russian → all labels fit
- [ ] Hover donut segment → dark tooltip with name + count + %
- [ ] Hover radar dot → dark tooltip with full name + count + % of reviews
- [ ] Hover legend row → corresponding chart element highlights
- [ ] Click donut/radar → NO blue outline/border
- [ ] Responsive 1024px → 2-col grid
- [ ] Responsive 375px → single column, charts readable

## Key Rules (from Constitution VI-B)

- Colors: ONLY design system tokens. No raw hex in JSX (except SVG chart fills where Tailwind can't apply).
- Typography: ONLY Tailwind scale (text-xs through text-3xl). No text-[11px].
- Cards: .card class. No ad-hoc border+shadow combos.
- Shadows: shadow-soft family. No shadow-sm, ring-1.
- Verify ALL changes visually via Playwright before committing.
- Commit after each completed task group, not at the end.

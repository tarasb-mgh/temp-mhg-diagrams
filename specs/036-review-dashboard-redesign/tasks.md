# Tasks: Review Dashboard Redesign

**Input**: Design documents from `/specs/036-review-dashboard-redesign/`
**Prerequisites**: spec.md (v3), research.md, plan.md

**Organization**: Tasks split into completed infrastructure + remaining UI work.

## Path Conventions

- **Workbench frontend**: `workbench-frontend/src/`

---

## Completed Tasks

- [x] T001 Create feature branch in workbench-frontend
- [x] T002 Add recharts dependency
- [x] T003 Add 21 i18n keys to en.json — MTB-845
- [x] T004 Add Ukrainian translations — MTB-846
- [x] T005 Add Russian translations — MTB-847
- [x] T006 Create DashboardEmptyState component — MTB-854
- [x] T007 Add auto-login for localhost dev mode in main.tsx
- [x] T008 Add dev-setup.sh script for local development
- [x] T009 Fix configureApi to pass workbenchApiUrl in main.tsx
- [x] T010 Optimize CI pipeline (artifact-based deploy, typecheck step)
- [x] T011 Revert chat-frontend-common to 0.5.0 (remove broken custom charts)
- [x] T012 Remove embedded report generator from TeamDashboard
- [x] T013 Add CSS to suppress recharts SVG focus outlines

---

## Remaining Tasks — Review Dashboard UI

### Phase 1: Fix known issues from review feedback

- [ ] T014 Fix Score Distribution bar proportions — bars must be proportional to totalReviews (count/total), NOT normalized to max count. Verify with data where Outstanding=8 and total=8 (should be 100%) vs Outstanding=8 and total=15 (should be ~53%)
- [ ] T015 Fix typography inconsistency — Criteria Breakdown count uses text-lg but Score Distribution count uses text-sm. Both should use Data number token: text-sm font-semibold text-neutral-700 (per spec typography hierarchy)
- [ ] T016 Show Activity Trend for all non-Today periods — remove `trendData.length >= 2` check; show bar chart even with 1 data point. Only hide for Today (show Daily Goal instead)
- [ ] T017 Fix recharts focus/click outlines — current CSS may not fully suppress. Test: click donut segment → no blue outline. Click radar → no outline. Tab through page → no SVG focus rings

### Phase 2: Interactive charts

- [ ] T018 Add legend↔donut hover linking — when user hovers Score Distribution legend row, corresponding donut segment expands (increase outerRadius by 5px) or highlights. Use React state `activeIndex` + recharts `activeIndex` prop on Pie
- [ ] T019 Add legend↔radar hover linking — when user hovers Criteria Breakdown legend row, corresponding radar dot enlarges. Use `activeIndex` on Radar component
- [ ] T020 Add donut segment hover tooltip — already partially done; verify tooltip shows "Outstanding: 8 reviews · 53%" format with dark compact style
- [ ] T021 Add radar dot hover tooltip — already partially done; verify tooltip shows "Empathy: 6 feedbacks · 75% of reviews" format

### Phase 3: Daily Goal & Trend Polish

- [ ] T022 Verify Daily Goal progress bar on Today — test with various review counts (0, 1, 3, 8). Verify percentage calc, color transitions (neutral→warning→success), text labels
- [ ] T023 Style Activity Trend bar chart — verify it matches design system. Bars use primary-500 color. Last bar full opacity, previous bars 50%. Custom dark tooltip

### Phase 4: Team Dashboard

- [ ] T024 Rewrite TeamDashboard.tsx with same design system — .card class, typography hierarchy, design system colors. Apply same patterns as Review Dashboard
- [ ] T025 Queue Depth donut chart with recharts PieChart — 4 segments with translated labels, custom tooltip
- [ ] T026 Verify Team Dashboard translations (en/uk/ru) and responsive layout

### Phase 5: Visual QA

- [ ] T027 Test all 4 periods (Today/Week/Month/All Time) with Playwright screenshots
- [ ] T028 Test all 3 locales (en/uk/ru) — verify labels fit
- [ ] T029 Test responsive: 1440px, 1024px, 768px, 375px viewports
- [ ] T030 Test hover interactions on donut, radar, bars — verify tooltips and highlights

---

## Key Context for Next Session

### Design system tokens to use

```
Colors: primary-500 (#7c8db0), secondary-700 (#658a72), secondary-500 (#8fb39a),
        neutral-* (warm grays), warning (#c9a86c), error (#c98686)
Cards: .card class (bg-white rounded-2xl shadow-soft border border-neutral-200/60)
Shadows: shadow-soft, shadow-soft-md, shadow-soft-lg
```

### Typography hierarchy (from spec)

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

### Files to edit

```
workbench-frontend/src/features/workbench/review/ReviewDashboard.tsx — main component
workbench-frontend/src/features/workbench/review/TeamDashboard.tsx — team dashboard
workbench-frontend/src/index.css — recharts CSS overrides
```

### Local dev setup

```bash
cd workbench-frontend
./scripts/dev-setup.sh  # creates .env.development.local + gets OTP
npx vite --port 5174    # MUST restart after dev-setup (Vite caches env)
# Auto-login happens on page load (localhost + DEV mode)
```

### API URLs

```
Dev backend (workbench): https://api.workbench.dev.mentalhelp.chat
Dev backend (chat):      https://api.dev.mentalhelp.chat
Dashboard endpoint:      GET /api/review/dashboard/me?period=<today|week|month|all>
```

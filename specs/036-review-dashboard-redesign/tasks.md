# Tasks: Review Dashboard Redesign

**Input**: Design documents from `/specs/036-review-dashboard-redesign/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: Tests are OPTIONAL per constitution (III). Not explicitly requested in this spec.

**Organization**: Tasks are grouped by user story. UI-kit chart components are foundational (Phase 2) since multiple stories depend on them.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2)
- Include exact file paths in descriptions

## Path Conventions

- **Shared frontend library**: `chat-frontend-common/src/`
- **Workbench frontend**: `workbench-frontend/src/`

---

## Phase 1: Setup

**Purpose**: Branch creation and i18n translations (shared across all stories)

- [x] T001 [P] Create feature branch `036-review-dashboard-redesign` from `develop` in chat-frontend-common — MTB-843
- [x] T002 [P] Create feature branch `036-review-dashboard-redesign` from `develop` in workbench-frontend — MTB-844
- [x] T003 [P] Add missing i18n translation keys for period selectors, queue depth statuses, report types, empty states, and chart labels to workbench-frontend/src/locales/en.json (~21 keys under review.dashboard.period.*, review.common.status.*, review.reports.types.*, review.dashboard.emptyState.*, review.dashboard.teamEmptyState.*, review.dashboard.goToReports, review.dashboard.stats.queueTotal, review.dashboard.trendChart.*) — MTB-845
- [x] T004 [P] Add Ukrainian translations for all new keys to workbench-frontend/src/locales/uk.json — MTB-846
- [x] T005 [P] Add Russian translations for all new keys to workbench-frontend/src/locales/ru.json — MTB-847

---

## Phase 2: Foundational (UI-Kit Chart Components)

**Purpose**: Reusable chart components in chat-frontend-common that MUST be complete before dashboard pages can be redesigned

**⚠️ CRITICAL**: No user story work (Phase 3+) can begin until these components are built and exported

- [x] T006 [P] Create DonutChart component — SVG-based reusable donut/ring chart accepting segments (label, value, color), optional center label, configurable size and stroke width, legend rendered below, responsive scaling, role="img" with aria-label — in chat-frontend-common/src/components/charts/DonutChart.tsx — MTB-848
- [x] T007 [P] Create RadarChart component — SVG-based reusable radar/spider chart accepting axes (label, value), 5-axis polygon with semi-transparent fill, concentric guide pentagons, axis labels at endpoints, values at vertices, configurable size and colors, responsive scaling — in chat-frontend-common/src/components/charts/RadarChart.tsx — MTB-849
- [x] T008 [P] Create Sparkline component — SVG-based reusable micro-sparkline accepting data points array, configurable width/height/color, optional gradient fill below line, no axis labels, preserveAspectRatio="none" for container stretch — in chat-frontend-common/src/components/charts/Sparkline.tsx — MTB-850
- [x] T009 [P] Create DualAxisChart component — SVG-based reusable bar+line dual-axis chart accepting data points (label, barValue, lineValue), bars for left axis, polyline for right axis, visible data labels on bars and line vertices, configurable colors and height, responsive scaling — in chat-frontend-common/src/components/charts/DualAxisChart.tsx — MTB-851
- [x] T010 Create barrel export for chart components and re-export from library — create chat-frontend-common/src/components/charts/index.ts exporting all 4 charts, update chat-frontend-common/src/index.ts to re-export the charts module — MTB-852
- [x] T011 Bump chat-frontend-common version and publish — update package.json version, build, publish to npm registry, update workbench-frontend/package.json to consume new version — MTB-853

**Checkpoint**: All 4 chart components available via `@mentalhelpglobal/chat-frontend-common` — dashboard work can begin

---

## Phase 3: User Story 1 — Fix Review Dashboard UI Bugs (Priority: P1) 🎯 MVP

**Goal**: Fix missing translations and broken empty state on Review Dashboard

**Independent Test**: Open Review Dashboard, verify period tabs show translated labels, verify empty state shows CTA without zero-value charts

- [x] T012 [US1] Create DashboardEmptyState component — illustration/icon, translated title and description, "Start Reviewing" CTA button linking to /workbench/review, consistent card styling — in workbench-frontend/src/features/workbench/review/components/DashboardEmptyState.tsx
- [x] T013 [US1] Update ReviewDashboard.tsx — when reviewsCompleted is 0, render only DashboardEmptyState (no stat cards, no ScoreDistribution, no criteria bars, no weekly trend); replace loading spinner with Tailwind animate-pulse skeleton loaders matching bento-grid card dimensions (3 KPI skeletons, 2 chart skeletons, 1 trend skeleton) — in workbench-frontend/src/features/workbench/review/ReviewDashboard.tsx

**Checkpoint**: Review Dashboard shows translated period tabs and meaningful empty state — MVP functional

---

## Phase 4: User Story 7 — Fix Team Dashboard UI Bugs (Priority: P1)

**Goal**: Fix missing translations, broken empty state, remove duplicate report generator on Team Dashboard

**Independent Test**: Open Team Dashboard as supervisor, verify period/status/report labels translated, verify no embedded report generator, verify empty state

- [x] T014 [US7] Update TeamDashboard.tsx — when totalReviews is 0, render only a team-specific empty state (reuse DashboardEmptyState pattern with team-specific i18n keys); replace loading spinner with Tailwind animate-pulse skeleton loaders matching team bento-grid layout (5 KPI skeletons, 2 middle-row skeletons); fix period selector to use translated keys — in workbench-frontend/src/features/workbench/review/TeamDashboard.tsx
- [x] T015 [US7] Remove embedded report generator from TeamDashboard.tsx — delete the entire Reports section (report type selector, date pickers, format selector, generate button, result preview), replace with a "Go to Reports" link/button that navigates to /workbench/review/reports — in workbench-frontend/src/features/workbench/review/TeamDashboard.tsx
- [x] T016 [US7] Update TeamDashboard.tsx Queue Depth — replace stacked bar with DonutChart from chat-frontend-common; map QueueDepth data (pendingReview/inReview/disputed/complete) to 4 segments with existing color scheme (amber/sky/rose/emerald), pass queue total as centerLabel, render translated status labels in legend — in workbench-frontend/src/features/workbench/review/TeamDashboard.tsx

**Checkpoint**: Both P1 stories complete — all translation bugs fixed, empty states working, report duplication removed, queue depth donut in place

---

## Phase 5: User Story 2 — Donut Chart for Score Distribution (Priority: P2)

**Goal**: Replace horizontal bars with DonutChart for score distribution on Review Dashboard

**Independent Test**: View Review Dashboard with review data, verify donut chart renders with correct proportional segments, center total, and legend

- [x] T017 [US2] Replace ScoreDistribution.tsx — remove horizontal bar implementation, integrate DonutChart from chat-frontend-common; map ScoreDistribution data (outstanding/good/adequate/poor/unsafe) to DonutChart segments with existing color scheme (emerald/green/amber/orange/red), pass total as centerLabel, render translated range labels in legend — in workbench-frontend/src/features/workbench/review/components/ScoreDistribution.tsx

**Checkpoint**: Score Distribution renders as donut chart on Review Dashboard

---

## Phase 6: User Story 3 — Radar Chart for Criteria Breakdown (Priority: P2)

**Goal**: Replace horizontal bars with RadarChart for criteria feedback profile on Review Dashboard

**Independent Test**: View Review Dashboard with criteria feedback data, verify radar chart renders 5 axes with correct proportional shape and values

- [x] T018 [US3] Update ReviewDashboard.tsx criteria section — remove horizontal bar rendering for criteria breakdown, integrate RadarChart from chat-frontend-common; map CriteriaFeedbackCounts (relevance/empathy/safety/ethics/clarity) to RadarChart axes with translated labels; hide section entirely when all counts are zero — in workbench-frontend/src/features/workbench/review/ReviewDashboard.tsx

**Checkpoint**: Criteria Breakdown renders as radar chart on Review Dashboard

---

## Phase 7: User Story 4 — Bento-Grid Layout (Priority: P2)

**Goal**: Reorganize both dashboards into bento-grid layout with responsive breakpoints

**Independent Test**: View both dashboards on desktop (>=1024px) and mobile (<640px), verify two-column middle row on desktop, single column on mobile

- [x] T019 [P] [US4] Refactor ReviewDashboard.tsx layout — wrap content in Tailwind CSS grid (grid grid-cols-1 lg:grid-cols-2 gap-6), place KPI cards row as col-span-full with inner grid-cols-3, place Score Distribution and Criteria Breakdown side by side (each col-span-1 on lg), place Weekly Trend as col-span-full — in workbench-frontend/src/features/workbench/review/ReviewDashboard.tsx
- [x] T020 [P] [US4] Refactor TeamDashboard.tsx layout — wrap content in same Tailwind CSS grid pattern, place KPI cards row as col-span-full with inner grid-cols-5, place Queue Depth donut and Reviewer Workload table side by side (each col-span-1 on lg), place "Go to Reports" link as col-span-full — in workbench-frontend/src/features/workbench/review/TeamDashboard.tsx

**Checkpoint**: Both dashboards use bento-grid layout

---

## Phase 8: User Story 5 — Sparklines and Dual-Axis Trend (Priority: P3)

**Goal**: Add sparklines to KPI cards and upgrade Weekly Trend to dual-axis chart

**Independent Test**: View Review Dashboard with 3+ weeks of data, verify sparklines appear in KPI cards and trend chart shows both bars and line

- [x] T021 [US5] Add sparklines to ReviewDashboard.tsx KPI cards — integrate Sparkline from chat-frontend-common; extract reviewsCompleted values from weeklyTrend array for Reviews Completed card, averageScore values for Average Score card; render sparkline below each metric value; hide when trend data has fewer than 2 points; omit sparkline for Agreement Rate (no per-week data available) — in workbench-frontend/src/features/workbench/review/ReviewDashboard.tsx
- [x] T022 [US5] Replace Weekly Trend bar chart with DualAxisChart — integrate DualAxisChart from chat-frontend-common; map weeklyTrend array to DualAxisDataPoint (week label, reviewsCompleted as barValue, averageScore as lineValue); show translated axis labels; render data labels directly on chart — in workbench-frontend/src/features/workbench/review/ReviewDashboard.tsx

**Checkpoint**: KPI cards show sparklines, Weekly Trend shows dual-axis chart

---

## Phase 9: User Story 6 — Agreement Rate Color Coding (Priority: P3)

**Goal**: Add contextual color coding to Agreement Rate KPI card

**Independent Test**: View Review Dashboard with various agreement rates, verify green (>=80%), amber (60-79%), red (<60%)

- [x] T023 [US6] Add color coding to Agreement Rate in ReviewDashboard.tsx and interRaterReliability in TeamDashboard.tsx — apply conditional Tailwind text color classes: text-emerald-600 when >=80, text-amber-600 when >=60 and <80, text-red-600 when <60 — in workbench-frontend/src/features/workbench/review/ReviewDashboard.tsx and workbench-frontend/src/features/workbench/review/TeamDashboard.tsx

**Checkpoint**: Agreement Rate shows contextual color

---

## Phase 10: Polish & Cross-Cutting Concerns

**Purpose**: Final QA and cleanup

- [ ] T024 Verify responsive behavior — check both dashboards at 1024px, 768px, 640px, and 375px viewport widths; ensure no horizontal scroll, charts scale, labels remain legible; fix any overflow or wrapping issues
- [ ] T025 Run locale verification — switch language to Ukrainian and Russian on both dashboards; verify all 21 new keys render correctly in all 3 locales; check for any remaining raw i18n key placeholders

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — start immediately
- **Phase 2 (UI-Kit)**: Depends on Phase 1 branch creation (T001) — BLOCKS all dashboard work
- **Phase 3 (US1)**: Depends on Phase 2 (chart components) and Phase 1 (i18n keys)
- **Phase 4 (US7)**: Depends on Phase 2 (DonutChart for queue depth) and Phase 1 — can run in parallel with Phase 3
- **Phase 5 (US2)**: Depends on Phase 2 (DonutChart) — can run in parallel with Phase 3/4
- **Phase 6 (US3)**: Depends on Phase 2 (RadarChart) — can run in parallel with Phase 3/4/5
- **Phase 7 (US4)**: Depends on Phase 5 (US2 donut in place) and Phase 6 (US3 radar in place) for full effect, but layout refactor can start independently
- **Phase 8 (US5)**: Depends on Phase 2 (Sparkline, DualAxisChart) and Phase 7 (bento layout)
- **Phase 9 (US6)**: Depends on Phase 3 (Review Dashboard working) — minimal dependencies
- **Phase 10 (Polish)**: Depends on all prior phases

### User Story Dependencies

- **US1 (P1)**: Independent after Phase 2
- **US7 (P1)**: Independent after Phase 2 — parallelizable with US1; includes Queue Depth donut (T016)
- **US2 (P2)**: Independent after Phase 2
- **US3 (P2)**: Independent after Phase 2
- **US4 (P2)**: Best after US2 + US3 for complete bento layout, but grid refactor alone is independent
- **US5 (P3)**: Depends on US4 layout being in place for sparklines to render correctly in KPI cards
- **US6 (P3)**: Independent after US1

### Parallel Opportunities

- T001 + T002: Branch creation in both repos simultaneously
- T003 + T004 + T005: All locale files can be edited in parallel
- T006 + T007 + T008 + T009: All 4 chart components in different files — fully parallel
- T012 (empty state component) can be built while T013 waits for it
- T019 + T020: Both dashboard layouts in different files — parallel

---

## Parallel Example: Phase 2 (UI-Kit)

```text
# All 4 chart components can be built simultaneously:
Task T006: "DonutChart in chat-frontend-common/src/components/charts/DonutChart.tsx"
Task T007: "RadarChart in chat-frontend-common/src/components/charts/RadarChart.tsx"
Task T008: "Sparkline in chat-frontend-common/src/components/charts/Sparkline.tsx"
Task T009: "DualAxisChart in chat-frontend-common/src/components/charts/DualAxisChart.tsx"
```

---

## Implementation Strategy

### MVP First (US1 + US7 Only)

1. Complete Phase 1: Setup + i18n keys
2. Complete Phase 2: UI-Kit chart components (needed for later phases)
3. Complete Phase 3: US1 — Fix Review Dashboard (translations + empty state)
4. Complete Phase 4: US7 — Fix Team Dashboard (translations + empty state + remove reports)
5. **STOP and VALIDATE**: Both dashboards functional with correct translations and empty states
6. Deploy to dev and verify

### Incremental Delivery

1. Setup + UI-Kit → Foundation ready
2. US1 + US7 → Translation bugs fixed, empty states working (MVP!)
3. US2 → Score Distribution donut chart
4. US3 → Criteria Breakdown radar chart
5. US4 → Bento-grid layout for both dashboards + Queue Depth donut
6. US5 → Sparklines + dual-axis trend
7. US6 → Agreement Rate color coding
8. Polish → Responsive QA, locale verification

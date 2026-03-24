# Tasks: Review Dashboard Redesign

**Input**: Design documents from `/specs/036-review-dashboard-redesign/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: Tests are OPTIONAL per constitution (III). Not explicitly requested in this spec.

**Organization**: Tasks grouped by user story. Simplified after switching from custom UI-kit to recharts.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2)
- Include exact file paths in descriptions

## Path Conventions

- **Workbench frontend**: `workbench-frontend/src/`

---

## Phase 1: Setup

**Purpose**: Branch creation, dependency install, i18n translations

- [x] T001 [P] Create feature branch `036-review-dashboard-redesign` from `develop` in workbench-frontend — MTB-844
- [x] T002 [P] Add recharts dependency to workbench-frontend/package.json
- [x] T003 [P] Add missing i18n translation keys (21 keys) to workbench-frontend/src/locales/en.json — MTB-845
- [x] T004 [P] Add Ukrainian translations for all new keys to workbench-frontend/src/locales/uk.json — MTB-846
- [x] T005 [P] Add Russian translations for all new keys to workbench-frontend/src/locales/ru.json — MTB-847

---

## Phase 2: User Story 1 — Fix Review Dashboard UI Bugs (Priority: P1) 🎯 MVP

**Goal**: Fix missing translations and broken empty state on Review Dashboard

**Independent Test**: Open Review Dashboard, verify period tabs show translated labels, verify empty state shows CTA without zero-value charts

- [x] T006 [US1] Create DashboardEmptyState component with CTA in workbench-frontend/src/features/workbench/review/components/DashboardEmptyState.tsx — MTB-854
- [x] T007 [US1] Update ReviewDashboard.tsx — empty state when reviewsCompleted=0, skeleton loaders, period translations in workbench-frontend/src/features/workbench/review/ReviewDashboard.tsx — MTB-855

**Checkpoint**: Review Dashboard shows translated period tabs and meaningful empty state

---

## Phase 3: User Story 7 — Fix Team Dashboard UI Bugs (Priority: P1)

**Goal**: Fix translations, empty state, remove report generator, add queue depth donut

- [x] T008 [US7] Update TeamDashboard.tsx — empty state, skeleton loaders, period translations, remove embedded report generator, add "Go to Reports" link, replace queue depth stacked bar with recharts PieChart donut in workbench-frontend/src/features/workbench/review/TeamDashboard.tsx — MTB-856, MTB-857, MTB-858

**Checkpoint**: Both P1 stories complete

---

## Phase 4: User Story 2 — Donut Chart for Score Distribution (Priority: P2)

**Goal**: Replace horizontal bars with recharts PieChart donut on Review Dashboard

- [x] T009 [US2] Replace ScoreDistribution with recharts PieChart (innerRadius/outerRadius donut) — delete ScoreDistribution.tsx, integrate PieChart inline in ReviewDashboard.tsx with color-coded segments, center total, legend, tooltip — MTB-859

**Checkpoint**: Score Distribution renders as donut chart

---

## Phase 5: User Story 3 — Radar Chart for Criteria Breakdown (Priority: P2)

**Goal**: Replace horizontal bars with recharts RadarChart on Review Dashboard

- [x] T010 [US3] Replace criteria breakdown horizontal bars with recharts RadarChart — PolarGrid, PolarAngleAxis, Radar with 5 axes, tooltip, responsive — in ReviewDashboard.tsx — MTB-860

**Checkpoint**: Criteria Breakdown renders as radar chart

---

## Phase 6: User Story 4 — Bento-Grid Layout (Priority: P2)

**Goal**: Reorganize both dashboards into bento-grid layout

- [x] T011 [P] [US4] Refactor ReviewDashboard.tsx layout — Tailwind grid grid-cols-1 lg:grid-cols-2, KPI row col-span-full, charts side by side, trend full-width — MTB-861
- [x] T012 [P] [US4] Refactor TeamDashboard.tsx layout — same bento-grid, KPI row 5-col, queue depth + workload side by side — MTB-862

**Checkpoint**: Both dashboards use bento-grid layout

---

## Phase 7: User Story 5 — Sparklines and Dual-Axis Trend (Priority: P3)

**Goal**: Add sparklines to KPI cards, upgrade Weekly Trend to ComposedChart

- [x] T013 [US5] Add recharts AreaChart sparklines to Reviews Completed and Average Score KPI cards in ReviewDashboard.tsx — MTB-863
- [x] T014 [US5] Replace Weekly Trend with recharts ComposedChart (Bar + Line, dual Y-axis) in ReviewDashboard.tsx — MTB-864

**Checkpoint**: KPI sparklines and dual-axis trend chart working

---

## Phase 8: User Story 6 — Agreement Rate Color Coding (Priority: P3)

- [x] T015 [US6] Add color coding to Agreement Rate (ReviewDashboard) and interRaterReliability (TeamDashboard) — MTB-865

**Checkpoint**: Agreement Rate shows contextual color

---

## Phase 9: Polish & Visual QA

**Purpose**: Verify visual quality via Playwright, fix issues

- [ ] T016 Visual QA via Playwright — navigate to both dashboards on dev, take screenshots, verify charts render correctly with proper proportions, labels readable, responsive layout works
- [ ] T017 Run locale verification — switch to uk/ru on both dashboards, verify all 21 keys render correctly
- [ ] T018 Fix any visual issues found in T016/T017

---

## Dependencies & Execution Order

- **Phase 1 (Setup)**: No dependencies — start immediately
- **Phases 2-8**: Sequential, all in workbench-frontend — no cross-repo deps
- **Phase 9 (Polish)**: After deployment to dev

### Notes

- Single repo: workbench-frontend only (chat-frontend-common reverted to clean 0.5.0)
- recharts provides ResponsiveContainer — charts auto-size to container
- No custom SVG code — all charts via recharts declarative API

# Feature Specification: Review Dashboard Redesign

**Feature Branch**: `036-review-dashboard-redesign`
**Created**: 2026-03-23
**Status**: Draft
**Jira Epic**: MTB-832
**Input**: Redesign the Review Dashboard page (/workbench/review/dashboard) and Team Dashboard page (/workbench/review/team) to fix bugs, add missing translations, and modernize the UX with contemporary visualization patterns (radial charts, radar charts, bento-grid layout, contextual color coding).

## Clarifications

### Session 2026-03-23

- Q: Should Team Dashboard be included in scope or handled separately? → A: Full redesign of Team Dashboard is included in this spec alongside Review Dashboard — shared translations, layout, and chart improvements apply to both pages.
- Q: Should charting be implemented without external dependencies or with a lightweight library? → A: Initially attempted pure CSS/SVG internal UI-kit — produced poor visual quality (broken scaling, unreadable labels, incorrect proportions). **Revised decision**: use recharts (16M+ weekly downloads, ~150kB, SVG-based, React-native API) as the charting library. Proven, well-maintained, responsive out of the box.
- Q: Should the embedded report generator in Team Dashboard be kept or removed (it duplicates the Reports & Analytics page)? → A: Remove the embedded report generator from Team Dashboard and replace it with a link/button navigating to the dedicated Reports & Analytics page. Eliminates UI duplication.
- Q: What visualization should replace the stacked bar for Queue Depth on Team Dashboard? → A: Replace with a DonutChart (reusing the same internal UI-kit component as Score Distribution). Queue Depth is part-of-whole data (4 statuses = 100% of queue), which fits the donut pattern and ensures visual consistency across dashboards.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - View Personal Review Statistics With Working UI (Priority: P1)

A reviewer opens the Review Dashboard page and sees their personal statistics displayed correctly — period selector buttons show translated labels (not raw i18n keys), the empty state is clear and actionable when no reviews exist, and all UI elements render without visual artifacts or redundant information.

**Why this priority**: The page is currently broken for all users due to missing translations and a confusing empty state that shows both "No data available" and zero-value charts simultaneously. This must be fixed before any visual improvements make sense.

**Independent Test**: Can be tested by opening the Review Dashboard as any user with review access, verifying translated period labels appear, and confirming that the empty state shows a single clear message with a call-to-action instead of empty charts.

**Acceptance Scenarios**:

1. **Given** a reviewer viewing the dashboard, **When** the page loads, **Then** the period selector buttons display translated labels ("Today", "Week", "Month", "All") instead of raw i18n keys.
2. **Given** a reviewer with zero completed reviews, **When** they view the dashboard, **Then** they see only a meaningful empty state with a descriptive message and a "Start reviewing" button linking to the review queue — no zero-value stat cards, no empty bar charts, no empty criteria breakdowns are shown.
3. **Given** a reviewer with zero completed reviews, **When** they switch between period tabs, **Then** the empty state persists without rendering empty charts underneath.
4. **Given** a reviewer viewing the dashboard in Ukrainian or Russian locale, **When** the page loads, **Then** all labels, period selectors, and messages appear in the selected language.

---

### User Story 2 - Understand Score Distribution at a Glance (Priority: P2)

A reviewer who has completed reviews sees their score distribution displayed as a donut chart instead of horizontal bars. The donut chart shows the five score ranges (Outstanding through Unacceptable) as proportional color-coded segments with the total review count in the center, allowing the reviewer to instantly understand their scoring pattern.

**Why this priority**: The current horizontal bar layout for score distribution is difficult to parse for proportional data. A donut chart is the standard visualization for part-of-whole relationships and communicates the pattern significantly faster.

**Independent Test**: Can be tested by having a reviewer complete at least 5 reviews with varying scores, then verifying the donut chart shows proportional segments that match the actual score distribution, with the total count displayed in the center.

**Acceptance Scenarios**:

1. **Given** a reviewer with completed reviews, **When** they view the Score Distribution section, **Then** they see a donut/ring chart with five color-coded segments representing Outstanding (9-10), Very Good (7-8), Above Average (5-6), Below Average (3-4), and Unacceptable (1-2).
2. **Given** a reviewer viewing the donut chart, **When** they look at the center, **Then** they see the total number of reviews displayed prominently.
3. **Given** a reviewer viewing the donut chart, **When** they look below the chart, **Then** they see a legend mapping colors to score range labels with counts.
4. **Given** a reviewer whose all scores fall in one range, **When** they view the chart, **Then** the donut shows a single full-circle segment in the corresponding color.
5. **Given** a reviewer viewing on a mobile device, **When** the chart renders, **Then** it scales down proportionally while remaining legible.

---

### User Story 3 - Understand Criteria Feedback Profile (Priority: P2)

A reviewer sees their criteria feedback breakdown as a radar (spider) chart with five axes — Relevance, Empathy, Safety, Ethics, Clarity — instead of horizontal bars. The radar shape instantly communicates their strengths and areas for improvement as a visual profile.

**Why this priority**: With exactly five criteria of equal importance, a radar chart is the optimal visualization. It transforms five separate numbers into a single recognizable shape — a balanced pentagon means consistent feedback, a skewed shape highlights exactly which criteria need attention.

**Independent Test**: Can be tested by having a reviewer submit feedback on multiple criteria across several reviews, then verifying the radar chart axes match the criteria counts and the shape accurately reflects the distribution.

**Acceptance Scenarios**:

1. **Given** a reviewer with criteria feedback data, **When** they view the Criteria Breakdown section, **Then** they see a radar chart with five labeled axes (Relevance, Empathy, Safety, Ethics, Clarity).
2. **Given** a reviewer with equal feedback counts across all criteria, **When** they view the chart, **Then** the shape appears as a regular pentagon.
3. **Given** a reviewer with feedback heavily weighted toward Safety and Ethics, **When** they view the chart, **Then** the shape visibly extends further on the Safety and Ethics axes.
4. **Given** a reviewer viewing the radar chart, **When** they examine the axes, **Then** each axis shows its count value at the tip.
5. **Given** a reviewer on a mobile device, **When** the chart renders, **Then** it scales proportionally while axis labels remain readable.

---

### User Story 4 - See Dashboard in Modern Bento-Grid Layout (Priority: P2)

A reviewer sees the dashboard organized in a bento-grid layout with visual hierarchy — KPI stat cards across the top, Score Distribution and Criteria Breakdown side by side in the middle row, and Weekly Trend spanning the full width at the bottom — instead of the current single-column vertical stack.

**Why this priority**: The bento-grid layout reduces vertical scrolling, creates clear visual groupings, and makes better use of screen real estate on desktop. It establishes visual hierarchy where the most important metrics (KPIs) are immediately visible.

**Independent Test**: Can be tested by viewing the dashboard on desktop (>=1024px) and verifying the two-column middle row, then resizing to mobile (<640px) and verifying graceful collapse to single column.

**Acceptance Scenarios**:

1. **Given** a reviewer on a desktop screen (>=1024px), **When** they view the dashboard, **Then** they see KPI cards in a row at the top, Score Distribution and Criteria Breakdown side by side in the second row, and Weekly Trend full-width at the bottom.
2. **Given** a reviewer on a tablet screen (640-1023px), **When** they view the dashboard, **Then** they see KPI cards in a row and chart sections stacked vertically.
3. **Given** a reviewer on a mobile screen (<640px), **When** they view the dashboard, **Then** all sections stack in a single column with appropriate spacing.
4. **Given** the bento-grid layout, **When** the reviewer views the page, **Then** there is no horizontal scrolling at any viewport width.

---

### User Story 5 - See Trends Inline and in Detail (Priority: P3)

A reviewer sees micro-sparklines embedded in applicable KPI stat cards (Reviews Completed and Average Score) showing the 8-week directional trend at a glance. The full Weekly Trend section at the bottom shows both review count (as bars) and average score (as a line) on a dual-axis chart, with data labels visible directly on the chart.

**Why this priority**: Sparklines in KPI cards give immediate trend context ("am I improving?") without scrolling. The dual-axis weekly trend chart adds the missing dimension (quality trend alongside volume trend). However, this is an enhancement that builds on the more fundamental layout and chart changes.

**Independent Test**: Can be tested by having a reviewer with at least 3 weeks of review history view the dashboard and verifying sparklines appear in each KPI card and the weekly trend chart shows both bars and a line.

**Acceptance Scenarios**:

1. **Given** a reviewer with weekly trend data, **When** they view a KPI stat card, **Then** they see a small sparkline (approximately 60x20 pixels) below the metric value showing the 8-week directional trend.
2. **Given** a reviewer with no trend data, **When** they view a KPI stat card, **Then** no sparkline is rendered (no empty chart placeholder).
3. **Given** a reviewer viewing the Weekly Trend section, **When** data is available, **Then** they see bars for review count (left axis) and a line for average score (right axis) on the same chart.
4. **Given** the weekly trend chart, **When** the reviewer views it, **Then** data labels showing the count and score appear directly on the bars and line — not hidden behind a tooltip hover.
5. **Given** a mobile viewport, **When** the weekly trend chart renders, **Then** it remains readable with labels scaled appropriately.

---

### User Story 6 - See Contextual Color Signals on Agreement Rate (Priority: P3)

A reviewer sees their Agreement Rate displayed with contextual color coding — green for healthy (80% or above), amber for moderate (60-79%), red for attention needed (below 60%) — so they instantly understand whether their rate is within acceptable bounds without needing to know the thresholds.

**Why this priority**: A bare percentage without context forces the reviewer to guess whether their rate is good or bad. Color coding is a low-effort change with high UX impact but is lower priority than the core layout and chart improvements.

**Independent Test**: Can be tested by viewing dashboards for reviewers with agreement rates in each of the three ranges and verifying the correct color is applied.

**Acceptance Scenarios**:

1. **Given** a reviewer with an agreement rate of 85%, **When** they view the Agreement Rate card, **Then** the value is displayed in green.
2. **Given** a reviewer with an agreement rate of 70%, **When** they view the Agreement Rate card, **Then** the value is displayed in amber.
3. **Given** a reviewer with an agreement rate of 45%, **When** they view the Agreement Rate card, **Then** the value is displayed in red.
4. **Given** a reviewer with an agreement rate of exactly 80%, **When** they view the card, **Then** the value is green (boundary is inclusive).
5. **Given** a reviewer with an agreement rate of exactly 60%, **When** they view the card, **Then** the value is amber (boundary is inclusive).

---

### User Story 7 - View Team Dashboard With Working UI and Modern Layout (Priority: P1)

A supervisor or moderator opens the Team Dashboard page and sees team-wide statistics displayed correctly — period selector buttons show translated labels, review status labels in the queue depth donut chart are translated, the embedded report generator is removed and replaced with a link to the dedicated Reports & Analytics page, and the page uses the same modernized bento-grid layout as the personal Review Dashboard.

**Why this priority**: Team Dashboard has the same translation bugs as Review Dashboard (period.*, status.* — missing keys) plus its own layout issues and a duplicate report generator. Since the page shares components and design patterns with Review Dashboard, fixing both together is more efficient than separate efforts.

**Independent Test**: Can be tested by opening the Team Dashboard as a user with review:team_dashboard permission, verifying all labels are translated, confirming queue depth renders as a donut chart, confirming no embedded report generator is present, and verifying the bento-grid layout renders correctly with KPI cards, queue depth visualization, reviewer workload table, and a "Go to Reports" link.

**Acceptance Scenarios**:

1. **Given** a supervisor viewing the Team Dashboard, **When** the page loads, **Then** the period selector buttons display translated labels ("Today", "Week", "Month", "All") instead of raw i18n keys.
2. **Given** a supervisor viewing the Queue Depth section, **When** the chart renders, **Then** they see a donut chart with four color-coded segments (Pending Review, In Review, Disputed, Complete), total queue count in the center, and a legend with translated status labels below.
3. **Given** a supervisor viewing the Team Dashboard, **When** they look for report generation, **Then** they see a "Go to Reports" link/button that navigates to the Reports & Analytics page — no embedded report generator is present on this page.
4. **Given** a supervisor on a desktop screen, **When** they view the Team Dashboard, **Then** they see KPI cards in a row at the top, Queue Depth and Reviewer Workload side by side in the middle, and a "Go to Reports" link at the bottom.
5. **Given** a supervisor with zero team reviews, **When** they view the dashboard, **Then** they see a meaningful empty state without zero-value cards or empty charts.
6. **Given** a supervisor viewing the dashboard in Ukrainian or Russian locale, **When** the page loads, **Then** all labels appear in the selected language.

---

### Edge Cases

- What happens when a reviewer has reviews in only one score range? Show a simple text indicator instead of a full-circle donut — a single segment donut is visually meaningless.
- What happens when all criteria feedback counts are zero or all equal? Hide the radar chart — it degenerates to a dot or invisible shape. Show a text summary instead.
- What happens when there are fewer than 3 reviews? Hide Score Distribution and Criteria Breakdown charts entirely — charts with 1-2 data points are misleading. Show a compact text summary of the scores instead.
- What happens when weekly trend data has fewer than 2 weeks? Hide the Weekly Trend section entirely — a single bar in a chart is visual noise, not information.
- What happens when the loading state is active? Skeleton loaders matching the bento-grid card shapes are displayed instead of a spinner.
- What happens on hover? Custom compact tooltips (not default recharts oversized tooltips). Consistent size and style across all chart types.

### Dashboard Purpose & Behaviour (defined 2026-03-24)

**Mission**: Help the reviewer answer "How am I performing?" at a glance.

**Default period**: All Time (shows the full picture; user can drill down to week/month/today).

**KPI cards** (top row — 3 cards):
- Reviews Completed — absolute count + delta arrow (green ▲ / red ▼) showing change vs previous period
- Average Score — value /10 + delta arrow showing change vs previous period
- Agreement Rate — percentage + contextual label (Excellent/Moderate/Needs attention) + delta arrow

**Delta logic by period**:
- All Time: no delta (no "previous" reference)
- This Month: compare to previous month
- This Week: compare to previous week
- Today: compare to yesterday

**Score Distribution** — answers "Am I a harsh or lenient reviewer?"
- Donut chart showing proportion of scores across 5 ranges
- Visual emphasis on where the reviewer clusters (the dominant range should be obvious)
- Hover on segment → tooltip with range name, count, percentage

**Criteria Breakdown** — answers "What do I focus on? What do I miss?"
- Radar chart with 3-letter axis labels (REL, EMP, SAF, ETH, CLR)
- Show reviewer's values as filled polygon
- Show **team average** as dashed outline polygon (comparison overlay)
- Hover on dot → tooltip with full criterion name, reviewer count, team average
- Side legend: full criterion names with **percentage** (% of reviews where this criterion had feedback), not raw count

**Activity Trend** (replaces "Weekly Trend") — answers "How is my performance changing?"
- Multi-line chart showing criteria trends over time
- Lines: one per criterion (color-coded), plus average score line
- Time axis step varies by period:
  - Today: don't show (not enough granularity)
  - This Week: 1 day per step (Mon–Sun)
  - This Month: 1 day per step or 1 week per step (auto based on data density)
  - All Time: 1 week per step (or 1 month if >6 months of data)
- Show only when ≥2 data points exist for the selected period
- Each criteria line shows how that criterion's feedback frequency changes over time

### Design Principles (added 2026-03-24, updated with feedback)

- **Use project design system**: All styling MUST use the shared Tailwind preset tokens (primary, secondary, neutral, accent, success, warning, error colors; shadow-soft; .card class; .badge-* classes). No raw hex colors, no ad-hoc text sizes. Font sizes must use Tailwind scale (text-xs, text-sm, text-base, text-lg, text-xl) — no custom `text-[11px]` or similar.
- **Consistent typography hierarchy**: Define exactly which size/weight applies to each element type (page title, section header, KPI value, KPI label, chart label, data number) and apply uniformly. This must feel like one system, not assembled from parts.
- **Data density over decoration**: Every pixel must convey useful information. Empty charts, single-point trends, and full-circle donuts waste space.
- **Graceful degradation**: When data is sparse, charts should still render but adapt (e.g., donut shows single segment with count, radar shows shape even if small). Hiding entire sections makes page feel empty.
- **Interactive charts**: All chart elements must respond to hover (highlight, tooltip with full details). No "dead" charts. Score Distribution donut segments must show tooltips on hover. Radar dots must show criterion name + count on hover.
- **No focus/click outlines on charts**: SVG elements must not show browser focus rings or recharts selection borders when clicked. Use `tabIndex={-1}`, CSS overrides, and recharts props to suppress.
- **Labels must fit in all locales**: Verify en/uk/ru labels fit their containers. For radar chart, use short 3-letter codes (REL, EMP, SAF, ETH, CLR) as axis labels, with full names shown on hover tooltip and in side legend.
- **Fill the viewport**: Dashboard should use available space without large empty areas. Asymmetric grid (e.g., 2:3 column ratio) helps balance visual density.
- **Professional finish**: No arbitrary sizing. Consistent spacing using Tailwind gap/padding scale. Consistent card treatment (use .card class). Subtle hover states on interactive rows.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST display translated labels for period selector buttons (Today, Week, Month, All) in all supported locales (English, Ukrainian, Russian).
- **FR-002**: System MUST show a single meaningful empty state when no review data exists, without rendering zero-value stat cards or empty charts.
- **FR-003**: The empty state MUST include a call-to-action button that navigates the reviewer to the review queue.
- **FR-004**: Score Distribution MUST be displayed as a donut/ring chart with proportional segments per score range, total count in center, and a legend below.
- **FR-005**: Criteria Breakdown MUST be displayed as a radar chart with five axes, one per evaluation criterion.
- **FR-006**: Dashboard layout MUST use a bento-grid pattern — KPI row on top, two charts side by side in the middle, trend full-width at bottom — on viewports 1024px and wider.
- **FR-007**: Dashboard layout MUST collapse gracefully to a single column on viewports below 640px.
- **FR-008**: Each KPI stat card MUST show a micro-sparkline of the 8-week trend when trend data is available.
- **FR-009**: Agreement Rate value MUST be color-coded: green (>=80%), amber (60-79%), red (<60%).
- **FR-010**: Weekly Trend chart MUST display both review count (bars) and average score (line) with data labels visible without hover interaction.
- **FR-011**: Loading state MUST display skeleton loaders matching the bento-grid card layout instead of a centered spinner.
- **FR-012**: All chart visualizations MUST be implemented using the recharts library (PieChart for donut, RadarChart for criteria, ComposedChart for weekly trend, AreaChart for sparklines) with ResponsiveContainer for adaptive sizing. Charts are rendered directly in page components — no separate UI-kit library needed.
- **FR-013**: All new user-facing text MUST have translation keys added to all three locale files (en.json, uk.json, ru.json).
- **FR-014**: Team Dashboard MUST display translated status labels for queue depth (Pending Review, In Review, Disputed, Complete) in all supported locales.
- **FR-015**: Team Dashboard MUST NOT contain an embedded report generator. Instead, it MUST display a link/button navigating to the dedicated Reports & Analytics page.
- **FR-016**: Team Dashboard MUST use the same bento-grid layout pattern as Review Dashboard — KPI row on top, Queue Depth and Reviewer Workload side by side in the middle, Reports link at bottom — on viewports 1024px and wider.
- **FR-017**: Team Dashboard MUST show a meaningful empty state when no team review data exists, consistent with the Review Dashboard empty state pattern.
- **FR-018**: Team Dashboard layout MUST collapse gracefully to a single column on viewports below 640px.
- **FR-019**: Team Dashboard Queue Depth MUST be displayed as a donut chart (recharts PieChart with innerRadius) with four status segments, total count in center, and a translated legend below.

### Key Entities

- **ReviewerDashboardStats**: Existing data entity returned by the backend — contains reviewsCompleted, averageScoreGiven, agreementRate, scoreDistribution (5 buckets), criteriaFeedbackCounts (5 criteria), weeklyTrend (array of weekly data points). No changes needed.
- **ScoreDistribution**: Existing — outstanding, good, adequate, poor, unsafe buckets. Visualization changes only.
- **CriteriaFeedbackCounts**: Existing — relevance, empathy, safety, ethics, clarity. Visualization changes only.
- **TeamDashboardStats**: Existing data entity — contains totalReviews, averageTeamScore, interRaterReliability, pendingEscalations, pendingDeanonymizations, reviewerWorkload (array), queueDepth (4 status buckets). No changes needed.
- **QueueDepth**: Existing — pendingReview, inReview, disputed, complete. Visualization and translation changes only.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All period selector buttons display translated text (no raw i18n keys visible) in all three supported locales.
- **SC-002**: When a reviewer has zero completed reviews, only the empty state message and CTA are visible — no charts, no zero-value cards.
- **SC-003**: A reviewer can identify their dominant score range within 3 seconds of viewing the donut chart (versus scanning 5 horizontal bars).
- **SC-004**: A reviewer can identify their strongest and weakest criteria within 3 seconds of viewing the radar chart.
- **SC-005**: On desktop viewports, the full dashboard is visible within one screen height (no scrolling required to see all sections) for typical data volumes.
- **SC-006**: On mobile viewports, no horizontal scrolling occurs and all chart elements remain legible.
- **SC-007**: Page load with skeleton loaders provides visual feedback within 200ms of navigation.
- **SC-008**: Agreement Rate color coding matches defined thresholds with 100% accuracy across all possible values.
- **SC-009**: All Team Dashboard labels (period selectors, queue depth statuses) display translated text in all three supported locales.
- **SC-010**: Team Dashboard bento-grid layout matches the same responsive breakpoint behavior as Review Dashboard (1024px two-column, <640px single-column).

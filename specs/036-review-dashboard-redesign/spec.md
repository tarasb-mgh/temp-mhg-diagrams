# Feature Specification: Review Dashboard Redesign

**Feature Branch**: `036-review-dashboard-redesign`
**Created**: 2026-03-23
**Status**: In Progress
**Jira Epic**: MTB-832
**Spec version**: 3 (consolidated 2026-03-24)

## Mission

Help the reviewer answer **"How am I performing?"** at a glance. Every element on the page must answer a specific question — if it doesn't, it doesn't belong.

## Scope

Two pages in workbench-frontend:
1. **Review Dashboard** (`/workbench/review/dashboard`) — personal reviewer statistics
2. **Team Dashboard** (`/workbench/review/team`) — team-wide statistics (supervisor view)

## Technology Decisions

- **Charting**: recharts (16M+ weekly downloads, ~150kB, SVG-based, React API)
- **Styling**: project design system tokens from `chat-frontend-common/tailwind-preset.js` — see Design System section
- **Backend**: existing API endpoints, no backend changes required for MVP. Delta/team-average features may need backend extensions.

---

## Review Dashboard — Page Layout

**Default period**: All Time

### Row 1: KPI Cards (3 cards, equal width)

| Card | Value | Context | Delta |
|------|-------|---------|-------|
| Reviews Completed | absolute count | sparkline (≥2 weeks data) | ▲/▼ vs previous period |
| Average Score | value /10 | sparkline (≥2 weeks data) | ▲/▼ vs previous period |
| Agreement Rate | percentage | label: Excellent / Moderate / Needs attention | ▲/▼ vs previous period |

**Delta logic**:
- All Time: no delta shown
- This Month: vs previous month
- This Week: vs previous week
- Today: vs yesterday

**Agreement Rate thresholds**: ≥80% = success (Excellent), 60-79% = warning (Moderate), <60% = error (Needs attention). Use design system `success`, `warning`, `error` colors.

### Row 2: Two cards side by side (asymmetric 2:3 grid on desktop)

**Left (2 cols): Score Distribution** — "Am I harsh or lenient?"
- Donut chart (recharts PieChart with innerRadius) showing 5 score ranges
- Donut shows when ≥2 ranges have data; single-range = donut with one segment (still shows)
- Below donut: horizontal bars with label, colored bar proportional to total, count
- Hover on donut segment → tooltip: range name, count, percentage of total
- All score ranges always listed (including 0-count) for context

**Right (3 cols): Criteria Breakdown** — "What do I focus on? What do I miss?"
- Radar chart with 3-letter axis labels (REL, EMP, SAF, ETH, CLR) — fits all locales
- Reviewer's values: filled polygon (solid stroke, translucent fill)
- Team average: dashed outline polygon overlay (comparison) — requires backend data
- Hover on radar dot → tooltip: full criterion name, reviewer count, team average
- Side legend: full criterion names with percentage (% of reviews containing feedback for this criterion)
- When all criteria = 0: show radar grid with "No criteria feedback yet" text

### Row 3: Adaptive bottom section

**Today → Daily Goal Progress** — "Am I on track?"
- Horizontal progress bar: today's reviews vs daily average
- Daily average = total reviews (all time) ÷ active days
- Color: <50% neutral, 50-99% warning, ≥100% success
- Text: "3 of ~6 reviews (52%)" or "8 of ~6 reviews (142% — above average!)"

**This Week / This Month / All Time → Activity Trend** — "How is my performance changing?"
- Multi-line chart: one line per criterion (color-coded) + average score line
- Time step: Week=daily, Month=daily or weekly (auto), All Time=weekly or monthly (auto based on data span)
- Custom compact dark tooltip on hover
- **MVP simplification**: if per-criterion trend data is not available from backend, show a simple bar chart of reviews-per-week from weeklyTrend data. The chart MUST always be visible for non-Today periods when data exists — even with 1 data point (show single bar, don't hide). Hiding creates empty page feel.

---

## Team Dashboard — Page Layout

Same period selector. Same design system. Different data.

### Row 1: KPI Cards (5 cards)
- Total Reviews, Team Average Score, Inter-rater Reliability, Pending Escalations, Pending Deanonymizations

### Row 2: Two cards (2:3 grid)
- **Left**: Queue Depth — donut chart with 4 status segments (Pending Review, In Review, Disputed, Complete), translated status labels
- **Right**: Reviewer Workload — table with reviewer name, completed, in-progress, average score

### Row 3
- "Go to Reports" link/button navigating to `/workbench/review/reports`
- No embedded report generator (removed — duplicated Reports page)

---

## Design System Compliance

All UI MUST follow the project design system (Constitution VI-B).

### Typography Hierarchy

| Element | Tailwind | Color token |
|---------|----------|-------------|
| Page title | text-lg font-semibold | text-neutral-800 |
| Section header | text-sm font-semibold uppercase tracking-wider | text-neutral-500 |
| KPI value | text-2xl font-bold | text-neutral-900 |
| KPI label | text-xs font-medium uppercase tracking-wider | text-neutral-400 |
| KPI delta | text-xs font-medium | success / warning / error |
| Data number | text-sm font-semibold | text-neutral-700 |
| Chart axis label | text-xs font-medium | text-neutral-500 |
| Body text | text-sm | text-neutral-600 |
| Caption / hint | text-xs | text-neutral-400 |

### Card Treatment
- Use `.card` class from `index.css` (bg-white rounded-2xl shadow-soft border border-neutral-200/60)
- No ad-hoc `ring-1`, `border-neutral-200`, or `shadow-sm` — use the established pattern

### Colors (from tailwind-preset.js)
- Primary: `primary-*` (slate-blue)
- Secondary: `secondary-*` (sage-green)
- Neutral: `neutral-*` (warm gray)
- Accent: `accent-*` (purple)
- Status: `success` (#7a9f86), `warning` (#c9a86c), `error` (#c98686)
- Chart-specific colors for score ranges: define a consistent palette using design system colors, NOT raw hex

### Interactions
- All chart elements: hover → custom dark compact tooltip (bg-neutral-800, text-white, rounded-lg, text-xs)
- Score bars: hover → bg-neutral-50 background, subtle bar highlight
- Donut segments: hover → tooltip with name + count + percentage
- Radar dots: hover → enlarged active dot + tooltip with full name + count + team avg
- **Legend ↔ Chart linking**: hover or click on a legend row MUST highlight the corresponding chart element. For donut: hovered segment expands outward (outerRadius increase) or pulses. For radar: corresponding dot enlarges. This makes charts feel alive and interactive, not static images.
- No focus/click outlines on SVG charts (tabIndex={-1}, CSS overrides)

### Data Consistency Rules
- Score Distribution bars: width MUST be proportional to **total reviews** (count/totalReviews), NOT normalized to the maximum count. If all reviews are Outstanding, the Outstanding bar should be 100% and all others 0% — but if Outstanding=8 out of total=15, the bar should be ~53%.
- Number sizes in legends MUST be consistent across all sections. Both Score Distribution counts and Criteria Breakdown counts use the same typography token (Data number = text-sm font-semibold text-neutral-700). No mixing text-sm in one section and text-lg in another for the same semantic role.

---

## Edge Cases

- 0 reviews for selected period → empty state with CTA "Start Reviewing"
- 1 score range with data → donut shows single full segment (don't hide donut)
- All criteria = 0 → show radar grid outline with centered "No criteria feedback yet"
- Non-Today with trend data → always show Activity Trend (even 1 data point). Today → show Daily Goal instead of trend
- Daily Goal with 0 all-time reviews → show 0% with encouraging message
- Loading → skeleton loaders matching card layout shapes

## i18n

21 translation keys across en.json, uk.json, ru.json. All labels verified to fit in all 3 locales.

## Backend Data Gaps (for future iterations)

These features are specified but may require backend API extensions:
- **Delta vs previous period**: backend currently returns single-period data, not comparison
- **Team average per criterion**: not in current API; needed for radar overlay
- **Criteria as percentages**: backend returns raw counts; percentage = count / totalReviews (computable on frontend)
- **Daily average**: computable from weeklyTrend data on frontend
- **Activity Trend per criterion per day**: not in current API; weeklyTrend only has aggregate reviewsCompleted + averageScore

For MVP: implement what's possible with current API. Features requiring backend changes marked as Phase 2.

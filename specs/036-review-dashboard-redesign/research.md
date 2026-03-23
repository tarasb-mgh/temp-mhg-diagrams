# Research: Review Dashboard Redesign

**Feature**: 036-review-dashboard-redesign
**Date**: 2026-03-23

## R1: SVG Donut Chart Implementation (Pure CSS/SVG)

**Decision**: Use SVG `<circle>` elements with `stroke-dasharray` and `stroke-dashoffset` for donut segments.

**Rationale**: This is the standard zero-dependency approach for donut/ring charts. A single SVG `<circle>` per segment, positioned with cumulative `stroke-dashoffset`, renders proportional arcs. The center text is a positioned `<text>` element. This technique requires no path calculations, no trigonometry, and works reliably across all browsers.

**Alternatives considered**:
- SVG `<path>` with arc commands: More flexible but requires trigonometric arc calculations; unnecessary complexity for simple proportional segments.
- CSS `conic-gradient`: Simpler CSS-only approach, but lacks per-segment interactivity, accessibility attributes, and cannot render a true ring with center content.
- External library (e.g., recharts, nivo): Rejected per FR-012 — no new external dependencies.

**Implementation pattern**:
- SVG viewBox with fixed aspect ratio (e.g., `0 0 200 200`)
- Circle radius chosen so `2πr` provides a convenient stroke-dasharray base
- Each segment is a `<circle>` with `stroke-dasharray="segmentLength circumference"` and `stroke-dashoffset` equal to the cumulative offset
- Center label via `<text>` element centered in viewBox
- Legend rendered as HTML below the SVG, not inside it
- `role="img"` and `aria-label` on the SVG for screen readers

## R2: SVG Radar Chart Implementation (Pure SVG)

**Decision**: Use SVG `<polygon>` for the data shape and `<line>` elements for axes, with `<text>` labels at axis endpoints.

**Rationale**: A radar chart with exactly 5 axes maps to regular pentagon geometry. The axis endpoints are calculated using simple polar-to-cartesian conversion (`x = cx + r * cos(angle)`, `y = cy + r * sin(angle)`) with angles at 72° intervals. The data polygon connects 5 points scaled proportionally along each axis.

**Alternatives considered**:
- Canvas-based rendering: Not React-friendly, no DOM accessibility, harder to style with Tailwind.
- Multiple overlapping circles: Visual approximation but not accurate for 5-axis data.
- External library (e.g., visx, D3): Rejected per FR-012.

**Implementation pattern**:
- SVG viewBox with fixed aspect ratio (e.g., `0 0 300 300`), center at `(150, 150)`
- 5 axes drawn as `<line>` from center to edge
- Concentric guide pentagons (optional, for scale reference) as `<polygon>` with `fill="none"`
- Data shape as `<polygon>` with semi-transparent fill and colored stroke
- Axis labels as `<text>` elements positioned slightly beyond axis endpoints
- Values displayed at data polygon vertices
- `role="img"` and `aria-label` on the SVG

## R3: SVG Sparkline Implementation

**Decision**: Use SVG `<polyline>` for a simple trend line, matching the existing pattern in `ScoreTrajectoryView.tsx`.

**Rationale**: The workbench-frontend already has a working SVG sparkline pattern in `ScoreTrajectoryView.tsx` that uses `<path>` elements for line charts. The new Sparkline component generalizes this into a reusable UI-kit component with configurable dimensions, color, and data points.

**Alternatives considered**:
- CSS-only sparklines using gradient backgrounds: Limited control, no per-point precision.
- Canvas: Not React-friendly for small inline elements.

**Implementation pattern**:
- Fixed SVG viewBox (e.g., `0 0 60 20`) scaled to container
- `<polyline>` with normalized data points mapped to viewBox coordinates
- No axis labels, no grid — pure shape visualization
- Optional gradient fill below the line for visual weight
- `preserveAspectRatio="none"` to stretch to container width

## R4: Dual-Axis Trend Chart

**Decision**: Use SVG with `<rect>` elements for bars (left axis) and `<polyline>` for the line (right axis), with `<text>` data labels.

**Rationale**: Combines the bar chart (review count) and line chart (average score) in a single SVG. Each axis has independent scaling. Data labels are `<text>` elements positioned above bars and at line vertices.

**Alternatives considered**:
- Two separate charts stacked vertically: Loses the visual correlation between volume and quality.
- Canvas: Not React-friendly.

**Implementation pattern**:
- SVG viewBox with padding for axis labels
- Bars as `<rect>` elements with height proportional to left-axis scale (review count)
- Line as `<polyline>` with Y positions proportional to right-axis scale (average score)
- `<text>` data labels above each bar and at each line vertex
- Left axis label for count, right axis label for score (minimal, not full axis ticks)
- Responsive: viewBox scales with container width

## R5: UI-Kit Component Location

**Decision**: Place all chart components in `chat-frontend-common/src/components/charts/`.

**Rationale**: `chat-frontend-common` is the established shared library consumed by all frontends. It already has a `components/` directory (currently containing `GroupScopeRoute.tsx` and `LanguageSelector.tsx`). Adding a `charts/` subdirectory follows the existing pattern and makes components available to workbench-frontend, chat-frontend, and delivery-workbench-frontend.

**Alternatives considered**:
- Placing in `workbench-frontend/src/components/`: Would not be reusable across other frontends.
- Creating a new `chart-components` package: Over-engineering for 4 components; `chat-frontend-common` already serves this purpose.

**Implementation notes**:
- Each component is self-contained (no internal cross-imports between chart components)
- Props use generic data types (arrays of numbers, labeled segments) — not domain-specific types
- Tailwind classes for colors, with prop-based overrides
- Barrel export via `charts/index.ts`
- Version bump of `chat-frontend-common` required after adding components

## R6: Bento-Grid Layout Pattern

**Decision**: Use Tailwind CSS Grid with responsive breakpoints.

**Rationale**: Tailwind's grid utilities (`grid`, `grid-cols-*`, `col-span-*`) with responsive prefixes (`lg:`, `sm:`) provide the bento-grid layout without custom CSS. This matches the existing Tailwind-first approach in the project.

**Implementation pattern**:
- Outer container: `grid grid-cols-1 lg:grid-cols-2 gap-6`
- KPI row: `col-span-full` with inner `grid grid-cols-1 sm:grid-cols-3`
- Charts row: two cards, each `col-span-1` (side by side on lg, stacked on sm)
- Trend section: `col-span-full`
- Consistent card styling: `rounded-xl border border-neutral-200 bg-white p-5 shadow-sm`

## R7: Skeleton Loader Pattern

**Decision**: Use Tailwind's `animate-pulse` with placeholder divs matching card dimensions.

**Rationale**: Skeleton loaders are standard in the 2026 dashboard UX pattern. Tailwind's `animate-pulse` on `bg-neutral-200 rounded-xl` divs provides the shimmer effect without any additional dependencies. The skeleton layout mirrors the bento-grid structure so the transition from loading to loaded is seamless.

**Alternatives considered**:
- Third-party skeleton library (react-loading-skeleton): Adds dependency; Tailwind approach is sufficient.
- Spinner (current): Poor UX — no spatial preview of content layout.

## R8: Missing i18n Keys Inventory

**Decision**: Add 20 translation keys across 3 locale files.

**Keys to add** (under `review` namespace):

| Key path | en | Notes |
|----------|-----|-------|
| `review.dashboard.period.today` | Today | Period selector |
| `review.dashboard.period.week` | This Week | Period selector |
| `review.dashboard.period.month` | This Month | Period selector |
| `review.dashboard.period.all` | All Time | Period selector |
| `review.common.status.pending_review` | Pending Review | Queue depth legend |
| `review.common.status.in_review` | In Review | Queue depth legend |
| `review.common.status.disputed` | Disputed | Queue depth legend |
| `review.common.status.complete` | Complete | Queue depth legend |
| `review.reports.types.daily_summary` | Daily Summary | Report type selector |
| `review.reports.types.weekly_performance` | Weekly Performance | Report type selector |
| `review.reports.types.monthly_quality` | Monthly Quality | Report type selector |
| `review.reports.types.escalation_report` | Escalation Report | Report type selector |
| `review.dashboard.emptyState.title` | No reviews yet | Empty state heading |
| `review.dashboard.emptyState.description` | Start reviewing chat sessions to see your statistics here | Empty state body |
| `review.dashboard.emptyState.cta` | Start Reviewing | Empty state CTA button |
| `review.dashboard.teamEmptyState.title` | No team reviews yet | Team empty state heading |
| `review.dashboard.teamEmptyState.description` | Team review statistics will appear here once reviews are completed | Team empty state body |
| `review.dashboard.goToReports` | Go to Reports | Team dashboard reports link |
| `review.dashboard.stats.queueTotal` | Queue Total | Queue depth center label |
| `review.dashboard.trendChart.reviewCount` | Reviews | Dual-axis left label |
| `review.dashboard.trendChart.avgScore` | Avg Score | Dual-axis right label |

Ukrainian and Russian translations will be provided alongside English.

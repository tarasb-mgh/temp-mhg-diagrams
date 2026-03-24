# Data Model: Review Dashboard Redesign

**Feature**: 036-review-dashboard-redesign
**Date**: 2026-03-23

## Overview

This feature is frontend-only. No backend data model changes are required. All existing entities and API responses remain unchanged. This document captures the existing data shapes consumed by the dashboard pages and the new UI-kit component prop interfaces.

## Existing Entities (Unchanged)

### ReviewerDashboardStats

Source: `@mentalhelpglobal/chat-types` — `reviewConfig.ts`
API: `GET /api/review/dashboard/me?period=<DashboardPeriod>`

| Field | Type | Description |
|-------|------|-------------|
| reviewsCompleted | number | Total reviews completed in period |
| averageScoreGiven | number \| null | Average score across all reviews |
| agreementRate | number | Percentage (0-100) of scores within variance threshold |
| scoreDistribution | ScoreDistribution | Distribution across 5 score ranges |
| criteriaFeedbackCounts | CriteriaFeedbackCounts | Feedback count per criterion |
| weeklyTrend | WeeklyTrendPoint[] | Weekly aggregated data points |

### ScoreDistribution

| Field | Type | Score Range |
|-------|------|-------------|
| outstanding | number | 9-10 |
| good | number | 7-8 |
| adequate | number | 5-6 |
| poor | number | 3-4 |
| unsafe | number | 1-2 |

### CriteriaFeedbackCounts

| Field | Type |
|-------|------|
| relevance | number |
| empathy | number |
| safety | number |
| ethics | number |
| clarity | number |

### WeeklyTrendPoint

| Field | Type | Description |
|-------|------|-------------|
| week | string | ISO date of the week start |
| reviewsCompleted | number | Reviews completed that week |
| averageScore | number | Average score that week |

### DailyTrendPoint

Source: `@mentalhelpglobal/chat-types` — `reviewConfig.ts` (v1.15.1+)
API: returned as part of `ReviewerDashboardStats`

| Field | Type | Description |
|-------|------|-------------|
| date | string | ISO date (YYYY-MM-DD) |
| reviewsCompleted | number | Reviews completed that day (always > 0) |

Last 90 days, non-zero days only. Used for precise Daily Goal calculation.

### TeamDashboardStats

Source: `@mentalhelpglobal/chat-types` — `reviewConfig.ts`
API: `GET /api/review/dashboard/team?period=<DashboardPeriod>`

| Field | Type | Description |
|-------|------|-------------|
| totalReviews | number | Team total reviews in period |
| averageTeamScore | number \| null | Team average score |
| interRaterReliability | number | Percentage (0-100) |
| pendingEscalations | number | Active escalation count |
| pendingDeanonymizations | number | Pending deanon requests |
| reviewerWorkload | ReviewerWorkloadEntry[] | Per-reviewer breakdown |
| queueDepth | QueueDepth | Queue status distribution |

### QueueDepth

| Field | Type | Description |
|-------|------|-------------|
| pendingReview | number | Awaiting first review |
| inReview | number | Currently being reviewed |
| disputed | number | Score variance exceeded |
| complete | number | All reviews submitted |

### DashboardPeriod

Type: `'today' | 'week' | 'month' | 'all'`

## Recharts Usage (No Custom UI-Kit)

Per research decision R1, custom SVG chart components were reverted. All charts use
recharts library components directly in page components. No shared UI-kit interfaces.

### Recharts Components Used

| recharts Component | Dashboard Section | Configuration |
|--------------------|-------------------|---------------|
| PieChart + Pie | Score Distribution (donut) | innerRadius for donut hole, activeIndex for hover |
| RadarChart + Radar + PolarGrid | Criteria Breakdown | 3-letter axis labels (REL, EMP, SAF, ETH, CLR) |
| BarChart + Bar | Activity Trend (non-Today) | Weekly review counts from weeklyTrend |
| Sparkline (custom SVG) | KPI cards | Inline SVG path from weeklyTrend data |
| ResponsiveContainer | All charts | Auto-sizing wrapper |
| Tooltip | All charts | Custom dark compact renderer |

### Frontend-Computed Values

| Value | Formula | Source Fields |
|-------|---------|---------------|
| Score range percentage | count / totalReviews × 100 | scoreDistribution.* / reviewsCompleted |
| Criteria percentage | count / totalReviews × 100 | criteriaFeedbackCounts.* / reviewsCompleted |
| Daily average | sum(weeklyTrend.reviewsCompleted) / activeWeeks / 5 | weeklyTrend[] |
| Daily goal progress | todayReviews / dailyAverage × 100 | reviewsCompleted + computed dailyAverage |

## State Transitions

No state transitions introduced. The dashboard pages are read-only views of existing data.

## Validation Rules

No new validation rules. All data comes pre-validated from the backend API.

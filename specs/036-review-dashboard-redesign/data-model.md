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

## New UI-Kit Component Interfaces

These are the prop interfaces for the new reusable chart components in `chat-frontend-common`.

### DonutChart Props

| Prop | Type | Required | Description |
|------|------|----------|-------------|
| segments | DonutSegment[] | Yes | Array of segments with label, value, color |
| centerLabel | string | No | Text displayed in the center (e.g., total count) |
| centerSubLabel | string | No | Secondary text below center label |
| size | number | No | Diameter in pixels (default: 180) |
| strokeWidth | number | No | Ring thickness (default: 28) |
| className | string | No | Additional CSS classes on container |

**DonutSegment**: `{ label: string; value: number; color: string }`

### RadarChart Props

| Prop | Type | Required | Description |
|------|------|----------|-------------|
| axes | RadarAxis[] | Yes | Array of axes with label and value |
| size | number | No | Chart diameter in pixels (default: 260) |
| fillColor | string | No | Polygon fill color (default: semi-transparent primary) |
| strokeColor | string | No | Polygon stroke color (default: primary) |
| showValues | boolean | No | Display values at vertices (default: true) |
| className | string | No | Additional CSS classes on container |

**RadarAxis**: `{ label: string; value: number }`

### Sparkline Props

| Prop | Type | Required | Description |
|------|------|----------|-------------|
| data | number[] | Yes | Array of data points |
| width | number | No | SVG width in pixels (default: 60) |
| height | number | No | SVG height in pixels (default: 20) |
| color | string | No | Line stroke color (default: sky-500) |
| showFill | boolean | No | Show gradient fill below line (default: false) |
| className | string | No | Additional CSS classes |

### DualAxisChart Props

| Prop | Type | Required | Description |
|------|------|----------|-------------|
| data | DualAxisDataPoint[] | Yes | Array of data points |
| barLabel | string | No | Left axis label (bar metric name) |
| lineLabel | string | No | Right axis label (line metric name) |
| barColor | string | No | Bar fill color (default: sky-500) |
| lineColor | string | No | Line stroke color (default: amber-500) |
| height | number | No | Chart height in pixels (default: 160) |
| showDataLabels | boolean | No | Show values on chart (default: true) |
| className | string | No | Additional CSS classes |

**DualAxisDataPoint**: `{ label: string; barValue: number; lineValue: number }`

## State Transitions

No state transitions introduced. The dashboard pages are read-only views of existing data.

## Validation Rules

No new validation rules. All data comes pre-validated from the backend API.

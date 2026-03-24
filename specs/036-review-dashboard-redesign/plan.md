# Implementation Plan: Review Dashboard Redesign

**Branch**: `036-review-dashboard-redesign` | **Date**: 2026-03-23 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/036-review-dashboard-redesign/spec.md`

## Summary

Redesign the Review Dashboard and Team Dashboard pages in the workbench frontend to fix missing i18n translations (21 keys across 3 locales), replace the broken empty state with a meaningful CTA-driven view, modernize chart visualizations (donut chart for score distribution and queue depth, radar chart for criteria breakdown, sparklines in KPI cards, dual-axis weekly trend), adopt a bento-grid layout, and add contextual color coding for Agreement Rate. All chart components are built as reusable internal UI-kit components in `chat-frontend-common` using pure CSS/SVG — no external charting dependencies.

## Technical Context

**Language/Version**: TypeScript 5.x, React 18  
**Primary Dependencies**: Tailwind CSS 3.4, Zustand, i18next, lucide-react, recharts, `@mentalhelpglobal/chat-frontend-common`, `@mentalhelpglobal/chat-types`  
**Storage**: N/A (frontend-only; backend API unchanged)  
**Testing**: Vitest + React Testing Library (workbench-frontend), Playwright E2E (chat-ui)  
**Target Platform**: Web (desktop/tablet/mobile responsive)  
**Project Type**: Web application (React SPA)  
**Performance Goals**: Skeleton loaders visible within 200ms of navigation; SVG charts render without jank  
**Constraints**: Use recharts library for all chart visualizations (FR-012). Charts are inline in page components, not in chat-frontend-common  
**Scale/Scope**: 2 dashboard pages, recharts integration, 3 locale files, ~10 affected files

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Spec-First | PASS | Spec at specs/036-review-dashboard-redesign/spec.md |
| II. Multi-Repo | PASS | Targets workbench-frontend + chat-frontend-common (shared UI-kit) |
| III. Test-Aligned | PASS | Vitest for component tests; Playwright for E2E |
| IV. Branch Discipline | PASS | Feature branch 036-review-dashboard-redesign across repos |
| V. Privacy/Security | PASS | No user data changes; display-only |
| VI. Accessibility/i18n | PASS | i18n keys added for all 3 locales; charts have text labels as redundant encoding |
| VII. Split-Repo First | PASS | chat-frontend-common for shared components; workbench-frontend for pages |
| VIII. GCP CLI | N/A | No infrastructure changes |
| IX. Responsive/PWA | PASS | Bento-grid responsive breakpoints defined (1024px, 640px) |
| X. Jira Traceability | PASS | Will create Epic and Stories |
| XI. Documentation | PASS | User Manual update needed post-deploy |
| XII. Release Engineering | PASS | Standard dev deploy, no special release |

## Project Structure

### Documentation (this feature)

```text
specs/036-review-dashboard-redesign/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
└── tasks.md             # Phase 2 output (via /speckit.tasks)
```

### Source Code (affected repositories)

```text
workbench-frontend/
├── package.json                     # UPDATE — add recharts dependency
└── src/
    ├── locales/
    │   ├── en.json                  # UPDATE — add ~21 missing translation keys
    │   ├── uk.json                  # UPDATE — add ~21 missing translation keys
    │   └── ru.json                  # UPDATE — add ~21 missing translation keys
    └── features/workbench/
        └── review/
            ├── ReviewDashboard.tsx   # UPDATE — bento layout, recharts (PieChart, RadarChart, ComposedChart, AreaChart), empty state, sparklines
            ├── TeamDashboard.tsx     # UPDATE — bento layout, recharts PieChart for queue depth, remove report generator
            └── components/
                ├── ScoreDistribution.tsx  # DELETE — replaced by inline recharts PieChart
                └── DashboardEmptyState.tsx # NEW — meaningful empty state with CTA
```

**Structure Decision**: All chart visualizations use recharts directly in page components. No separate UI-kit components needed — recharts provides the composable component API. Only `workbench-frontend` is affected; `chat-frontend-common` has no chart-related changes.

## Cross-Repository Dependencies

| Order | Repository | Changes | Depends On |
|-------|-----------|---------|------------|
| 1 | `workbench-frontend` | Dashboard pages, locale files, recharts integration | None |

**Execution order**: Single repository — no cross-repo dependency chain.

## Complexity Tracking

No constitution violations to justify. The feature uses existing patterns and does not exceed complexity thresholds.

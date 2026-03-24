# Implementation Plan: Review Dashboard Redesign

**Branch**: `036-review-dashboard-redesign` | **Date**: 2026-03-23 (updated 2026-03-24) | **Spec**: [spec.md](./spec.md)

## Summary

Redesign Review Dashboard and Team Dashboard pages. Uses recharts for visualizations, project design system for styling. Single-repo change (workbench-frontend only).

## Technical Context

**Language/Version**: TypeScript 5.x, React 18
**Primary Dependencies**: Tailwind CSS 3.4, Zustand, i18next, recharts, `@mentalhelpglobal/chat-frontend-common` (v0.5.0, no chart components), `@mentalhelpglobal/chat-types`
**Storage**: N/A (frontend-only; backend API unchanged for MVP)
**Testing**: Vitest + React Testing Library, Playwright E2E (chat-ui)
**Constraints**: Use recharts for charts. Use project design system tokens (Constitution VI-B). Charts inline in page components.

## Project Structure

```
workbench-frontend/
├── package.json                     # recharts dependency
├── scripts/dev-setup.sh             # Local dev setup script
├── .env.development.local           # Local API URL override (gitignored)
├── .github/workflows/ci.yml         # Optimized CI (artifact-based deploy)
└── src/
    ├── index.css                    # Recharts CSS focus overrides
    ├── config.ts                    # API URL config
    ├── main.tsx                     # configureApi + auto-login
    ├── locales/
    │   ├── en.json                  # +21 translation keys
    │   ├── uk.json                  # +21 translation keys
    │   └── ru.json                  # +21 translation keys
    └── features/workbench/review/
        ├── ReviewDashboard.tsx      # REWRITE — main dashboard component
        ├── TeamDashboard.tsx        # UPDATE — same design system treatment
        └── components/
            └── DashboardEmptyState.tsx  # Empty state with CTA
```

## Cross-Repository Dependencies

None. Single repo (workbench-frontend). chat-frontend-common reverted to clean 0.5.0.

## Key Design Decisions

1. **No shared chart UI-kit** — charts render directly in page components using recharts. Custom SVG components produced poor quality and were reverted.
2. **Design system first** — all colors from tailwind-preset.js, all typography from defined hierarchy, all cards use .card class.
3. **Adaptive bottom section** — Today=Daily Goal Progress, other periods=Activity Trend.
4. **Radar with short labels** — 3-letter codes (REL, EMP, SAF, ETH, CLR) to fit all locales. Full names in side legend + hover tooltip.
5. **Legend ↔ Chart linking** — hover on legend row highlights corresponding chart element for interactivity.
6. **MVP with current API** — delta arrows, team average overlay, per-criterion trends deferred to Phase 2 (requires backend changes).

## Current State (as of 2026-03-24 end of session)

### What works
- Recharts rendering (donut, radar, bar chart, sparklines)
- i18n translations (21 keys × 3 locales)
- Auto-login on localhost
- CI pipeline optimized
- Period selector (Today/This Week/This Month/All Time)
- DashboardEmptyState component
- Skeleton loaders
- Daily Goal progress bar (Today)
- Design system .card class and color tokens

### What needs fixing (next session)
- Score bar proportions (normalized to max, should be proportional to total)
- Typography inconsistency (text-lg vs text-sm for same semantic role)
- Activity Trend hidden when <2 data points (should always show for non-Today)
- Recharts click outlines still visible in some cases
- No legend↔chart hover linking
- TeamDashboard not updated yet
- Responsive not tested
- Locale labels not verified at all breakpoints

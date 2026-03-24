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
    │   ├── en.json                  # +26 translation keys (21 original + 5 i18n fixes)
    │   ├── uk.json                  # +26 translation keys
    │   └── ru.json                  # +26 translation keys
    └── features/workbench/review/
        ├── ReviewDashboard.tsx      # REWRITE — main dashboard component
        ├── TeamDashboard.tsx        # UPDATE — same design system treatment
        └── components/
            └── DashboardEmptyState.tsx  # Empty state with CTA
```

## Cross-Repository Dependencies

- **chat-types**: `DailyTrendPoint` type + `dailyTrend` field in `ReviewerDashboardStats` (v1.15.1)
- **chat-backend**: `dailyTrend` SQL query in `getReviewerStats` + team dashboard hardening
- **workbench-frontend**: all dashboard UI (primary repo for this feature)
- chat-frontend-common reverted to clean 0.5.0 (no chart components)

## Constitution Check

*GATE: Pre-design check passed 2026-03-23. Post-design re-check 2026-03-24.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Spec-First | PASS | spec.md v3 complete before implementation |
| II. Multi-Repo | PASS | Single repo (workbench-frontend), no cross-repo changes |
| III. Test-Aligned | PASS | Vitest + RTL available; Playwright QA planned (T028-T031) |
| IV. Branch Discipline | PASS | Feature branch `036-review-dashboard-redesign` from `develop` |
| V. Privacy/Security | N/A | No user data changes; read-only dashboard of existing stats |
| VI. A11y/i18n | PASS | 26 keys × 3 locales (en/uk/ru); 5 added for agreement labels, daily goal header, no-criteria text |
| VI-B. Design System | PASS | All colors from tailwind-preset.js; typography hierarchy defined; .card class used |
| VII. Split-Repo First | PASS | workbench-frontend is a split repo |
| VIII. GCP CLI | N/A | No infrastructure changes |
| IX. Responsive/PWA | PASS | Responsive grid planned (1440/1024/768/375px); PWA unaffected |
| X. Jira Traceability | PASS | Epic MTB-832; tasks have Jira keys |
| XI. Documentation | PENDING | User Manual update needed after implementation |
| XII. Release Engineering | N/A | No release in scope; dev validation only |

**Violations**: None. No Complexity Tracking entries required.

## Key Design Decisions

1. **No shared chart UI-kit** — charts render directly in page components using recharts. Custom SVG components produced poor quality and were reverted.
2. **Design system first** — all colors from tailwind-preset.js, all typography from defined hierarchy, all cards use .card class.
3. **Adaptive bottom section** — Today=Daily Goal Progress, other periods=Activity Trend.
4. **Radar with short labels** — 3-letter codes (REL, EMP, SAF, ETH, CLR) to fit all locales. Full names in side legend + hover tooltip.
5. **Legend ↔ Chart linking** — hover on legend row highlights corresponding chart element for interactivity.
6. **MVP with current API** — delta arrows, team average overlay, per-criterion trends deferred to Phase 2 (requires backend changes).

## Current State (as of 2026-03-24 end of session)

### Completed (T001-T027 + bug fixes + backend)
- All setup, i18n (26 keys × 3 locales), CI, dev tooling (T001-T013, T013a-T013b)
- Review Dashboard: data accuracy fixes, typography, Activity Trend visibility, focus outlines (T014-T017)
- Interactive charts: legend↔donut and legend↔radar hover linking, tooltip verification (T018-T021)
- Daily Goal & Activity Trend polish, radar pct scale with domain=[0,100] (T022-T023)
- Team Dashboard: full design system rewrite — .card class, typography, colors, Queue Depth hover linking (T024-T027)
- ChartTooltip component (design system standard for all charts)
- Chart CSS classes in index.css (chart-tooltip, chart-legend-row, chart-bar-track/fill, recharts sector opacity)
- Backend: `dailyTrend` API added to chat-backend (DailyTrendPoint in chat-types)
- Frontend uses dailyTrend for precise Daily Goal (fallback to weeklyTrend)

### Cross-repo changes
- **chat-types** (branch `036-review-dashboard-redesign`, merged to main): `DailyTrendPoint` type, `dailyTrend` field in `ReviewerDashboardStats`
- **chat-backend** (PR#183 → develop): daily trend SQL query + team dashboard hardening (merged with 038)
- **workbench-frontend** (PR#103 → develop): all dashboard UI changes (merged with 039 menu restructure)

### Remaining (T028-T031) — Visual QA

| Phase | Story | Tasks | Description |
|-------|-------|-------|-------------|
| 6 | US5 (P5) | T028-T031 | Playwright visual QA across periods/locales/viewports/interactions |

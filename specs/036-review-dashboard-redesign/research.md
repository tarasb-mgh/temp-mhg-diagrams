# Research: Review Dashboard Redesign

**Feature**: 036-review-dashboard-redesign
**Date**: 2026-03-23 (updated 2026-03-24)

## R1: Charting Library

**Decision**: Use recharts (~150kB, 16M+ weekly downloads).

**Rationale**: Initially attempted pure CSS/SVG custom chart components in chat-frontend-common. Produced poor visual quality — broken scaling, unreadable labels, incorrect proportions. Custom SVG charts require precise geometry math that AI agents cannot visually verify without a browser. Recharts provides production-grade rendering, ResponsiveContainer for adaptive sizing, built-in tooltips, and proper SVG geometry out of the box.

**Alternatives rejected**:
- Custom SVG UI-kit in chat-frontend-common: poor quality, 3 patch releases (0.4.0→0.4.2) to fix sizing issues, still broken
- Tremor (~200kB): heavier, opinionated SaaS styling
- Nivo (500kB+): too heavy for our needs

**Implementation notes**:
- Charts render directly in page components, NOT in a shared UI-kit library
- chat-frontend-common was reverted to 0.5.0 (clean, no chart components)
- recharts added as dependency to workbench-frontend only

## R2: Design System Compliance

**Decision**: All UI must use project design system tokens from `chat-frontend-common/tailwind-preset.js`.

**Rationale**: Initial implementation used raw hex colors (#059669, #34d399), arbitrary text sizes (text-[11px], fontSize: 9), and ad-hoc shadows (ring-1 ring-neutral-900/5). This produced an inconsistent "draft" look. Constitution VI-B now mandates design system compliance.

**Available tokens**:
- Colors: primary-* (slate-blue), secondary-* (sage-green), neutral-* (warm gray), accent-* (purple), success (#7a9f86), warning (#c9a86c), error (#c98686)
- Shadows: shadow-soft, shadow-soft-md, shadow-soft-lg
- Components: .card (bg-white rounded-2xl shadow-soft border border-neutral-200/60), .btn-*, .badge-*
- Font: Inter, system-ui

**Score range color palette** (using design system):
| Range | Color | Token source |
|-------|-------|-------------|
| Outstanding 9-10 | #658a72 | secondary-700 |
| Very Good 7-8 | #8fb39a | secondary-500 |
| Above Average 5-6 | #c9a86c | warning |
| Below Average 3-4 | #c4956b | warm orange (near warning) |
| Unacceptable 1-2 | #c98686 | error |

## R3: Radar Chart Labels

**Decision**: Use 3-letter codes (REL, EMP, SAF, ETH, CLR) as radar axis labels.

**Rationale**: Full criterion names ("Empathy", "Relevance") truncate at small radar sizes, especially in Ukrainian/Russian where words are longer. 3-letter codes fit in all locales at all sizes. Full names shown in side legend and on hover tooltip.

## R4: Activity Trend vs Daily Goal

**Decision**: Bottom section adapts to selected period.

**Rationale**: "Today" has no meaningful time series (no intra-day data points). Instead, show a Daily Goal progress bar that gamifies daily productivity. For other periods, show Activity Trend chart.

**Daily average formula**: totalReviews(allTime) / activeWeeks / 5 (workdays estimate). Computable on frontend from weeklyTrend data.

## R5: Local Development Setup

**Decision**: `.env.development.local` + auto-login script + `configureApi({ apiUrl, workbenchApiUrl })`.

**Rationale**: Dev backend is at `api.workbench.dev.mentalhelp.chat` (different from `api.dev.mentalhelp.chat`). Vite caches import.meta.env transforms in memory — `.env.development.local` only takes effect after Vite restart. Auto-login sends OTP programmatically on localhost in dev mode.

**Key files**:
- `scripts/dev-setup.sh` — creates .env.development.local, obtains OTP token
- `src/main.tsx` — configureApi with workbenchApiUrl, auto-login block
- `src/config.ts` — reads VITE_API_URL (no hacks needed when .env.development.local is correct)

## R6: CI Pipeline Optimization

**Decision**: Use checkout-based CI with PKG_TOKEN for cross-repo deps, upload/download artifact for deploy.

**Rationale**: npm registry auth (GITHUB_TOKEN, PKG_TOKEN) was unreliable. Checkout + local build pattern is established and works. Deploy job now downloads pre-built artifact from test job instead of re-building.

**Key change**: Added `tsc --noEmit` typecheck step to CI test job.

## R7: Backend Data Gaps

Current `ReviewerDashboardStats` API limitations for the full spec:

| Feature | Status | Notes |
|---------|--------|-------|
| Reviews count, avg score, agreement rate | Available | Current API |
| Score distribution (5 buckets) | Available | Current API |
| Criteria feedback counts | Available | Current API |
| Weekly trend (reviews + avg score) | Available | Current API |
| Delta vs previous period | NOT available | Needs backend: return previous period stats alongside current |
| Team average per criterion | NOT available | Needs backend: aggregate team stats per criterion |
| Per-criterion per-day trend | NOT available | Needs backend: granular time series per criterion |
| Daily average | Computable | Frontend calc from weeklyTrend |
| Criteria as percentages | Computable | Frontend calc: count / totalReviews |

**MVP scope**: implement with current API. Phase 2 = backend extensions for delta, team average, per-criterion trends.

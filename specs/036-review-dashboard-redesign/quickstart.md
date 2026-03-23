# Quickstart: Review Dashboard Redesign

**Feature**: 036-review-dashboard-redesign

## Prerequisites

- Node.js 18+ and npm
- Access to `chat-frontend-common` and `workbench-frontend` repositories
- Both repos cloned locally and on the `036-review-dashboard-redesign` branch

## Development Setup

### 1. Chat Frontend Common (UI-kit components)

```bash
cd chat-frontend-common
git checkout -b 036-review-dashboard-redesign develop
npm install
npm run dev  # Starts watch mode for library builds
```

### 2. Workbench Frontend (dashboard pages)

```bash
cd workbench-frontend
git checkout -b 036-review-dashboard-redesign develop
npm install
npm run dev  # Starts Vite dev server
```

### 3. Link local chat-frontend-common (for development)

```bash
cd chat-frontend-common
npm link

cd ../workbench-frontend
npm link @mentalhelpglobal/chat-frontend-common
```

## Key Files to Edit

### chat-frontend-common

| File | Action | Description |
|------|--------|-------------|
| `src/components/charts/DonutChart.tsx` | CREATE | Reusable donut/ring chart |
| `src/components/charts/RadarChart.tsx` | CREATE | Reusable radar/spider chart |
| `src/components/charts/Sparkline.tsx` | CREATE | Reusable micro-sparkline |
| `src/components/charts/DualAxisChart.tsx` | CREATE | Reusable bar+line dual-axis chart |
| `src/components/charts/index.ts` | CREATE | Barrel export |
| `src/index.ts` | UPDATE | Re-export charts module |

### workbench-frontend

| File | Action | Description |
|------|--------|-------------|
| `src/features/workbench/review/ReviewDashboard.tsx` | UPDATE | Bento layout, integrate charts, empty state, sparklines, color coding |
| `src/features/workbench/review/TeamDashboard.tsx` | UPDATE | Bento layout, donut for queue depth, remove report generator, add Reports link |
| `src/features/workbench/review/components/ScoreDistribution.tsx` | REPLACE | Integrate DonutChart from UI-kit |
| `src/features/workbench/review/components/DashboardEmptyState.tsx` | CREATE | Meaningful empty state with CTA |
| `src/locales/en.json` | UPDATE | Add ~20 missing translation keys |
| `src/locales/uk.json` | UPDATE | Add Ukrainian translations |
| `src/locales/ru.json` | UPDATE | Add Russian translations |

## Verification

### Dev environment

1. Open `https://workbench.dev.mentalhelp.chat/workbench/review/dashboard`
2. Verify period selector shows translated labels
3. If no review data: verify meaningful empty state with CTA
4. Resize browser to verify responsive bento-grid layout
5. Open `https://workbench.dev.mentalhelp.chat/workbench/review/team`
6. Verify donut chart for queue depth, translated labels, no embedded report generator

### Locale verification

Switch language selector to Ukrainian and Russian; verify all labels translate correctly on both dashboard pages.

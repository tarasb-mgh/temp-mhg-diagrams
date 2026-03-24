# Quickstart: 036 Review Dashboard Redesign — Next Session

**Read this file first. Do NOT start coding without completing all preparation steps.**

## 1. Read Context (mandatory, in order)

```
Read specs/036-review-dashboard-redesign/spec.md        — full spec v3
Read specs/036-review-dashboard-redesign/tasks.md       — tasks + "Key Context" section at bottom
Read specs/036-review-dashboard-redesign/research.md    — decisions + backend gaps
Read chat-frontend-common/tailwind-preset.js            — design system tokens
Read workbench-frontend/src/index.css                   — component classes (.card, .btn-*, recharts CSS)
```

## 2. Start Local Dev

```bash
cd /Users/malyarevich/dev/workbench-frontend
git checkout 036-review-dashboard-redesign

# If .env.development.local missing:
./scripts/dev-setup.sh pavelm@mentalhelp.global

# Start dev server (MUST restart if env changed):
npx vite --port 5174

# Auto-login happens automatically on localhost (dev mode)
# Navigate to: http://localhost:5174/workbench/review/dashboard
```

## 3. Verify Current State via Playwright

Take screenshot of current dashboard on all 4 periods:
- Today, This Week, This Month, All Time
- Identify what renders, what's broken

## 4. Fix Tasks (in order)

### T014: Score Distribution bar proportions
File: `src/features/workbench/review/ReviewDashboard.tsx`
Issue: bars may show 100% when all reviews in one range. Bars MUST be proportional to totalReviews.
Fix: verify `pct = (count / totalReviews) * 100` — this should already be correct but test with different data.

### T015: Typography consistency
File: `src/features/workbench/review/ReviewDashboard.tsx`
Issue: Criteria Breakdown count = `text-lg font-bold` but Score Distribution count = `text-sm font-semibold`. 
Fix: Both must use `text-sm font-semibold text-neutral-700` per typography hierarchy.

### T016: Activity Trend always visible
File: `src/features/workbench/review/ReviewDashboard.tsx`
Issue: `trendData.length >= 2` check hides chart with 1 data point. Spec says always show for non-Today.
Fix: change to `trendData.length > 0` (or remove check entirely for non-Today).

### T017: Recharts focus outlines
Files: `src/index.css`, `ReviewDashboard.tsx`
Issue: click on donut/radar may still show blue outline.
Fix: test in browser. If still visible, add `outline: none` to more selectors or use recharts `onMouseDown={(e) => e?.preventDefault?.()}`.

### T018-T019: Legend ↔ Chart hover linking
File: `src/features/workbench/review/ReviewDashboard.tsx`
Pattern:
```tsx
const [activeScoreIndex, setActiveScoreIndex] = useState<number | undefined>(undefined);
// On legend row: onMouseEnter={() => setActiveScoreIndex(i)} onMouseLeave={() => setActiveScoreIndex(undefined)}
// On Pie: activeIndex={activeScoreIndex} activeShape with increased outerRadius
```

### T020-T021: Verify tooltips
Test hover on donut segments and radar dots. Tooltips should show dark compact style with name + count + percentage.

### T022-T023: Daily Goal + Trend polish
Switch to Today → verify progress bar. Switch to This Week → verify bar chart.

## 5. After Fixes — Visual QA Checklist

Run through Playwright:
- [ ] Today: KPI cards + Score Distribution + Criteria Breakdown + Daily Goal
- [ ] This Week: same + Activity Trend (bar chart)
- [ ] This Month: same + Activity Trend
- [ ] All Time: same + Activity Trend
- [ ] Switch locale to Ukrainian → all labels fit
- [ ] Switch locale to Russian → all labels fit
- [ ] Hover donut segment → dark tooltip with name + count + %
- [ ] Hover radar dot → dark tooltip with full name + count + % of reviews
- [ ] Hover legend row → corresponding chart element highlights
- [ ] Click donut/radar → NO blue outline/border
- [ ] Responsive 1024px → 2-col grid
- [ ] Responsive 375px → single column, charts readable

## 6. Then Team Dashboard (T024-T026)

Apply same patterns to TeamDashboard.tsx. Same .card class, same typography, recharts PieChart for Queue Depth.

## Key Rules (from Constitution VI-B)

- Colors: ONLY design system tokens. No raw hex in JSX (except SVG chart fills where Tailwind can't apply).
- Typography: ONLY Tailwind scale (text-xs through text-3xl). No text-[11px].
- Cards: .card class. No ad-hoc border+shadow combos.
- Shadows: shadow-soft family. No shadow-sm, ring-1.
- Verify ALL changes visually via Playwright before committing.
- Commit after each completed task group, not at the end.

# Quickstart: Validate Frontend + Backend Split

## Scope

Validate feature `001-split-workbench-app` across dev and release candidate
stages with both frontend and backend split boundaries.

## Prerequisites

- Feature branches in affected repos: `chat-frontend`, `chat-backend`,
  `chat-ui`, `chat-infra`, and if needed `chat-ci`.
- Test users:
  - one without workbench permissions,
  - one with workbench permissions.
- Latest deployment URLs and backend service revisions from the same deploy cycle.

## 1) Domain topology validation (dev + prod-like stage)

1. Confirm chat hosts remain unchanged for FE/API.
2. Confirm workbench FE/API hosts are dedicated and canonical:
   - prod: `workbench.mentalhelp.chat`, `api.workbench.mentalhelp.chat`
   - dev: same naming pattern for workbench FE/API hosts.
3. Confirm DNS and LB rules resolve each host to the intended surface/service.

## 2) Backend service split and scaling validation

1. Confirm chat-api and workbench-api deploy independently.
2. Trigger controlled scaling/load on one backend service.
3. Verify the other backend service remains stable and unaffected.
4. Capture service revision IDs and scaling evidence.

## 3) Entry-point and deep-link validation

1. Sign in and open chat entry point; verify chat-only controls and chat API host usage.
2. Sign in and open workbench entry point; verify workbench-only controls and workbench API host usage.
3. Validate deep links for both surfaces resolve correctly.

## 4) Access-policy and contract isolation validation

1. With chat-only user, attempt workbench routes and workbench API calls.
2. Verify denial behavior and fallback guidance.
3. With workbench-authorized user, verify allowed access and context retention.
4. Verify workbench-only capabilities are not exposed via chat API paths.

## 5) Legacy-route continuity validation

1. Test known legacy bookmarks/routes in scope.
2. Verify deterministic mapping to canonical split hosts/routes.
3. Complete critical journeys after redirect/mapping.

## 6) Responsive breakpoint verification checklist

| Viewport | Width | Chat Surface | Workbench Surface |
|---|---|---|---|
| Mobile (portrait) | 375px | [ ] No horizontal overflow, controls touch-friendly | [ ] Sidebar collapsed, nav accessible |
| Mobile (landscape) | 812px | [ ] Layout adjusts, no clipped content | [ ] Layout adjusts, no clipped content |
| Tablet (portrait) | 768px | [ ] Comfortable reading width | [ ] Sidebar + content both visible |
| Tablet (landscape) | 1024px | [ ] Full layout, no wasted space | [ ] Full layout with sidebar |
| Desktop | 1440px | [ ] Centered content, max-width respected | [ ] Full workbench dashboard |

### Responsive verification steps

1. Open chat surface at each viewport; confirm no horizontal scrollbar.
2. Open workbench surface at each viewport; confirm sidebar is usable.
3. Verify touch targets are at least 44x44px on mobile/tablet.
4. Verify text is readable without zooming on all viewports.

## 7) PWA installability and fallback verification

- [ ] `manifest.json` is present and valid at both surface roots
- [ ] Service worker registers on both surfaces
- [ ] "Add to Home Screen" prompt appears on supported mobile browsers
- [ ] Offline fallback page is shown when network is unavailable
- [ ] If PWA install is unsupported (desktop Firefox, older browsers), app functions normally as web app

## 8) Accessibility and localization continuity

### Accessibility checks
- [ ] All pages have `lang` attribute on `<html>`
- [ ] All interactive elements are keyboard-focusable (Tab/Shift+Tab)
- [ ] Focus order follows visual reading order on both surfaces
- [ ] Screen reader announces page headings and navigation items
- [ ] Color contrast meets WCAG 2.1 AA (4.5:1 for body text)
- [ ] All form inputs have associated labels
- [ ] Error messages are announced to screen readers

### Localization checks
- [ ] Language selector works on both surfaces
- [ ] All visible text renders correctly in each supported locale (en, ru, uk)
- [ ] No untranslated keys visible (no `workbench.nav.*` raw keys)
- [ ] RTL layout not required for current locales (LTR only)

## 9) Regression evidence and smoke checks

1. Capture console errors and non-static network anomalies (endpoint + status).
2. Capture route, deep-link, and key API smoke outcomes for both surfaces.
3. Record CORS behavior for cross-host FE/API combinations.
4. Store evidence under feature evidence paths per repository policy.

## 10) Integration policy reminders

1. Merge only via PRs into `develop` with required approvals/checks.
2. Verify gates in all affected repositories before promotion.
3. Delete merged remote/local feature branches and sync local `develop`.

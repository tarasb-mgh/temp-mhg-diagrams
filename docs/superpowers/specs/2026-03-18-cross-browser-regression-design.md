# Cross-Browser Regression Test Suite — Design Document

**Date**: 2026-03-18
**Status**: Approved
**Spec**: 033-cross-browser-regression

## Goal

Add visual and functional regression testing across 3 browser engines (Chromium, Firefox, WebKit) × 3 viewport classes (phone, tablet, desktop) — 9 configurations total — running in headless mode via Playwright, with hybrid CI integration.

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Opera support | Excluded | Same Blink/V8 engine as Chromium; zero additional bug detection |
| Device matrix | 3×3 viewport-class | Covers meaningful rendering breakpoints without exploding CI time |
| Visual regression | Full-page + component-level | Critical flows get full-page; shared UI gets component-level |
| Pixel diff threshold | 0.5% (`maxDiffPixelRatio: 0.005`) | Handles cross-browser anti-aliasing/font rendering variance |
| Snapshot storage | Playwright built-in `__snapshots__/` | Purpose-built, no external deps; migrate to LFS if repo grows |
| CI strategy | Hybrid (PR reduced + nightly full) | Fast PR feedback (~5-7 min) + full coverage nightly |
| Flow coverage | All 7 critical flows | Maximum functional regression coverage |

## Browser/Device Matrix

| | Phone (iPhone 14: 390×844) | Tablet (iPad Mini: 768×1024) | Desktop (1920×1080) |
|---|---|---|---|
| **Chromium** | chromium-phone | chromium-tablet | chromium-desktop |
| **Firefox** | firefox-phone | firefox-tablet | firefox-desktop |
| **WebKit** | webkit-phone | webkit-tablet | webkit-desktop |

All 9 projects run headless. Device emulation uses Playwright's built-in device descriptors for viewport, `hasTouch`, `isMobile`, and user-agent.

## Functional Regression — 7 Critical Flows

Each flow executes across all 9 configurations:

1. **Authentication** — OTP login (verify dashboard loads), session persistence (reload preserves auth), logout (redirects to login page)
2. **Chat** — send message (message appears in chat panel), receive assistant response (response element visible AND loading indicator absent within 30s timeout), message history (previous messages render on page load)
3. **Workbench dashboard** — load review queue (list of sessions renders; test precondition: uses the `playwright@mentalhelp.global` fixture account which has pre-seeded reviewable sessions in the dev environment), session list (sessions display status badges)
4. **Review flow** — open session (messages load in review panel), view messages (all assistant/user messages render), submit review (success toast appears and session status transitions from "pending" to "reviewed")
5. **Survey management** — create survey (survey persisted and appears in survey list on reload), edit survey (modified fields persist on save), preview survey (each field label and value visible in the preview panel equals the corresponding value entered in the editor form fields, verified via DOM text content assertion)
6. **Group/space navigation** — switch groups (group name in active-group indicator matches selected group AND either at least one session row is visible or the empty-state placeholder is visible — loading spinner absent), verify data isolation (sessions from other groups are not visible in the filtered list)
7. **Responsive layout** — sidebar collapse (sidebar hidden and hamburger menu visible on phone viewport), mobile nav (tap hamburger opens nav overlay), touch interactions (swiping left on the chat panel dismisses the sidebar; assert sidebar element has `display: none` or is removed from DOM)

## Visual Regression Strategy

### Full-Page Screenshots
Captured at key states for each of the 7 flows:
- Post-login dashboard
- Chat view with messages loaded
- Workbench review queue
- Review form with session messages
- Survey editor/preview
- Group switcher with active selection
- Mobile nav expanded / sidebar collapsed

### Component-Level Screenshots
Targeted captures for shared UI components:
- Header / navigation bar
- Sidebar (expanded and collapsed states)
- Chat message panel
- Modal dialogs
- Form controls (inputs, selects, buttons)
- Toast notifications

### Comparison Settings
- Pixel diff threshold: 0.5% (`maxDiffPixelRatio: 0.005`); diffs at or below 0.5% pass, above 0.5% fail
- Baselines stored via Playwright `toMatchSnapshot()` in `__snapshots__/` directories
- Organized by project name (e.g., `__snapshots__/chromium-phone/`)
- Update workflow: `npx playwright test --update-snapshots` for intentional UI changes
- **Baseline bootstrap**: On first run (no existing snapshots), run `npx playwright test --update-snapshots` locally on `develop` to generate initial baselines, commit them, then all subsequent CI runs compare against these committed baselines
- **Baseline update process**: When intentional UI changes cause snapshot failures: (1) developer runs `--update-snapshots` locally (never in CI — CI must reject any `--update-snapshots` flag), (2) reviews the diff visually, (3) commits updated snapshots in the same PR as the UI change, (4) PR review must include explicit snapshot diff approval from a reviewer before merge

## CI Integration

### PR to `develop` (fast feedback)
- **Matrix**: Chromium × 3 viewports = 3 configurations
- **Scope**: Functional + visual regression
- **Duration**: ~5-7 minutes
- **Behavior**: Blocks merge on failure

### Nightly Scheduled (full coverage)
- **Matrix**: All 9 configurations (3 browsers × 3 viewports)
- **Target**: Deployed `https://dev.mentalhelp.chat` and `https://workbench.dev.mentalhelp.chat`
- **On failure**: Creates a single GitHub issue per nightly run with: failed test names, browser/viewport configs affected, and links to HTML report artifact. If an open nightly-regression issue already exists, adds a comment instead of creating a duplicate.
- **Artifacts**: HTML report + Playwright trace files (retained for 14 days)

### Manual Trigger (`workflow_dispatch`)
- Full 9-config matrix on demand
- Use case: pre-release verification

## File Structure (chat-ui repo)

```
chat-ui/
├── playwright.config.ts              # 9 projects defined
├── tests/e2e/
│   ├── regression/
│   │   ├── auth.regression.spec.ts
│   │   ├── chat.regression.spec.ts
│   │   ├── workbench.regression.spec.ts
│   │   ├── review.regression.spec.ts
│   │   ├── survey.regression.spec.ts
│   │   ├── group-nav.regression.spec.ts
│   │   ├── responsive.regression.spec.ts
│   │   └── visual/
│   │       ├── full-page.visual.spec.ts
│   │       └── components.visual.spec.ts
│   └── fixtures/
│       └── regression.fixture.ts     # Shared setup: auth state, viewport assertions
├── .github/workflows/
│   ├── regression-pr.yml             # PR: chromium × 3 viewports
│   ├── regression-nightly.yml        # Nightly: full 9-config matrix
│   └── regression-manual.yml         # Manual: workflow_dispatch
```

## Playwright Config — Project Definitions

Extends existing config with 9 named projects. Each project specifies:
- `name`: `{browser}-{viewport}` (e.g., `chromium-phone`)
- `use.browserName`: `chromium` | `firefox` | `webkit`
- `use.viewport`: device-specific dimensions
- `use.hasTouch`: `true` for phone/tablet
- `use.isMobile`: `true` for phone
- `use.userAgent`: from Playwright device descriptors
- `use.headless`: `true`

## Suite-Level Success Criteria

- **PR gate**: All 3 Chromium configurations (phone, tablet, desktop) must pass all 7 functional flows and all visual comparisons. Any failure blocks merge.
- **Nightly gate**: All 9 configurations must pass all 7 flows and all visual comparisons. Any failure creates/updates a GitHub issue. Two consecutive nightly failures on the same test/config combination triggers a `P1` label on the issue. Consecutive tracking mechanism: the nightly workflow queries open issues with the `nightly-regression` label for a comment matching the failed test+config pattern from the prior run; if found, the workflow adds the `P1` label.
- **Release readiness**: A release candidate requires a full 9-config nightly run with zero failures within the preceding 24 hours.

## Edge Cases and Failure Modes

1. **Dev environment down**: If the target URL (`dev.mentalhelp.chat`) is unreachable, tests fail at navigation, not at assertions. The nightly workflow should include a health-check step (`curl -f https://api.dev.mentalhelp.chat/health`) before running tests. If the health check fails, the workflow exits with a distinct "environment-unavailable" status and does not create a regression issue.
2. **Firefox/WebKit OTP clipboard restrictions**: Headless Firefox and WebKit may not support clipboard API for OTP extraction. The auth fixture must retrieve OTP from browser console output (existing pattern from spec 007) rather than clipboard, ensuring cross-browser compatibility.
3. **Test data absence**: All regression tests depend on the `playwright@mentalhelp.global` fixture account having pre-seeded data (sessions, surveys, groups). If data is missing, tests fail with assertion errors, not infrastructure errors. A precondition check at suite startup should verify the fixture account has the required data and fail fast with a descriptive error if not.
4. **Stale baselines accepted silently**: Mitigated by prohibiting `--update-snapshots` in CI and requiring PR reviewer approval of snapshot diffs (see Baseline update process above).
5. **Snapshot flakiness from dynamic content**: Timestamps, relative dates, and animation states cause non-deterministic screenshots. Tests must freeze time (`page.clock`) and disable CSS animations (`*, *::before, *::after { animation: none !important; transition: none !important; }`) before capturing visual snapshots.
6. **WebKit auth state incompatibility**: WebKit's Intelligent Tracking Prevention (ITP) in headless mode may silently invalidate session cookies from shared `storageState`, causing auth failures that manifest as data-absence errors. Mitigation: each browser project performs a fresh OTP login via the auth fixture rather than reusing cross-browser `storageState` files. Auth state files are stored per-project (e.g., `.auth/chromium-phone.json`).

## Out of Scope

- Opera browser (same rendering engine as Chromium)
- Real device testing / device farms (BrowserStack, Sauce Labs)
- Performance / load testing
- Accessibility testing (separate concern)
- Git LFS for snapshots (migrate later if repo size becomes a concern)
- API-level regression testing (covered by backend unit/integration tests)

# Quickstart: Restore Missing Workbench Navigation Links

## Prerequisites

- `workbench-frontend` repository cloned and on `053-restore-nav-links` branch
- Node.js and npm installed
- Dev environment deployed: `https://workbench.dev.mentalhelp.chat`

## Validation Checklist

### 1. Tag Center link in sidebar

1. Open `https://workbench.dev.mentalhelp.chat` and log in with an account that has `TAG_MANAGE` permission.
2. Look at the sidebar "People & Access" group.
3. Confirm "Tag Center" appears as the first item, before "Users".
4. Click "Tag Center" — the Tag Center page should load.
5. Confirm the sidebar item is highlighted (primary color, bold text).
6. Navigate away and back — highlight should follow correctly.

### 2. Tag Center permission gating

1. Log in with an account that does NOT have `TAG_MANAGE` permission.
2. Confirm "Tag Center" does NOT appear in the sidebar.
3. Confirm the "People & Access" group hides entirely if no other items are visible.

### 3. Settings link in sidebar (desktop)

1. Open the workbench on a desktop viewport (≥ 1024px).
2. Confirm "Settings" appears at the bottom of the sidebar navigation, before "Back to Chat".
3. Click "Settings" — the Settings page should load.
4. Confirm the sidebar item is highlighted when on `/workbench/settings`.
5. Confirm Settings is ALSO still accessible via the avatar dropdown menu.

### 4. Settings link in sidebar (mobile)

1. Open the workbench on a mobile viewport (< 768px) or use browser DevTools.
2. Tap the hamburger menu to open the sidebar.
3. Confirm "Settings" is visible in the sidebar.
4. Tap "Settings" — the Settings page should load and the sidebar should close.

### 5. Settings link in sidebar (tablet)

1. Open the workbench on a tablet viewport (768–1023px).
2. Confirm "Settings" is visible in the sidebar.
3. Click "Settings" — the Settings page should load.

### 6. Visual consistency

1. Compare the Tag Center nav item against Users, Groups, Review Queue:
   - Same icon size (20px / `w-5 h-5`)
   - Same padding and height
   - Same hover state (neutral-50 background)
   - Same active state (primary-50 background, primary-700 text)
2. Compare the Settings nav item against the Dashboard button for the same consistency checks.

### 7. No regression

1. Confirm all previously visible sidebar items still appear and function.
2. Confirm group collapse/expand behavior still works.
3. Confirm breadcrumbs display correctly for Tag Center and Settings pages.

## E2E Test Evidence

- `chat-ui/tests/e2e/workbench/` — navigation tests should cover:
  - Tag Center appears for `TAG_MANAGE` user, hidden otherwise
  - Settings visible on mobile, tablet, desktop viewports
  - Click navigation works for both items
  - Active state highlighting

## Responsive Viewports

| Viewport | Width | Expected behavior |
|----------|-------|-------------------|
| Mobile | 375px | Both links in hamburger sidebar, 44px touch targets |
| Tablet | 768px | Both links in sidebar |
| Desktop | 1280px | Both links in sidebar, Settings also in avatar dropdown |

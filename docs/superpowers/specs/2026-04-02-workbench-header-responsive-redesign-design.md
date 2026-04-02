# Workbench Header Responsive Redesign

**Date**: 2026-04-02
**Status**: Design Complete

## Goal

Redesign the workbench header bar to be fully functional across all viewports (mobile, tablet, desktop) with the Space selector accessible at every breakpoint, compact icon-based controls, and a cleaner information hierarchy.

## Current Problems

1. **Space selector invisible below 1024px** — users cannot switch spaces on tablet or mobile
2. **Language selector shows full text** ("English") — wastes horizontal space; hidden entirely on mobile
3. **PII toggle shows full text** ("PII Masked") — wastes space; icon alone is sufficient with tooltip
4. **User name shown in header on tablet** — consumes space that could be used for the space selector
5. **User name is masked when PII is masked** — the logged-in user shouldn't mask their own name
6. **"Workbench / Admin Panel" title is not clickable** — should link to dashboard
7. **No overflow menu** — elements hidden on smaller viewports have no alternative access point

## Design

### Element Behavior by Viewport

| Element | Desktop (>=1024px) | Tablet (640-1024px) | Mobile (<640px) |
|---------|-------------------|---------------------|-----------------|
| PII Toggle | Eye icon + tooltip on hover | Eye icon + tooltip | Eye icon + tooltip |
| Language Selector | Flag icon only; dropdown shows flag + full name | Flag icon only | Flag icon only |
| Space Selector | Dropdown in header | Dropdown in header | Inside burger/sidebar menu |
| User Name + Role | Visible in header | Inside burger/sidebar menu | Inside burger/sidebar menu |
| Sign Out | Icon button in header | Inside burger/sidebar menu | Inside burger/sidebar menu |
| Workbench Title | Clickable, navigates to /workbench | Same | Same |

### PII Toggle

- All viewports: render as icon-only button (Eye / EyeOff icon)
- Add `title` attribute for native tooltip: "PII Masked" / "PII Visible"
- Keep the colored status dot next to the icon (green = visible, amber = masked) at all breakpoints
- Do NOT mask the currently logged-in user's own display name

### Language Selector

- All viewports: show only the flag emoji as the selected value display
- The dropdown options keep full names: "English", "Українська", "Русский"
- This is a visual-only change — the `<select>` still contains all options with full names, but the displayed selected value is just the flag

### Space Selector

- Desktop + Tablet: render in the header bar (between PII toggle and user area)
- Mobile (<640px): render inside the sidebar/burger menu, above the navigation items
- The component itself (GroupScopeSelector) doesn't change — only its mount point shifts

### User Display

- Desktop: show avatar + name + role in the header
- Tablet + Mobile: move user info (name, role, sign out) into the sidebar/burger menu
  - Show at the bottom of the sidebar, above "Back to Chat"
  - Avatar + full name + role + Sign Out button
- The user's own display name is NEVER masked by PII toggle (it's the logged-in user — masking yourself is nonsensical)

### Workbench Title

- Make the "Workbench / Admin Panel" block in the sidebar header clickable
- On click, navigate to `/workbench` (dashboard)
- Add cursor: pointer and subtle hover effect

### Header Layout (Simplified)

**Desktop (>=1024px)**:
```
[☰ if sidebar closed] [👁●] [🇬🇧▾] [Space: All Spaces ▾] [👤 Pavel Malyarevich · Owner ▾] [→]
```

**Tablet (640-1024px)**:
```
[☰] [👁●] [🇬🇧▾] [Space: All Spaces ▾]
```
(User name + sign out moved to sidebar)

**Mobile (<640px)**:
```
[☰] [👁●] [🇬🇧▾]
```
(Space selector + user name + sign out in sidebar)

### Sidebar Addition (Tablet + Mobile)

At the bottom of the sidebar, above "Back to Chat":
```
──────────────
👤 Pavel Malyarevich
   Owner
[Space: All Spaces ▾]  ← only on mobile
[Sign Out →]
──────────────
[← Back to Chat]
```

## Acceptance Criteria

1. Space selector is accessible and functional at all viewports (mobile, tablet, desktop)
2. PII toggle renders as icon-only with tooltip at all viewports
3. Language selector shows flag-only; dropdown preserves full names
4. User's own name is never masked by PII toggle
5. User info (name, role, sign out) appears in sidebar on tablet/mobile
6. "Workbench" title is clickable and navigates to dashboard
7. No functional regressions — all existing header actions remain accessible
8. Touch targets are at least 44x44px on mobile

## Affected Repositories

- `workbench-frontend` only (header layout is entirely frontend)
- No backend changes needed
- `chat-frontend-common` may need a compact `LanguageSelector` variant (flag-only display)

## Out of Scope

- Sidebar navigation restructuring (only adding user info block at bottom)
- Design system token changes
- New components — reuse existing UI patterns

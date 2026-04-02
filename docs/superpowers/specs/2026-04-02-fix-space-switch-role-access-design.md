# Fix Space Switch Role Access — Design Spec

**Date:** 2026-04-02
**Status:** Draft
**Feature:** Fix workbench Space selector to respect global role access when switching spaces
**Related:** Spec 034 (Global Role Group Access), Spec 035 (Dynamic Permissions Engine — disabled)

---

## Problem Statement

Despite Spec 034 defining a two-tier access resolution model (membership OR global role >= Researcher), the workbench Space selector still enforces membership-only access when switching spaces. When a global role holder (Researcher, Supervisor, Moderator, Owner) selects a Space they are not a member of, the system falls back to the first Space where they have membership. This defeats the purpose of the global role access model.

## Root Cause Analysis

The issue likely exists in one or more of these locations:

1. **Backend `setActiveGroup()`** in `groupMembership.service.ts` — may still validate membership even for global role holders despite T012 claiming this was fixed
2. **Backend `GET /api/admin/groups`** — may not return all groups for Researcher+ roles, causing the dropdown to show incomplete list
3. **Frontend `GroupScopeSelector.tsx`** — may have fallback logic that resets to a membership-based group when the backend response doesn't match expectations
4. **Frontend active group state management** — may re-validate membership client-side after setting active group

## Goal

Global role holders (Researcher, Supervisor, Moderator, Owner) can switch to ANY Space via the workbench header dropdown without being redirected or reset to a different Space. The fix must work within the current static permission mechanism and remain compatible with the future Dynamic Permissions Engine (spec 035).

## Acceptance Criteria

1. Researcher with zero memberships sees ALL spaces in dropdown and can select any one — selection persists
2. Owner selects a Space they're not a member of — stays on that Space after page refresh
3. QA Specialist sees only membership-gated spaces (no regression)
4. `setActiveGroup()` skips membership check for `GLOBAL_GROUP_ACCESS_ROLES`
5. Frontend does not fallback/redirect when backend returns 200 for space switch
6. No changes to chat-frontend — membership still gates chat participation
7. Compatible with future `DYNAMIC_PERMISSIONS_ENABLED` flag activation

## Technical Approach

- Audit `setActiveGroup()` to ensure `hasGlobalGroupAccess(role)` bypass is actually working
- Audit `GET /api/admin/groups` endpoint to confirm it returns all groups for Researcher+ roles
- Audit `GroupScopeSelector.tsx` for any client-side membership validation or fallback logic
- Fix identified gaps without changing the `canAccessGroup()` interface
- Add regression tests for the space-switch flow

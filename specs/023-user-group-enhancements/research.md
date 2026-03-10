# Research: User Group and Management Interface Enhancements

**Date**: 2026-03-10
**Branch**: `023-user-group-enhancements`

---

## Decision 1: Spaces List Refresh Mechanism (US2)

**Decision**: Post-API reactive re-fetch triggered by a Zustand `groupListVersion` counter in `workbenchStore`, plus a 30-second polling interval in `GroupScopeSelector`.

**Rationale**:
- `GroupScopeSelector` (in `WorkbenchLayout`) is a sibling to the page components — it lives above `GroupsView` in the tree. A shared store signal (incrementing counter) is the cleanest way to notify it without prop-drilling.
- Polling at 30 s provides the fallback required by the clarification (A+C answer) without WebSocket infrastructure.
- 30 s is well within the SC-002 2-second target for the reactive path; the polling fallback simply catches edge cases where the signal is missed.

**Alternatives considered**:
- React Context event emitter — more complex, not aligned with the Zustand-first patterns already in workbench-frontend.
- WebSocket / SSE push — over-engineered for a group-creation frequency of at most a few times per day.
- Re-fetching inside `initializeAuth()` — would refresh the full auth token; too heavy for a list refresh.

**Implementation detail**: `workbenchStore` gains `groupListVersion: number` and `bumpGroupListVersion()`. `GroupsView.handleCreateGroup` calls `bumpGroupListVersion()` after a successful API response. `GroupScopeSelector` `useEffect` depends on `groupListVersion` to re-fetch managed groups. A separate `useInterval`-style `useEffect` runs every 30 000 ms.

---

## Decision 2: Privileged Account Group Membership — Backend Change (US1)

**Decision**: Remove `OWNER`, `MODERATOR`, and `SUPERVISOR` from the `FORBIDDEN_TARGET_ROLE` blocklist in `group.service.ts:addUserToGroup`. Retain the block for `RESEARCHER` and `GROUP_ADMIN`.

**Rationale**:
- The restriction at `group.service.ts:305` was: `['owner', 'moderator', 'researcher', 'supervisor', 'group_admin']`.
- The spec defines "privileged accounts" as users with system-wide elevated roles (admins, supervisors) that SHOULD be able to join groups.
- `RESEARCHER` and `GROUP_ADMIN` roles are not "privileged accounts" in the spec's sense; they are workbench-specific roles that should remain excluded from group membership manipulation via the admin groups API.
- `OWNER`, `MODERATOR`, and `SUPERVISOR` need to be able to participate in groups as members per FR-001.

**Alternatives considered**:
- Remove the entire check — rejected because `RESEARCHER`/`GROUP_ADMIN` should not be group participants via this API.
- Add a separate API endpoint for privileged participation — over-engineered; the same endpoint works with a narrowed blocklist.

---

## Decision 3: Privileged Account Identification — Frontend (US3, US7)

**Decision**: Use the `UserRole` enum from `@mentalhelpglobal/chat-types` to identify privileged accounts as roles `OWNER`, `MODERATOR`, and `SUPERVISOR`. A frontend utility `isPrivilegedRole(role: UserRole): boolean` is added to the local `types/` directory of `workbench-frontend`.

**Rationale**:
- The `UserRole` enum is already imported throughout `workbench-frontend`. A simple helper avoids inline role comparisons scattered across components.
- `OWNER` has all permissions; `MODERATOR` has `WORKBENCH_USER_MANAGEMENT`; `SUPERVISOR` has group-level workbench permissions — all three are "system-wide elevated."
- `GroupScopeSelector` currently uses `canManageUsers` (which covers `OWNER` and `MODERATOR` but NOT `SUPERVISOR`) for "always show dropdown." Adding an explicit `isPrivilegedRole` check on `user.role` correctly covers all three roles per FR-004.

**Alternatives considered**:
- Rely solely on `WORKBENCH_USER_MANAGEMENT` permission — misses `SUPERVISOR` role (which lacks that permission but is still "privileged").
- Add `isPrivileged` flag to the User type in `chat-types` — deferred; the `UserRole` check is sufficient for this feature and does not require a types package bump.

---

## Decision 4: Survey Cross-Group Deduplication (US5)

**Decision**: Deduplication is **already implemented** at the database level. No backend changes required for US5.

**Rationale**:
- A survey instance can be assigned to multiple groups via the `survey_instances.group_ids[]` array column.
- `getGateCheck` in `surveyResponse.service.ts` excludes any instance where the user (`pseudonymous_id`) has a non-invalidated complete response — regardless of which group the response was associated with.
- This means completing a survey shared across groups (single `instance_id` with multiple `group_ids`) marks it complete for all groups that share the instance.
- US5's acceptance scenarios all describe this "same instance shared across groups" pattern, which is the canonical usage.

**Scope**: The implementation task for US5 is to write a Playwright E2E test that proves this behavior. No backend service code changes are needed.

---

## Decision 5: Invalidation Menu Architecture (US6)

**Decision**: Extract a reusable `InvalidationMenu` component (`surveys/components/InvalidationMenu.tsx`) that renders an "Invalidation" dropdown button. Each action in the menu opens a shared confirmation modal (replacing `window.prompt()`). Render the component in both `SurveyInstanceDetailView` and `SurveyResponseListView`.

**Rationale**:
- `SurveyInstanceDetailView` and `SurveyResponseListView` both have identical invalidation controls (invalidate instance, invalidate group, invalidate single response). A shared component eliminates duplication and ensures both views comply with FR-008 and FR-009 simultaneously.
- Using `window.prompt()` for confirmation is not accessible, not styleable, and violates WCAG guidelines for modal dialogs. A React-based modal is required.
- The "Invalidation" menu is restricted to `SURVEY_INSTANCE_MANAGE` permission (already gated in route config); within the menu, higher-risk actions (invalidate all, invalidate group) are shown only for `OWNER` + `MODERATOR` roles per FR-008a.

**Alternatives considered**:
- Inline modal state per view — duplicates confirmation logic; rejected.
- A global Zustand modal slice — over-engineered for this scope; local component state is sufficient.

---

## Decision 6: Search Filter Preservation (US8)

**Decision**: Move search, role filter, status filter, and sort state in `UserListView` to URL search params (`useSearchParams`). When navigating back from `UserProfileCard`, the browser history preserves the full URL, restoring filters automatically.

**Rationale**:
- Currently, all filter state is in component local state. Navigating to a user card and pressing back re-mounts `UserListView`, resetting all state to defaults.
- Encoding filters in URL search params is the idiomatic React Router v6 solution: it requires no custom history management, works with browser back button, and is bookmarkable.
- `statusFilter` already reads from `searchParams.get('status')` — this pattern just needs to be extended to all filter fields.

**Alternatives considered**:
- Zustand persistence — adds boilerplate and persists state across unrelated navigations.
- Session storage — works but fragile; URL is canonical.

---

## Decision 7: Copy-to-Clipboard Implementation (US8)

**Decision**: Use `navigator.clipboard.writeText()` with a 2-second icon state change (copy icon → check icon) as visual feedback. No toast library needed — icon state change is sufficient per the Assumptions in the spec.

**Rationale**:
- `navigator.clipboard.writeText()` is supported in all target browsers (modern Chromium/Safari).
- The Lucide icon library (already a dependency) has both `Copy` and `Check` icons.
- Toggling the icon for 2 s provides clear visual feedback without adding a toast notification library dependency.

**Alternatives considered**:
- `document.execCommand('copy')` — deprecated; rejected.
- External toast library — unnecessary dependency for a single use case.

---

## Decision 8: Polling Interval Implementation (US2)

**Decision**: Implement polling via a standard `useEffect` with `setInterval` inside `GroupScopeSelector`, scoped to `canManageUsers` (only privileged users who see the managed groups list need polling).

**Rationale**:
- Non-privileged users' group membership comes from `user.memberships` (part of JWT auth data), not from a separate groups API call. Polling the groups API for non-privileged users has no effect.
- `canManageUsers` users load from `adminGroupsApi.list()` which is the endpoint that needs refreshing.
- 30-second interval is low-traffic and will not stress the backend.

**Implementation note**: The `setInterval` is cleared in the `useEffect` cleanup function to prevent memory leaks when the component unmounts.

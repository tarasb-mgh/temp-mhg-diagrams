# Research: Move Privacy to Security & Hide Escalations

**Feature**: 039-menu-privacy-escalations  
**Date**: 2026-03-24

## Research Topics

### 1. Security Group Permission Filtering

**Decision**: Remove the `group.id === 'security'` special case in `visibleGroups` and let all groups pass through `filterByPermission`.

**Rationale**: The security group currently bypasses per-item permission filtering because its original items (Dashboard, Principal Groups, Permissions, Assignments, Effective Viewer) have no `permission` field — they rely entirely on the group-level `isSecurityAdmin` gate. Adding Privacy (which has `permission: Permission.WORKBENCH_PRIVACY`) requires per-item filtering within the group. Removing the special case is safe because `filterByPermission` passes through items without `permission`/`anyPermissions` fields unchanged.

**Alternatives considered**:
- Keep special case and add Privacy-specific filter → more complex, introduces a second special case
- Add `permission` fields to all security items → scope creep, requires defining which permissions gate each security page (out of scope for this feature)

### 2. Privacy Visibility After Move

**Decision**: Privacy inherits the Security group's visibility requirement (`isSecurityAdmin`). Users who previously saw Privacy under People & Access but lack Security group access will lose sidebar visibility. They retain direct URL access via route-level `Permission.WORKBENCH_PRIVACY` guard.

**Rationale**: The spec explicitly accepts this narrowing. Privacy is semantically a security concern. The group-level gate ensures only security administrators see security-related tools.

**Alternatives considered**:
- Keep Privacy in People & Access and add a duplicate in Security → violates NavGroupConfig contract (no item in multiple groups)
- Create a hybrid visibility rule → overcomplicates sidebar rendering for a single item

### 3. Escalations Sidebar Removal Approach

**Decision**: Remove the Escalations `NavItemConfig` entry from the `reviews` group items array. Do not modify routes, components, or permission guards.

**Rationale**: The spec requires hiding from menu only. The simplest implementation is removing the config object from the array. The route in `WorkbenchShell.tsx` continues to work. In-flow links from review sessions are unaffected since they use `<Link to="/workbench/review/escalations">` or programmatic navigation, not sidebar config.

**Alternatives considered**:
- Add a `hidden: boolean` property to `NavItemConfig` → over-engineering for a single item; if more items need hiding in the future, this can be introduced then
- Comment out the config entry → leaves dead code; clean removal is better

### 4. AlertTriangle Icon Cleanup

**Decision**: Remove the `AlertTriangle` import from `WorkbenchLayout.tsx` if it is no longer referenced after removing the Escalations nav item.

**Rationale**: Unused imports trigger linter warnings. The Escalations component itself may still use `AlertTriangle`, but that's a separate file.

**Alternatives considered**:
- Leave the import → triggers ESLint `no-unused-imports` or `unused-vars` warning

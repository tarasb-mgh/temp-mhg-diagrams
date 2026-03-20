# Feature Specification: Dynamic Permissions Engine

**Feature Branch**: `035-dynamic-permissions-engine`
**Created**: 2026-03-20
**Status**: Draft
**Jira Epic**: MTB-825
**Input**: User description: "Replace hardcoded RBAC with database-driven hierarchical permission engine with Allow/Deny/Inherit model, principal groups, feature flag for backward compatibility, and Security Configuration UI."

## Summary

The MHG platform uses a hardcoded RBAC system: 7 static roles mapped to 58 permissions via a code constant. Changing who can do what requires a code change, package publish, and deployment across all repos. There is no way to grant permissions per-group, create custom roles, or adjust access without developer intervention.

This feature replaces the static role-permission mapping with a database-driven, hierarchical permission system. Administrators can create principal groups (custom roles), assign Allow or Deny permissions at platform or group scope, and manage it all through a dedicated Security Configuration section in the workbench. A feature flag ensures instant rollback to the existing static system, and pre-seeded system principal groups replicate current role behavior for full backward compatibility.

## User Scenarios & Testing

### User Story 1 — Feature Flag Toggle and Backward Compatibility (Priority: P1)

An Owner enables the dynamic permissions engine via the Security Configuration dashboard. All existing workbench functionality continues to work identically — the same users can access the same features as before. If anything breaks, the Owner flips the flag back off and the system instantly reverts to static permissions.

**Why this priority**: Without proven backward compatibility, the entire feature is unsafe to ship. This is the foundational trust layer.

**Independent Test**: Enable the feature flag. Log in as each role type (Owner, Moderator, Supervisor, Researcher, QA Specialist, Group Admin, regular User). Verify every workbench feature accessible before the flag was enabled remains accessible after. Disable the flag and verify reversion.

**Acceptance Scenarios**:

1. **Given** the feature flag is OFF, **When** any user performs any action in the system, **Then** behavior is identical to the pre-feature baseline with zero observable difference.
2. **Given** the feature flag is ON with only seed data (no custom assignments), **When** any user performs any action, **Then** behavior is identical to the pre-feature baseline.
3. **Given** the feature flag is ON, **When** the Owner toggles it back to OFF, **Then** all permissions instantly revert to the static role-based model with no data loss in the permission tables.

---

### User Story 2 — Principal Group Management (Priority: P1)

A Security Admin creates a new principal group called "Survey Managers," adds three users to it, and assigns them the survey management permissions at platform scope. Those users can now manage surveys across all groups without being assigned a hardcoded role that grants unrelated permissions.

**Why this priority**: Principal groups are the core building block for custom access control. Without them, the system is just a database copy of the static roles.

**Independent Test**: Create a principal group, add a user, assign an Allow permission. Log in as that user with the flag ON. Verify the permission is granted.

**Acceptance Scenarios**:

1. **Given** a Security Admin is logged into the Security Configuration section, **When** they create a new principal group with a name and description, **Then** the group appears in the list with zero members.
2. **Given** a principal group exists, **When** the Security Admin adds a user by email, **Then** the user appears as a member of the group.
3. **Given** a user is a member of a principal group with Allow for a permission, **When** the feature flag is ON and the user accesses the workbench, **Then** the user has the granted permission.
4. **Given** the Owners or Security Admins group, **When** a Security Admin attempts to delete it, **Then** the system rejects the action with an error message.
5. **Given** the Owners group has exactly one member, **When** a Security Admin attempts to remove that member, **Then** the system rejects the action to prevent lockout.
6. **Given** the Security Admins group has exactly one member, **When** an Owner attempts to remove that member, **Then** the system rejects the action to prevent lockout.
7. **Given** a Deny assignment was just created for a user, **When** a Security Admin triggers "force cache invalidation" from the Security Dashboard, **Then** the user's cached permissions are cleared immediately and the Deny takes effect on the next request (not waiting for TTL expiry).

---

### User Story 3 — Permission Assignments with Allow and Deny (Priority: P1)

A Security Admin assigns Deny for `REVIEW_DEANONYMIZE_APPROVE` to a specific user at platform scope, overriding the Allow inherited from their principal group. That user can no longer approve deanonymization requests anywhere in the system, even though their group still has the permission.

**Why this priority**: Allow/Deny is the core access control mechanism. Without Deny, administrators cannot restrict individuals without removing them from groups.

**Independent Test**: Assign Allow to a group, then Deny to an individual user in that group. Log in as the user. Verify the permission is denied.

**Acceptance Scenarios**:

1. **Given** a user belongs to a group with Allow for `REVIEW_SUBMIT`, **When** the Security Admin adds a Deny for `REVIEW_SUBMIT` directly to that user at the same scope, **Then** the user cannot submit reviews (Deny wins).
2. **Given** a user has Allow for `REVIEW_SUBMIT` at platform scope but Deny at a specific group scope, **When** the user accesses that group (flag ON), **Then** the permission is denied for that group but allowed for other groups.
3. **Given** a permission is platform-only (e.g., data export), **When** the Security Admin attempts to create a group-scoped assignment for it, **Then** the system rejects the assignment with a validation error.
4. **Given** a user has Deny for `REVIEW_SUBMIT` at platform scope, **When** a group-level Allow for `REVIEW_SUBMIT` exists for that user in Group A (flag ON), **Then** the permission is still denied in Group A (platform Deny wins over group Allow).
5. **Given** a user belongs to Group X (Allow for `REVIEW_SUBMIT`) and Group Y (Deny for `REVIEW_SUBMIT`) at the same scope, **When** the user attempts to submit a review (flag ON), **Then** the permission is denied (Deny from any group wins).

---

### User Story 4 — Group-Scoped Permissions (Priority: P2)

A Security Admin assigns `GROUP_VIEW_CHATS` to a principal group "Group A Reviewers" scoped to Group A only. Members of "Group A Reviewers" can view chat sessions in Group A but not in other groups, without needing a global role.

**Why this priority**: Group-scoped permissions are the primary reason for building a dynamic system — they enable per-group access control that was impossible with hardcoded roles.

**Independent Test**: Create a group-scoped assignment. Log in as the affected user. Verify permission is granted only in the specified group.

**Acceptance Scenarios**:

1. **Given** a user has `GROUP_VIEW_CHATS` assigned at Group A scope only, **When** they access Group A (flag ON), **Then** they can view chats.
2. **Given** the same user, **When** they access Group B, **Then** they cannot view chats (no assignment for Group B).
3. **Given** a user has `GROUP_VIEW_CHATS` at platform scope, **When** they access any group, **Then** they can view chats in all groups.

---

### User Story 5 — Security Configuration UI (Priority: P2)

An Owner navigates to the Security Configuration section in the workbench. They see a dashboard with the feature flag toggle, summary statistics, and links to manage principal groups, browse permissions, and manage assignments. They can select any user and see their effective resolved permissions with source attribution showing which group or direct assignment grants each permission.

**Why this priority**: The UI makes the permission system usable by non-developers. Without it, the database tables are only configurable via direct API calls.

**Independent Test**: Log in as Owner. Navigate to Security Configuration. Verify all sub-pages load and are functional.

**Acceptance Scenarios**:

1. **Given** a user with Owner role, **When** they navigate to the workbench, **Then** the Security Configuration section is visible in the sidebar.
2. **Given** a user who is NOT a member of the Owners or Security Admins principal group (regardless of feature flag state or other role assignments), **When** they navigate to the workbench, **Then** the Security Configuration section is NOT visible. This applies even if the user has other elevated roles.
3a. **Given** a QA Specialist who is added to the Security Admins principal group, **When** they navigate to the workbench (flag ON), **Then** the Security Configuration section IS visible (group membership determines access, not the legacy role field).
3. **Given** the Security Configuration dashboard, **When** the Owner views it, **Then** the feature flag toggle, summary cards, and navigation to sub-pages are displayed.
4. **Given** the effective permissions viewer, **When** the Security Admin selects a user, **Then** all resolved permissions are displayed with source attribution (which principal group or direct assignment grants each one).
5. **Given** the feature flag is OFF, **When** the Security Admin views the effective permissions viewer, **Then** a preview banner indicates "Preview mode — static permissions currently active" and the displayed permissions show what WOULD apply if the flag were on.

---

### User Story 6 — System Principal Groups and Migration (Priority: P1)

On first deployment, the system automatically creates principal groups for each existing role (QA Specialists, Researchers, Supervisors, Moderators, Group Admins) with permission assignments that exactly replicate the current static mappings. Existing Owner-role users are added to the immutable Owners group. The migration is idempotent — running it again produces no duplicates.

**Why this priority**: Without correct seed data, enabling the feature flag would break all existing users' access.

**Independent Test**: Run the seed migration. For each system principal group, resolve permissions and compare against the static `ROLE_PERMISSIONS` mapping. They must be identical.

**Acceptance Scenarios**:

1. **Given** a fresh deployment, **When** the seed migration runs, **Then** 7 principal groups are created (2 immutable + 5 system) with correct permission assignments.
2. **Given** the seed migration has already run, **When** it runs again, **Then** no duplicate records are created and no errors occur.
3. **Given** a user with role "researcher" in the database, **When** the feature flag is ON, **Then** their resolved permissions match the static `ROLE_PERMISSIONS` mapping for Researcher exactly.
4. **Given** a system principal group (e.g., "Supervisors"), **When** a Security Admin deletes it, **Then** the deletion succeeds (system groups are deletable; only immutable groups are protected).

---

### Edge Cases

- **User in zero principal groups with no direct assignments**: Access denied for all permissions. User can authenticate but cannot perform any permissioned action (system is closed by default).
- **Deny wins unconditionally across all scopes and sources**: If any assignment from any source (group or direct) says Deny for a permission at any scope, it is denied. This includes: platform Deny blocks group-level Allow; group A's Deny blocks group B's Allow at the same scope; direct user Deny blocks group Allow. There is no "more specific scope wins" — Deny always wins.
- **Scope mismatch validation**: Creating a group-scoped assignment for a platform-only permission is rejected by the system.
- **Last Owner protection**: The system prevents removing the last member from the Owners or Security Admins group.
- **Cache staleness window**: After a permission change, there is a maximum 60-second window where affected users may still operate under stale permissions. A manual "force cache invalidation" action is available for critical security changes.
- **Seed migration idempotency**: Running the migration multiple times produces no duplicates and no errors.
- **Startup validation**: On startup, the system validates that the permission registry in the database matches the known permission set. Mismatches are logged as warnings.
- **Feature flag rollback**: Toggling the flag from ON to OFF instantly reverts to static permissions with no data loss — all permission table data is preserved for when the flag is re-enabled.

## Requirements

### Functional Requirements

- **FR-001**: The system MUST support two securable scope levels: Platform (singleton) and Group (1..N). Permissions set at Platform scope MUST inherit to all Groups unless overridden.
- **FR-002**: The system MUST support two principal types: individual users and principal groups (named collections of users).
- **FR-003**: The system MUST provide three assignment effects: Allow (grants permission), Deny (blocks permission), and Inherit (default — no explicit assignment, resolved from parent scope).
- **FR-004**: Permission resolution MUST follow deny-wins logic: if any assignment from any source says Deny, the permission is denied regardless of Allow assignments from other sources.
- **FR-005**: The system MUST be closed by default: a user with no explicit Allow assignments has no permissions.
- **FR-006**: The system MUST include a `DYNAMIC_PERMISSIONS_ENABLED` feature flag. When OFF, all authorization MUST use the existing static role-permission mappings with zero behavioral change.
- **FR-007**: When the feature flag is ON, the system MUST resolve permissions from the database and produce results identical to the static mappings for all users assigned to system principal groups.
- **FR-008**: The system MUST provide two immutable principal groups: Owners (seeded with Allow for ALL permissions) and Security Admins (seeded with Allow for `WORKBENCH_ACCESS`, `SECURITY_VIEW`, `SECURITY_MANAGE`, `SECURITY_FEATURE_FLAG` only). These groups MUST NOT be deletable or renamable.
- **FR-009**: The system MUST enforce a minimum of 1 member in each immutable principal group to prevent administrative lockout.
- **FR-010**: The system MUST provide system principal groups (QA Specialists, Researchers, Supervisors, Moderators, Group Admins) pre-seeded with permission assignments replicating current role behavior. These groups MUST be deletable by administrators.
- **FR-011**: The system MUST maintain a permission registry with each permission's key, display name, category, and applicable scope types (platform-only, group-only, or both).
- **FR-012**: The system MUST reject permission assignments where the securable scope type does not match the permission's applicable scope types.
- **FR-013**: The system MUST add 8 new permissions with the following scope types: platform-only: `SECURITY_VIEW`, `SECURITY_MANAGE`, `SECURITY_FEATURE_FLAG`; group-only: `GROUP_ADMIT_USERS`, `GROUP_VIEW_SURVEYS`, `GROUP_VIEW_CHATS`, `GROUP_VIEW_MEMBERS`, `GROUP_MANAGE_CONFIG`.
- **FR-014**: The Security Configuration section in the workbench MUST be visible only to members of the Owners or Security Admins principal groups, regardless of feature flag state.
- **FR-015**: The Security Configuration section MUST include: a dashboard with feature flag toggle and summary statistics, principal group CRUD with member management, a permissions browser, permission assignment management, and an effective permissions viewer with source attribution.
- **FR-016**: The effective permissions viewer MUST show what permissions WOULD apply if the feature flag were on, with a preview banner when the flag is currently off.
- **FR-017**: The seed migration MUST be idempotent: running it multiple times produces no duplicates and no errors.
- **FR-018**: On startup, the system MUST validate that the permission registry matches the known permission set and log warnings for any mismatches.
- **FR-019**: Permission resolution MUST use a cache with a maximum staleness window of 60 seconds. A manual cache invalidation action MUST be available for critical security changes.
- **FR-020**: All permission CRUD operations MUST be logged through the existing audit logging mechanism with distinct action types for each operation.
- **FR-021**: All existing ~195 permission check call sites MUST continue to work unchanged through a compatibility layer that flattens resolved permissions into the existing format.

### Key Entities

- **Permission**: A registered capability with a key, display name, category, and applicable scope types. The system seeds 58 existing + 8 new permissions.
- **Principal Group**: A named collection of users. Can be immutable (Owners, Security Admins), system (pre-seeded, deletable), or custom (user-created).
- **Principal Group Member**: A link between a user and a principal group.
- **Permission Assignment**: An ACL entry linking a permission to a principal (user or group) at a securable scope (platform or specific group) with an effect (Allow or Deny).
- **Resolved Permissions**: The computed effective permissions for a user, combining all assignments from all their groups and direct assignments across all scopes.

## Success Criteria

### Measurable Outcomes

- **SC-001**: With feature flag OFF, 100% of existing functionality works identically — zero behavioral change across all user roles and all workbench features.
- **SC-002**: With feature flag ON (seed data only), 100% of existing functionality works identically — resolved permissions match static mappings for all 7 system roles.
- **SC-003**: Permission changes take effect for all affected users within 60 seconds of the change being saved, measured as wall-clock time from the save API response to the next authorization check reflecting the new permission state. Force cache invalidation reduces this to under 1 second.
- **SC-004**: Security Configuration section is accessible to 100% of Owners and Security Admins, and inaccessible to 100% of other users.
- **SC-005**: Toggling the feature flag from ON to OFF restores static behavior within 1 second with zero data loss.
- **SC-006**: Seed migration is idempotent — running it N times produces the same result as running it once, with zero duplicate records.
- **SC-007**: Effective permissions viewer correctly displays resolved permissions with source attribution for any selected user.
- **SC-008**: All existing permission check call sites compile and pass their unit tests without modification when the feature flag is both ON and OFF.

## Out of Scope

- Migrating the ~195 existing permission check call sites to use the new resolution model directly (the compatibility/flattening layer handles this)
- Removing the `users.role` column or `ROLE_PERMISSIONS` constant (cleanup after flag is permanently enabled)
- Dedicated audit logging UI for permission changes (uses existing `logAuditEvent` infrastructure)
- Multi-tenancy or organization-level permission scoping
- Permission versioning, history, or diff views
- Time-based or conditional permissions (e.g., "Allow only during business hours")
- Self-service permission request workflows
- API key or service account principals
- Mobile/responsive UI for the Security Configuration section
- Session-level securables (sessions inherit from their group)

## Assumptions

- The existing 58 permissions and their semantics are stable and will not change as part of this feature.
- The feature flag default is OFF — the dynamic engine is opt-in after deployment.
- The Security Configuration UI is English-only (internal tooling, consistent with delivery workbench precedent).
- The Security Configuration UI is desktop-only (workbench is not responsive).
- Principal groups are separate from spaces (groups/spaces remain organizational units for data scoping; principal groups are purely a security concept).
- The `users.role` column and `ROLE_PERMISSIONS` constant remain in the codebase for the lifetime of the feature flag. Cleanup is a follow-up task after the flag is permanently enabled.
- Audit logging for permission changes uses the existing `logAuditEvent()` infrastructure. A dedicated audit feature is a follow-up.

# Tasks: Dynamic Permissions Engine

**Input**: Design documents from `/specs/035-dynamic-permissions-engine/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/security-api.md, quickstart.md

**Tests**: Included for core resolution logic, admin service validation, and backward compatibility.

**Organization**: Tasks grouped by user story for independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to
- Include exact file paths in descriptions

## Path Conventions

- **chat-types**: `D:\src\MHG\chat-types\src\`
- **chat-backend**: `D:\src\MHG\chat-backend\src\`
- **chat-frontend-common**: `D:\src\MHG\chat-frontend-common\src\`
- **workbench-frontend**: `D:\src\MHG\workbench-frontend\src\`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create feature branches and publish shared types

- [x] T001 Create feature branch `035-dynamic-permissions-engine` from `main` in `chat-types` at `D:\src\MHG\chat-types`
- [x] T002 [P] Create feature branch `035-dynamic-permissions-engine` from `develop` in `chat-backend` at `D:\src\MHG\chat-backend`
- [x] T003 [P] Create feature branch `035-dynamic-permissions-engine` from `develop` in `chat-frontend-common` at `D:\src\MHG\chat-frontend-common`
- [x] T004 [P] Create feature branch `035-dynamic-permissions-engine` from `develop` in `workbench-frontend` at `D:\src\MHG\workbench-frontend`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Shared types and database schema that ALL user stories depend on

**CRITICAL**: No user story work can begin until this phase is complete

- [x] T005 Add 8 new `Permission` enum values to `D:\src\MHG\chat-types\src\rbac.ts`: platform-only `SECURITY_VIEW`, `SECURITY_MANAGE`, `SECURITY_FEATURE_FLAG`; group-only `GROUP_ADMIT_USERS`, `GROUP_VIEW_SURVEYS`, `GROUP_VIEW_CHATS`, `GROUP_VIEW_MEMBERS`, `GROUP_MANAGE_CONFIG`
- [x] T006 Create `D:\src\MHG\chat-types\src\security.ts` with types: `PrincipalGroup` (id, name, description, isSystem, isImmutable, memberCount, createdAt, updatedAt), `PrincipalGroupMember` (userId, email, displayName, createdAt), `PermissionRecord` (id, key, displayName, category, scopeTypes, isSystem), `PermissionAssignment` (id, permissionId, principalType, principalId, principalName, securableType, securableId, securableName, effect, createdBy, createdAt), `ResolvedPermissions` (platform: Map, groups: Map), `EffectivePermission` (permissionKey, effect, sources: array of attribution)
- [x] T007 Export all new types and permissions from `D:\src\MHG\chat-types\src\index.ts`
- [x] T008 Bump `chat-types` version in `D:\src\MHG\chat-types\package.json`, build, and publish to GitHub Packages
- [x] T009 Update `@mentalhelpglobal/chat-types` dependency in `D:\src\MHG\chat-backend\package.json` and run `npm install`
- [x] T010 Create database migration `D:\src\MHG\chat-backend\src\db\migrations\0XX_dynamic_permissions.sql` with: `permissions` table (id, key, display_name, category, scope_types, is_system, timestamps), `principal_groups` table (id, name, description, is_system, is_immutable, timestamps), `principal_group_members` table (principal_group_id, user_id, created_at, PK composite), `permission_assignments` table (id, permission_id, principal_type, principal_id, securable_type, securable_id, effect, created_by, created_at, UNIQUE constraint), `ALTER TABLE settings ADD COLUMN IF NOT EXISTS dynamic_permissions_enabled BOOLEAN NOT NULL DEFAULT false`. All with indexes per data-model.md. Use `IF NOT EXISTS` and `ON CONFLICT DO NOTHING` throughout.
- [x] T011 Add seed data to the migration: INSERT all 66 permissions (58 existing + 8 new) with correct categories and scope_types. INSERT 7 principal groups (Owners + Security Admins as immutable, 5 system groups). INSERT permission_assignments replicating ROLE_PERMISSIONS for each system group. INSERT Owners group with Allow for ALL 66 permissions. INSERT Security Admins group with Allow for WORKBENCH_ACCESS, SECURITY_VIEW, SECURITY_MANAGE, SECURITY_FEATURE_FLAG only.
- [x] T012 Create seed logic in `D:\src\MHG\chat-backend\src\db\migrations\0XX_dynamic_permissions_seed.ts` to add existing users to principal groups based on their `users.role` value (owners → Owners group, researchers → Researchers group, etc.)
- [x] T013 Implement startup validation in `D:\src\MHG\chat-backend\src\services\permissionValidation.service.ts`: compare Permission enum values from chat-types against `permissions` table rows; log warnings for mismatches

**Checkpoint**: Database schema ready, seed data populated, types published

---

## Phase 3: User Story 6 — System Principal Groups and Migration (Priority: P1) MVP

**Goal**: Seed migration produces principal groups that exactly replicate current role-permission mappings

**Independent Test**: Run migration. For each system group, resolve permissions and compare against ROLE_PERMISSIONS.

### Implementation for User Story 6

- [x] T014 [US6] Write unit test in `D:\src\MHG\chat-backend\tests\unit\permissionResolution.test.ts` that verifies: for each of the 7 system principal groups, the resolved permission set matches the corresponding `ROLE_PERMISSIONS[role]` array exactly
- [x] T015 [US6] Write unit test verifying seed migration idempotency: running seed twice produces no duplicates (mock DB with ON CONFLICT assertions)
- [x] T016 [US6] Write unit test verifying system groups are deletable but immutable groups are not

**Checkpoint**: Migration correctness proven by tests

---

## Phase 4: User Story 1 — Feature Flag Toggle and Backward Compatibility (Priority: P1)

**Goal**: Feature flag controls whether permissions come from static constant or database. Flag OFF = zero change. Flag ON with seed data = identical behavior.

**Independent Test**: Toggle flag, verify identical behavior for all role types.

### Implementation for User Story 1

- [x] T017 [US1] Add `dynamicPermissionsEnabled` to `AppSettings` type in `D:\src\MHG\chat-backend\src\services\settings.service.ts` and expose via `getSettings()`
- [x] T018 [US1] Create `D:\src\MHG\chat-backend\src\services\permissionResolution.service.ts` with `resolvePermissions(userId): Promise<ResolvedPermissions>` — queries principal_group_members + permission_assignments, applies deny-wins logic per data-model.md resolution algorithm
- [x] T019 [US1] Implement in-memory cache in `permissionResolution.service.ts`: Map keyed by userId, 60s TTL, `invalidateUserCache(userId)` and `invalidateAllCaches()` functions
- [x] T020 [US1] Create `flattenToPermissionArray(resolved: ResolvedPermissions, activeGroupId: string | null): Permission[]` in `permissionResolution.service.ts` — merges platform-level Allow permissions + active-group-level Allow permissions into a single array, excluding any Deny'd permissions
- [x] T021 [US1] Modify `authenticate()` in `D:\src\MHG\chat-backend\src\middleware\auth.ts`: after existing `ROLE_PERMISSIONS[payload.role]` lookup, check `getSettings().dynamicPermissionsEnabled`; if true, call `resolvePermissions(userId)` then `flattenToPermissionArray()` and set `req.user.permissions` to the result; if false, keep existing behavior unchanged
- [x] T022 [US1] Write unit tests in `D:\src\MHG\chat-backend\tests\unit\permissionResolution.test.ts`: flag OFF returns static permissions; flag ON with seed data returns identical permissions for each role; cache TTL works; cache invalidation works
- [x] T023 [US1] Write unit test: flag toggle from ON to OFF immediately reverts to static permissions (no stale cache)

**Checkpoint**: Dual-mode auth middleware working. All existing tests pass with flag both ON and OFF.

---

## Phase 5: User Story 3 — Permission Assignments with Allow and Deny (Priority: P1)

**Goal**: Allow and Deny assignments work correctly with deny-wins resolution

**Independent Test**: Assign Allow to group, Deny to individual. Verify Deny wins.

### Implementation for User Story 3

- [x] T024 [US3] Create `D:\src\MHG\chat-backend\src\services\securityAdmin.service.ts` with `createAssignment(permissionId, principalType, principalId, securableType, securableId, effect, createdBy)` — validates scope_types match per FR-012, prevents duplicates, invalidates affected user caches
- [x] T025 [US3] Implement `deleteAssignment(assignmentId)` and `listAssignments(securableType, securableId?)` in `securityAdmin.service.ts`
- [x] T026 [US3] Write unit tests in `D:\src\MHG\chat-backend\tests\unit\permissionResolution.test.ts`: deny-wins over allow at same scope; platform deny blocks group allow; multi-group conflict (Group X allow + Group Y deny = denied); user in zero groups = no permissions
- [x] T027 [US3] Write unit test: scope mismatch rejected (group-scoped assignment for platform-only permission returns validation error)

**Checkpoint**: Allow/Deny resolution proven correct across all edge cases

---

## Phase 6: User Story 2 — Principal Group Management (Priority: P1)

**Goal**: CRUD for principal groups with immutability and last-member protection

**Independent Test**: Create group, add user, assign permission. Verify permission granted with flag ON.

### Implementation for User Story 2

- [x] T028 [US2] Implement principal group CRUD in `securityAdmin.service.ts`: `createGroup(name, description)`, `updateGroup(id, name?, description?)`, `deleteGroup(id)` — reject delete on immutable groups, cascade-delete assignments on group delete
- [x] T029 [US2] Implement member management in `securityAdmin.service.ts`: `addMember(groupId, email)` (lookup user by email, reject if not found or already member), `removeMember(groupId, userId)` (reject if last member of immutable group), `listMembers(groupId)`, invalidate user cache on membership changes
- [x] T030 [US2] Implement feature flag toggle in `securityAdmin.service.ts`: `toggleFeatureFlag(enabled, actorId)` — updates settings, logs audit event `security.flag_toggle`, clears all permission caches
- [x] T031 [US2] Implement force cache invalidation: `invalidateAllCaches(actorId)` — clears all permission caches, logs audit event `security.cache_invalidate`
- [x] T032 [US2] Write unit tests in `D:\src\MHG\chat-backend\tests\unit\securityAdmin.test.ts`: create/update/delete groups, immutability guard, last-member guard for both Owners and Security Admins, member add/remove, scope validation

**Checkpoint**: Principal group management fully functional with all guards

---

## Phase 7: User Story 2+3 — Security API Routes (Priority: P1)

**Goal**: Expose all security admin operations via REST API

### Implementation

- [x] T033 Create `D:\src\MHG\chat-backend\src\middleware\securityGuard.ts`: middleware that checks if `req.user` is a member of Owners or Security Admins principal groups (queries `principal_group_members` for immutable group IDs); returns 403 if not
- [x] T034 Create `D:\src\MHG\chat-backend\src\routes\security.ts` with all 16 endpoints per `contracts/security-api.md`: principal groups CRUD (7), permissions browser (2), assignments CRUD (3), effective permissions (1), settings (2), cache invalidation (1). Wire `securityGuard` middleware, `authenticate`, `requireActiveAccount`
- [x] T035 Implement effective permissions resolver with source attribution in `securityAdmin.service.ts`: `getEffectivePermissions(userId)` returns resolved permissions with which group/assignment grants each permission
- [x] T036 Wire audit logging for all CRUD operations in `security.ts` routes: use `logAuditEvent()` with action types from data-model.md audit event types table
- [x] T037 Run full backend test suite (`npx vitest run`) and verify 0 failures

**Checkpoint**: Complete backend API ready for frontend consumption

---

## Phase 8: User Story 4 — Group-Scoped Permissions (Priority: P2)

**Goal**: Permissions can be assigned at group scope, granting access to specific groups only

**Independent Test**: Assign GROUP_VIEW_CHATS at Group A scope. Verify access in Group A, denied in Group B.

### Implementation for User Story 4

- [x] T038 [US4] Create `hasPermissionInGroup(resolved: ResolvedPermissions, permissionKey: string, groupId: string): boolean` helper in `permissionResolution.service.ts` — checks group-level assignments, falls back to platform level, respects deny-wins
- [x] T039 [US4] Write unit tests: group-scoped allow grants access only in target group; platform allow grants access in all groups; group deny overrides platform allow in that group; no assignment = denied

**Checkpoint**: Group-scoped permissions working end-to-end

---

## Phase 9: User Story 5 — Security Configuration UI (Priority: P2)

**Goal**: Full Security Configuration section in the workbench

**Independent Test**: Log in as Owner. Navigate to Security Configuration. Verify all pages functional.

### Implementation for User Story 5

- [x] T040 [US5] Modify `GET /api/auth/me` in `D:\src\MHG\chat-backend\src\routes\auth.ts` to include `principalGroupIds: string[]` in the response when the user has principal group memberships (required BEFORE frontend work — T041 depends on this)
- [x] T041 [US5] Update `@mentalhelpglobal/chat-types` dependency in `D:\src\MHG\chat-frontend-common\package.json` and `D:\src\MHG\workbench-frontend\package.json`
- [x] T042 [US5] Extend auth store in `D:\src\MHG\chat-frontend-common\src\stores\authStore.ts`: add `principalGroupIds: string[]` from auth response; add `isSecurityAdmin(): boolean` helper checking membership in Owners or Security Admins groups
- [x] T043 [US5] Create `D:\src\MHG\workbench-frontend\src\services\securityApi.ts` with all 16 API endpoints matching contracts/security-api.md
- [x] T044 [US5] Create `D:\src\MHG\workbench-frontend\src\stores\securityStore.ts` Zustand store for security state (groups, permissions, assignments, loading states)
- [x] T045 [US5] Build `D:\src\MHG\workbench-frontend\src\features\security\SecurityDashboard.tsx`: feature flag toggle with confirmation dialog, summary cards (total groups, total assignments, total permissions), preview mode banner when flag is off
- [x] T046 [P] [US5] Build `D:\src\MHG\workbench-frontend\src\features\security\PrincipalGroupsPage.tsx`: list view with member count, system/immutable badges, create/delete buttons (respecting immutability)
- [x] T047 [P] [US5] Build `D:\src\MHG\workbench-frontend\src\features\security\PrincipalGroupDetailPage.tsx`: member list table, add member by email search, remove member button (with last-member guard feedback)
- [x] T048 [P] [US5] Build `D:\src\MHG\workbench-frontend\src\features\security\PermissionsBrowserPage.tsx`: grouped by category, searchable, click-through to assignments for each permission
- [x] T049 [US5] Build `D:\src\MHG\workbench-frontend\src\features\security\AssignmentsPage.tsx`: scope selector (Platform / specific Group), assignment table, add assignment form (permission picker + principal picker + effect toggle + scope), remove assignment
- [x] T050 [US5] Build `D:\src\MHG\workbench-frontend\src\features\security\EffectivePermissionsPage.tsx`: user search/selector, resolved permissions table with source attribution columns, preview banner when flag is off
- [x] T051 [US5] Add Security nav group to `D:\src\MHG\workbench-frontend\src\features\workbench\WorkbenchLayout.tsx` sidebar: visible only when `isSecurityAdmin()` returns true; links to all 5 security pages; verify QA Specialist added to Security Admins group gains access (US5-AS3a)
- [x] T052 [US5] Add routes for `/workbench/security/*` in workbench-frontend router (WorkbenchShell or App.tsx)

**Checkpoint**: Security Configuration UI fully functional

---

## Phase 10: Polish & Cross-Cutting Concerns

**Purpose**: Final verification, integration, and cleanup

- [x] T053 Run all Vitest tests in `D:\src\MHG\chat-backend` and verify 0 failures
- [x] T054 Run TypeScript typecheck in `D:\src\MHG\workbench-frontend` and verify 0 errors
- [ ] T055 Manual verification on dev: backward compatibility test — flag OFF, verify all roles work; flag ON with seed data, verify identical behavior
- [ ] T056 Manual verification on dev: create principal group, add user, assign permission, toggle flag ON, verify permission granted
- [ ] T057 Manual verification on dev: deny-wins test — assign Allow to group, Deny to user, verify denied
- [ ] T058 Manual verification on dev: Security Configuration UI — all 5 pages load and are functional for Owner; not visible for non-admin users
- [ ] T059 Update `specs/035-dynamic-permissions-engine/tasks.md` — mark all tasks complete

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Setup — BLOCKS all user stories
- **US6 Migration (Phase 3)**: Depends on Foundational — tests seed correctness
- **US1 Feature Flag (Phase 4)**: Depends on Foundational — builds resolution service
- **US3 Allow/Deny (Phase 5)**: Depends on Phase 4 (resolution service exists)
- **US2 Groups CRUD (Phase 6)**: Depends on Foundational — parallel with US1/US3
- **API Routes (Phase 7)**: Depends on Phases 4-6 (services ready)
- **US4 Group Scope (Phase 8)**: Depends on Phase 5 (assignments work)
- **US5 UI (Phase 9)**: Depends on Phase 7 (API ready) + Phase 6 frontend-common
- **Polish (Phase 10)**: Depends on all previous phases

### User Story Dependencies

- **US6 (Migration)**: Can start after Foundational — no other story dependencies
- **US1 (Feature Flag)**: Can start after Foundational — core resolution service
- **US3 (Allow/Deny)**: Depends on US1 (resolution service must exist)
- **US2 (Groups CRUD)**: Can start after Foundational — parallel with US1
- **US4 (Group Scope)**: Depends on US3 (assignment resolution must work)
- **US5 (UI)**: Depends on API Routes (Phase 7) being complete

### Parallel Opportunities

- T001-T004 can run in parallel (branch creation)
- T005-T006 can run in parallel (different files in chat-types)
- US6 (Phase 3) and US2 (Phase 6) can run in parallel after Foundational
- T045, T046, T047 can run in parallel (independent UI pages)
- Phase 9 frontend work can start once API routes are ready

---

## Implementation Strategy

### MVP First (US1 + US6)

1. Complete Phase 1: Setup (branches)
2. Complete Phase 2: Foundational (types + DB + migration)
3. Complete Phase 3: US6 — prove migration correctness
4. Complete Phase 4: US1 — prove backward compatibility
5. **STOP and VALIDATE**: Flag ON matches flag OFF for all roles

### Incremental Delivery

1. Setup + Foundational → types and schema ready
2. US6 (migration) → seed data correct
3. US1 (feature flag) → dual-mode auth working (MVP!)
4. US3 (allow/deny) → core resolution logic
5. US2 (groups CRUD) → admin management
6. API Routes → backend complete
7. US4 (group scope) → fine-grained permissions
8. US5 (UI) → self-service administration
9. Polish → final verification

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story
- The `flattenToPermissionArray()` function (T020) is the key backward compatibility shim
- All 195 existing permission check call sites work unchanged
- Feature flag default is OFF — zero risk on deployment
- Migration is idempotent — safe to re-run

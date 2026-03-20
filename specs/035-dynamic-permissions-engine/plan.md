# Implementation Plan: Dynamic Permissions Engine

**Branch**: `035-dynamic-permissions-engine` | **Date**: 2026-03-20 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/035-dynamic-permissions-engine/spec.md`

## Summary

Replace the hardcoded `ROLE_PERMISSIONS` constant with a database-driven hierarchical permission engine. Key components: 4 new database tables, a permission resolution service with caching, dual-mode auth middleware controlled by a feature flag, CRUD API for security configuration, and a 5-page Security Configuration UI in the workbench. Full backward compatibility via system principal groups and a feature flag with instant rollback.

## Technical Context

**Language/Version**: TypeScript 5.x (Node.js 20+)
**Primary Dependencies**: Express.js (backend), React 18 (frontend), Zustand (state), `@mentalhelpglobal/chat-types` (shared types)
**Storage**: PostgreSQL — 4 new tables (`permissions`, `principal_groups`, `principal_group_members`, `permission_assignments`) + 1 column on `settings`
**Testing**: Vitest (backend unit tests), React Testing Library (frontend)
**Target Platform**: Web application (workbench SPA + Express API)
**Project Type**: Web service (multi-repo)
**Performance Goals**: Permission resolution < 50ms p95 warm cache, < 200ms cold cache
**Constraints**: Zero behavioral change with flag OFF; all ~195 existing permission check call sites unchanged
**Scale/Scope**: ~40 files across 4 repositories

## Constitution Check

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Spec-First | PASS | spec.md complete, 0 markers |
| II. Multi-Repo Orchestration | PASS | chat-types → chat-backend → chat-frontend-common → workbench-frontend |
| III. Test-Aligned | PASS | Vitest backend, RTL frontend |
| IV. Branch Discipline | PASS | Same branch name across all repos |
| V. Privacy & Security | PASS | Core authorization feature; audit logging included |
| VI. Accessibility & i18n | PASS | English-only internal tooling (constitution exemption for workbench) |
| VII. Split-Repo First | PASS | All work in split repos |
| VIII. GCP CLI Infra | N/A | No infrastructure changes |
| IX. Responsive UX / PWA | N/A | Desktop-only workbench |
| X. Jira Traceability | PASS | Epic MTB-825 created |
| XI. Documentation Standards | PASS | Will update documentation after implementation |
| XII. Release Engineering | PASS | Standard feature release |

## Project Structure

### Documentation (this feature)

```text
specs/035-dynamic-permissions-engine/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── security-api.md
└── tasks.md
```

### Source Code (affected repositories)

```text
chat-types/src/
├── rbac.ts                                    # Add 8 new Permission enum values
└── security.ts                                # NEW: types for principal groups, assignments, resolution

chat-backend/src/
├── db/migrations/
│   └── 0XX_dynamic_permissions.sql            # NEW: 4 tables + seed data
├── services/
│   ├── permissionResolution.service.ts        # NEW: resolution engine + cache
│   ├── securityAdmin.service.ts               # NEW: CRUD for groups/assignments
│   └── settings.service.ts                    # Modified: add dynamic_permissions_enabled
├── routes/
│   └── security.ts                            # NEW: Security Configuration API (16 endpoints)
├── middleware/
│   ├── auth.ts                                # Modified: dual-mode permission resolution
│   └── securityGuard.ts                       # NEW: check Owners/SecurityAdmins membership
└── tests/unit/
    ├── permissionResolution.test.ts           # NEW: resolution logic tests
    └── securityAdmin.test.ts                  # NEW: CRUD + validation tests

chat-frontend-common/src/
└── stores/authStore.ts                        # Modified: carry principal group memberships

workbench-frontend/src/
├── features/security/
│   ├── SecurityDashboard.tsx                  # NEW: feature flag toggle, summary cards
│   ├── PrincipalGroupsPage.tsx                # NEW: group CRUD + member management
│   ├── PrincipalGroupDetailPage.tsx           # NEW: members list, add/remove
│   ├── PermissionsBrowserPage.tsx             # NEW: registry browser
│   ├── AssignmentsPage.tsx                    # NEW: scoped assignment management
│   └── EffectivePermissionsPage.tsx           # NEW: resolved permissions viewer
├── features/workbench/WorkbenchLayout.tsx      # Modified: add Security nav group
├── services/securityApi.ts                    # NEW: API service
└── stores/securityStore.ts                    # NEW: Zustand store
```

**Structure Decision**: Security UI as a new feature module `features/security/`. Backend API in single route file with service layer split into resolution and admin.

## Implementation Order

### Phase 0: Types (chat-types)
1. Add 8 new `Permission` enum values to `rbac.ts`
2. Create `security.ts` with types: `PrincipalGroup`, `PrincipalGroupMember`, `PermissionAssignment`, `PermissionRecord`, `ResolvedPermissions`, `EffectivePermission`
3. Export from `index.ts`, bump version, publish

### Phase 1: Database + Migration (chat-backend)
**Depends on**: Phase 0

4. Create migration `0XX_dynamic_permissions.sql`: 4 new tables + settings column + seed data (66 permissions, 7 principal groups, permission assignments replicating ROLE_PERMISSIONS)
5. Implement seed logic for mapping existing users to principal groups based on `users.role`
6. Implement startup validation (Permission enum vs permissions table)

### Phase 2: Permission Resolution Service (chat-backend)
**Depends on**: Phase 1

7. Create `permissionResolution.service.ts`: `resolvePermissions(userId)` with deny-wins logic
8. Implement in-memory cache with 60s TTL and invalidation API
9. Create `flattenToPermissionArray(resolved, activeGroupId)` compatibility function
10. Modify `authenticate()` in `auth.ts`: check feature flag → if ON, resolve from DB; if OFF, use static

### Phase 3: Security Admin Service (chat-backend)
**Depends on**: Phase 1

11. Create `securityAdmin.service.ts`: CRUD for principal groups (with immutability/last-member guards)
12. Implement principal group member management (add/remove with validation)
13. Implement permission assignment CRUD (with scope-type validation per FR-012)
14. Implement effective permissions resolver with source attribution
15. Implement feature flag toggle + force cache invalidation

### Phase 4: Security API Routes (chat-backend)
**Depends on**: Phases 2-3

16. Create `securityGuard.ts` middleware: check membership in Owners or Security Admins groups
17. Create `security.ts` route file with 16 endpoints per contracts/security-api.md
18. Wire audit logging for all CRUD operations

### Phase 5: Backend Tests (chat-backend)
**Depends on**: Phases 2-4

19. Write resolution tests: allow, deny, deny-wins, multi-group, platform vs group scope, empty groups
20. Write admin tests: CRUD, immutability guards, last-member protection, scope validation
21. Write middleware tests: dual-mode (flag ON/OFF), backward compatibility verification
22. Run full test suite to verify zero regressions

### Phase 6: Frontend Common (chat-frontend-common)
**Depends on**: Phase 0

23. Extend auth store to carry `principalGroupIds: string[]` from auth response
24. Add `isSecurityAdmin(): boolean` helper checking group membership

### Phase 7: Security Configuration UI (workbench-frontend)
**Depends on**: Phases 4, 6

25. Create `securityApi.ts` service for all security endpoints
26. Create `securityStore.ts` Zustand store
27. Build SecurityDashboard page (feature flag toggle, summary cards, preview banner)
28. Build PrincipalGroupsPage (list view, create/delete, system/immutable badges)
29. Build PrincipalGroupDetailPage (member list, add/remove by email)
30. Build PermissionsBrowserPage (registry grouped by category, assignment drill-down)
31. Build AssignmentsPage (scoped view, add/remove assignments)
32. Build EffectivePermissionsPage (user selector, resolved permissions with source attribution)
33. Add Security nav group to WorkbenchLayout sidebar (with Owners/SecurityAdmins membership check)

### Phase 8: Integration + Polish
**Depends on**: All previous phases

34. Update `@mentalhelpglobal/chat-types` dependency in all consuming repos
35. Run full test suites across all repos
36. Manual verification: backward compatibility test flow
37. Manual verification: principal group + assignment test flow
38. Manual verification: deny-wins test flow

## Cross-Repository Dependencies

| Order | Repository | Dependency |
|-------|-----------|------------|
| 1st | chat-types | None — publishes first |
| 2nd | chat-backend | Depends on chat-types@latest |
| 3rd | chat-frontend-common | Depends on chat-types@latest |
| 4th | workbench-frontend | Depends on chat-types, chat-frontend-common, and backend API |

## Modified Endpoint Behaviors

### authenticate() middleware
**Current**: `req.user.permissions = ROLE_PERMISSIONS[user.role]`
**Changed**: When flag ON: `req.user.permissions = flattenToPermissionArray(resolvePermissions(userId), activeGroupId)`. When flag OFF: unchanged.

### GET /api/auth/me
**Current**: Returns user with role and permissions
**Changed**: Additionally returns `principalGroupIds: string[]` for frontend sidebar visibility checks

### GET /api/admin/settings
**Changed**: Response includes `dynamicPermissionsEnabled: boolean`

### New endpoints: /api/security/*
14 new endpoints as defined in contracts/security-api.md. All require Owners/SecurityAdmins membership.

## Complexity Tracking

No constitution violations. No complexity justifications needed.

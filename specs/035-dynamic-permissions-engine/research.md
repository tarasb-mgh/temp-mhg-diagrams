# Research: Dynamic Permissions Engine

**Feature Branch**: `035-dynamic-permissions-engine`
**Date**: 2026-03-20

## Decision 1: Permission Resolution Storage and Caching

**Decision**: In-memory cache per Node.js process with 60-second TTL, keyed by userId. Cache stores the fully resolved `ResolvedPermissions` object. Invalidation on write path (assignment/group membership changes) clears affected user entries. A "force invalidate all" endpoint clears the entire cache.

**Rationale**: The existing settings service uses the same pattern (30s TTL in-memory cache). Redis-based caching was considered but rejected — the permission data is user-specific and the in-memory approach avoids an extra network hop on every authenticated request. With Cloud Run's single-instance-per-request model, the cache is per-revision, which is acceptable given the short TTL.

**Alternatives considered**:
- Redis cache: rejected — adds latency and a failure dependency for the most critical path (auth)
- No cache (query every request): rejected — joins across 4 tables on every request is too expensive
- Longer TTL (5 min): rejected — too long for security-critical changes to propagate

## Decision 2: Feature Flag Implementation

**Decision**: Add `dynamic_permissions_enabled BOOLEAN DEFAULT false` to the existing `settings` table (single-row singleton). Read via the existing `getSettings()` cached function. Toggled via a new API endpoint restricted to Owner/Security Admin.

**Rationale**: Reuses the proven settings infrastructure. No new table, no new caching layer. The settings cache (30s TTL) means the flag change propagates within 30 seconds, which is acceptable since enabling/disabling the engine is a rare, deliberate action.

**Alternatives considered**:
- Environment variable: rejected — requires redeployment to toggle
- Separate feature flag table: rejected — over-engineering for a single boolean
- Database column on a config table: this is effectively what we chose via the settings table

## Decision 3: Auth Middleware Integration Point

**Decision**: Modify the `authenticate()` middleware in `auth.ts` (line 46-58). After the current `ROLE_PERMISSIONS[payload.role]` lookup, check the feature flag. If ON, call `resolvePermissions(userId)` and flatten the result into the same `Permission[]` format. The `req.user.permissions` array remains the single source of truth for all downstream checks.

**Rationale**: This is the narrowest possible integration point. All ~195 call sites read from `req.user.permissions` — by changing how that array is populated, we get full coverage without touching any call site. The flatten function merges platform permissions + active group permissions into a single array.

**Alternatives considered**:
- New middleware: rejected — would require inserting it after authenticate() in every route stack
- Decorator/wrapper around permission checks: rejected — would require touching all 195 call sites
- req.user.resolvedPermissions alongside req.user.permissions: considered for Phase 2 (per-group checks), but the flattening approach handles the current active-group model

## Decision 4: Seed Migration Strategy

**Decision**: A single SQL migration file that creates all 4 new tables, seeds the permissions registry, creates principal groups, and creates permission assignments. Uses `INSERT ... ON CONFLICT DO NOTHING` throughout for idempotency. A companion TypeScript migration step adds existing Owner-role users to the Owners principal group.

**Rationale**: SQL migration follows the existing pattern in `src/db/migrations/`. The TypeScript step is needed because we need to query the `users` table dynamically (we can't hardcode user IDs in SQL). The migration runner already supports both SQL and TS migrations.

**Alternatives considered**:
- Pure SQL with subqueries: possible but fragile — relies on specific data state
- Application-level seed on first startup: rejected — migrations are the established pattern and run exactly once

## Decision 5: Security Configuration UI Architecture

**Decision**: New top-level section in the workbench with its own route group `/workbench/security/*`. Five sub-pages: dashboard, principal-groups, permissions, assignments, effective-viewer. Follows the existing WorkbenchLayout NavGroupConfig pattern for sidebar integration.

**Rationale**: The existing sidebar uses a `navGroups` array with permission-based filtering. Adding a new group with a permission check (membership in Owners/Security Admins groups) follows the established pattern. The check is special — it's not a standard `Permission` enum value but a principal group membership check. This requires a small extension to the sidebar filtering logic.

**Alternatives considered**:
- Sub-page under Settings: rejected — Security Configuration is a major feature with 5 sub-pages, not a settings subsection
- Separate app (like delivery workbench): rejected — it's workbench functionality for workbench users, not a separate tool

## Decision 6: Affected Repositories

**Decision**: Changes span four repositories: `chat-types`, `chat-backend`, `workbench-frontend`, `chat-frontend-common`.

- `chat-types`: New permission enum values, new types for principal groups/assignments/resolved permissions
- `chat-backend`: New tables, migration, resolution service, API endpoints, auth middleware changes, settings extension
- `workbench-frontend`: Security Configuration UI (5 pages), sidebar extension
- `chat-frontend-common`: Extended auth store to carry principal group memberships for sidebar visibility check

No changes to `chat-frontend` (chat app), `chat-ui`, or `chat-infra`.

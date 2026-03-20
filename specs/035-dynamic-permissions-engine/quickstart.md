# Quickstart: Dynamic Permissions Engine

**Feature Branch**: `035-dynamic-permissions-engine`
**Date**: 2026-03-20

## Prerequisites

- Node.js 20+
- Access to `chat-types`, `chat-backend`, `workbench-frontend`, `chat-frontend-common`
- PostgreSQL with existing MHG schema
- At least one user with Owner role

## Development Setup

### 1. Create feature branches

```bash
cd D:\src\MHG\chat-types && git checkout develop 2>/dev/null || git checkout main && git pull && git checkout -b 035-dynamic-permissions-engine
cd D:\src\MHG\chat-backend && git checkout develop && git pull && git checkout -b 035-dynamic-permissions-engine
cd D:\src\MHG\chat-frontend-common && git checkout develop && git pull && git checkout -b 035-dynamic-permissions-engine
cd D:\src\MHG\workbench-frontend && git checkout develop && git pull && git checkout -b 035-dynamic-permissions-engine
```

### 2. Types first (chat-types)

Add new permissions to `Permission` enum, add types for principal groups/assignments/resolution, bump version, publish.

### 3. Backend (chat-backend)

1. Run migration to create new tables and seed data
2. Create permission resolution service
3. Modify auth middleware for dual-mode
4. Create Security API routes
5. Run tests: `npm test`

### 4. Frontend common (chat-frontend-common)

Extend auth store to carry principal group memberships.

### 5. Frontend (workbench-frontend)

Build Security Configuration UI: dashboard, principal groups, permissions browser, assignments, effective viewer.

## Verification

### Backward Compatibility Test

1. Deploy with feature flag OFF (default)
2. Log in as each role type — verify all features work identically to pre-deployment
3. Enable feature flag via Security Configuration dashboard
4. Repeat step 2 — verify all features still work identically
5. Disable feature flag — verify instant reversion

### Principal Group Test

1. Log in as Owner, navigate to Security Configuration
2. Create a new principal group "Test Group"
3. Add a user to it
4. Assign Allow for `SURVEY_SCHEMA_MANAGE` at platform scope
5. Enable feature flag
6. Log in as that user — verify survey schema management is accessible
7. Remove the assignment — verify access revoked within 60 seconds

### Deny Test

1. Assign Allow for `REVIEW_SUBMIT` to a group
2. Add Deny for `REVIEW_SUBMIT` directly to one user in that group
3. Log in as that user — verify review submit is blocked

## Key Files

| Repository | File | Change |
|------------|------|--------|
| chat-types | `src/rbac.ts` | New permission enum values, new types |
| chat-types | `src/security.ts` | New file: principal group/assignment types |
| chat-backend | `src/db/migrations/0XX_dynamic_permissions.sql` | New tables + seed data |
| chat-backend | `src/services/permissionResolution.service.ts` | New: resolution engine + cache |
| chat-backend | `src/services/securityAdmin.service.ts` | New: CRUD for groups/assignments |
| chat-backend | `src/routes/security.ts` | New: Security Configuration API |
| chat-backend | `src/middleware/auth.ts` | Modified: dual-mode permission resolution |
| chat-backend | `src/services/settings.service.ts` | Modified: add feature flag |
| chat-frontend-common | `src/stores/authStore.ts` | Modified: carry principal group memberships |
| workbench-frontend | `src/features/security/*` | New: 5 Security Configuration pages |
| workbench-frontend | `src/features/workbench/WorkbenchLayout.tsx` | Modified: add Security nav group |
| workbench-frontend | `src/services/securityApi.ts` | New: Security API service |

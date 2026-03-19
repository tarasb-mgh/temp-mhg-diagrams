# Quickstart: Global Role Group Access

**Feature Branch**: `034-global-role-group-access`
**Date**: 2026-03-19

## Prerequisites

- Node.js 20+
- Access to `chat-types`, `chat-backend`, and `workbench-frontend` repositories
- PostgreSQL with existing MHG schema (no new migrations needed)
- At least one test user with Researcher, Supervisor, Moderator, or Owner role
- At least two groups in the system

## Development Setup

### 1. Create feature branches

```bash
# In each affected repo, create feature branch from develop
cd D:\src\MHG\chat-types && git checkout develop && git pull && git checkout -b 034-global-role-group-access
cd D:\src\MHG\chat-backend && git checkout develop && git pull && git checkout -b 034-global-role-group-access
cd D:\src\MHG\workbench-frontend && git checkout develop && git pull && git checkout -b 034-global-role-group-access
```

### 2. Types first (chat-types)

```bash
cd D:\src\MHG\chat-types
# Add GLOBAL_GROUP_ACCESS_ROLES constant to src/rbac.ts
# Bump version in package.json
npm run build
npm publish
```

### 3. Backend (chat-backend)

```bash
cd D:\src\MHG\chat-backend
# Update @mentalhelpglobal/chat-types dependency
npm install
# Create src/services/groupAccess.service.ts
# Update group routes and review routes
npm test  # Run Vitest
```

### 4. Frontend (workbench-frontend)

```bash
cd D:\src\MHG\workbench-frontend
# Update GroupScopeSelector.tsx
npm run dev  # Local development server
```

## Verification

### Manual Test Flow

1. Log in to workbench as a Researcher with zero group memberships
2. Verify the group selector shows all groups
3. Select a group → verify review queue loads with that group's sessions
4. Submit a review → verify it saves successfully
5. Check audit log → verify `access_type: "global_role"` in details

### Negative Test

1. Log in as a QA Specialist with no group memberships
2. Verify the group selector is empty
3. Verify no group-scoped features are accessible

## Key Files to Modify

| Repository | File | Change |
|------------|------|--------|
| chat-types | `src/rbac.ts` | Add `GLOBAL_GROUP_ACCESS_ROLES` constant |
| chat-backend | `src/services/groupAccess.service.ts` | New file: `canAccessGroup()` function |
| chat-backend | `src/services/reviewQueue.service.ts` | Remove `canAccessGroupScopedQueue()`, use `canAccessGroup()` |
| chat-backend | `src/routes/review.queue.ts` | Use `canAccessGroup()` for access check |
| chat-backend | `src/routes/review.sessions.ts` | Use `canAccessGroup()` for access check |
| chat-backend | `src/routes/group.ts` | Add role-tier check for group endpoints |
| chat-backend | `src/routes/admin.groups.ts` | Widen permission gate on `GET /api/admin/groups` |
| chat-backend | `src/services/groupMembership.service.ts` | Allow `setActiveGroup()` for global roles without membership |
| chat-backend | `src/services/auth.service.ts` | Pass `access_type` to audit log entries |
| workbench-frontend | `src/features/workbench/components/GroupScopeSelector.tsx` | Show all groups for Researcher+ roles |

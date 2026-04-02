# Quickstart: Fix Workbench Space Selector Role-Based Access

**Feature**: 043-fix-space-role-access
**Date**: 2026-04-02

## Prerequisites

- Access to `chat-backend` and `workbench-frontend` repositories
- Node.js 20+ and npm installed
- Dev environment access: `https://workbench.dev.mentalhelp.chat`
- Test accounts with the following roles:
  - Researcher (with membership in at least one Space, and at least one Space without membership)
  - QA Specialist (with membership in exactly one Space)
  - Owner (with zero group memberships, or configurable)

## Setup

### 1. Create feature branches

```bash
# In chat-backend
cd /path/to/chat-backend
git checkout develop && git pull
git checkout -b 043-fix-space-role-access

# In workbench-frontend
cd /path/to/workbench-frontend
git checkout develop && git pull
git checkout -b 043-fix-space-role-access
```

### 2. Install dependencies

```bash
# In each repository
npm install
```

No `chat-types` update needed — `GLOBAL_GROUP_ACCESS_ROLES` and `hasGlobalGroupAccess()` are already available in the current published version.

## Verification Flow

### Test 1: Global Role Holder Switches Space (P1)

1. Log in to `https://workbench.dev.mentalhelp.chat` as **Researcher**
2. Open the Space selector dropdown in the header
3. **Verify**: All non-archived Spaces are listed (not just membership Spaces)
4. Select a Space you are NOT a member of
5. **Verify**: The selected Space becomes active; review queue / dashboard shows that Space's data
6. Refresh the page (F5)
7. **Verify**: The selected Space persists after refresh

### Test 2: QA Specialist Gating (P1)

1. Log in as **QA Specialist** with membership in Space A only
2. Open the Space selector dropdown
3. **Verify**: Only Space A is listed
4. Manually navigate to a URL scoped to Space B
5. **Verify**: Access denied / redirected back

### Test 3: Navigation Persistence (P2)

1. Log in as **Supervisor** (no memberships)
2. Select any Space
3. Navigate: Review Queue → Dashboard → Group Configuration → back to Review Queue
4. **Verify**: Same Space remains active throughout all navigations

### Test 4: Server Error Handling (P2)

1. Simulate a server error during Space switch (e.g., kill backend temporarily)
2. Attempt to switch Space
3. **Verify**: Dropdown reverts to previous Space; error notification displayed

### Test 5: Chat Frontend Regression (P1)

1. Log in as a regular **User** on `https://dev.mentalhelp.chat`
2. **Verify**: Chat group selector shows only membership groups
3. **Verify**: Chat participation works normally — no behavioral change

## Running Tests

```bash
# Backend unit tests
cd /path/to/chat-backend
npm test -- --run src/services/__tests__/groupAccess.service.test.ts

# All backend tests
npm test
```

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Dropdown still shows only membership Spaces | `GET /api/admin/groups` not returning all groups for Researcher+ | Check `admin.groups.ts` permission gate |
| Space resets after selection | `setActiveGroup()` rejecting non-member group | Check `groupMembership.service.ts` membership validation bypass |
| Space resets on page refresh | Frontend re-validating active group against membership list | Check `GroupScopeSelector.tsx` mount/effect logic |
| QA Specialist sees all Spaces | Role check not properly excluding QA_SPECIALIST | Verify `hasGlobalGroupAccess()` returns false for QA_SPECIALIST |

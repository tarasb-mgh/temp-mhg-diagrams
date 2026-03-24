# Quickstart: Move Privacy to Security & Hide Escalations

**Feature**: 039-menu-privacy-escalations  
**Date**: 2026-03-24

## Prerequisites

- `workbench-frontend` repository cloned and on `develop`
- Node.js and npm installed
- 033-workbench-menu-groups sidebar groups already deployed
- 035-dynamic-permissions-engine Security nav group already deployed

## Setup

### 1. Create feature branch

```bash
cd workbench-frontend
git checkout develop && git pull origin develop
git checkout -b 039-menu-privacy-escalations
```

### 2. Modify WorkbenchLayout.tsx

Single file: `src/features/workbench/WorkbenchLayout.tsx`

Three changes:
1. Remove Privacy item from `peopleAccess` group items array
2. Add Privacy item as last entry in `securityNavGroup` items array
3. Remove Escalations item from `reviews` group items array
4. Remove `group.id === 'security'` special case in `visibleGroups` useMemo
5. Remove unused `AlertTriangle` import (if applicable)

### 3. Local dev server

```bash
npm run dev
```

## Verification

### Manual (local)

1. Log in as Owner → verify Privacy appears under Security (last item), not under People & Access
2. Verify Escalations does NOT appear under Reviews
3. Navigate to `/workbench/privacy` via URL bar → page loads
4. Navigate to `/workbench/review/escalations` via URL bar → page loads
5. Collapse Security group → navigate to `/workbench/privacy` → Security auto-expands

### After deploy to dev

1. Same checks on `https://workbench.dev.mentalhelp.chat`
2. Playwright tests for SC-001 through SC-006

## Affected Repositories

| Repository | Files Changed |
|------------|--------------|
| `workbench-frontend` | `src/features/workbench/WorkbenchLayout.tsx` |

No other repositories are affected.

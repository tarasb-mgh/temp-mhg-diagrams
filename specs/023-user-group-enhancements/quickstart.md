# Quickstart: 023-user-group-enhancements

**Date**: 2026-03-10

## Prerequisites

- Access to both `workbench-frontend` and `chat-backend` repositories at `D:\src\MHG\`
- Node.js 20+, npm
- A running local or dev backend (`npm run dev` in `chat-backend`)
- `GITHUB_TOKEN` set for `@mentalhelpglobal` scoped packages

## Branch Setup

Run in both repos:

```bash
git checkout develop
git pull origin develop
git checkout -b 023-user-group-enhancements
```

## workbench-frontend

```bash
cd D:/src/MHG/workbench-frontend
npm install
npm run dev        # http://localhost:5173
npm test           # Vitest unit tests
npm run build      # TypeScript compilation check
```

## chat-backend

```bash
cd D:/src/MHG/chat-backend
npm install
npm run dev        # http://localhost:8080
npm test           # Vitest unit tests
```

## Key Files to Modify

### workbench-frontend

| Story | File | Change |
|-------|------|--------|
| US1 | `src/features/workbench/groups/GroupsView.tsx` | Show privileged role indicator in member list |
| US2 | `src/stores/workbenchStore.ts` | Add `groupListVersion` + `bumpGroupListVersion` |
| US2 | `src/features/workbench/groups/GroupsView.tsx` | Call `bumpGroupListVersion()` after successful create |
| US2/US3 | `src/features/workbench/components/GroupScopeSelector.tsx` | Add polling + privileged-always-show logic |
| US6 | `src/features/workbench/surveys/components/InvalidationMenu.tsx` | NEW component |
| US6 | `src/features/workbench/surveys/SurveyInstanceDetailView.tsx` | Replace inline buttons with `<InvalidationMenu>` |
| US6 | `src/features/workbench/surveys/SurveyResponseListView.tsx` | Replace inline buttons with `<InvalidationMenu>` |
| US7 | `src/features/workbench/groups/GroupsView.tsx` | Add privileged filter to member lookup |
| US8 | `src/features/workbench/users/UserListView.tsx` | Remove row-click nav, add copy icon, URL params for filter |
| US8 | `src/features/workbench/users/UserProfileCard.tsx` | Add copy icon next to email |

### chat-backend

| Story | File | Change |
|-------|------|--------|
| US1 | `src/services/group.service.ts` | Remove OWNER/MODERATOR/SUPERVISOR from FORBIDDEN_TARGET_ROLE |
| US7 | `src/routes/users.ts` | Add `privileged=true` query param filter |

## i18n Keys to Add

All new translation keys must be added to all three locale files:
- `src/locales/en/translation.json`
- `src/locales/uk/translation.json`
- `src/locales/ru/translation.json`

New keys needed (at minimum):

```json
{
  "groups.privilegedBadge": "Privileged",
  "groups.lookupPrivileged": "Show privileged accounts only",
  "survey.invalidation.menu": "Invalidation",
  "survey.invalidation.confirmTitle": "Confirm Invalidation",
  "survey.invalidation.confirmBody": "This action cannot be undone. All affected responses will be marked invalid.",
  "users.copyEmail": "Copy email",
  "users.emailCopied": "Email copied!"
}
```

## Verification Checklist

- [ ] `npm run build` passes in both repos with no TypeScript errors
- [ ] `npm test` passes in both repos
- [ ] Dev browser: create a group → spaces dropdown updates within 2 s without page reload
- [ ] Dev browser: privileged account (OWNER/SUPERVISOR) always sees spaces dropdown regardless of group count
- [ ] Dev browser: adding a privileged account to a group succeeds (no FORBIDDEN error)
- [ ] Dev browser: invalidation buttons appear only in the Invalidation menu; confirmation modal fires before any action
- [ ] Dev browser: user list row click does NOT navigate; only [View] button navigates
- [ ] Dev browser: copy icon on email copies to clipboard, icon briefly changes to ✓
- [ ] Dev browser: apply search filter, navigate to user card, press back → filter is preserved

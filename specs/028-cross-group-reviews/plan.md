# Implementation Plan: Cross-Group Review Access and Group Filter Scoping

**Branch**: `028-cross-group-reviews` | **Date**: 2026-03-12 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/028-cross-group-reviews/spec.md`

## Summary

Fix two backend route guards that block RESEARCHER and SUPERVISOR users from viewing sessions belonging to groups they are not a member of. The `REVIEW_CROSS_GROUP` permission already exists in `chat-types` and is already assigned to both roles — the guards simply do not check for it. Secondary: verify and if needed fix the workbench group filter dropdown so it presents all available groups (not just user-membership groups) to users with `REVIEW_CROSS_GROUP`.

## Technical Context

**Language/Version**: TypeScript 5.x (backend + frontend)
**Primary Dependencies**: Express 4.x (backend), React + Zustand (workbench-frontend)
**Storage**: PostgreSQL (no schema changes)
**Testing**: Vitest (backend unit), Playwright in `chat-ui` (E2E against dev)
**Target Platform**: Node.js 20 on Cloud Run (backend); React SPA on GCS/GCLB (workbench)
**Project Type**: Multi-repo web service (backend API + workbench frontend)
**Performance Goals**: No performance impact — the change removes a DB membership lookup for privileged users rather than adding work
**Constraints**: No migrations; no breaking API changes; Reviewer behaviour must remain unchanged (FR-003)
**Scale/Scope**: 2 backend route files; 1–2 workbench-frontend files depending on group list source finding

## Constitution Check

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Spec-First | ✅ Pass | spec.md complete, checklist passed |
| II. Multi-Repo Orchestration | ✅ Pass | `chat-backend` primary; `workbench-frontend` conditional; cross-repo dependencies documented |
| III. Test-Aligned | ✅ Pass | Vitest for backend unit; Playwright E2E for UI flow (in `chat-ui`) |
| IV. Branch & Integration | ✅ Pass | Feature branch `028-cross-group-reviews` exists; PRs target `develop` |
| V. Privacy & Security | ✅ Pass | Change grants read access to existing sessions for roles already authorised by the permission model — no new data exposure beyond what the permission was designed for; Reviewer isolation preserved |
| VI. Accessibility & i18n | ✅ Pass | No UI text changes; existing i18n applies |
| VII. Split-Repo First | ✅ Pass | Implementation targets `chat-backend` and `workbench-frontend` split repos only |
| VIII. GCP CLI Infra | ✅ Pass | No infrastructure changes |
| IX. Responsive/PWA | ✅ Pass | No layout or PWA changes |
| X. Jira Traceability | ✅ Pass | Epic/Stories/Tasks to be created via `/speckit.tasks` |
| XI. Documentation | ⚠️ Note | User Manual and Non-Technical Onboarding for workbench require update on production release (new cross-group review access described) |
| XII. Release Engineering | ✅ Pass | Dev validation before release; no infra topology changes |

## Project Structure

### Documentation (this feature)

```text
specs/028-cross-group-reviews/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Technical decisions (Phase 0)
├── data-model.md        # Entity reference (Phase 1)
├── contracts/
│   └── review-api.md    # Endpoint behaviour contract (Phase 1)
└── tasks.md             # Task breakdown (Phase 2 — /speckit.tasks)
```

### Source Code

```text
chat-backend/
└── src/
    └── routes/
        ├── review.queue.ts       # CHANGE: group access guard line 38
        └── review.sessions.ts    # CHANGE: group access guard line 73

workbench-frontend/
└── src/
    └── features/workbench/review/
        └── ReviewQueueView.tsx   # VERIFY: group filter data source
        (conditional: fix group list fetch if needed)
```

**Structure Decision**: Two split repos. `chat-backend` is the required change. `workbench-frontend` is conditional on the group list verification (see Task T004).

---

## Implementation Details

### US1 — Backend: Fix group access guard in review.queue.ts

**File**: `chat-backend/src/routes/review.queue.ts`
**Location**: lines 38–49 (group access guard block)

**Current code** (simplified):
```typescript
if (groupId && req.user?.role !== UserRole.OWNER) {
  const hasAccess = await canAccessGroupScopedQueue(req.user!.id, groupId);
  if (!hasAccess) {
    return res.status(403).json({ success: false, error: { code: 'FORBIDDEN' } });
  }
}
```

**Fix**:
```typescript
const hasCrossGroupAccess = req.user?.permissions?.includes(Permission.REVIEW_CROSS_GROUP);
if (groupId && req.user?.role !== UserRole.OWNER && !hasCrossGroupAccess) {
  const hasAccess = await canAccessGroupScopedQueue(req.user!.id, groupId);
  if (!hasAccess) {
    return res.status(403).json({ success: false, error: { code: 'FORBIDDEN' } });
  }
}
```

**Import to add**: `Permission` from the rbac types (already imported or re-exported via middleware).

---

### US1 — Backend: Fix group access guard in review.sessions.ts

**File**: `chat-backend/src/routes/review.sessions.ts`
**Location**: lines 73–81 (group access guard block — same pattern as above)

**Same fix**: Add `hasCrossGroupAccess` bypass alongside the existing `OWNER` bypass.

---

### US2 — Frontend: Verify group filter data source

**File**: `workbench-frontend/src/features/workbench/review/ReviewQueueView.tsx`

**Verification task**: Determine how the group list for the filter dropdown is populated:
- Option A: API returns all groups (e.g., `/api/admin/groups`) — no frontend change needed
- Option B: API returns only user's membership groups — need to change the source for `REVIEW_CROSS_GROUP` users so the filter shows all groups

If Option B, the fix is to:
1. Check if the user has `REVIEW_CROSS_GROUP` permission in the component or store
2. Fetch all groups from an appropriate admin-level groups endpoint for those users
3. Populate the filter dropdown with the full group list

---

## Execution Order

```
T001: Create feature branch 028-cross-group-reviews in chat-backend
T002: Create feature branch 028-cross-group-reviews in workbench-frontend
  ↓
T003 [US1]: Fix group access guard in chat-backend/src/routes/review.queue.ts
T004 [US1]: Fix group access guard in chat-backend/src/routes/review.sessions.ts
  ↓
T005 [US2]: Verify group filter data source in workbench-frontend ReviewQueueView.tsx
T006 [US2]: (conditional) Fix group list fetch for REVIEW_CROSS_GROUP users if needed
  ↓
T007: Open PR for chat-backend → develop
T008: Open PR for workbench-frontend → develop (if changes made)
  ↓
T009: Smoke test on dev — RESEARCHER can see cross-group sessions
T010: Smoke test on dev — group filter scopes correctly
```

---

## Dependencies and Assumptions

- `Permission.REVIEW_CROSS_GROUP` exists in `chat-types/src/rbac.ts` and is importable in `chat-backend` route files — confirmed by research.
- `req.user.permissions` is populated by the auth middleware before route handlers run — assumed based on existing OWNER check pattern; verify during T003.
- `reviewQueue.service.ts` `listQueueSessions()` already applies `groupId` as an exact WHERE filter when provided and returns all when absent — confirmed by research; no service change needed.
- The workbench `workbenchGuard` middleware already confirms WORKBENCH_ACCESS before any review route is reached — RESEARCHER and SUPERVISOR already pass this gate.
- No changes to `chat-types` — permission model is complete.
- No database migrations.

---

## Risk Notes

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| `req.user.permissions` not populated for workbench routes | Low | Verify in T003; if absent, check auth middleware population |
| Group filter shows empty for zero-membership RESEARCHER | Medium | Addressed by T005/T006 verification and conditional fix |
| Reviewer accidentally gains cross-group access | Very Low | Guard condition only bypasses for `hasCrossGroupAccess`; Reviewer does not have `REVIEW_CROSS_GROUP` permission |

---

## Complexity Tracking

No constitution violations. All changes are minimal, targeted, and within existing patterns.

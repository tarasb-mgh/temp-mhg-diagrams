# Implementation Plan: Survey Instance Management

**Branch**: `029-survey-management` | **Date**: 2026-03-14 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/029-survey-management/spec.md`

## Summary

Add admin-facing survey instance management capabilities to the workbench: (1) edit the expiration date of an active or expired survey instance, with automatic re-activation if expired; (2) reassign the group(s) mid-flight while preserving all existing responses; (3) view per-group completion statistics with a list of individual non-completers. No database schema changes required — all work is service-layer, API, and UI additions.

## Technical Context

**Language/Version**: TypeScript 5.x (backend: Node.js 20 LTS, frontend: React 18)
**Primary Dependencies**: Express (chat-backend), React + Zustand + react-i18next (workbench-frontend), `pg` (native PostgreSQL client)
**Storage**: PostgreSQL via `pg` — no new tables; updates to `survey_instances` and `group_survey_order`
**Testing**: Vitest (unit — chat-backend, workbench-frontend), Playwright (E2E — chat-ui)
**Target Platform**: GCP Cloud Run (backend), GCS/GCLB (workbench-frontend)
**Performance Goals**: Statistics endpoint < 500ms p95 for groups up to 200 members
**Constraints**: Responses are immutable (never deleted); closed instances cannot be modified; expiration date must be a future datetime
**Scale/Scope**: Existing deployment scale; no infrastructure changes needed

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Spec-First | ✅ Pass | spec.md complete, no unresolved clarifications |
| II. Multi-Repository Orchestration | ✅ Pass | Affected repos documented below: chat-types, chat-backend, workbench-frontend, chat-ui |
| III. Test-Aligned Development | ✅ Pass | Vitest unit tests in chat-backend + workbench-frontend; Playwright E2E in chat-ui |
| IV. Branch and Integration Discipline | ✅ Pass | Feature branch `029-survey-management` created; PRs to `develop` only |
| V. Privacy and Security First | ✅ Pass | Statistics endpoint gated by workbench permissions; email only exposed to SURVEY_INSTANCE_MANAGE / SURVEY_INSTANCE_VIEW role |
| VI. Accessibility and i18n | ✅ Pass | All new UI labels use i18n keys; edit form and statistics view must be keyboard-accessible |
| VII. Split-Repository First | ✅ Pass | chat-client (monorepo) not touched |
| VIII. GCP CLI Infrastructure | ✅ Pass | No infrastructure changes required |
| IX. Responsive UX / PWA | ✅ Pass | Edit form and statistics view must be responsive (workbench breakpoints) |
| X. Jira Traceability | ✅ Pass | Jira Epic + Stories + Tasks will be created via /speckit.tasks + /speckit.sync |
| XI. Documentation Standards | ✅ Pass | User Manual + Non-Technical Onboarding updates required on release |
| XII. Release Engineering | ✅ Pass | Production release requires explicit owner approval |

**Post-design re-check**: No violations introduced. The statistics query joins group_memberships → users, which exposes email — scoped to workbench-only permissions. Principle V satisfied.

## Project Structure

### Documentation (this feature)

```text
specs/029-survey-management/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/
│   └── survey-instance-management.yaml  # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (affected repositories)

```text
chat-types/
└── src/
    └── survey.ts                        # New types: SurveyInstanceUpdateInput,
                                         #   SurveyMemberCompletion, SurveyGroupStatistics,
                                         #   SurveyInstanceStatistics

chat-backend/
└── src/
    ├── services/
    │   └── surveyInstance.service.ts    # updateInstance(), getInstanceStatistics()
    └── routes/
        └── survey.instances.ts          # PATCH /:id, GET /:id/statistics

workbench-frontend/
└── src/
    ├── features/workbench/surveys/
    │   ├── SurveyInstanceDetailView.tsx # Add edit button → InstanceEditModal
    │   ├── components/
    │   │   ├── InstanceEditModal.tsx    # New: expiration + group edit form
    │   │   └── SurveyStatisticsView.tsx # New: completion stats + non-completers
    ├── services/
    │   └── surveyApi.ts                 # patchInstance(), getInstanceStatistics()
    └── stores/
        └── surveyStore.ts               # updateInstance(), fetchInstanceStatistics()

chat-ui/
└── tests/
    └── survey-management.spec.ts        # New E2E tests for all 3 user stories
```

**Structure Decision**: Web application (workbench-frontend + chat-backend) with shared types in chat-types. No infra or CI changes. Feature branch `029-survey-management` must be created in chat-types, chat-backend, workbench-frontend, and chat-ui.

## Cross-Repository Execution Order

1. **chat-types** first — new types must be published before backend/frontend can consume them
2. **chat-backend** second — new endpoints, validated against new types
3. **workbench-frontend** third — new UI, validated against dev backend
4. **chat-ui** last — E2E tests run against deployed dev environment

## Implementation Phases

### Phase 1: Shared Types (chat-types)

**Target**: `D:\src\MHG\chat-types`

Add to `src/survey.ts`:

```typescript
// New input type for PATCH /survey-instances/:id
export interface SurveyInstanceUpdateInput {
  expirationDate?: string;   // ISO 8601; must be future
  groupIds?: string[];       // Non-empty; replaces existing
}

// Per-member completion status (used in statistics)
export interface SurveyMemberCompletion {
  userId: string;
  displayName: string;
  email: string;
  isComplete: boolean;
  completedAt: string | null;
}

// Per-group statistics block
export interface SurveyGroupStatistics {
  groupId: string;
  groupName: string;
  totalMembers: number;
  completedCount: number;
  pendingCount: number;
  completionRate: number;   // 0–1, safe for totalMembers=0
  members: SurveyMemberCompletion[];
}

// Top-level response for GET /survey-instances/:id/statistics
export interface SurveyInstanceStatistics {
  instanceId: string;
  groups: SurveyGroupStatistics[];
}
```

Export all four types from `src/index.ts`. Bump patch version.

---

### Phase 2: Backend Service & Routes (chat-backend)

**Target**: `D:\src\MHG\chat-backend`

#### 2A: `surveyInstance.service.ts` — updateInstance()

```typescript
async function updateInstance(
  id: string,
  input: SurveyInstanceUpdateInput
): Promise<SurveyInstance>
```

Logic:
1. Load current instance; throw 404 if not found
2. Throw 409 if `status = 'closed'`
3. If `expirationDate` provided:
   - Validate it parses as ISO datetime
   - Validate it is strictly after `new Date()` (UTC)
   - If current `status = 'expired'` AND new date > now: set `newStatus = 'active'`; else keep current status
4. If `groupIds` provided:
   - Validate array is non-empty
   - Resolve old `group_ids` from DB
   - Compute added groups = new − old; removed groups = old − new
5. Build and execute UPDATE on `survey_instances`
6. If `groupIds` changed: INSERT `group_survey_order` rows for added groups; DELETE rows for removed groups (transactional)
7. Return updated instance (with `completedCount`)

#### 2B: `surveyInstance.service.ts` — getInstanceStatistics()

```typescript
async function getInstanceStatistics(
  instanceId: string,
  groupIdFilter?: string
): Promise<SurveyInstanceStatistics>
```

Logic:
1. Load instance; throw 404 if not found
2. If `groupIdFilter` provided: validate it exists in `instance.group_ids`; throw 400 if not
3. Determine target groups = `groupIdFilter ? [groupIdFilter] : instance.group_ids`
4. Query: all active members for target groups (JOIN users + group_memberships)
5. Query: all valid complete responses for this instance (is_complete=true, invalidated_at IS NULL)
6. Build per-group statistics:
   - JOIN member list against responses by `user_id = pseudonymous_id`
   - Compute counts, rate (handle totalMembers=0 → completionRate=0)
7. Return `SurveyInstanceStatistics`

#### 2C: `survey.instances.ts` — New routes

```typescript
// PATCH /survey-instances/:id
router.patch('/:id',
  authenticate, requireActiveAccount, workbenchGuard,
  requirePermission(Permission.SURVEY_INSTANCE_MANAGE),
  async (req, res) => { ... }
)

// GET /survey-instances/:id/statistics
router.get('/:id/statistics',
  authenticate, requireActiveAccount, workbenchGuard,
  requireAnyPermission(Permission.SURVEY_INSTANCE_MANAGE, Permission.SURVEY_INSTANCE_VIEW),
  async (req, res) => { ... }
)
```

#### 2D: Unit tests (Vitest)

- `updateInstance` with expirationDate: valid future date, past date rejection, closed rejection
- `updateInstance` with groupIds: group add/remove sync, response preservation assertion
- `updateInstance` with expired status + future date: verifies status reset to 'active'
- `getInstanceStatistics`: completers/non-completers calculation, empty group handling, groupId filter

---

### Phase 3: Workbench Frontend (workbench-frontend)

**Target**: `D:\src\MHG\workbench-frontend`

#### 3A: `surveyApi.ts` — New API calls

```typescript
// PATCH /workbench/survey-instances/:id
export async function patchInstance(
  id: string,
  input: SurveyInstanceUpdateInput
): Promise<ApiResponse<SurveyInstance>>

// GET /workbench/survey-instances/:id/statistics?groupId=
export async function getInstanceStatistics(
  id: string,
  groupId?: string
): Promise<ApiResponse<SurveyInstanceStatistics>>
```

#### 3B: `surveyStore.ts` — New store actions

```typescript
updateInstance: (id: string, input: SurveyInstanceUpdateInput) => Promise<boolean>
// On success: updates currentInstance and refreshes the instances list entry

fetchInstanceStatistics: (id: string, groupId?: string) => Promise<void>
// Stores result in instanceStatistics / instanceStatisticsLoading / instanceStatisticsError
```

#### 3C: `InstanceEditModal.tsx` (new component)

- Modal triggered by "Edit" button on `SurveyInstanceDetailView`
- Form fields:
  - **Expiration Date**: datetime-local input, pre-filled with current value, future-only validation
  - **Groups**: multi-select checkbox list (reuse existing pattern from `InstanceCreateForm`), pre-selected with current groups
- Submit calls `surveyStore.updateInstance()`
- On success: closes modal, shows success toast, refreshes instance detail
- On error: displays validation message from API response
- Disabled (read-only display) for `status='closed'` instances
- All labels use i18n keys (`survey.instanceEdit.*`)
- Keyboard accessible; focus trap in modal

#### 3D: `SurveyStatisticsView.tsx` (new component)

- Rendered as a tab or section within `SurveyInstanceDetailView`
- On mount: calls `surveyStore.fetchInstanceStatistics(instanceId)`
- If instance spans multiple groups: renders a group tabs/selector at top
- Per-group display:
  - Summary row: total members, completed, pending, completion rate (as percentage)
  - Progress bar showing completion rate
  - **Non-Completers** table: columns — Name, Email, Status (pending/completed)
  - Table filterable: show all / show pending only
- Loading skeleton while fetching
- Empty state when all members completed ("All members have completed this survey")
- All labels use i18n keys (`survey.statistics.*`)
- Responsive layout: table scrolls horizontally on small screens

#### 3E: `SurveyInstanceDetailView.tsx` — Modifications

- Add **Edit** button (pencil icon) in header, gated by `SURVEY_INSTANCE_MANAGE` permission
  - Opens `InstanceEditModal`
  - Hidden (or disabled with tooltip) when `status='closed'`
- Add **Statistics** tab alongside existing Responses view
  - Renders `SurveyStatisticsView`
  - Visible to `SURVEY_INSTANCE_MANAGE | SURVEY_INSTANCE_VIEW`

#### 3F: i18n keys (add to `en.json`, `uk.json`, `ru.json`)

```
survey.instanceEdit.title
survey.instanceEdit.expirationDate
survey.instanceEdit.groups
survey.instanceEdit.save
survey.instanceEdit.cancel
survey.instanceEdit.successMessage
survey.instanceEdit.errorPastDate
survey.instanceEdit.errorClosed
survey.statistics.title
survey.statistics.totalMembers
survey.statistics.completed
survey.statistics.pending
survey.statistics.completionRate
survey.statistics.nonCompleters
survey.statistics.allCompleted
survey.statistics.filterAll
survey.statistics.filterPending
```

---

### Phase 4: E2E Tests (chat-ui)

**Target**: `D:\src\MHG\chat-ui`

File: `tests/survey-management.spec.ts`

Test cases:
1. **Edit expiration date (US1)**: Log in as workbench admin → open active instance → edit expiration date → verify new date shown → verify existing responses preserved
2. **Reject past expiration date (US1 edge)**: Attempt to set past date → verify validation error shown
3. **Change group assignment (US2)**: Log in as admin → open active instance with response → change group → verify response still visible in responses tab → verify new group's user sees survey in gate-check
4. **View statistics (US3)**: Log in as admin → open instance with mixed completions → navigate to statistics tab → verify counts match → verify non-completer names listed
5. **Statistics all-completed state (US3 edge)**: All members completed → statistics shows 100% → non-completers list empty

---

## Complexity Tracking

No constitution violations. No complexity justification required.

## Dependencies Between Repositories

| Dependency | From | To | Notes |
|------------|------|----|-------|
| `SurveyInstanceUpdateInput`, `SurveyInstanceStatistics`, etc. | chat-backend, workbench-frontend | chat-types | Must publish new types before backend/frontend implement |
| New PATCH + statistics endpoints | workbench-frontend | chat-backend | Frontend depends on backend being deployed to dev |
| E2E tests | chat-ui | workbench-frontend + chat-backend | Tests run against deployed dev environment |

## i18n Requirement

Per Constitution Principle VI: all new user-visible strings in workbench-frontend must be added to `en.json`, `uk.json`, and `ru.json` translation files. Translations for `uk` and `ru` may use placeholder values initially but must not be omitted.

## Accessibility Requirement

Per Constitution Principle VI:
- `InstanceEditModal`: focus trap, ESC closes, form labels associated with inputs
- `SurveyStatisticsView`: table has proper `<thead>` and `<caption>` or `aria-label`; progress bar uses `role="progressbar"` with `aria-valuenow`/`aria-valuemax`

## Evidence Required

Per Constitution Principle III:
- Screenshots of edit modal (before/after save)
- Screenshots of statistics tab with non-completers visible
- Playwright test run output (pass)
- Backend unit test run output (pass)
- Store in `evidence/` under this feature directory
